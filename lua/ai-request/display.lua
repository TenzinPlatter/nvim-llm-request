local M = {}

local SPINNERS = {
  "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"
}

--- Create a new display manager
--- @param bufnr number Buffer number
--- @param line number Line number (1-indexed)
--- @param opts table Options { show_spinner, show_thinking }
--- @param indent string Leading whitespace for indentation
--- @param is_empty_line boolean Whether the line is empty/whitespace-only
--- @return table Display instance
function M.new(bufnr, line, opts, indent, is_empty_line)
  opts = opts or {}
  indent = indent or ""
  is_empty_line = is_empty_line or false

  local self = {
    bufnr = bufnr,
    line = line,
    namespace = vim.api.nvim_create_namespace('ai_request_display'),
    extmark_id = nil,
    spinner_index = 1,
    spinner_timer = nil,
    opts = opts,
    indent = indent,
    is_empty_line = is_empty_line,
  }

  setmetatable(self, { __index = M })
  return self
end

--- Show virtual text with optional spinner
--- @param text string Text to display
function M:show(text)
  -- Build the display text
  -- Add spacing prefix, then spinner, then text
  local display_text
  if self.opts.show_spinner then
    local spinner = SPINNERS[self.spinner_index]
    display_text = " " .. spinner .. " " .. text
  else
    display_text = " " .. text
  end

  -- Get the line number to place the extmark on
  -- If we already have an extmark, use its current position (it tracks automatically)
  -- Otherwise use the initial line
  local target_line
  if self.extmark_id then
    local mark = vim.api.nvim_buf_get_extmark_by_id(self.bufnr, self.namespace, self.extmark_id, {})
    if mark and #mark > 0 then
      target_line = mark[1]
    else
      -- Extmark was deleted somehow, recreate at original line
      self.extmark_id = nil
      target_line = self.line - 1
    end
  else
    target_line = self.line - 1  -- Convert from 1-indexed to 0-indexed
  end

  -- Create or update extmark with inline virt_text at end of line
  if self.extmark_id then
    vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, target_line, 0, {
      id = self.extmark_id,
      virt_text = {{display_text, "Comment"}},
      virt_text_pos = "eol",  -- Position at end of line
    })
  else
    self.extmark_id = vim.api.nvim_buf_set_extmark(self.bufnr, self.namespace, target_line, 0, {
      virt_text = {{display_text, "Comment"}},
      virt_text_pos = "eol",  -- Position at end of line
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
