#!/usr/bin/env python3
"""
AI Request backend - handles LLM API calls via stdio JSON protocol.
"""
import sys
import json
from typing import Iterator, Dict, Any
from config import Config
from providers.anthropic_client import AnthropicClient
from providers.openai_client import OpenAIClient
from tools import get_tool_definitions, convert_tools_for_anthropic


def process_request(request: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    """
    Process a request and yield response events.

    Args:
        request: {
            "type": "complete",
            "context": "...",
            "prompt": "..." or None,
            "config": {...} or None
        }

    Yields:
        {"type": "completion", "content": "..."}
        {"type": "thinking", "content": "..."}
        {"type": "tool_call", "name": "...", "args": {...}}
        {"type": "done"}
        {"type": "error", "message": "..."}
    """
    try:
        if request['type'] != 'complete':
            yield {"type": "error", "message": f"Unknown request type: {request['type']}"}
            return

        # Get config (from request or environment)
        if 'config' in request:
            config_dict = request['config']
            from config import Config as ConfigClass
            config = ConfigClass(**config_dict)
        else:
            config = Config.from_env()

        # Get tools
        tools = get_tool_definitions()

        # Create client
        if config.provider == 'anthropic':
            client = AnthropicClient(config.api_key, config.model)
            tools = convert_tools_for_anthropic(tools)
        elif config.provider == 'openai':
            client = OpenAIClient(config.api_key, config.model, config.base_url)
        elif config.provider == 'local':
            # Local models use OpenAI-compatible API
            client = OpenAIClient(config.api_key, config.model, config.base_url)
        else:
            yield {"type": "error", "message": f"Unknown provider: {config.provider}"}
            return

        # Stream completion
        context = request['context']
        prompt = request.get('prompt')

        for event in client.stream_completion(context, prompt, tools):
            yield event

    except Exception as e:
        yield {"type": "error", "message": str(e)}


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
