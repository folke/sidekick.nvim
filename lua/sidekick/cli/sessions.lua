local M = {}

--- Discover sessions from all CLIs
---@param opts? {cwd?: string, limit?: number}
---@return sidekick.cli.session.Info[]
function M.discover_all_sessions(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local limit = opts.limit or 50

  local Config = require("sidekick.config")
  local Tool = require("sidekick.cli.tool")
  local all_sessions = {}

  -- Get all configured tools
  local tools = Config.cli.tools or {}
  for name, _ in pairs(tools) do
    local tool = Tool.get(name)
    if tool and tool.config.discover_sessions then
      local ok, sessions = pcall(tool.config.discover_sessions, cwd, limit)
      if ok and sessions then
        vim.list_extend(all_sessions, sessions)
      end
    end
  end

  -- Sort all sessions by updated timestamp (descending, newest first)
  table.sort(all_sessions, function(a, b)
    return a.updated > b.updated
  end)

  -- Apply global limit
  if #all_sessions > limit then
    local limited = {}
    for i = 1, limit do
      limited[i] = all_sessions[i]
    end
    return limited
  end

  return all_sessions
end

--- Resume a session
---@param session sidekick.cli.session.Info
---@param opts? {show?: boolean, focus?: boolean}
function M.resume_session(session, opts)
  opts = opts or {}
  local Config = require("sidekick.config")
  local Session = require("sidekick.cli.session")
  local State = require("sidekick.cli.state")
  local Tool = require("sidekick.cli.tool")
  local Util = require("sidekick.util")

  -- Ensure session backends are registered
  Session.setup()

  -- Get tool configuration
  local tool = Tool.get(session.cli_name)
  if not tool then
    Util.error("Unknown CLI tool: " .. session.cli_name)
    return
  end

  if not tool.config.resume then
    Util.error("CLI tool " .. session.cli_name .. " does not support resuming sessions")
    return
  end

  -- Handle existing sessions
  local sessions = Session.sessions()
  for _, existing_session in pairs(sessions) do
    local existing_state = State.get_state(existing_session)

    if existing_session.tool.name == session.cli_name then
      -- Same CLI: close it
      if existing_state.terminal then
        existing_state.terminal:close()
      else
        Session.detach(existing_session)
      end
    elseif existing_state.terminal and existing_state.terminal:is_open() then
      -- Different CLI with open terminal: hide it
      existing_state.terminal:hide()
    end
  end

  -- Build command with resume arguments
  local cmd = vim.deepcopy(tool.cmd)
  vim.list_extend(cmd, tool.config.resume)
  vim.list_extend(cmd, { session.id })

  -- Clone tool with new command
  local resume_tool = tool:clone({ cmd = cmd })

  -- Create session
  local new_session = Session.new({
    tool = resume_tool,
    cwd = session.cwd,
  })

  -- Attach and show
  local state = {
    tool = resume_tool,
    session = new_session,
    cwd = session.cwd,
  }

  State.attach(state, {
    show = opts.show ~= false,
    focus = opts.focus ~= false,
  })
end

return M
