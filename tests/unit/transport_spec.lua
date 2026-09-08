local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true
local assert_false = helper.assert_false

test("transport start without agent returns error", function()
  local transport = require("cursor.transport")
  transport.stop()
  local orig_find = transport.find_agent
  transport.find_agent = function()
    return nil
  end
  local ok, err = transport.start()
  transport.find_agent = orig_find
  transport.stop()
  assert_false(ok)
  assert_true(err and err:find("agent") ~= nil)
end)
