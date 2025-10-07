local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Zellij: sidekick.cli.Session
---@field zellij_pane_id string
---@field zellij string
local M = {}
M.__index = M

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

  local layout_file = Config.state("zellij-layout-" .. self.id .. ".kdl")
  vim.fn.writefile(vim.split(layout, "\n"), layout_file)
  Util.set_state(self.id, { tool = self.tool.name, cwd = self.cwd })

  return {
    cmd = { "zellij", "--layout", layout_file, "attach", "--create", self.id },
    env = {
      ZELLIJ = false,
      ZELLIJ_SESSION_NAME = false,
      ZELLIJ_PANE_ID = false,
    },
  }
end

---@return sidekick.cli.terminal.Cmd?
function M:attach()
  if not self.started and vim.env.ZELLIJ and Config.cli.mux.create ~= "terminal" then
    Util.warn({
      ("Zellij does not support `opts.cli.mux.create = %q`."):format(Config.cli.mux.create),
      ("Falling back to `%q`."):format("terminal"),
      "Please update your config.",
    })
  end
  do
    -- Zellij's scripting API is too limited, so
    -- always run embedded sessions
    return self:terminal()
  end

  -- if self.started then
  --   if self.sid == self.mux_session then
  --     return {
  --       cmd = { "zellij", "attach", self.sid },
  --       env = {
  --         ZELLIJ = false,
  --         ZELLIJ_SESSION_NAME = false,
  --         ZELLIJ_PANE_ID = false,
  --       },
  --     }
  --   end
  --   return -- nothing to do
  -- end
  --
  -- if Config.cli.mux.create == "terminal" or vim.env.ZELLIJ == nil then
  --   return self:terminal()
  -- elseif Config.cli.mux.create == "split" then
  --   local cmd = { "zellij", "run", "--cwd", self.cwd, "-d" }
  --   cmd[#cmd + 1] = Config.cli.mux.split.vertical and "right" or "down"
  --   -- local size = Config.cli.mux.split.size
  --   -- vim.list_extend(cmd, { "-l", tostring(size <= 1 and ((size * 100) .. "%") or size) })
  --
  --   cmd[#cmd + 1] = "--"
  --   vim.list_extend(cmd, self.tool.cmd)
  --   Util.exec(cmd)
  -- end
end

function M.sessions()
  local sessions = Util.exec({ "zellij", "list-sessions", "-ns" }, { notify = false }) or {}
  local ret = {} ---@type sidekick.cli.session.State[]

  for _, s in ipairs(sessions) do
    local state = Util.get_state(s)
    if state then
      ret[#ret + 1] = {
        id = s,
        cwd = state.cwd,
        tool = state.tool,
        mux_session = s,
      }
    end
  end

  return ret
end

return M
