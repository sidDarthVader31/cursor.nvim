local M = {}

---@param excluded table<number, boolean> line indices (0-based) to skip
function M.apply(buf, ns, excluded)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  excluded = excluded or {}
  local line_count = vim.api.nvim_buf_line_count(buf)
  for line_idx = 0, line_count - 1 do
    if excluded[line_idx] then
      goto continue
    end
    local line = vim.api.nvim_buf_get_lines(buf, line_idx, line_idx + 1, false)[1] or ""
    if line == "" then
      goto continue
    end

    -- Fenced code fence lines
    if line:match("^```") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
        end_col = #line,
        hl_group = "CursorMdFence",
        strict = false,
      })
      goto continue
    end

    -- Headings
    local heading = line:match("^(#{1,6})%s+(.+)$")
    if heading then
      local hashes = line:match("^(#{1,6})")
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
        end_col = #hashes,
        hl_group = "CursorMdHeading",
        strict = false,
      })
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, #hashes, {
        end_col = #line,
        hl_group = "CursorMdHeading",
        strict = false,
      })
      goto continue
    end

    -- Horizontal rule
    if line:match("^%s*([-*_])%1%1+%s*$") then
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
        end_col = #line,
        hl_group = "CursorMdHr",
        strict = false,
      })
      goto continue
    end

    -- Blockquote
    local bq = line:match("^(%s*>%s?)")
    if bq then
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
        end_col = #bq,
        hl_group = "CursorMdQuote",
        strict = false,
      })
    end

    -- Unordered list marker
    local ul = line:match("^(%s*[-*+]%s+)")
    if ul then
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
        end_col = #ul,
        hl_group = "CursorMdList",
        strict = false,
      })
    end

    -- Ordered list marker
    local ol = line:match("^(%s*%d+%.%s+)")
    if ol then
      vim.api.nvim_buf_set_extmark(buf, ns, line_idx, 0, {
        end_col = #ol,
        hl_group = "CursorMdList",
        strict = false,
      })
    end

    -- Inline patterns: code, bold, italic (order matters)
    M._inline(buf, ns, line_idx, line, "`[^`]+`", "CursorMdCode")
    M._inline(buf, ns, line_idx, line, "%*%*[^%*]+%*%*", "CursorMdBold")
    M._inline(buf, ns, line_idx, line, "%*[^%*]+%*", "CursorMdItalic")
    M._inline(buf, ns, line_idx, line, "__[^_]+__", "CursorMdBold")
    M._inline(buf, ns, line_idx, line, "_[^_]+_", "CursorMdItalic")

    ::continue::
  end
end

function M._inline(buf, ns, line_idx, line, pattern, hl)
  local start = 1
  while start <= #line do
    local s, e = line:find(pattern, start)
    if not s then
      break
    end
    vim.api.nvim_buf_set_extmark(buf, ns, line_idx, s - 1, {
      end_col = e,
      hl_group = hl,
      strict = false,
    })
    start = e + 1
  end
end

return M
