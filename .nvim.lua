R = function(m, ...)
  require("plenary.reload").reload_module(m, ...)
  return require(m)
end

vim.cmd([[ set rtp^=. ]])

require("vim._core.ui2").enable({})

vim.api.nvim_create_autocmd("UIEnter", {
  callback = function()
    R("artio").setup()
  end,
})

vim.cmd([[ noremap <leader>r <cmd>restart +qall!<cr> ]])
vim.cmd([[ noremap <leader>; <Plug>(artio-resume) ]])

vim.ui.select = function(...)
  return require("artio").select(...)
end
