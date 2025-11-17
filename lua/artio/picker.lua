local View = require("artio.view")

---@alias artio.Picker.item { id: integer, v: string, text: string }
---@alias artio.Picker.match [integer, integer[], integer] [item, pos[], score]

---@class artio.Picker.proto
---@field items? artio.Picker.item[]
---@field fn? fun(lst: artio.Picker.item[], input: string): artio.Picker.match[]
---@field on_close? fun(text: string, idx: integer)
---@field format_item? fun(item: string): string
---@field opts? artio.config.opts
---@field win? artio.config.win
---@field prompt? string
---@field defaulttext? string
---@field prompttext? string

---@class artio.Picker : artio.Picker.proto
---@field idx integer 1-indexed
---@field matches artio.Picker.match[]
local Picker = {}
Picker.__index = Picker

---@param props artio.Picker.proto
function Picker:new(props)
  vim.validate("fn", props.fn, "function")
  vim.validate("on_close", props.on_close, "function")

  local t = vim.tbl_deep_extend("force", {
    prompt = "",
    idx = 1,
    items = {},
    matches = {},
  }, require("artio.config").get(), props)

  t.prompttext = t.prompttext or ("%s %s"):format(t.prompt, t.opts.promptprefix)

  t.items = vim
    .iter(ipairs(t.items))
    :map(function(i, v)
      local text
      if t.format_item and vim.is_callable(t.format_item) then
        text = t.format_item(v)
      end

      return {
        id = i,
        v = v,
        text = text or v,
      }
    end)
    :totable()

  return setmetatable(t, Picker)
end

function Picker:open()
  if not self.fn or not self.on_close then
    vim.notify("Picker must have `fn` and `on_close`", vim.log.levels.ERROR)
    return
  end

  local accepted
  local cancelled

  local view = View:new()
  view.picker = self

  coroutine.wrap(function()
    view:open()

    local co, ismain = coroutine.running()
    assert(not ismain, "must be called from a coroutine")

    local key_ns = vim.on_key(function(_, typed)
      if view.closed then
        coroutine.resume(co)
        return
      end

      typed = string.lower(vim.fn.keytrans(typed))
      if typed == "<down>" then
        self.idx = self.idx + 1
        view:showmatches()
        view:hlselect()
        return ""
      elseif typed == "<up>" then
        self.idx = self.idx - 1
        view:showmatches()
        view:hlselect()
        return ""
      elseif typed == "<cr>" then
        accepted = true
        coroutine.resume(co)
        return ""
      elseif typed == "<esc>" then
        cancelled = true
        coroutine.resume(co)
        return ""
      end
    end)

    coroutine.yield()

    vim.on_key(nil, key_ns)
    view:close()

    if cancelled or not accepted then
      return
    end

    local current = self.matches[self.idx][1]
    if not current then
      return
    end

    local item = self.items[current]

    self.on_close(item.v, item.id)
  end)()
end

function Picker:fix()
  self.idx = math.max(self.idx, self.opts.preselect and 1 or 0)
  self.idx = math.min(self.idx, #self.matches)
end

function Picker:getmatches(input)
  self.matches = self.fn(self.items, input)
end

return Picker
