"""Anthropic API client with streaming support."""
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

        # Stream the response
        with self.client.messages.stream(
            model=self.model,
            max_tokens=4096,
            messages=messages,
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

                # Handle tool calls
                elif event.type == 'content_block_start':
                    if hasattr(event.content_block, 'type') and event.content_block.type == 'tool_use':
                        # Will be completed in subsequent deltas
                        pass

        yield {'type': 'done'}
