---@type sidekick.cli.Config
return {
  cmd = { "claude" },
  is_proc = "\\<claude\\>",
  url = "https://github.com/anthropics/claude-code",
  resume = { "--resume" },
  continue = { "--continue" },
  format = function(text)
    local Text = require("sidekick.text")

    Text.transform(text, function(str)
      return str:find("[^%w/_%.%-]") and ('"' .. str .. '"') or str
    end, "SidekickLocFile")

    local ret = Text.to_string(text)

  -- transform line ranges to a format that Claude understands
  ret = ret:gsub("@([^@]-) :L(%d+)%-L(%d+)", "@%1#L%2-%3")

  -- single line (and line+column) locations should also use `#L...` instead
  -- of the default ` :L...` formatting produced by the location helper.
  -- handle line+column first, then plain line to avoid double-replacing.
  ret = ret:gsub("@([^@]-) :L(%d+):C(%d+)", "@%1#L%2:C%3")
  ret = ret:gsub("@([^@]-) :L(%d+)", "@%1#L%2")

    return ret
  end,
}
