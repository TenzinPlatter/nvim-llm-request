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

  it("should display spinner inline at end of empty line", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"line 1", "   ", "line 3"})

    -- Create display on whitespace-only line (line 2)
    local d = display.new(buf, 2, { show_spinner = true }, "   ", true)
    d:show("Generating...")

    -- Check extmark exists and uses virt_text with eol positioning
    local marks = vim.api.nvim_buf_get_extmarks(buf, d.namespace, 0, -1, { details = true })
    assert.is_true(#marks > 0)

    -- Verify it uses virt_text positioned at eol (not virt_lines)
    local mark_details = marks[1][4]
    assert.is_not_nil(mark_details.virt_text, "Should use virt_text")
    assert.is_nil(mark_details.virt_lines, "Should NOT use virt_lines")
    assert.equals("eol", mark_details.virt_text_pos, "Should position at end of line")

    -- Verify line count unchanged (no new lines created)
    local line_count = vim.api.nvim_buf_line_count(buf)
    assert.equals(3, line_count, "Should not create new lines")

    d:clear()
  end)
end)
