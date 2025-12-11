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
