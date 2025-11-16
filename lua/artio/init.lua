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

---@param lst string[]
artio.sorter = function(lst)
  return function(input)
    if not lst or #lst == 0 then
      return {}
    end

    if not input or #input == 0 then
      return vim.tbl_map(function(v)
        return { v, {} }
      end, lst)
    end

    local matches = vim.fn.matchfuzzypos(lst, input)
    return vim
      .iter(ipairs(matches[1]))
      :map(function(index, v)
        return { v, matches[2][index] }
      end)
      :totable()
  end
end

artio.generic = function(lst, props)
  return artio.pick(vim.tbl_deep_extend("force", {
    fn = artio.sorter(lst),
  }, props))
end

artio.pick = function(...)
  local Picker = require("artio.picker")
  return Picker:new(...):open()
end

return artio
