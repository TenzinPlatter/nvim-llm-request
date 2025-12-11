# ai-request.nvim

Async LLM-powered code completion for Neovim.

## Installation

### Dependencies
- Neovim 0.10+
- Python 3.8+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Install with lazy.nvim

```lua
{
  'your-username/ai-request.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  build = 'pip3 install -r python/requirements.txt',
  config = function()
    require('ai-request').setup({})
  end
}
```

## Configuration

Set environment variables:
```bash
export OPENAI_API_KEY=sk-...
export ANTHROPIC_API_KEY=sk-ant-...
export AI_REQUEST_PROVIDER=anthropic  # or openai, local
export AI_REQUEST_MODEL=claude-sonnet-4.5
```

## Usage

`:AIRequest` - Auto-complete at cursor
`:AIRequest make this async` - Prompted completion
