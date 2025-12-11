local python_client = require('ai-request.python_client')
local context = require('ai-request.context')
local display = require('ai-request.display')

local M = {}

-- Global Python client (reused across requests)
local client = nil
local active_requests = {}

--- Initialize Python client if needed
local function ensure_client()
  if not client then
    client = python_client.new()
  end
  return client
end

--- Handle a completion request
--- @param prompt string|nil Optional user prompt
--- @param opts table Config options
function M.request(prompt, opts)
  opts = opts or require('ai-request').config

  -- Check concurrent request limit
  if #active_requests >= opts.max_concurrent_requests then
    vim.notify("Max concurrent requests reached", vim.log.levels.WARN)
    return
  end

  -- Get current position
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Get current line content and check if empty/whitespace only
  local current_line = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
  local indent = current_line:match("^%s*") or ""
  local is_empty_line = current_line:match("^%s*$") ~= nil

  -- Extract context
  local ctx = context.extract(bufnr, line, opts.context)
  local formatted_context = context.format(ctx)

  -- Create display with indentation
  local disp = display.new(bufnr, line, opts.display, indent)
  disp:show("Generating...")

  -- Track this request with unique ID
  local request_id = tostring(os.time() * 1000 + math.random(1000))
  active_requests[request_id] = {
    display = disp,
    bufnr = bufnr,
    line = line,
    completion_parts = {},
    indent = indent,
    is_empty_line = is_empty_line,
  }

  -- Set timeout
  local timeout_timer = vim.loop.new_timer()
  timeout_timer:start(opts.timeout_ms, 0, vim.schedule_wrap(function()
    if active_requests[request_id] then
      vim.notify("AI Request timed out", vim.log.levels.ERROR)
      active_requests[request_id].display:clear()
      active_requests[request_id] = nil
    end
  end))

  -- Store timer for cleanup
  active_requests[request_id].timeout_timer = timeout_timer

  -- Build config for Python backend
  local provider_config = {
    provider = opts.provider,
    model = opts.model,
    base_url = opts.base_url,
    api_key = opts.api_key,
    timeout = opts.timeout,
    max_tool_calls = opts.max_tool_calls,
  }

  -- Send request to Python
  local c = ensure_client()
  c:send({
    type = "complete",
    request_id = request_id,
    context = formatted_context,
    prompt = prompt,
    config = provider_config,
  }, function(response)
    M._handle_response(request_id, response, opts)
  end)
end

--- Handle streaming responses
--- @param request_id number Request ID
--- @param response table Response from Python
--- @param opts table Config options
function M._handle_response(request_id, response, opts)
  local req = active_requests[request_id]
  if not req then
    return
  end

  if response.type == "thinking" then
    -- Just accumulate, don't update display
    -- Spinner continues showing "Generating..."

  elseif response.type == "completion" then
    -- Accumulate completion parts, spinner continues
    table.insert(req.completion_parts, response.content)

  elseif response.type == "tool_call" then
    -- Find implementation without changing display
    local implementation = M._find_implementation(req.bufnr, response.args.function_name or "unknown")

    -- Send back to Python with tool_call_id
    local c = ensure_client()
    c:send({
      type = "tool_response",
      request_id = request_id,
      tool_call_id = response.id,
      content = implementation or "Function not found",
    }, function(resp)
      M._handle_response(request_id, resp, opts)
    end)

  elseif response.type == "done" then
    -- Clean up timer
    if req.timeout_timer then
      req.timeout_timer:stop()
      req.timeout_timer:close()
    end

    -- Insert completion
    local completion = table.concat(req.completion_parts, "")
    if completion ~= "" then
      M._insert_completion(req.bufnr, req.line, completion, req.indent, req.is_empty_line)
    end
    req.display:clear()
    active_requests[request_id] = nil

  elseif response.type == "error" then
    -- Clean up timer
    if req.timeout_timer then
      req.timeout_timer:stop()
      req.timeout_timer:close()
    end

    vim.notify("AI Request failed: " .. response.message, vim.log.levels.ERROR)
    req.display:clear()
    active_requests[request_id] = nil
  end
end

--- Strip markdown code block markers from completion
--- @param text string Completion text that may contain code blocks
--- @return string Cleaned text without code block markers
function M._strip_code_blocks(text)
  -- Remove opening code block (```lang or just ```)
  text = text:gsub("^%s*```%w*\n", "")

  -- Remove closing code block
  text = text:gsub("\n```%s*$", "")

  -- Also handle if closing is at the very end without newline
  text = text:gsub("```%s*$", "")

  return text
end

--- Insert completion at position
--- @param bufnr number Buffer number
--- @param line number Line number (1-indexed)
--- @param completion string Text to insert
--- @param indent string Leading whitespace from original line
--- @param is_empty_line boolean Whether the original line was empty/whitespace only
function M._insert_completion(bufnr, line, completion, indent, is_empty_line)
  -- Strip markdown code block markers
  completion = M._strip_code_blocks(completion)

  -- Trim leading/trailing whitespace from entire completion
  completion = completion:match("^%s*(.-)%s*$") or completion

  local lines = vim.split(completion, "\n")

  -- Remove trailing empty lines (caused by trailing newlines in completion)
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end

  -- Add indentation to all lines
  for i, l in ipairs(lines) do
    if l ~= "" then
      lines[i] = indent .. l
    end
  end

  if is_empty_line then
    -- Replace the current line instead of inserting after it
    vim.api.nvim_buf_set_lines(bufnr, line - 1, line, false, lines)
  else
    -- Insert after the current line (original behavior)
    vim.api.nvim_buf_set_lines(bufnr, line, line, false, lines)
  end
end

--- Find function implementation using treesitter
--- @param bufnr number Buffer number
--- @param function_name string Function name to find
--- @return string|nil Implementation code
function M._find_implementation(bufnr, function_name)
  -- Try current buffer first
  local impl = M._search_buffer(bufnr, function_name)
  if impl then
    return impl
  end

  -- Try LSP workspace symbols
  impl = M._search_lsp(function_name)
  if impl then
    return impl
  end

  -- Search project files
  impl = M._search_project(bufnr, function_name)
  if impl then
    return impl
  end

  return nil
end

--- Search a specific buffer for function
--- @param bufnr number Buffer number
--- @param function_name string Function name
--- @return string|nil Implementation
function M._search_buffer(bufnr, function_name)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  -- Language-specific patterns
  local patterns = {
    lua = {
      "function%s+" .. function_name .. "%s*%(.-%)[^e]*end",
      "local%s+function%s+" .. function_name .. "%s*%(.-%)[^e]*end",
      function_name .. "%s*=%s*function%s*%(.-%)[^e]*end",
    },
    python = {
      "def%s+" .. function_name .. "%s*%(.-%):[^\n]*\n%s+.*",
    },
    javascript = {
      "function%s+" .. function_name .. "%s*%(.-%)[^}]*}",
      "const%s+" .. function_name .. "%s*=%s*%(.-%)[^}]*}",
    },
  }

  local lang_patterns = patterns[filetype] or patterns.lua
  for _, pattern in ipairs(lang_patterns) do
    local impl = content:match(pattern)
    if impl then
      return impl
    end
  end

  return nil
end

--- Search using LSP workspace symbols
--- @param function_name string Function name
--- @return string|nil Implementation
function M._search_lsp(function_name)
  local clients = vim.lsp.get_active_clients()
  if #clients == 0 then
    return nil
  end

  -- Try to find symbol via LSP (simplified, async version would be better)
  -- This is a placeholder - full implementation would use LSP workspace symbols
  return nil
end

--- Search project files
--- @param bufnr number Current buffer number (for file type detection)
--- @param function_name string Function name
--- @return string|nil Implementation
function M._search_project(bufnr, function_name)
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  local extensions = {
    lua = "lua",
    python = "py",
    javascript = "js",
    typescript = "ts",
  }

  local ext = extensions[filetype]
  if not ext then
    return nil
  end

  -- Get project root
  local root = vim.fn.getcwd()

  -- Search for files containing the function name (using ripgrep if available)
  local pattern = function_name .. "%s*[=%(]"
  local cmd = string.format("rg -l '%s' --type %s '%s' 2>/dev/null", pattern, ext, root)

  local handle = io.popen(cmd)
  if not handle then
    return nil
  end

  local result = handle:read("*a")
  handle:close()

  if result == "" then
    return nil
  end

  -- Get first matching file
  local files = vim.split(result, "\n", { trimempty = true })
  if #files == 0 then
    return nil
  end

  -- Read and search the file
  local file_path = files[1]
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Try to extract the function
  local impl = content:match("function%s+" .. function_name .. "%s*%(.-%)[^e]*end")
  if impl then
    return impl
  end

  -- Return a snippet if exact match not found
  return string.format("-- Found in %s\n%s", file_path, content:sub(1, 500))
end

return M
