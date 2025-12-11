import os
import pytest
from config import Config

def test_load_from_env():
    """Test loading configuration from environment variables."""
    os.environ['AI_REQUEST_PROVIDER'] = 'anthropic'
    os.environ['AI_REQUEST_MODEL'] = 'claude-sonnet-4.5'
    os.environ['ANTHROPIC_API_KEY'] = 'sk-test-key'

    config = Config.from_env()

    assert config.provider == 'anthropic'
    assert config.model == 'claude-sonnet-4.5'
    assert config.api_key == 'sk-test-key'
    assert config.timeout == 30  # default

def test_missing_api_key():
    """Test error when API key missing."""
    os.environ.pop('OPENAI_API_KEY', None)
    os.environ.pop('ANTHROPIC_API_KEY', None)
    os.environ['AI_REQUEST_PROVIDER'] = 'openai'

    with pytest.raises(ValueError, match="API key not found"):
        Config.from_env()
