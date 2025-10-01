---@module 'luassert'

local Cli = require("sidekick.cli")
local Config = require("sidekick.config")
local Terminal = require("sidekick.cli.terminal")
local Util = require("sidekick.util")

describe("cli default tool", function()
  local orig_default
  local orig_terminals
  local orig_new
  local orig_select
  local orig_schedule_wrap
  local orig_executable
  local orig_error

  local created
  local select_calls
  local errors

  before_each(function()
    orig_default = Config.cli.default
    orig_terminals = Terminal.terminals
    orig_new = Terminal.new
    orig_select = Cli.select_tool
    orig_schedule_wrap = vim.schedule_wrap
    orig_executable = vim.fn.executable
    orig_error = Util.error

    created = nil
    select_calls = 0
    errors = {}

    Config.cli.default = nil
    Terminal.terminals = {}
    vim.schedule_wrap = function(fn)
      return fn
    end
    Util.error = function(msg)
      errors[#errors + 1] = msg
    end
    Cli.select_tool = function(...)
      select_calls = select_calls + 1
    end
    Terminal.new = function(tool)
      created = tool
      local term = {
        tool = tool,
        session = { id = "sidekick " .. tool.name },
        atime = 0,
      }
      function term:show() end
      function term:focus() end
      function term:toggle() end
      function term:is_open()
        return true
      end
      function term:is_focused()
        return false
      end
      function term:blur() end
      function term:hide() end
      function term:close() end
      Terminal.terminals[term.session.id] = term
      return term
    end
  end)

  after_each(function()
    Config.cli.default = orig_default
    Terminal.terminals = orig_terminals
    Terminal.new = orig_new
    Cli.select_tool = orig_select
    vim.schedule_wrap = orig_schedule_wrap
    vim.fn.executable = orig_executable
    Util.error = orig_error
  end)

  it("creates the configured default when available", function()
    Config.cli.default = "codex"
    vim.fn.executable = function(cmd)
      return cmd == "codex" and 1 or 0
    end

    local called = false
    Cli.with(function()
      called = true
    end, { create = true })

    assert.is_true(called)
    assert.is_not_nil(created)
    assert.are.same("codex", created.name)
    assert.are.same(0, select_calls)
    assert.are.same({}, errors)
  end)

  it("falls back to selection when default is unavailable", function()
    Config.cli.default = "codex"
    vim.fn.executable = function()
      return 0
    end

    Cli.with(function() end, { create = true })

    assert.is_nil(created)
    assert.are.same(1, select_calls)
    assert.are.same({ "`codex` is not installed" }, errors)
  end)
end)
