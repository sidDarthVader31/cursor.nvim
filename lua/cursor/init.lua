local acp = require("cursor.acp")
local auth = require("cursor.auth")
local config = require("cursor.config")
local project = require("cursor.project")
local state = require("cursor.state")
local transport = require("cursor.transport")

local M = {}

function M.setup(opts)
  config.setup(opts)
  require("cursor.commands").setup()
  M.setup_recommended_mappings()
end

function M.setup_recommended_mappings()
  local cfg = config.get().mappings
  local group = { noremap = true, silent = true }

  local function map(key, rhs)
    if key and key ~= "" and not vim.g.cursor_disable_mappings then
      vim.keymap.set("n", key, rhs, group)
    end
  end

  map(cfg.chat, "<cmd>CursorChat<cr>")
  map(cfg.toggle, "<cmd>CursorToggle<cr>")
  map(cfg.ask, "<cmd>CursorAsk<cr>")
  map(cfg.cancel, "<cmd>CursorCancel<cr>")
  map(cfg.focus, "<cmd>CursorFocus<cr>")
  map(cfg.focus_chat, "<cmd>CursorFocusChat<cr>")
  map(cfg.focus_code, "<cmd>CursorFocusCode<cr>")
end

function M.start(callback)
  require("cursor.acp").start({}, callback)
end

function M.restart(callback)
  require("cursor.acp").restart({}, callback)
end

function M.chat()
  require("cursor.ui").ensure_started(function(ok)
    if ok then
      require("cursor.ui").open()
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
  require("cursor.ui").toggle()
end

function M.ask(prompt)
  require("cursor.ui").ensure_started(function(ok)
    if not ok then
      return
    end
    require("cursor.ui").open()
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
  acp.session_cancel()
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
    table.insert(lines, "✗ agent executable: not found in PATH")
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
