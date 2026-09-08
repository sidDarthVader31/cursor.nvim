local config = require("cursor.config")
local transport = require("cursor.transport")

local M = {}

M.buf = nil
M.win = nil
M.job_id = nil

local URL_PATTERN = "https?://[%w%-%._~:/?#%[%]@!$&'()*+,;=%]+"

local function close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
  M.job_id = nil
end

local function append_lines(lines)
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end
  vim.api.nvim_buf_set_option(M.buf, "modifiable", true)
  local count = vim.api.nvim_buf_line_count(M.buf)
  vim.api.nvim_buf_set_lines(M.buf, count, count, false, lines)
  vim.api.nvim_buf_set_option(M.buf, "modifiable", false)
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_set_cursor(M.win, { vim.api.nvim_buf_line_count(M.buf), 0 })
  end
end

local function append_text(text)
  if not text or text == "" then
    return
  end
  local lines = vim.split(text, "\n", { plain = true })
  if text:sub(-1) == "\n" then
    table.remove(lines)
  end
  append_lines(lines)
end

local function extract_urls(text)
  local urls = {}
  for url in text:gmatch(URL_PATTERN) do
    table.insert(urls, url)
  end
  return urls
end

local function open_float(title, height)
  close()
  M.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(M.buf, "swapfile", false)
  vim.api.nvim_buf_set_name(M.buf, "cursor-login")

  local width = math.min(80, vim.o.columns - 4)
  height = math.min(height or 16, vim.o.lines - 4)

  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = config.get().border or "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", close, { buffer = M.buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = M.buf, nowait = true })

  return M.buf, M.win
end

local function on_login_exit(code)
  if code == 0 then
    append_lines({ "", "✓ Login successful. Run :CursorRestart" })
    vim.notify("[cursor] Login successful. Run :CursorRestart", vim.log.levels.INFO)
  else
    append_lines({ "", "✗ Login failed or was cancelled (exit " .. tostring(code) .. ")" })
    vim.notify("[cursor] Login failed or cancelled", vim.log.levels.WARN)
  end
end

function M.open_terminal()
  local agent = transport.find_agent()
  if not agent then
    vim.notify(
      "[cursor] `agent` not found in PATH. Install Cursor CLI: https://cursor.com/docs/cli/overview",
      vim.log.levels.ERROR
    )
    return
  end

  vim.notify("[cursor] Opening terminal for `agent login` — complete SSO in your browser", vim.log.levels.INFO)

  vim.cmd("belowright split")
  local term_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_option(term_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_name(term_buf, "cursor-login-terminal")

  local cmd = vim.fn.shellescape(agent) .. " login"
  M.job_id = vim.fn.termopen(cmd, {
    env = vim.env,
    on_exit = function(_, code, _)
      vim.schedule(function()
        on_login_exit(code)
      end)
    end,
  })

  if M.job_id <= 0 then
    vim.notify("[cursor] Failed to start login terminal", vim.log.levels.ERROR)
    return
  end

  vim.cmd("startinsert")
end

function M.open_no_browser()
  local agent = transport.find_agent()
  if not agent then
    vim.notify(
      "[cursor] `agent` not found in PATH. Install Cursor CLI: https://cursor.com/docs/cli/overview",
      vim.log.levels.ERROR
    )
    return
  end

  open_float("Cursor login (no browser)", 18)
  append_lines({
    "Running `NO_OPEN_BROWSER=1 agent login`…",
    "Open the URL below in your browser to complete SSO.",
    "",
  })

  local captured = ""
  local env = vim.deepcopy(vim.env)
  env.NO_OPEN_BROWSER = "1"

  vim.system({ agent, "login" }, {
    env = env,
    stdout = function(_, data)
      if data then
        captured = captured .. data
        append_text(data)
        local urls = extract_urls(data)
        if #urls > 0 then
          append_lines({ "", "Login URL:", urls[#urls], "" })
        end
      end
    end,
    stderr = function(_, data)
      if data then
        captured = captured .. data
        append_text(data)
        local urls = extract_urls(data)
        if #urls > 0 then
          append_lines({ "", "Login URL:", urls[#urls], "" })
        end
      end
    end,
  }, function(obj)
    vim.schedule(function()
      local urls = extract_urls(captured)
      if #urls == 0 and obj.stdout then
        urls = extract_urls(obj.stdout)
      end
      if #urls == 0 and obj.stderr then
        urls = extract_urls(obj.stderr)
      end
      if #urls > 0 then
        append_lines({ "", "── Login URL (copy and open) ──", urls[#urls], "" })
      end
      on_login_exit(obj.code)
    end)
  end)
end

function M.start(opts)
  opts = opts or {}
  if opts.no_browser then
    M.open_no_browser()
  else
    M.open_terminal()
  end
end

return M
