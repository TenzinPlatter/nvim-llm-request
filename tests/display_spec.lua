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
    local d = display.new(buf, 2, { show_spinner = true })
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

  it("should display spinner inline at end of non-empty line", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"line 1", "existing content", "line 3"})

    -- Create display on non-empty line (line 2)
    local d = display.new(buf, 2, { show_spinner = true })
    d:show("Generating...")

    -- Check extmark uses virt_text with eol positioning
    local marks = vim.api.nvim_buf_get_extmarks(buf, d.namespace, 0, -1, { details = true })
    assert.is_true(#marks > 0)

    local mark_details = marks[1][4]
    assert.is_not_nil(mark_details.virt_text)
    assert.is_nil(mark_details.virt_lines)
    assert.equals("eol", mark_details.virt_text_pos)

    -- Verify line count unchanged
    local line_count = vim.api.nvim_buf_line_count(buf)
    assert.equals(3, line_count)

    d:clear()
  end)

  it("should maintain spinner position when buffer is edited", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"line 1", "   ", "line 3"})

    -- Create display on line 2
    local d = display.new(buf, 2, { show_spinner = true })
    d:show("Generating...")

    -- Insert a line before the spinner line
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, {"new line 1"})

    -- Spinner should now be on line 3 (shifted down)
    local marks = vim.api.nvim_buf_get_extmarks(buf, d.namespace, 0, -1, { details = true })
    assert.is_true(#marks > 0)

    -- Extmark should have moved to line 2 (0-indexed, so line 3 in 1-indexed)
    local mark_line = marks[1][2]
    assert.equals(2, mark_line, "Extmark should track to new position")

    d:clear()
  end)

  -- Comprehensive verification test for Task 7
  describe("comprehensive implementation verification", function()
    it("should meet all inline display requirements", function()
      local buf = vim.api.nvim_create_buf(false, true)

      -- Test 1: Spinner on empty/whitespace-only line
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"", "    ", "  \t  "})
      local d1 = display.new(buf, 2, { show_spinner = true })
      d1:show("Test 1")

      local marks = vim.api.nvim_buf_get_extmarks(buf, d1.namespace, 0, -1, { details = true })
      assert.equals(1, #marks, "Should have exactly one extmark")
      assert.equals("eol", marks[1][4].virt_text_pos, "Should position at eol")
      assert.is_not_nil(marks[1][4].virt_text, "Should use virt_text")
      assert.is_nil(marks[1][4].virt_lines, "Should NOT use virt_lines")
      assert.equals(3, vim.api.nvim_buf_line_count(buf), "Line count should not change")
      d1:clear()

      -- Test 2: Spinner on non-empty line with content
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"local x = 1", "function foo()", "end"})
      local d2 = display.new(buf, 2, { show_spinner = true })
      d2:show("Test 2")

      marks = vim.api.nvim_buf_get_extmarks(buf, d2.namespace, 0, -1, { details = true })
      assert.equals(1, #marks, "Should have exactly one extmark")
      assert.equals("eol", marks[1][4].virt_text_pos, "Should position at eol on non-empty line")
      assert.equals(3, vim.api.nvim_buf_line_count(buf), "Line count should not change")

      -- Verify virt_text contains spinner and message
      local virt_text = marks[1][4].virt_text[1][1]
      assert.is_true(virt_text:match("Test 2") ~= nil, "Should contain message text")
      d2:clear()

      -- Test 3: Position tracking during multiple edits
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"line 1", "line 2", "line 3", "line 4"})
      local d3 = display.new(buf, 3, { show_spinner = true })
      d3:show("Test 3")

      -- Initial position check (line 3, 0-indexed = 2)
      marks = vim.api.nvim_buf_get_extmarks(buf, d3.namespace, 0, -1, { details = true })
      assert.equals(2, marks[1][2], "Should start at line 2 (0-indexed)")

      -- Insert line above
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, {"new line"})
      marks = vim.api.nvim_buf_get_extmarks(buf, d3.namespace, 0, -1, { details = true })
      assert.equals(3, marks[1][2], "Should track to line 3 after insert above")

      -- Insert line below
      vim.api.nvim_buf_set_lines(buf, 5, 5, false, {"another line"})
      marks = vim.api.nvim_buf_get_extmarks(buf, d3.namespace, 0, -1, { details = true })
      assert.equals(3, marks[1][2], "Should stay at line 3 after insert below")

      -- Verify it maintains eol positioning throughout edits
      assert.equals("eol", marks[1][4].virt_text_pos, "Should remain at eol position after edits")
      assert.is_not_nil(marks[1][4].virt_text, "Should still use virt_text")
      assert.is_nil(marks[1][4].virt_lines, "Should NOT use virt_lines after edits")

      d3:clear()

      -- Test 4: No spinner mode (show_spinner = false)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"test"})
      local d4 = display.new(buf, 1, { show_spinner = false })
      d4:show("No spinner")

      marks = vim.api.nvim_buf_get_extmarks(buf, d4.namespace, 0, -1, { details = true })
      assert.equals(1, #marks, "Should still create extmark without spinner")
      assert.equals("eol", marks[1][4].virt_text_pos, "Should still use eol positioning")

      local virt_text_no_spinner = marks[1][4].virt_text[1][1]
      assert.is_true(virt_text_no_spinner:match("No spinner") ~= nil, "Should show text without spinner")
      d4:clear()
    end)
  end)
end)
