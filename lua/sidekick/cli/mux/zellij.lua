local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Zellij: sidekick.cli.Muxer
local M = {}
M.backend = "zellij"
setmetatable(M, require("sidekick.cli.mux"))

M.tpl = [[
layout {
    pane command="{cmd}" {
      borderless true
      focus true
      name "{name}"
      close_on_exit {close_on_exit}
      {args}
   }
}
session_serialization false
]]

---@return sidekick.cli.Tool.spec?
function M:cmd()
  if vim.fn.executable("zellij") ~= 1 then
    Util.error("zellij executable not found on $PATH")
    return
  end

  local layout = M.tpl
  layout = layout:gsub("{cmd}", self.tool.cmd[1])
  layout = layout:gsub("{name}", self.tool.name)
  local close_on_exit = self.tool.close_on_exit
  if close_on_exit == nil then -- Default to true
    close_on_exit = true
  end
  layout = layout:gsub("{close_on_exit}", tostring(close_on_exit))
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

  local layout_file = Config.state("zellij-layout-" .. self.session.id .. ".kdl")
  vim.fn.writefile(vim.split(layout, "\n"), layout_file)

  return {
    cmd = { "zellij", "--layout", layout_file, "attach", "--create", self.session.id },
    env = {
      ZELLIJ = false,
      ZELLIJ_SESSION_NAME = false,
      ZELLIJ_PANE_ID = false,
    },
  }
end

function M._sessions()
  local ret = vim.system({ "zellij", "list-sessions", "-ns" }, { text = true }):wait()
  if ret.code ~= 0 then
    return {}
  end
  local sessions = {} ---@type string[]
  for _, line in ipairs(vim.split(ret.stdout, "\n", { plain = true })) do
    sessions[#sessions + 1] = line:match("^(sidekick .+)$")
  end
  return sessions
end

return M
