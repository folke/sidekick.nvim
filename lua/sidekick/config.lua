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

local state_dir = vim.fn.stdpath("state") .. "/sidekick"

local config = vim.deepcopy(defaults) --[[@as sidekick.Config]]

---@param name string
function M.state(name)
  return state_dir .. "/" .. name
end

---@param opts? sidekick.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  vim.fn.mkdir(state_dir, "p")

  local group = vim.api.nvim_create_augroup("sidekick", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and M.is_copilot(client) then
        require("sidekick.status").attach(client)
      end
    end,
  })

  vim.schedule(function()
    local Util = require("sidekick.util")

    M.set_hl()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = M.set_hl,
    })

    -- Copilot requires the custom didFocus notification
    local function notify_focus()
      local buf = vim.api.nvim_get_current_buf()
      local client = M.get_client(buf)
      ---@diagnostic disable-next-line: param-type-mismatch
      return client and client:notify("textDocument/didFocus", { textDocument = { uri = vim.uri_from_bufnr(buf) } })
        or nil
    end

    ---@param events string[]
    ---@param fn fun()
    local function on(events, fn)
      for _, event in ipairs(events) do
        local name, pattern = event:match("^(%S+)%s*(.*)$") --[[@as string, string]]
        vim.api.nvim_create_autocmd(name, {
          pattern = pattern ~= "" and pattern or nil,
          group = group,
          callback = fn,
        })
      end
    end

    on(M.nes.clear.events, require("sidekick").clear)
    on(M.nes.trigger.events, Util.debounce(require("sidekick.nes").update, M.nes.debounce))
    on({ "BufEnter", "WinEnter" }, Util.debounce(notify_focus, 10))

    if M.nes.clear.esc then
      local ESC = vim.keycode("<Esc>")
      vim.on_key(function(_, typed)
        if typed == ESC then
          require("sidekick").clear()
        end
      end, nil)
    end

    -- attach to existing copilot clients
    notify_focus()
    for _, client in ipairs(M.get_clients()) do
      require("sidekick.status").attach(client)
    end
  end)
end

---@param client vim.lsp.Client
function M.is_copilot(client)
  return client.name and client.name:lower():find("copilot")
end

---@param filter? vim.lsp.get_clients.Filter
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
