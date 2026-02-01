local View = require("artio.view")

---@alias artio.Picker.item { id: integer, v: any, text: string, icon?: string, icon_hl?: string, hls?: artio.Picker.hl[] }
---@alias artio.Picker.match [integer, integer[], integer] [item, pos[], score]
---@alias artio.Picker.matches table<integer, artio.Picker.match> id: match
---@alias artio.Picker.sorter fun(lst: artio.Picker.item[], input: string): artio.Picker.matches
---@alias artio.Picker.hl [[integer, integer], string]
---@alias artio.Picker.action fun(self: artio.Picker)

---@class artio.Picker.config
---@field items artio.Picker.item[]|string[]
---@field fn artio.Picker.sorter
---@field on_close fun(text: string, idx: integer)
---@field get_items? fun(input: string): artio.Picker.item[]
---@field format_item? fun(item: any): string
---@field preview_item? fun(item: any): integer, fun(win: integer)
---@field get_icon? fun(item: artio.Picker.item): string, string
---@field hl_item? fun(item: artio.Picker.item): artio.Picker.hl[]
---@field on_quit? fun()
---@field live? boolean
---@field prompt? string
---@field defaulttext? string
---@field prompttext? string
---@field opts? artio.config.opts
---@field win? artio.config.win
---@field actions? table<string, artio.Picker.action>
---@field mappings? table<string, 'up'|'down'|'accept'|'cancel'|'togglepreview'|string>

---@class artio.Picker : artio.Picker.config
---@field co thread|nil
---@field input string
---@field liveinput? string
---@field idx integer 1-indexed
---@field matches artio.Picker.match[]
---@field marked table<integer, true|nil>
---@field live boolean
local Picker = {}
Picker.__index = Picker
Picker.active_picker = nil

---@param props artio.Picker.config
function Picker:new(props)
  vim.validate("Picker.items", props.items, "table")
  vim.validate("Picker:fn", props.fn, "function")
  vim.validate("Picker:on_close", props.on_close, "function")

  local t = vim.tbl_deep_extend("force", {
    closed = false,
    prompt = "",
    input = nil,
    liveinput = nil,
    idx = 0,
    items = {},
    matches = {},
    marked = {},
  }, require("artio.config").get(), props)

  if not t.prompttext then
    t.prompttext = t.opts.prompt_title and ("%s %s"):format(t.prompt, t.opts.promptprefix) or t.opts.promptprefix
  end

  t.live = vim.F.if_nil(t.live, t.get_items ~= nil)

  if t.live then
    t.input = ""
    t.liveinput = t.defaulttext or ""
  else
    t.input = t.defaulttext or ""
    t.liveinput = ""
  end

  Picker.getitems(t, "")

  return setmetatable(t, Picker)
end

local action_enum = {
  accept = 0,
  cancel = 1,
}

function Picker:open()
  if Picker.active_picker and Picker.active_picker ~= self then
    Picker.active_picker:close(true)
  end
  Picker.active_picker = self

  self.view = View:new(self)

  coroutine.wrap(function()
    self.view:open()

    self:initkeymaps()

    local co, ismain = coroutine.running()
    assert(not ismain, "must be called from a coroutine")
    self.co = co

    vim.api.nvim_exec_autocmds("User", { pattern = "ArtioEnter" })

    local result = coroutine.yield()

    self:close()

    while true do
      if result == action_enum.cancel or result ~= action_enum.accept then
        if self.on_quit then
          self.on_quit()
        end
        break
      end

      local current = self.matches[self.idx] and self.matches[self.idx][1]
      if not current then
        break
      end

      local item = self.items[current]
      if item then
        self.on_close(item.v, item.id)
      end

      break
    end

    vim.api.nvim_exec_autocmds("User", { pattern = "ArtioLeave" })
  end)()
end

function Picker:resume()
  if not self.closed then
    return
  end
  self.closed = false

  self:open()
end

---@param free? boolean
function Picker:close(free)
  if self.closed then
    return
  end

  if self.view then
    self.view:close()
  end

  self:delkeymaps()

  self.closed = true

  if free then
    self:free()
  end
end

function Picker:free()
  if self == nil then
    return
  end
  self.items = nil
  self.matches = nil
  self.marked = nil
  self = nil
  vim.schedule(function()
    collectgarbage("collect")
  end)
end

function Picker:initkeymaps()
  local ui2 = require("vim._core.ui2")

  ---@type vim.keymap.set.Opts
  local opts = { buffer = ui2.bufs.cmd }

  if self.actions then
    vim.iter(pairs(self.actions)):each(function(k, v)
      vim.keymap.set("i", ("<Plug>(artio-action-%s)"):format(k), v, opts)
    end)
  end
  if self.mappings then
    vim.iter(pairs(self.mappings)):each(function(k, v)
      vim.keymap.set("i", k, ("<Plug>(artio-action-%s)"):format(v), opts)
    end)
  end
end

function Picker:delkeymaps()
  local ui2 = require("vim._core.ui2")

  local keymaps = vim.api.nvim_buf_get_keymap(ui2.bufs.cmd, "i")

  vim.iter(ipairs(keymaps)):each(function(_, v)
    if v.lhs:match("^<Plug>(artio-action-") or (v.rhs and v.rhs:match("^<Plug>(artio-action-")) then
      vim.api.nvim_buf_del_keymap(ui2.bufs.cmd, "i", v.lhs)
    end
  end)
end

function Picker:accept()
  coroutine.resume(self.co, action_enum.accept)
end

function Picker:cancel()
  coroutine.resume(self.co, action_enum.cancel)
end

function Picker:fix()
  self.idx = math.max(self.idx, self.opts.preselect and 1 or 0)
  self.idx = math.min(self.idx, #self.matches)
end

local function item_is_structured(item)
  return type(item) == "table" and item.id and item.v and item.text
end

function Picker:getitems(input)
  if self.live then
    self.items = self.get_items and self.get_items(input) or self.items
  end

  if #self.items > 0 and not item_is_structured(self.items[1]) then
    self.items = vim
      .iter(ipairs(self.items))
      :map(function(i, v)
        local text
        if self.format_item and vim.is_callable(self.format_item) then
          text = self.format_item(v)
        end

        return {
          id = i,
          v = v,
          text = text or v,
        }
      end)
      :totable()
  end
end

---@param input? string
function Picker:getmatches(input)
  if not input then
    input = self.live and self.liveinput or self.input
  end
  self:getitems(input)

  -- if live, ignore sorting
  if self.live then
    self.matches = self:getallmatches()
    return
  end

  self.matches = vim.tbl_values(self.fn(self.items, input))
  table.sort(self.matches, function(a, b)
    return a[3] > b[3]
  end)
end

---@return artio.Picker.match[]
function Picker:getallmatches()
  return vim
    .iter(ipairs(self.items))
    :map(function(_, v)
      return { v.id, {}, 0 }
    end)
    :totable()
end

---@param idx integer
---@param yes? boolean
function Picker:mark(idx, yes)
  self.marked[idx] = yes == nil and true or yes
end

---@return integer[]
function Picker:getmarked()
  return vim
    .iter(pairs(self.marked))
    :map(function(k, v)
      return v and k or nil
    end)
    :totable()
end

---@param idx? integer index in items
---@return artio.Picker.item?
function Picker:getcurrent(idx)
  if not idx then
    local i = self.idx
    idx = self.matches[i] and self.matches[i][1]
  end
  if not idx then
    return
  end

  return self.items[idx]
end

function Picker:togglelive()
  -- check if live can be toggled
  if not self.get_items then
    return
  end

  -- reset fuzzy search when enabling live search
  if not self.live then
    self.input = ""
  end
  self.live = not self.live
end

return Picker
