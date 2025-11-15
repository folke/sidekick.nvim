local Config = require("sidekick.config")
local Util = require("sidekick.util")

---@class sidekick.cli.muxer.WezTerm: sidekick.cli.Session
---@field wezterm_pane_id number
local M = {}
M.__index = M
M.priority = 70  -- Higher than tmux/zellij for backwards compatibility
M.external = false  -- Only works from inside WezTerm

--- Initialize WezTerm session, verify we're running inside WezTerm
function M:init()
  if not vim.env.WEZTERM_PANE then
    Util.warn("WezTerm backend requires running inside WezTerm")
    return
  end

  if vim.fn.executable("wezterm") ~= 1 then
    Util.warn("wezterm executable not found in PATH")
    return
  end
end

--- Start a new WezTerm split pane session
---@return sidekick.cli.terminal.Cmd?
function M:start()
  if not vim.env.WEZTERM_PANE then
    Util.error("Cannot start WezTerm session: not running inside WezTerm")
    return
  end

  -- Build command: wezterm cli split-pane --cwd <cwd> -- <tool.cmd>
  local cmd = { "wezterm", "cli", "split-pane", "--cwd", self.cwd, "--" }
  vim.list_extend(cmd, self.tool.cmd)

  -- Execute and capture pane_id
  local output = Util.exec(cmd, { notify = true })
  if not output or #output == 0 then
    Util.error("Failed to create WezTerm split pane")
    return
  end

  -- Parse pane_id (wezterm cli split-pane returns just the pane ID number)
  self.wezterm_pane_id = tonumber(output[1])
  if not self.wezterm_pane_id then
    Util.error(("Failed to parse pane ID from WezTerm output: %s"):format(output[1]))
    return
  end

  self.started = true
  Util.info(("Started **%s** in WezTerm pane %d"):format(self.tool.name, self.wezterm_pane_id))
end

return M
