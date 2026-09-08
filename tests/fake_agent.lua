local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")

function M.script_path()
  return root .. "/fake_agent.sh"
end

function M.fixture_path(name)
  return root .. "/fixtures/" .. name
end

function M.log_path()
  return root .. "/.fake_agent.log"
end

function M.clear_log()
  local path = M.log_path()
  local f = io.open(path, "w")
  if f then
    f:close()
  end
end

function M.read_log()
  local path = M.log_path()
  local f = io.open(path, "r")
  if not f then
    return ""
  end
  local content = f:read("*a")
  f:close()
  return content or ""
end

function M.init_count()
  local log = M.read_log()
  local count = 0
  for line in log:gmatch("[^\n]+") do
    if line:match("^INIT_COUNT=") then
      count = tonumber(line:match("INIT_COUNT=(%d+)")) or count
    end
  end
  return count
end

function M.env()
  return {
    CURSOR_NVIM_FAKE_AGENT_LOG = M.log_path(),
    CURSOR_NVIM_FIXTURE_DIR = root .. "/fixtures",
  }
end

return M
