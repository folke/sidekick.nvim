local Context = require("sidekick.cli.context")
local State = require("sidekick.cli.state")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.Prompt
---@field msg string

---@class sidekick.cli.Message
---@field msg? string
---@field prompt? string

---@class sidekick.cli.Config
---@field cmd string[] Command to run the CLI tool
---@field env? table<string, string|false> Environment variables to set when running the command
---@field url? string Web URL to open when the tool is not installed
---@field keys? table<string, sidekick.cli.Keymap|false>
---@field is_proc? (fun(self:sidekick.cli.Tool, proc:sidekick.cli.Proc):boolean)|string Regex or function to identity a running process

---@class sidekick.cli.Show
---@field name? string
---@field focus? boolean
---@field filter? sidekick.cli.Filter

---@class sidekick.cli.Hide
---@field name? string
---@field all? boolean

---@class sidekick.cli.Send: sidekick.cli.Show,sidekick.cli.Message
---@field submit? boolean
---@field render? boolean

--- Keymap options similar to `vim.keymap.set` and `lazy.nvim` mappings
---@class sidekick.cli.Keymap: vim.keymap.set.Opts
---@field [1] string keymap
---@field [2] string|sidekick.cli.Action
---@field mode? string|string[]

---@param opts? sidekick.cli.Show|string
local function show_opts(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  ---@cast opts sidekick.cli.Show
  opts.filter = opts.filter or {}
  opts.filter.name = opts.name or opts.filter.name or nil
  return opts
end

---@param opts? sidekick.cli.Prompt|{cb:nil}
---@overload fun(cb:fun(msg?:string))
function M.prompt(opts)
  opts = opts or {}
  opts = type(opts) == "function" and { cb = opts } or opts --[[@as sidekick.cli.Prompt]]
  opts.cb = opts.cb or function(msg)
    if msg then
      M.send({ msg = msg, render = false })
    end
  end
  require("sidekick.cli.ui.prompt").select(opts)
end

---@param opts? sidekick.cli.Select|{cb:nil}|{focus?:boolean}
---@overload fun(cb:fun(state?:sidekick.cli.State))
function M.select(opts)
  opts = opts or {}
  opts = type(opts) == "function" and { cb = opts } or opts --[[@as sidekick.cli.Select]]
  opts.cb = opts.cb
    or function(state)
      if state then
        State.attach(state, { show = true, focus = opts.focus })
      end
    end
  require("sidekick.cli.ui.select").select(opts)
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.show(opts)
  opts = show_opts(opts)
  M.with(function(t) end, { filter = opts.filter, create = true, show = true, focus = opts.focus })
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.toggle(opts)
  opts = show_opts(opts)
  State.with(function(state)
    local t = state.terminal
    if not t then
      return
    end
    t:toggle()
    if t:is_open() and opts.focus ~= false then
      t:focus()
    end
  end, { filter = opts.filter, create = true })
end

--- Toggle focus of the terminal window if it is already open
---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.focus(opts)
  opts = show_opts(opts)
  State.with(function(state)
    local t = state.terminal
    if not t then
      return
    end
    if t:is_focused() then
      t:blur()
    else
      t:focus()
    end
  end, { filter = opts.filter, create = true, show = true, focus = opts.focus })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.hide(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:hide()
  end, { filter = { name = opts.name, running = true }, all = opts.all }, { filter = { terminal = true } })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.close(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  M.with(function(t)
    t:close()
  end, { filter = { name = opts.name, running = true }, all = opts.all }, { filter = { terminal = true } })
end

---@param opts? sidekick.cli.Message|string
function M.render(opts)
  return Context.get():render(opts or "")
end

---@param opts? sidekick.cli.Send
---@overload fun(msg:string)
function M.send(opts)
  opts = opts or {}
  opts = type(opts) == "string" and { msg = opts } or opts

  if not opts.msg and not opts.prompt and Util.visual_mode() then
    opts.msg = "{selection}"
  end

  local msg = opts.render ~= false and M.render(opts) or opts.msg
  if not msg then
    Util.warn("Nothing to send.")
    return
  end

  State.with(function(state)
    Util.exit_visual_mode()
    vim.schedule(function()
      if opts.focus ~= false and state.terminal then
        state.terminal:focus()
      end
      state.session:send(msg .. "\n")
      if opts.submit then
        state.session:submit()
      end
    end)
  end, { filter = opts.filter, create = true, show = true })
end

---@deprecated use `require("sidekick.cli").prompt()`
function M.select_prompt(...)
  Util.deprecate('require("sidekick.cli").select_prompt()', 'require("sidekick.cli").prompt()')
  return M.prompt(...)
end

---@deprecated use `require("sidekick.cli").select()`
function M.select_tool(...)
  Util.deprecate('require("sidekick.cli").select_tool()', 'require("sidekick.cli").select()')
  return M.select(...)
end

---@deprecated use `require("sidekick.cli").send()`
function M.ask(...)
  Util.deprecate('require("sidekick.cli").ask()', 'require("sidekick.cli").send()')
  return M.send(...)
end

return M
