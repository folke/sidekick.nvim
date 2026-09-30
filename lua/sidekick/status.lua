local Config = require("sidekick.config")

local M = {}

---@class sidekick.lsp.Status
---@field busy boolean
---@field kind "Normal" | "Error" | "Warning" | "Inactive"
---@field message? string

---@class sidekick.cli.Status
---@field id string
---@field tool string
---@field cwd string

local status = {} ---@type table<integer, sidekick.lsp.Status>
local cli_sessions = {} ---@type table<string, sidekick.cli.Status>
local cli_last_update = 0

local levels = {
  Normal = vim.log.levels.INFO,
  Warning = vim.log.levels.WARN,
  Error = vim.log.levels.ERROR,
  Inactive = vim.log.levels.WARN,
}

local function update_cli_status()
  local Session = require("sidekick.cli.session")
  cli_sessions = {}
  for id, session in pairs(Session.attached()) do
    cli_sessions[id] = {
      id = session.id,
      tool = session.tool.name,
      cwd = session.cwd,
    }
  end
end

---@param res sidekick.lsp.Status
---@type lsp.Handler
function M.on_status(err, res, ctx)
  if err then
    return
  end
  status[ctx.client_id] = vim.deepcopy(res)
  local level = levels[res.kind or "Normal"] or vim.log.levels.INFO

  if Config.nes.enabled ~= false and res.message and level >= Config.copilot.status.level then
    local msg = "**Copilot:** " .. res.message
    if msg:find("not signed") then
      if package.loaded.copilot then
        msg = msg .. "\nPlease use `:Copilot auth` to sign in."
      else
        msg = msg .. "\nPlease use `:LspCopilotSignIn` to sign in."
      end
    end
    require("sidekick.util").notify(msg, res.kind == "Error" and vim.log.levels.ERROR or vim.log.levels.WARN)
  end
end

---@param client vim.lsp.Client
function M.attach(client)
  client.handlers.didChangeStatus = M.on_status
end

---@param buf? integer
---@return sidekick.lsp.Status?
function M.get(buf)
  if not Config.copilot.status.enabled then
    return
  end
  local client = Config.get_client(buf)
  return client and (status[client.id] or { busy = false, kind = "Normal" }) or nil
end

function M.setup()
  if Config.copilot.status.enabled then
    vim.api.nvim_create_autocmd("LspAttach", {
      group = Config.augroup,
      callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and Config.is_copilot(client) then
          M.attach(client)
        end
      end,
    })
    for _, client in ipairs(Config.get_clients()) do
      M.attach(client)
    end
  end

  vim.api.nvim_create_autocmd("User", {
    group = Config.augroup,
    pattern = { "SidekickCliAttach", "SidekickCliDetach" },
    callback = update_cli_status,
  })

  update_cli_status()
end

--- Get CLI session status
---@return sidekick.cli.Status[]
function M.cli()
  local now = vim.uv.now()
  if now - cli_last_update > 5000 then
    -- update periodically to detect sessions where `is_running()` returns false
    -- can happen when an external process stopped
    update_cli_status()
    cli_last_update = now
  end
  return vim.tbl_values(cli_sessions)
end

return M
