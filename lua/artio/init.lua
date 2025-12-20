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

  return function(lst, input)
    return vim.iter(ipairs(sorters)):fold({}, function(oldmatches, it, sorter)
      ---@type artio.Picker.matches
      local newmatches = sorter(lst, input)

      return vim
        .iter(pairs(newmatches))
        :fold(strat == "intersect" and {} or oldmatches, function(matches, idx, newmatch)
          local oldmatch = oldmatches[idx]
          if oldmatch then
            local next = mergematches(oldmatch, newmatch)
            matches[idx] = next
          elseif strat == "combine" or it == 1 then
            matches[idx] = newmatch
          end
          return matches
        end)
    end)
  end
end

---@type artio.Picker.sorter
artio.fuzzy_sorter = function(lst, input)
  if not lst or #lst == 0 then
    return {}
  end

  if not input or #input == 0 then
    return vim.iter(lst):fold({}, function(acc, v)
      acc[v.id] = { v.id, {}, 0 }
      return acc
    end)
  end

  local matches = vim.fn.matchfuzzypos(lst, input, { key = "text" })

  local items = {}
  for i = 1, #matches[1] do
    items[matches[1][i].id] = { matches[1][i].id, matches[2][i], matches[3][i] }
  end
  return items
end

---@type artio.Picker.sorter
artio.pattern_sorter = function(lst, input)
  local match = string.match(input, "^/[^/]*/")
  local pattern = match and string.match(match, "^/([^/]*)/$")

  return vim.iter(lst):fold({}, function(acc, v)
    if pattern and not string.match(v.text, pattern) then
      return acc
    end

    acc[v.id] = { v.id, {}, 0 }
    return acc
  end)
end

---@type artio.Picker.sorter
artio.sorter = artio.mergesorters("intersect", artio.pattern_sorter, function(lst, input)
  input = string.gsub(input, "^/[^/]*/", "")
  return artio.fuzzy_sorter(lst, input)
end)

---@generic T
---@param items T[] Arbitrary items
---@param opts vim.ui.select.Opts Additional options
---@param on_choice fun(item: T|nil, idx: integer|nil)
---@param start_opts? artio.Picker.config
artio.select = function(items, opts, on_choice, start_opts)
  return artio.generic(
    items,
    vim.tbl_deep_extend(
      "force",
      {
        on_close = function(_, idx)
          return on_choice(items[idx], idx)
        end,
      },
      opts or {}, -- opts.prompt, opts.format_item
      start_opts or {}
    )
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

---@param fn artio.Picker.action
---@param scheduled_fn? artio.Picker.action
artio.wrap = function(fn, scheduled_fn)
  return function()
    local Picker = require("artio.picker")
    local current = Picker.active_picker
    if not current or current.closed then
      return
    end

    -- whether to accept key inputs
    if coroutine.status(current.co) ~= "suspended" then
      return
    end

    pcall(fn, current)

    if scheduled_fn == nil then
      return
    end
    vim.schedule(function()
      pcall(scheduled_fn, current)
    end)
  end
end

return artio
