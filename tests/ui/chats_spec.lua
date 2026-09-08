local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("open_chats schedules UI from fast event callback", function()
  local picker = require("cursor.ui.picker")
  local session = require("cursor.session")
  helper.reset_plugin()

  local orig_list = session.list_chats
  session.list_chats = function(cb)
    cb({
      { id = "sess_1", title = "First chat", updatedAtMs = vim.loop.now() },
    })
  end

  picker.open_chats()
  helper.wait_schedule()

  assert_true(picker.win ~= nil)
  assert_true(vim.api.nvim_win_is_valid(picker.win))

  picker.close()
  session.list_chats = orig_list
end)

test("list_chats uses chats_index for project", function()
  local config = require("cursor.config")
  local session = require("cursor.session")
  local project = require("cursor.project")
  local fixture_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p") .. "tests/fixtures/chats"
  config.setup({ chats_storage_dirs = { fixture_root } })

  local chats_index = require("cursor.chats_index")
  local orig_hash = chats_index.workspace_hash
  local orig_root = project.root
  chats_index.workspace_hash = function()
    return "abc123workspacehash"
  end
  project.root = function()
    return "/tmp/cursor-nvim-test-project"
  end

  local done = false
  local chats = {}
  session.list_chats(function(result)
    chats = result
    done = true
  end)

  vim.wait(1000, function()
    return done
  end)

  chats_index.workspace_hash = orig_hash
  project.root = orig_root
  assert_true(#chats >= 2)
end)
