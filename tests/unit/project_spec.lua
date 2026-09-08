local helper = require("tests.helper")
local test = helper.test
local assert_true = helper.assert_true
local assert_false = helper.assert_false

test("project within root", function()
  local project = require("cursor.project")
  assert_true(project.within_root("/repo/src/foo.go", "/repo"))
  assert_false(project.within_root("/other/foo.go", "/repo"))
end)
