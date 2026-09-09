local config = require("cursor.config")
local state = require("cursor.state")

local M = {}

M.chat_buf = nil
M.input_buf = nil
M.chat_win = nil
M.input_win = nil
M.main_win = nil

local function setup_chat_buffer(buf)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  pcall(vim.treesitter.start, buf, "markdown")
end

local function apply_chat_win_options(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  vim.api.nvim_win_set_option(win, "wrap", true)
  local md = config.get().markdown or {}
  if md.conceal then
    vim.api.nvim_win_set_option(win, "conceallevel", 2)
    vim.api.nvim_win_set_option(win, "concealcursor", "n")
  end
end

local function ensure_buffers()
  if not M.chat_buf or not vim.api.nvim_buf_is_valid(M.chat_buf) then
    M.chat_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.chat_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.chat_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.chat_buf, "swapfile", false)
    vim.api.nvim_buf_set_option(M.chat_buf, "modifiable", false)
    vim.api.nvim_buf_set_name(M.chat_buf, "cursor-chat")
    setup_chat_buffer(M.chat_buf)
    M.setup_chat_keymaps(M.chat_buf)
  end

  if not M.input_buf or not vim.api.nvim_buf_is_valid(M.input_buf) then
    M.input_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(M.input_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.input_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.input_buf, "swapfile", false)
    vim.api.nvim_buf_set_name(M.input_buf, "cursor-input")
    require("cursor.ui.input").setup(M.input_buf)
  else
    -- Re-apply keymaps when reopening (buffer may already exist)
    require("cursor.ui.input").setup(M.input_buf)
  end
end

function M.setup_chat_keymaps(buf)
  local opts = { buffer = buf, silent = true }
  -- Jump to input (below in split layout)
  vim.keymap.set("n", "<C-w>j", function()
    M.focus_input()
  end, opts)
  vim.keymap.set("n", "i", function()
    M.focus_input()
  end, opts)
  vim.keymap.set("n", "R", function()
    require("cursor.session").prompt_rename()
  end, opts)
  vim.keymap.set("n", "P", function()
    require("cursor.plans").open_latest_or_picker()
  end, opts)
  vim.keymap.set("n", "x", function()
    require("cursor.ui.input").stop()
  end, opts)
end

function M.open_split()
  ensure_buffers()

  if M.is_open() then
    if config.get().return_to_code_on_open then
      M.focus_code()
    else
      M.focus_input()
    end
    return
  end

  M.main_win = vim.api.nvim_get_current_win()

  vim.cmd("vsplit")
  M.chat_win = vim.api.nvim_get_current_win()

  local width = math.floor(vim.o.columns * config.get().width)
  vim.cmd("vertical resize " .. width)

  vim.api.nvim_win_set_buf(M.chat_win, M.chat_buf)
  vim.api.nvim_win_set_option(M.chat_win, "number", false)
  vim.api.nvim_win_set_option(M.chat_win, "relativenumber", false)
  vim.api.nvim_win_set_option(M.chat_win, "winfixwidth", true)
  apply_chat_win_options(M.chat_win)

  vim.cmd("split")
  M.input_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.input_win, M.input_buf)
  vim.api.nvim_win_set_option(M.input_win, "number", false)
  vim.api.nvim_win_set_option(M.input_win, "relativenumber", false)
  vim.api.nvim_win_set_option(M.input_win, "wrap", true)
  vim.api.nvim_win_set_option(M.input_win, "winfixheight", true)
  vim.cmd("resize " .. (config.get().input_height or 4))

  -- chat on top, input on bottom in the right column
  local chat_wins = vim.fn.win_findbuf(M.chat_buf)
  local input_wins = vim.fn.win_findbuf(M.input_buf)
  M.chat_win = chat_wins[1]
  M.input_win = input_wins[1]

  if config.get().return_to_code_on_open and M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
    vim.api.nvim_set_current_win(M.main_win)
  else
    M.focus_input()
  end

  require("cursor.ui.chat").render()
end

function M.open_float()
  if M.is_open() then
    M.focus_input()
    return
  end
  ensure_buffers()
  local cfg = config.get()
  local width = math.floor(vim.o.columns * cfg.width)
  local height = vim.o.lines - 4
  local col = vim.o.columns - width - 1
  local row = 1

  local input_height = config.get().input_height or 4
  local chat_height = height - input_height - 2

  M.chat_win = vim.api.nvim_open_win(M.chat_buf, false, {
    relative = "editor",
    width = width,
    height = chat_height,
    col = col,
    row = row,
    style = "minimal",
    border = cfg.border,
    title = M.title_text(),
    title_pos = "center",
    focusable = true,
    zindex = 40,
  })

  M.input_win = vim.api.nvim_open_win(M.input_buf, true, {
    relative = "editor",
    width = width,
    height = input_height,
    col = col,
    row = row + chat_height + 1,
    style = "minimal",
    border = cfg.border,
    title = require("cursor.ui.input").input_title(),
    title_pos = "center",
    focusable = true,
    zindex = 41,
  })

  apply_chat_win_options(M.chat_win)

  require("cursor.ui.chat").render()
end

function M.open()
  local layout = config.get().layout or "split"
  if layout == "float" then
    M.open_float()
  else
    M.open_split()
  end
end

function M.title_text()
  return require("cursor.ui.status").text({ window = true })
end

function M.update_title()
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    vim.api.nvim_win_set_config(M.chat_win, { title = M.title_text() })
  end
end

function M.update_input_title()
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_win_set_config(M.input_win, {
      title = require("cursor.ui.input").input_title(),
    })
  end
end

function M.close()
  -- Close bottom (input) first so the column collapses cleanly
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_win_close(M.input_win, true)
  end
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    vim.api.nvim_win_close(M.chat_win, true)
  end
  M.chat_win = nil
  M.input_win = nil
end

function M.is_open()
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    return true
  end
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    return true
  end
  return false
end

function M.focus_chat()
  if M.chat_win and vim.api.nvim_win_is_valid(M.chat_win) then
    vim.api.nvim_set_current_win(M.chat_win)
    vim.cmd("stopinsert")
  end
end

function M.focus_input()
  if M.input_win and vim.api.nvim_win_is_valid(M.input_win) then
    vim.api.nvim_set_current_win(M.input_win)
    vim.cmd("startinsert")
  end
end

function M.focus_code()
  if M.main_win and vim.api.nvim_win_is_valid(M.main_win) then
    vim.api.nvim_set_current_win(M.main_win)
    vim.cmd("stopinsert")
    return
  end
  -- fallback: leftmost window
  vim.cmd("wincmd h")
  vim.cmd("stopinsert")
end

return M
