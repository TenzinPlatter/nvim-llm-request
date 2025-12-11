local M = {}

--- Extract context around cursor position
--- @param bufnr number Buffer number
--- @param line number Line number (1-indexed)
--- @param opts table Options { lines_before, lines_after, include_treesitter, include_lsp }
--- @return table Context { bufnr, cursor_line, before, after, filetype, symbols }
function M.extract(bufnr, line, opts)
  opts = opts or {}
  local lines_before = opts.lines_before or 100
  local lines_after = opts.lines_after or 20

  -- Get total line count
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Calculate range
  local start_line = math.max(0, line - lines_before - 1)
  local end_line = math.min(total_lines, line + lines_after)

  -- Extract lines
  local before_lines = vim.api.nvim_buf_get_lines(bufnr, start_line, line - 1, false)
  local after_lines = vim.api.nvim_buf_get_lines(bufnr, line, end_line, false)

  local ctx = {
    bufnr = bufnr,
    cursor_line = line,
    before = table.concat(before_lines, "\n"),
    after = table.concat(after_lines, "\n"),
    filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype'),
    symbols = {},
  }

  -- Extract symbols if requested
  if opts.include_treesitter then
    ctx.symbols = M.extract_treesitter_symbols(bufnr)
  end

  if opts.include_lsp then
    -- TODO: Extract LSP symbols
  end

  return ctx
end

--- Extract function/class signatures using treesitter
--- @param bufnr number Buffer number
--- @return table List of symbols { name, type, signature }
function M.extract_treesitter_symbols(bufnr)
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if not ok then
    return {}
  end

  local parser = parsers.get_parser(bufnr)
  if not parser then
    return {}
  end

  local symbols = {}
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Query for function definitions (simplified, needs per-language queries)
  local query_string = [[
    (function_declaration name: (identifier) @name)
    (function_definition name: (identifier) @name)
  ]]

  local ok_query, query = pcall(vim.treesitter.query.parse, parser:lang(), query_string)
  if not ok_query then
    return symbols
  end

  for _, match in query:iter_matches(root, bufnr) do
    for id, node in pairs(match) do
      local name = vim.treesitter.get_node_text(node, bufnr)
      table.insert(symbols, {
        name = name,
        type = 'function',
        signature = name .. '()',  -- Simplified
      })
    end
  end

  return symbols
end

--- Format context for LLM
--- @param ctx table Context from extract()
--- @return string Formatted context
function M.format(ctx)
  local parts = {}

  table.insert(parts, "File type: " .. (ctx.filetype or "unknown"))

  if #ctx.symbols > 0 then
    table.insert(parts, "\nAvailable functions:")
    for _, sym in ipairs(ctx.symbols) do
      table.insert(parts, "- " .. sym.signature)
    end
  end

  table.insert(parts, "\nCode before cursor:")
  table.insert(parts, ctx.before)
  table.insert(parts, "\n<cursor>")
  table.insert(parts, "\nCode after cursor:")
  table.insert(parts, ctx.after)

  return table.concat(parts, "\n")
end

return M
