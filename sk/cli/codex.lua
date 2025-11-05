---@type sidekick.cli.Config
return {
  cmd = { "codex", "--enable", "web_search_request" },
  is_proc = "\\<codex\\>",
  url = "https://github.com/openai/codex",
  resume = { "resume" },
  continue = { "resume", "--last" },
}
