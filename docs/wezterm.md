# WezTerm Support

sidekick.nvim supports WezTerm as a terminal multiplexer backend.

## Requirements

- WezTerm must be installed and `wezterm` executable in PATH
- Must run Neovim from within WezTerm (not external mode)
- WezTerm CLI must be functional

## Configuration

To use WezTerm as the multiplexer backend:

```lua
require('sidekick').setup({
  cli = {
    mux = {
      enabled = true,
      backend = 'wezterm',
      create = 'split',  -- WezTerm only supports 'split' mode
      split = {
        vertical = true,  -- true for side-by-side, false for top-bottom
        size = 0.5,       -- 0-1 for percentage, >1 for cell count
      },
    }
  }
})
```

**Note:** WezTerm only supports `create = "split"` mode. If you specify `"terminal"` or `"window"`, it will fall back to `"split"` with a warning.

## Features

- ✅ Split pane creation
- ✅ Send text to panes
- ✅ Session discovery via process inspection
- ✅ Check if sessions are running
- ⚠️  Focus events: not implemented (test first if needed)
- ❌ Dump pane contents: not implemented (may add later)

## Limitations

- Only works when running Neovim inside WezTerm (not external mode)
- Cannot dump pane contents yet (WezTerm API limitation)
- Priority set to 70 to maintain backwards compatibility with existing configs

## How It Works

WezTerm support uses the WezTerm CLI to:
1. Create split panes with `wezterm cli split-pane`
2. Send text with `wezterm cli send-text`
3. Discover sessions by listing panes and inspecting processes via TTY mapping
4. Check session status by querying pane list

## Troubleshooting

**"WezTerm backend requires running inside WezTerm"**
- You must launch Neovim from within a WezTerm terminal

**"wezterm executable not found in PATH"**
- Install WezTerm or ensure it's in your PATH

**Pane not receiving input**
- Check if pane still exists with `:lua require('sidekick.cli.session').sessions()`
- Verify `wezterm cli list` shows the pane
