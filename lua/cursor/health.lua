local M = {}

function M.check()
  vim.health.start("cursor.nvim")

  local nvim_ver = vim.version()
  if nvim_ver.major > 0 or nvim_ver.minor >= 11 then
    vim.health.ok(string.format("Neovim %d.%d.%d", nvim_ver.major, nvim_ver.minor, nvim_ver.patch))
  else
    vim.health.warn("Neovim 0.11+ recommended")
  end

  local transport = require("cursor.transport")
  local agent_path = transport.find_agent()
  if agent_path then
    vim.health.ok("agent executable: " .. agent_path)
  else
    vim.health.error("agent executable not found in PATH")
  end

  local auth = require("cursor.auth")
  if auth.is_api_key_set() then
    vim.health.ok("CURSOR_API_KEY is set")
  else
    vim.health.info("CURSOR_API_KEY not set; use :CursorLogin for browser/SSO auth")
  end

  local project = require("cursor.project")
  vim.health.ok("project root: " .. project.root())

  local st = require("cursor.state").get()
  if transport.is_running() then
    vim.health.ok("ACP process running")
  else
    vim.health.info("ACP process stopped (use :CursorStart)")
  end

  if st.session_id then
    vim.health.ok("active session: " .. st.session_id)
  else
    vim.health.info("no active session")
  end

  vim.health.info("Usage is billed to your Cursor account (same pool as Cursor desktop).")
end

return M
