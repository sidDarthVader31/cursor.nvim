local M = {}

M.passed = 0
M.failed = 0

function M.test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    M.passed = M.passed + 1
    print("PASS: " .. name)
  else
    M.failed = M.failed + 1
    print("FAIL: " .. name .. " — " .. tostring(err))
  end
end

function M.assert_eq(a, b)
  if a ~= b then
    error(string.format("expected %s, got %s", vim.inspect(b), vim.inspect(a)))
  end
end

function M.assert_true(v, msg)
  if not v then
    error(msg or "expected true")
  end
end

function M.assert_false(v, msg)
  if v then
    error(msg or "expected false")
  end
end

function M.assert_not_nil(v, msg)
  if v == nil then
    error(msg or "expected non-nil")
  end
end

function M.assert_nil(v, msg)
  if v ~= nil then
    error(msg or string.format("expected nil, got %s", vim.inspect(v)))
  end
end

function M.assert_match(pattern, value, msg)
  if type(value) ~= "string" or not value:find(pattern) then
    error(msg or string.format("expected %q to match %q", vim.inspect(value), pattern))
  end
end

--- Close UI windows and reset plugin state between tests.
function M.reset_plugin()
  local layout = require("cursor.ui.layout")
  if layout.close then
    layout.close()
  end
  layout.chat_buf = nil
  layout.input_buf = nil
  layout.chat_win = nil
  layout.input_win = nil
  layout.main_win = nil

  local picker = require("cursor.ui.picker")
  if picker.close then
    picker.close()
  end

  local plan_ui = require("cursor.ui.plan")
  if plan_ui.close then
    plan_ui.close()
  end

  local spinner = require("cursor.ui.spinner")
  if spinner.stop then
    spinner.stop()
  end

  local transport = require("cursor.transport")
  if transport.stop then
    transport.stop()
  end

  require("cursor.state").reset()
  require("cursor.chats_index").clear_overrides()
end

--- Run scheduled callbacks (for tests that use vim.schedule).
function M.wait_schedule()
  vim.wait(100, function()
    return false
  end)
end

local function list_lua_files(dir)
  local files = {}
  local handle = vim.loop.fs_scandir(dir)
  if not handle then
    return files
  end
  while true do
    local name, t = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    if t == "file" and name:match("%.lua$") then
      table.insert(files, dir .. "/" .. name)
    end
  end
  table.sort(files)
  return files
end

function M.discover_specs()
  local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
  local dirs = {
    root .. "tests/unit",
    root .. "tests/ui",
    root .. "tests/integration",
  }
  local specs = {}
  for _, dir in ipairs(dirs) do
    for _, file in ipairs(list_lua_files(dir)) do
      table.insert(specs, file)
    end
  end
  return specs
end

function M.run_specs(spec_files)
  M.passed = 0
  M.failed = 0

  for _, file in ipairs(spec_files) do
    local fn, err = loadfile(file)
    if not fn then
      M.failed = M.failed + 1
      print("FAIL: load " .. file .. " — " .. tostring(err))
    else
      fn()
    end
  end

  print(string.format("\n%d passed, %d failed", M.passed, M.failed))
  if M.failed > 0 then
    os.exit(1)
  end
end

return M
