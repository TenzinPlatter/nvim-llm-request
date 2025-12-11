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
- (Optional) [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for enhanced context extraction

### Install with lazy.nvim

**Standard installation:**
```lua
{
  'your-username/ai-request.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',  -- optional but recommended
  },
  build = 'pip3 install -r python/requirements.txt',
  config = function()
    require('ai-request').setup({
      -- Provider configuration
      provider = 'anthropic',  -- 'anthropic', 'openai', or 'local'
      model = nil,  -- Auto-selected if nil (claude-sonnet-4.5, gpt-4, etc.)
      base_url = nil,  -- Only needed for local models

      -- Behavior
      timeout = 30,  -- seconds
      max_tool_calls = 3,
      max_concurrent_requests = 3,

      -- Display
      display = {
        show_thinking = true,
        show_spinner = true,
      },

      -- Context extraction
      context = {
        lines_before = 100,
        lines_after = 20,
        include_treesitter = true,
        include_lsp = false,
      },
    })
  end
}
```

**Lazy-loading on command (faster startup):**
```lua
{
  'your-username/ai-request.nvim',
  cmd = 'AIRequest',  -- Load only when :AIRequest is called
  dependencies = {
    'nvim-treesitter/nvim-treesitter',  -- optional
  },
  build = 'pip3 install -r python/requirements.txt',
  config = function()
    require('ai-request').setup({
      provider = 'anthropic',
      -- other options...
    })
  end
}
```

**Local model example (Ollama):**
```lua
require('ai-request').setup({
  provider = 'local',
  model = 'deepseek-coder:6.7b',
  base_url = 'http://localhost:11434/v1',
})
```

## Configuration

### API Keys (Required)

Set the API key for your chosen provider:

```bash
# Anthropic Claude
export ANTHROPIC_API_KEY=sk-ant-...

# OpenAI
export OPENAI_API_KEY=sk-...

# Local models (optional, some don't need keys)
export AI_REQUEST_LOCAL_API_KEY=your-key
```

### Configuration Priority

Settings are resolved in this order:
1. **Lua `setup()` config** - Non-sensitive settings (provider, model, timeouts, etc.)
2. **Environment variables** - Fallback for any setting, required for API keys
3. **Defaults** - Sensible defaults if nothing specified

**Best practice:** Configure provider/model in `setup()`, keep API keys in environment variables.

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
