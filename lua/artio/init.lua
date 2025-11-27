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
  config.set(cfg)
end

---@param a integer[]
---@param ... integer[]
---@return integer[]
local function mergehl(a, ...)
  local hl_lists = { a, ... }

  local t = vim.iter(hl_lists):fold({}, function(hls, hl_list)
    for i = 1, #hl_list do
      hls[hl_list[i]] = true
    end
    return hls
  end)
  return vim.tbl_keys(t)
end

---@param a artio.Picker.match
---@param b artio.Picker.match
---@return artio.Picker.match
local function mergematches(a, b)
  return { a[1], mergehl(a[2], b[2]), a[3] + b[3] }
end

---@param strat 'combine'|'intersect'|'base'
--- combine:
---   a, b -> a + ab + b
--- intersect:
---   a, b -> ab
--- base:
---   a, b -> a + ab
---@param a artio.Picker.sorter
---@param ... artio.Picker.sorter
---@return artio.Picker.sorter
function artio.mergesorters(strat, a, ...)
  local sorters = { a, ... } ---@type artio.Picker.sorter[]

  ---@generic T
  ---@param t T[]
  ---@param cmp fun(T): boolean
  ---@return integer?
  local function findi(t, cmp)
    for i = 1, #t do
      if t[i] and cmp(t[i]) then
        return i
      end
    end
  end

  return function(lst, input)
    local it = 0
    return vim.iter(sorters):fold({}, function(oldmatches, sorter)
      it = it + 1
      ---@type artio.Picker.match[]
      local newmatches = sorter(lst, input)

      return vim.iter(newmatches):fold(strat == "intersect" and {} or oldmatches, function(matches, newmatch)
        local oldmatchidx = findi(oldmatches, function(v)
          return v[1] == newmatch[1]
        end)

        if oldmatchidx then
          local oldmatch = oldmatches[oldmatchidx]
          local next = mergematches(oldmatch, newmatch)
          if strat == "intersect" then
            matches[#matches + 1] = next
          else
            matches[oldmatchidx] = next
          end
        elseif strat == "combine" or it == 1 then
          matches[#matches + 1] = newmatch
        end
        return matches
      end)
    end)
  end
end

---@type artio.Picker.sorter
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
---@param start_opts? artio.Picker.config
artio.select = function(items, opts, on_choice, start_opts)
  return artio.generic(
    items,
    vim.tbl_deep_extend("force", {
      prompt = opts.prompt,
      on_close = function(_, idx)
        return on_choice(items[idx], idx)
      end,
      format_item = opts.format_item and function(item)
        return opts.format_item(item)
      end or nil,
    }, start_opts or {})
  )
end

---@generic T
---@param items T[]
---@param props artio.Picker.config
artio.generic = function(items, props)
  return artio.pick(vim.tbl_deep_extend("force", {
    fn = artio.sorter,
    items = items,
  }, props))
end

---@param ... artio.Picker.config
artio.pick = function(...)
  local Picker = require("artio.picker")
  return Picker:new(...):open()
end

return artio
