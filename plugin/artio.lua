if vim.g.loaded_artio then
  return
end

vim.g.loaded_artio = true

local augroup = vim.api.nvim_create_augroup("artio:hl", {})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = function()
    local hi = function(name, opts)
      opts.default = true
      vim.api.nvim_set_hl(0, name, opts)
    end

    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
    local msgarea_hl = vim.api.nvim_get_hl(0, { name = "MsgArea" })

    hi("ArtioNormal", { fg = normal_hl.fg, bg = msgarea_hl.bg })
    hi("ArtioPrompt", { link = "Title" })

    local cursor_hl = vim.api.nvim_get_hl(0, { name = "Cursor" })
    local cursorline_hl = vim.api.nvim_get_hl(0, { name = "CursorLine" })
    hi("ArtioSel", { fg = cursor_hl.bg, bg = cursorline_hl.bg })
    hi("ArtioPointer", { fg = cursor_hl.bg })

    hi("ArtioMatch", { link = "PmenuMatch" })
  end,
})

vim.keymap.set("n", "<Plug>(artio-files)", function()
  return require("artio.builtins").files()
end)
vim.keymap.set("n", "<Plug>(artio-oldfiles)", function()
  return require("artio.builtins").oldfiles()
end)
vim.keymap.set("n", "<Plug>(artio-grep)", function()
  return require("artio.builtins").grep()
end)
vim.keymap.set("n", "<Plug>(artio-helptags)", function()
  return require("artio.builtins").helptags()
end)
vim.keymap.set("n", "<Plug>(artio-buffergrep)", function()
  return require("artio.builtins").buffergrep()
end)
vim.keymap.set("n", "<Plug>(artio-buffers)", function()
  return require("artio.builtins").buffers()
end)
vim.keymap.set("n", "<Plug>(artio-smart)", function()
  return require("artio.builtins").smart()
end)
