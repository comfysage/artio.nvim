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
    hi("ArtioMarker", { link = "DiagnosticWarn" })
  end,
})

-- == pickers ==

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
vim.keymap.set("n", "<Plug>(artio-highlights)", function()
  return require("artio.builtins").highlights()
end)
vim.keymap.set("n", "<Plug>(artio-colorschemes)", function()
  return require("artio.builtins").colorschemes()
end)
vim.keymap.set("n", "<Plug>(artio-diagnostics)", function()
  return require("artio.builtins").diagnostics()
end)
vim.keymap.set("n", "<Plug>(artio-diagnostics-buffer)", function()
  return require("artio.builtins").diagnostics_buffer()
end)

-- == actions ==

local function wrap(fn)
  return function()
    (require("artio").wrap(fn))()
  end
end

vim.keymap.set(
  "i",
  "<Plug>(artio-action-down)",
  wrap(function(self)
    self.idx = self.idx + 1
    self.view:showmatches() -- adjust for scrolling
    self.view:hlselect()
  end)
)
vim.keymap.set(
  "i",
  "<Plug>(artio-action-up)",
  wrap(function(self)
    self.idx = self.idx - 1
    self.view:showmatches() -- adjust for scrolling
    self.view:hlselect()
  end)
)
vim.keymap.set(
  "i",
  "<Plug>(artio-action-accept)",
  wrap(function(self)
    coroutine.resume(self.co, 0)
  end)
)
vim.keymap.set(
  "i",
  "<Plug>(artio-action-cancel)",
  wrap(function(self)
    coroutine.resume(self.co, 1)
  end)
)
vim.keymap.set(
  "i",
  "<Plug>(artio-action-mark)",
  wrap(function(self)
    local match = self.matches[self.idx]
    if not match then
      return
    end
    local idx = match[1]
    self:mark(idx, not self.marked[idx])
    self.view:showmatches() -- redraw marker
    self.view:hlselect()
  end)
)
vim.keymap.set(
  "i",
  "<Plug>(artio-action-togglepreview)",
  wrap(function(self)
    self.view:togglepreview()
  end)
)
