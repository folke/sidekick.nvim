---@type sidekick.cli.Config
return {
  cmd = { "agy" },
  is_proc = "\\<agy\\>",
  url = "https://antigravity.google/docs/cli-overview",
  resume = { "--continue" },
  continue = { "--continue" },
  format = function(text)
    require("sidekick.text").transform(text, function(str)
      return str:find("[^%w/_%.%-]") and ('"' .. str .. '"') or str
    end, "SidekickLocFile")
  end,
}
