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
