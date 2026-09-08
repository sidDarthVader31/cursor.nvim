local M = {}

function M.should_include_full_buffer()
  return false
end

function M.validate_prompt(text)
  if not text or vim.trim(text) == "" then
    return false, "Prompt is empty"
  end
  return true
end

function M.coalesce_assistant_flush_ms()
  local config = require("cursor.config")
  return config.get().ui_flush_ms or 30
end

return M
