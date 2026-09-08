local acp = require("cursor.acp")
local config = require("cursor.config")
local context = require("cursor.context")
local state = require("cursor.state")
local transport = require("cursor.transport")
local usage = require("cursor.usage")

local M = {}

local function insert_newline()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", true)
end

function M.setup(buf)
  local cfg = config.get().mappings

  local function bind_submit(key)
    if not key or key == "" then
      return
    end
    vim.api.nvim_buf_set_keymap(buf, "i", key, "", {
      noremap = true,
      silent = true,
      callback = function()
        M.submit()
      end,
    })
  end

  local function bind_newline(key)
    if not key or key == "" then
      return
    end
    vim.api.nvim_buf_set_keymap(buf, "i", key, "", {
      noremap = true,
      silent = true,
      callback = insert_newline,
    })
  end

  -- Cursor-like: Enter sends, Shift+Enter (or Ctrl+J) adds a newline
  bind_submit(cfg.submit or "<CR>")
  bind_submit(cfg.submit_alt or "<C-CR>")
  bind_newline(cfg.newline or "<S-CR>")
  bind_newline(cfg.newline_alt or "<C-j>")

  vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "", {
    noremap = true,
    silent = true,
    callback = function()
      acp.session_cancel()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    end,
  })
end

function M.input_title()
  return " input · Enter=send · Shift+Enter=newline "
end

function M.get_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

function M.do_submit(text)
  local layout = require("cursor.ui.layout")
  local buf = layout.input_buf
  if not buf then
    return
  end

  state.add_message({ role = "user", content = text })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  require("cursor.ui").refresh()

  acp.session_prompt(text, function(_, prompt_err)
    if prompt_err then
      vim.notify(
        "[cursor] " .. (prompt_err.message or vim.inspect(prompt_err) or "prompt failed"),
        vim.log.levels.ERROR
      )
    end
  end)
end

function M.submit()
  local layout = require("cursor.ui.layout")
  local buf = layout.input_buf
  if not buf then
    return
  end

  local text = vim.trim(M.get_text(buf))
  local ok, err = usage.validate_prompt(text)
  if not ok then
    vim.notify("[cursor] " .. err, vim.log.levels.WARN)
    return
  end

  if state.get().prompting then
    vim.notify("[cursor] Agent is busy", vim.log.levels.WARN)
    return
  end

  if not transport.is_running() or not state.get().session_id then
    require("cursor.ui").ensure_started(function(started, start_err)
      if not started then
        vim.notify("[cursor] " .. (start_err or "Agent not ready — try :CursorLogin"), vim.log.levels.ERROR)
        return
      end
      M.do_submit(text)
    end)
    return
  end

  M.do_submit(text)
end

function M.submit_with_context(user_text)
  local prompt = context.from_editor(user_text)
  local layout = require("cursor.ui.layout")
  if layout.input_buf then
    vim.api.nvim_buf_set_lines(layout.input_buf, 0, -1, false, vim.split(prompt, "\n"))
  end
  require("cursor.ui").open()
  require("cursor.ui.layout").focus_input()
end

return M
