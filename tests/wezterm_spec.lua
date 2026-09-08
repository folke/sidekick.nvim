---@module 'luassert'

local WezTerm = require("sidekick.cli.session.wezterm")
local Config = require("sidekick.config")
local Util = require("sidekick.util")
local Session = require("sidekick.cli.session")

-- Minimal tool stub for building session objects
local function make_tool(opts)
  opts = opts or {}
  return {
    name = opts.name or "claude",
    cmd = opts.cmd or { "claude" },
    env = opts.env or {},
    config = { env = {} },
    keys = {},
    is_proc = function() return false end,
    clone = function(self, o)
      return vim.tbl_extend("force", self, o or {})
    end,
  }
end

-- Build a session object directly without going through Session.new
-- (avoids needing a full Config setup for most unit tests)
local function make_session(opts)
  opts = opts or {}
  local tool = opts.tool or make_tool()
  local self = setmetatable({
    tool = tool,
    cwd = opts.cwd or "/home/user/project",
    sid = opts.sid or "claude abc123456789",
    id = opts.id,
    backend = "wezterm",
    started = opts.started or false,
    mux_session = opts.mux_session,
    wezterm_pane_id = opts.wezterm_pane_id,
    wezterm_pid = opts.wezterm_pid,
    external = opts.external,
  }, WezTerm)
  self.id = self.id or self.sid
  return self
end

-- ── cwd_from_uri ────────────────────────────────────────────────────────────

describe("WezTerm.cwd_from_uri", function()
  local cases = {
    { "file://hostname.local/Users/james/projects/foo", "/Users/james/projects/foo" },
    { "file://dsl-lt-1124.local/Users/james/projects/sidekick.nvim", "/Users/james/projects/sidekick.nvim" },
    { "file:///home/user/project", "/home/user/project" },
    { "/already/absolute", "/already/absolute" },
    { nil, nil },
  }

  for _, case in ipairs(cases) do
    it(("parses %s"):format(vim.inspect(case[1])), function()
      assert.are.same(case[2], WezTerm.cwd_from_uri(case[1]))
    end)
  end
end)

-- ── root_pid ─────────────────────────────────────────────────────────────────

describe("WezTerm.root_pid", function()
  local original_exec

  before_each(function()
    original_exec = Util.exec
  end)

  after_each(function()
    Util.exec = original_exec
  end)

  it("returns the process whose ppid is not in the set", function()
    -- Shell (1234) -> claude (5678): root is 1234
    Util.exec = function(cmd, _)
      if cmd[1] == "ps" then
        return { "  1234  900", "  5678 1234" }, "  1234  900\n  5678 1234\n"
      end
    end
    assert.are.same(1234, WezTerm.root_pid("/dev/ttys001"))
  end)

  it("returns a pid when only one process is on the tty", function()
    Util.exec = function(cmd, _)
      if cmd[1] == "ps" then
        return { "  9999  1" }, "  9999  1\n"
      end
    end
    local pid = WezTerm.root_pid("/dev/ttys042")
    assert.is_not_nil(pid)
  end)

  it("returns nil when ps returns nothing", function()
    Util.exec = function(_, _)
      return nil
    end
    assert.is_nil(WezTerm.root_pid("/dev/ttys001"))
  end)

  it("passes the short tty name (without /dev/) to ps", function()
    local captured_cmd
    Util.exec = function(cmd, _)
      captured_cmd = cmd
      return { "  1 0" }, "  1 0\n"
    end
    WezTerm.root_pid("/dev/ttys007")
    -- The -t argument should be the short form
    local t_idx
    for i, v in ipairs(captured_cmd) do
      if v == "-t" then t_idx = i end
    end
    assert.is_not_nil(t_idx)
    assert.are.same("ttys007", captured_cmd[t_idx + 1])
  end)
end)

-- ── add_cmd ──────────────────────────────────────────────────────────────────

describe("WezTerm session:add_cmd", function()
  it("appends tool.cmd when there are no env vars", function()
    local s = make_session({ tool = make_tool({ cmd = { "claude", "--no-auto-accept" } }) })
    local cmd = { "wezterm", "cli", "spawn" }
    s:add_cmd(cmd)
    assert.are.same({ "wezterm", "cli", "spawn", "claude", "--no-auto-accept" }, cmd)
  end)

  it("prepends 'env KEY=VAL' for each env var that is not false", function()
    local s = make_session({
      tool = make_tool({
        cmd = { "claude" },
        env = { FOO = "bar", SKIP = false },
      }),
    })
    local cmd = { "wezterm", "cli", "spawn" }
    s:add_cmd(cmd)
    -- 'env' prefix should appear
    assert.are.same("env", cmd[4])
    -- tool cmd should come after env vars
    assert.are.same("claude", cmd[#cmd])
    -- false values should not appear
    for _, v in ipairs(cmd) do
      assert.is_not.equal("SKIP=false", v)
      assert.is_not.equal("false", v)
    end
  end)

  it("does not prepend 'env' when all env vars are false", function()
    local s = make_session({
      tool = make_tool({ cmd = { "claude" }, env = { REMOVE_ME = false } }),
    })
    local cmd = {}
    s:add_cmd(cmd)
    assert.are.same({ "claude" }, cmd)
  end)
end)

-- ── spawn ────────────────────────────────────────────────────────────────────

describe("WezTerm session:spawn", function()
  local original_exec

  before_each(function()
    original_exec = Util.exec
  end)

  after_each(function()
    Util.exec = original_exec
  end)

  it("sets wezterm_pane_id, id, mux_session and started from CLI output", function()
    Util.exec = function(_, _)
      return { "42" }, "42\n"
    end
    local s = make_session()
    s:spawn({ "wezterm", "cli", "spawn" })
    assert.are.same(42, s.wezterm_pane_id)
    assert.are.same("wezterm: 42", s.id)
    assert.are.same("42", s.mux_session)
    assert.is_true(s.started)
  end)

  it("does nothing when the command fails", function()
    Util.exec = function(_, _)
      return nil
    end
    local s = make_session()
    s:spawn({ "wezterm", "cli", "spawn" })
    assert.is_nil(s.wezterm_pane_id)
    assert.is_false(s.started)
  end)
end)

-- ── init ─────────────────────────────────────────────────────────────────────

describe("WezTerm session:init", function()
  local original_create

  before_each(function()
    original_create = Config.cli.mux.create
  end)

  after_each(function()
    Config.cli.mux.create = original_create
    vim.env.WEZTERM_PANE = nil
  end)

  it("external=true for discovered (started) sessions", function()
    local s = make_session({ started = true })
    s:init()
    assert.is_true(s.external)
    assert.are.same(10, s.priority)
  end)

  it("external=true when in WezTerm and create=window", function()
    vim.env.WEZTERM_PANE = "5"
    Config.cli.mux.create = "window"
    local s = make_session({ started = false })
    s:init()
    assert.is_true(s.external)
  end)

  it("external=true when in WezTerm and create=split", function()
    vim.env.WEZTERM_PANE = "5"
    Config.cli.mux.create = "split"
    local s = make_session({ started = false })
    s:init()
    assert.is_true(s.external)
  end)

  it("external=true when in WezTerm and create=tab", function()
    vim.env.WEZTERM_PANE = "5"
    Config.cli.mux.create = "tab"
    local s = make_session({ started = false })
    s:init()
    assert.is_true(s.external)
  end)

  it("external=false when create=terminal", function()
    vim.env.WEZTERM_PANE = "5"
    Config.cli.mux.create = "terminal"
    local s = make_session({ started = false })
    s:init()
    assert.is_false(s.external)
    assert.are.same(50, s.priority)
  end)

  it("external=false when not in WezTerm", function()
    vim.env.WEZTERM_PANE = nil
    Config.cli.mux.create = "window"
    local s = make_session({ started = false })
    s:init()
    assert.is_false(s.external)
  end)

  it("sets mux_session=sid for non-external sessions", function()
    vim.env.WEZTERM_PANE = nil
    Config.cli.mux.create = "terminal"
    local s = make_session({ started = false })
    s:init()
    assert.are.same(s.sid, s.mux_session)
  end)
end)

-- ── is_running ───────────────────────────────────────────────────────────────

describe("WezTerm session:is_running", function()
  it("returns true when wezterm_pid process exists", function()
    local s = make_session({ wezterm_pid = vim.fn.getpid() }) -- current nvim pid
    assert.is_true(s:is_running())
  end)

  it("returns false when wezterm_pid process does not exist", function()
    local s = make_session({ wezterm_pid = 9999999 })
    assert.is_false(s:is_running())
  end)

  it("returns true when no wezterm_pid but wezterm_pane_id is set (just spawned)", function()
    local s = make_session({ wezterm_pane_id = 7 })
    assert.is_true(s:is_running())
  end)

  it("returns false when neither wezterm_pid nor wezterm_pane_id is set", function()
    local s = make_session()
    assert.is_false(s:is_running())
  end)
end)

-- ── current_workspace ────────────────────────────────────────────────────────

describe("WezTerm.current_workspace", function()
  local original_exec
  local original_pane

  before_each(function()
    original_exec = Util.exec
    original_pane = vim.env.WEZTERM_PANE
  end)

  after_each(function()
    Util.exec = original_exec
    vim.env.WEZTERM_PANE = original_pane
  end)

  it("returns the workspace name for the current pane", function()
    vim.env.WEZTERM_PANE = "5"
    Util.exec = function(_, _)
      local json = vim.json.encode({
        { pane_id = 5, workspace = "mywork" },
        { pane_id = 6, workspace = "other" },
      })
      return {}, json
    end
    assert.are.same("mywork", WezTerm.current_workspace())
  end)

  it("returns nil when WEZTERM_PANE is not set", function()
    vim.env.WEZTERM_PANE = nil
    assert.is_nil(WezTerm.current_workspace())
  end)

  it("returns nil when the pane is not found in the list", function()
    vim.env.WEZTERM_PANE = "99"
    Util.exec = function(_, _)
      return {}, vim.json.encode({ { pane_id = 5, workspace = "mywork" } })
    end
    assert.is_nil(WezTerm.current_workspace())
  end)

  it("returns nil when exec fails", function()
    vim.env.WEZTERM_PANE = "5"
    Util.exec = function(_, _)
      return nil
    end
    assert.is_nil(WezTerm.current_workspace())
  end)
end)

-- ── start (tab) ──────────────────────────────────────────────────────────────

describe("WezTerm session:start (tab)", function()
  local original_exec
  local original_create
  local original_pane
  local spawned_cmd

  before_each(function()
    original_exec = Util.exec
    original_create = Config.cli.mux.create
    original_pane = vim.env.WEZTERM_PANE
    Config.cli.mux.create = "tab"
    vim.env.WEZTERM_PANE = "3"
    spawned_cmd = nil
    Util.exec = function(cmd, _)
      spawned_cmd = vim.deepcopy(cmd)
      return { "7" }, "7\n"
    end
  end)

  after_each(function()
    Util.exec = original_exec
    Config.cli.mux.create = original_create
    vim.env.WEZTERM_PANE = original_pane
  end)

  it("spawns without --new-window", function()
    local s = make_session({ external = true })
    s:start()
    assert.is_not_nil(spawned_cmd)
    for _, v in ipairs(spawned_cmd) do
      assert.is_not.equal("--new-window", v)
    end
  end)

  it("includes --pane-id with the WEZTERM_PANE value", function()
    local s = make_session({ external = true })
    s:start()
    local found = false
    for i, v in ipairs(spawned_cmd) do
      if v == "--pane-id" and spawned_cmd[i + 1] == "3" then
        found = true
      end
    end
    assert.is_true(found)
  end)

  it("omits --pane-id when WEZTERM_PANE is not set", function()
    vim.env.WEZTERM_PANE = nil
    local s = make_session({ external = true })
    s:start()
    for _, v in ipairs(spawned_cmd) do
      assert.is_not.equal("--pane-id", v)
    end
  end)

  it("returns nil (does not request a terminal cmd)", function()
    local s = make_session({ external = true })
    local result = s:start()
    assert.is_nil(result)
  end)
end)
