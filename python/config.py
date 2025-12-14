"""Configuration management from environment variables and Lua setup."""
import os
from dataclasses import dataclass
from typing import Optional, Dict, Any


SYSTEM_PROMPT = """You are a precise code completion assistant.

CRITICAL RULES:
1. Only generate NEW code that should be inserted at the <cursor> position
2. DO NOT repeat any code that appears before or after the cursor
3. DO NOT include explanations, comments about what you're doing, or markdown
4. Generate only the exact code to insert - nothing more, nothing less
5. Match the indentation and style of the surrounding code
6. Your output must be syntactically valid code in the same language as the surrounding context
7. NEVER output JSON, function call objects, or any structured data format - only raw source code

BAD (never do this):
{"name": "some_function", "parameters": {...}}

GOOD:
some_function(arg1, arg2)

The code before and after <cursor> is provided for context only - do not regenerate it."""


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
    def from_dict(cls, config_dict: Dict[str, Any]) -> 'Config':
        """
        Load configuration from dictionary (passed from Lua setup).
        Falls back to environment variables for missing values.
        API keys always prefer environment variables for security.
        """
        # Get provider (from dict or env)
        provider = config_dict.get('provider') or os.getenv('AI_REQUEST_PROVIDER', 'anthropic')

        # Validate provider
        valid_providers = ['anthropic', 'openai', 'local']
        if provider not in valid_providers:
            raise ValueError(f"Invalid provider '{provider}'. Must be one of: {valid_providers}")

        # Get model (from dict, env, or defaults)
        model = config_dict.get('model') or os.getenv('AI_REQUEST_MODEL') or cls._default_model(provider)

        # Get timeout (from dict or env)
        timeout = config_dict.get('timeout')
        if timeout is None:
            timeout = int(os.getenv('AI_REQUEST_TIMEOUT', '30'))

        # Get max_tool_calls (from dict or env)
        max_tool_calls = config_dict.get('max_tool_calls')
        if max_tool_calls is None:
            max_tool_calls = int(os.getenv('AI_REQUEST_MAX_TOOL_CALLS', '3'))

        # Get API key - ALWAYS prefer env vars for security, only use dict as fallback
        api_key = config_dict.get('api_key')
        if not api_key:
            if provider == 'anthropic':
                api_key = os.getenv('ANTHROPIC_API_KEY')
            elif provider == 'openai':
                api_key = os.getenv('OPENAI_API_KEY')
            elif provider == 'local':
                api_key = os.getenv('AI_REQUEST_LOCAL_API_KEY', 'none')

        if not api_key and provider != 'local':
            raise ValueError(f"API key not found for provider '{provider}'. Set {provider.upper()}_API_KEY environment variable.")

        # Get base_url (from dict or env)
        base_url = config_dict.get('base_url')
        if not base_url and provider == 'local':
            base_url = os.getenv('AI_REQUEST_LOCAL_URL', 'http://localhost:11434/v1')

        return cls(
            provider=provider,
            model=model,
            api_key=api_key,
            base_url=base_url,
            timeout=timeout,
            max_tool_calls=max_tool_calls,
        )

    @classmethod
    def from_env(cls) -> 'Config':
        """Load configuration from environment variables only."""
        return cls.from_dict({})

    @staticmethod
    def _default_model(provider: str) -> str:
        """Get default model for provider."""
        defaults = {
            'anthropic': 'claude-sonnet-4.5',
            'openai': 'gpt-4',
            'local': 'deepseek-coder:6.7b',
        }
        return defaults.get(provider, 'claude-sonnet-4.5')
