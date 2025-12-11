local M = {}

--- Create a new Python client
--- @return table Client instance
function M.new()
  local self = {
    job_id = nil,
    callbacks = {},
    next_id = 1,
  }

  -- Find python script path
  local script_path = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h") .. "/python/main.py"

  -- Start python process
  self.job_id = vim.fn.jobstart(
    {'python3', script_path},
    {
      on_stdout = function(_, data)
        self:_on_stdout(data)
      end,
      on_stderr = function(_, data)
        if data and #data > 0 then
          vim.notify("AI Request Python error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end
      end,
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify("AI Request Python exited with code " .. code, vim.log.levels.ERROR)
          self.job_id = nil  -- Mark as dead
        end
      end,
      stdout_buffered = false,
      stderr_buffered = false,
    }
  )

  if self.job_id <= 0 then
    error("Failed to start Python process")
  end

  setmetatable(self, { __index = M })
  return self
end

--- Handle stdout from Python
--- @param data table Lines of output
function M:_on_stdout(data)
  for _, line in ipairs(data) do
    if line and line ~= "" then
      local ok, response = pcall(vim.json.decode, line)
      if ok then
        -- Find callback for this response
        -- For now, call all callbacks (TODO: match by ID)
        for id, callback in pairs(self.callbacks) do
          callback(response)
          if response.type == "done" or response.type == "error" then
            self.callbacks[id] = nil
          end
        end
      end
    end
  end
end

--- Send a request to Python
--- @param request table Request object
--- @param callback function Callback for responses
function M:send(request, callback)
  -- Restart if dead
  if not self.job_id or self.job_id <= 0 then
    vim.notify("Restarting Python backend...", vim.log.levels.INFO)
    -- Re-initialize
    local new_client = M.new()
    self.job_id = new_client.job_id
  end

  local id = self.next_id
  self.next_id = self.next_id + 1

  self.callbacks[id] = callback

  local json = vim.json.encode(request)
  vim.fn.chansend(self.job_id, json .. "\n")
end

--- Stop the Python process
function M:stop()
  if self.job_id then
    vim.fn.jobstop(self.job_id)
    self.job_id = nil
  end
end

return M
