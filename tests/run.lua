local helper = require("tests.helper")

local spec_files = helper.discover_specs()

-- Allow running a single spec file: FILE=tests/unit/foo_spec.lua make test-file
local single = os.getenv("FILE")
if single and single ~= "" then
  spec_files = { single }
end

helper.run_specs(spec_files)
