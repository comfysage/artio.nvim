R = function(m, ...)
  require("plenary.reload").reload_module(m, ...)
  return require(m)
end

vim.cmd([[ set rtp^=. ]])

R("artio").setup()

vim.cmd([[ noremap <leader>r <cmd>restart<cr> ]])

vim.ui.select = function(...)
  return require("artio").select(...)
end
