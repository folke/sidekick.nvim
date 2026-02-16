---@type sidekick.cli.Config
return {
  cmd = { "codex" },
  is_proc = "\\<codex\\>",
  url = "https://github.com/openai/codex",
  resume = { "resume" },
  continue = { "resume", "--last" },
}
