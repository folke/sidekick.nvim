-- CSI-u key forwarding.
-- Neovim collapses modified special keys (e.g. `<S-CR>`) when forwarding to a
-- terminal job; these keymaps send the raw CSI-u bytes straight to the job.
-- Enable with `opts.cli.win.csiu = true` (the tmux options are applied automatically).

local M = {}

-- CSI-u modifier bitmask (encoded number = 1 + bitmask)
local mod = { shift = 1, alt = 2, ctrl = 4 }

local function key(lhs, code, m)
  local bytes = ("\27[%d;%du"):format(code, 1 + (m or 0))
  return {
    lhs,
    function(self)
      if self:is_running() then
        vim.api.nvim_chan_send(self.job, bytes)
      end
    end,
    mode = "t",
  }
end

--- Default CSI-u keymaps, merged into `opts.cli.win.keys` when `cli.win.csiu` is on.
---@return table<string, sidekick.cli.Keymap>
function M.defaults()
  return {
    shift_cr = key("<S-CR>", 13, mod.shift),
    alt_cr = key("<A-CR>", 13, mod.alt),
    ctrl_cr = key("<C-CR>", 13, mod.ctrl),
    ctrl_shift_cr = key("<C-S-CR>", 13, mod.ctrl + mod.shift),
    alt_shift_cr = key("<A-S-CR>", 13, mod.alt + mod.shift),
    ctrl_alt_cr = key("<C-A-CR>", 13, mod.ctrl + mod.alt),
    ctrl_space = key("<C-Space>", 32, mod.ctrl),
  }
end

return M
