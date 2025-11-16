local function lzrq(modname)
  return setmetatable({}, {
    __index = function(_, key)
      return require(modname)[key]
    end,
  })
end

local artio = lzrq("artio")

local builtins = {}

local findprg = "fd -p -t f --color=never"

local function find_files(match)
  if not findprg then
    return {}
  end
  local farg = string.format("'%s'", match or "")
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

builtins.files = function()
  local lst = find_files()

  return artio.generic(lst, {
    prompt = "files",
    on_close = function(text, _)
      vim.schedule(function()
        vim.cmd.edit(text)
      end)
    end,
  })
end

return builtins
