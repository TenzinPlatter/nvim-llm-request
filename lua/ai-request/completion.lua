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

  -- Extract context
  local ctx = context.extract(bufnr, line, opts.context)
  local formatted_context = context.format(ctx)

  -- Create display
  local disp = display.new(bufnr, line, opts.display)
  disp:show("Starting request...")

  -- Track this request
  local request_id = #active_requests + 1
  active_requests[request_id] = {
    display = disp,
    bufnr = bufnr,
    line = line,
    completion_parts = {},
  }

  -- Send request to Python
  local c = ensure_client()
  c:send({
    type = "complete",
    context = formatted_context,
    prompt = prompt,
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
    if opts.display.show_thinking then
      req.display:update("Thinking: " .. response.content)
    end

  elseif response.type == "completion" then
    req.display:update("Generating...")
    table.insert(req.completion_parts, response.content)

  elseif response.type == "tool_call" then
    -- TODO: Handle tool calls
    req.display:update("Requesting " .. response.name .. "...")

  elseif response.type == "done" then
    -- Insert completion
    local completion = table.concat(req.completion_parts, "")
    if completion ~= "" then
      M._insert_completion(req.bufnr, req.line, completion)
    end
    req.display:clear()
    active_requests[request_id] = nil

  elseif response.type == "error" then
    vim.notify("AI Request failed: " .. response.message, vim.log.levels.ERROR)
    req.display:clear()
    active_requests[request_id] = nil
  end
end

--- Insert completion at position
--- @param bufnr number Buffer number
--- @param line number Line number
--- @param completion string Text to insert
function M._insert_completion(bufnr, line, completion)
  local lines = vim.split(completion, "\n")
  vim.api.nvim_buf_set_lines(bufnr, line, line, false, lines)
end

return M
