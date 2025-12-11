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
