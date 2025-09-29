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
- The official **Copilot LSP** server, enabled with `vim.lsp.enable`, [copilot.lua](https://github.com/zbirenbaum/copilot.lua) or [copilot.vim](https://github.com/github/copilot.vim)
  **TIP:** can be installed with [mason-lspconfig.nvim](https://github.com/mason-org/mason-lspconfig.nvim)
- A working `lsp/copilot.lua` configuration.
  **TIP:** Included in [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- **Optional**: Other AI cli tools, such as Claude and Gemini, for integrated ai cli experience in neovim.

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
      function()
        require("sidekick.cli").focus()
      end,
      desc = "Sidekick Switch Focus",
      mode = { "n", "v" },
    },
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ focus = true })
      end,
      desc = "Sidekick Toggle CLI",
      mode = { "n", "v" },
    },
    {
      "<leader>ac",
      function()
        require("sidekick.cli").toggle({ name = "claude", focus = true })
      end,
      desc = "Sidekick Claude Toggle",
      mode = { "n", "v" },
    },
    {
      "<leader>ag",
      function()
        require("sidekick.cli").toggle({ name = "grok", focus = true })
      end,
      desc = "Sidekick Grok Toggle",
      mode = { "n", "v" },
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").select_prompt()
      end,
      desc = "Sidekick Ask Prompt",
      mode = { "n", "v" },
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
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle({ focus = true })
      end,
      desc = "Sidekick Toggle CLI",
      mode = { "n", "v" },
    },
    {
      "<leader>ac",
      function()
        -- Same as above, but opens Claude directly
        require("sidekick.cli").toggle({ name = "claude", focus = true })
      end,
      desc = "Sidekick Claude Toggle",
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").select_prompt()
      end,
      desc = "Sidekick Ask Prompt",
      mode = { "n", "v" },
    },
    {
      "<leader>ag",
      function()
        -- Jump straight into Grok with the current context
        require("sidekick.cli").toggle({ name = "grok", focus = true })
      end,
      desc = "Sidekick Grok Toggle",
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
      events = { "TextChangedI", "BufWritePre", "InsertEnter" },
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
    win = {
      wo = {}, ---@type vim.wo
      bo = {}, ---@type vim.bo
      width = 80,
      height = 20,
      layout = "vertical", ---@type "vertical" | "horizontal"
      position = "right", ---@type "left"|"bottom"|"top"|"right"
      --- CLI Tool Keymaps
      --- default mode is `t`
      ---@type table<string, sidekick.cli.Keymap|false>
      keys = {
        stopinsert = { "<esc><esc>", "stopinsert", mode = "t" }, -- enter normal mode
        hide_n = { "q", "hide", mode = "n" }, -- hide from normal mode
        hide_t = { "<c-q>", "hide" }, -- hide from terminal mode
        win_p = { "<c-w>p", "blur" }, -- leave the cli window
        blur = { "<c-o>", "blur" }, -- leave the cli window
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
      claude = { cmd = { "claude" }, url = "https://github.com/anthropics/claude-code" },
      codex = { cmd = { "codex", "--search" }, url = "https://github.com/openai/codex" },
      copilot = { cmd = { "copilot", "--banner" }, url = "https://github.com/github/copilot-cli" },
      cursor = { cmd = { "cursor-agent" }, url = "https://cursor.com/cli" },
      gemini = { cmd = { "gemini" }, url = "https://github.com/google-gemini/gemini-cli" },
      grok = { cmd = { "grok" }, url = "https://github.com/superagent-ai/grok-cli" },
      opencode = { cmd = { "opencode" }, url = "https://github.com/sst/opencode" },
      qwen = { cmd = { "qwen" }, url = "https://github.com/QwenLM/qwen-code" },
    },
    ---@type table<string, sidekick.Prompt.spec>
    prompts = {
      explain = "Explain this code",
      diagnostics = {
        msg = "What do the diagnostics in this file mean?",
        diagnostics = true,
      },
      diagnostics_all = {
        msg = "Can you help me fix these issues?",
        diagnostics = { all = true },
      },
      fix = {
        msg = "Can you fix the issues in this code?",
        diagnostics = true,
      },
      review = {
        msg = "Can you review this code for any issues or improvements?",
        diagnostics = true,
      },
      optimize = "How can this code be optimized?",
      tests = "Can you write tests for this code?",
      file = { location = { row = false, col = false } },
      position = {},
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
- `require("sidekick.cli").ask({ prompt = "review", submit = true })` – format a prompt,
  push it to the active tool, and send it immediately.
- `require("sidekick.cli").ask({ msg = "What does this do?", submit = true })` – same as above,
  but with a custom message.
- `require("sidekick.cli").select_prompt()` – browse the prompt presets (Snacks picker is
  used when available).

Keymaps that pair well with the defaults:

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
      require("sidekick.cli").select_prompt()
    end,
    desc = "Sidekick Prompt Picker",
  },
}
```

Tune the behaviour via `Config.cli`: add your own tool definitions, tweak window
layout, or extend the prompt list. See the defaults above for all available fields.

### Default CLI tools

Sidekick preconfigures a handful of popular CLIs so you can get started quickly:

- [`claude`](https://github.com/anthropics/claude-code) – Anthropic’s official CLI.
- [`codex`](https://github.com/openai/codex) – OpenAI’s Codex CLI.
- [`gemini`](https://github.com/google-gemini/gemini-cli) – Google’s Gemini CLI.
- [`copilot`](https://github.com/github/copilot-cli) – GitHub Copilot CLI.
- [`cursor`](https://cursor.com/cli) – Cursor’s command-line interface.
- [`grok`](https://github.com/superagent-ai/grok-cli) – xAI’s Grok CLI.
- [`opencode`](https://github.com/sst/opencode) – OpenCode’s CLI for local workflows.
- [`qwen`](https://github.com/QwenLM/qwen-code) – Alibaba’s Qwen Code CLI.

## 📟 Statusline Integration

Using the `require("sidekick.status")` API, you can easily integrate **Copilot LSP**
in your statusline.

<details>
<summary>Example for <a href="https://github.com/nvim-lualine/lualine.nvim">lualine.nvim</a></summary>

<!-- setup_lualine:start -->

```lua
{
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
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
  end,
}
```

<!-- setup_lualine:end -->

</details>

## 📄 License

Released under the [MIT License](LICENSE).
