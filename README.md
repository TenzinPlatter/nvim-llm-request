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
      -- configuration here
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
