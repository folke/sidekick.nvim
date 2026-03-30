---@type sidekick.cli.Config
return {
  cmd = { "amp" },
  is_proc = "\\<amp\\>",
  url = "https://ampcode.com",
  resume = { "threads", "continue" },
  continue = { "threads", "continue", "--last" },
}
