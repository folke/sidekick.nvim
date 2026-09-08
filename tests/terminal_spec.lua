---@module 'luassert'

local Config = require("sidekick.config")
local Terminal = require("sidekick.cli.terminal")

describe("terminal", function()
  local orig_number, orig_signcolumn, orig_watch, orig_width
  local tmp_files, tmp_bufs

  local function open()
    require("sidekick.cli").show({ name = "test" })
    -- cli.show is deferred to the next tick
    vim.wait(1000, function()
      local t = vim.tbl_values(Terminal.terminals)[1] ---@type sidekick.cli.Terminal?
      return t ~= nil and t:is_open() or false
    end)
    local terminal = vim.tbl_values(Terminal.terminals)[1] ---@type sidekick.cli.Terminal?
    assert.is_not_nil(terminal)
    assert.is_truthy(terminal:is_open())
    assert.is_truthy(terminal:is_running())
    return terminal
  end

  ---@param win integer
  local function takeover(win)
    local file = vim.fn.tempname() .. ".txt"
    vim.fn.writefile({ "test" }, file)
    vim.api.nvim_win_call(win, function()
      vim.cmd.edit(file)
    end)
    table.insert(tmp_files, file)
    table.insert(tmp_bufs, vim.api.nvim_win_get_buf(win))
  end

  before_each(function()
    orig_number, orig_signcolumn = vim.o.number, vim.o.signcolumn
    orig_watch, orig_width = Config.cli.watch, Config.cli.win.split.width
    tmp_files, tmp_bufs = {}, {}
    vim.o.number = true
    vim.o.signcolumn = "yes"
    Config.cli.watch = false
    Config.cli.tools.test = { cmd = { "cat" } }
  end)

  after_each(function()
    for _, terminal in pairs(vim.tbl_extend("force", {}, Terminal.terminals)) do
      terminal:close()
    end
    vim.wait(100) -- drain deferred cli callbacks before removing the tool
    for _, buf in ipairs(tmp_bufs) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    for _, file in ipairs(tmp_files) do
      vim.fn.delete(file)
    end
    Config.cli.tools.test = nil
    Config.cli.watch = orig_watch
    Config.cli.win.split.width = orig_width
    vim.o.number = orig_number
    vim.o.signcolumn = orig_signcolumn
  end)

  it("applies window options to the terminal window", function()
    local terminal = open()
    local expected = {
      number = false,
      relativenumber = false,
      signcolumn = "no",
      statuscolumn = "",
      winbar = "",
      foldcolumn = "0",
      winfixwidth = true,
    }
    for option, value in pairs(expected) do
      assert.are.same(value, vim.api.nvim_get_option_value(option, { win = terminal.win }), option)
    end
    assert.is_not_nil(vim.w[terminal.win].sidekick_cli)
    assert.are.same(terminal.id, vim.w[terminal.win].sidekick_session_id)
  end)

  it("does not pin the window size for auto-sized splits", function()
    Config.cli.win.split.width = 0
    local terminal = open()
    assert.are.same(false, vim.api.nvim_get_option_value("winfixwidth", { win = terminal.win }))
    assert.are.same(false, vim.api.nvim_get_option_value("winfixheight", { win = terminal.win }))
  end)

  it("releases the window when another buffer replaces the terminal", function()
    local terminal = open()
    local win = terminal.win
    takeover(win)

    -- Neovim restores the user's window options for the new buffer
    assert.are.same(true, vim.api.nvim_get_option_value("number", { win = win }))
    assert.are.same("yes", vim.api.nvim_get_option_value("signcolumn", { win = win }))
    -- sidekick undoes what sticks to the window and lets go of it
    assert.are.same(false, vim.api.nvim_get_option_value("winfixwidth", { win = win }))
    assert.is_nil(vim.w[win].sidekick_cli)
    assert.is_nil(vim.w[win].sidekick_session_id)
    assert.is_falsy(terminal:is_open())
    -- the session keeps running in the background
    assert.is_truthy(terminal:is_running())
  end)

  it("does not re-apply options to a released window", function()
    local terminal = open()
    local win = terminal.win

    -- keep the window held to exercise the fix_cursorline guard directly
    vim.opt.eventignore = "BufWinEnter"
    takeover(win)
    vim.opt.eventignore = ""

    terminal:fix_cursorline()
    assert.are.same(true, vim.api.nvim_get_option_value("number", { win = win }))

    terminal:release_win()
    assert.are.same(false, vim.api.nvim_get_option_value("winfixwidth", { win = win }))
    assert.is_falsy(terminal:is_open())
  end)

  it("reopens a styled window after the previous one was taken over", function()
    local terminal = open()
    local old_win = terminal.win
    takeover(old_win)
    assert.is_falsy(terminal:is_open())

    terminal:show()
    assert.is_truthy(terminal:is_open())
    assert.are_not.equal(old_win, terminal.win)
    assert.are.same(false, vim.api.nvim_get_option_value("number", { win = terminal.win }))
    assert.are.same(true, vim.api.nvim_get_option_value("winfixwidth", { win = terminal.win }))
  end)
end)
