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
