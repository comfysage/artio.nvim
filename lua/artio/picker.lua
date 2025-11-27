local Actions = require("artio.actions")
local View = require("artio.view")

---@alias artio.Picker.item { id: integer, v: any, text: string, icon?: string, icon_hl?: string, hls?: artio.Picker.hl[] }
---@alias artio.Picker.match [integer, integer[], integer] [item, pos[], score]
---@alias artio.Picker.sorter fun(lst: artio.Picker.item[], input: string): artio.Picker.match[]
---@alias artio.Picker.hl [[integer, integer], string]

---@class artio.Picker.config : artio.config
---@field items artio.Picker.item[]
---@field fn artio.Picker.sorter
---@field on_close fun(text: string, idx: integer)
---@field format_item? fun(item: any): string
---@field preview_item? fun(item: any): integer, fun(win: integer)
---@field get_icon? fun(item: artio.Picker.item): string, string
---@field hl_item? fun(item: artio.Picker.item): artio.Picker.hl[]
---@field actions? artio.Actions
---@field prompt? string
---@field defaulttext? string
---@field prompttext? string

---@class artio.Picker : artio.Picker.config
---@field idx integer 1-indexed
---@field matches artio.Picker.match[]
local Picker = {}
Picker.__index = Picker

local action_enum = {
  accept = 0,
  cancel = 1,
}

---@type table<string, fun(self: artio.Picker, co: thread)>
local default_actions = {
  down = function(self, co)
    self.idx = self.idx + 1
    self.view:showmatches()
    self.view:hlselect()
  end,
  up = function(self, co)
    self.idx = self.idx - 1
    self.view:showmatches()
    self.view:hlselect()
  end,
  accept = function(self, co)
    coroutine.resume(co, action_enum.accept)
  end,
  cancel = function(self, co)
    coroutine.resume(co, action_enum.cancel)
    self.view:togglepreview()
  end,
  togglepreview = function(self, co)
    self.view:togglepreview()
  end,
}

---@param props artio.Picker.config
function Picker:new(props)
  vim.validate("Picker.items", props.items, "table")
  vim.validate("Picker:fn", props.fn, "function")
  vim.validate("Picker:on_close", props.on_close, "function")

  local t = vim.tbl_deep_extend("force", {
    closed = false,
    prompt = "",
    idx = 0,
    items = {},
    matches = {},
  }, require("artio.config").get(), props)

  if not t.prompttext then
    t.prompttext = t.opts.prompt_title and ("%s %s"):format(t.prompt, t.opts.promptprefix) or t.opts.promptprefix
  end

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

  t.actions = t.actions or Actions:new({
    actions = default_actions,
  })

  return setmetatable(t, Picker)
end

function Picker:open()
  self.view = View:new(self)

  coroutine.wrap(function()
    self.view:open()

    local result = self.actions:init(self)

    self:close()

    if result == action_enum.cancel or result ~= action_enum.accept then
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

function Picker:close()
  if self.closed then
    return
  end

  if self.view then
    self.view:close()
  end

  self.closed = true
end

function Picker:fix()
  self.idx = math.max(self.idx, self.opts.preselect and 1 or 0)
  self.idx = math.min(self.idx, #self.matches)
end

function Picker:getmatches(input)
  self.matches = self.fn(self.items, input)
  table.sort(self.matches, function(a, b)
    return a[3] > b[3]
  end)
end

return Picker
