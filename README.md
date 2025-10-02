# 🤖 `sidekick.nvim`

**sidekick.nvim** is your Neovim AI sidekick that integrates Copilot LSP's
"Next Edit Suggestions" with a built-in terminal for any AI CLI.
Review and apply diffs, chat with AI assistants, and streamline your coding,
without leaving your editor.

<img width="2311" height="1396" alt="image" src="https://github.com/user-attachments/assets/63a33610-9a8e-45e2-bbd0-b7e3a4fde621" />

## ✨ Features

- **🤖 Next Edit Suggestions (NES) powered by Copilot LSP**
  - 🪄 **Automatic Suggestions**: Fetches suggestions automatically when you pause typing or move the cursor.
  - 🎨 **Rich Diffs**: Visualizes changes with inline and block-level diffs, featuring Treesitter-based syntax highlighting.
    granular diffing down to the word or character level.
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
- AI cli tools, such as Codex, Claude, Copilot, Gemini, … **_(optional)_**
  see the [🤖 AI CLI Integration](#-ai-cli-integration) section for details.

## ❓ Questions

- What are Copilot's Next Edit Suggestions? (**NES**)
  - Copilot can suggest the next logical change, anywhere in your project.
  - For more info, see this [blog post](https://githubnext.com/projects/copilot-next-edit-suggestions/)

- Does **NES** replace Copilot's inline suggestions?
  - No! You'll likely still want to pair **NES** with a plugin that supports inline suggestions.
  - On Neovim `< 0.12`, you can use [copilot.lua](https://github.com/zbirenbaum/copilot.lua)
  - On Neovim `>= 0.12` (_nightly_) you can enable the native feature instead:

    ```lua
    vim.lsp.inline_completion.enable()
    ```

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
  -- stylua: ignore
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
      "<leader>at",
      function() require("sidekick.cli").send({ msg = "{this}" }) end,
      mode = { "x", "n" },
      desc = "Send This",
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
    {
      "<c-.>",
      function() require("sidekick.cli").focus() end,
      mode = { "n", "x", "i", "t" },
      desc = "Sidekick Switch Focus",
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
      events = { "InsertLeave", "TextChanged", "User SidekickNesDone" },
    },
    clear = {
      -- events that clear the current next edit suggestion
      events = { "TextChangedI", "TextChanged", "BufWritePre", "InsertEnter" },
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
      --- The is ran when a new terminal is created, before starting it.
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
        width = 80,
        height = 20,
      },
      --- CLI Tool Keymaps
      --- default mode is `t`
      ---@type table<string, sidekick.cli.Keymap|false>
      keys = {
        -- -- diabled the soptinsert keymaps since it interfers with some tools
        -- -- Use Neovim's default `<c-\><c-n>` instead
        -- stopinsert = { "<c-o>", "stopinsert", mode = "t" }, -- enter normal mode
        hide_n = { "q", "hide", mode = "n" }, -- hide the terminal window in normal mode
        hide_t = { "<c-q>", "hide" }, -- hide the terminal window in terminal mode
        win_p = { "<c-w>p", "blur" }, -- leave the cli window
        prompt = { "<c-p>", "prompt" }, -- insert prompt or context
        -- example of custom keymap:
        -- say_hi = {
        --   "<c-h>",
        --   function(t)
        --     t:send("hi!")
        --   end,
        -- },
      },
    },
    ---@class sidekick.cli.Mux
    ---@field backend? "tmux"|"zellij" Multiplexer backend to persist CLI sessions
    mux = {
      backend = "zellij",
      enabled = false,
    },
    ---@type table<string, sidekick.cli.Tool.spec>
    tools = {
      aider = { cmd = { "aider" }, url = "https://github.com/Aider-AI/aider" },
      amazon_q = { cmd = { "q" }, url = "https://github.com/aws/amazon-q-developer-cli" },
      claude = { cmd = { "claude" }, url = "https://github.com/anthropics/claude-code" },
      codex = { cmd = { "codex", "--search" }, url = "https://github.com/openai/codex" },
      copilot = { cmd = { "copilot", "--banner" }, url = "https://github.com/github/copilot-cli" },
      crush = {
        cmd = { "crush" },
        url = "https://github.com/charmbracelet/crush",
        keys = {
          -- crush uses <a-p> for its own functionality, so we override the default
          prompt = { "<a-p>", "prompt" }, -- insert prompt or context
        },
      },
      cursor = { cmd = { "cursor-agent" }, url = "https://cursor.com/cli" },
      gemini = { cmd = { "gemini" }, url = "https://github.com/google-gemini/gemini-cli" },
      grok = { cmd = { "grok" }, url = "https://github.com/superagent-ai/grok-cli" },
      opencode = { cmd = { "opencode" }, url = "https://github.com/sst/opencode" },
      qwen = { cmd = { "qwen" }, url = "https://github.com/QwenLM/qwen-code" },
    },
    --- Add custom context. See `lua/sidekick/context/init.lua`
    ---@type table<string, sidekick.context.Fn>
    context = {},
    -- stylua: ignore
    ---@type table<string, sidekick.Prompt|string|fun(ctx:sidekick.context.ctx):(string?)>
    prompts = {
      changes         = "Can you review my changes?",
      diagnostics     = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
      diagnostics_all = "Can you help me fix these diagnostics?\n{diagnostics_all}",
      document        = "Add documentation to {position}",
      explain         = "Explain {this}",
      fix             = "Can you fix {this}?",
      optimize        = "How can {this} be optimized?",
      review          = "Can you review {file} for any issues or improvements?",
      tests           = "Can you write tests for {this}?",
      -- simple context prompts
      buffers         = "{buffers}",
      file            = "{file}",
      position        = "{position}",
      selection       = "{selection}",
    },
  },
  copilot = {
    -- track copilot's status with `didChangeStatus`
    status = {
      enabled = true,
    },
  },
  debug = false, -- enable debug logging
}
```

<!-- config:end -->

</details>

## 🚀 Usage

- Copilot NES requests run automatically when you leave insert mode,
  modify text in normal mode, or after applying an edit.
- Use the helper functions to control suggestions manually:
  - `require("sidekick.nes").update()` – request fresh edits for the current buffer.
  - `require("sidekick.nes").jump()` – move the cursor to the first suggested hunk.
  - `require("sidekick.nes").apply()` – apply all pending edits and emit the
    `User SidekickNesDone` autocmd.
  - `require("sidekick").clear()` – cancel requests and hide overlays.
  - `require("sidekick.nes").have()` – check if any edits are active in the buffer.
- Hook into the `User` autocmd (`pattern = "SidekickNesDone"`) to run follow-up logic
  after an edit has been applied.

## 🤖 AI CLI Integration

Sidekick ships with a lightweight terminal wrapper so you can talk to local AI CLI
tools without leaving Neovim. Each tool runs in its own scratch terminal window and
shares helper prompts that bundle buffer context, the current cursor position, and
diagnostics when requested.

- `require("sidekick.cli").toggle()` – open or focus the most recent tool, or pick one if none are running.
- `require("sidekick.cli").select()` – select a tool to open from a list of all configured tools.
- `require("sidekick.cli").send({ prompt = "review", submit = true })` – format a prompt,
  push it to the active tool, and send it immediately.
- `require("sidekick.cli").send({ msg = "What does this do?", submit = true })` – same as above,
  but with a custom message.
- `require("sidekick.cli").prompt()` – browse the prompt presets (Snacks picker is
  used when available).

<details>
<summary>Keymaps that pair well with the defaults:</summary>

```lua
{
  {
    "<leader>aa",
    function()
      require("sidekick.cli").toggle({ focus = true })
    end,
    desc = "Sidekick Toggle CLI",
  },
  {
    "<leader>ap",
    function()
      require("sidekick.cli").prompt()
    end,
    desc = "Sidekick Prompt Picker",
  },
}
```

</details>

Tune the behaviour via `Config.cli`: add your own tool definitions, tweak window
layout, or extend the prompt list. See the defaults above for all available fields.

### Prompts & Context

Sidekick comes with a set of predefined prompts that you can use with your AI tools.
You can also use context variables in your prompts to include information about the
current file, selection, diagnostics, and more.

<img width="1431" height="723" alt="image" src="https://github.com/user-attachments/assets/652867ec-f34e-4036-9b0b-8a4817cc8722" />

**Available Prompts:**

- **changes**: `Can you review my changes?`
- **diagnostics**: `Can you help me fix the diagnostics in {file}?\n{diagnostics}`
- **diagnostics_all**: `Can you help me fix these diagnostics?\n{diagnostics_all}`
- **document**: `Add documentation to {position}`
- **explain**: `Explain {this}`
- **fix**: `Can you fix {this}?`
- **optimize**: `How can {this} be optimized?`
- **review**: `Can you review {file} for any issues or improvements?`
- **tests**: `Can you write tests for {this}?`

**Available Context Variables:**

- `{buffers}`: A list of all open buffers.
- `{file}`: The current file path.
- `{position}`: The cursor position in the current file.
- `{selection}`: The visual selection.
- `{diagnostics}`: The diagnostics for the current buffer.
- `{diagnostics_all}`: All diagnostics in the workspace.
- `{this}`: A special context variable. If the current buffer is a file, it resolves to `{position}`. Otherwise, it resolves to the literal string "this" and appends the current `{selection}` to the prompt.

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

Sidekick preconfigures a handful of popular CLIs so you can get started quickly:

- [`aider`](https://github.com/Aider-AI/aider) - Aider
- [`amazon_q`](https://github.com/aws/amazon-q-developer-cli) – Amazon Q
- [`claude`](https://github.com/anthropics/claude-code) – Anthropic’s Claude Code
- [`codex`](https://github.com/openai/codex) – OpenAI’s Codex
- [`copilot`](https://github.com/github/copilot-cli) – GitHub Copilot
- [`crush`](https://github.com/charmbracelet/crush) – Crush
- [`cursor`](https://cursor.com/cli) – Cursor CLI
- [`gemini`](https://github.com/google-gemini/gemini-cli) – Google’s Gemini CLI.
- [`grok`](https://github.com/superagent-ai/grok-cli) – xAI’s Grok CLI.
- [`opencode`](https://github.com/sst/opencode) – OpenCode
- [`qwen`](https://github.com/QwenLM/qwen-code) – Alibaba’s Qwen Code

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

### Available Commands

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

### Examples

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

## 📟 Statusline Integration

Using the `require("sidekick.status")` API, you can easily integrate **Copilot LSP**
in your statusline.

<details>
<summary>Example for <a href="https://github.com/nvim-lualine/lualine.nvim">lualine.nvim</a></summary>

<!-- setup_lualine:start -->

```lua
{
  "nvim-lualine/lualine.nvim",
  opts = {
    sections = {
      lualine_c = {
        {
          function()
            return " "
          end,
           color = function()
            local status = require("sidekick.status").get()
              if status then
                 return status.kind == "Error" and "DiagnosticError" or status.busy and "DiagnosticWarn" or
                  "Special"
               end
          end,
           cond = function()
            local status = require("sidekick.status")
            return status.get() ~= nil
           end,
        },
      },
    },
    options = { theme = "tokyonight" },
  }
}
```

<!-- setup_lualine:end -->

</details>
