local View = require("artio.view")

---@class artio.Picker.proto
---@field idx? integer 1-indexed
---@field fn? fun(input: string): [string, integer][]
---@field on_close? fun(text: string, idx: integer)
---@field opts? artio.config.opts
---@field win? artio.config.win
---@field prompt? string
---@field defaulttext? string
---@field prompttext? string

---@class artio.Picker : artio.Picker.proto
---@field idx integer
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
  }, require("artio.config").get(), props)

  t.prompttext = t.prompttext or ("%s %s"):format(t.prompt, t.opts.promptprefix)

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
        self:fix()
        view:hlselect()
        return ""
      elseif typed == "<up>" then
        self.idx = self.idx - 1
        self:fix()
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

    local current = self.items[self.idx]
    if not current then
      return
    end

    self.on_close(current[1], self.idx)
  end)()
end

function Picker:fix()
  self.idx = math.max(self.idx, self.opts.preselect and 1 or 0)
  self.idx = math.min(self.idx, self.win.height - 1, #self.items)
end

function Picker:getitems(input)
  self.items = self.fn(input)
  return self.items
end

return Picker
