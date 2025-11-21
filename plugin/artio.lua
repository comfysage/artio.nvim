if vim.g.loaded_artio then
  return
end

vim.g.loaded_artio = true

local augroup = vim.api.nvim_create_augroup("artio:hl", {})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = function()
    local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
    local msgarea_hl = vim.api.nvim_get_hl(0, { name = "MsgArea" })

    vim.api.nvim_set_hl(0, "ArtioNormal", { fg = normal_hl.fg, bg = msgarea_hl.bg, default = true })
    vim.api.nvim_set_hl(0, "ArtioPrompt", { link = "Title", default = true })

    local cursor_hl = vim.api.nvim_get_hl(0, { name = "Cursor" })
    local cursorline_hl = vim.api.nvim_get_hl(0, { name = "CursorLine" })
    vim.api.nvim_set_hl(0, "ArtioSel", { fg = cursor_hl.bg, bg = cursorline_hl.bg, default = true })
    vim.api.nvim_set_hl(0, "ArtioPointer", { fg = cursor_hl.bg, default = true })

    vim.api.nvim_set_hl(0, "ArtioMatch", { link = "PmenuMatch", default = true })
  end,
})

vim.api.nvim_create_autocmd("ColorSchemePre", {
  group = augroup,
  callback = function()
    vim.api.nvim_set_hl(0, "ArtioNormal", {})
    vim.api.nvim_set_hl(0, "ArtioPrompt", {})
    vim.api.nvim_set_hl(0, "ArtioSel", {})
    vim.api.nvim_set_hl(0, "ArtioPointer", {})
    vim.api.nvim_set_hl(0, "ArtioMatch", {})
  end,
})

vim.keymap.set("n", "<Plug>(artio-files)", function()
  return require("artio.builtins").files()
end)
vim.keymap.set("n", "<Plug>(artio-oldfiles)", function()
  return require("artio.builtins").oldfiles()
end)
vim.keymap.set("n", "<Plug>(artio-livegrep)", function()
  return require("artio.builtins").livegrep()
end)
vim.keymap.set("n", "<Plug>(artio-helptags)", function()
  return require("artio.builtins").helptags()
end)
vim.keymap.set("n", "<Plug>(artio-buffers)", function()
  return require("artio.builtins").buffers()
end)
vim.keymap.set("n", "<Plug>(artio-smart)", function()
  return require("artio.builtins").smart()
end)
