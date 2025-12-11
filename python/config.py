"""Configuration management from environment variables."""
import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class Config:
    """Configuration for AI request backend."""
    provider: str  # anthropic, openai, local
    model: str
    api_key: str
    base_url: Optional[str] = None  # For local models
    timeout: int = 30
    max_tool_calls: int = 3

    @classmethod
    def from_env(cls) -> 'Config':
        """Load configuration from environment variables."""
        provider = os.getenv('AI_REQUEST_PROVIDER', 'anthropic')
        model = os.getenv('AI_REQUEST_MODEL', cls._default_model(provider))
        timeout = int(os.getenv('AI_REQUEST_TIMEOUT', '30'))
        max_tool_calls = int(os.getenv('AI_REQUEST_MAX_TOOL_CALLS', '3'))

        # Get API key based on provider
        if provider == 'anthropic':
            api_key = os.getenv('ANTHROPIC_API_KEY')
        elif provider == 'openai':
            api_key = os.getenv('OPENAI_API_KEY')
        elif provider == 'local':
            api_key = os.getenv('AI_REQUEST_LOCAL_API_KEY', 'none')  # Local might not need key
        else:
            raise ValueError(f"Unknown provider: {provider}")

        if not api_key and provider != 'local':
            raise ValueError(f"API key not found for provider {provider}")

        base_url = os.getenv('AI_REQUEST_LOCAL_URL') if provider == 'local' else None

        return cls(
            provider=provider,
            model=model,
            api_key=api_key,
            base_url=base_url,
            timeout=timeout,
            max_tool_calls=max_tool_calls,
        )

    @staticmethod
    def _default_model(provider: str) -> str:
        """Get default model for provider."""
        defaults = {
            'anthropic': 'claude-sonnet-4.5',
            'openai': 'gpt-4',
            'local': 'deepseek-coder:6.7b',
        }
        return defaults.get(provider, 'claude-sonnet-4.5')
