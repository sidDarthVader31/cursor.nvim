# cursor.nvim — Implementation Plan

## 0. Mission

Build a Neovim plugin that gives a Neovim-first user a Cursor-like AI coding experience **inside Neovim**, while using the official Cursor Agent CLI as the AI/agent backend.

The primary motivation is practical:

- Keep Neovim as the editor and preserve Vim muscle memory.
- Use the organization's existing Cursor entitlement rather than paying for or wiring a separate LLM provider.
- Get a persistent chat/agent panel inside Neovim.
- Let Cursor Agent inspect the repository, edit files, run commands, and stream progress.
- Make the integration feel native to Neovim rather than opening Cursor separately.

### Core architectural decision

**Do not implement an LLM client. Do not call a model API directly. Do not reimplement Cursor's agent.**

The plugin should be an **ACP client**:

```text
                 Neovim
                   │
                   │ cursor.nvim
                   │ ACP client
                   ▼
        ┌─────────────────────┐
        │  Cursor Agent CLI   │
        │     `agent acp`     │
        └─────────────────────┘
                   │
                   ▼
          Cursor's agent/model
                   │
          ┌────────┴────────┐
          ▼                 ▼
       project FS        terminal
```

Cursor officially supports running its Agent CLI as an ACP server, specifically so external editors can integrate with the Cursor agent. The official Cursor documentation describes spawning `agent acp`, communicating over stdio/JSON-RPC, receiving `session/update` events, and handling permission requests. ACP itself is an editor↔agent protocol designed for exactly this use case.

The plugin therefore owns:

1. Neovim UI.
2. ACP transport.
3. ACP message routing.
4. User interaction and permissions.
5. Mapping Neovim context into prompts.
6. Session/UI state.
7. Rendering agent activity.
8. Optional Neovim-native conveniences.

Cursor Agent owns:

1. Model selection.
2. Agent reasoning.
3. Repository search.
4. File editing.
5. Terminal execution.
6. Cursor-side MCP/tool configuration.
7. Agent session semantics.

---

# 1. Research conclusions

## 1.1 Existing Cursor integration

The closest existing project is `h4kbas/cursor.nvim`.

It is particularly valuable as a reference because it already implemented:

- ACP communication with Cursor Agent.
- Streaming responses.
- Multi-panel chat UI.
- Permission prompts.
- File/terminal operations.
- Affected-files display.
- Queuing.
- Sessions.
- Checkpoints/revert.
- Cursor CLI integration.

However, the repository was archived on July 27, 2026. It should therefore be treated as **reference material, not a dependency or upstream base**.

Reference:

- https://github.com/h4kbas/cursor.nvim

The implementation should be independently designed and should avoid copying large sections of its code. Read it to understand edge cases and UX ideas.

## 1.2 Existing alternatives

### avante.nvim

`avante.nvim` explicitly aims to emulate Cursor in Neovim and now supports ACP, including Cursor Agent.

It is a useful architectural reference, but this project should not simply wrap Avante.

Why build independently:

- We want a much smaller, Cursor-specific plugin.
- The UI/UX should be designed around Neovim and Cursor Agent rather than supporting many providers.
- Fewer abstractions means easier debugging.
- The goal is to understand and own the ACP integration.

Reference:

- https://github.com/yetone/avante.nvim

### codecompanion.nvim

CodeCompanion is another mature Neovim AI assistant with ACP support and support for multiple agents.

Reference:

- https://github.com/olimorris/codecompanion.nvim

Use it as a reference for Neovim AI UX and ACP patterns, but do not make it a runtime dependency.

## 1.3 Cursor's current agent model

Cursor Agent consists conceptually of:

- instructions/rules
- tools
- model

Cursor's tools include file search, file reading, editing, terminal execution, web access, and MCP integrations.

The Cursor CLI supports:

- interactive agent mode
- ask mode
- plan mode
- session resume
- non-interactive execution
- MCP
- project rules

The plugin should expose the useful subset of these capabilities without trying to reproduce Cursor's desktop UI.

Relevant official documentation:

- https://cursor.com/docs/agent/overview
- https://cursor.com/docs/cli/overview
- https://cursor.com/docs/cli/using
- https://cursor.com/docs/cli/acp

## 1.4 ACP

ACP is the correct integration boundary.

Current ACP documentation describes:

- JSON-RPC 2.0 messages.
- Client → Agent initialization.
- Authentication when required.
- Session creation/resume.
- Prompt submission.
- Streaming `session/update` notifications.
- Cancellation.
- Agent → Client permission requests.
- Agent → Client filesystem requests.
- Agent → Client terminal requests.

The current stable ACP wire protocol version is 1. The protocol is capability-negotiated, so the implementation must not blindly assume every optional feature exists.

References:

- https://github.com/agentclientprotocol/agent-client-protocol
- https://github.com/agentclientprotocol/agent-client-protocol/blob/main/docs/protocol/v1/overview.mdx
- https://github.com/agentclientprotocol/agent-client-protocol/blob/main/schema/v1/schema.json

## 1.5 Neovim APIs make this implementation straightforward

Target **Neovim 0.11+**.

Important built-in facilities:

- `vim.system()` for spawning and communicating with `agent acp`.
- `vim.SystemObj:write()` for stdin.
- asynchronous stdout/stderr callbacks.
- `vim.api.nvim_create_buf()`.
- `vim.api.nvim_open_win()` for floating UI.
- extmarks for tracking buffer locations.
- `vim.ui.input()` and `vim.ui.select()` for lightweight interaction.
- `vim.fs` for filesystem helpers.
- `vim.json` for JSON encoding/decoding.
- `vim.uv` if lower-level stream/process control is ever needed.

This means the MVP can be implemented with **zero mandatory third-party Neovim dependencies**.

---

# 2. Product definition

Call the plugin `cursor.nvim`.

The MVP should feel like:

```text
┌───────────────────────────────────────────────────────────────┐
│                         Neovim                                │
│                                                               │
│  ┌───────────────────────────────┬───────────────────────────┐ │
│  │                               │ Cursor Agent              │ │
│  │                               │                           │ │
│  │       normal code             │ You:                     │ │
│  │                               │ Fix the retry logic...    │ │
│  │                               │                           │ │
│  │                               │ Agent:                    │ │
│  │                               │ I'll inspect...           │ │
│  │                               │                           │ │
│  │                               │ > Reading foo.go         │ │
│  │                               │ > Editing retry.go       │ │
│  │                               │ > Running tests           │ │
│  │                               │                           │ │
│  │                               │ ───────────────────────── │ │
│  │                               │ [ type message... ]       │ │
│  └───────────────────────────────┴───────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

The user should not need to leave Neovim for normal AI coding work.

---

# 3. MVP scope

The first release must implement only the following.

## 3.1 Required

### A. Start/stop Cursor Agent

Plugin command:

```vim
:CursorStart
:CursorStop
:CursorRestart
```

The plugin should:

1. Verify that `agent` exists in `$PATH`.
2. Start:

```bash
agent acp
```

3. Set the working directory to the detected project root.
4. Keep stdin/stdout connected.
5. Parse ACP messages.
6. Shut down cleanly.

Do not use `cursor-agent --print` as the primary transport.

Use ACP.

### B. Chat window

Command:

```vim
:CursorChat
```

Open a right-side panel.

Default width:

```text
40% of editor width
```

The panel should contain:

1. Chat/history area.
2. Input area.

Do not initially build four separate complicated panels.

MVP:

```text
┌──────────────────────────┐
│ Cursor Agent             │
│                          │
│ You                      │
│ Fix this bug             │
│                          │
│ Agent                    │
│ I'll inspect...          │
│                          │
│ ◌ Reading files          │
│ ◌ Editing foo.go         │
│ ✓ Tests passed           │
│                          │
│──────────────────────────│
│ > type message...        │
└──────────────────────────┘
```

### C. Streaming

When Cursor sends:

```text
session/update
```

with assistant message chunks, append the text incrementally.

Do not wait for the entire response.

The UI must feel like a live chat.

### D. Agent tool activity

Render tool activity in a compact, collapsible-looking style.

Examples:

```text
◌ Read src/server.go
◌ Search "retry"
◌ Edit src/client.go
◌ Run go test ./...
✓ go test ./...
```

The plugin should maintain a mapping:

```text
toolCallId -> tool state
```

and update the display as `tool_call` / `tool_call_update` events arrive.

### E. Permission requests

When the agent requests permission:

```text
session/request_permission
```

show a Neovim-native confirmation UI.

Example:

```text
Cursor wants to:

Run:
  npm test

Options:
  [a] Allow once
  [s] Allow for session
  [d] Deny
  [q] Cancel
```

Do not auto-approve everything.

Default behavior should be safe.

### F. Send prompts

Input:

```text
<CR>
```

submits the current input.

Support multiline input.

Suggested default:

```text
<C-CR>  submit
<C-c>   cancel/clear
```

If terminal limitations make `<C-CR>` unreliable, use `<C-s>` or another configurable mapping.

### G. Cancel

Command:

```vim
:CursorCancel
```

and a default keybinding inside the chat:

```text
<C-c>
```

should send:

```text
session/cancel
```

and update the UI.

### H. Session

MVP must support at least:

- one active ACP session per project
- new session
- session resume if Cursor advertises the capability

Commands:

```vim
:CursorSessionNew
:CursorSessionResume
```

Do not build a sophisticated session manager until the basic session lifecycle is reliable.

### I. Current buffer context

The plugin should be able to send the following context explicitly:

- current file path
- current working directory/project root
- current cursor location
- visual selection

Commands:

```vim
:CursorAsk
```

should default to current context.

Example prompt internally:

```text
User request:
Explain this function.

Current editor context:
File: /repo/src/foo.go
Cursor: line 143, column 17

Selected text:
...
```

However, **do not blindly send the entire current buffer** on every prompt.

Cursor Agent already has filesystem/repository tools.

Use explicit context only when the user requests it or when the command semantics require it.

---

# 4. UX design

## 4.1 Commands

Implement these first:

```text
:CursorChat
:CursorClose
:CursorStart
:CursorStop
:CursorRestart
:CursorAsk [prompt]
:CursorCancel
:CursorSessionNew
:CursorSessionResume
:CursorHealth
```

Later:

```text
:CursorToggle
:CursorFocus
:CursorModel
:CursorMode
:CursorHistory
```

## 4.2 Default mappings

Do not impose global mappings automatically.

Expose recommended mappings through configuration.

Example:

```lua
vim.keymap.set("n", "<leader>cc", "<cmd>CursorChat<cr>")
vim.keymap.set("n", "<leader>ca", "<cmd>CursorAsk<cr>")
vim.keymap.set("v", "<leader>ca", "<cmd>CursorAsk<cr>")
vim.keymap.set("n", "<leader>cx", "<cmd>CursorCancel<cr>")
```

## 4.3 Visual selection

For visual mode:

```vim
:'<,'>CursorAsk
```

should capture the selected text.

The command should not modify the user's buffer just to obtain context.

Use Neovim APIs to read the selected range.

## 4.4 Chat buffer

Use a scratch buffer.

Recommended:

```lua
buftype = "nofile"
bufhidden = "hide"
swapfile = false
modifiable = false
```

The input buffer should be separate and editable.

Do not mix chat text and input text in the same buffer.

---

# 5. Architecture

Use a small modular architecture.

Suggested repository:

```text
cursor.nvim/
├── lua/
│   └── cursor/
│       ├── init.lua
│       ├── config.lua
│       ├── commands.lua
│       ├── state.lua
│       ├── project.lua
│       ├── context.lua
│       ├── transport.lua
│       ├── rpc.lua
│       ├── acp.lua
│       ├── session.lua
│       ├── permissions.lua
│       └── ui/
│           ├── init.lua
│           ├── chat.lua
│           ├── input.lua
│           ├── activity.lua
│           └── layout.lua
├── plugin/
│   └── cursor.lua
├── doc/
│   └── cursor.txt
├── tests/
│   ├── rpc_spec.lua
│   ├── context_spec.lua
│   ├── state_spec.lua
│   └── acp_spec.lua
├── README.md
├── LICENSE
├── Makefile
└── stylua.toml
```

Keep modules small.

---

# 6. State machine

Create an explicit plugin state.

Example:

```lua
local states = {
  stopped = "stopped",
  starting = "starting",
  ready = "ready",
  prompting = "prompting",
  stopping = "stopping",
  error = "error",
}
```

State should include:

```lua
{
  status = "ready",
  process = nil,
  session_id = nil,
  project_root = nil,
  rpc_next_id = 1,
  pending_requests = {},
  tool_calls = {},
  messages = {},
}
```

Do not scatter state across UI modules.

The transport layer should not know about windows.

The UI layer should not know how ACP messages are transported.

---

# 7. Process / transport layer

Implement a persistent subprocess using:

```lua
vim.system(
  { "agent", "acp" },
  {
    cwd = project_root,
    stdin = true,
    stdout = function(err, data)
      ...
    end,
    stderr = function(err, data)
      ...
    end,
  },
  on_exit
)
```

Important:

- stdout must contain only ACP protocol data.
- stderr should be captured for diagnostics.
- never block Neovim waiting for Cursor.
- all process IO must be asynchronous.
- process termination must clean up callbacks and state.

The transport must support:

```lua
transport.start(opts)
transport.send(data)
transport.stop()
transport.is_running()
```

---

# 8. JSON-RPC layer

Create a generic JSON-RPC implementation rather than putting protocol parsing inside UI code.

Responsibilities:

```lua
rpc.request(method, params, callback)
rpc.notify(method, params)
rpc.handle_message(message)
```

Maintain:

```lua
pending_requests[id] = callback
```

For incoming agent requests, route by method:

```text
session/request_permission
fs/read_text_file
fs/write_text_file
terminal/create
terminal/output
terminal/wait_for_exit
terminal/kill
terminal/release
```

Do not implement every ACP method blindly.

Advertise only capabilities the plugin actually implements.

---

# 9. ACP lifecycle

Implement the lifecycle in this order.

## 9.1 Initialize

Send:

```text
initialize
```

with:

```text
protocolVersion: 1
```

and client information.

Advertise only supported client capabilities.

Store:

```text
protocol version
agent capabilities
authentication methods
```

Do not assume protocol features without checking capabilities.

## 9.2 Authentication

Cursor's current CLI can authenticate using Cursor login.

The plugin should not implement Cursor authentication itself.

If `agent acp` reports authentication requirements:

1. Tell the user.
2. Provide a command/help message telling them to run Cursor's CLI login.
3. Do not collect or store Cursor credentials in the plugin.

Example:

```text
Cursor Agent is not authenticated.

Run:
  agent login

Then run:
  :CursorRestart
```

## 9.3 Create session

Send:

```text
session/new
```

using the project root as `cwd`.

Persist the returned `sessionId` in memory.

## 9.4 Prompt

Send:

```text
session/prompt
```

with text content.

While the prompt is running, process asynchronous:

```text
session/update
```

notifications.

## 9.5 Completion

Handle the response from `session/prompt`.

Display a final state:

```text
✓ Completed
```

or an appropriate failure/cancelled state.

## 9.6 Cancel

Send:

```text
session/cancel
```

for the active session.

---

# 10. Incoming ACP messages

Build a dispatcher.

At minimum:

```text
session/update
session/request_permission
```

and JSON-RPC responses.

## 10.1 session/update

Support these first:

```text
agent_message_chunk
agent_thought_chunk
tool_call
tool_call_update
plan
available_commands_update
```

Do not fail if an unknown update arrives.

Instead:

```text
log/debug -> ignore unknown event
```

The plugin must be forward-compatible.

## 10.2 agent_message_chunk

Append text to the active assistant message.

Avoid rebuilding the entire chat buffer for every token.

Use buffered UI updates if necessary.

For example:

```text
flush assistant text every 20-50ms
```

This prevents excessive redraws.

## 10.3 tool_call

Create:

```lua
tool_calls[tool_call_id] = {
  id = ...,
  kind = ...,
  status = ...,
  title = ...,
}
```

Render it in the activity section.

## 10.4 tool_call_update

Update the existing entry.

Possible states:

```text
pending
in_progress
completed
failed
```

Display:

```text
◌ Running tests
✓ Running tests
✗ Running tests
```

## 10.5 plan

If Cursor emits a plan, show it in the chat/activity area.

Do not attempt to reproduce Cursor's entire Plan UI in MVP.

---

# 11. Agent → Neovim requests

This is critical.

ACP allows the agent to ask the editor/client to perform operations.

## 11.1 Filesystem

Implement:

```text
fs/read_text_file
fs/write_text_file
```

Security rule:

Only allow access under the active project root unless configuration explicitly allows otherwise.

Before resolving a path:

1. convert to absolute path
2. normalize it
3. verify it is within the project root
4. reject path traversal

Be careful with symlinks.

For MVP, document the policy clearly and prefer rejecting ambiguous/outside-root paths.

## 11.2 Terminal

Implement:

```text
terminal/create
terminal/output
terminal/wait_for_exit
terminal/kill
terminal/release
```

Use Neovim's asynchronous process APIs.

Do not use `vim.fn.system()`.

Do not block the UI.

Maintain:

```lua
terminals[id] = {
  process = ...,
  output = ...,
  exit_code = ...,
}
```

This is a major part of making the integration agentic rather than just chat.

## 11.3 Permissions

The permission system should be centralized.

```lua
permissions.request(tool_call, options, callback)
```

Never let arbitrary agent requests directly execute user-sensitive actions without going through the permission policy.

Configuration should eventually support:

```lua
permissions = {
  default = "ask",
  terminal = "ask",
  file_write = "ask",
}
```

For MVP, always ask when Cursor asks.

---

# 12. Context system

Create:

```text
lua/cursor/context.lua
```

API:

```lua
context.current_buffer()
context.visual_selection()
context.cursor_position()
context.project_root()
context.build_prompt(...)
```

Return structured data rather than one giant string.

Example:

```lua
{
  cwd = "...",
  file = "...",
  cursor = {
    line = 143,
    column = 17,
  },
  selection = {
    start_line = 140,
    end_line = 150,
    text = "...",
  },
}
```

The prompt builder can then decide what to include.

Do not send full file contents by default.

---

# 13. Project root detection

Implement a project root resolver.

Priority:

1. Git root.
2. Existing project markers.
3. Current working directory.

At minimum:

```text
.git
```

should be recognized.

Do not rely solely on `vim.fn.getcwd()` because users commonly launch Neovim from outside the repository.

Provide:

```lua
project.root()
```

and cache it per session.

---

# 14. UI implementation

Start with native Neovim floating windows.

Do not add `nui.nvim` as a mandatory dependency.

Layout:

```text
right sidebar
    ├── chat buffer
    └── input buffer
```

Use:

```lua
vim.api.nvim_create_buf()
vim.api.nvim_open_win()
```

The chat window should be:

- non-focus stealing when possible
- scrollable
- closable
- resizable
- reopenable without losing session state

## 14.1 Window lifecycle

Implement:

```lua
ui.open()
ui.close()
ui.toggle()
ui.focus()
ui.is_open()
ui.refresh()
```

The UI should be reconstructable from state.

Never make the UI the source of truth.

If the chat window is closed and reopened, the conversation should remain available.

---

# 15. Chat rendering

Represent messages internally:

```lua
{
  {
    role = "user",
    content = "...",
  },
  {
    role = "assistant",
    content = "...",
  },
  {
    role = "tool",
    tool_id = "...",
    title = "...",
    status = "completed",
  },
}
```

Render these into the chat buffer.

Use simple markdown-compatible text initially.

Do not depend on a markdown rendering plugin.

Later optionally integrate:

```text
render-markdown.nvim
```

but keep it optional.

---

# 16. Input handling

The input buffer should support:

- multiline text
- submit
- clear
- cancel
- focus switching

Suggested:

```text
<C-CR>  submit
<C-c>   cancel/close
```

Provide configurable mappings.

The user's existing insert-mode muscle memory must not be disrupted outside the chat window.

---

# 17. Sessions

The ACP session should be treated as the source of conversation continuity.

MVP:

```text
project -> active session
```

Later:

```text
project
  ├── session A
  ├── session B
  └── session C
```

Do not duplicate the entire Cursor conversation in local files unless ACP requires it.

If ACP supports resume/load, use the agent's session functionality.

If a Cursor version does not support a requested session operation:

- detect capability
- degrade gracefully
- tell the user what is unsupported

Never fabricate session persistence.

---

# 18. Error handling

Every failure should produce a useful Neovim message.

Examples:

```text
[Cursor] `agent` executable not found.
Install Cursor CLI and ensure `agent` is in PATH.
```

```text
[Cursor] Agent process exited unexpectedly (code 1).
Check :messages and `:CursorHealth`.
```

```text
[Cursor] ACP protocol error: session/prompt failed.
```

Do not swallow errors.

Add debug logging.

Configuration:

```lua
log_level = "warn" -- trace/debug/info/warn/error
```

Default:

```text
warn
```

---

# 19. Health check

Implement:

```vim
:CursorHealth
```

It should report:

```text
cursor.nvim health
───────────────────
✓ Neovim version: 0.11.x
✓ agent executable: ~/.local/bin/agent
✓ Cursor CLI version: ...
✓ Cursor authentication: available/unknown/missing
✓ project root: /repo
✓ ACP process: running/stopped
✓ ACP protocol: 1
✓ active session: yes/no
```

Use the standard Neovim health framework eventually:

```text
:checkhealth cursor
```

---

# 20. Configuration

API:

```lua
require("cursor").setup({
  agent_command = "agent",
  agent_args = { "acp" },

  width = 0.40,

  border = "rounded",

  auto_start = false,

  project_root = nil,

  log_level = "warn",

  permissions = {
    default = "ask",
  },

  mappings = {
    chat = "<leader>cc",
    ask = "<leader>ca",
    cancel = "<leader>cx",
  },
})
```

Do not over-configure the first version.

Every option needs a reason.

---

# 21. Important non-goals

Do NOT implement these in MVP:

- Direct OpenAI/Anthropic API integration.
- Model API key management.
- Custom LLM provider abstraction.
- RAG/vector database.
- Repository embedding.
- Custom semantic search.
- Reimplementation of Cursor's agent.
- Full Cursor desktop UI clone.
- Automatic code completion.
- Inline ghost text.
- AI autocomplete.
- MCP implementation.
- Cloud synchronization.
- Complex persistent local chat storage.
- Plugin marketplace.
- Multi-agent orchestration.

Cursor Agent already provides most agent capabilities.

The plugin is an editor client.

---

# 22. MVP implementation phases

## Phase 0 — Repository skeleton

Create:

```text
lua/cursor/
plugin/
doc/
tests/
```

Add:

- README
- LICENSE
- Makefile
- stylua config
- test runner

Acceptance:

```text
nvim --headless +'lua require("cursor")' +qa
```

works.

---

## Phase 1 — Process transport

Implement:

- `agent` discovery
- `agent acp` spawn
- async stdout
- stderr
- stdin write
- process lifecycle

Add a debug command:

```vim
:CursorStart
```

Acceptance:

1. Agent starts.
2. No Neovim freeze.
3. Agent output is captured.
4. Agent can be stopped.
5. Agent restart works.

---

## Phase 2 — JSON-RPC

Implement:

- request IDs
- pending callbacks
- notifications
- responses
- errors
- parsing

Add tests using mocked input.

Acceptance:

```text
request -> matching response callback
notification -> notification handler
error -> error callback
unknown message -> safely ignored/logged
```

---

## Phase 3 — ACP handshake

Implement:

```text
initialize
session/new
```

Acceptance:

```text
:CursorStart
```

results in:

```text
ACP initialized
Session created
```

and a stored `session_id`.

Do not build UI yet.

---

## Phase 4 — Minimal chat

Implement:

```text
:CursorChat
```

with:

- chat buffer
- input buffer
- submit
- `session/prompt`
- streamed assistant chunks

Acceptance:

User can type:

```text
Explain this repository.
```

and receive a streaming answer inside Neovim.

---

## Phase 5 — Tool activity

Implement:

```text
tool_call
tool_call_update
```

Acceptance:

When asking:

```text
Find where authentication is implemented and explain it.
```

the UI shows activity while Cursor searches/reads the repository.

---

## Phase 6 — Permission requests

Implement:

```text
session/request_permission
```

Acceptance:

A command requiring permission results in an actionable UI prompt.

Test:

- allow once
- deny
- cancel
- malformed permission request

---

## Phase 7 — Filesystem + terminal

Implement ACP client methods:

```text
fs/read_text_file
fs/write_text_file

terminal/create
terminal/output
terminal/wait_for_exit
terminal/kill
terminal/release
```

Acceptance:

Ask Cursor:

```text
Create a file called /tmp? 
```

This should be constrained by project-root policy.

Then test an in-project task:

```text
Add a small function and run the tests.
```

The agent should be able to read/write/run commands through ACP.

---

## Phase 8 — Context

Implement:

```text
current file
visual selection
cursor position
project root
```

Commands:

```vim
:CursorAsk
```

and visual-mode usage.

Acceptance:

Select code, invoke CursorAsk, ask:

```text
What is wrong with this?
```

and verify the selected text is available to the agent.

---

## Phase 9 — Sessions

Implement:

```text
:CursorSessionNew
:CursorSessionResume
```

Only use capabilities actually advertised by the agent.

Acceptance:

1. Start session.
2. Ask question.
3. Close Neovim chat.
4. Reopen chat.
5. Session remains usable.
6. Restart agent.
7. Resume if Cursor supports it.

---

## Phase 10 — Polish

Add:

- better activity display
- scrolling
- focus management
- status indicator
- configurable mappings
- health check
- documentation
- clean shutdown
- better errors
- tests

Only after this should optional dependencies be considered.

---

# 23. Testing strategy

Do not depend entirely on a live Cursor account for tests.

Separate tests into:

## Unit tests

Mock ACP messages.

Test:

```text
JSON-RPC request matching
JSON-RPC errors
ACP notification parsing
session state transitions
tool state transitions
permission decisions
context extraction
path validation
```

## Integration tests

If `agent` exists:

```text
initialize
session/new
session/prompt
session/update
session/cancel
```

should be testable manually.

Use environment detection to skip live tests when Cursor CLI is unavailable.

## Manual smoke test

Create a tiny fixture repository:

```text
fixture/
├── README.md
├── main.lua
└── tests/
    └── main_spec.lua
```

Test:

1. Explain repository.
2. Find a function.
3. Edit a function.
4. Run tests.
5. Reject a terminal operation.
6. Cancel an agent operation.
7. Restart Neovim.
8. Reopen chat.

---

# 24. Security requirements

This plugin executes commands through an AI agent.

Treat it as a privileged integration.

Rules:

1. Never expose Cursor credentials.
2. Never log authentication tokens.
3. Never automatically approve permissions in MVP.
4. Validate file paths.
5. Keep file access constrained to project root where the ACP contract permits client-side filesystem access.
6. Do not run shell commands through a shell unless ACP explicitly requests shell semantics.
7. Use argument arrays rather than string concatenation.
8. Do not execute arbitrary commands locally merely because they appear in agent text.
9. Only execute commands as a result of ACP terminal requests.
10. Keep stderr/stdout protocol separation strict.
11. Never print debugging information to ACP stdout.

---

# 25. Performance requirements

The plugin must remain responsive while Cursor works.

Never:

```lua
vim.fn.system(...)
```

for agent work.

Never:

```lua
process:wait()
```

on the UI thread during normal interaction.

Use async APIs.

Throttle UI rendering when streaming high-frequency chunks.

Suggested approach:

```text
ACP message
    ↓
state update immediately
    ↓
schedule render
    ↓
coalesce updates for ~20-50ms
    ↓
update chat buffer
```

This avoids redrawing the entire chat for every token.

---

# 26. Compatibility

Target:

```text
Neovim >= 0.11
Lua 5.1 / LuaJIT-compatible plugin code
Cursor Agent CLI with ACP support
macOS
Linux
Windows where Neovim + Cursor CLI + process APIs support the required behavior
```

Do not use Lua 5.2+ only features.

Avoid OS-specific shell commands where possible.

---

# 27. Code quality rules

Use:

- Lua
- `vim.*` APIs
- small modules
- explicit state
- type annotations where useful
- `luacheck`
- `stylua`

Avoid:

- global variables
- hidden mutable state
- giant modules
- synchronous subprocess calls
- hardcoded paths
- hardcoded user configuration
- mandatory UI dependencies
- unnecessary abstractions

Every public function should have a clear responsibility.

---

# 28. Suggested module responsibilities

## `init.lua`

Public API:

```lua
setup()
start()
stop()
chat()
ask()
cancel()
```

## `config.lua`

Defaults + user configuration.

## `state.lua`

Single source of truth for runtime state.

## `project.lua`

Project root detection.

## `context.lua`

Neovim editor context extraction.

## `transport.lua`

Process lifecycle + raw stdin/stdout.

## `rpc.lua`

Generic JSON-RPC.

## `acp.lua`

ACP-specific protocol lifecycle and dispatch.

## `session.lua`

Session lifecycle.

## `permissions.lua`

Permission policy and UI interaction.

## `ui/layout.lua`

Window creation/destruction.

## `ui/chat.lua`

Conversation rendering.

## `ui/input.lua`

Prompt input.

## `ui/activity.lua`

Tool-call rendering.

## `commands.lua`

Neovim user commands.

---

# 29. Recommended development order inside Cursor

When Cursor is asked to implement this plan, it should **not** attempt the entire plugin in one giant change.

Work incrementally.

For every phase:

1. Inspect current repository.
2. State the implementation approach briefly.
3. Implement the smallest coherent change.
4. Add/update tests.
5. Run formatter.
6. Run tests.
7. Run a minimal Neovim headless smoke test.
8. Review the diff.
9. Only then proceed to the next phase.

Do not continue if the previous phase is broken.

---

# 30. First implementation task

The first Cursor task should be:

> Create the repository skeleton and implement Phase 0 only.
>
> Do not implement ACP yet.
>
> Set up a clean Neovim Lua plugin structure targeting Neovim 0.11+.
>
> Add:
>
> - `lua/cursor/init.lua`
> - `lua/cursor/config.lua`
> - `lua/cursor/state.lua`
> - `lua/cursor/commands.lua`
> - `plugin/cursor.lua`
> - `tests/`
> - `README.md`
> - `doc/cursor.txt`
> - `Makefile`
> - formatter/linter configuration
>
> Expose:
>
> ```vim
> :CursorHealth
> ```
>
> which reports that the plugin is loaded.
>
> Keep the implementation minimal.
>
> Do not add external dependencies.
>
> Do not implement UI.
>
> Do not implement Cursor communication.
>
> Run the available tests and a headless Neovim smoke test before finishing.

---

# 31. Second implementation task

After Phase 0 is green:

> Implement Phase 1.
>
> Build an asynchronous process manager around Neovim's `vim.system()` API.
>
> Spawn:
>
> ```text
> agent acp
> ```
>
> with the detected project root as `cwd`.
>
> Requirements:
>
> - stdin must remain writable.
> - stdout must be captured asynchronously.
> - stderr must be captured separately.
> - process exit must update plugin state.
> - start/stop/restart must be safe to call repeatedly.
> - never block Neovim.
> - never write diagnostics to stdout.
>
> Add unit tests using a fake executable/process where practical.
>
> Add:
>
> ```vim
> :CursorStart
> :CursorStop
> :CursorRestart
> ```
>
> Do not implement ACP JSON-RPC yet.

---

# 32. Third implementation task

> Implement the generic JSON-RPC layer.
>
> Requirements:
>
> - JSON encode/decode using Neovim's built-in facilities.
> - request IDs.
> - pending request callbacks.
> - notifications.
> - responses.
> - errors.
> - unknown messages must not crash the plugin.
> - transport and UI must remain completely decoupled.
>
> Add comprehensive unit tests with mocked messages.
>
> Do not implement Cursor-specific behavior yet.

---

# 33. Fourth implementation task

> Implement ACP v1 lifecycle against Cursor Agent.
>
> Use the current ACP schema as the source of truth.
>
> Implement:
>
> ```text
> initialize
> session/new
> session/prompt
> session/update
> session/cancel
> ```
>
> Negotiate capabilities rather than assuming optional functionality.
>
> Start with a simple non-UI smoke test that can:
>
> 1. start `agent acp`
> 2. initialize
> 3. create a session
> 4. send a prompt
> 5. print streamed assistant chunks to `:messages`
> 6. finish cleanly
>
> Do not build the full UI yet.

---

# 34. Fifth implementation task

> Build the first real Cursor chat UI.
>
> Use only native Neovim floating windows.
>
> Create:
>
> - chat buffer
> - input buffer
> - right-side layout
> - focus switching
> - submit
> - cancel
> - close
>
> Connect it to the existing ACP session.
>
> Render streaming `agent_message_chunk` updates incrementally.
>
> Keep UI state separate from ACP state.
>
> Do not implement filesystem/terminal permissions yet unless required to complete the ACP handshake.

---

# 35. Sixth implementation task

> Implement agent tool activity and permissions.
>
> Render:
>
> - tool calls
> - tool call updates
> - tool status
> - tool title
> - locations when available
>
> Implement:
>
> ```text
> session/request_permission
> ```
>
> with an interactive Neovim prompt.
>
> Never auto-approve in the default configuration.
>
> Add tests for:
>
> - allow
> - deny
> - cancel
> - malformed request
> - unknown permission option

---

# 36. Seventh implementation task

> Implement ACP filesystem and terminal client methods.
>
> Required:
>
> ```text
> fs/read_text_file
> fs/write_text_file
> terminal/create
> terminal/output
> terminal/wait_for_exit
> terminal/kill
> terminal/release
> ```
>
> Use asynchronous Neovim process APIs.
>
> Enforce project-root security boundaries for filesystem access.
>
> Never execute agent-supplied shell strings directly.
>
> Preserve argument boundaries.
>
> Add tests for path traversal and terminal lifecycle.

---

# 37. Eighth implementation task

> Implement Neovim-aware context.
>
> Support:
>
> - current file
> - cursor position
> - visual selection
> - project root
>
> Add:
>
> ```vim
> :CursorAsk
> ```
>
> and visual selection support.
>
> The command should open/focus the chat, populate the input with appropriate context, and allow the user to edit the prompt before sending.
>
> Do not automatically send the entire buffer.

---

# 38. Ninth implementation task

> Implement session management.
>
> Add:
>
> ```vim
> :CursorSessionNew
> :CursorSessionResume
> ```
>
> Use only ACP capabilities advertised by Cursor Agent.
>
> Maintain one active session per project in runtime state.
>
> Do not create a custom transcript store unless the ACP implementation requires it.

---

# 39. Tenth implementation task

> Polish the plugin for daily use.
>
> Add:
>
> - `:checkhealth cursor`
> - robust errors
> - configurable mappings
> - status indicator
> - better scrolling
> - clean shutdown
> - restart recovery
> - documentation
> - complete test suite
>
> Review the plugin as a real open-source Neovim plugin.
>
> Remove unnecessary abstractions and dependencies.
>
> Make the default experience excellent before adding advanced features.

---

# 40. Future roadmap

Only after the MVP is stable:

## V1.1

- session picker
- persistent session metadata
- affected files panel
- jump-to-file from tool activity
- model/mode indicator
- better markdown rendering
- image attachments
- configurable permission policies

## V1.2

- plan mode UI
- ask mode
- agent mode
- slash-command support
- Cursor commands exposed by `available_commands_update`

## V1.3

- checkpoint/revert UX
- richer diffs
- file-change review
- inline edit workflow

## V2

- optional integration with other ACP agents
- optional provider abstraction
- MCP-aware UI
- extensibility API

Important:

Do not turn the plugin into another generic multi-agent framework unless there is a strong reason.

The original product thesis is:

> **Neovim + Cursor Agent, with as little friction as possible.**

---

# 41. Definition of done

The project is successful when a user can install it and configure:

```lua
{
  "yourname/cursor.nvim",
  config = function()
    require("cursor").setup()
  end,
}
```

Then:

```vim
:CursorChat
```

opens a Cursor-like panel.

The user can type:

```text
Find the authentication implementation and explain how it works.
```

and see streaming output.

Then:

```text
Refactor it to use the new interface, run the tests, and fix any failures.
```

and Cursor Agent can:

1. inspect the repository,
2. read files,
3. ask permission when required,
4. edit files,
5. run tests,
6. stream progress,
7. report completion,

without the user leaving Neovim.

That is the MVP.

---

# 42. Critical engineering principle

The most important design decision is to resist building too much.

This project is **not**:

```text
Neovim + our own AI agent
```

It is:

```text
Neovim
   +
excellent ACP client
   +
Cursor Agent
```

Cursor already owns the hard parts of agentic coding.

Neovim owns the editor.

The plugin's job is to make the boundary between the two feel invisible.

---

# 43. Primary references

Cursor:

- Cursor Agent overview: https://cursor.com/docs/agent/overview
- Cursor CLI overview: https://cursor.com/docs/cli/overview
- Cursor CLI usage: https://cursor.com/docs/cli/using
- Cursor ACP: https://prod.cursor.com/docs/cli/acp

ACP:

- ACP repository: https://github.com/agentclientprotocol/agent-client-protocol
- ACP v1 overview: https://github.com/agentclientprotocol/agent-client-protocol/blob/main/docs/protocol/v1/overview.mdx
- ACP v1 schema: https://github.com/agentclientprotocol/agent-client-protocol/blob/main/schema/v1/schema.json

Neovim:

- Neovim API: https://neovim.io/doc/user/api/
- Neovim Lua API: https://neovim.io/doc/user/lua
- Neovim Lua plugin guide: https://neovim.io/doc/user/lua-plugin/

Reference implementations:

- Archived cursor.nvim: https://github.com/h4kbas/cursor.nvim
- Avante: https://github.com/yetone/avante.nvim
- CodeCompanion: https://github.com/olimorris/codecompanion.nvim

---

# 44. Final instruction to the implementing agent

Build this as a production-quality Neovim plugin, but work incrementally.

Before writing code:

1. Inspect the current repository.
2. Inspect the current Cursor ACP documentation and schema.
3. Verify the installed Cursor CLI behavior locally.
4. Verify the installed Neovim version.
5. Compare the current ACP schema with assumptions in this document.
6. If this document conflicts with the live ACP schema, **the live official schema wins**.
7. Do not invent protocol fields.
8. Do not copy the archived `cursor.nvim` implementation wholesale.
9. Use the archived plugin, Avante, CodeCompanion, and ACP implementations as references for edge cases.
10. Keep the plugin small and maintainable.

Implement one phase at a time.

After every phase:

```text
format → test → smoke test → inspect diff → proceed
```

Do not declare the project complete until the end-to-end workflow works:

```text
Neovim
  → cursor.nvim
  → agent acp
  → initialize
  → session/new
  → session/prompt
  → session/update streaming
  → tool calls
  → permission request
  → file/terminal operations
  → completion
```

The end product should make a Neovim user feel like they have brought the useful part of Cursor into their editor, without having to abandon Neovim.
