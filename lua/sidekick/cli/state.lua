local Config = require("sidekick.config")
local Session = require("sidekick.cli.session")
local Terminal = require("sidekick.cli.terminal")
local Util = require("sidekick.util")

local M = {}

---@class sidekick.cli.State
---@field tool sidekick.cli.Tool
---@field attached? boolean
---@field external? boolean
---@field installed? boolean
---@field session? sidekick.cli.Session
---@field started? boolean
---@field terminal? sidekick.cli.Terminal

---@class sidekick.cli.Filter
---@field attached? boolean
---@field cwd? boolean
---@field external? boolean
---@field installed? boolean
---@field name? string
---@field session? string
---@field started? boolean
---@field terminal? boolean

---@class sidekick.cli.With
---@field filter? sidekick.cli.Filter
---@field show? boolean
---@field focus? boolean
---@field attach? boolean
---@field all? boolean

---@param t sidekick.cli.State
---@param filter? sidekick.cli.Filter
function M.is(t, filter)
  filter = filter or {}
  return (filter.attached == nil or filter.attached == t.attached)
    and (filter.cwd == nil or (t.session and t.session.cwd == Session.cwd()))
    and (filter.external == nil or filter.external == t.external)
    and (filter.installed == nil or filter.installed == t.installed)
    and (filter.name == nil or filter.name == t.tool.name)
    and (filter.session == nil or (t.session and t.session.id == filter.session))
    and (filter.started == nil or filter.started == t.started)
    and (filter.terminal == nil or filter.terminal == (t.terminal ~= nil))
end

---@param session sidekick.cli.Session
function M.get_state(session)
  ---@type sidekick.cli.State
  return setmetatable({
    session = session,
    installed = true, -- it's running, so it must be installed
  }, {
    __index = function(_, k)
      if k == "tool" or k == "started" or k == "external" then
        return session[k]
      elseif k == "attached" then
        return session:is_attached()
      elseif k == "terminal" then
        return session.backend == "terminal" and Terminal.get(session.id) or nil
      end
    end,
  })
end

---@param filter? sidekick.cli.Filter
---@return sidekick.cli.State[]
function M.get(filter)
  filter = filter or {}
  local all = {} ---@type sidekick.cli.State[]
  local sids = {} ---@type table<string, boolean>
  local sessions = filter.attached and Session.attached() or Session.sessions()

  for _, s in pairs(sessions) do
    -- if not attached, skip if another session with higher priority
    -- is running with overlapping pids
    local skip = false
    if not s:is_attached() then
      for _, s2 in pairs(sessions) do
        if s2 ~= s and Util.overlaps(s2.pids or {}, s.pids or {}) and s2.priority > s.priority then
          skip = true
          break
        end
      end
    end

    if not skip then
      local ss = M.get_state(s)
      all[#all + 1] = ss
      if not ss.external then
        sids[s.sid] = true
      end
    end
  end

  if not filter.attached then
    for name, tool in pairs(Config.tools()) do
      local sid = Session.sid({ tool = name })
      if not sids[sid] then
        all[#all + 1] = {
          tool = tool,
          installed = vim.fn.executable(tool.cmd[1]) == 1,
        }
      end
    end
  end

  local cwd = Session.cwd()

  ---@type sidekick.cli.State[]
  ---@param t sidekick.cli.State
  local ret = vim.tbl_filter(function(t)
    return M.is(t, filter)
  end, all)
  table.sort(ret, function(a, b)
    if a.installed ~= b.installed then
      return a.installed
    end
    -- sessions in cwd, or tools without a session
    local a_cwd = (not a.session or a.session.cwd == cwd or false)
    local b_cwd = (not b.session or b.session.cwd == cwd or false)
    if a_cwd ~= b_cwd then
      return a_cwd
    end
    if a.started ~= b.started then
      return a.started
    end
    if (a.terminal ~= nil) ~= (b.terminal ~= nil) then
      return a.terminal ~= nil
    end
    if a.external ~= b.external then
      return not a.external
    end
    return a.tool.name < b.tool.name
  end)
  return ret
end

--- Executes a callback with one or more attached sessions.
---@param cb fun(state: sidekick.cli.State, attached?: boolean):any?
---@param opts? sidekick.cli.With
function M.with(cb, opts)
  opts = opts or {}
  cb = vim.schedule_wrap(cb)

  ---@param state sidekick.cli.State
  local use = vim.schedule_wrap(function(state)
    if not state then
      return
    end
    local ret, attached = M.attach(state, { show = opts.show, focus = opts.focus })
    cb(ret, attached)
  end)

  local filter_attached = Util.merge(opts.filter, { attached = true })
  local attached = M.get(filter_attached)

  if #attached == 0 and opts.attach then
    require("sidekick.cli.ui.select").select({
      auto = true,
      filter = opts.filter,
      cb = use,
    })
  elseif #attached > 1 and not opts.all then
    require("sidekick.cli.ui.select").select({
      auto = true,
      filter = filter_attached,
      cb = use,
    })
  else
    vim.tbl_map(use, attached)
  end
end

---@param state sidekick.cli.State
---@param opts? {show?:boolean, focus?:boolean}
---@return sidekick.cli.State state, boolean attached whether we just attached
function M.attach(state, opts)
  opts = opts or {}
  local attached = state.session == nil or not state.attached
  local tool = state.tool

  -- if the session is already attached, the below is a no-op
  local session = state.session or Session.new({ tool = tool.name })
  session = Session.attach(session)

  state = M.get_state(session) -- update state
  local terminal = state.terminal
  if terminal then
    if opts.show then
      terminal:show()
      if opts.focus ~= false and terminal:is_running() then
        terminal:focus()
      end
    end
  elseif state.session then
    -- External session (tmux/kitty/zellij pane)
    if opts.focus and state.external and session.focus then
      session:focus()
    end
  elseif attached then
    Util.info("Attached to `" .. state.tool.name .. "`")
  end

  return state, attached
end

---@param state sidekick.cli.State
function M.detach(state)
  if state.session and state.attached then
    if state.terminal then
      state.terminal:close()
    else
      Session.detach(state.session)
      Util.info("Detached from `" .. state.tool.name .. "`")
    end
  end
  return state
end

return M
