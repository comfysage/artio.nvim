local function lzrq(modname)
  return setmetatable({}, {
    __index = function(_, key)
      return require(modname)[key]
    end,
  })
end

local config = lzrq("artio.config")

local artio = {}

---@param cfg? artio.config
artio.setup = function(cfg)
  cfg = cfg or {}
  config.set(config.override(cfg))
end

---@param lst artio.Picker.item[]
---@param input string
---@return artio.Picker.match[]
artio.sorter = function(lst, input)
  if not lst or #lst == 0 then
    return {}
  end

  if not input or #input == 0 then
    return vim.tbl_map(function(v)
      return { v.id, {}, 0 }
    end, lst)
  end

  local matches = vim.fn.matchfuzzypos(lst, input, { key = "text" })

  local items = {}
  for i = 1, #matches[1] do
    items[#items + 1] = { matches[1][i].id, matches[2][i], matches[3][i] }
  end
  return items
end

---@generic T
---@param items T[] Arbitrary items
---@param opts vim.ui.select.Opts Additional options
---@param on_choice fun(item: T|nil, idx: integer|nil)
artio.select = function(items, opts, on_choice)
  return artio.generic(items, {
    prompt = opts.prompt,
    on_close = function(_, idx)
      return on_choice(items[idx], idx)
    end,
    format_item = opts.format_item and function(item)
      return opts.format_item(item)
    end or nil,
  })
end

---@generic T
---@param items T[]
---@param props artio.Picker.proto
artio.generic = function(items, props)
  return artio.pick(vim.tbl_deep_extend("force", {
    fn = artio.sorter,
    items = items,
  }, props))
end

---@param ... artio.Picker.proto
artio.pick = function(...)
  local Picker = require("artio.picker")
  return Picker:new(...):open()
end

return artio
