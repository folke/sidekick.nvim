---@alias sidekick.cli.Action fun(terminal: sidekick.cli.Terminal)
---@type table<string, sidekick.cli.Action>
local M = {}

function M.prompt(t)
  local Cli = require("sidekick.cli")
  Cli.prompt(function(prompt)
    vim.schedule(function()
      vim.cmd.startinsert()
    end)
    if prompt then
      t:send(prompt .. "\n")
    end
  end)
end

return M
