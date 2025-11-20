local function lzrq(modname)
  return setmetatable({}, {
    __index = function(_, key)
      return require(modname)[key]
    end,
  })
end

local artio = lzrq("artio")
local config = lzrq("artio.config")

local builtins = {}

local findprg = "fd -H -p -t f --color=never"

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
    get_icon = config.get().opts.use_icons and function(item)
      return require("mini.icons").get("file", item.v)
    end or nil,
    preview_item = function(item)
      return vim.fn.bufadd(item)
    end,
  })
end

local function find_helptags()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "help"
  local tags = vim.api.nvim_buf_call(buf, function()
    return vim.fn.taglist(".*")
  end)
  vim.api.nvim_buf_delete(buf, { force = true })
  return vim.tbl_map(function(t)
    return t.name
  end, tags)
end

builtins.helptags = function()
  local lst = find_helptags()

  return artio.generic(lst, {
    prompt = "helptags",
    on_close = function(text, _)
      vim.schedule(function()
        vim.cmd.help(text)
      end)
    end,
  })
end

builtins.buffers = function()
  local lst = vim
    .iter(vim.api.nvim_list_bufs())
    :filter(function(bufnr)
      return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
    end)
    :totable()

  return artio.select(lst, {
    prompt = "buffers",
    format_item = function(bufnr)
      return vim.api.nvim_buf_get_name(bufnr)
    end,
  }, function(bufnr, _)
    vim.schedule(function()
      vim.cmd.buffer(bufnr)
    end)
  end, {
    get_icon = config.get().opts.use_icons and function(item)
      return require("mini.icons").get("file", vim.api.nvim_buf_get_name(item.v))
    end or nil,
    preview_item = function(item)
      return item
    end,
  })
end

return builtins
