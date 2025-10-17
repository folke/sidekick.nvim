local Context = require("sidekick.cli.context")
local State = require("sidekick.cli.state")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.Prompt
---@field msg string

---@class sidekick.cli.Message
---@field msg? string
---@field prompt? string
---@field text? sidekick.Text[]

---@class sidekick.cli.Config
---@field cmd string[] Command to run the CLI tool
---@field env? table<string, string|false> Environment variables to set when running the command
---@field url? string Web URL to open when the tool is not installed
---@field keys? table<string, sidekick.cli.Keymap|false>
---@field is_proc? (fun(self:sidekick.cli.Tool, proc:sidekick.cli.Proc):boolean)|string Regex or function to identity a running process
---@field mux_focus? boolean wether the tool needs to be focused in order to receive input
---@field format? fun(text:sidekick.Text[], str:string):string?

---@class sidekick.cli.Show
---@field name? string
---@field focus? boolean
---@field filter? sidekick.cli.Filter
---@field all? boolean

---@class sidekick.cli.Hide
---@field name? string
---@field filter? sidekick.cli.Filter
---@field all? boolean

---@class sidekick.cli.Send: sidekick.cli.Show,sidekick.cli.Message
---@field submit? boolean

--- Keymap options similar to `vim.keymap.set` and `lazy.nvim` mappings
---@class sidekick.cli.Keymap: vim.keymap.set.Opts
---@field [1] string keymap
---@field [2] string|sidekick.cli.Action
---@field mode? string|string[]

---@generic T: {name?:string, filter?:sidekick.cli.Filter}
---@param opts? T|string
---@return T
local function filter_opts(opts)
  opts = type(opts) == "string" and { name = opts } or opts or {}
  ---@cast opts {name?:string, filter?:sidekick.cli.Filter}
  opts.filter = opts.filter or {}
  opts.filter.name = opts.name or opts.filter.name or nil
  return opts
end

--- Select a prompt to send
---@param opts? sidekick.cli.Prompt|{cb:nil}
---@overload fun(cb:fun(msg?:string))
function M.prompt(opts)
  opts = opts or {}
  opts = type(opts) == "function" and { cb = opts } or opts --[[@as sidekick.cli.Prompt]]
  opts.cb = opts.cb or function(_, text)
    if text then
      M.send({ text = text })
    end
  end
  require("sidekick.cli.ui.prompt").select(opts)
end

--- Start or attach to a CLI tool
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
  opts = filter_opts(opts)
  State.with(function() end, {
    all = opts.all,
    attach = true,
    filter = opts.filter,
    focus = opts.focus,
    show = true,
  })
end

---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.toggle(opts)
  opts = filter_opts(opts)
  State.with(function(state, attached)
    if not state.terminal then
      return
    end
    if not attached then
      state.terminal:toggle()
    end
    if state.terminal:is_open() and opts.focus ~= false then
      state.terminal:focus()
    end
  end, {
    attach = true,
    filter = opts.filter,
  })
end

--- Toggle focus of the terminal window if it is already open
---@param opts? sidekick.cli.Show
---@overload fun(name: string)
function M.focus(opts)
  opts = filter_opts(opts)
  State.with(function(state)
    if not state.terminal then
      return
    end
    if state.terminal:is_focused() then
      state.terminal:blur()
    else
      state.terminal:focus()
    end
  end, {
    attach = true,
    filter = opts.filter,
    focus = false,
    show = true,
  })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.hide(opts)
  opts = filter_opts(opts)
  State.with(function(state)
    return state.terminal and state.terminal:hide()
  end, {
    all = opts.all,
    filter = Util.merge(opts.filter, { terminal = true }),
  })
end

---@param opts? sidekick.cli.Hide
---@overload fun(name: string)
function M.close(opts)
  opts = filter_opts(opts)
  State.with(State.detach, {
    all = opts.all,
    filter = Util.merge(opts.filter),
  })
end

-- Render a message template or prompt
---@param opts? sidekick.cli.Message|string
function M.render(opts)
  return Context.get():render(opts or "")
end

--- Send a message or prompt to a CLI
---@param opts? sidekick.cli.Send
---@overload fun(msg:string)
function M.send(opts)
  opts = opts or {}
  opts = type(opts) == "string" and { msg = opts } or opts

  if not opts.msg and not opts.prompt and Util.visual_mode() then
    opts.msg = "{selection}"
  end

  local msg, text = "", opts.text ---@type string?, sidekick.Text[]?
  if not text then
    msg, text = M.render(opts)
    if msg == "" or not text then
      Util.warn("Nothing to send.")
      return
    elseif msg == "\n" then
      msg = "" -- allow sending a new line
      text = {}
    end
  end

  State.with(function(state)
    Util.exit_visual_mode()
    vim.schedule(function()
      msg = state.tool:format(text)
      state.session:send(msg)
      if opts.submit then
        state.session:submit()
      end
    end)
  end, {
    attach = true,
    filter = opts.filter,
    focus = opts.focus,
    show = true,
  })
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
