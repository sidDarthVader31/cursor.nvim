-- Tool activity is rendered inside chat.lua (single pass).
local chat = require("cursor.ui.chat")

local M = {}

function M.render()
  chat.render()
end

return M
