---@class artio.Actions.proto
---@field actions table<string, function>

---@class artio.Actions : artio.Actions.proto
---@field picker artio.Picker
---@field co thread
---@field key_ns integer
local Actions = {}
Actions.__index = Actions

---@param props artio.Actions.proto
function Actions:new(props)
  return setmetatable(
    vim.tbl_extend("force", {
      actions = {},
    }, props),
    Actions
  )
end

function Actions:init(picker)
  self.picker = picker

  local co, ismain = coroutine.running()
  assert(not ismain, "must be called from a coroutine")
  self.co = co

  self.key_ns = vim.on_key(function(key, typed)
    return self:on_key(key, typed)
  end)

  local result = coroutine.yield()

  vim.on_key(nil, self.key_ns)

  return result
end

function Actions:on_key(_, typed)
  if self.picker.view.closed then
    coroutine.resume(self.co)
    return
  end

  typed = string.lower(vim.fn.keytrans(typed))

  local _, actionname = vim.iter(pairs(self.picker.mappings)):find(function(key, _)
    return key == typed
  end)

  local action = self.actions[actionname]
  if action and vim.is_callable(action) then
    action(self.picker, self.co)
    return ""
  end
end

return Actions
