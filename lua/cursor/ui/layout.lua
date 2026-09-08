local config = require("cursor.config")
local state = require("cursor.state")

local M = {}

M.chat_buf = nil
M.input_buf = nil
M.chat_win = nil
M.input_win = nil

local function setup_highlights()
  vim.api.nvim_set_hl(0, "CursorTitle", { link = "Title" })
  vim.api.nvim_set_hl(0, "CursorUser", { link = "Identifier" })
  vim.api.nvim_set_hl(0, "CursorAgent", { link = "Comment" })
  vim.api.nvim_set_hl(0, "CursorTool", { link = "Special" })
  vim.api.nvim_set_hl(0, "CursorPickerCurrent", { link = "CursorLine" })
  vim.api.nvim_set_hl(0, "CursorPickerTab", { link = "TabLineSel" })
  vim.api.nvim_set_hl(0, "CursorPickerFilter", { link = "Question" })
end

function M.open()
  setup_highlights()
  local cfg = config.get()
  local width = math.floor(vim.o.columns * cfg.width)
  local height = vim.o.lines - 4
  local col = vim.o.columns - width - 1
  local row = 1

  if not M.chat_buf or not vim.api.nvim_buf_is_valid(M.chat_buf) then
    M.chat_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.chat_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.chat_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.chat_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(M.chat_buf, "modifiable", false)
    vim.api.nvim_buf_set_name(M.chat_buf, "cursor-chat")
  end

  if not M.input_buf or not vim.api.nvim_buf_is_valid(M.input_buf) then
    M.input_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.input_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.input_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.input_buf, "swapfile", false)
    vim.api.nvim_buf_set_name(M.input_buf, "cursor-input")
    require("cursor.ui.input").setup(M.input_buf)
  end

  local input_height = 4
  local chat_height = height - input_height - 2

  M.chat_win = vim.api.nvim_open_win(M.chat_buf, true, {
    relative = "editor",
    width = width,
    height = chat_height,
    col = col,
    row = row,
    style = "minimal",
    border = cfg.border,
    title = M.title_text(),
    title_pos = "center",
  })

  M.input_win = vim.api.nvim_open_win(M.input_buf, true, {
    relative = "editor",
    width = width,
    height = input_height,
    col = col,
    row = row + chat_height + 1,
    style = "minimal",
    border = cfg.border,
    title = " input ",
    title_pos = "center",
  })

  require("cursor.ui.chat").render()
end

function M.title_text()
  local st = state.get()
  local model = st.current_model or "?"
  local effort = st.current_effort or "medium"
  local mode = st.current_mode or "agent"
  local status = st.status or "stopped"
  return string.format(" Cursor  %s  %s  %s · %s ", model, effort, mode, status)
end

function M.update_title()
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    vim.api.nvim_win_set_config(M.chat_win, { title = M.title_text() })
  end
end

function M.close()
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    vim.api.nvim_win_close(M.chat_win, true)
  end
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_win_close(M.input_win, true)
  end
  M.chat_win = nil
  M.input_win = nil
end

function M.is_open()
  return M.chat_win and vim.api.nvim_win_is_valid(M.chat_win)
end

function M.focus_input()
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_set_current_win(M.input_win)
    vim.cmd("startinsert")
  end
end

return M
