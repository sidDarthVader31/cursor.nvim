local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

test("session.rename updates session title in state", function()
  local state = require("cursor.state")
  local session = require("cursor.session")
  local chats_index = require("cursor.chats_index")
  local acp = require("cursor.acp")
  local config = require("cursor.config")

  state.reset()
  state.get().session_id = "sess-rename-test"

  local fixture_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p") .. "tests/fixtures/chats"
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local workspace = tmp_dir .. "/abc123workspacehash"
  local session_dir = workspace .. "/sess-rename-test"
  vim.fn.mkdir(session_dir, "p")

  local src = fixture_root .. "/abc123workspacehash/11111111-1111-1111-1111-111111111111/meta.json"
  local dst = session_dir .. "/meta.json"
  vim.fn.writefile(vim.fn.readfile(src), dst)

  config.setup({ chats_storage_dirs = { tmp_dir } })

  local orig_set_title = acp.session_set_title
  acp.session_set_title = function(_, _, cb)
    if cb then
      cb({}, nil)
    end
  end

  local done = false
  local ok_result = false
  session.rename("My renamed chat", "sess-rename-test", function(ok)
    ok_result = ok
    done = true
  end)

  vim.wait(1000, function()
    return done
  end)

  acp.session_set_title = orig_set_title
  vim.fn.delete(tmp_dir, "rf")

  assert_true(ok_result)
  assert_eq(state.get().session_title, "My renamed chat")
end)
