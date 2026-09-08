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
- [Cursor Agent CLI](https://cursor.com/docs/cli/overview) (`agent` binary)
- A Cursor account (org SSO supported via browser login)

## Install Cursor CLI

```bash
curl https://cursor.com/install -fsS | bash
```

Verify in your **terminal** (not Neovim yet):

```bash
which agent
agent --version
```

Typical install location: `~/.local/bin/agent`

## Install the plugin

```lua
-- lazy.nvim
{
  "yourname/cursor.nvim",
  config = function()
    require("cursor").setup({
      auto_start = false,
      mappings_enabled = true,
      mappings = {
        chat = "<leader>cc",
        toggle = "<leader>ct",
        ask = "<leader>ca",
        cancel = "<leader>cx",
        focus = "<leader>cf",
        focus_chat = "<leader>ch",
        focus_code = "<leader>cb",
      },
    })
  end,
}
```

You usually **do not** need to set `agent_path` manually — see below.

## Finding `agent` automatically

On `setup()`, cursor.nvim resolves the CLI in this order:

1. `agent_path` in your config (if you set it)
2. `agent` on Neovim's `PATH` (`vim.fn.exepath`)
3. Common install locations (`~/.local/bin/agent`, `~/.cursor/bin/agent`, Homebrew paths, …)
4. Your **login shell** (`sh -lc 'command -v agent'`) — fixes GUI Neovim not inheriting terminal `PATH`

This is enabled by default (`auto_resolve_agent = true`). After setup, run `:CursorHealth` — it should show the resolved path.

### When auto-resolve fails

If `:CursorHealth` says agent not found, set the path explicitly:

```bash
# In your terminal:
which agent
# e.g. /Users/you/.local/bin/agent
```

```lua
require("cursor").setup({
  agent_path = vim.fn.expand("~/.local/bin/agent"), -- paste output of `which agent`
})
```

> **Note:** `vim.fn.expand("which agent")` does **not** work — `expand` only expands `~` and env vars, it does not run shell commands. Use `which agent` in your terminal, or rely on auto-resolve.

To disable shell lookup:

```lua
require("cursor").setup({
  auto_resolve_agent = false,
  agent_path = "/full/path/to/agent",
})
```

## Quick start

```vim
:CursorHealth         " confirm agent path is found
:CursorLogin          " SSO / browser auth (once per machine)
:CursorRestart        " start ACP after login
:CursorChat           " open chat panel
```

In the chat input:

- **Enter** — send message
- **Shift+Enter** — new line
- **Ctrl+w h** — back to code (split layout)

```vim
:CursorModel          " pick model + effort + mode
:CursorAsk Explain this function
:checkhealth cursor
```

### Recommended mappings (opt-in)

Mappings are **not** set unless you enable them:

```lua
require("cursor").setup({
  mappings_enabled = true,
  mappings = {
    chat = "<leader>cc",
    toggle = "<leader>ct",
    ask = "<leader>ca",
    cancel = "<leader>cx",
    focus = "<leader>cf",
    focus_chat = "<leader>ch",
    focus_code = "<leader>cb",
  },
})
```

Or set them manually:

```lua
vim.keymap.set("n", "<leader>cc", "<cmd>CursorChat<cr>")
vim.keymap.set("n", "<leader>ct", "<cmd>CursorToggle<cr>")
vim.keymap.set("n", "<leader>ca", "<cmd>CursorAsk<cr>")
vim.keymap.set("v", "<leader>ca", "<cmd>CursorAsk<cr>")
vim.keymap.set("n", "<leader>cm", "<cmd>CursorModel<cr>")
vim.keymap.set("n", "<leader>cf", "<cmd>CursorFocus<cr>")
vim.keymap.set("n", "<leader>cx", "<cmd>CursorCancel<cr>")
```

## Authentication (org SSO)

The plugin does **not** store Cursor credentials. Authentication is delegated to the CLI:

1. `:CursorLogin` — runs `agent login` in a **real Neovim terminal** so your browser can open for SSO
2. `:CursorLogin!` — runs `NO_OPEN_BROWSER=1 agent login`, streams output into a float, and shows the login URL to copy
3. `CURSOR_API_KEY` — for automation / CI (read from environment only)

After login: `:CursorRestart`.

If the browser still does not open (remote SSH, headless, etc.), use `:CursorLogin!` and open the printed URL manually.

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
| `:CursorFocus` / `:CursorFocusChat` / `:CursorFocusCode` | Focus input / history / code |
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

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ENOENT: no such file or directory (cmd): 'agent'` | Run `which agent` in terminal; set `agent_path` in setup |
| `:CursorChat` opens but agent won't start | `:CursorLogin` then `:CursorRestart` |
| `:CursorModel` shows Internal error | Run `:CursorRestart` after login; ensure a session is active |
| Keymaps don't update after config change | Set `mappings_enabled = true` and call `require("cursor").reload()` |
| `:CursorChats` is empty | Chats are read from `~/.cursor/chats` for the current project; run `agent` in this directory first |
| Browser doesn't open on login | `:CursorLogin!` and copy the URL |
| Commands do nothing | `:CursorHealth` — check agent path |

## Development

```bash
make test                              # run all headless tests
make test-file FILE=tests/unit/foo.lua # run one spec file
make smoke                             # quick load check
```

Tests use a fake ACP agent (`tests/fake_agent.sh`) so CI does not need the real `agent` binary.

## License

MIT — see [LICENSE](LICENSE). This license applies to cursor.nvim source only, not to Cursor's services.
