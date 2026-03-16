---@type sidekick.cli.Config
return {
  cmd = { "vibe" },
  is_proc = "\\<vibe\\>",
  url = "https://github.com/mistralai/mistral-vibe",
  continue = { "--continue" },
  format = function(text)
    local Text = require("sidekick.text")

    -- Quote paths with special characters
    Text.transform(text, function(str)
      return str:find("[^%w%._/\\%-()%[%]{}]") and ('"' .. str .. '"') or str
    end, "SidekickLocFile")

    local ret = Text.to_string(text)

    -- Strip space between path and line/char references
    ret = ret:gsub('(@"[^"]+") (:L[%d:LC%-]+)', "%1%2") -- quoted paths
    ret = ret:gsub("(@[^@%s]+) (:L[%d:LC%-]+)", "%1%2") -- unquoted paths

    return ret
  end,
}
