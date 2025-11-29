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

function utils.make_setqflist(fn)
  return function(self, co)
    vim.fn.setqflist(vim
      .iter(ipairs(self.matches))
      :map(function(_, match)
        local item = self.items[match[1]]
        local qfitem = fn(item)
        return qfitem
      end)
      :totable())
    vim.schedule(function()
      vim.cmd.copen()
    end)
    coroutine.resume(co, 1)
  end
end

return utils
