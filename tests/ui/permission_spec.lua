local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true
local assert_eq = helper.assert_eq

test("permission dialog is readonly and closes on key", function()
  local permission = require("cursor.ui.permission")
  local permissions = require("cursor.permissions")
  helper.reset_plugin()

  local responded = false
  local orig_respond = permissions.respond
  permissions.respond = function(_, option_id)
    responded = true
    assert_eq(option_id, "allow-session")
  end

  permission.show({
    title = "Run shell command",
    options = {
      { id = "allow-once", name = "Allow once" },
      { id = "allow-session", name = "Allow for session" },
      { id = "reject-once", name = "Deny" },
    },
  }, 42)

  assert_true(permission.buf ~= nil)
  assert_eq(vim.api.nvim_buf_get_option(permission.buf, "readonly"), true)

  vim.api.nvim_set_current_win(permission.win)
  vim.cmd("stopinsert")
  vim.api.nvim_feedkeys("s", "x", true)

  assert_true(responded)
  assert_true(permission.win == nil or not vim.api.nvim_win_is_valid(permission.win))

  permissions.respond = orig_respond
end)
