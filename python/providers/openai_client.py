"""OpenAI API client with streaming support."""
import json
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
            {"type": "tool_call", "id": "...", "name": "...", "args": {...}}
            {"type": "done"}
        """
        # Build messages
        user_message = context
        if prompt:
            user_message += f"\n\n{prompt}"

        # System instructions
        system_prompt = """You are a precise code completion assistant.

CRITICAL RULES:
1. Only generate NEW code that should be inserted at the <cursor> position
2. DO NOT repeat any code that appears before or after the cursor
3. DO NOT include explanations, comments about what you're doing, or markdown
4. Generate only the exact code to insert - nothing more, nothing less
5. Match the indentation and style of the surrounding code

The code before and after <cursor> is provided for context only - do not regenerate it."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ]

        # Track accumulated tool calls by index
        tool_calls = {}

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
            finish_reason = chunk.choices[0].finish_reason

            # Handle text content
            if delta.content:
                yield {
                    'type': 'completion',
                    'content': delta.content
                }

            # Accumulate tool calls
            if delta.tool_calls:
                for tool_call_chunk in delta.tool_calls:
                    idx = tool_call_chunk.index

                    if idx not in tool_calls:
                        tool_calls[idx] = {
                            'id': tool_call_chunk.id or '',
                            'name': '',
                            'arguments': '',
                        }

                    if tool_call_chunk.id:
                        tool_calls[idx]['id'] = tool_call_chunk.id

                    if tool_call_chunk.function:
                        if tool_call_chunk.function.name:
                            tool_calls[idx]['name'] = tool_call_chunk.function.name
                        if tool_call_chunk.function.arguments:
                            tool_calls[idx]['arguments'] += tool_call_chunk.function.arguments

            # Yield completed tool calls when stream finishes
            if finish_reason == 'tool_calls':
                for tool_call in tool_calls.values():
                    try:
                        args = json.loads(tool_call['arguments']) if tool_call['arguments'] else {}
                    except json.JSONDecodeError:
                        args = {}

                    yield {
                        'type': 'tool_call',
                        'id': tool_call['id'],
                        'name': tool_call['name'],
                        'args': args,
                    }

        yield {'type': 'done'}
