local acp = require("cursor.acp")
local context = require("cursor.context")
local state = require("cursor.state")
local usage = require("cursor.usage")

local M = {}

function M.setup(buf)
  vim.api.nvim_buf_set_keymap(buf, "i", "<C-CR>", "", {
    noremap = true,
    silent = true,
    callback = function()
      M.submit()
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "", {
    noremap = true,
    silent = true,
    callback = function()
      acp.session_cancel()
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    end,
  })
end

function M.get_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
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

  state.add_message({ role = "user", content = text })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  require("cursor.ui").refresh()

  acp.session_prompt(text, function(_, prompt_err)
    if prompt_err then
      vim.notify("[cursor] " .. (prompt_err.message or "prompt failed"), vim.log.levels.ERROR)
    end
  end)
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
