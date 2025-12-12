local utils = {}

local function cmd_callback(o)
  local src = o.stderr
  if o.code == 0 then
    src = o.stdout
  end
  src = src
  local lines = vim.split(src, "\n", { trimempty = true })
  return lines
end

---@param prg? string
---@return fun(arg?: string): string[]
function utils.make_cmd(prg)
  return function(arg)
    if not prg then
      return {}
    end
    arg = string.format("'%s'", arg or "")
    local cmd, n = prg:gsub("%$%*", arg)
    if n == 0 then
      cmd = ("%s %s"):format(prg, arg)
    end
    return cmd_callback(vim
      .system({ vim.o.shell, "-c", cmd }, {
        text = true,
      })
      :wait())
  end
end

---@param fn fun(item: artio.Picker.item): vim.quickfix.entry
---@return artio.Picker.action
function utils.make_setqflist(fn)
  return require("artio").wrap(function(self)
    vim.fn.setqflist(vim
      .iter(ipairs(self.matches))
      :map(function(_, match)
        local item = self.items[match[1]]
        local qfitem = fn(item)
        return qfitem
      end)
      :totable())
    self:cancel()
  end, function(_)
    vim.cmd.copen()
  end)
end

---@param fn fun(item: artio.Picker.item): vim.quickfix.entry
---@return artio.Picker.action
function utils.make_setqflistmark(fn)
  return require("artio").wrap(function(self)
    vim.fn.setqflist(vim
      .iter(ipairs(self:getmarked()))
      :map(function(_, id)
        local item = self.items[id]
        local qfitem = fn(item)
        return qfitem
      end)
      :totable())
    self:cancel()
  end, function(_)
    vim.cmd.copen()
  end)
end

---@param fn fun(item: artio.Picker.item): vim.quickfix.entry
---@return table<string, artio.Picker.action>
function utils.make_setqflistactions(fn)
  return {
    setqflist = utils.make_setqflist(fn),
    setqflistmark = utils.make_setqflistmark(fn),
  }
end

---@param fn fun(item: artio.Picker.item): integer
---@return table<string, artio.Picker.action>
function utils.make_fileactions(fn)
  return {
    split = require("artio").wrap(function(self)
      self:cancel()
    end, function(self)
      local item = self:getcurrent()
      if not item then
        return
      end
      local buf = fn(item)
      vim.api.nvim_open_win(buf, true, { win = -1, vertical = false })
    end),
    vsplit = require("artio").wrap(function(self)
      self:cancel()
    end, function(self)
      local item = self:getcurrent()
      if not item then
        return
      end
      local buf = fn(item)
      vim.api.nvim_open_win(buf, true, { win = -1, vertical = true })
    end),
    tabnew = require("artio").wrap(function(self)
      self:cancel()
    end, function(self)
      local item = self:getcurrent()
      if not item then
        return
      end
      local buf = fn(item)
      vim.api.nvim_cmd({
        cmd = "split",
        args = { ("+%dbuf"):format(buf) },
        ---@diagnostic disable-next-line: missing-fields
        mods = {
          tab = 1,
          silent = true,
        },
      }, {
        output = false,
      })
    end),
  }
end

return utils
