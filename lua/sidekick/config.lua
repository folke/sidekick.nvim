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
      events = { "ModeChanged *:n", "TextChanged", "User SidekickNesDone" },
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
      -- stylua: ignore
      keys = {
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
    -- stylua: ignore
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
    -- stylua: ignore
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

local state_dir = vim.fn.stdpath("state") .. "/sidekick"

local config = vim.deepcopy(defaults) --[[@as sidekick.Config]]
M.augroup = vim.api.nvim_create_augroup("sidekick", { clear = true })

---@param name string
function M.state(name)
  return state_dir .. "/" .. name
end

---@param opts? sidekick.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, vim.deepcopy(defaults), opts or {})

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

    M.validate("cli.win.layout", { "float", "left", "bottom", "top", "right" })
    M.validate("cli.mux.backend", { "tmux", "zellij" })
    M.validate("cli.mux.create", { "terminal", "window", "split" })
  end)
end

---@param key string
---@param t "string"|"number"|"boolean"|"table"|"function"|any[]
function M.validate(key, t)
  local value = vim.tbl_get(config, unpack(vim.split(key, "%.")))
  local err ---@type string?
  if type(t) == "table" then
    if not vim.tbl_contains(t, value) then
      err = ("Invalid value for option `opts.%s`\n- found: `%s`\n- expected: `%s`"):format(
        key,
        tostring(value),
        table.concat(vim.tbl_map(tostring, t), " | ")
      )
    end
  elseif type(value) ~= t then
    err = ("Expected `opts.%s` to be a `%s`, got `%s`"):format(key, t, type(value))
  end
  if err then
    require("sidekick.util").error(err)
    return false
  end
  return true
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

---@param name string
function M.get_tool(name)
  return require("sidekick.cli.tool").get(name)
end

function M.tools()
  local ret = {} ---@type table<string, sidekick.cli.Tool>
  for name in pairs(M.cli.tools) do
    ret[name] = M.get_tool(name)
  end
  return ret
end

function M.set_hl()
  local links = {
    DiffContext = "DiffChange",
    DiffAdd = "DiffText",
    DiffDelete = "DiffDelete",
    Sign = "Special",
    Chat = "NormalFloat",
    CliMissing = "DiagnosticError",
    CliAttached = "Special",
    CliStarted = "DiagnosticWarn",
    CliInstalled = "DiagnosticOk",
    CliUnavailable = "DiagnosticError",
    LocDelim = "Delimiter",
    LocFile = "@markup.link",
    LocNum = "@attribute",
    LocRow = "SidekickLocDelim",
    LocCol = "SidekickLocDelim",
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
