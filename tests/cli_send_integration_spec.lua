---@module 'luassert'

local Cli = require("sidekick.cli")
local Config = require("sidekick.config")

describe("cli.send integration", function()
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

  describe("submit timing", function()
    local events
    local mock_state

    before_each(function()
      events = {}
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
          send_queue = {},
          send = function(self, msg)
            table.insert(events, { type = "send", msg = msg, time = vim.uv.hrtime() })
            table.insert(self.send_queue, msg)
            -- Simulate async processing
            vim.defer_fn(function()
              table.remove(self.send_queue, 1)
            end, 50)
          end,
          submit = function()
            table.insert(events, { type = "submit", time = vim.uv.hrtime() })
          end,
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

    it("submits after queue is empty", function()
      Cli.send({ msg = "test message", submit = true })

      -- Wait for polling to complete
      vim.wait(500, function()
        return #vim.tbl_filter(function(e)
          return e.type == "submit"
        end, events) > 0
      end)

      local send_event = vim.tbl_filter(function(e)
        return e.type == "send"
      end, events)[1]
      local submit_event = vim.tbl_filter(function(e)
        return e.type == "submit"
      end, events)[1]

      assert.is_not_nil(send_event, "send event should exist")
      assert.is_not_nil(submit_event, "submit event should exist")
      assert.is_true(submit_event.time > send_event.time, "submit should happen after send")
    end)

    it("waits for multiple queued messages", function()
      mock_state.session.send = function(self, msg)
        table.insert(events, { type = "send", msg = msg, time = vim.uv.hrtime() })
        table.insert(self.send_queue, msg)
        -- Simulate slower processing
        vim.defer_fn(function()
          if #self.send_queue > 0 then
            table.remove(self.send_queue, 1)
          end
        end, 150)
      end

      -- Add multiple messages to queue
      table.insert(mock_state.session.send_queue, "queued1")
      table.insert(mock_state.session.send_queue, "queued2")

      Cli.send({ msg = "test message", submit = true })

      vim.wait(1000, function()
        return #vim.tbl_filter(function(e)
          return e.type == "submit"
        end, events) > 0
      end)

      local submit_event = vim.tbl_filter(function(e)
        return e.type == "submit"
      end, events)[1]

      assert.is_not_nil(submit_event, "submit should eventually happen")
    end)

    it("does not submit when submit=false", function()
      Cli.send({ msg = "test message", submit = false })

      vim.wait(300)

      local submit_events = vim.tbl_filter(function(e)
        return e.type == "submit"
      end, events)

      assert.are.equal(0, #submit_events, "submit should not be called")
    end)

    it("handles empty queue immediately", function()
      mock_state.session.send_queue = {}

      Cli.send({ msg = "test message", submit = true })

      vim.wait(300, function()
        return #vim.tbl_filter(function(e)
          return e.type == "submit"
        end, events) > 0
      end)

      local submit_event = vim.tbl_filter(function(e)
        return e.type == "submit"
      end, events)[1]

      assert.is_not_nil(submit_event, "submit should happen quickly with empty queue")
    end)

    it("times out after 5 seconds with stuck queue", function()
      local warnings = {}
      local Util = require("sidekick.util")
      local original_warn = Util.warn
      Util.warn = function(msg)
        table.insert(warnings, msg)
      end

      -- Queue that never empties
      mock_state.session.send = function(self, msg)
        table.insert(events, { type = "send", msg = msg, time = vim.uv.hrtime() })
        table.insert(self.send_queue, msg)
        -- Never remove from queue
      end

      Cli.send({ msg = "test message", submit = true })

      -- Wait for timeout (5 seconds + buffer)
      vim.wait(5500, function()
        return #warnings > 0
      end)

      Util.warn = original_warn

      assert.are.equal(1, #warnings)
      assert.is_true(warnings[1]:match("timeout") ~= nil)

      -- Submit should not have been called
      local submit_events = vim.tbl_filter(function(e)
        return e.type == "submit"
      end, events)
      assert.are.equal(0, #submit_events)
    end)
  end)

  describe("terminal submit behavior", function()
    it("sends carriage return directly to channel", function()
      local Terminal = require("sidekick.cli.terminal")
      local sent_data = {}

      -- Mock nvim_chan_send
      local original_chan_send = vim.api.nvim_chan_send
      vim.api.nvim_chan_send = function(chan, data)
        table.insert(sent_data, { chan = chan, data = data })
      end

      -- Create a minimal terminal instance
      local term = setmetatable({
        job = 123,
        send_queue = {},
        is_running = function()
          return true
        end,
      }, { __index = Terminal })

      term:submit()

      vim.api.nvim_chan_send = original_chan_send

      assert.are.equal(1, #sent_data)
      assert.are.equal(123, sent_data[1].chan)
      assert.are.equal("\r", sent_data[1].data)
    end)
  end)
end)
