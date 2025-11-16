vim.cmd([[ nnoremap <leader>ff <Plug>(picker-find) ]])
vim.cmd([[ noremap <leader>r <cmd>restart<cr> ]])

vim.ui.select = require("artio").select
