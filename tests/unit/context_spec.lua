local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true

test("context lean prompt", function()
  local context = require("cursor.context")
  local prompt = context.build_prompt("explain", {
    file = "/repo/foo.go",
    cwd = "/repo",
    cursor = { line = 10, column = 5 },
  })
  assert_true(prompt:find("explain") ~= nil)
  assert_true(prompt:find("foo.go") ~= nil)
end)
