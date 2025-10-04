---@class sidekick.config: sidekick.Config
local M = {}

M.ns = vim.api.nvim_create_namespace("sidekick.ui")

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
        width = 80,
        height = 20,
      },
      --- CLI Tool Keymaps
      --- default mode is `t`
      ---@type table<string, sidekick.cli.Keymap|false>
      keys = {
        -- -- disabled the stopinsert keymaps since it interferes with some tools
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
      opencode = {
        cmd = { "opencode" },
        -- HACK: https://github.com/sst/opencode/issues/445
        env = { OPENCODE_THEME = "system" },
        url = "https://github.com/sst/opencode",
      },
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
      quickfix        = "{quickfix}",
      selection       = "{selection}",
      ["function"]    = "{function}",
      class           = "{class}",
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

local state_dir = vim.fn.stdpath("state") .. "/sidekick"

local config = vim.deepcopy(defaults) --[[@as sidekick.Config]]
M.augroup = vim.api.nvim_create_augroup("sidekick", { clear = true })

---@param name string
function M.state(name)
  return state_dir .. "/" .. name
end

---@param opts? sidekick.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  vim.api.nvim_create_user_command("Sidekick", function(args)
    require("sidekick.commands").cmd(args)
  end, {
    range = true,
    nargs = "?",
    desc = "Sidekick",
    complete = function(_, line)
      return require("sidekick.commands").complete(line)
    end,
  })

  vim.schedule(function()
    vim.fn.mkdir(state_dir, "p")
    M.set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = M.augroup,
      callback = M.set_hl,
    })

    -- Track when a window was last focused
    vim.api.nvim_create_autocmd({ "WinEnter" }, {
      group = M.augroup,
      callback = function()
        local win = vim.api.nvim_get_current_win()
        vim.w[win].sidekick_visit = vim.uv.hrtime()
      end,
    })

    if M.nes.enabled ~= false then
      require("sidekick.nes").enable()
    end

    if M.copilot.status.enabled then
      require("sidekick.status").setup()
    end
  end)
end

---@param client vim.lsp.Client|string
function M.is_copilot(client)
  local name = type(client) == "table" and client.name or client --[[@as string]]
  return name and name:lower():find("copilot")
end

---@param filter? vim.lsp.get_clients.Filter
---@return vim.lsp.Client[]
function M.get_clients(filter)
  return vim.tbl_filter(M.is_copilot, vim.lsp.get_clients(filter))
end

---@param buf? number
function M.get_client(buf)
  return M.get_clients({ bufnr = buf or 0 })[1]
end

function M.set_hl()
  local links = {
    DiffContext = "DiffChange",
    DiffAdd = "DiffText",
    DiffDelete = "DiffDelete",
    Sign = "Special",
    Chat = "NormalFloat",
  }
  for from, to in pairs(links) do
    vim.api.nvim_set_hl(0, "Sidekick" .. from, { link = to, default = true })
  end
end

setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

return M
