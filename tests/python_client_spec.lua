local python_client = require('ai-request.python_client')

describe("python_client", function()
  it("should start python process", function()
    local client = python_client.new()
    assert.is_not_nil(client)
    assert.is_not_nil(client.job_id)
  end)

  it("should send and receive JSON", function()
    local client = python_client.new()
    local received = nil

    client:send({
      type = "complete",
      context = "test",
      prompt = nil
    }, function(response)
      received = response
    end)

    -- Wait for response (in real test, use vim.wait)
    vim.wait(1000, function() return received ~= nil end)

    assert.is_not_nil(received)
    assert.equals("error", received.type) -- Should error (no API key in test)
  end)
end)
