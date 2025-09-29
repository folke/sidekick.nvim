# Changelog

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
