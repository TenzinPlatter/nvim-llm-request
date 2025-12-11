import os
import pytest
from config import Config

def test_load_from_env(monkeypatch):
    """Test loading configuration from environment variables."""
    monkeypatch.setenv('AI_REQUEST_PROVIDER', 'anthropic')
    monkeypatch.setenv('AI_REQUEST_MODEL', 'claude-sonnet-4.5')
    monkeypatch.setenv('ANTHROPIC_API_KEY', 'sk-test-key')

    config = Config.from_env()

    assert config.provider == 'anthropic'
    assert config.model == 'claude-sonnet-4.5'
    assert config.api_key == 'sk-test-key'
    assert config.timeout == 30  # default

def test_missing_api_key(monkeypatch):
    """Test error when API key missing."""
    monkeypatch.setenv('AI_REQUEST_PROVIDER', 'openai')
    # Don't set OPENAI_API_KEY

    with pytest.raises(ValueError, match="API key not found"):
        Config.from_env()

def test_local_provider(monkeypatch):
    """Test local provider with optional API key."""
    monkeypatch.setenv('AI_REQUEST_PROVIDER', 'local')

    config = Config.from_env()

    assert config.provider == 'local'
    assert config.api_key == 'none'
    assert config.model == 'deepseek-coder:6.7b'

def test_default_model_selection(monkeypatch):
    """Test default model is selected when not specified."""
    monkeypatch.setenv('AI_REQUEST_PROVIDER', 'openai')
    monkeypatch.setenv('OPENAI_API_KEY', 'sk-test')
    # Don't set AI_REQUEST_MODEL

    config = Config.from_env()

    assert config.model == 'gpt-4'

def test_invalid_timeout_raises_error(monkeypatch):
    """Test that invalid timeout raises ValueError."""
    monkeypatch.setenv('AI_REQUEST_PROVIDER', 'anthropic')
    monkeypatch.setenv('ANTHROPIC_API_KEY', 'sk-test')
    monkeypatch.setenv('AI_REQUEST_TIMEOUT', 'not-a-number')

    with pytest.raises(ValueError):
        Config.from_env()

def test_unknown_provider_raises_error(monkeypatch):
    """Test that unknown provider raises ValueError."""
    monkeypatch.setenv('AI_REQUEST_PROVIDER', 'unknown')

    with pytest.raises(ValueError, match="Unknown provider"):
        Config.from_env()
