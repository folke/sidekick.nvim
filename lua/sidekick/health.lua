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

  start("Sidekick Copilot LSP")
  local found = false
  for name in pairs(vim.lsp.config._configs) do
    if Config.is_copilot(name) and vim.lsp.is_enabled(name) then
      ok(("Copilot LSP `%s` is enabled"):format(name))
      found = true
    end
  end
  if not found then
    error("No Copilot LSP client is enabled")
  end

  for _, client in ipairs(Config.get_clients()) do
    if client.handlers["didChangeStatus"] == require("sidekick.status").on_status then
      ok("Sidekick is handling Copilot LSP status notifications for client: " .. client.id)
    else
      error("Sidekick is not handling Copilot LSP status notifications for client: " .. client.id)
    end
  end

  start("Sidekick AI CLI")
  if vim.o.autoread then
    ok("autoread is enabled")
  else
    warn("autoread is disabled, file changes from AI CLI tools will not be detected automatically")
  end

  for _, tool in ipairs(require("sidekick.cli").get_tools()) do
    if tool.installed then
      ok("`" .. tool.name .. "` is installed")
    else
      warn("`" .. tool.name .. "` is not installed")
    end
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
end

return M
