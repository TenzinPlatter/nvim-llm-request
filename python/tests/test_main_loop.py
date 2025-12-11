import json
from unittest.mock import patch, Mock
from main import process_request

def test_process_completion_request():
    """Test processing a completion request."""
    request = {
        "type": "complete",
        "context": "def foo():\n    # TODO",
        "prompt": "implement factorial",
        "config": {
            "provider": "anthropic",
            "model": "claude-sonnet-4.5",
            "api_key": "test-key"
        }
    }

    with patch('main.AnthropicClient') as MockClient:
        mock_instance = MockClient.return_value
        mock_instance.stream_completion.return_value = [
            {"type": "completion", "content": "return n * factorial(n-1)"},
            {"type": "done"}
        ]

        responses = list(process_request(request))

        assert len(responses) == 2
        assert responses[0]['type'] == 'completion'
        assert responses[1]['type'] == 'done'
