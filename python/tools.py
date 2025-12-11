"""Tool definitions for LLM function calling."""
from typing import List, Dict, Any


def get_tool_definitions() -> List[Dict[str, Any]]:
    """
    Get tool definitions for function calling.

    Returns OpenAI-compatible tool definition format
    (also works with Anthropic after conversion).
    """
    return [
        {
            "type": "function",
            "function": {
                "name": "get_implementation",
                "description": "Retrieve the full implementation of a function or class from the codebase.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "function_name": {
                            "type": "string",
                            "description": "Name of the function or class to retrieve (e.g., 'validateEmail' or 'UserService')"
                        }
                    },
                    "required": ["function_name"]
                }
            }
        }
    ]


def convert_tools_for_anthropic(tools: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Convert OpenAI tool format to Anthropic format.

    Anthropic expects:
    {
      "name": "...",
      "description": "...",
      "input_schema": {...}
    }
    """
    anthropic_tools = []
    for tool in tools:
        if tool['type'] == 'function':
            func = tool['function']
            anthropic_tools.append({
                "name": func['name'],
                "description": func['description'],
                "input_schema": func['parameters']
            })
    return anthropic_tools
