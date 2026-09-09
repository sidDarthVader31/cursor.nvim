local acp = require("cursor.acp")
local auth = require("cursor.auth")
local config = require("cursor.config")
local project = require("cursor.project")
local state = require("cursor.state")
local transport = require("cursor.transport")

local M = {}

M._mapped_keys = {}

function M.setup(opts)
  config.setup(opts or {})

  if config.get().auto_resolve_agent then
    local path = transport.resolve_agent()
    if path then
      config.setup(vim.tbl_deep_extend("force", config.get(), { agent_path = path }))
    end
  end

  require("cursor.highlight").setup()
  require("cursor.commands").setup()
  M.setup_recommended_mappings()
end

function M.setup_recommended_mappings()
  local cfg = config.get()
  if not cfg.mappings_enabled then
    M.clear_recommended_mappings()
    return
  end

  local mappings = cfg.mappings or {}
  local group = { noremap = true, silent = true }

  local function map(key, rhs)
    if key and key ~= "" and not vim.g.cursor_disable_mappings then
      vim.keymap.set("n", key, rhs, group)
      M._mapped_keys[key] = true
    end
  end

  M.clear_recommended_mappings()

  map(mappings.chat, "<cmd>CursorChat<cr>")
  map(mappings.toggle, "<cmd>CursorToggle<cr>")
  map(mappings.ask, "<cmd>CursorAsk<cr>")
  map(mappings.cancel, "<cmd>CursorCancel<cr>")
  map(mappings.focus, "<cmd>CursorFocus<cr>")
  map(mappings.focus_chat, "<cmd>CursorFocusChat<cr>")
  map(mappings.focus_code, "<cmd>CursorFocusCode<cr>")
end

function M.clear_recommended_mappings()
  for key in pairs(M._mapped_keys) do
    pcall(vim.keymap.del, "n", key)
  end
  M._mapped_keys = {}
end

--- Reload plugin modules for development (does not re-run plugin/cursor.lua).
function M.reload(opts)
  M.clear_recommended_mappings()
  require("cursor.commands")._setup = false
  require("cursor.highlight")._done = false
  M.setup(opts or {})
end

function M.start(callback)
  require("cursor.acp").start({}, callback)
end

function M.restart(callback)
  require("cursor.acp").restart({}, callback)
end

function M.chat()
  require("cursor.ui").open()
  require("cursor.ui").ensure_started(function(ok, err)
    if not ok then
      require("cursor.state").set_error(err or "Agent not available — see :CursorHealth")
      require("cursor.ui").schedule_refresh()
    end
  end)
end

function M.focus()
  require("cursor.ui").focus()
end

function M.close()
  require("cursor.ui").close()
end

function M.toggle()
  local layout = require("cursor.ui.layout")
  if layout.is_open() then
    require("cursor.ui").close()
  else
    M.chat()
  end
end

function M.ask(prompt)
  require("cursor.ui").open()
  require("cursor.ui").ensure_started(function(ok, err)
    if not ok then
      require("cursor.state").set_error(err or "Agent not available")
      require("cursor.ui").schedule_refresh()
      return
    end
    if prompt and prompt ~= "" then
      require("cursor.ui.input").submit_with_context(prompt)
    else
      require("cursor.ui.input").submit_with_context("")
    end
  end)
end

function M.stop()
  acp.stop()
end

function M.cancel()
  state.get().run_cancelled = true
  acp.session_cancel(function()
    require("cursor.ui").schedule_refresh()
  end)
end

function M.login(opts)
  require("cursor.ui.login").start(opts or {})
end

function M.logout()
  auth.logout(function()
    M.stop()
    vim.notify("[cursor] Logged out", vim.log.levels.INFO)
  end)
end

function M.focus_chat()
  require("cursor.ui").focus_chat()
end

function M.focus_code()
  require("cursor.ui").focus_code()
end

function M.auth_status()
  auth.status(function(data)
    vim.notify(vim.inspect(data), vim.log.levels.INFO)
  end)
end

function M.health()
  local lines = {}
  table.insert(lines, "cursor.nvim health")
  table.insert(lines, string.rep("─", 20))

  local nvim_ver = vim.version()
  table.insert(lines, string.format("✓ Neovim version: %d.%d.%d", nvim_ver.major, nvim_ver.minor, nvim_ver.patch))

  local agent_path = transport.find_agent()
  if agent_path then
    table.insert(lines, "✓ agent executable: " .. agent_path)
  else
    table.insert(lines, "✗ agent executable: not found")
    table.insert(lines, "  → Run `which agent` in your terminal")
    table.insert(lines, "  → Auto-resolve checks PATH, common paths, and login shell")
    table.insert(lines, "  → Set agent_path in require('cursor').setup({ agent_path = '...' })")
  end

  if auth.is_api_key_set() then
    table.insert(lines, "✓ CURSOR_API_KEY: set")
  else
    table.insert(lines, "○ CURSOR_API_KEY: not set (browser login may be used)")
  end

  local root = project.root()
  table.insert(lines, "✓ project root: " .. root)

  local st = state.get()
  table.insert(lines, "○ ACP process: " .. (transport.is_running() and "running" or "stopped"))
  table.insert(lines, "○ active session: " .. (st.session_id and ("yes (" .. st.session_id .. ")") or "no"))
  table.insert(lines, "○ status: " .. st.status)
  table.insert(lines, "")
  table.insert(lines, "Usage is billed to your Cursor account (same pool as Cursor desktop).")

  return lines
end

return M
