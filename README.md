# 🤖 `sidekick.nvim`

**sidekick.nvim** is your Neovim AI sidekick that integrates Copilot LSP's
"Next Edit Suggestions" with a built-in terminal for any AI CLI.
Review and apply diffs, chat with AI assistants, and streamline your coding,
without leaving your editor.

<img width="2311" height="1396" alt="image" src="https://github.com/user-attachments/assets/63a33610-9a8e-45e2-bbd0-b7e3a4fde621" />

## ✨ Features

- **🤖 Next Edit Suggestions (NES) powered by Copilot LSP**
  - 🪄 **Automatic Suggestions**: Fetches suggestions automatically when you pause typing or move the cursor.
  - 🎨 **Rich Diffs**: Visualizes changes with inline and block-level diffs, featuring Treesitter-based syntax highlighting with granular diffing down to the word or character level.
  - 🧭 **Hunk-by-Hunk Navigation**: Jump through edits to review them one by one before applying.
  - 📊 **Statusline Integration**: Shows Copilot LSP's status, request progress, and preview text in your statusline.

- **💬 Integrated AI CLI Terminal**
  - 🚀 **Direct Access to AI CLIs**: Interact with your favorite AI command-line tools without leaving Neovim.
  - 📦 **Pre-configured for Popular Tools**: Out-of-the-box support for Claude, Gemini, Grok, Codex, Copilot CLI, and more.
  - ✨ **Context-Aware Prompts**: Automatically include file content, cursor position, and diagnostics in your prompts.
  - 📝 **Prompt Library**: A library of pre-defined prompts for common tasks like explaining code, fixing issues, or writing tests.
  - 🔄 **Session Persistence**: Keep your CLI sessions alive with `tmux` and `zellij` integration.
  - 📂 **Automatic File Watching**: Automatically reloads files in Neovim when they are modified by AI tools.

- **🔌 Extensible and Customizable**
  - ⚙️ **Flexible Configuration**: Fine-tune every aspect of the plugin to your liking.
  - 🧩 **Plugin-Friendly API**: A rich API for integrating with other plugins and building custom workflows.
  - 🎨 **Customizable UI**: Change the appearance of diffs, signs, and more.

## 📋 Requirements

- **Neovim** `>= 0.11.2` or newer
- The official [copilot-language-server](https://github.com/github/copilot-language-server-release) LSP server,
  enabled with `vim.lsp.enable`. Can be installed in multiple ways:
  1. install using `npm` or your OS's package manager
  2. install with [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim)
  3. [copilot.lua](https://github.com/zbirenbaum/copilot.lua) and [copilot.vim](https://github.com/github/copilot.vim)
     both bundle the LSP Server in their plugin.
- A working `lsp/copilot.lua` configuration.
  - **TIP:** Included in [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [snacks.nvim](https://github.com/folke/snacks.nvim) for better prompt/tool selection **_(optional)_**
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects) **_(`main` branch)_** for `{function}` and `{class}` context variables **_(optional)_**
- AI cli tools, such as Codex, Claude, Copilot, Gemini, … **_(optional)_**
  see the [🤖 AI CLI Integration](#-ai-cli-integration) section for details.
- [lsof](https://man7.org/linux/man-pages/man8/lsof.8.html) and [ps](https://man7.org/linux/man-pages/man1/ps.1.html) are used
  on Unix-like systems to detect running AI CLI tool sessions. **_(optional, but recommended)_**

## 🚀 Quick Start

1. **Install** the plugin with your package manager (see below)
2. **Configure Copilot LSP** - must be enabled with `vim.lsp.enable`
3. **Check health**: `:checkhealth sidekick`
4. **Sign in to Copilot**: `:LspCopilotSignIn`
5. **Try it out**:
   - Type some code and pause - watch for Next Edit Suggestions appearing
   - Press `<Tab>` to navigate through or apply suggestions
   - Use `<leader>aa` to open AI CLI tools

> [!NOTE]
> **New to Next Edit Suggestions?** Unlike inline completions, NES suggests entire refactorings or multi-line changes anywhere in your file - think of it as Copilot's "big picture" suggestions.

## 📦 Installation

Install with your favorite manager. With [lazy.nvim](https://github.com/folke/lazy.nvim):

<!-- setup_base:start -->

```lua
{
  "folke/sidekick.nvim",
  opts = {
    -- add any options here
    cli = {
      mux = {
        backend = "zellij",
        enabled = true,
      },
    },
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
    {
      "<c-.>",
      function() require("sidekick.cli").toggle() end,
      desc = "Sidekick Toggle",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<leader>aa",
      function() require("sidekick.cli").toggle() end,
      desc = "Sidekick Toggle CLI",
    },
    {
      "<leader>as",
      function() require("sidekick.cli").select() end,
      -- Or to select only installed tools:
      -- require("sidekick.cli").select({ filter = { installed = true } })
      desc = "Select CLI",
    },
    {
      "<leader>ad",
      function() require("sidekick.cli").close() end,
      desc = "Detach a CLI Session",
    },
    {
      "<leader>at",
      function() require("sidekick.cli").send({ msg = "{this}" }) end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>af",
      function() require("sidekick.cli").send({ msg = "{file}" }) end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function() require("sidekick.cli").send({ msg = "{selection}" }) end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
    {
      "<leader>ap",
      function() require("sidekick.cli").prompt() end,
      mode = { "n", "x" },
      desc = "Sidekick Select Prompt",
    },
    -- Example of a keybinding to open Claude directly
    {
      "<leader>ac",
      function() require("sidekick.cli").toggle({ name = "claude", focus = true }) end,
      desc = "Sidekick Toggle Claude",
    },
  },
}
```

<!-- setup_base:end -->

> [!TIP]
> It's a good idea to run `:checkhealth sidekick` after install.

<details>
  <summary>Integrate <code>&lt;Tab&gt;</code> in insert mode with <a href="https://github.com/saghen/blink.cmp">blink.cmp</a></summary>

<!-- setup_blink:start -->

```lua
{
  "saghen/blink.cmp",
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {

    keymap = {
      ["<Tab>"] = {
        "snippet_forward",
        function() -- sidekick next edit suggestion
          return require("sidekick").nes_jump_or_apply()
        end,
        function() -- if you are using Neovim's native inline completions
          return vim.lsp.inline_completion.get()
        end,
        "fallback",
      },
    },
  },
}
```

<!-- setup_blink:end -->

</details>

<details>
  <summary>Custom <code>&lt;Tab&gt;</code> integration for <b>insert mode</b></summary>

<!-- setup_custom:start -->

```lua
{
  "folke/sidekick.nvim",
  opts = {
    -- add any options here
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if require("sidekick").nes_jump_or_apply() then
          return -- jumped or applied
        end

        -- if you are using Neovim's native inline completions
        if vim.lsp.inline_completion.get() then
          return
        end

        -- any other things (like snippets) you want to do on <tab> go here.

        -- fall back to normal tab
        return "<tab>"
      end,
      mode = { "i", "n" },
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
  },
}
```

<!-- setup_custom:end -->

</details>

After installation sign in with `:LspCopilotSignIn` if prompted.

## ⚙️ Configuration

The module ships with safe defaults and exposes everything through
`require("sidekick").setup({ ... })`.

<details>
<summary>Default settings</summary>

<!-- config:start -->

```lua
---@class sidekick.Config
local defaults = {
  jump = {
    jumplist = true, -- add an entry to the jumplist
  },
  signs = {
    enabled = true, -- enable signs by default
    icon = " ",
  },
  nes = {
    ---@type boolean|fun(buf:integer):boolean?
    enabled = function(buf)
      return vim.g.sidekick_nes ~= false and vim.b.sidekick_nes ~= false
    end,
    debounce = 100,
    trigger = {
      -- events that trigger sidekick next edit suggestions
      events = { "ModeChanged i:n", "TextChanged", "User SidekickNesDone" },
    },
    clear = {
      -- events that clear the current next edit suggestion
      events = { "TextChangedI", "InsertEnter" },
      esc = true, -- clear next edit suggestions when pressing <Esc>
    },
    ---@class sidekick.diff.Opts
    ---@field inline? "words"|"chars"|false Enable inline diffs
    diff = {
      inline = "words",
    },
  },
  -- Work with AI cli tools directly from within Neovim
  cli = {
    watch = true, -- notify Neovim of file changes done by AI CLI tools
    ---@class sidekick.win.Opts
    win = {
      --- This is run when a new terminal is created, before starting it.
      --- Here you can change window options `terminal.opts`.
      ---@param terminal sidekick.cli.Terminal
      config = function(terminal) end,
      wo = {}, ---@type vim.wo
      bo = {}, ---@type vim.bo
      layout = "right", ---@type "float"|"left"|"bottom"|"top"|"right"
      --- Options used when layout is "float"
      ---@type vim.api.keyset.win_config
      float = {
        width = 0.9,
        height = 0.9,
      },
      -- Options used when layout is "left"|"bottom"|"top"|"right"
      ---@type vim.api.keyset.win_config
      split = {
        width = 80, -- set to 0 for default split width
        height = 20, -- set to 0 for default split height
      },
      --- CLI Tool Keymaps (default mode is `t`)
      ---@type table<string, sidekick.cli.Keymap|false>
      keys = {
        buffers       = { "<c-b>", "buffers"   , mode = "nt", desc = "open buffer picker" },
        files         = { "<c-f>", "files"     , mode = "nt", desc = "open file picker" },
        hide_n        = { "q"    , "hide"      , mode = "n" , desc = "hide the terminal window" },
        hide_ctrl_q   = { "<c-q>", "hide"      , mode = "n" , desc = "hide the terminal window" },
        hide_ctrl_dot = { "<c-.>", "hide"      , mode = "nt", desc = "hide the terminal window" },
        hide_ctrl_z   = { "<c-z>", "hide"      , mode = "nt", desc = "hide the terminal window" },
        prompt        = { "<c-p>", "prompt"    , mode = "t" , desc = "insert prompt or context" },
        stopinsert    = { "<c-q>", "stopinsert", mode = "t" , desc = "enter normal mode" },
        -- Navigate windows in terminal mode. Only active when:
        -- * layout is not "float"
        -- * there is another window in the direction
        -- With the default layout of "right", only `<c-h>` will be mapped
        nav_left      = { "<c-h>", "nav_left"  , expr = true, desc = "navigate to the left window" },
        nav_down      = { "<c-j>", "nav_down"  , expr = true, desc = "navigate to the below window" },
        nav_up        = { "<c-k>", "nav_up"    , expr = true, desc = "navigate to the above window" },
        nav_right     = { "<c-l>", "nav_right" , expr = true, desc = "navigate to the right window" },
      },
      ---@type fun(dir:"h"|"j"|"k"|"l")?
      --- Function that handles navigation between windows.
      --- Defaults to `vim.cmd.wincmd`. Used by the `nav_*` keymaps.
      nav = nil,
    },
    ---@class sidekick.cli.Mux
    ---@field backend? "tmux"|"zellij" Multiplexer backend to persist CLI sessions
    mux = {
      backend = vim.env.ZELLIJ and "zellij" or "tmux", -- default to tmux unless zellij is detected
      enabled = false,
      -- terminal: new sessions will be created for each CLI tool and shown in a Neovim terminal
      -- window: when run inside a terminal multiplexer, new sessions will be created in a new tab
      -- split: when run inside a terminal multiplexer, new sessions will be created in a new split
      -- NOTE: zellij only supports `terminal`
      create = "terminal", ---@type "terminal"|"window"|"split"
      split = {
        vertical = true, -- vertical or horizontal split
        size = 0.5, -- size of the split (0-1 for percentage)
      },
    },
    ---@type table<string, sidekick.cli.Config|{}>
    tools = {
      aider = { cmd = { "aider" } },
      amazon_q = { cmd = { "q" } },
      claude = { cmd = { "claude" } },
      codex = { cmd = { "codex", "--search" } },
      copilot = { cmd = { "copilot", "--banner" } },
      crush = {
        cmd = { "crush" },
        -- crush uses <a-p> for its own functionality, so we override the default
        keys = { prompt = { "<a-p>", "prompt" } },
      },
      cursor = { cmd = { "cursor-agent" } },
      gemini = { cmd = { "gemini" } },
      grok = { cmd = { "grok" } },
      opencode = {
        cmd = { "opencode" },
        -- HACK: https://github.com/sst/opencode/issues/445
        env = { OPENCODE_THEME = "system" },
      },
      qwen = { cmd = { "qwen" } },
    },
    --- Add custom context. See `lua/sidekick/context/init.lua`
    ---@type table<string, sidekick.context.Fn>
    context = {},
    ---@type table<string, sidekick.Prompt|string|fun(ctx:sidekick.context.ctx):(string?)>
    prompts = {
      changes         = "Can you review my changes?",
      diagnostics     = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
      diagnostics_all = "Can you help me fix these diagnostics?\n{diagnostics_all}",
      document        = "Add documentation to {function|line}",
      explain         = "Explain {this}",
      fix             = "Can you fix {this}?",
      optimize        = "How can {this} be optimized?",
      review          = "Can you review {file} for any issues or improvements?",
      tests           = "Can you write tests for {this}?",
      -- simple context prompts
      buffers         = "{buffers}",
      file            = "{file}",
      line            = "{line}",
      position        = "{position}",
      quickfix        = "{quickfix}",
      selection       = "{selection}",
      ["function"]    = "{function}",
      class           = "{class}",
    },
    -- preferred picker for selecting files
    ---@alias sidekick.picker "snacks"|"telescope"|"fzf-lua"
    picker = "snacks", ---@type sidekick.picker
  },
  copilot = {
    -- track copilot's status with `didChangeStatus`
    status = {
      enabled = true,
      level = vim.log.levels.WARN,
      -- set to vim.log.levels.OFF to disable notifications
      -- level = vim.log.levels.OFF,
    },
  },
  ui = {
    icons = {
      attached          = " ",
      started           = " ",
      installed         = " ",
      missing           = " ",
      external_attached = "󰖩 ",
      external_started  = "󰖪 ",
      terminal_attached = " ",
      terminal_started  = " ",
    },
  },
  debug = false, -- enable debug logging
}
```

<!-- config:end -->

</details>

## ✏️ Next Edit Suggestions (NES)

Copilot NES requests run automatically when you leave insert mode,
modify text in normal mode, or after applying an edit.

<!-- api_nes:start -->

<table><tr><th>Cmd</th><th>Lua</th></tr>
<tr><td><code>:Sidekick nes apply</code> Apply active text edits</td><td>


```lua
---@return boolean applied
require("sidekick.nes").apply()
```

</td></tr>
<tr><td><code>:Sidekick nes clear</code> Clear all active edits</td><td>


```lua
require("sidekick.nes").clear()
```

</td></tr>
<tr><td><code>:Sidekick nes disable</code> </td><td>


```lua

require("sidekick.nes").disable()
```

</td></tr>
<tr><td><code>:Sidekick nes enable</code> </td><td>


```lua
---@param enable? boolean
require("sidekick.nes").enable(enable)
```

</td></tr>
<tr><td> Check if any edits are active in the current buffer</td><td>


```lua
require("sidekick.nes").have()
```

</td></tr>
<tr><td><code>:Sidekick nes jump</code> Jump to the start of the active edit</td><td>


```lua
---@return boolean jumped
require("sidekick.nes").jump()
```

</td></tr>
<tr><td><code>:Sidekick nes toggle</code> </td><td>


```lua

require("sidekick.nes").toggle()
```

</td></tr>
<tr><td><code>:Sidekick nes update</code> Request new edits from the LSP server (if any)</td><td>


```lua
require("sidekick.nes").update()
```

</td></tr>
</table>

<!-- api_nes:end -->

## 🤖 AI CLI Integration

Sidekick ships with a lightweight terminal wrapper so you can talk to local AI CLI
tools without leaving Neovim. Each tool runs in its own scratch terminal window and
shares helper prompts that bundle buffer context, the current cursor position, and
diagnostics when requested.

<!-- api_cli:start -->

<table><tr><th>Cmd</th><th>Lua</th></tr>
<tr><td><code>:Sidekick cli close</code> </td><td>


```lua
---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
require("sidekick.cli").close(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli focus</code> Toggle focus of the terminal window if it is already open</td><td>


```lua
---@param opts? sidekick.cli.Show
---@overload fun(name: string)
require("sidekick.cli").focus(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli hide</code> </td><td>


```lua
---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
require("sidekick.cli").hide(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli prompt</code> Select a prompt to send</td><td>


```lua
---@param opts? sidekick.cli.Prompt|{cb:nil}
---@overload fun(cb:fun(msg?:string))
require("sidekick.cli").prompt(opts)
```

</td></tr>
<tr><td> Render a message template or prompt</td><td>


```lua
---@param opts? sidekick.cli.Message|string
require("sidekick.cli").render(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli select</code> Start or attach to a CLI tool</td><td>


```lua
---@param opts? sidekick.cli.Select|{cb:nil}|{focus?:boolean}
---@overload fun(cb:fun(state?:sidekick.cli.State))
require("sidekick.cli").select(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli send</code> Send a message or prompt to a CLI</td><td>


```lua
---@param opts? sidekick.cli.Send
---@overload fun(msg:string)
require("sidekick.cli").send(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli show</code> </td><td>


```lua
---@param opts? sidekick.cli.Show
---@overload fun(name: string)
require("sidekick.cli").show(opts)
```

</td></tr>
<tr><td><code>:Sidekick cli toggle</code> </td><td>


```lua
---@param opts? sidekick.cli.Show
---@overload fun(name: string)
require("sidekick.cli").toggle(opts)
```

</td></tr>
</table>

<!-- api_cli:end -->

### Prompts & Context

Sidekick comes with a set of predefined prompts that you can use with your AI tools.
You can also use context variables in your prompts to include information about the
current file, selection, diagnostics, and more.

<img width="1431" height="723" alt="image" src="https://github.com/user-attachments/assets/652867ec-f34e-4036-9b0b-8a4817cc8722" />

<details><summary><strong>Available Prompts</strong></summary>

- **changes**: `Can you review my changes?`
- **diagnostics**: `Can you help me fix the diagnostics in {file}?\n{diagnostics}`
- **diagnostics_all**: `Can you help me fix these diagnostics?\n{diagnostics_all}`
- **document**: `Add documentation to {position}`
- **explain**: `Explain {this}`
- **fix**: `Can you fix {this}?`
- **optimize**: `How can {this} be optimized?`
- **review**: `Can you review {file} for any issues or improvements?`
- **tests**: `Can you write tests for {this}?`
- **quickfix**: `{quickfix}` (current quickfix entries).

</details>

<details><summary><strong>Available Context Variables</strong></summary>

- `{buffers}`: A list of all open buffers.
- `{file}`: The current file path.
- `{position}`: The cursor position in the current file.
- `{line}`: The current line.
- `{selection}`: The visual selection.
- `{diagnostics}`: The diagnostics for the current buffer.
- `{diagnostics_all}`: All diagnostics in the workspace.
- `{quickfix}`: The current quickfix list, including title and formatted items.
- `{function}`: The function at cursor (Tree-sitter) - returns location like `function foo @file:10:5`.
- `{class}`: The class/struct at cursor (Tree-sitter) - returns location.
- `{this}`: A special context variable. If the current buffer is a file, it resolves to `{position}`. Otherwise, it resolves to the literal string "this" and appends the current `{selection}` to the prompt.

</details>

### Snacks.nvim Picker Integration

If you're using [snacks.nvim](https://github.com/folke/snacks.nvim), you can send picker selections directly to Sidekick's AI CLI tools. This is useful for sending search results, grep matches, or file selections as context.

<details><summary>Example Snacks picker configuration</summary>

<!-- snacks_picker:start -->

```lua
{
  "folke/snacks.nvim",
  optional = true,
  opts = {
    picker = {
      actions = {
        sidekick_send = function(...)
          return require("sidekick.cli.picker.snacks").send(...)
        end,
      },
      win = {
        input = {
          keys = {
            ["<a-a>"] = {
              "sidekick_send",
              mode = { "n", "i" },
            },
          },
        },
      },
    },
  },
}
```

<!-- snacks_picker:end -->

With this configuration, pressing `<a-a>` in any Snacks picker will send the selected items to your current AI CLI session. The integration automatically handles:

- File selections with full paths
- Grep results with line numbers and positions
- Multiple selections (sends all selected items)
- Position ranges for precise context

</details>

### CLI Keymaps

You can customize the keymaps for the CLI window by setting the `cli.win.keys` option.
The default keymaps are:

- `q` (in normal mode): Hide the terminal window.
- `<c-q>` (in terminal mode): Hide the terminal window.
- `<c-w>p`: Leave the CLI window.
- `<c-p>`: Insert prompt or context.

<details><summary>Example of how to override the default keymaps
</summary>

```lua
{
  "folke/sidekick.nvim",
  opts = {
    cli = {
      win = {
        keys = {
          -- override the default hide keymap
          hide_n = { "<leader>q", "hide", mode = "n" },
          -- add a new keymap to say hi
          say_hi = {
            "<c-h>",
            function(t)
              t:send("hi!")
            end,
          },
        },
      },
    },
  },
}
```

</details>

### Default CLI tools

Sidekick preconfigures popular AI CLIs. Run `:checkhealth sidekick` to see which ones are installed.

| Tool                                                        | Description          | Installation                                                                                                           |
| ----------------------------------------------------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| [`aider`](https://github.com/Aider-AI/aider)                | AI pair programmer   | `pip install aider-chat` or `pipx install aider-chat`                                                                  |
| [`amazon_q`](https://github.com/aws/amazon-q-developer-cli) | Amazon Q Developer   | [Install guide](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/command-line-getting-started-installing.html) |
| [`claude`](https://github.com/anthropics/claude-code)       | Claude Code CLI      | `npm install -g @anthropic-ai/claude-code`                                                                             |
| [`codex`](https://github.com/openai/codex)                  | OpenAI Codex CLI     | See [OpenAI docs](https://github.com/openai/codex)                                                                     |
| [`copilot`](https://github.com/github/copilot-cli)          | GitHub Copilot CLI   | `npm install -g @githubnext/github-copilot-cli`                                                                        |
| [`crush`](https://github.com/charmbracelet/crush)           | Charm's AI assistant | See [installation](https://github.com/charmbracelet/crush)                                                             |
| [`cursor`](https://cursor.com/cli)                          | Cursor CLI agent     | See [Cursor docs](https://cursor.com/cli)                                                                              |
| [`gemini`](https://github.com/google-gemini/gemini-cli)     | Google Gemini CLI    | See [repo](https://github.com/google-gemini/gemini-cli)                                                                |
| [`grok`](https://github.com/superagent-ai/grok-cli)         | xAI Grok CLI         | See [repo](https://github.com/superagent-ai/grok-cli)                                                                  |
| [`opencode`](https://github.com/sst/opencode)               | OpenCode CLI         | `npm install -g opencode`                                                                                              |
| [`qwen`](https://github.com/QwenLM/qwen-code)               | Alibaba Qwen Code    | See [repo](https://github.com/QwenLM/qwen-code)                                                                        |

> [!TIP]
> After installing tools, restart Neovim or run `:Sidekick cli select` to see them available.

## 🚀 Commands

Sidekick provides a `:Sidekick` command that allows you to interact with the plugin
from the command line. The command is a thin wrapper around the Lua API, so you
can use it to do anything that the Lua API can do.

### Command Structure

The command structure is simple:

```
:Sidekick <module> <command> [args]
```

- `<module>`: The name of the module you want to use (e.g., `nes`, `cli`).
- `<command>`: The name of the command you want to execute.
- `[args]`: Optional arguments for the command. The arguments are parsed as a Lua
  table.

For example, to show the CLI window for the `claude` tool, you can use the
following command:

```
:Sidekick cli show name=claude
```

This is equivalent to the following Lua code:

```lua
require("sidekick.cli").show({ name = "claude" })
```

<details><summary>
<strong>Available Commands</strong></summary>

Here's a list of the available commands:

**NES (`nes`)**

- `enable`: Enable Next Edit Suggestions.
- `disable`: Disable Next Edit Suggestions.
- `toggle`: Toggle Next Edit Suggestions.
- `update`: Trigger a new suggestion.
- `clear`: Clear the current suggestion.

**CLI (`cli`)**

- `show`: Show the CLI window.
- `toggle`: Toggle the CLI window.
- `hide`: Hide the CLI window.
- `close`: Close the CLI window.
- `focus`: Focus the CLI window.
- `select`: Select a CLI tool to open.
- `send`: Send a message to the current CLI tool.
- `prompt`: Select a prompt to send to the current CLI tool.

</details>

<details><summary>
<strong>Examples</strong></summary>

Here are some examples of how to use the `:Sidekick` command:

- Toggle the CLI window:

  ```
  :Sidekick cli toggle
  ```

  Lua equivalent:

  ```lua
  require("sidekick.cli").toggle()
  ```

- Send the visual selection to the current CLI tool:

  ```
  :'<,'>Sidekick cli send msg="{selection}"
  ```

  Lua equivalent:

  ```lua
  require("sidekick.cli").send({ msg = "{selection}" })
  ```

- Show the CLI window for the `grok` tool and focus it:

  ```
  :Sidekick cli show name=grok focus=true
  ```

  Lua equivalent:

  ```lua
  require("sidekick.cli").show({ name = "grok", focus = true })
  ```

  </details>

## 📟 Statusline Integration

Using the `require("sidekick.status")` API, you can easily integrate **Copilot LSP**
and **CLI sessions** in your statusline.

<details>
<summary>Example for <a href="https://github.com/nvim-lualine/lualine.nvim">lualine.nvim</a></summary>

<!-- setup_lualine:start -->

```lua
{
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    opts.sections = opts.sections or {}
    opts.sections.lualine_c = opts.sections.lualine_c or {}

    -- Copilot status
    table.insert(opts.sections.lualine_c, {
      function()
        return " "
      end,
      color = function()
        local status = require("sidekick.status").get()
        if status then
          return status.kind == "Error" and "DiagnosticError" or status.busy and "DiagnosticWarn" or "Special"
        end
      end,
      cond = function()
        local status = require("sidekick.status")
        return status.get() ~= nil
      end,
    })

    -- CLI session status
    table.insert(opts.sections.lualine_x, 2, {
      function()
        local status = require("sidekick.status").cli()
        return " " .. (#status > 1 and #status or "")
      end,
      cond = function()
        return #require("sidekick.status").cli() > 0
      end,
      color = function()
        return "Special"
      end,
    })
  end,
}
```

<!-- setup_lualine:end -->

</details>

## ❓ FAQ

### Does sidekick.nvim replace Copilot's inline suggestions?

No! NES complements inline suggestions. They serve different purposes:

- **Inline completions**: Quick, as-you-type suggestions (use copilot.lua or native `vim.lsp.inline_completion`)
- **NES**: Larger refactorings and multi-line changes after you pause

You'll want both for the best experience.

### How is this different from copilot.lua or copilot.vim?

`copilot.lua` and `copilot.vim` provide **inline completions** (suggestions as you type). `sidekick.nvim` adds:

- **Next Edit Suggestions (NES)**: Multi-line refactorings and context-aware edits across your file
- **AI CLI Integration**: Built-in terminal for Claude, Gemini, and other AI tools

Use them together for the complete experience!

### NES not showing suggestions?

1. Run `:checkhealth sidekick` to verify your setup
2. Check Copilot is signed in: `:LspCopilotSignIn`
3. Verify the LSP is attached: `:lua vim.print(require("sidekick.config").get_client())`
4. Try manually triggering: `:Sidekick nes update`

### CLI tools not starting?

1. Verify the tool is installed: `which claude` (or your tool name)
2. Check `:checkhealth sidekick` for tool installation status
3. Try running the tool directly in your terminal first
4. Check for errors with `:messages` after attempting to start

### Terminal sessions not persisting?

Make sure you have tmux or zellij installed and enable the multiplexer:

```lua
opts = {
  cli = {
    mux = {
      enabled = true,
      backend = "tmux", -- or "zellij"
    },
  },
}
```

### Do I need a GitHub Copilot subscription?

Yes, but only for the **NES feature** (Next Edit Suggestions). The **AI CLI integration** works independently with any CLI tool (Claude, Gemini, etc.) and doesn't require Copilot.

### Can I use this without NES, just for CLI tools?

Absolutely! Just disable NES:

```lua
opts = {
  nes = { enabled = false },
}
```

### Will this work with Neovim 0.10?

No, Neovim **>= 0.11.2** is required for the LSP features and API used by sidekick.nvim.

### How do I add my own AI tool?

Add it to the `cli.tools` configuration:

```lua
opts = {
  cli = {
    tools = {
      my_tool = {
        cmd = { "my-ai-cli", "--flag" },
        -- Optional: custom keymaps for this tool
        keys = {
          submit = { "<c-s>", function(t) t:send("\n") end },
        },
      },
    },
  },
}
```

### How do I create custom prompts?

Add them to your config:

```lua
opts = {
  cli = {
    prompts = {
      refactor = "Please refactor {this} to be more maintainable",
      security = "Review {file} for security vulnerabilities",
      custom = function(ctx)
        return "Current file: " .. ctx.buf .. " at line " .. ctx.row
      end,
    },
  },
}
```

Then use with `<leader>ap` or `:Sidekick cli prompt`.
