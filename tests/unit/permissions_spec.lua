local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true
local assert_match = helper.assert_match

test("fs read error returns json-rpc error response", function()
  local rpc = require("cursor.rpc")
  local state = require("cursor.state")
  state.reset()
  rpc.on_request("fs/read_text_file", function(params, id)
    return rpc.error_response(id, -32000, "missing path")
  end)
  local response = rpc.handle_line(vim.json.encode({
    jsonrpc = "2.0",
    id = 42,
    method = "fs/read_text_file",
    params = {},
  }))
  assert_true(response ~= nil)
  assert_match("error", response)
  assert_match("missing path", response)
end)

test("permissions default_option_id prefers agent options", function()
  local permissions = require("cursor.permissions")
  local id = permissions.default_option_id({
    options = {
      { id = "allow-once", name = "Allow once" },
      { id = "allow-session", name = "Allow for session" },
      { id = "reject-once", name = "Deny" },
    },
  }, "allow")
  assert_match("allow", id)
end)
