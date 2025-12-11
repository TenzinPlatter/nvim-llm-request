"""OpenAI API client with streaming support."""
from typing import Iterator, Dict, Any, List, Optional
from openai import OpenAI


class OpenAIClient:
    """Client for OpenAI API."""

    def __init__(self, api_key: str, model: str, base_url: Optional[str] = None):
        self.client = OpenAI(api_key=api_key, base_url=base_url)
        self.model = model

    def stream_completion(
        self,
        context: str,
        prompt: Optional[str],
        tools: List[Dict[str, Any]],
    ) -> Iterator[Dict[str, Any]]:
        """
        Stream a completion from OpenAI.

        Yields:
            {"type": "completion", "content": "..."}
            {"type": "tool_call", "name": "...", "args": {...}}
            {"type": "done"}
        """
        # Build messages
        user_message = context
        if prompt:
            user_message += f"\n\n{prompt}"

        messages = [
            {"role": "system", "content": "You are a code completion assistant."},
            {"role": "user", "content": user_message}
        ]

        # Stream the response
        stream = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            tools=tools if tools else None,
            stream=True,
        )

        for chunk in stream:
            if not chunk.choices:
                continue

            delta = chunk.choices[0].delta

            # Handle text content
            if delta.content:
                yield {
                    'type': 'completion',
                    'content': delta.content
                }

            # Handle tool calls
            if delta.tool_calls:
                for tool_call in delta.tool_calls:
                    if tool_call.function:
                        yield {
                            'type': 'tool_call',
                            'name': tool_call.function.name,
                            'args': tool_call.function.arguments,
                        }

        yield {'type': 'done'}
