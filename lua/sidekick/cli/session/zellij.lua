local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Zellij: sidekick.cli.Session
---@field zellij_pane_id string
---@field zellij string
local M = {}
M.__index = M
M.priority = 50
M.external = false

M.tpl = [[
layout {
    pane command="{cmd}" {
      borderless true
      focus true
      name "{name}"
      close_on_exit true
      {args}
   }
}
session_serialization false
]]

---@return sidekick.cli.terminal.Cmd?
function M:terminal()
  local layout = M.tpl
  layout = layout:gsub("{cmd}", self.tool.cmd[1])
  layout = layout:gsub("{name}", self.tool.name)
  if #self.tool.cmd == 1 then
    layout = layout:gsub("{args}", "")
  else
    local args = vim.list_slice(self.tool.cmd, 2)
    layout = layout:gsub("{args}", "args " .. table.concat(
      vim.tbl_map(function(a)
        return ("%q"):format(a)
      end, args),
      " "
    )) --[[@as string]]
  end

  local session = self.sid

  local layout_file = Config.state("zellij-layout-" .. session .. ".kdl")
  vim.fn.writefile(vim.split(layout, "\n"), layout_file)
  Util.set_state(session, { tool = self.tool.name, cwd = self.cwd })

  return {
    cmd = { "zellij", "--layout", layout_file, "attach", "--create", session },
    env = {
      ZELLIJ = false,
      ZELLIJ_SESSION_NAME = false,
      ZELLIJ_PANE_ID = false,
    },
  }
end

---@return sidekick.cli.terminal.Cmd?
function M:start()
  if vim.env.ZELLIJ and Config.cli.mux.create ~= "terminal" then
    Util.warn({
      ("Zellij does not support `opts.cli.mux.create = %q`."):format(Config.cli.mux.create),
      ("Falling back to `%q`."):format("terminal"),
      "Please update your config.",
    })
  end
  -- Zellij's scripting API is too limited, so
  -- always run embedded sessions
  return self:terminal()
end

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  -- Zellij's scripting API is too limited, so
  -- always run embedded sessions
  return self:terminal()
end

function M.sessions()
  local sessions = Util.exec({ "zellij", "list-sessions", "-ns" }, { notify = false }) or {}
  local ret = {} ---@type sidekick.cli.session.State[]
  local Terminal = require("sidekick.cli.terminal")

  -- Find the terminal instance attached to this zellij session.
  -- We need this to get the PIDs for deduplication, since zellij's
  -- API doesn't provide process information.
  local function find_pids(sid)
    local pids = {} ---@type integer[]
    for _, t in pairs(Terminal.terminals) do
      if t.mux_backend == "zellij" and t.mux_session == sid then
        vim.list_extend(pids, t.pids or {})
      end
    end
    return pids
  end

  for _, s in ipairs(sessions) do
    local state = Util.get_state(s)
    if state then
      ret[#ret + 1] = {
        id = "zellij: " .. s,
        cwd = state.cwd,
        tool = state.tool,
        mux_session = s,
        pids = find_pids(s),
      }
    end
  end

  return ret
end

function M:dump()
  if self.mux_session == nil then
    return
  end
  local ok, ret = Util.exec({ "zellij", "-s", self.mux_session, "action", "dump-screen", "-f", "--ansi" }, {
    notify = true,
  })
  if not ok or ret == "" then
    return
  end
  return ret
end

return M
