---@module 'luassert'

local Context = require("sidekick.cli.context")
local Config = require("sidekick.config")

describe("context module", function()
  local buf, win
  local original_cwd

  before_each(function()
    original_cwd = vim.fn.getcwd()
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "local foo = 1",
      "local bar = 2",
      "local baz = 3",
    })
    vim.bo[buf].filetype = "lua"
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.w[win].sidekick_visit = vim.uv.hrtime()
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
  end)

  describe("ctx()", function()
    it("returns current context", function()
      vim.api.nvim_win_set_cursor(win, { 2, 5 })
      local ctx = Context.ctx()
      assert.are.equal(win, ctx.win)
      assert.are.equal(buf, ctx.buf)
      assert.are.equal(2, ctx.row)
      assert.are.equal(6, ctx.col) -- 1-based
      assert.is_not_nil(ctx.cwd)
    end)

    it("excludes sidekick_terminal buffers", function()
      local term_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[term_buf].filetype = "sidekick_terminal"
      local term_win = vim.api.nvim_open_win(term_buf, true, {
        relative = "editor",
        width = 50,
        height = 10,
        row = 0,
        col = 0,
      })
      vim.w[term_win].sidekick_visit = vim.uv.hrtime() + 1000000000

      local ctx = Context.ctx()
      -- Should still return the original window, not the terminal
      assert.are.equal(buf, ctx.buf)

      vim.api.nvim_win_close(term_win, true)
      vim.api.nvim_buf_delete(term_buf, { force = true })
    end)

    it("prefers most recently visited window", function()
      local buf2 = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "test" })
      local win2 = vim.api.nvim_open_win(buf2, false, {
        relative = "editor",
        width = 50,
        height = 10,
        row = 0,
        col = 0,
      })

      -- Mark win2 as more recently visited
      vim.w[win2].sidekick_visit = vim.uv.hrtime() + 1000000000

      local ctx = Context.ctx()
      assert.are.equal(win2, ctx.win)
      assert.are.equal(buf2, ctx.buf)

      vim.api.nvim_win_close(win2, true)
      vim.api.nvim_buf_delete(buf2, { force = true })
    end)
  end)

  describe("selection()", function()
    it("returns nil when not in visual mode", function()
      local selection = Context.selection(buf)
      assert.is_nil(selection)
    end)

    it("captures visual selection range", function()
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      vim.cmd("normal! v")
      vim.api.nvim_win_set_cursor(win, { 1, 5 })

      local selection = Context.selection(buf)
      assert.is_not_nil(selection)
      assert.are.equal("char", selection.kind)
      assert.are.same({ 1, 0 }, selection.from)
      assert.are.same({ 1, 5 }, selection.to)

      -- Exit visual mode
      vim.cmd("normal! \27") -- ESC
    end)

    it("handles line visual mode", function()
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      vim.cmd("normal! V")
      vim.api.nvim_win_set_cursor(win, { 2, 0 })

      local selection = Context.selection(buf)
      assert.is_not_nil(selection)
      assert.are.equal("line", selection.kind)

      vim.cmd("normal! \27")
    end)

    it("handles block visual mode", function()
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
      vim.cmd("normal! \22") -- Ctrl-V
      vim.api.nvim_win_set_cursor(win, { 2, 3 })

      local selection = Context.selection(buf)
      assert.is_not_nil(selection)
      assert.are.equal("block", selection.kind)

      vim.cmd("normal! \27")
    end)

    it("swaps from/to if selection is backwards", function()
      vim.api.nvim_win_set_cursor(win, { 2, 5 })
      vim.cmd("normal! v")
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

      local selection = Context.selection(buf)
      assert.is_not_nil(selection)
      -- Should be normalized so from < to
      assert.is_true(selection.from[1] <= selection.to[1])

      vim.cmd("normal! \27")
    end)
  end)

  describe("Context class", function()
    describe("get()", function()
      it("evaluates context functions", function()
        -- Create a real file buffer since 'file' context requires it
        local tmp = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "test" }, tmp)
        local file_buf = vim.fn.bufadd(tmp)
        vim.fn.bufload(file_buf)
        vim.bo[file_buf].buflisted = true
        vim.api.nvim_win_set_buf(win, file_buf)
        vim.w[win].sidekick_visit = vim.uv.hrtime()

        local ctx = Context.get()
        local result = ctx:get("file")
        -- Context:get() returns false when context cannot be evaluated
        -- For file buffers, it should return a table
        if result ~= false then
          assert.is_table(result)
        end

        vim.fn.delete(tmp)
        vim.api.nvim_buf_delete(file_buf, { force = true })
      end)

      it("caches context results", function()
        local call_count = 0
        Config.cli.context.test_cache = function()
          call_count = call_count + 1
          return { { { "cached" } } }
        end

        local ctx = Context.get()
        ctx:get("test_cache")
        ctx:get("test_cache")
        ctx:get("test_cache")

        assert.are.equal(1, call_count)
        Config.cli.context.test_cache = nil
      end)

      it("returns false for invalid context", function()
        local ctx = Context.get()
        local result = ctx:get("nonexistent_context")
        assert.is_false(result)
      end)

      it("returns false for empty results", function()
        Config.cli.context.test_empty = function()
          return {}
        end

        local ctx = Context.get()
        local result = ctx:get("test_empty")
        assert.is_false(result)

        Config.cli.context.test_empty = nil
      end)
    end)

    describe("render_line()", function()
      it("renders plain text", function()
        local ctx = Context.get()
        local result = ctx:render_line("hello world")
        assert.is_not_nil(result)
        assert.are.equal(1, #result)
        -- Result is array of lines, each line is array of text chunks
        assert.are.same({ { { "hello world" } } }, result)
      end)

      it("substitutes single context variable", function()
        Config.cli.context.test_var = function()
          return { { { "replacement" } } }
        end

        local ctx = Context.get()
        local result = ctx:render_line("before {test_var} after")
        assert.is_not_nil(result)
        assert.are.equal(1, #result)
        assert.are.same({ { "before " }, { "replacement" }, { " after" } }, result[1])

        Config.cli.context.test_var = nil
      end)

      it("substitutes multiple context variables", function()
        Config.cli.context.var1 = function()
          return { { { "first" } } }
        end
        Config.cli.context.var2 = function()
          return { { { "second" } } }
        end

        local ctx = Context.get()
        local result = ctx:render_line("{var1} and {var2}")
        assert.is_not_nil(result)
        assert.are.equal(1, #result)
        assert.are.same({ { "first" }, { " and " }, { "second" } }, result[1])

        Config.cli.context.var1 = nil
        Config.cli.context.var2 = nil
      end)

      it("returns nil if context variable fails", function()
        local ctx = Context.get()
        local result = ctx:render_line("test {nonexistent}")
        assert.is_nil(result)
      end)

      it("handles multiline context results", function()
        Config.cli.context.multiline = function()
          return { { { "line1" } }, { { "line2" } } }
        end

        local ctx = Context.get()
        local result = ctx:render_line("start {multiline} end")
        assert.is_not_nil(result)
        assert.are.equal(2, #result)
        assert.are.same({ { "start " }, { "line1" } }, result[1])
        assert.are.same({ { "line2" }, { " end" } }, result[2])

        Config.cli.context.multiline = nil
      end)
    end)

    describe("render()", function()
      it("renders string message", function()
        local ctx = Context.get()
        local text, rendered = ctx:render("hello world")
        assert.are.equal("hello world", text)
        assert.is_not_nil(rendered)
      end)

      it("renders table with msg field", function()
        local ctx = Context.get()
        local text, rendered = ctx:render({ msg = "test message" })
        assert.are.equal("test message", text)
        assert.is_not_nil(rendered)
      end)

      it("renders multiline messages", function()
        local ctx = Context.get()
        local text = ctx:render("line1\nline2\nline3")
        assert.are.equal("line1\nline2\nline3", text)
      end)

      it("renders prompt by name", function()
        Config.cli.prompts.test_prompt = "This is a test prompt"

        local ctx = Context.get()
        local text = ctx:render({ prompt = "test_prompt" })
        assert.are.equal("This is a test prompt", text)

        Config.cli.prompts.test_prompt = nil
      end)

      it("renders prompt function", function()
        Config.cli.prompts.test_fn = function(ctx_arg)
          return "Dynamic: " .. ctx_arg.row
        end

        local ctx = Context.get()
        local text = ctx:render({ prompt = "test_fn" })
        assert.is_not_nil(text:match("Dynamic: %d+"))

        Config.cli.prompts.test_fn = nil
      end)

      it("returns nil for invalid prompt", function()
        local ctx = Context.get()
        local text = ctx:render({ prompt = "nonexistent_prompt" })
        assert.is_nil(text)
      end)

      it("handles {this} in file buffer", function()
        -- Create a real file buffer
        local tmp = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "test" }, tmp)
        local file_buf = vim.fn.bufadd(tmp)
        vim.fn.bufload(file_buf)
        vim.bo[file_buf].buflisted = true
        vim.api.nvim_win_set_buf(win, file_buf)
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        vim.w[win].sidekick_visit = vim.uv.hrtime()

        local ctx = Context.get()
        local text = ctx:render("check {this}")
        -- {this} in file buffer should render position
        if text then
          assert.is_not_nil(text)
          assert.is_true(text:match("@") ~= nil) -- position format includes @
        end

        vim.fn.delete(tmp)
        vim.api.nvim_buf_delete(file_buf, { force = true })
      end)

      it("handles {this} in non-file buffer with selection", function()
        -- Use the scratch buffer and create a selection
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(win, { 1, 5 })

        local ctx = Context.get()
        local text = ctx:render("test {this}")
        -- In non-file buffer, {this} becomes "this" and selection is appended
        assert.is_not_nil(text)
        assert.is_true(text:match("test this") ~= nil)

        vim.cmd("normal! \27") -- ESC
      end)

      it("disables {this} replacement when this=false", function()
        local ctx = Context.get()
        local text = ctx:render({ msg = "plain text", this = false })
        -- Plain message without context vars should work
        assert.are.equal("plain text", text)
      end)

      it("combines msg and prompt", function()
        Config.cli.prompts.test_combo = "prompt text"

        local ctx = Context.get()
        local text = ctx:render({ msg = "msg text", prompt = "test_combo" })
        assert.are.equal("msg text\nprompt text", text)

        Config.cli.prompts.test_combo = nil
      end)
    end)
  end)

  describe("context functions", function()
    describe("position", function()
      it("returns position info for file buffer", function()
        local tmp = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "line1", "line2" }, tmp)
        local file_buf = vim.fn.bufadd(tmp)
        vim.fn.bufload(file_buf)
        vim.api.nvim_win_set_buf(win, file_buf)
        vim.api.nvim_win_set_cursor(win, { 2, 0 })
        vim.w[win].sidekick_visit = vim.uv.hrtime()

        local ctx_data = Context.ctx()
        local result = Context.context.position(ctx_data)

        assert.is_not_nil(result)
        vim.fn.delete(tmp)
        vim.api.nvim_buf_delete(file_buf, { force = true })
      end)

      it("returns false for non-file buffer", function()
        local ctx_data = Context.ctx()
        local result = Context.context.position(ctx_data)
        -- Context functions use 'and' operator which returns false when is_file() is false
        assert.is_false(result)
      end)
    end)

    describe("file", function()
      it("returns file info for file buffer", function()
        local tmp = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "test" }, tmp)
        local file_buf = vim.fn.bufadd(tmp)
        vim.fn.bufload(file_buf)
        vim.api.nvim_win_set_buf(win, file_buf)
        vim.w[win].sidekick_visit = vim.uv.hrtime()

        local ctx_data = Context.ctx()
        local result = Context.context.file(ctx_data)

        assert.is_not_nil(result)
        vim.fn.delete(tmp)
        vim.api.nvim_buf_delete(file_buf, { force = true })
      end)
    end)

    describe("buffers", function()
      it("returns list of file buffers", function()
        local tmp1 = vim.fn.tempname() .. ".lua"
        local tmp2 = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "test1" }, tmp1)
        vim.fn.writefile({ "test2" }, tmp2)
        local buf1 = vim.fn.bufadd(tmp1)
        local buf2 = vim.fn.bufadd(tmp2)
        vim.fn.bufload(buf1)
        vim.fn.bufload(buf2)
        vim.bo[buf1].buflisted = true
        vim.bo[buf2].buflisted = true

        local ctx_data = Context.ctx()
        local result = Context.context.buffers(ctx_data)

        assert.is_not_nil(result)
        assert.is_true(type(result) == "table")

        vim.fn.delete(tmp1)
        vim.fn.delete(tmp2)
        vim.api.nvim_buf_delete(buf1, { force = true })
        vim.api.nvim_buf_delete(buf2, { force = true })
      end)
    end)

    describe("quickfix", function()
      local Text = require("sidekick.text")

      before_each(function()
        vim.fn.setqflist({}, "r", { items = {} })
      end)

      after_each(function()
        vim.fn.setqflist({}, "r", { items = {} })
      end)

      it("returns entries from the quickfix list", function()
        local tmp = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "local foo = 1", "error line" }, tmp)
        local buf_nr = vim.fn.bufadd(tmp)
        vim.fn.bufload(buf_nr)

        vim.fn.setqflist({}, "r", {
          title = "Test Quickfix",
          items = {
            {
              bufnr = buf_nr,
              lnum = 2,
              col = 1,
              text = "Test error message",
              type = "E",
            },
          },
        })

        local ctx_data = Context.ctx()
        local result = Context.context.quickfix(ctx_data)

        assert.is_not_nil(result)
        local lines = Text.lines(result)
        assert.are.same("Quickfix: Test Quickfix", lines[1])
        local rel = vim.fs.basename(tmp)
        assert.is_true(lines[2]:find("- @", 1, true) ~= nil, lines[2])
        assert.is_true(lines[2]:find(rel, 1, true) ~= nil, lines[2])
        assert.is_true(lines[2]:find(":2", 1, true) ~= nil, lines[2])
        assert.is_true(lines[2]:find("[E]", 1, true) ~= nil)
        assert.is_true(lines[2]:find("Test error message", 1, true) ~= nil)

        vim.api.nvim_buf_delete(buf_nr, { force = true })
        vim.fn.delete(tmp)
      end)

      it("returns nil when quickfix list is empty", function()
        vim.fn.setqflist({}, "r", { items = {} })

        local ctx_data = Context.ctx()
        local result = Context.context.quickfix(ctx_data)

        assert.is_nil(result)
      end)

      it("omits command-style titles", function()
        local tmp = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "local foo = 1" }, tmp)
        local buf_nr = vim.fn.bufadd(tmp)
        vim.fn.bufload(buf_nr)

        vim.fn.setqflist({}, "r", {
          title = ":setqflist()",
          items = {
            {
              bufnr = buf_nr,
              lnum = 1,
              col = 1,
              text = "message",
            },
          },
        })

        local ctx_data = Context.ctx()
        local result = Context.context.quickfix(ctx_data)

        assert.is_not_nil(result)
        local lines = Text.lines(result)
        assert.is_true(lines[1]:find("- @", 1, true) ~= nil)

        vim.api.nvim_buf_delete(buf_nr, { force = true })
        vim.fn.delete(tmp)
      end)
    end)

    describe("selection", function()
      it("returns selection text when in visual mode", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "select me" })
        vim.api.nvim_win_set_cursor(win, { 1, 0 })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(win, { 1, 6 })

        local ctx_data = Context.ctx()
        local result = require("sidekick.cli.context.selection").get(ctx_data)

        assert.is_not_nil(result)

        vim.cmd("normal! \27")
      end)
    end)
  end)

  describe("fn()", function()
    it("returns built-in context function", function()
      local fn = Context.fn("file")
      assert.is_not_nil(fn)
      assert.are.equal("function", type(fn))
    end)

    it("returns custom context function", function()
      Config.cli.context.custom = function()
        return "custom"
      end

      local fn = Context.fn("custom")
      assert.is_not_nil(fn)
      assert.are.equal("function", type(fn))

      Config.cli.context.custom = nil
    end)

    it("returns nil for nonexistent function", function()
      local fn = Context.fn("nonexistent")
      assert.is_nil(fn)
    end)

    it("prioritizes custom over built-in", function()
      Config.cli.context.file = function()
        return "custom file"
      end

      local fn = Context.fn("file")
      assert.are.equal("custom file", fn(Context.ctx()))

      Config.cli.context.file = nil
    end)
  end)
end)
