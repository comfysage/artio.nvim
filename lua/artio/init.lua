local artio = {}

---@param lst string[]
artio.sorter = function(lst)
  return function(input)
    if not lst or #lst == 0 then
      return {}
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
