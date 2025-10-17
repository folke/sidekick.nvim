# Changelog

## [2.0.0](https://github.com/folke/sidekick.nvim/compare/v1.3.0...v2.0.0) (2025-10-17)


### ⚠ BREAKING CHANGES

* **config:** changed the default keymaps. Please check the updated documentation and example mappings

### Features

* **cli.claude:** transform line ranges to a format Claude can understand. Closes [#59](https://github.com/folke/sidekick.nvim/issues/59) ([4a492da](https://github.com/folke/sidekick.nvim/commit/4a492da6e863d06b15e887be97dd43c50b76f11d))
* **cli.select:** better distinction between attaching to terminal/external ([48d0bf6](https://github.com/folke/sidekick.nvim/commit/48d0bf66459f2fab8d917fea961bbe95c5d829c1))
* **cli:** `close()` on an external session, now detaches from that session. Closes [#98](https://github.com/folke/sidekick.nvim/issues/98) ([d2e6c64](https://github.com/folke/sidekick.nvim/commit/d2e6c6447e750a5f565ae1a832f1ca7fd8e6e8dd))
* **cli:** added `<c-q>` to hide in normal mode, so from terminal double `<c-q>` will hide ([358804c](https://github.com/folke/sidekick.nvim/commit/358804c71cd988b1ce7efc7a91e3d265df530a83))
* **cli:** added health checks and optional reqs to the docs for `lsof` and `ps`. Fixes [#89](https://github.com/folke/sidekick.nvim/issues/89) ([d403ec3](https://github.com/folke/sidekick.nvim/commit/d403ec3e695e17859e03aa0e6b4fe865140f7155))
* **cli:** added some config option validation ([c236b38](https://github.com/folke/sidekick.nvim/commit/c236b389819a3a11ada7234cd2a7a1be358b0785))
* **cli:** added terminal navigation with `<c-hjkl>`. Only mapped when not a float and a window in the dir exists. See [#51](https://github.com/folke/sidekick.nvim/issues/51) ([b48e177](https://github.com/folke/sidekick.nvim/commit/b48e177b20aeb422d3ea6838d8f2ca985ee6a21a))
* **cli:** deduplicate cli tool sessions. Closes [#92](https://github.com/folke/sidekick.nvim/issues/92) ([e5bcf17](https://github.com/folke/sidekick.nvim/commit/e5bcf171b13a99e53a8ac6b584baebf7c435584a))
* **cli:** handle special filenames for Claude, Gemini, Qwen. Fixes [#130](https://github.com/folke/sidekick.nvim/issues/130) ([19b5985](https://github.com/folke/sidekick.nvim/commit/19b59854782837430ae297ed4690660b7aa254d5))
* **config:** changed the default keymaps. Please check the updated documentation and example mappings ([6608705](https://github.com/folke/sidekick.nvim/commit/6608705fc6bd949efafbdeca879c63a5f933730c))
* **context:** you can now use context fallbacks like `{function|line}` ([076147a](https://github.com/folke/sidekick.nvim/commit/076147a6046836955712dcfc2702fc02c66684c9))
* **copilot:** allow configuring minimum level for copilot LSP messages ([4b6750b](https://github.com/folke/sidekick.nvim/commit/4b6750bb5218c0d8be2f006e41894a1655b1dd27))
* **opencode:** add pid to external opencode sessions ([3d9d519](https://github.com/folke/sidekick.nvim/commit/3d9d519c90a2a071f56067a750840e6113359480))
* **terminal:** much better scrollback buffer. no flickering and should work in all modes ([3aa2fe5](https://github.com/folke/sidekick.nvim/commit/3aa2fe5d54f084cbfae591623f50cb8833a17f76))
* **terminal:** restore normal/terminal mode when entering the sidekick window ([50c40d5](https://github.com/folke/sidekick.nvim/commit/50c40d52bf9e9f6aad0c0071fd44cc283ababf92))
* **terminal:** switch to scrollback when doing mouse scroll ([0dd3c3b](https://github.com/folke/sidekick.nvim/commit/0dd3c3bc4547b840f00fb2857e501d1efb254bf5))
* **tmux:** entering normal mode in a tmux terminal, now loads the whole tmux scrollback ([a453f76](https://github.com/folke/sidekick.nvim/commit/a453f76615bb49a1fbd25151a2229708a5187939))
* **tmux:** some tools won't process input if they don't have focus, so tools can now set `mux_focus = true` ([41dec4d](https://github.com/folke/sidekick.nvim/commit/41dec4dcdf0c8fe17f5f2e9eeced4645a88afb0d))
* **tool:** tools can now further format text before it's sent. See [#130](https://github.com/folke/sidekick.nvim/issues/130), see [#59](https://github.com/folke/sidekick.nvim/issues/59) ([28f8a07](https://github.com/folke/sidekick.nvim/commit/28f8a07a236dd0dea60942b3996465ddd29b770d))
* **util:** weak ref util method ([8036aea](https://github.com/folke/sidekick.nvim/commit/8036aeac392666e1b39d6c664f1741e813f74d49))


### Bug Fixes

* **cli.prompt:** proper way of rendering templates with highlights ([30b7b9e](https://github.com/folke/sidekick.nvim/commit/30b7b9ef72a1d78fbabf5484f4dc33adc3abb7d1))
* **cli.select:** sort terminal sessions before external sessions ([c487d53](https://github.com/folke/sidekick.nvim/commit/c487d532ed9245ddaaba0ef233e1a36565a38c78))
* **cli.state:** allow creating new sessions for tools that have only external sessions ([c588efb](https://github.com/folke/sidekick.nvim/commit/c588efbba7651446aaf767c1c7455804b30ad0e8))
* **cli:** allow sending a newlline `msg="\n"` ([fc0067a](https://github.com/folke/sidekick.nvim/commit/fc0067a2ee8c40188744e67c55d8e6c0b92fc8a4))
* **cli:** don't send empty messages ([63f626c](https://github.com/folke/sidekick.nvim/commit/63f626cd4490d61852009ea306dfb12845a412c3))
* **location:** different format that should work for most cli tools. Closes [#59](https://github.com/folke/sidekick.nvim/issues/59) ([d570e1f](https://github.com/folke/sidekick.nvim/commit/d570e1f83bf2a19e6c1fad5de9b1b07beb54b67d))
* **nes:** added triggerKind. Maybe that's needed for nes? ([e535808](https://github.com/folke/sidekick.nvim/commit/e5358082b1c58608d3ed1260f7c4f9841b632ae6))
* **nes:** better didFocus tracking ([3669eae](https://github.com/folke/sidekick.nvim/commit/3669eae4354f9fdd479ff285877f610bb95dfdd5))
* **nes:** don't clear NES on `TextChanged` or `BufWritePre`. Closes [#91](https://github.com/folke/sidekick.nvim/issues/91) ([32fa55c](https://github.com/folke/sidekick.nvim/commit/32fa55c1ad2d391b577f3c667364284937b5cb0c))
* **nes:** don't process unloaded buffers. Closes [#86](https://github.com/folke/sidekick.nvim/issues/86) ([620adf0](https://github.com/folke/sidekick.nvim/commit/620adf034a21e08ac569523cc478caf375eaa24c))
* **nes:** exec nes commands AFTER edits have been applied ([80d1604](https://github.com/folke/sidekick.nvim/commit/80d1604f7081cb6f72f6985af133dced8db5c5a8))
* **nes:** skip old edits early ([8395007](https://github.com/folke/sidekick.nvim/commit/839500723b578984ed6e4975b3302c8267784e81))
* **nes:** textDocument/didFocus ([b7085d7](https://github.com/folke/sidekick.nvim/commit/b7085d79df9efb9f8be5ca4a65d771b163d7d34c))
* **nes:** trigger on `ModeChanged *:n` instead of `InsertLeave`. See [#125](https://github.com/folke/sidekick.nvim/issues/125) ([abbd051](https://github.com/folke/sidekick.nvim/commit/abbd05132d88e2966016e40d2184bcc930ccbc48))
* **opencode:** check that open server is actually from an opencode process. Closes [#87](https://github.com/folke/sidekick.nvim/issues/87) ([cb8485a](https://github.com/folke/sidekick.nvim/commit/cb8485afa3be2221f06c66abcebff053572c2644))
* **procs:** handle case where `USER` is not set. Closes [#82](https://github.com/folke/sidekick.nvim/issues/82) ([01f89b7](https://github.com/folke/sidekick.nvim/commit/01f89b748349982906c65de3685a9fb7444c8748))
* **q:** filer procs on qchat instead of `q`, which seems to be the actual binary. Closes [#80](https://github.com/folke/sidekick.nvim/issues/80) ([4b65b8a](https://github.com/folke/sidekick.nvim/commit/4b65b8ad7e5e7e91e3db24a9061c6eb561fe2fd4))
* **qwen:** set `mux_focus = true` since qwen doesnt process input if unfocused. Fixes [#104](https://github.com/folke/sidekick.nvim/issues/104) ([c262b25](https://github.com/folke/sidekick.nvim/commit/c262b25be46de67b96ca38c005a97d7091025818))
* **sessions:** load tools during session setup, since thet may register session backends (like opencode) ([c7761eb](https://github.com/folke/sidekick.nvim/commit/c7761eb382af14e220933ad50cf23c559dfb3815))
* **status:** always return `nil` when copilot status is disabled in config ([f908fec](https://github.com/folke/sidekick.nvim/commit/f908fec933fe3e5ad3c31fb3ed7fb48fee232a44))
* **terminal:** allow auto split width/height ([#111](https://github.com/folke/sidekick.nvim/issues/111)) ([03cf9fb](https://github.com/folke/sidekick.nvim/commit/03cf9fbe5fe23d4aeea981d62790ef54e307017e))
* **terminal:** better handling of crlf for send. See [#119](https://github.com/folke/sidekick.nvim/issues/119) ([7185e08](https://github.com/folke/sidekick.nvim/commit/7185e0863ba9f533b39d699243ee65c2f16062af))
* **terminal:** blur on hide ([81b2a85](https://github.com/folke/sidekick.nvim/commit/81b2a85543c5fd7fd19ce29169c99665e672c666))
* **terminal:** cleanup scrollback buffer ([9ef38db](https://github.com/folke/sidekick.nvim/commit/9ef38db6ea49fe04e2d237027e60cb96fe66af44))
* **terminal:** don't error when it's the last window and hiding. Closes [#124](https://github.com/folke/sidekick.nvim/issues/124) ([cab3ec4](https://github.com/folke/sidekick.nvim/commit/cab3ec49b751ad8aa3e1c743380accfe8f0798e8))
* **terminal:** keymap rhs fallback to rhs string ([2b644f0](https://github.com/folke/sidekick.nvim/commit/2b644f007ff59e9407ca8a12a400bcd896c1b096))
* **terminal:** no need to check for mouse scroll when we're not in terminal mode ([b52c3be](https://github.com/folke/sidekick.nvim/commit/b52c3beb608ae21079ac3800925e11a972cb76d9))
* **terminal:** only show scrollback when entering normal mode and the terminal window is current. Closes [#106](https://github.com/folke/sidekick.nvim/issues/106) ([1e03666](https://github.com/folke/sidekick.nvim/commit/1e036668600fc339fb69b406bab7227fdec668a2))
* **terminal:** remove padding since it causes issues with terminal reflow (Neovim bug) ([cc32068](https://github.com/folke/sidekick.nvim/commit/cc320688ed6015508f7b72a2770581e47ad972f6))
* **terminal:** safer way of entering terminal mode from scrollback buffer ([#129](https://github.com/folke/sidekick.nvim/issues/129)) ([2195213](https://github.com/folke/sidekick.nvim/commit/2195213ba29be1a5178e502076c1102958bd7283))
* **terminal:** safer way of entering terminal mode from scrollback buffer. Closes [#103](https://github.com/folke/sidekick.nvim/issues/103) ([0bc6f88](https://github.com/folke/sidekick.nvim/commit/0bc6f884ae4d807f5414b70d51a34fb813f588f9))
* **terminal:** scroll to last line in normal mode. Closes [#101](https://github.com/folke/sidekick.nvim/issues/101) ([69eb7b7](https://github.com/folke/sidekick.nvim/commit/69eb7b736798af9d382f1fc67df88e0450cf1529))
* **terminal:** send all text in one chunk with nvim_paste. Fixes [#119](https://github.com/folke/sidekick.nvim/issues/119). Fixes [#118](https://github.com/folke/sidekick.nvim/issues/118) ([ca97ecd](https://github.com/folke/sidekick.nvim/commit/ca97ecd0cface9913f942e3424aca767c6720445))
* **terminal:** use `nvim_paste` instead of `nvim_chan_send` to better simulate user input. Closes [#110](https://github.com/folke/sidekick.nvim/issues/110) ([cebcd44](https://github.com/folke/sidekick.nvim/commit/cebcd4415dc73e3713162e4ea317a6e91312f1a8))
* **terminal:** use nvim_put directly to paste into the terminal ([bed1d65](https://github.com/folke/sidekick.nvim/commit/bed1d65385e33bb0eae3fa4163b97606f2e4d8dc))
* **text:** handle empty virtual lines ([98a33eb](https://github.com/folke/sidekick.nvim/commit/98a33eb8c3550d4755570a2372e8cc573044711b))
* **tmux:** use `paste-buffer` with the `-r` flag to preserve newlines. Fixes [#93](https://github.com/folke/sidekick.nvim/issues/93) ([2fdc4d4](https://github.com/folke/sidekick.nvim/commit/2fdc4d482326035d9c5fe03f32ebeef84b63142c))
* **zellij:** attach to existing isolated session ([9deb771](https://github.com/folke/sidekick.nvim/commit/9deb7716ca1a60fa0644cbee10681ac9772f2c38))
* **zellij:** zellij:create -&gt; zellij:start ([4bd0df2](https://github.com/folke/sidekick.nvim/commit/4bd0df2694464b5fbe13a224bb5409f97e0af860))


### Performance Improvements

* **nes:** only send didFocus events for regular buffers and if different ([39a1638](https://github.com/folke/sidekick.nvim/commit/39a16381ef711a4e6ac6f95f4ba1297365889fef))
* **terminal:** only load scrollback buffer when needed ([628c3d0](https://github.com/folke/sidekick.nvim/commit/628c3d001e8697debdbd36dfed6441e7fe6fffc5))

## [1.3.0](https://github.com/folke/sidekick.nvim/compare/v1.2.0...v1.3.0) (2025-10-08)


### Features

* **context:** added quickfix context provider in CLI prompts ([#61](https://github.com/folke/sidekick.nvim/issues/61)) ([6c24d47](https://github.com/folke/sidekick.nvim/commit/6c24d47646ad3191a425bf646c0fe9396805d10a))
* **context:** added treesitter context `class`, `function`. You can add more in your config. ([8fb70e0](https://github.com/folke/sidekick.nvim/commit/8fb70e025a3dfd144944be7a1fa74b2af0e0f07d))
* **mux:** default to `tmux`, unless running inside a `zellij` session ([2110966](https://github.com/folke/sidekick.nvim/commit/2110966b5a2b76cb187b9bf80e23dd0b5327c8c7))
* **session:** attach to running tools in other tmux sessions ([#74](https://github.com/folke/sidekick.nvim/issues/74)) ([1de752c](https://github.com/folke/sidekick.nvim/commit/1de752c7c098e587928b193299c8a259f3499533))
* **tmux:** notify when starting a cli tool in a new window. ([c3d7572](https://github.com/folke/sidekick.nvim/commit/c3d7572c2dc0bb3d108debda5736c30909133433))
* **util:** Util.emit ([b0f3762](https://github.com/folke/sidekick.nvim/commit/b0f37629ac424cbde37d97066402506ea14dc1fa))


### Bug Fixes

* **cli:** fix insert mode for prompt action. Closes [#50](https://github.com/folke/sidekick.nvim/issues/50) ([8ebbd75](https://github.com/folke/sidekick.nvim/commit/8ebbd7578bcdd345b81ab0d3e6776133d6b0d140))
* **cli:** open cli window when started. Closes [#78](https://github.com/folke/sidekick.nvim/issues/78) ([b3560df](https://github.com/folke/sidekick.nvim/commit/b3560df49bd0a6d02a404a7a3ec8c57507861a3f))
* **cli:** properly propagate tool filter for show/toggle/focus. Closes [#57](https://github.com/folke/sidekick.nvim/issues/57) ([bc44db0](https://github.com/folke/sidekick.nvim/commit/bc44db09bbd5bd18551273d9349582b6e0f24bbc))
* **copilot-cli:** exclude copilot-language-server procs. Closes [#75](https://github.com/folke/sidekick.nvim/issues/75) ([ce85284](https://github.com/folke/sidekick.nvim/commit/ce852849344f3ef0410d2b3f6e5465819603e41f))
* **mux:** shorter session names. Fixes [#56](https://github.com/folke/sidekick.nvim/issues/56) ([a4e62ce](https://github.com/folke/sidekick.nvim/commit/a4e62cef32b6404bcbe4ef568d8a9d206b3cdaa8))
* **opencode:** onlny attach to existing opencode sessions on non-windows. Closes [#76](https://github.com/folke/sidekick.nvim/issues/76) ([063457e](https://github.com/folke/sidekick.nvim/commit/063457e154693ed532fb3c440b31066dde4d06b5))
* **opencode:** set back to system theme, since it is still not working for some ([b2818ec](https://github.com/folke/sidekick.nvim/commit/b2818ec5edffe061ce10ec3ca19c9896e418b32f))
* **session:** add optional detach() for session backends ([3aa531e](https://github.com/folke/sidekick.nvim/commit/3aa531e449965f5455b203c8356eb2f4e430adee))
* **session:** added detach ([7e88fa5](https://github.com/folke/sidekick.nvim/commit/7e88fa5672c4288c61548fe43e004dcd25ca4f84))
* **sessions:** better attached session tracking ([eaa7592](https://github.com/folke/sidekick.nvim/commit/eaa759204325abe4444a431517bb1ab697eadf0e))
* **state:** metatable to always get latest state through getters ([e0b32f5](https://github.com/folke/sidekick.nvim/commit/e0b32f59f2e03d0d67c0897c344a7d46f5d56e6a))
* **terminal:** use `exepath()` on windows. See [#53](https://github.com/folke/sidekick.nvim/issues/53) ([c307316](https://github.com/folke/sidekick.nvim/commit/c307316f77d80fbe92bd571c59ce1868703fe411))
* **terminal:** use shell on windows for jobstart when cmd is not an exe. See [#53](https://github.com/folke/sidekick.nvim/issues/53) ([3f1ccba](https://github.com/folke/sidekick.nvim/commit/3f1ccba5277417388a81598a4b7f08db849f29f7))
* **test:** treesitter woes in tests ([af931db](https://github.com/folke/sidekick.nvim/commit/af931dbda2efb19777810955c4563a6d0ce3201a))
* **tmux:** add detach-on-destroy option to tmux sessions ([#67](https://github.com/folke/sidekick.nvim/issues/67)) ([c525b13](https://github.com/folke/sidekick.nvim/commit/c525b1325b801b12f725ab4f2ae07b30676bdf54))
* **tmux:** set tool env vars. Closes [#62](https://github.com/folke/sidekick.nvim/issues/62) ([e869205](https://github.com/folke/sidekick.nvim/commit/e869205ff05a8defec31175e0f7f8f923e13cde6))
* **tmux:** use load-buffer instead of set-buffer to prevent issues with non-escaped text ([de62ed1](https://github.com/folke/sidekick.nvim/commit/de62ed1804897028cd3b0467f10d8f41dc8996db))

## [1.2.0](https://github.com/folke/sidekick.nvim/compare/v1.1.0...v1.2.0) (2025-10-02)


### Features

* added `:Sidekick` command ([2f17d6b](https://github.com/folke/sidekick.nvim/commit/2f17d6bdf245381149b2515401a37ee67364904f))
* **cli.prompts:** when viewing the prompt select with snacks, you can copy with `<c-y>` and `y` in insert/normal mode ([f2098d9](https://github.com/folke/sidekick.nvim/commit/f2098d978dbf19a64283ebe98c901cae8c986960))
* **cli:** added Amazon Q ([e84c5d0](https://github.com/folke/sidekick.nvim/commit/e84c5d0df454ded38d6cd1982c8f689ebdde8b4e))
* **cli:** added proper multi-session management. you can now also resume mux sessions from other directories ([605c26b](https://github.com/folke/sidekick.nvim/commit/605c26b72eca9e310a67cb3ab8a4feaae4ca416f))
* **cli:** allow dynamic terminal configuration. Closes [#25](https://github.com/folke/sidekick.nvim/issues/25) ([6b265fa](https://github.com/folke/sidekick.nvim/commit/6b265faa39a182fb3fe0e92166232a330ed26d60))
* **cli:** allow overriding/adding keymaps per tool ([6def9f4](https://github.com/folke/sidekick.nvim/commit/6def9f4b1ae681c9b71c6ac054a67c0fe9773a4c))
* **cli:** lots of prompt/context improvements ([8a1f761](https://github.com/folke/sidekick.nvim/commit/8a1f76109b0a126a304151d64b540a7392ee08a7))
* **cli:** rework prompts/context and sending ([75b1897](https://github.com/folke/sidekick.nvim/commit/75b189707d087e8b142b10fd5dec8be03ef23ff4))
* **config:** added aider ([5144187](https://github.com/folke/sidekick.nvim/commit/514418756189083767177099d85768d72c21f103))
* **context:** lots of improvements to context including visual selection and proper previews ([7877322](https://github.com/folke/sidekick.nvim/commit/78773228c05461f40737680177de695e579b1ace))
* **health:** added extra checks for duplicate Copilot LSP servers ([0b89f04](https://github.com/folke/sidekick.nvim/commit/0b89f04999065e8917eb480c9243a70e7ccdf147))
* **nes:** added enable/disable/toggle for NES ([2d280e9](https://github.com/folke/sidekick.nvim/commit/2d280e931e02a44cb65c35d58ae42f55538866bc))
* **nes:** disable nes fully when `enabled=false` ([11428c1](https://github.com/folke/sidekick.nvim/commit/11428c1e9890056136329dd4c0451dcb81feb830))
* **nes:** trigger SidekickNesShow and SidekickNesHide after update. Closes [#19](https://github.com/folke/sidekick.nvim/issues/19) ([302cec7](https://github.com/folke/sidekick.nvim/commit/302cec770ca0a4b7dfafd7879034d33320592b33))
* **terminal:** added full support for split / float layouts ([c93c0cb](https://github.com/folke/sidekick.nvim/commit/c93c0cbc2177a0eef19cf81adfe20329e4a90e83))
* **terminal:** set `ft=sidekick_terminal` ([03366cc](https://github.com/folke/sidekick.nvim/commit/03366ccdcb9a58c140ad1c68c0da644d5d264f2f))
* **tmux:** disable status bar in sidekick window ([#42](https://github.com/folke/sidekick.nvim/issues/42)) ([832165b](https://github.com/folke/sidekick.nvim/commit/832165bf84f40e3dd3a86c8d66835903e036013f))
* **tmux:** pass custom config file including user's config with a disabled status bar. Closes [#36](https://github.com/folke/sidekick.nvim/issues/36) ([6f06163](https://github.com/folke/sidekick.nvim/commit/6f0616359540fcbfa5cf2ae88cbdf2a028331a86))
* **tools:** added crush ([d6e25f3](https://github.com/folke/sidekick.nvim/commit/d6e25f370f9fd969158b40094bcbe7b75a776623))


### Bug Fixes

* **cli.context:** don't add a location for non-file buffers ([d72c611](https://github.com/folke/sidekick.nvim/commit/d72c611aa37b24d8ad401c4029d8946e27f53475))
* **cli.context:** get the correct buffer for providing context ([754ee76](https://github.com/folke/sidekick.nvim/commit/754ee7640ba32ce0e2350a3604ac85ea00865f45))
* **cli.context:** lastused sorting ([c448bb2](https://github.com/folke/sidekick.nvim/commit/c448bb2bd11fb1aaabd291eafe9759dc214c792e))
* **cli.crush:** use `<a-p>` for prompt instead of `<c-p>` for crush, since it's needed for its own functionality. Fixes [#17](https://github.com/folke/sidekick.nvim/issues/17) ([efbce7a](https://github.com/folke/sidekick.nvim/commit/efbce7a7110f7aa1592ab875fde7f724094bf3a7))
* **cli.prompts:** don't show empty rendered prompts in select ([d930586](https://github.com/folke/sidekick.nvim/commit/d930586085c970fe58356c2da9462572bb31d1dc))
* **cli:** fup ([094080d](https://github.com/folke/sidekick.nvim/commit/094080d5ca5b1dbe474cbdcefac63436881c8fe3))
* **cli:** prompt action ([8d9b06c](https://github.com/folke/sidekick.nvim/commit/8d9b06cabf5370f5e84798d86c84bc347cea859a))
* **cli:** removed some default keymaps since they clash with cli tools. Closes [#30](https://github.com/folke/sidekick.nvim/issues/30) ([8519d3b](https://github.com/folke/sidekick.nvim/commit/8519d3b777b39273e8734ab9e00f1c4e39805896))
* **cli:** set proper TERM for cli tools. Fixes [#37](https://github.com/folke/sidekick.nvim/issues/37) ([7608be2](https://github.com/folke/sidekick.nvim/commit/7608be2a532fe663e471bf23483e6537e73a0d51))
* **health:** special checks for LSP server bundled with copilot.lua and copilot.vim. Fixes [#15](https://github.com/folke/sidekick.nvim/issues/15) ([d11ee7f](https://github.com/folke/sidekick.nvim/commit/d11ee7f7209d3417d1bc007f387b665db43117bc))
* **mux:** `M:_sessions` -&gt; `M._sessions` ([c73cc39](https://github.com/folke/sidekick.nvim/commit/c73cc397cf4c01df774815d4f5e089390be3a59b))
* **mux:** better commands to get existing sessions ([feea2b2](https://github.com/folke/sidekick.nvim/commit/feea2b2560cd9229f72bef74e0d0e69754c34d5f))
* **nes:** allow any lsp server name containing `copilot` ([#9](https://github.com/folke/sidekick.nvim/issues/9)) ([74acbde](https://github.com/folke/sidekick.nvim/commit/74acbde14b824f67ba0194992bb669a053033711))
* **nes:** delete at end of file triggered error ([7b8769f](https://github.com/folke/sidekick.nvim/commit/7b8769f7f6c820b66965b91382fcf34d3da5889f))
* **opencode:** remove hack since it's no longer needed. See [#16](https://github.com/folke/sidekick.nvim/issues/16) ([f2dcd16](https://github.com/folke/sidekick.nvim/commit/f2dcd16641ebb7bedc86b3211d3f97c84954d4ae))
* **opencode:** work-around for opencode rendering artifacts by forcing `system` theme. See [#16](https://github.com/folke/sidekick.nvim/issues/16) ([d29fbc9](https://github.com/folke/sidekick.nvim/commit/d29fbc90a3593ffcd00244a8c48a6dd373013353))
* **terminal:** change initial delay from 2 seconds to 500 ms ([c7948f1](https://github.com/folke/sidekick.nvim/commit/c7948f12ae9c77433c95b701e46f05728e90cc44))
* **terminal:** check for exit code ~= 0 ([5bd2d01](https://github.com/folke/sidekick.nvim/commit/5bd2d0163b3bbe35c4f7b464cf9b070c33e1c59f))
* **terminal:** don't automatically close the terminal window when the command exited too quickly ([52a6ed4](https://github.com/folke/sidekick.nvim/commit/52a6ed40d312726a45ffc191fdc81791c4d928f5))
* **terminal:** don't close when cli tool exits too quickly ([63ec164](https://github.com/folke/sidekick.nvim/commit/63ec164ea9e88731b1fc69533eefe908731a625d))
* **terminal:** set winfixwidth and winfixheight when needed ([09dbae1](https://github.com/folke/sidekick.nvim/commit/09dbae13046193bf83d23e23297c678b62591424))
* **terminal:** startinsert on focus and stopinsert on blur ([5e9f9da](https://github.com/folke/sidekick.nvim/commit/5e9f9da7bd53d4777a3ee1ff94f8355473d1ab4b))
* **terminal:** use vim environ instead of uv ([0d99706](https://github.com/folke/sidekick.nvim/commit/0d997060670028544438fa3eb4d26c04492af1e7))
* **zellij:** disable session serialization for AI tools ([71d17b9](https://github.com/folke/sidekick.nvim/commit/71d17b92648b84fbe654fec07934fd5dbef330e4))

## [1.1.0](https://github.com/folke/sidekick.nvim/compare/v1.0.0...v1.1.0) (2025-09-29)


### Features

* **cli:** added ai tool urls ([51431b1](https://github.com/folke/sidekick.nvim/commit/51431b158c2cf76d65fcfd4166d29b7486b0999f))
* **cli:** added blur/is_focused ([614c08c](https://github.com/folke/sidekick.nvim/commit/614c08c00b71b56f2b2e99189ebf2a41e7127951))
* **cli:** added cli.blur to defocus the terminal window ([4e465c0](https://github.com/folke/sidekick.nvim/commit/4e465c0113166f43467c55ca1a5e42cd58b5eb45))
* **cli:** added custom snacks options for `vim.ui.select` ([8e8677c](https://github.com/folke/sidekick.nvim/commit/8e8677c2ea53feeb47f05bdcb3d02e1038a32dbb))
* **cli:** added support for starting AI cli tools in a zellij or tmux session ([0385dbf](https://github.com/folke/sidekick.nvim/commit/0385dbf7f597a27c14de99ee594670008fdf9b7a))
* **cli:** added toggle focus ([c83ebd5](https://github.com/folke/sidekick.nvim/commit/c83ebd52501a230276c9fa8b86657d044517a379))
* **cli:** added watcher to let Neovim know when an AI tool updated any buffers ([c1083fa](https://github.com/folke/sidekick.nvim/commit/c1083faba3e9f4b5cc53c610564c43bbb9bbfc4f))
* **cli:** AI cli tools integration ([ab5da08](https://github.com/folke/sidekick.nvim/commit/ab5da081ae5ba579c306f20de5e3598c7045151f))
* **cli:** cli tool keymaps ([ac353d4](https://github.com/folke/sidekick.nvim/commit/ac353d4be53a44cc05350c35f4d2bd41e116f328))
* **config:** `enabled` option that defaults to checking `vim.g|b.copilot.nes == false` ([9ab4458](https://github.com/folke/sidekick.nvim/commit/9ab44589492ae06639d1af2bf5be674a95e70460))
* **config:** added opencode and cursor to tools ([c11c1b9](https://github.com/folke/sidekick.nvim/commit/c11c1b98e364b4c28c8a940526b8118663555f05))
* **health:** add multiplexer checks ([a903fb1](https://github.com/folke/sidekick.nvim/commit/a903fb1ecaec153c3975a6de204c7f9da22e739e))
* **util:** debug logging ([6315c92](https://github.com/folke/sidekick.nvim/commit/6315c927a7c7913c8c9954c6d23b4e7830ddcc1e))
* **util:** debug notify ([9454ee7](https://github.com/folke/sidekick.nvim/commit/9454ee78ecbbaf416682ccf24830912cb7e3b153))
* **watch:** added config flag to enable/disable watch ([8a8c1ae](https://github.com/folke/sidekick.nvim/commit/8a8c1aeda4c98c434e109cd6a96b1aafd9957627))


### Bug Fixes

* **cli:** tag buffer for context ([08e67b8](https://github.com/folke/sidekick.nvim/commit/08e67b8d724a2a29bda89a6c3e97e8875c84a594))
* **cli:** toggle with focus by default ([c8e60d7](https://github.com/folke/sidekick.nvim/commit/c8e60d7802372f28761b5da189224ea20c4337ae))
* **context:** border cases ([ee09859](https://github.com/folke/sidekick.nvim/commit/ee09859a5e68bebfdfe890a15a889455070d2c54))
* **diff:** added support for Neovim &lt; 0.12 ([9166a6b](https://github.com/folke/sidekick.nvim/commit/9166a6b8bc2e3316cf404b76864d9cba84abb588))
* **diff:** better diff rendering to let extmarks behave ([90f693b](https://github.com/folke/sidekick.nvim/commit/90f693b161d0c0ba3aaa0d218661feb6a9f1e0c8))
* **diff:** fixed some edge cases for insertions before after first/last line of the buffer ([a3ec994](https://github.com/folke/sidekick.nvim/commit/a3ec994d53ed5d19321f198ad9604ce17bf97ae7))
* **diff:** hunk position for inline diff was sometimes wrong. Fixes [#4](https://github.com/folke/sidekick.nvim/issues/4) ([f421518](https://github.com/folke/sidekick.nvim/commit/f421518ebe9b0184d020d7694f2ffbcf40719aa3))
* **diff:** line insert before first line ([2cc5374](https://github.com/folke/sidekick.nvim/commit/2cc53741c5ec2eb8bd031495a45b635736edaabf))
* **nes:** only execute edit command when available ([49e79a6](https://github.com/folke/sidekick.nvim/commit/49e79a6d7a36e8d03ae790efe2c4b7a2c9b61376))
* **nes:** properly clear render flag and make it different from the disable flag ([3271eea](https://github.com/folke/sidekick.nvim/commit/3271eea2630e4342fa719e0b10ea75c7f99cdb55))
* **snacks:** load module instead of using global ([77bf35f](https://github.com/folke/sidekick.nvim/commit/77bf35f4ee4f41dbc40b739fa2d988e0fcf27bc9))
* **terminal:** open window before running cli tool. Fixes [#5](https://github.com/folke/sidekick.nvim/issues/5) ([4e4928c](https://github.com/folke/sidekick.nvim/commit/4e4928c7a271befe27e3b5a541951e93efd95eaa))
* **treesitter:** one-off with getting text before first highlight ([5e79172](https://github.com/folke/sidekick.nvim/commit/5e79172f947daf6e748e063f1283f795fafbdf23))
* **ui:** show only one sign ([f4545fa](https://github.com/folke/sidekick.nvim/commit/f4545faa29a02ddaf6ac8752b81d219ace7b4640))
* **watch:** disable debug ([cd69b41](https://github.com/folke/sidekick.nvim/commit/cd69b416dba425053545f5518610aa6d5e310de2))

## 1.0.0 (2025-09-27)


### Features

* added trigger/clear configs ([55beb96](https://github.com/folke/sidekick.nvim/commit/55beb9626bcbe7277d8aee15aca075e6befad138))
* **config:** configure copilot through Lsp events. Not needed to use `vim.lsp.config` for this ([3fe1f3d](https://github.com/folke/sidekick.nvim/commit/3fe1f3da260f870cd0e93b5ecc02a4140cdedc4d))
* **diff:** better inline diffing ([23ca2c6](https://github.com/folke/sidekick.nvim/commit/23ca2c6b89ccad93ed3a1aa9c1f559fcc8ed0df2))
* **diff:** diff config options ([ac5f9b8](https://github.com/folke/sidekick.nvim/commit/ac5f9b844fc998360fba7b8458517c8db8ca06aa))
* **diff:** diff options ([d606531](https://github.com/folke/sidekick.nvim/commit/d606531f617f1346551e1f840c6af03300d5cfb9))
* **diff:** diff refactoring ([ef2884e](https://github.com/folke/sidekick.nvim/commit/ef2884e513f45cca69e99fb3d39cca54e4bc8cae))
* **health:** added health check ([1f72350](https://github.com/folke/sidekick.nvim/commit/1f7235019511b04c4482d870966f2261955a1654))
* initial commit ([9464193](https://github.com/folke/sidekick.nvim/commit/94641937514c21c657128e76f474c03bd971ba58))
* **nes:** jump to end of text edit after apply ([77ab4b2](https://github.com/folke/sidekick.nvim/commit/77ab4b2815bb65e462155ba11c79e62477a1feee))
* **treesitter.slice:** allow to to be nil ([0bb097e](https://github.com/folke/sidekick.nvim/commit/0bb097ec52b88f2b67ea91ccef472709f72d8761))
* **treesitter:** update leading/trailing/eol whitespace hl_group ([6cf8067](https://github.com/folke/sidekick.nvim/commit/6cf8067fdb7aa4721d16fceade93936a37d42c37))
* **ui:** optional signs ([59abe52](https://github.com/folke/sidekick.nvim/commit/59abe526852fd3e56532452dfa49793b4d5e1b8b))
* **util:** split_words / split_chars ([5335ad9](https://github.com/folke/sidekick.nvim/commit/5335ad94baca9463dc02a6c767bda057dcf99992))


### Bug Fixes

* **config:** move result_type to diff ([489834c](https://github.com/folke/sidekick.nvim/commit/489834c0a7d58110b008043f2215369a66a90328))
* **diff:** diff fixes ([c816758](https://github.com/folke/sidekick.nvim/commit/c816758ae0f5698fc682c372313daa1cbefd2a2f))
* offset encoding ([11b38ae](https://github.com/folke/sidekick.nvim/commit/11b38ae68f0557c15e082d93c43e8eca40686fac))
* **status:** notify on copilot errors/warnings ([765c8e3](https://github.com/folke/sidekick.nvim/commit/765c8e3afe6b9c171403666171f03d983274df74))
* **ui:** one sign per hunk ([5a16ea8](https://github.com/folke/sidekick.nvim/commit/5a16ea84e983a4d5c6edaaa1a6662db2d138bf82))
