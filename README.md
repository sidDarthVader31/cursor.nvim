# cursor.nvim

A Neovim plugin that brings a Cursor-like AI coding experience **inside Neovim**, powered by the official [Cursor Agent CLI](https://cursor.com/docs/cli/overview) over [ACP](https://cursor.com/docs/cli/acp).

**This plugin requires the official Cursor Agent CLI and uses your Cursor entitlement.** Usage is billed to your Cursor account—the same pool as Cursor desktop. Running the same task in both Neovim and Cursor will double-spend.

## Features

- Native Neovim chat sidebar (no Telescope / nui required)
- ACP client for `agent acp` (streaming, tools, permissions)
- SSO login via `:CursorLogin` (`agent login` + corporate IdP)
- Mason-inspired model/effort/mode picker (`:CursorModel`)
- Session list and resume (`:CursorChats`)
- Lean context: file path + cursor + selection (never full-buffer dumps by default)
- Project-root filesystem sandbox for ACP client methods

## Requirements

- Neovim **0.11+**
- [Cursor Agent CLI](https://cursor.com/docs/cli/overview) (`agent` on `$PATH`)
- A Cursor account (org SSO supported via browser login)

## Install

```lua
-- lazy.nvim
{
  "yourname/cursor.nvim",
  config = function()
    require("cursor").setup({
      auto_start = false, -- do not spawn agent on Neovim startup
    })
  end,
}
```

## Quick start

```vim
:CursorLogin          " SSO / browser auth (once per machine)
:CursorChat           " open chat panel
:CursorModel          " pick model + effort + mode
:CursorAsk Explain this function
:CursorHealth         " diagnostics
:checkhealth cursor   " Neovim health framework
```

### Recommended mappings (not set by default)

```lua
vim.keymap.set("n", "<leader>cc", "<cmd>CursorChat<cr>")
vim.keymap.set("n", "<leader>ct", "<cmd>CursorToggle<cr>")
vim.keymap.set("n", "<leader>ca", "<cmd>CursorAsk<cr>")
vim.keymap.set("v", "<leader>ca", "<cmd>CursorAsk<cr>")
vim.keymap.set("n", "<leader>cm", "<cmd>CursorModel<cr>")
vim.keymap.set("n", "<leader>cx", "<cmd>CursorCancel<cr>")
```

## Authentication (org SSO)

The plugin does **not** store Cursor credentials. Authentication is delegated to the CLI:

1. `:CursorLogin` — opens browser SSO flow (`agent login`)
2. `:CursorLogin!` — print URL without opening browser (`NO_OPEN_BROWSER=1`)
3. `CURSOR_API_KEY` — for automation / CI (read from environment only)

After login: `:CursorRestart`.

## Token usage

- Same backend, same billing as Cursor desktop/CLI.
- `auto_start = false` — agent does not start until you ask.
- Prompts include pointers (path, cursor, selection), not whole files.
- Prefer **medium** effort and fresh sessions for unrelated tasks.
- Do not run the same task in Cursor desktop and Neovim simultaneously.

## Commands

| Command | Description |
|---------|-------------|
| `:CursorLogin` / `:CursorLogout` | Browser SSO login / logout |
| `:CursorAuthStatus` | Show `agent status` |
| `:CursorStart` / `:CursorStop` / `:CursorRestart` | ACP process lifecycle |
| `:CursorChat` / `:CursorClose` / `:CursorToggle` | Chat panel |
| `:CursorAsk [prompt]` | Context-aware question |
| `:CursorCancel` | Cancel active prompt |
| `:CursorChats` | Session picker |
| `:CursorSessionNew` / `:CursorSessionResume` | Session management |
| `:CursorModel` / `:CursorEffort` / `:CursorMode` | Config picker (m/e/o tabs) |
| `:CursorHealth` / `:checkhealth cursor` | Diagnostics |

## Model picker keys

Inside `:CursorModel`:

- `m` / `e` / `o` — switch Model / Effort / Mode tabs
- `/` — filter models
- `j` / `k` — move
- `<CR>` — apply (window stays open)
- `q` — close

## License

MIT — see [LICENSE](LICENSE). This license applies to cursor.nvim source only, not to Cursor's services.
