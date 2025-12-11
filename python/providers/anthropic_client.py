"""Anthropic API client with streaming support."""
import json
from typing import Iterator, Dict, Any, List, Optional
from anthropic import Anthropic


class AnthropicClient:
    """Client for Anthropic Claude API."""

    def __init__(self, api_key: str, model: str):
        self.client = Anthropic(api_key=api_key)
        self.model = model

    def stream_completion(
        self,
        context: str,
        prompt: Optional[str],
        tools: List[Dict[str, Any]],
    ) -> Iterator[Dict[str, Any]]:
        """
        Stream a completion from Claude.

        Yields:
            {"type": "thinking", "content": "..."}
            {"type": "completion", "content": "..."}
            {"type": "tool_call", "name": "...", "args": {...}}
            {"type": "done"}
        """
        # Build messages
        user_message = context
        if prompt:
            user_message += f"\n\n{prompt}"

        messages = [{"role": "user", "content": user_message}]

        # System instructions
        system_prompt = """You are a precise code completion assistant.

CRITICAL RULES:
1. Only generate NEW code that should be inserted at the <cursor> position
2. DO NOT repeat any code that appears before or after the cursor
3. DO NOT include explanations, comments about what you're doing, or markdown
4. Generate only the exact code to insert - nothing more, nothing less
5. Match the indentation and style of the surrounding code

The code before and after <cursor> is provided for context only - do not regenerate it."""

        # Track current tool use block
        current_tool = None
        tool_input_json = ""

        # Stream the response
        with self.client.messages.stream(
            model=self.model,
            max_tokens=4096,
            messages=messages,
            system=system_prompt,
            tools=tools if tools else None,
        ) as stream:
            for event in stream:
                # Handle text content
                if event.type == 'content_block_delta':
                    if hasattr(event.delta, 'text'):
                        yield {
                            'type': 'completion',
                            'content': event.delta.text
                        }
                    # Handle thinking (extended thinking in some models)
                    elif hasattr(event.delta, 'thinking'):
                        yield {
                            'type': 'thinking',
                            'content': event.delta.thinking
                        }
                    # Accumulate tool input JSON
                    elif hasattr(event.delta, 'type') and event.delta.type == 'input_json_delta':
                        if hasattr(event.delta, 'partial_json'):
                            tool_input_json += event.delta.partial_json

                # Handle tool call start
                elif event.type == 'content_block_start':
                    if hasattr(event.content_block, 'type') and event.content_block.type == 'tool_use':
                        current_tool = {
                            'id': event.content_block.id,
                            'name': event.content_block.name,
                        }
                        tool_input_json = ""

                # Handle tool call completion
                elif event.type == 'content_block_stop':
                    if current_tool:
                        try:
                            args = json.loads(tool_input_json) if tool_input_json else {}
                        except json.JSONDecodeError:
                            args = {}

                        yield {
                            'type': 'tool_call',
                            'id': current_tool['id'],
                            'name': current_tool['name'],
                            'args': args,
                        }
                        current_tool = None
                        tool_input_json = ""

        yield {'type': 'done'}
