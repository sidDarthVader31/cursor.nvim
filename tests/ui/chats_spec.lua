local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

test("session parse_ls_line extracts id and title", function()
  local session = require("cursor.session")
  local parsed = session.parse_ls_line("sess_abc123def456  Fix login bug in picker")
  assert_eq(parsed.id, "sess_abc123def456")
  assert_eq(parsed.title, "Fix login bug in picker")
end)

test("session parse_ls_output skips blank lines", function()
  local session = require("cursor.session")
  local fixture = require("tests.fake_agent").fixture_path("agent_ls.txt")
  local lines = vim.fn.readfile(fixture)
  local chats = session.parse_ls_output(lines)
  assert_eq(#chats, 3)
  assert_eq(chats[1].id, "sess_abc123def456")
  assert_true(chats[1].title:find("login") ~= nil)
end)

test("open_chats schedules UI from fast event callback", function()
  local picker = require("cursor.ui.picker")
  local session = require("cursor.session")
  helper.reset_plugin()

  local orig_list = session.list_chats
  session.list_chats = function(cb)
    -- Simulate vim.system fast-event callback
    cb({
      { id = "sess_1", title = "First chat" },
    })
  end

  picker.open_chats()
  helper.wait_schedule()

  assert_true(picker.win ~= nil)
  assert_true(vim.api.nvim_win_is_valid(picker.win))

  picker.close()
  session.list_chats = orig_list
end)
