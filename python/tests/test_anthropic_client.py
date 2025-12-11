import pytest
from unittest.mock import Mock, patch
from providers.anthropic_client import AnthropicClient

def test_stream_completion():
    """Test streaming completion from Anthropic."""
    # Mock the anthropic client BEFORE creating the client
    with patch('providers.anthropic_client.Anthropic') as MockAnthropic:
        mock_stream = [
            Mock(type='content_block_delta', delta=Mock(type='text_delta', text='def ')),
            Mock(type='content_block_delta', delta=Mock(type='text_delta', text='foo():')),
            Mock(type='message_stop'),
        ]
        MockAnthropic.return_value.messages.stream.return_value.__enter__.return_value = mock_stream

        client = AnthropicClient(api_key="test-key", model="claude-3-5-sonnet")

        chunks = list(client.stream_completion(
            context="# Write a function",
            prompt=None,
            tools=[]
        ))

        assert len(chunks) == 3
        assert chunks[0] == {'type': 'completion', 'content': 'def '}
        assert chunks[1] == {'type': 'completion', 'content': 'foo():'}
        assert chunks[2] == {'type': 'done'}
