local Config = require("sidekick.config")

local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error

function M.check()
  start("Sidekick")

  if vim.fn.has("nvim-0.11.2") == 1 then
    ok("Using Neovim >= 0.11.2")
  else
    error("Neovim >= 0.11.2 is required")
    return
  end

  local clients = Config.get_clients()

  start("Sidekick Copilot LSP")

  local found = #clients > 0
  for name in pairs(vim.lsp.config._configs) do
    if Config.is_copilot(name) and vim.lsp.is_enabled(name) then
      ok(("Copilot LSP `%s` is enabled"):format(name))
      found = true
    end
  end
  if not found then
    error("No Copilot LSP server is enabled with `vim.lsp.enable(...)`")
  end

  local names = {} ---@type table<string,boolean>
  for _, client in ipairs(clients) do
    local cmd = vim.inspect(client.config.cmd):gsub("\\", "/")
    if cmd:find("/copilot.lua/", 0, true) then
      ok("Using `copilot.lua`'s bundled LSP server")
    elseif cmd:find("/copilot.vim/", 0, true) then
      ok("Using `copilot.vim`s bundled LSP server")
    end
    names[client.name] = true
    if client.handlers["didChangeStatus"] == require("sidekick.status").on_status then
      ok("Sidekick is handling Copilot LSP status notifications for client: " .. client.id)
    else
      error("Sidekick is not handling Copilot LSP status notifications for client: " .. client.id)
    end
  end
  if vim.tbl_count(names) > 1 then
    error("You have multiple different LSP servers running: " .. table.concat(vim.tbl_map(function(n)
      return "`" .. n .. "`"
    end, names)))
  end

  start("Sidekick AI CLI")
  if vim.o.autoread then
    ok("autoread is enabled")
  else
    warn("autoread is disabled, file changes from AI CLI tools will not be detected automatically")
  end

  if Config.cli.mux.enabled then
    ok("Terminal multiplexer integration is enabled")
  else
    ok("Terminal multiplexer integration is disabled")
  end

  for _, mux in ipairs({ "tmux", "zellij" }) do
    if vim.fn.executable(mux) == 1 then
      ok("`" .. mux .. "` is installed")
    elseif mux == Config.cli.mux.backend then
      error("Multiplexer backend `" .. mux .. "` is not installed")
    else
      ok("`" .. mux .. "` is not installed, but it's not the configured backend")
    end
  end

  local tools = require("sidekick.config").tools()
  local tool_names = vim.tbl_keys(tools) ---@type string[]
  table.sort(tool_names)
  for _, name in ipairs(tool_names) do
    local tool = tools[name]
    if vim.fn.executable(tool.cmd[1]) == 1 then
      ok("`" .. tool.name .. "` is installed")
    else
      warn("`" .. tool.name .. "` is not installed")
    end
  end
end

return M
