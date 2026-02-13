---@type sidekick.cli.Config
return {
  cmd = { "cortex" },
  is_proc = "\\<cortex\\>",
  url = "https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli",
  resume = { "resume" },
  continue = { "--continue" },
  format = function(text)
    local Text = require("sidekick.text")

    Text.transform(text, function(str)
      return str:find("[^%w/_%.%-]") and ('"' .. str .. '"') or str
    end, "SidekickLocFile")

    local ret = Text.to_string(text)
    ret = ret:gsub("@([^@]-) :L(%d+)%-L(%d+)", "@%1#L%2-%3")
    return ret
  end,
}
