local Config = require("sidekick.config")
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

  local conf = {} ---@type string[]
  for _, f in ipairs({ "/etc/tmux.conf", "~/.tmux.conf", (vim.env.XDG_CONFIG_HOME or "~/.config") .. "/tmux/tmux.conf" }) do
    f = vim.fs.normalize(f)
    if vim.fn.filereadable(f) == 1 then
      conf[#conf + 1] = "source-file " .. f
    end
  end

  local conf_file = Config.state("tmux-" .. self.session.id .. ".conf")
  vim.fn.writefile(conf, conf_file)

  local tool_cmd_str = table.concat(self.tool.cmd, " ")
  local new_shell_cmd = "tmux set-option status off; " .. tool_cmd_str
  local cmd = { "tmux", "-f", conf_file, "new", "-A", "-s", self.session.id, new_shell_cmd }
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
