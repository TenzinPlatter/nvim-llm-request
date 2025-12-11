local M = {}

M.config = {
  -- Provider configuration
  provider = 'anthropic',  -- 'anthropic', 'openai', or 'local'
  model = nil,  -- Auto-selected based on provider if nil
  base_url = nil,  -- For local/custom endpoints

  -- API keys (will use env vars if not provided)
  api_key = nil,  -- Only set if you want to override env vars (not recommended)

  -- Behavior settings
  timeout = 30,  -- seconds (for Python backend)
  timeout_ms = 30000,  -- milliseconds (for Lua timeout timer)
  max_tool_calls = 3,
  max_concurrent_requests = 3,

  -- Display settings
  display = {
    show_thinking = true,
    show_spinner = true,
  },

  -- Context extraction settings
  context = {
    lines_before = 100,
    lines_after = 20,
    include_treesitter = true,
    include_lsp = false,
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Validate provider
  local valid_providers = { anthropic = true, openai = true, local = true }
  if not valid_providers[M.config.provider] then
    vim.notify(
      string.format("Invalid provider '%s'. Must be: anthropic, openai, or local", M.config.provider),
      vim.log.levels.ERROR
    )
  end
end

--- Handle :AIRequest command
--- @param args string Command arguments (optional prompt)
function M.request(args)
  local completion = require('ai-request.completion')
  local prompt = args ~= "" and args or nil
  completion.request(prompt, M.config)
end

return M
