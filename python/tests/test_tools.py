from tools import get_tool_definitions

def test_get_tool_definitions():
    """Test tool definitions are properly formatted."""
    tools = get_tool_definitions()

    assert len(tools) == 1
    assert tools[0]['type'] == 'function'
    assert tools[0]['function']['name'] == 'get_implementation'
    assert 'function_name' in tools[0]['function']['parameters']['properties']
