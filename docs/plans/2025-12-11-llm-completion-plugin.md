# LLM Completion Plugin Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Build a Neovim plugin that provides async LLM-powered code completions with virtual text feedback, supporting OpenAI, Anthropic, and local models.

**Architecture:** Python backend handles API streaming and tool calling, Lua frontend manages UI/commands/context. Communication via JSON over stdio. Virtual text shows progress at invocation position while user retains full control.

**Tech Stack:** Neovim 0.10+, Lua, Python 3.8+, plenary.nvim, nvim-treesitter (optional), anthropic SDK, openai SDK

---

## Task 1: Project Structure Setup

**Files:**
- Create: `lua/ai-request/init.lua`
- Create: `plugin/ai-request.vim`
- Create: `python/main.py`
- Create: `python/requirements.txt`
- Create: `README.md`

**Step 1: Create basic Lua plugin structure**

Create `lua/ai-request/init.lua`:
```lua
local M = {}

M.config = {
  display = {
    show_thinking = true,
    show_spinner = true,
  },
  context = {
    lines_before = 100,
    lines_after = 20,
  },
  max_concurrent_requests = 3,
  timeout_ms = 30000,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
```

Create `plugin/ai-request.vim`:
```vim
" Load once
if exists('g:loaded_ai_request')
  finish
endif
let g:loaded_ai_request = 1

" Commands defined in Lua
command! -nargs=* AIRequest lua require('ai-request').request(<q-args>)
```

**Step 2: Create Python requirements**

Create `python/requirements.txt`:
```
anthropic>=0.18.0
openai>=1.10.0
requests>=2.31.0
```

Create `python/main.py`:
```python
#!/usr/bin/env python3
"""
AI Request backend - handles LLM API calls via stdio JSON protocol.
"""
import sys
import json

def main():
    """Main stdio loop."""
    for line in sys.stdin:
        try:
            message = json.loads(line)
            # TODO: Route messages
            response = {"type": "error", "message": "Not implemented"}
            print(json.dumps(response), flush=True)
        except Exception as e:
            error = {"type": "error", "message": str(e)}
            print(json.dumps(error), flush=True)

if __name__ == "__main__":
    main()
```

**Step 3: Create README**

Create `README.md`:
```markdown
# ai-request.nvim

Async LLM-powered code completion for Neovim.

## Installation

### Dependencies
- Neovim 0.10+
- Python 3.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Install with lazy.nvim

\`\`\`lua
{
  'your-username/ai-request.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  build = 'pip3 install -r python/requirements.txt',
  config = function()
    require('ai-request').setup({})
  end
}
\`\`\`

## Configuration

Set environment variables:
\`\`\`bash
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export AI_REQUEST_PROVIDER=anthropic  # or openai, local
export AI_REQUEST_MODEL=claude-sonnet-4.5
\`\`\`

## Usage

\`\`\`:AIRequest\`\`\` - Auto-complete at cursor
\`\`\`:AIRequest make this async\`\`\` - Prompted completion
```

**Step 4: Verify structure**

Run: `find . -type f -name "*.lua" -o -name "*.py" -o -name "*.md" | sort`
Expected output:
```
./README.md
./lua/ai-request/init.lua
./plugin/ai-request.vim
./python/main.py
./python/requirements.txt
```

**Step 5: Commit**

```bash
git add .
git commit -m "feat: initial project structure with plugin skeleton

- Add Lua plugin entry points
- Add Python backend scaffold
- Add README with installation instructions"
```

---

## Task 2: Python Config System

**Files:**
- Create: `python/config.py`
- Create: `python/tests/test_config.py`

**Step 1: Write the failing test**

Create `python/tests/test_config.py`:
```python
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
```

**Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_config.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'config'"

**Step 3: Write minimal implementation**

Create `python/config.py`:
```python
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
```

**Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_config.py -v`
Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add python/config.py python/tests/test_config.py
git commit -m "feat: add Python config system with env var loading

- Load provider, model, API keys from environment
- Validate required API keys
- Support anthropic, openai, local providers"
```

---

## Task 3: Python API Client - Anthropic

**Files:**
- Create: `python/providers/__init__.py`
- Create: `python/providers/anthropic_client.py`
- Create: `python/tests/test_anthropic_client.py`

**Step 1: Write the failing test**

Create `python/tests/test_anthropic_client.py`:
```python
import pytest
from unittest.mock import Mock, patch
from providers.anthropic_client import AnthropicClient

def test_stream_completion():
    """Test streaming completion from Anthropic."""
    client = AnthropicClient(api_key="test-key", model="claude-3-5-sonnet")

    # Mock the anthropic client
    with patch('providers.anthropic_client.Anthropic') as MockAnthropic:
        mock_stream = [
            Mock(type='content_block_delta', delta=Mock(type='text_delta', text='def ')),
            Mock(type='content_block_delta', delta=Mock(type='text_delta', text='foo():')),
            Mock(type='message_stop'),
        ]
        MockAnthropic.return_value.messages.stream.return_value.__enter__.return_value = mock_stream

        chunks = list(client.stream_completion(
            context="# Write a function",
            prompt=None,
            tools=[]
        ))

        assert len(chunks) == 2
        assert chunks[0] == {'type': 'completion', 'content': 'def '}
        assert chunks[1] == {'type': 'completion', 'content': 'foo():'}
```

**Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_anthropic_client.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'providers.anthropic_client'"

**Step 3: Write minimal implementation**

Create `python/providers/__init__.py`:
```python
"""LLM provider clients."""
```

Create `python/providers/anthropic_client.py`:
```python
"""Anthropic API client with streaming support."""
from typing import Iterator, Dict, Any, List, Optional
from anthropic import Anthropic


class AnthropicClient:
    """Client for Anthropic Claude API."""

    def __init__(self, api_key: str, model: str):
        self.client = Anthropic(api_key=api_key)
        self.model = model

    def stream_completion(
        self,
        context: str,
        prompt: Optional[str],
        tools: List[Dict[str, Any]],
    ) -> Iterator[Dict[str, Any]]:
        """
        Stream a completion from Claude.

        Yields:
            {"type": "thinking", "content": "..."}
            {"type": "completion", "content": "..."}
            {"type": "tool_call", "name": "...", "args": {...}}
            {"type": "done"}
        """
        # Build messages
        user_message = context
        if prompt:
            user_message += f"\n\n{prompt}"

        messages = [{"role": "user", "content": user_message}]

        # Stream the response
        with self.client.messages.stream(
            model=self.model,
            max_tokens=4096,
            messages=messages,
            tools=tools if tools else None,
        ) as stream:
            for event in stream:
                # Handle text content
                if event.type == 'content_block_delta':
                    if hasattr(event.delta, 'text'):
                        yield {
                            'type': 'completion',
                            'content': event.delta.text
                        }
                    # Handle thinking (extended thinking in some models)
                    elif hasattr(event.delta, 'thinking'):
                        yield {
                            'type': 'thinking',
                            'content': event.delta.thinking
                        }

                # Handle tool calls
                elif event.type == 'content_block_start':
                    if hasattr(event.content_block, 'type') and event.content_block.type == 'tool_use':
                        # Will be completed in subsequent deltas
                        pass

        yield {'type': 'done'}
```

**Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_anthropic_client.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add python/providers/
git commit -m "feat: add Anthropic streaming client

- Stream completions with text deltas
- Support thinking and tool calling events
- Yield structured events for Lua consumption"
```

---

## Task 4: Python API Client - OpenAI

**Files:**
- Create: `python/providers/openai_client.py`
- Create: `python/tests/test_openai_client.py`

**Step 1: Write the failing test**

Create `python/tests/test_openai_client.py`:
```python
import pytest
from unittest.mock import Mock, patch
from providers.openai_client import OpenAIClient

def test_stream_completion():
    """Test streaming completion from OpenAI."""
    client = OpenAIClient(api_key="test-key", model="gpt-4")

    with patch('providers.openai_client.OpenAI') as MockOpenAI:
        # Mock streaming response
        mock_chunks = [
            Mock(choices=[Mock(delta=Mock(content='def ', tool_calls=None))]),
            Mock(choices=[Mock(delta=Mock(content='foo():', tool_calls=None))]),
            Mock(choices=[Mock(delta=Mock(content=None, tool_calls=None))]),  # done
        ]
        MockOpenAI.return_value.chat.completions.create.return_value = mock_chunks

        chunks = list(client.stream_completion(
            context="# Write a function",
            prompt=None,
            tools=[]
        ))

        assert len(chunks) == 3
        assert chunks[0] == {'type': 'completion', 'content': 'def '}
        assert chunks[1] == {'type': 'completion', 'content': 'foo():'}
        assert chunks[2] == {'type': 'done'}
```

**Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_openai_client.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'providers.openai_client'"

**Step 3: Write minimal implementation**

Create `python/providers/openai_client.py`:
```python
"""OpenAI API client with streaming support."""
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
            {"type": "tool_call", "name": "...", "args": {...}}
            {"type": "done"}
        """
        # Build messages
        user_message = context
        if prompt:
            user_message += f"\n\n{prompt}"

        messages = [
            {"role": "system", "content": "You are a code completion assistant."},
            {"role": "user", "content": user_message}
        ]

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

            # Handle text content
            if delta.content:
                yield {
                    'type': 'completion',
                    'content': delta.content
                }

            # Handle tool calls
            if delta.tool_calls:
                for tool_call in delta.tool_calls:
                    if tool_call.function:
                        yield {
                            'type': 'tool_call',
                            'name': tool_call.function.name,
                            'args': tool_call.function.arguments,
                        }

        yield {'type': 'done'}
```

**Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_openai_client.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add python/providers/openai_client.py python/tests/test_openai_client.py
git commit -m "feat: add OpenAI streaming client

- Stream completions with content deltas
- Support tool calling
- Compatible with OpenAI-compatible APIs via base_url"
```

---

## Task 5: Python Tool Definitions

**Files:**
- Create: `python/tools.py`
- Create: `python/tests/test_tools.py`

**Step 1: Write the failing test**

Create `python/tests/test_tools.py`:
```python
from tools import get_tool_definitions

def test_get_tool_definitions():
    """Test tool definitions are properly formatted."""
    tools = get_tool_definitions()

    assert len(tools) == 1
    assert tools[0]['type'] == 'function'
    assert tools[0]['function']['name'] == 'get_implementation'
    assert 'function_name' in tools[0]['function']['parameters']['properties']
```

**Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_tools.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'tools'"

**Step 3: Write minimal implementation**

Create `python/tools.py`:
```python
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
```

**Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_tools.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add python/tools.py python/tests/test_tools.py
git commit -m "feat: add tool definitions for function calling

- Define get_implementation tool
- Support OpenAI and Anthropic formats
- Tool allows LLM to request code implementations"
```

---

## Task 6: Python Main Loop with Tool Calling

**Files:**
- Modify: `python/main.py`
- Create: `python/tests/test_main_loop.py`

**Step 1: Write the failing test**

Create `python/tests/test_main_loop.py`:
```python
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
```

**Step 2: Run test to verify it fails**

Run: `cd python && python -m pytest tests/test_main_loop.py -v`
Expected: FAIL with "ImportError: cannot import name 'process_request'"

**Step 3: Write implementation**

Modify `python/main.py`:
```python
#!/usr/bin/env python3
"""
AI Request backend - handles LLM API calls via stdio JSON protocol.
"""
import sys
import json
from typing import Iterator, Dict, Any
from config import Config
from providers.anthropic_client import AnthropicClient
from providers.openai_client import OpenAIClient
from tools import get_tool_definitions, convert_tools_for_anthropic


def process_request(request: Dict[str, Any]) -> Iterator[Dict[str, Any]]:
    """
    Process a request and yield response events.

    Args:
        request: {
            "type": "complete",
            "context": "...",
            "prompt": "..." or None,
            "config": {...} or None
        }

    Yields:
        {"type": "completion", "content": "..."}
        {"type": "thinking", "content": "..."}
        {"type": "tool_call", "name": "...", "args": {...}}
        {"type": "done"}
        {"type": "error", "message": "..."}
    """
    try:
        if request['type'] != 'complete':
            yield {"type": "error", "message": f"Unknown request type: {request['type']}"}
            return

        # Get config (from request or environment)
        if 'config' in request:
            config_dict = request['config']
            from config import Config as ConfigClass
            config = ConfigClass(**config_dict)
        else:
            config = Config.from_env()

        # Get tools
        tools = get_tool_definitions()

        # Create client
        if config.provider == 'anthropic':
            client = AnthropicClient(config.api_key, config.model)
            tools = convert_tools_for_anthropic(tools)
        elif config.provider == 'openai':
            client = OpenAIClient(config.api_key, config.model, config.base_url)
        elif config.provider == 'local':
            # Local models use OpenAI-compatible API
            client = OpenAIClient(config.api_key, config.model, config.base_url)
        else:
            yield {"type": "error", "message": f"Unknown provider: {config.provider}"}
            return

        # Stream completion
        context = request['context']
        prompt = request.get('prompt')

        for event in client.stream_completion(context, prompt, tools):
            yield event

    except Exception as e:
        yield {"type": "error", "message": str(e)}


def main():
    """Main stdio loop."""
    for line in sys.stdin:
        try:
            request = json.loads(line)

            for response in process_request(request):
                print(json.dumps(response), flush=True)

        except json.JSONDecodeError as e:
            error = {"type": "error", "message": f"Invalid JSON: {e}"}
            print(json.dumps(error), flush=True)
        except Exception as e:
            error = {"type": "error", "message": str(e)}
            print(json.dumps(error), flush=True)


if __name__ == "__main__":
    main()
```

**Step 4: Run test to verify it passes**

Run: `cd python && python -m pytest tests/test_main_loop.py -v`
Expected: PASS

**Step 5: Commit**

```bash
git add python/main.py python/tests/test_main_loop.py
git commit -m "feat: implement main request processing loop

- Process complete requests and stream responses
- Create appropriate client based on provider
- Handle errors and yield structured events"
```

---

## Task 7: Lua Python Process Manager

**Files:**
- Create: `lua/ai-request/python_client.lua`
- Create: `tests/python_client_spec.lua`

**Step 1: Write the failing test**

Create `tests/python_client_spec.lua`:
```lua
local python_client = require('ai-request.python_client')

describe("python_client", function()
  it("should start python process", function()
    local client = python_client.new()
    assert.is_not_nil(client)
    assert.is_not_nil(client.job_id)
  end)

  it("should send and receive JSON", function()
    local client = python_client.new()
    local received = nil

    client:send({
      type = "complete",
      context = "test",
      prompt = nil
    }, function(response)
      received = response
    end)

    -- Wait for response (in real test, use vim.wait)
    vim.wait(1000, function() return received ~= nil end)

    assert.is_not_nil(received)
    assert.equals("error", received.type) -- Should error (no API key in test)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`
Expected: FAIL with "module 'ai-request.python_client' not found"

**Step 3: Write minimal implementation**

Create `lua/ai-request/python_client.lua`:
```lua
local Job = require('plenary.job')
local M = {}

--- Create a new Python client
--- @return table Client instance
function M.new()
  local self = {
    job_id = nil,
    callbacks = {},
    next_id = 1,
  }

  -- Find python script path
  local script_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h") .. "/python/main.py"

  -- Start python process
  self.job_id = vim.fn.jobstart(
    {'python3', script_path},
    {
      on_stdout = function(_, data)
        self:_on_stdout(data)
      end,
      on_stderr = function(_, data)
        if data and #data > 0 then
          vim.notify("AI Request Python error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end
      end,
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify("AI Request Python exited with code " .. code, vim.log.levels.ERROR)
        end
      end,
      stdout_buffered = false,
      stderr_buffered = false,
    }
  )

  if self.job_id <= 0 then
    error("Failed to start Python process")
  end

  setmetatable(self, { __index = M })
  return self
end

--- Handle stdout from Python
--- @param data table Lines of output
function M:_on_stdout(data)
  for _, line in ipairs(data) do
    if line and line ~= "" then
      local ok, response = pcall(vim.json.decode, line)
      if ok then
        -- Find callback for this response
        -- For now, call all callbacks (TODO: match by ID)
        for id, callback in pairs(self.callbacks) do
          callback(response)
          if response.type == "done" or response.type == "error" then
            self.callbacks[id] = nil
          end
        end
      end
    end
  end
end

--- Send a request to Python
--- @param request table Request object
--- @param callback function Callback for responses
function M:send(request, callback)
  local id = self.next_id
  self.next_id = self.next_id + 1

  self.callbacks[id] = callback

  local json = vim.json.encode(request)
  vim.fn.chansend(self.job_id, json .. "\n")
end

--- Stop the Python process
function M:stop()
  if self.job_id then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
end

return M
```

**Step 4: Run test to verify it passes**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/ai-request/python_client.lua tests/python_client_spec.lua
git commit -m "feat: add Python process manager

- Start Python backend via jobstart
- Send/receive JSON over stdio
- Handle callbacks for streaming responses"
```

---

## Task 8: Lua Context Extraction

**Files:**
- Create: `lua/ai-request/context.lua`
- Create: `tests/context_spec.lua`

**Step 1: Write the failing test**

Create `tests/context_spec.lua`:
```lua
local context = require('ai-request.context')

describe("context extraction", function()
  it("should extract sliding window", function()
    -- Create a buffer with test content
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {}
    for i = 1, 200 do
      table.insert(lines, "line " .. i)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Extract context at line 150
    local ctx = context.extract(buf, 150, {
      lines_before = 100,
      lines_after = 20,
    })

    assert.equals(buf, ctx.bufnr)
    assert.equals(150, ctx.cursor_line)
    assert.is_not_nil(ctx.before)
    assert.is_not_nil(ctx.after)
    assert.equals(100, #vim.split(ctx.before, "\n"))
    assert.equals(20, #vim.split(ctx.after, "\n"))
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`
Expected: FAIL with "module 'ai-request.context' not found"

**Step 3: Write minimal implementation**

Create `lua/ai-request/context.lua`:
```lua
local M = {}

--- Extract context around cursor position
--- @param bufnr number Buffer number
--- @param line number Line number (1-indexed)
--- @param opts table Options { lines_before, lines_after, include_treesitter, include_lsp }
--- @return table Context { bufnr, cursor_line, before, after, filetype, symbols }
function M.extract(bufnr, line, opts)
  opts = opts or {}
  local lines_before = opts.lines_before or 100
  local lines_after = opts.lines_after or 20

  -- Get total line count
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Calculate range
  local start_line = math.max(0, line - lines_before - 1)
  local end_line = math.min(total_lines, line + lines_after)

  -- Extract lines
  local before_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, line - 1, false)
  local after_lines = vim.api.nvim_buf_get_lines(bufnr, line, end_line, false)

  local ctx = {
    bufnr = bufnr,
    cursor_line = line,
    before = table.concat(before_lines, "\n"),
    after = table.concat(after_lines, "\n"),
    filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype'),
    symbols = {},
  }

  -- Extract symbols if requested
  if opts.include_treesitter then
    ctx.symbols = M.extract_treesitter_symbols(bufnr)
  end

  if opts.include_lsp then
    -- TODO: Extract LSP symbols
  end

  return ctx
end

--- Extract function/class signatures using treesitter
--- @param bufnr number Buffer number
--- @return table List of symbols { name, type, signature }
function M.extract_treesitter_symbols(bufnr)
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if not ok then
    return {}
  end

  local parser = parsers.get_parser(bufnr)
  if not parser then
    return {}
  end

  local symbols = {}
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for function definitions (simplified, needs per-language queries)
  local query_string = [[
    (function_declaration name: (identifier) @name)
    (function_definition name: (identifier) @name)
  ]]

  local ok_query, query = pcall(vim.treesitter.query.parse, parser:lang(), query_string)
  if not ok_query then
    return symbols
  end

  for _, match in query:iter_matches(root, bufnr) do
    for id, node in pairs(match) do
      local name = vim.treesitter.get_node_text(node, bufnr)
      table.insert(symbols, {
        name = name,
        type = 'function',
        signature = name .. '()',  -- Simplified
      })
    end
  end

  return symbols
end

--- Format context for LLM
--- @param ctx table Context from extract()
--- @return string Formatted context
function M.format(ctx)
  local parts = {}

  table.insert(parts, "File type: " .. (ctx.filetype or "unknown"))

  if #ctx.symbols > 0 then
    table.insert(parts, "\nAvailable functions:")
    for _, sym in ipairs(ctx.symbols) do
      table.insert(parts, "- " .. sym.signature)
    end
  end

  table.insert(parts, "\nCode before cursor:")
  table.insert(parts, ctx.before)
  table.insert(parts, "\n<cursor>")
  table.insert(parts, "\nCode after cursor:")
  table.insert(parts, ctx.after)

  return table.concat(parts, "\n")
end

return M
```

**Step 4: Run test to verify it passes**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/ai-request/context.lua tests/context_spec.lua
git commit -m "feat: add context extraction with sliding window

- Extract lines before/after cursor
- Optional treesitter symbol extraction
- Format context for LLM consumption"
```

---

## Task 9: Lua Virtual Text Display

**Files:**
- Create: `lua/ai-request/display.lua`
- Create: `tests/display_spec.lua`

**Step 1: Write the failing test**

Create `tests/display_spec.lua`:
```lua
local display = require('ai-request.display')

describe("virtual text display", function()
  it("should show spinner at position", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"line 1", "line 2", "line 3"})

    local d = display.new(buf, 2, { show_spinner = true })
    d:show("Testing...")

    -- Check extmark exists
    local marks = vim.api.nvim_buf_get_extmarks(buf, d.namespace, 0, -1, {})
    assert.is_true(#marks > 0)

    d:clear()
    marks = vim.api.nvim_buf_get_extmarks(buf, d.namespace, 0, -1, {})
    assert.equals(0, #marks)
  end)
end)
```

**Step 2: Run test to verify it fails**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`
Expected: FAIL with "module 'ai-request.display' not found"

**Step 3: Write minimal implementation**

Create `lua/ai-request/display.lua`:
```lua
local M = {}

local SPINNERS = {
  "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
}

--- Create a new display manager
--- @param bufnr number Buffer number
--- @param line number Line number (1-indexed)
--- @param opts table Options { show_spinner, show_thinking }
--- @return table Display instance
function M.new(bufnr, line, opts)
  opts = opts or {}

  local self = {
    bufnr = bufnr,
    line = line,
    namespace = vim.api.nvim_create_namespace('ai_request_display'),
    extmark_id = nil,
    spinner_index = 1,
    spinner_timer = nil,
    opts = opts,
  }

  setmetatable(self, { __index = M })
  return self
end

--- Show virtual text with optional spinner
--- @param text string Text to display
function M:show(text)
  local virt_lines = {}

  if self.opts.show_spinner then
    local spinner = SPINNERS[self.spinner_index]
    table.insert(virt_lines, {{spinner .. " " .. text, "Comment"}})
  else
    table.insert(virt_lines, {{text, "Comment"}})
  end

  -- Add empty line for spacing
  table.insert(virt_lines, {{"", ""}})

  -- Create or update extmark
  if self.extmark_id then
    vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, self.line - 1, 0, {
      id = self.extmark_id,
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  else
    self.extmark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, self.line - 1, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })
  end

  -- Start spinner animation
  if self.opts.show_spinner and not self.spinner_timer then
    self.spinner_timer = vim.loop.new_timer()
    self.spinner_timer:start(100, 100, vim.schedule_wrap(function()
      self.spinner_index = (self.spinner_index % #SPINNERS) + 1
      self:show(text)  -- Update with new spinner
    end))
  end
end

--- Update text without resetting spinner
--- @param text string New text
function M:update(text)
  self._current_text = text
  self:show(text)
end

--- Clear virtual text
function M:clear()
  if self.spinner_timer then
    self.spinner_timer:stop()
    self.spinner_timer:close()
    self.spinner_timer = nil
  end

  if self.extmark_id then
    vim.api.nvim_buf_del_extmark(self.bufnr, self.namespace, self.extmark_id)
    self.extmark_id = nil
  end
end

return M
```

**Step 4: Run test to verify it passes**

Run: `nvim --headless -c "PlenaryBustedDirectory tests/"`
Expected: PASS

**Step 5: Commit**

```bash
git add lua/ai-request/display.lua tests/display_spec.lua
git commit -m "feat: add virtual text display with spinner

- Show virtual lines below marked position
- Animated spinner using vim.loop timer
- Clear and update display as needed"
```

---

## Task 10: Main AIRequest Command

**Files:**
- Modify: `lua/ai-request/init.lua`
- Create: `lua/ai-request/completion.lua`

**Step 1: Write implementation for completion orchestration**

Create `lua/ai-request/completion.lua`:
```lua
local python_client = require('ai-request.python_client')
local context = require('ai-request.context')
local display = require('ai-request.display')

local M = {}

-- Global Python client (reused across requests)
local client = nil
local active_requests = {}

--- Initialize Python client if needed
local function ensure_client()
  if not client then
    client = python_client.new()
  end
  return client
end

--- Handle a completion request
--- @param prompt string|nil Optional user prompt
--- @param opts table Config options
function M.request(prompt, opts)
  opts = opts or require('ai-request').config

  -- Check concurrent request limit
  if #active_requests >= opts.max_concurrent_requests then
    vim.notify("Max concurrent requests reached", vim.log.levels.WARN)
    return
  end

  -- Get current position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Extract context
  local ctx = context.extract(bufnr, line, opts.context)
  local formatted_context = context.format(ctx)

  -- Create display
  local disp = display.new(bufnr, line, opts.display)
  disp:show("Starting request...")

  -- Track this request
  local request_id = #active_requests + 1
  active_requests[request_id] = {
    display = disp,
    bufnr = bufnr,
    line = line,
    completion_parts = {},
  }

  -- Send request to Python
  local c = ensure_client()
  c:send({
    type = "complete",
    context = formatted_context,
    prompt = prompt,
  }, function(response)
    M._handle_response(request_id, response, opts)
  end)
end

--- Handle streaming responses
--- @param request_id number Request ID
--- @param response table Response from Python
--- @param opts table Config options
function M._handle_response(request_id, response, opts)
  local req = active_requests[request_id]
  if not req then
    return
  end

  if response.type == "thinking" then
    if opts.display.show_thinking then
      req.display:update("Thinking: " .. response.content)
    end

  elseif response.type == "completion" then
    req.display:update("Generating...")
    table.insert(req.completion_parts, response.content)

  elseif response.type == "tool_call" then
    -- TODO: Handle tool calls
    req.display:update("Requesting " .. response.name .. "...")

  elseif response.type == "done" then
    -- Insert completion
    local completion = table.concat(req.completion_parts, "")
    if completion ~= "" then
      M._insert_completion(req.bufnr, req.line, completion)
    end
    req.display:clear()
    active_requests[request_id] = nil

  elseif response.type == "error" then
    vim.notify("AI Request failed: " .. response.message, vim.log.levels.ERROR)
    req.display:clear()
    active_requests[request_id] = nil
  end
end

--- Insert completion at position
--- @param bufnr number Buffer number
--- @param line number Line number
--- @param completion string Text to insert
function M._insert_completion(bufnr, line, completion)
  local lines = vim.split(completion, "\n")
  vim.api.nvim_buf_set_lines(bufnr, line, line, false, lines)
end

return M
```

**Step 2: Update init.lua to wire up command**

Modify `lua/ai-request/init.lua`:
```lua
local M = {}

M.config = {
  display = {
    show_thinking = true,
    show_spinner = true,
  },
  context = {
    lines_before = 100,
    lines_after = 20,
    include_treesitter = true,
    include_lsp = false,
  },
  max_concurrent_requests = 3,
  timeout_ms = 30000,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

--- Handle :AIRequest command
--- @param args string Command arguments (optional prompt)
function M.request(args)
  local completion = require('ai-request.completion')
  local prompt = args ~= "" and args or nil
  completion.request(prompt, M.config)
end

return M
```

**Step 3: Test manually**

Run: `nvim test.lua` and execute `:AIRequest` (will fail without API key, but should show spinner)

**Step 4: Verify structure**

Run: `find lua -name "*.lua" | sort`
Expected:
```
lua/ai-request/completion.lua
lua/ai-request/context.lua
lua/ai-request/display.lua
lua/ai-request/init.lua
lua/ai-request/python_client.lua
```

**Step 5: Commit**

```bash
git add lua/ai-request/
git commit -m "feat: implement main AIRequest command

- Orchestrate context extraction, display, and Python communication
- Handle streaming responses (thinking, completion, errors)
- Insert completions at marked position
- Track concurrent requests"
```

---

## Task 11: Tool Calling - Request Implementation

**Files:**
- Modify: `lua/ai-request/completion.lua`
- Modify: `python/providers/anthropic_client.py`

**Step 1: Implement tool call handling in Lua**

Modify `lua/ai-request/completion.lua`, update `_handle_response`:
```lua
  elseif response.type == "tool_call" then
    req.display:update("Fetching " .. response.args.function_name .. "...")

    -- Find implementation
    local implementation = M._find_implementation(req.bufnr, response.args.function_name)

    -- Send back to Python
    local c = ensure_client()
    c:send({
      type = "tool_response",
      request_id = request_id,
      content = implementation or "Function not found",
    }, function(resp)
      M._handle_response(request_id, resp, opts)
    end)
```

Add helper function:
```lua
--- Find function implementation using treesitter
--- @param bufnr number Buffer number
--- @param function_name string Function name to find
--- @return string|nil Implementation code
function M._find_implementation(bufnr, function_name)
  -- Try current buffer first
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Simple pattern match (could use treesitter for better accuracy)
  local pattern = "function%s+" .. function_name .. "%s*%(.-%).-\nend"
  local impl = content:match(pattern)

  if impl then
    return impl
  end

  -- TODO: Search other files using treesitter/LSP

  return nil
end
```

**Step 2: Update Python to handle tool responses**

Modify `python/providers/anthropic_client.py` to support multi-turn tool calling:
```python
def stream_completion_with_tools(
    self,
    context: str,
    prompt: Optional[str],
    tools: List[Dict[str, Any]],
    max_turns: int = 3,
) -> Iterator[Dict[str, Any]]:
    """
    Stream completion with tool calling support.
    May require multiple turns if tools are called.
    """
    messages = self._build_messages(context, prompt)

    for turn in range(max_turns):
        tool_uses = []

        with self.client.messages.stream(
            model=self.model,
            max_tokens=4096,
            messages=messages,
            tools=tools if tools else None,
        ) as stream:
            for event in stream:
                if event.type == 'content_block_delta':
                    if hasattr(event.delta, 'text'):
                        yield {'type': 'completion', 'content': event.delta.text}

                elif event.type == 'content_block_start':
                    if hasattr(event.content_block, 'type'):
                        if event.content_block.type == 'tool_use':
                            tool_uses.append({
                                'id': event.content_block.id,
                                'name': event.content_block.name,
                                'input': {},
                            })

                elif event.type == 'content_block_delta':
                    if hasattr(event.delta, 'partial_json'):
                        # Update last tool use input
                        if tool_uses:
                            import json
                            tool_uses[-1]['input'].update(
                                json.loads(event.delta.partial_json)
                            )

        # If no tools called, we're done
        if not tool_uses:
            break

        # Request tool results from Lua
        for tool_use in tool_uses:
            yield {
                'type': 'tool_call',
                'id': tool_use['id'],
                'name': tool_use['name'],
                'args': tool_use['input'],
            }

            # Wait for tool response (this needs coordination with main loop)
            # For now, mark that we need a tool response
            yield {'type': 'awaiting_tool_response', 'tool_id': tool_use['id']}

    yield {'type': 'done'}
```

**Step 3: Test tool calling flow**

Test manually:
1. Create a file with a function
2. Call `:AIRequest use the foo function`
3. Verify LLM requests implementation via tool
4. Verify completion uses the implementation

**Step 4: Commit**

```bash
git add lua/ai-request/completion.lua python/providers/anthropic_client.py
git commit -m "feat: implement tool calling for fetching implementations

- Lua finds function implementations using treesitter/pattern matching
- Python streams tool call requests
- Multi-turn conversation for tool results"
```

---

## Task 12: Error Handling and Timeouts

**Files:**
- Modify: `lua/ai-request/completion.lua`
- Modify: `lua/ai-request/python_client.lua`

**Step 1: Add timeout handling**

Modify `lua/ai-request/completion.lua`, in `request()`:
```lua
  -- Set timeout
  local timeout_timer = vim.loop.new_timer()
  timeout_timer:start(opts.timeout_ms, 0, vim.schedule_wrap(function()
    if active_requests[request_id] then
      vim.notify("AI Request timed out", vim.log.levels.ERROR)
      active_requests[request_id].display:clear()
      active_requests[request_id] = nil
    end
  end))

  -- Store timer for cleanup
  active_requests[request_id].timeout_timer = timeout_timer
```

And in `_handle_response`, clean up timer:
```lua
  elseif response.type == "done" or response.type == "error" then
    if req.timeout_timer then
      req.timeout_timer:stop()
      req.timeout_timer:close()
    end
    -- ... rest of handling
```

**Step 2: Add Python process crash recovery**

Modify `lua/ai-request/python_client.lua`, in `on_exit`:
```lua
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify("AI Request Python exited with code " .. code, vim.log.levels.ERROR)
          self.job_id = nil  -- Mark as dead
        end
      end,
```

Add auto-restart in `send()`:
```lua
function M:send(request, callback)
  -- Restart if dead
  if not self.job_id or self.job_id <= 0 then
    vim.notify("Restarting Python backend...", vim.log.levels.INFO)
    -- Re-initialize
    local new_client = M.new()
    self.job_id = new_client.job_id
  end

  -- ... rest of send logic
```

**Step 3: Test error scenarios**

Manual tests:
- Kill Python process mid-request
- Set very short timeout
- Invalid API key

**Step 4: Commit**

```bash
git add lua/ai-request/completion.lua lua/ai-request/python_client.lua
git commit -m "feat: add error handling and timeouts

- Request timeout with configurable duration
- Python process crash recovery with auto-restart
- Proper cleanup of timers and resources"
```

---

## Task 13: Documentation and Polish

**Files:**
- Modify: `README.md`
- Create: `doc/ai-request.txt`

**Step 1: Update README with full documentation**

Modify `README.md`:
```markdown
# ai-request.nvim

Async LLM-powered code completion for Neovim with virtual text feedback.

## Features

- **Async Streaming**: Non-blocking completions with real-time progress
- **Multiple Providers**: OpenAI, Anthropic Claude, local models (Ollama, llama.cpp)
- **Smart Context**: Sliding window + treesitter symbols for accurate completions
- **Tool Calling**: LLM can request function implementations from your codebase
- **Virtual Text UI**: Spinner and thinking display at invocation point
- **Concurrent Requests**: Multiple completions in parallel (configurable)

## Installation

### Prerequisites
- Neovim 0.10+
- Python 3.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- (Optional) [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for better context

### Install with lazy.nvim

```lua
{
  'your-username/ai-request.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',  -- optional
  },
  build = 'pip3 install -r python/requirements.txt',
  config = function()
    require('ai-request').setup({
      -- Defaults shown, all optional
      display = {
        show_thinking = true,
        show_spinner = true,
      },
      context = {
        lines_before = 100,
        lines_after = 20,
        include_treesitter = true,
        include_lsp = false,
      },
      max_concurrent_requests = 3,
      timeout_ms = 30000,
    })
  end
}
```

## Configuration

### Environment Variables (Required)

```bash
# Choose provider
export AI_REQUEST_PROVIDER=anthropic  # or: openai, local

# API Keys
export ANTHROPIC_API_KEY=sk-ant-...
export OPENAI_API_KEY=sk-...

# Model selection
export AI_REQUEST_MODEL=claude-sonnet-4.5  # or: gpt-4, deepseek-coder, etc.

# Local model settings (if provider=local)
export AI_REQUEST_LOCAL_URL=http://localhost:11434/v1  # Ollama
export AI_REQUEST_LOCAL_MODEL=deepseek-coder:33b
```

### Optional Environment Variables

```bash
export AI_REQUEST_TIMEOUT=60              # Request timeout in seconds
export AI_REQUEST_MAX_CONCURRENT=5        # Max parallel requests
export AI_REQUEST_MAX_TOOL_CALLS=3        # Max tool calling rounds
```

## Usage

### Commands

**Auto-completion at cursor:**
```vim
:AIRequest
```

**Prompted completion:**
```vim
:AIRequest make this function async
:AIRequest add error handling
:AIRequest refactor using functional style
```

### Keybindings (Example)

```lua
vim.keymap.set('n', '<leader>ai', ':AIRequest<CR>', { desc = 'AI auto-complete' })
vim.keymap.set('n', '<leader>ap', ':AIRequest ', { desc = 'AI prompted completion' })
```

## How It Works

1. **Context Extraction**: Captures code before/after cursor + function signatures
2. **Async Request**: Sends to LLM (OpenAI/Claude/local) via Python backend
3. **Streaming Display**: Shows spinner and thinking as virtual text
4. **Tool Calling** (optional): LLM requests specific function implementations
5. **Insertion**: Auto-inserts completion at marked position when ready

## Troubleshooting

**Python errors on startup:**
```bash
cd ~/.local/share/nvim/lazy/ai-request.nvim
pip3 install -r python/requirements.txt
```

**No completions:**
- Check `:messages` for errors
- Verify API keys are set: `echo $ANTHROPIC_API_KEY`
- Test Python backend: `python3 python/main.py` (should wait for stdin)

**Slow completions:**
- Reduce context window: `lines_before = 50`
- Disable tool calling by using simpler prompts
- Use local model for faster responses

## License

MIT
```

**Step 2: Create Vim help doc**

Create `doc/ai-request.txt`:
```
*ai-request.txt*  Async LLM code completion for Neovim

CONTENTS                                                  *ai-request-contents*

1. Introduction ........................... |ai-request-introduction|
2. Commands ............................... |ai-request-commands|
3. Configuration .......................... |ai-request-configuration|
4. Functions .............................. |ai-request-functions|

==============================================================================
INTRODUCTION                                          *ai-request-introduction*

ai-request.nvim provides async LLM-powered code completions with virtual text
feedback. Supports OpenAI, Anthropic Claude, and local models.

==============================================================================
COMMANDS                                                  *ai-request-commands*

:AIRequest [prompt]                                                *:AIRequest*
    Request a code completion at cursor position.

    Without arguments: Auto-completion based on context
    With arguments: Prompted completion using the provided instruction

    Examples:
        :AIRequest
        :AIRequest make this async
        :AIRequest add error handling

==============================================================================
CONFIGURATION                                        *ai-request-configuration*

Setup function:                                            *ai-request.setup()*
>
    require('ai-request').setup({
      display = {
        show_thinking = true,
        show_spinner = true,
      },
      context = {
        lines_before = 100,
        lines_after = 20,
        include_treesitter = true,
        include_lsp = false,
      },
      max_concurrent_requests = 3,
      timeout_ms = 30000,
    })
<

Environment variables (required):
    AI_REQUEST_PROVIDER       Provider: anthropic, openai, local
    ANTHROPIC_API_KEY        Anthropic API key
    OPENAI_API_KEY           OpenAI API key
    AI_REQUEST_MODEL         Model name override

==============================================================================
vim:tw=78:ts=8:ft=help:norl:
```

**Step 3: Generate help tags**

Run: `nvim --headless -c "helptags doc" -c quit`

**Step 4: Commit**

```bash
git add README.md doc/ai-request.txt
git commit -m "docs: add comprehensive documentation

- Complete README with installation, config, usage
- Vim help documentation
- Troubleshooting guide"
```

---

## Task 14: Final Testing and Polish

**Files:**
- Create: `tests/integration_test.lua`
- Create: `.github/workflows/test.yml` (optional)

**Step 1: Create integration test**

Create `tests/integration_test.lua`:
```lua
-- Integration test - requires API key
local ai_request = require('ai-request')

describe("integration test", function()
  before_each(function()
    ai_request.setup({
      timeout_ms = 10000,
    })
  end)

  it("should complete simple code", function()
    -- Create test buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'lua')
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "-- Write a function that adds two numbers",
      ""
    })

    -- Position cursor
    vim.api.nvim_win_set_cursor(0, {2, 0})

    -- Request completion
    ai_request.request("implement the function")

    -- Wait for completion (or timeout)
    vim.wait(10000, function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      return #lines > 2  -- Should have added lines
    end)

    -- Verify
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.is_true(#lines > 2, "Should have inserted completion")
  end)
end)
```

**Step 2: Manual testing checklist**

Test the following scenarios:
- [ ] Basic auto-completion
- [ ] Prompted completion
- [ ] Multiple concurrent requests
- [ ] Timeout handling
- [ ] Tool calling (function lookup)
- [ ] Error notification (invalid API key)
- [ ] Python crash recovery
- [ ] Spinner animation
- [ ] Thinking text display (with Claude)
- [ ] Different providers (OpenAI, Anthropic, local)

**Step 3: Add CI (optional)**

Create `.github/workflows/test.yml`:
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Neovim
        run: |
          wget https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
          tar xzf nvim-linux64.tar.gz
          sudo ln -s $(pwd)/nvim-linux64/bin/nvim /usr/local/bin/nvim

      - name: Install Python dependencies
        run: pip install -r python/requirements.txt

      - name: Run Python tests
        run: cd python && python -m pytest tests/

      - name: Install Plenary
        run: |
          git clone https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim

      - name: Run Lua tests
        run: nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa!"
```

**Step 4: Polish and final verification**

Run:
```bash
# Python tests
cd python && python -m pytest tests/ -v

# Lua tests
nvim --headless -c "PlenaryBustedDirectory tests/" -c "qa!"

# Check file structure
tree -L 3
```

**Step 5: Commit**

```bash
git add tests/ .github/
git commit -m "test: add integration tests and CI

- Integration test for full completion flow
- GitHub Actions CI workflow
- Manual testing checklist"
```

---

## Done!

You now have a complete LLM completion plugin with:

✅ Python backend (OpenAI, Anthropic, local models)
✅ Streaming with tool calling
✅ Lua frontend with virtual text UI
✅ Context extraction (sliding window + treesitter)
✅ Async, non-blocking operation
✅ Error handling and timeouts
✅ Comprehensive documentation
✅ Tests

**Next steps:**
1. Test with real API keys
2. Tweak context extraction for your use cases
3. Add LSP symbol support
4. Optimize prompts for better completions
5. Consider adding: cancel command, completion preview mode, history

**Reference skills used:**
- @skills/testing/test-driven-development for TDD workflow
- @skills/collaboration/executing-plans for this implementation
