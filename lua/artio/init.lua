local artio = {}

local function lzrq(modname)
  return setmetatable({}, {
    __index = function(_, key)
      return require(modname)[key]
    end,
  })
end

local Picker = lzrq("artio.picker")

local findprg = "fd -p -t f --color=never"

local function find_files(match)
  if not findprg then
    return {}
  end
  local farg = string.format("'%s'", match)
  local findcmd, n = findprg:gsub("%$%*", farg)
  if n == 0 then
    findcmd = findcmd .. " " .. farg
  end
  local fn = function(o)
    local src = o.stderr
    if o.code == 0 then
      src = o.stdout
    end
    src = src
    local lines = vim.split(src, "\n", { trimempty = true })
    return lines
  end
  return fn(vim
    .system({ vim.o.shell, "-c", findcmd }, {
      text = true,
    })
    :wait())
end

artio.files = function()
  return artio.pick({
    prompt = "files",
    fn = function(input)
      local lst = find_files(input)
      if not lst or #lst == 0 then
        return {}
      end

      local matches = vim.fn.matchfuzzypos(lst, input)
      return vim
        .iter(ipairs(matches[1]))
        :map(function(index, v)
          return { v, matches[2][index] }
        end)
        :totable()
    end,
    on_close = function(text, _)
      vim.schedule(function()
        vim.cmd.edit(text)
      end)
    end,
  })
end

artio.pick = function(...)
  return Picker:new(...):open()
end

return artio
