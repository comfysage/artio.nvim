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

---@param a artio.Picker.sorter
---@param ... artio.Picker.sorter
---@return artio.Picker.sorter
function artio.mergesorters(a, ...)
  local sorters = { ... } ---@type artio.Picker.sorter[]

  return function(lst, input)
    local basematches = a(lst, input)

    return vim.iter(sorters):fold(basematches, function(oldmatches, sorter)
      ---@type artio.Picker.match[]
      local newmatches = sorter(lst, input)

      return vim.iter(newmatches):fold(oldmatches, function(matches, newmatch)
        local oldmatchidx
        for i = 1, #matches do
          if lst[matches[i][1]] == lst[newmatch[1]] then
            oldmatchidx = i
            break
          end
        end

        if oldmatchidx then
          local oldmatch = matches[oldmatchidx]
          matches[oldmatchidx] = { oldmatch[1], mergehl(oldmatch[2], newmatch[2]), oldmatch[3] + newmatch[3] }
        else
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
---@param start_opts? artio.Picker.proto
artio.select = function(items, opts, on_choice, start_opts)
  return artio.generic(items, vim.tbl_deep_extend("force", {
    prompt = opts.prompt,
    on_close = function(_, idx)
      return on_choice(items[idx], idx)
    end,
    format_item = opts.format_item and function(item)
      return opts.format_item(item)
    end or nil,
  }, start_opts or {}))
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
  if artio.active_picker then
    artio.active_picker:close()
  end
  artio.active_picker = Picker
  return Picker:new(...):open()
end

return artio
