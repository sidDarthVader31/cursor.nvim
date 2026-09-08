local M = {}

local defaults = {
  agent_command = "agent",
  agent_args = { "acp" },
  width = 0.40,
  border = "rounded",
  auto_start = false,
  project_root = nil,
  log_level = "warn",
  permissions = {
    default = "ask",
    terminal = "ask",
    file_write = "ask",
  },
  mappings = {
    chat = "<leader>cc",
    ask = "<leader>ca",
    cancel = "<leader>cx",
    toggle = "<leader>ct",
  },
  picker = {
    width = 70,
    height = 18,
  },
  ui_flush_ms = 30,
}

M._config = vim.deepcopy(defaults)

function M.setup(opts)
  opts = opts or {}
  M._config = vim.tbl_deep_extend("force", defaults, opts)
end

function M.get()
  return M._config
end

function M.get_log_level()
  local levels = { trace = 0, debug = 1, info = 2, warn = 3, error = 4 }
  return levels[M._config.log_level] or levels.warn
end

return M
