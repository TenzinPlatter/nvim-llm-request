local context = require('ai-request.context')

describe("context extraction", function()
  it("should extract sliding window", function()
    -- Create a buffer with test content
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {}
    for i = 1, 200 do
      table.insert(lines, "line " .. i)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Extract context at line 150
    local ctx = context.extract(buf, 150, {
      lines_before = 100,
      lines_after = 20,
    })

    assert.equals(buf, ctx.bufnr)
    assert.equals(150, ctx.cursor_line)
    assert.is_not_nil(ctx.before)
    assert.is_not_nil(ctx.after)
    assert.equals(100, #vim.split(ctx.before, "\n"))
    assert.equals(20, #vim.split(ctx.after, "\n"))
  end)
end)
