---@module 'artio.config'

---@class artio.config
---@field opts artio.config.opts
---@field win artio.config.win
---@field mappings table<string, 'up'|'down'|'accept'|'cancel'|'togglepreview'|string>

---@class artio.config.opts
---@field preselect boolean
---@field bottom boolean
---@field shrink boolean
---@field promptprefix string
---@field prompt_title boolean
---@field pointer string
---@field marker string
---@field infolist ('index'|'list')[]
---@field use_icons boolean

---@class artio.config.win
---@field height? integer|number
---@field hidestatusline? boolean
---@field preview_opts? fun(view: artio.View): vim.api.keyset.win_config

local M = {}

---@type artio.config
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Default ~
M.default = {
  opts = {
    preselect = true,
    bottom = true,
    shrink = true,
    promptprefix = "",
    prompt_title = true,
    pointer = "",
    marker = "│",
    infolist = { "list" }, -- index: [1] list: (4/5)
    use_icons = _G["MiniIcons"] and true or false,
  },
  win = {
    height = 0.4,
    hidestatusline = false, -- works best with laststatus=3
    ---@diagnostic disable-next-line: assign-type-mismatch
    preview_opts = vim.NIL,
  },
  mappings = {
    ["<down>"] = "down",
    ["<up>"] = "up",
    ["<cr>"] = "accept",
    ["<esc>"] = "cancel",
    ["<tab>"] = "mark",
    ["<c-g>"] = "togglelive",
    ["<c-l>"] = "togglepreview",
    ["<c-q>"] = "setqflist",
    ["<m-q>"] = "setqflistmark",
    ["<c-s>"] = "split",
    ["<c-v>"] = "vsplit",
    ["<c-t>"] = "tabnew",
  },
}

---@type artio.config
---@diagnostic disable-next-line: missing-fields
M.config = {}

---@private
---@generic T: table|any[]
---@param tdefault T
---@param toverride T
---@return T
local function tmerge(tdefault, toverride)
  if toverride == nil then
    return tdefault
  end

  if tdefault == vim.NIL or vim.islist(tdefault) then
    return toverride
  end
  if vim.tbl_isempty(tdefault) then
    return toverride
  end

  return vim.iter(pairs(tdefault)):fold({}, function(tnew, k, v)
    if toverride[k] == nil or type(v) ~= type(toverride[k]) then
      tnew[k] = v
      return tnew
    end
    if type(v) == "table" then
      tnew[k] = tmerge(v, toverride[k])
      return tnew
    end

    tnew[k] = toverride[k]
    return tnew
  end)
end

---@param tdefault artio.config
---@param toverride artio.config
---@return artio.config
function M.merge(tdefault, toverride)
  local defaults = vim.deepcopy(tdefault, true)
  local mappings = tdefault.mappings
  defaults.mappings = vim.NIL
  local t = tmerge(defaults, toverride)
  t.mappings = toverride.mappings or mappings

  return t
end

---@return artio.config
function M.get()
  return M.merge(M.default, M.config)
end

---@param cfg artio.config
---@return artio.config
function M.override(cfg)
  return M.merge(M.default, cfg)
end

---@param cfg artio.config
function M.set(cfg)
  M.config = cfg
end

return M
