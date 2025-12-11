import pytest
from unittest.mock import Mock, patch

def test_stream_completion():
    """Test streaming completion from OpenAI."""
    with patch('providers.openai_client.OpenAI') as MockOpenAI:
        # Import after patching
        from providers.openai_client import OpenAIClient

        # Mock streaming response
        mock_chunks = [
            Mock(choices=[Mock(delta=Mock(content='def ', tool_calls=None))]),
            Mock(choices=[Mock(delta=Mock(content='foo():', tool_calls=None))]),
            Mock(choices=[Mock(delta=Mock(content=None, tool_calls=None))]),  # done
        ]
        MockOpenAI.return_value.chat.completions.create.return_value = mock_chunks

        client = OpenAIClient(api_key="test-key", model="gpt-4")
        chunks = list(client.stream_completion(
            context="# Write a function",
            prompt=None,
            tools=[]
        ))

        assert len(chunks) == 3
        assert chunks[0] == {'type': 'completion', 'content': 'def '}
        assert chunks[1] == {'type': 'completion', 'content': 'foo():'}
        assert chunks[2] == {'type': 'done'}
