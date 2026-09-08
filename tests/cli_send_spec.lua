---@module 'luassert'

local Cli = require("sidekick.cli")
local Config = require("sidekick.config")

describe("cli.send with prompt option", function()
  local buf, win

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test line" })
    vim.bo[buf].filetype = "lua"
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.w[win].sidekick_visit = vim.uv.hrtime()
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  describe("prompt resolution", function()
    it("resolves string prompt by name", function()
      Config.cli.prompts.test_simple = "Simple test prompt"
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      local rendered = Cli.render({ prompt = "test_simple" })
      assert.is_not_nil(rendered)
      Config.cli.prompts.test_simple = nil
    end)

    it("resolves function prompt by name", function()
      Config.cli.prompts.test_fn = function()
        return "Function result"
      end
      local rendered = Cli.render({ prompt = "test_fn" })
      assert.is_not_nil(rendered)
      Config.cli.prompts.test_fn = nil
    end)

    it("returns nil for non-existent prompt", function()
      local rendered = Cli.render({ prompt = "nonexistent" })
      assert.is_nil(rendered)
    end)
  end)

  describe("send with prompt option", function()
    local sent_messages
    local mock_state

    before_each(function()
      sent_messages = {}
      mock_state = {
        tool = {
          format = function(_, text)
            return table.concat(
              vim.tbl_map(function(t)
                return type(t) == "table" and t[1] or t
              end, text or {}),
              ""
            )
          end,
        },
        session = {
          send = function(_, msg)
            table.insert(sent_messages, msg)
          end,
          submit = function() end,
        },
      }

      local State = require("sidekick.cli.state")
      _G._original_state_with = State.with
      State.with = function(fn, _)
        fn(mock_state)
      end
    end)

    after_each(function()
      if _G._original_state_with then
        require("sidekick.cli.state").with = _G._original_state_with
        _G._original_state_with = nil
      end
    end)

    it("sends prompt content when prompt option is provided", function()
      Cli.send({ prompt = "explain" })
      vim.wait(100)
      assert.is_true(#sent_messages > 0)
      assert.is_true(sent_messages[1]:match("Explain") ~= nil)
    end)

    it("prefers msg over prompt when both provided", function()
      Cli.send({ msg = "Direct message", prompt = "explain" })
      vim.wait(100)
      assert.is_true(#sent_messages > 0)
      assert.are.equal("Direct message\n", sent_messages[1])
    end)

    it("handles function-based prompts", function()
      Config.cli.prompts.test_fn = function()
        return "Function result"
      end
      Cli.send({ prompt = "test_fn" })
      vim.wait(100)
      assert.is_true(#sent_messages > 0)
      assert.is_true(sent_messages[1]:match("Function result") ~= nil)
      Config.cli.prompts.test_fn = nil
    end)

    it("warns on non-existent prompt", function()
      local warned = false
      local Util = require("sidekick.util")
      local original_warn = Util.warn
      Util.warn = function()
        warned = true
      end

      Cli.send({ prompt = "nonexistent" })
      vim.wait(100)

      Util.warn = original_warn
      assert.is_true(warned)
      assert.are.equal(0, #sent_messages)
    end)
  end)
end)
