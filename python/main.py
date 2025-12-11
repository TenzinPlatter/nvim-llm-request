#!/usr/bin/env python3
"""
AI Request backend - handles LLM API calls via stdio JSON protocol.
"""
import sys
import json
from typing import Iterator, Dict, Any, Optional
from config import Config
from providers.anthropic_client import AnthropicClient
from providers.openai_client import OpenAIClient
from tools import get_tool_definitions, convert_tools_for_anthropic


# Global state for tracking conversations
conversations: Dict[str, Dict[str, Any]] = {}


def process_request(request: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    """
    Process a request and yield response events.

    Args:
        request: {
            "type": "complete" | "tool_response",
            "request_id": "..." (optional for complete, required for tool_response),
            "context": "..." (for complete),
            "prompt": "..." or None (for complete),
            "config": {...} or None (for complete),
            "tool_call_id": "..." (for tool_response),
            "content": "..." (for tool_response)
        }

    Yields:
        {"type": "completion", "content": "..."}
        {"type": "thinking", "content": "..."}
        {"type": "tool_call", "id": "...", "name": "...", "args": {...}}
        {"type": "done"}
        {"type": "error", "message": "..."}
    """
    try:
        request_type = request.get('type')

        if request_type == 'complete':
            yield from handle_complete_request(request)
        elif request_type == 'tool_response':
            yield from handle_tool_response(request)
        else:
            yield {"type": "error", "message": f"Unknown request type: {request_type}"}

    except Exception as e:
        yield {"type": "error", "message": str(e)}


def handle_complete_request(request: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    """Handle initial completion request."""
    # Get config (from request or environment)
    if 'config' in request:
        config_dict = request['config']
        from config import Config as ConfigClass
        config = ConfigClass(**config_dict)
    else:
        config = Config.from_env()

    # Get tools
    tools = get_tool_definitions()
    is_anthropic = config.provider == 'anthropic'

    # Create client
    if is_anthropic:
        client = AnthropicClient(config.api_key, config.model)
        tools = convert_tools_for_anthropic(tools)
    elif config.provider in ['openai', 'local']:
        client = OpenAIClient(config.api_key, config.model, config.base_url)
    else:
        yield {"type": "error", "message": f"Unknown provider: {config.provider}"}
        return

    # Build initial message
    context = request['context']
    prompt = request.get('prompt')
    user_message = context
    if prompt:
        user_message += f"\n\n{prompt}"

    # Store conversation state
    request_id = request.get('request_id', str(id(request)))
    conversations[request_id] = {
        'config': config,
        'client': client,
        'tools': tools,
        'is_anthropic': is_anthropic,
        'user_message': user_message,
        'tool_calls': [],
        'completion_parts': [],
    }

    # Stream completion
    for event in client.stream_completion(context, prompt, tools):
        if event['type'] == 'tool_call':
            # Store tool call and wait for response
            conversations[request_id]['tool_calls'].append(event)
        elif event['type'] == 'completion':
            # Store completion parts
            conversations[request_id]['completion_parts'].append(event['content'])
        yield event


def handle_tool_response(request: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    """Handle tool response and continue conversation."""
    request_id = request.get('request_id')
    if not request_id or request_id not in conversations:
        yield {"type": "error", "message": "Invalid or expired request_id"}
        return

    conv = conversations[request_id]
    tool_call_id = request.get('tool_call_id')
    tool_content = request.get('content', '')

    # Find the corresponding tool call
    tool_call = None
    for tc in conv['tool_calls']:
        if tc.get('id') == tool_call_id:
            tool_call = tc
            break

    if not tool_call:
        yield {"type": "error", "message": f"Tool call {tool_call_id} not found"}
        return

    # Continue conversation with tool result
    if conv['is_anthropic']:
        yield from continue_anthropic_conversation(conv, tool_call, tool_content)
    else:
        yield from continue_openai_conversation(conv, tool_call, tool_content)

    # Clean up conversation after completion
    cleanup_conversation(request_id)


def continue_anthropic_conversation(
    conv: Dict[str, Any],
    tool_call: Dict[str, Any],
    tool_content: str
) -> Iterator[Dict[str, Any]]:
    """Continue Anthropic conversation with tool result."""
    from anthropic import Anthropic

    client = conv['client'].client
    model = conv['client'].model
    tools = conv['tools']

    # Build message history
    assistant_content = []

    # Add completion text if any
    if conv['completion_parts']:
        assistant_content.append({
            "type": "text",
            "text": "".join(conv['completion_parts'])
        })

    # Add tool use
    assistant_content.append({
        "type": "tool_use",
        "id": tool_call['id'],
        "name": tool_call['name'],
        "input": tool_call['args']
    })

    messages = [
        {"role": "user", "content": conv['user_message']},
        {"role": "assistant", "content": assistant_content},
        {"role": "user", "content": [
            {
                "type": "tool_result",
                "tool_use_id": tool_call['id'],
                "content": tool_content
            }
        ]}
    ]

    # Stream continuation
    with client.messages.stream(
        model=model,
        max_tokens=4096,
        messages=messages,
        tools=tools
    ) as stream:
        for event in stream:
            if event.type == 'content_block_delta':
                if hasattr(event.delta, 'text'):
                    yield {
                        'type': 'completion',
                        'content': event.delta.text
                    }

    yield {'type': 'done'}


def continue_openai_conversation(
    conv: Dict[str, Any],
    tool_call: Dict[str, Any],
    tool_content: str
) -> Iterator[Dict[str, Any]]:
    """Continue OpenAI conversation with tool result."""
    client = conv['client'].client
    model = conv['client'].model
    tools = conv['tools']

    # Build message history
    messages = [
        {"role": "system", "content": "You are a code completion assistant."},
        {"role": "user", "content": conv['user_message']},
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [{
                "id": tool_call['id'],
                "type": "function",
                "function": {
                    "name": tool_call['name'],
                    "arguments": json.dumps(tool_call['args'])
                }
            }]
        },
        {
            "role": "tool",
            "tool_call_id": tool_call['id'],
            "content": tool_content
        }
    ]

    # Stream continuation
    stream = client.chat.completions.create(
        model=model,
        messages=messages,
        tools=tools,
        stream=True
    )

    for chunk in stream:
        if chunk.choices:
            delta = chunk.choices[0].delta
            if delta.content:
                yield {
                    'type': 'completion',
                    'content': delta.content
                }

    yield {'type': 'done'}


def cleanup_conversation(request_id: str):
    """Clean up conversation state."""
    if request_id in conversations:
        del conversations[request_id]


def main():
    """Main stdio loop."""
    for line in sys.stdin:
        try:
            request = json.loads(line)

            for response in process_request(request):
                print(json.dumps(response), flush=True)

        except json.JSONDecodeError as e:
            error = {"type": "error", "message": f"Invalid JSON: {e}"}
            print(json.dumps(error), flush=True)
        except Exception as e:
            error = {"type": "error", "message": str(e)}
            print(json.dumps(error), flush=True)


if __name__ == "__main__":
    main()
