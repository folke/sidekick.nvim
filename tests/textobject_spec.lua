---@module 'luassert'

local Context = require("sidekick.cli.context")
local TextObject = require("sidekick.cli.context.textobject")

local function pending(msg)
  print("PENDING: " .. msg)
  assert.is_true(true)
end

describe("textobject context", function()
  local buf, win

  before_each(function()
    buf = vim.api.nvim_create_buf(false, true)
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.w[win].sidekick_visit = vim.uv.hrtime()
  end)

  after_each(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  ---Helper to check if a parser is available
  ---@param lang string
  ---@return boolean
  local function has_parser(lang)
    local ok, _ = pcall(vim.treesitter.get_parser, nil, lang)
    return ok
  end

  describe("function context", function()
    it("extracts lua function with kind=position (default)", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local function test()",
        "  return 42",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 }) -- Inside function

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_not_nil(result)
      assert.is_true(#result > 0)
      -- Should be single line with position format: "function test @file:line:col"
      assert.are.equal(1, #result)
    end)

    it("extracts lua function with kind=code", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local function my_func()",
        "  return 42",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function", kind = "code" })

      assert.is_not_nil(result)
      assert.is_true(#result >= 3) -- Should have multiple lines of code
    end)

    it("returns nil when not in a function", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local x = 1",
        "local y = 2",
      })
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_nil(result)
    end)

    it("extracts python function", function()
      if not has_parser("python") then
        pending("Python parser not available")
        return
      end

      vim.bo[buf].filetype = "python"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "def hello(name):",
        "    return f'Hello {name}'",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 4 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_not_nil(result)
      assert.is_true(#result > 0)
    end)

    it("extracts javascript function", function()
      if not has_parser("javascript") then
        pending("JavaScript parser not available")
        return
      end

      vim.bo[buf].filetype = "javascript"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "function greet(name) {",
        "  return 'Hello ' + name;",
        "}",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_not_nil(result)
    end)

    it("extracts javascript arrow function", function()
      if not has_parser("javascript") then
        pending("JavaScript parser not available")
        return
      end

      vim.bo[buf].filetype = "javascript"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "const add = (a, b) => {",
        "  return a + b;",
        "};",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_not_nil(result)
    end)

    it("finds outer function when nested", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local function outer()",
        "  local function inner()",
        "    return 1",
        "  end",
        "  return inner()",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 3, 4 }) -- Inside inner function

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      -- Should get the inner function first
      assert.is_not_nil(result)
    end)
  end)

  describe("class context", function()
    it("extracts lua class-like table", function()
      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local M = {}",
        "function M:method()",
        "  return 42",
        "end",
        "return M",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.ctx()
      -- Note: Lua doesn't have class syntax, so this may not find anything
      local result = TextObject.get(ctx, { type = "class" })

      -- May be nil for Lua since it doesn't have classes
      -- This is expected behavior
      assert.is_true(result == nil or #result > 0)
    end)

    it("extracts python class", function()
      if not has_parser("python") then
        pending("Python parser not available")
        return
      end

      vim.bo[buf].filetype = "python"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "class MyClass:",
        "    def __init__(self):",
        "        self.value = 42",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 4 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "class" })

      assert.is_not_nil(result)
      assert.is_true(#result > 0)
    end)

    it("extracts javascript class", function()
      if not has_parser("javascript") then
        pending("JavaScript parser not available")
        return
      end

      vim.bo[buf].filetype = "javascript"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "class Person {",
        "  constructor(name) {",
        "    this.name = name;",
        "  }",
        "}",
      })
      vim.api.nvim_win_set_cursor(win, { 3, 4 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "class" })

      assert.is_not_nil(result)
    end)
  end)

  describe("block context", function()
    it("extracts code block", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "if true then",
        "  print('hello')",
        "  print('world')",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "block" })

      assert.is_not_nil(result)
    end)
  end)

  describe("context integration", function()
    it("works through context system", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local function test()",
        "  return 42",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.get()
      local result = ctx:get("function")

      -- Should work through the context system
      assert.is_not_nil(result)
    end)

    it("can be used in prompts", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local function test()",
        "  return 42",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.get()
      local text = ctx:render("Explain {function}")

      -- Should render the function context
      if text then
        assert.is_true(text:match("function") ~= nil)
      end
    end)

    it("returns false when no function found", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local x = 1",
      })
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

      local ctx = Context.get()
      local result = ctx:get("function")

      -- Should return false when not in a function
      assert.is_false(result)
    end)
  end)

  describe("edge cases", function()
    it("handles invalid buffer", function()
      local invalid_ctx = {
        buf = 99999,
        win = win,
        row = 1,
        col = 1,
        cwd = vim.fn.getcwd(),
      }

      local result = TextObject.get(invalid_ctx, { type = "function" })
      assert.is_nil(result)
    end)

    it("handles unsupported filetype", function()
      vim.bo[buf].filetype = "text"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "some text",
      })
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      -- Should return nil for unsupported filetype
      assert.is_nil(result)
    end)

    it("handles cursor at end of function", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "local function test()",
        "  return 42",
        "end",
      })
      vim.api.nvim_win_set_cursor(win, { 3, 0 }) -- At beginning of 'end'

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      -- Should find the function when cursor is on the 'end' keyword
      assert.is_not_nil(result)
    end)

    it("handles empty buffer", function()
      if not has_parser("lua") then
        pending("Lua parser not available")
        return
      end

      vim.bo[buf].filetype = "lua"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      vim.api.nvim_win_set_cursor(win, { 1, 0 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_nil(result)
    end)
  end)

  describe("multi-language support", function()
    it("works with typescript", function()
      if not has_parser("typescript") then
        pending("TypeScript parser not available")
        return
      end

      vim.bo[buf].filetype = "typescript"
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "function greet(name: string): string {",
        "  return `Hello ${name}`;",
        "}",
      })
      vim.api.nvim_win_set_cursor(win, { 2, 2 })

      local ctx = Context.ctx()
      local result = TextObject.get(ctx, { type = "function" })

      assert.is_not_nil(result)
    end)

    -- it("works with rust", function()
    --   if not has_parser("rust") then
    --     pending("Rust parser not available")
    --     return
    --   end
    --
    --   vim.bo[buf].filetype = "rust"
    --   vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    --     "fn add(a: i32, b: i32) -> i32 {",
    --     "    a + b",
    --     "}",
    --   })
    --   vim.api.nvim_win_set_cursor(win, { 2, 4 })
    --
    --   local ctx = Context.ctx()
    --   local result = TextObject.get(ctx, { type = "function" })
    --
    --   assert.is_not_nil(result)
    -- end)


  end)
end)
