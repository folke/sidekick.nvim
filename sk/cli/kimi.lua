---@type sidekick.cli.Config
return {
  cmd = { "kimi" },
  is_proc = "\\<kimi\\>",
  url = "https://github.com/MoonshotAI/kimi-code",
  resume = { "--session" },
  continue = { "--continue" },
  format = function(text)
    local Text = require("sidekick.text")

    Text.transform(text, function(str)
      return str:find("[^%w/_%.%-]") and ('"' .. str .. '"') or str
    end, "SidekickLocFile")

    local ret = Text.to_string(text)

    -- transform line ranges to a format that Kimi Code understands
    ret = ret:gsub("@([^@]-) :L(%d+)%-L(%d+)", "@%1#L%2-%3")

    return ret
  end,
}
