local helper = require("tests.helper")
local test = helper.test
local assert_eq = helper.assert_eq
local assert_true = helper.assert_true
local assert_false = helper.assert_false

test("setup does not map keys when mappings_enabled is false", function()
  local cursor = require("cursor")
  cursor.setup({ mappings_enabled = false, mappings = { chat = "<leader>cc" } })

  local modes = vim.fn.maparg("<leader>cc", "n", false, true)
  assert_false(modes and modes.lhs ~= nil)
end)

test("setup applies mappings idempotently when enabled", function()
  local cursor = require("cursor")
  cursor.setup({ mappings_enabled = true, mappings = { chat = "<leader>cc" } })
  local first = vim.fn.maparg("<leader>cc", "n", false, true)
  assert_true(first and first.rhs and first.rhs:find("CursorChat") ~= nil)

  cursor.setup({ mappings_enabled = true, mappings = { chat = "<leader>xx" } })
  local old = vim.fn.maparg("<leader>cc", "n", false, true)
  local new = vim.fn.maparg("<leader>xx", "n", false, true)
  assert_false(old and old.rhs and old.rhs:find("CursorChat") ~= nil)
  assert_true(new and new.rhs and new.rhs:find("CursorChat") ~= nil)
end)
