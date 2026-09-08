local M = {}

--- Build an env dict safe for termopen / vim.system (string keys and values only).
function M.current(overrides)
  local env = {}
  for k, v in pairs(vim.env) do
    if type(k) == "string" and type(v) == "string" then
      env[k] = v
    end
  end
  if overrides then
    for k, v in pairs(overrides) do
      env[k] = v
    end
  end
  return env
end

return M
