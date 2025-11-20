# artio.nvim

A minimal, nature-infused file picker for Neovim using the new extui window.
Inspired by forest spirits and the calm intuition of hunting, Artio helps you gently select files without the weight of heavy fuzzy-finder dependencies.

![preview](./assets/preview.png)

## features

Requires Neovim `>= 0.12`

- Lightweight picker window built on Neovim's extui
- Prompt + list UI components - minimal and focused
- Fuzzy filtering using matchfuzzy (built-in)
- Icon support for common filetypes through [mini.icons](https://github.com/echasnovski/mini.nvim) _(optional)_
- No heavy dependencies - pure Lua

## installation

`vim.pack`

```lua
vim.pack.add({ src = "https://github.com/comfysage/artio.nvim" })
```

`lazy.nvim`

```lua
{
  "comfysage/artio.nvim", lazy = false,
}
```

## configuration

```lua
require("artio").setup({
  opts = {
    preselect = true,
    bottom = true,
    promptprefix = "",
    pointer = "",
    use_icons = true, -- requires mini.icons
  },
  win = {
    height = 12,
    hidestatusline = false, -- works best with laststatus=3
  },
})

-- override built-in ui select with artio
vim.ui.select = require("artio").select

vim.keymap.set("n", "<leader><leader>", "<Plug>(artio-files)")
```
