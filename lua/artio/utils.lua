local uv = vim.uv

local utils = {}

---@param path string
---@param ctx? vim.context.mods
function utils.edit(path, ctx)
  local f = function()
    vim.api.nvim_cmd({
      cmd = "edit",
      args = { path },
      magic = { file = false, bar = false },
    }, {})
  end

  if ctx then
    return vim._with(ctx, f)
  end

  return f()
end

local function parsechunks(chunks)
  local lines = {}

  for _, chunk in ipairs(chunks) do
    for _, line in ipairs(vim.split(chunk, "\n", { trimempty = true })) do
      table.insert(lines, line)
    end
  end

  return lines
end

---@param prg? string
---@param opts? table
---@return fun(arg?: string): string[]
function utils.make_cmd(prg, opts)
  ---@async
  ---@param arg? string
  ---@return string[]
  return function(arg)
    if not prg then
      return {}
    end
    local cmd, n = prg, nil
    if arg and #arg > 0 then
      arg = string.format("'%s'", arg)
      cmd, n = prg:gsub("%$%*", arg)
      if n == 0 then
        cmd = ("%s %s"):format(prg, arg)
      end
    end

    local chunks = {}

    local stdout = uv.new_pipe()

    local co = coroutine.running()
    assert(co, "utils.make_cmd needs to be run inside a coroutine")

    uv.spawn(
      vim.o.shell,
      vim.tbl_extend("keep", {
        stdio = { nil, stdout, nil },
        args = { vim.o.shellcmdflag, cmd },
      }, opts or {}),
      function(code, signal)
        if code == 0 then
          local lines = parsechunks(chunks)
          coroutine.resume(co, lines)
          return
        end
        coroutine.resume(co, {
          ("error while running shell cmd %s (%d)"):format(signal, code),
        })
      end
    )

    ---@diagnostic disable-next-line: param-type-mismatch
    uv.read_start(stdout, function(err, data)
      assert(not err, err)
      if data then
        table.insert(chunks, data)
      end
    end)

    return coroutine.yield()
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

function utils.hl_qfitem(item)
  local name_end = string.find(item.text, ":") - 1
  local lnum_end = string.find(item.text, ":", name_end + 2) - 1
  local col_end = string.find(item.text, ":", lnum_end + 2) - 1

  return {
    { { 0, name_end }, "Title" },
    { { name_end, name_end + 1 }, "NonText" },
    { { name_end + 1, lnum_end }, "Number" },
    { { lnum_end, lnum_end + 1 }, "NonText" },
    { { lnum_end + 1, col_end }, "Number" },
    { { col_end, col_end + 1 }, "NonText" },
  }
end

return utils
