---@module 'luassert'

local Config = require("sidekick.config")
local csiu = require("sidekick.cli.csiu")

describe("csiu.defaults", function()
  local sent, orig_chan_send

  before_each(function()
    sent = {}
    orig_chan_send = vim.api.nvim_chan_send
    vim.api.nvim_chan_send = function(_, data)
      table.insert(sent, data)
    end
  end)

  after_each(function()
    vim.api.nvim_chan_send = orig_chan_send
  end)

  -- name, lhs, expected CSI-u bytes (number = 1 + modifier bitmask)
  local cases = {
    { "shift_cr", "<S-CR>", "\27[13;2u" },
    { "alt_cr", "<A-CR>", "\27[13;3u" },
    { "ctrl_cr", "<C-CR>", "\27[13;5u" },
    { "ctrl_shift_cr", "<C-S-CR>", "\27[13;6u" },
    { "alt_shift_cr", "<A-S-CR>", "\27[13;4u" },
    { "ctrl_alt_cr", "<C-A-CR>", "\27[13;7u" },
    { "ctrl_space", "<C-Space>", "\27[32;5u" },
  }

  for _, c in ipairs(cases) do
    it(("%s is a terminal keymap sending %q"):format(c[1], c[2]), function()
      local km = csiu.defaults()[c[1]]
      assert.is_not_nil(km)
      assert.are.equal(c[2], km[1])
      assert.are.equal("t", km.mode)
      assert.are.equal("function", type(km[2]))
      km[2]({
        is_running = function()
          return true
        end,
        job = 1,
      })
      assert.are.equal(c[3], sent[1])
    end)
  end

  it("does nothing when the job is not running", function()
    csiu.defaults().shift_cr[2]({
      is_running = function()
        return false
      end,
      job = 1,
    })
    assert.are.same({}, sent)
  end)
end)

describe("tmux.options (CSI-u auto-inject)", function()
  local tmux = require("sidekick.cli.session.tmux")
  local orig_csiu

  before_each(function()
    orig_csiu = Config.cli.win.csiu
  end)

  after_each(function()
    Config.cli.win.csiu = orig_csiu
  end)

  local function seg()
    return table.concat(tmux.options(), " ")
  end
  local function has(s, lit)
    return string.find(s, lit, 1, true) ~= nil
  end

  it("injects extended-keys options when win.csiu is on", function()
    Config.cli.win.csiu = true
    local s = seg()
    assert.is_true(has(s, "; set-option extended-keys on"))
    assert.is_true(has(s, "; set-option extended-keys-format csi-u"))
  end)

  it("injects nothing when win.csiu is off", function()
    Config.cli.win.csiu = false
    assert.are.same({}, tmux.options())
  end)
end)

describe("config setup: CSI-u keymap injection", function()
  -- Suppress the deferred side effects of Config.setup (autocmds, nes, status)
  -- so repeated setup() calls don't accumulate them across the suite.
  local orig_schedule

  before_each(function()
    orig_schedule = vim.schedule
    vim.schedule = function() end
  end)

  after_each(function()
    Config.setup({}) -- restore defaults (schedule still suppressed)
    vim.schedule = orig_schedule
  end)

  it("injects csiu keymaps into cli.win.keys when csiu is on", function()
    Config.setup({ cli = { win = { csiu = true } } })
    local keys = Config.cli.win.keys
    assert.is_not_nil(keys.shift_cr)
    assert.is_not_nil(keys.ctrl_cr)
    assert.is_not_nil(keys.ctrl_shift_cr)
    assert.is_not_nil(keys.alt_cr)
  end)

  it("does not inject when csiu is off", function()
    Config.setup({ cli = { win = { csiu = false } } })
    assert.is_nil(Config.cli.win.keys.shift_cr)
  end)

  it("user keys override and can disable individual csiu keymaps", function()
    Config.setup({ cli = { win = { csiu = true, keys = { prompt = false, ctrl_cr = false } } } })
    local keys = Config.cli.win.keys
    assert.is_false(keys.prompt) -- user override preserved
    assert.is_false(keys.ctrl_cr) -- user disabled this csiu key
    assert.is_not_nil(keys.shift_cr) -- other csiu keys still present
  end)
end)
