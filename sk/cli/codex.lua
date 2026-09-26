---@type sidekick.cli.Config
return {
  cmd = { "codex", "--no-alt-screen" },
  is_proc = "\\<codex\\>",
  url = "https://github.com/openai/codex",
  resume = { "resume" },
  continue = { "resume", "--last" },
}
