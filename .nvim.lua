R = function(m, ...)
  require("plenary.reload").reload_module(m, ...)
  return require(m)
end

vim.cmd([[ set rtp^=. ]])

R("artio")

vim.cmd([[ nnoremap <leader>ff <Plug>(artio-files) ]])
vim.cmd([[ noremap <leader>r <cmd>restart<cr> ]])

vim.ui.select = require("artio").select
