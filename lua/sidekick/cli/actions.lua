local Config = require("sidekick.config")

---@alias sidekick.cli.Action fun(terminal: sidekick.cli.Terminal):string?
---@type table<string, sidekick.cli.Action>
local M = {}

function M.prompt(t)
  vim.cmd.stopinsert() -- needed, since otherwise Neovim will do this

  vim.schedule(function()
    local Cli = require("sidekick.cli")
    Cli.prompt(function(prompt)
      vim.schedule(function()
        vim.cmd.startinsert()
      end)
      if prompt then
        t:send(prompt .. "\n")
      end
    end)
  end)
end

---@param source string
---@param t sidekick.cli.Terminal
local function picker(source, t)
  vim.cmd.stopinsert()
  vim.schedule(function()
    require("sidekick.cli.picker").open(source, { filter = { session = t.id } }, {
      on_show = function()
        t.normal_mode = false
      end,
    })
  end)
end

function M.files(t)
  picker("files", t)
end

function M.buffers(t)
  picker("buffers", t)
end

---@param dir "h"|"j"|"k"|"l"
local function nav(dir)
  ---@type sidekick.cli.Action
  return function(terminal)
    local at_edge = vim.fn.winnr() == vim.fn.winnr(dir)
    if at_edge or terminal:is_float() then
      -- When running under a mux backend (e.g., tmux via psmux on Windows),
      -- returning the key as an expr string passes through Neovim's terminal
      -- emulation, which can mangle control characters (e.g., C-j becomes CR).
      -- Send the key directly to the mux pane instead.
      if terminal.parent and terminal.parent.send_key then
        vim.schedule(function()
          terminal.parent:send_key(("C-%s"):format(dir))
        end)
        return
      end
      return ("<c-%s>"):format(dir)
    end
    vim.schedule(function()
      (Config.cli.win.nav or vim.cmd.wincmd)(dir)
    end)
  end
end

M.nav_left = nav("h")
M.nav_down = nav("j")
M.nav_up = nav("k")
M.nav_right = nav("l")

return M
