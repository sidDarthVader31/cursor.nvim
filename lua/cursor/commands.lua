local M = {}

M._setup = false

function M.setup()
  if M._setup then
    return
  end
  M._setup = true

  local function cmd(name, fn, opts)
    opts = opts or {}
    vim.api.nvim_create_user_command(name, fn, opts)
  end

  cmd("CursorHealth", function()
    local lines = require("cursor").health()
    for _, line in ipairs(lines) do
      vim.notify(line, vim.log.levels.INFO)
    end
  end, {})

  cmd("CursorStart", function()
    require("cursor").start(function(ok, err)
      if ok then
        vim.notify("[cursor] Agent started", vim.log.levels.INFO)
      else
        vim.notify("[cursor] " .. (err or "start failed"), vim.log.levels.ERROR)
      end
    end)
  end, {})

  cmd("CursorStop", function()
    require("cursor").stop()
    vim.notify("[cursor] Agent stopped", vim.log.levels.INFO)
  end, {})

  cmd("CursorRestart", function()
    require("cursor").restart(function(ok, err)
      if ok then
        vim.notify("[cursor] Agent restarted", vim.log.levels.INFO)
      else
        vim.notify("[cursor] " .. (err or "restart failed"), vim.log.levels.ERROR)
      end
    end)
  end, {})

  cmd("CursorLogin", function(opts)
    require("cursor").login({ no_browser = opts.bang })
  end, { bang = true })

  cmd("CursorLogout", function()
    require("cursor").logout()
  end, {})

  cmd("CursorAuthStatus", function()
    require("cursor").auth_status()
  end, {})

  cmd("CursorChat", function()
    require("cursor").chat()
  end, {})

  cmd("CursorClose", function()
    require("cursor").close()
  end, {})

  cmd("CursorToggle", function()
    require("cursor").toggle()
  end, {})

  cmd("CursorFocus", function()
    require("cursor").focus()
  end, {})

  cmd("CursorFocusChat", function()
    require("cursor").focus_chat()
  end, {})

  cmd("CursorFocusCode", function()
    require("cursor").focus_code()
  end, {})

  cmd("CursorAsk", function(opts)
    local prompt = opts.args
    if opts.range > 0 then
      local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
      local selection = table.concat(lines, "\n")
      if prompt == "" then
        prompt = "Explain the selected code."
      end
      require("cursor.ui").ensure_started(function(ok)
        if not ok then
          return
        end
        require("cursor.ui").open()
        local ctx = require("cursor.context")
        local text = ctx.build_prompt(prompt, {
          file = vim.api.nvim_buf_get_name(0),
          cwd = require("cursor.project").root(),
          selection = { text = selection, start_line = opts.line1, end_line = opts.line2 },
        })
        local layout = require("cursor.ui.layout")
        if layout.input_buf then
          vim.api.nvim_buf_set_lines(layout.input_buf, 0, -1, false, vim.split(text, "\n"))
        end
        layout.focus_input()
      end)
    else
      require("cursor").ask(prompt)
    end
  end, { nargs = "?", range = true })

  cmd("CursorCancel", function()
    require("cursor").cancel()
  end, {})

  cmd("CursorSessionNew", function()
    require("cursor.ui").ensure_started(function(ok)
      if ok then
        require("cursor.session").new(function()
          vim.notify("[cursor] New session created", vim.log.levels.INFO)
        end)
      end
    end)
  end, {})

  cmd("CursorSessionResume", function(opts)
    local id = opts.args
    if id == "" then
      vim.notify("[cursor] Usage: :CursorSessionResume <id>", vim.log.levels.WARN)
      return
    end
    require("cursor.ui").ensure_started(function(ok)
      if ok then
        require("cursor.session").resume(id)
      end
    end)
  end, { nargs = 1 })

  cmd("CursorChats", function()
    require("cursor.ui.picker").open_chats()
  end, {})

  cmd("CursorModel", function(opts)
    local name = opts.args
    if name ~= "" then
      require("cursor.ui.picker").open({ tab = "model", apply_name = name })
    else
      require("cursor.ui.picker").open({ tab = "model" })
    end
  end, { nargs = "?" })

  cmd("CursorEffort", function()
    require("cursor.ui.picker").open({ tab = "effort" })
  end, {})

  cmd("CursorMode", function()
    require("cursor.ui.picker").open({ tab = "mode" })
  end, {})

  cmd("CursorAbout", function()
    require("cursor.auth").about(function(stdout)
      vim.notify(stdout or "no output", vim.log.levels.INFO)
    end)
  end, {})
end

return M
