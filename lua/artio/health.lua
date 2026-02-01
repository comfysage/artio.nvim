local health = {}

health.check = function()
  vim.health.start("artio")

  if not vim.g.loaded_artio then
    vim.health.error("artio.nvim not loaded")
  end

  if not vim.tbl_get(require("vim._core.ui2") or {}, "cfg", "enable") then
    vim.health.error("ui2 not enabled")
  end

  if _G["MiniIcons"] then
    vim.health.ok("mini.icons support")
  else
    vim.health.warn([[
      mini.icons support not found
      make sure you have mini.nvim installed and configured using `require('mini.icons').setup()`.]])
  end
end

return health
