local Docs = require("lazy.docs")

local M = {}

function M.update()
  local config = Docs.extract("lua/sidekick/config.lua", "\n(--@class sidekick%.Config.-\n})")
  config = config:gsub("%s*debug = false.\n", "\n")

  Docs.save({
    config = config,
    setup_base = Docs.extract("tests/fixtures/readme.lua", "local base = ({.-\n})"),
    setup_custom = Docs.extract("tests/fixtures/readme.lua", "local custom = ({.-\n})"),
    setup_blink = Docs.extract("tests/fixtures/readme.lua", "local blink = ({.-\n})"),
    setup_lualine = Docs.extract("tests/fixtures/readme.lua", "local lualine = ({.-\n})"),
  })
end

M.update()
print("Updated docs")

return M
