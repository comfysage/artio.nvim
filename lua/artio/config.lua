---@module 'artio.config'

---@class artio.config
---@field opts artio.config.opts
---@field win artio.config.win

---@class artio.config.opts
---@field preselect boolean
---@field bottom boolean
---@field promptprefix string
---@field pointer string

---@class artio.config.win
---@field height? integer|number
---@field hidestatusline? boolean

local M = {}

---@type artio.config
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
---@text # Default ~
M.default = {
  opts = {
    preselect = true,
    bottom = true,
    promptprefix = "",
    pointer = "",
  },
  win = {
    height = 12,
    hidestatusline = false, -- works best with laststatus=3
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

  if vim.islist(tdefault) then
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
  if vim.fn.has("nvim-0.11.0") == 1 then
    toverride =
      vim.tbl_deep_extend("keep", toverride, { editor = { float = { solid_border = vim.o.winborder == "solid" } } })
  end
  return tmerge(tdefault, toverride)
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
