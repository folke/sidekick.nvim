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

  -- WezTerm only supports split mode (not terminal or window modes)
  if Config.cli.mux.create ~= "split" then
    Util.warn({
      ("WezTerm does not support `opts.cli.mux.create = %q`."):format(Config.cli.mux.create),
      ("Falling back to %q."):format("split"),
      "Please update your config.",
    })
  end

  -- Build command: wezterm cli split-pane --cwd <cwd> [split options] -- <tool.cmd>
  local cmd = { "wezterm", "cli", "split-pane", "--cwd", self.cwd }

  -- Add split direction (WezTerm: horizontal = left/right, vertical = top/bottom)
  -- Note: In WezTerm, "horizontal" means the split line is horizontal (panes side-by-side)
  if Config.cli.mux.split.vertical then
    table.insert(cmd, "--bottom")  -- Top-bottom split
  else
    table.insert(cmd, "--horizontal")  -- Side-by-side split
  end

  -- Add split size
  local size = Config.cli.mux.split.size
  if size > 0 and size <= 1 then
    -- Percentage (0-1)
    table.insert(cmd, "--percent")
    table.insert(cmd, tostring(math.floor(size * 100)))
  elseif size > 1 then
    -- Absolute cells
    table.insert(cmd, "--cells")
    table.insert(cmd, tostring(math.floor(size)))
  end

  -- Add command separator and tool command
  table.insert(cmd, "--")
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

  -- Save state to track this as a sidekick-created session
  Util.set_state(tostring(self.wezterm_pane_id), { tool = self.tool.name, cwd = self.cwd })

  Util.info(("Started **%s** in WezTerm pane %d"):format(self.tool.name, self.wezterm_pane_id))
end

--- Send text to WezTerm pane
---@param text string
function M:send(text)
  if not self.wezterm_pane_id then
    Util.error("Cannot send text: no pane ID available")
    return
  end

  Util.exec({
    "wezterm",
    "cli",
    "send-text",
    "--pane-id",
    tostring(self.wezterm_pane_id),
    "--no-paste",
    text,
  }, { notify = false })
end

--- Submit current input (send newline)
function M:submit()
  if not self.wezterm_pane_id then
    Util.error("Cannot submit: no pane ID available")
    return
  end

  Util.exec({
    "wezterm",
    "cli",
    "send-text",
    "--pane-id",
    tostring(self.wezterm_pane_id),
    "--no-paste",
    "\n",
  }, { notify = false })
end

--- Get process ID for a given TTY device
---@param tty string TTY device path like "/dev/ttys000"
---@return integer? pid
local function get_pid_from_tty(tty)
  if not tty then
    return nil
  end

  -- Extract tty name (e.g., "ttys000" from "/dev/ttys000")
  local tty_name = tty:match("/dev/(.+)$")
  if not tty_name then
    return nil
  end

  -- Use ps to find the process with this tty
  local lines = Util.exec({ "ps", "-o", "pid=,tty=", "-a" }, { notify = false })
  if not lines then
    return nil
  end

  for _, line in ipairs(lines) do
    local pid, line_tty = line:match("^%s*(%d+)%s+(%S+)")
    if line_tty == tty_name and pid then
      return tonumber(pid)
    end
  end

  return nil
end

--- Check if the WezTerm pane still exists
---@return boolean
function M:is_running()
  if not self.wezterm_pane_id then
    return false
  end

  -- List all panes and check if our pane_id exists
  local output = Util.exec({ "wezterm", "cli", "list", "--format", "json" }, { notify = false })
  if not output then
    return false
  end

  local ok, panes = pcall(vim.json.decode, table.concat(output, "\n"))
  if not ok or type(panes) ~= "table" then
    return false
  end

  for _, pane in ipairs(panes) do
    if pane.pane_id == self.wezterm_pane_id then
      return true
    end
  end

  return false
end

--- List all active sidekick sessions in WezTerm panes
---@return sidekick.cli.session.State[]
function M.sessions()
  -- Get all WezTerm panes
  local output = Util.exec({ "wezterm", "cli", "list", "--format", "json" }, { notify = false })
  if not output then
    return {}
  end

  local ok, panes = pcall(vim.json.decode, table.concat(output, "\n"))
  if not ok or type(panes) ~= "table" then
    return {}
  end

  local ret = {} ---@type sidekick.cli.session.State[]
  local tools = Config.tools()
  local Procs = require("sidekick.cli.procs")
  local procs = Procs.new()

  -- Walk through each pane's processes
  for _, pane in ipairs(panes) do
    -- Only include panes that were created by sidekick
    local state = Util.get_state(tostring(pane.pane_id))
    if not state then
      goto continue
    end

    local pid = get_pid_from_tty(pane.tty_name)

    if pid then
      procs:walk(pid, function(proc)
        for _, tool in pairs(tools) do
          if tool:is_proc(proc) then
            -- Parse cwd from file:// URL
            local cwd = pane.cwd and pane.cwd:gsub("^file://", "") or proc.cwd

            ret[#ret + 1] = {
              id = "wezterm:" .. pane.pane_id,
              cwd = cwd,
              tool = tool,
              wezterm_pane_id = pane.pane_id,
              pids = Procs.pids(pid),
            }
            return true
          end
        end
      end)
    end

    ::continue::
  end

  return ret
end

return M
