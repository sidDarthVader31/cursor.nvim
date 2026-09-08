local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true

local fixture_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p") .. "tests/fixtures/chats"

test("chats_index workspace_hash is stable md5", function()
  local chats_index = require("cursor.chats_index")
  local hash = chats_index.workspace_hash("/tmp/cursor-nvim-test-project")
  assert_true(hash ~= nil)
  assert_eq(#hash, 32)
  assert_eq(chats_index.workspace_hash("/tmp/cursor-nvim-test-project"), hash)
end)

test("chats_index read_meta parses fixture", function()
  local chats_index = require("cursor.chats_index")
  local meta = chats_index.read_meta(fixture_root .. "/abc123workspacehash/11111111-1111-1111-1111-111111111111/meta.json")
  assert_eq(meta.title, "Fix picker colors")
  assert_eq(meta.cwd, "/tmp/cursor-nvim-test-project")
end)

test("chats_index list_for_root returns project chats sorted", function()
  local config = require("cursor.config")
  local chats_index = require("cursor.chats_index")
  config.setup({ chats_storage_dirs = { fixture_root } })

  local orig_hash = chats_index.workspace_hash
  chats_index.workspace_hash = function()
    return "abc123workspacehash"
  end

  local chats = chats_index.list_for_root("/tmp/cursor-nvim-test-project")
  chats_index.workspace_hash = orig_hash

  assert_eq(#chats, 2)
  assert_eq(chats[1].title, "Add chats index")
  assert_eq(chats[2].title, "Fix picker colors")
end)

test("chats_index format_chat_line includes relative time", function()
  local chats_index = require("cursor.chats_index")
  local line = chats_index.format_chat_line({
    title = "My chat",
    updatedAtMs = vim.loop.now() - 120000,
  })
  assert_true(line:find("My chat") ~= nil)
  assert_true(line:find("ago") ~= nil)
end)

test("chats_index set_title updates meta.json", function()
  local chats_index = require("cursor.chats_index")
  local config = require("cursor.config")
  local fixture_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p") .. "tests/fixtures/chats"
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local workspace = tmp_dir .. "/abc123workspacehash"
  local session_dir = workspace .. "/22222222-2222-2222-2222-222222222222"
  vim.fn.mkdir(session_dir, "p")

  local src = fixture_root .. "/abc123workspacehash/11111111-1111-1111-1111-111111111111/meta.json"
  local dst = session_dir .. "/meta.json"
  vim.fn.writefile(vim.fn.readfile(src), dst)

  config.setup({ chats_storage_dirs = { tmp_dir } })
  chats_index.clear_overrides()
  local ok = chats_index.set_title("22222222-2222-2222-2222-222222222222", "Renamed chat")
  assert_true(ok)

  local meta = chats_index.read_meta(dst)
  assert_eq(meta.title, "Renamed chat")

  vim.fn.delete(tmp_dir, "rf")
  chats_index.clear_overrides()
end)

test("chats_index title overlay appears in list_for_root", function()
  local config = require("cursor.config")
  local chats_index = require("cursor.chats_index")
  config.setup({ chats_storage_dirs = { fixture_root } })
  chats_index.clear_overrides()

  local orig_hash = chats_index.workspace_hash
  chats_index.workspace_hash = function()
    return "abc123workspacehash"
  end

  chats_index.remember_title("sess-overlay-test", "Live title", {
    cwd = "/tmp/cursor-nvim-test-project",
  })

  local chats = chats_index.list_for_root("/tmp/cursor-nvim-test-project")
  chats_index.workspace_hash = orig_hash
  chats_index.clear_overrides()

  local found = false
  for _, chat in ipairs(chats) do
    if chat.id == "sess-overlay-test" and chat.title == "Live title" then
      found = true
      break
    end
  end
  assert_true(found)
end)

test("chats_index overlay overrides stale disk title", function()
  local config = require("cursor.config")
  local chats_index = require("cursor.chats_index")
  config.setup({ chats_storage_dirs = { fixture_root } })
  chats_index.clear_overrides()

  local orig_hash = chats_index.workspace_hash
  chats_index.workspace_hash = function()
    return "abc123workspacehash"
  end

  chats_index.remember_title("11111111-1111-1111-1111-111111111111", "Updated live title", {
    cwd = "/tmp/cursor-nvim-test-project",
  })

  local chats = chats_index.list_for_root("/tmp/cursor-nvim-test-project")
  chats_index.workspace_hash = orig_hash
  chats_index.clear_overrides()

  local title = nil
  for _, chat in ipairs(chats) do
    if chat.id == "11111111-1111-1111-1111-111111111111" then
      title = chat.title
      break
    end
  end
  assert_eq(title, "Updated live title")
end)
