vim.cmd([[ set rtp^=. ]])

vim.cmd([[ nnoremap <leader>ff <Plug>(artio-files) ]])
vim.cmd([[ noremap <leader>r <cmd>restart<cr> ]])

vim.ui.select = require("artio").select
