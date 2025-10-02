local Util = require("sidekick.util")

---@class sidekick.cli.muxer.Tmux: sidekick.cli.Muxer
local M = {}
M.backend = "tmux"
setmetatable(M, require("sidekick.cli.mux"))

---@return sidekick.cli.Tool.spec?
function M:cmd()
  if vim.fn.executable("tmux") ~= 1 then
    Util.error("tmux executable not found on $PATH")
    return
  end

  local cmd = { "tmux", "new", "-A", "-s", self.session.id }
  vim.list_extend(cmd, self.tool.cmd)
  vim.list_extend(cmd, { ";", "set-option", "status", "off" })
  return { cmd = cmd }
end

function M._sessions()
  local ret = vim.system({ "tmux", "list-sessions", "-F", "#{session_name}" }, { text = true }):wait()
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
