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

local function grep(input)
  input = input or ""
  local grepcmd, n = vim.o.grepprg:gsub("%$%*", input)
  if n == 0 then
    grepcmd = grepcmd .. " " .. input
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
    .system({ vim.o.shell, "-c", grepcmd }, {
      text = true,
    })
    :wait())
end

builtins.grep = function()
  local ext = require("vim._extui.shared")

  return artio.pick({
    items = {},
    prompt = "grep",
    get_items = function(input)
      if input == "" then
        return {}
      end

      local lines = grep(input)

      vim.fn.setloclist(ext.wins.cmd, {}, " ", {
        title = "grep[" .. input .. "]",
        lines = lines,
        efm = vim.o.grepformat,
        nr = "$",
      })

      return vim
        .iter(ipairs(vim.fn.getloclist(ext.wins.cmd)))
        :map(function(i, locitem)
          return {
            id = i,
            v = { vim.fn.bufname(locitem.bufnr), locitem.lnum, locitem.col },
            text = locitem.text,
          }
        end)
        :totable()
    end,
    fn = artio.sorter,
    on_close = function(item, _)
      vim.schedule(function()
        vim.cmd.edit(item[1])
        vim.api.nvim_win_set_cursor(0, { item[2], item[3] })
      end)
    end,
    preview_item = function(item)
      return vim.fn.bufadd(item[1])
    end,
    get_icon = config.get().opts.use_icons and function(item)
      return require("mini.icons").get("file", item.v[1])
    end or nil,
  })
end

local function find_oldfiles()
  return vim
    .iter(vim.v.oldfiles)
    :filter(function(v)
      return vim.uv.fs_stat(v) --[[@as boolean]]
    end)
    :totable()
end

builtins.oldfiles = function()
  local lst = find_oldfiles()

  return artio.generic(lst, {
    prompt = "oldfiles",
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

builtins.buffergrep = function()
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local n = vim.api.nvim_buf_line_count(buf)
  local lst = {} ---@type integer[]
  for i = 1, n do
    lst[#lst + 1] = i
  end

  local pad = #tostring(lst[#lst])

  return artio.generic(lst, {
    prompt = "buffergrep",
    on_close = function(row, _)
      vim.schedule(function()
        vim.api.nvim_win_set_cursor(win, { row, 0 })
      end)
    end,
    format_item = function(row)
      return vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1]
    end,
    preview_item = function(row)
      return buf,
        function(w)
          vim.api.nvim_set_option_value("cursorline", true, { scope = "local", win = w })
          vim.api.nvim_win_set_cursor(w, { row, 0 })
        end
    end,
    get_icon = function(row)
      local v = tostring(row.v)
      return ("%s%s"):format((" "):rep(pad - #v), v)
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

local function find_buffers()
  return vim
    .iter(vim.api.nvim_list_bufs())
    :filter(function(bufnr)
      return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
    end)
    :totable()
end

builtins.buffers = function()
  local lst = find_buffers()

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

---@param currentfile string
---@param item string
---@return integer score
local function matchproximity(currentfile, item)
  item = vim.fs.abspath(item)

  return vim.iter(ipairs(vim.split(item, "/", { trimempty = true }))):fold(0, function(score, i, part)
    if part == currentfile[i] then
      return score + 50
    end
    return score
  end)
end

--- uses the regular files picker as a base
--- - boosts items in the bufferlist
--- - proportionally boosts items that match closely to the current file in proximity within the filesystem
builtins.smart = function()
  local currentfile = vim.api.nvim_buf_get_name(0)
  currentfile = vim.fs.abspath(currentfile)

  local lst = find_files()

  local pwd = vim.fn.getcwd()
  local recentlst = vim
    .iter(find_buffers())
    :map(function(buf)
      local v = vim.api.nvim_buf_get_name(buf)
      return vim.fs.relpath(pwd, v) or v
    end)
    :totable()

  return artio.pick({
    prompt = "smart",
    items = vim.tbl_keys(vim.iter({ lst, recentlst }):fold({}, function(items, l)
      for i = 1, #l do
        items[l[i]] = true
      end
      return items
    end)),
    fn = artio.mergesorters("base", artio.sorter, function(l, _)
      return vim
        .iter(l)
        :map(function(v)
          if not vim.tbl_contains(recentlst, v.text) then
            return
          end
          return { v.id, {}, 100 }
        end)
        :totable()
    end, function(l, _)
      return vim
        .iter(l)
        :map(function(v)
          return { v.id, {}, matchproximity(currentfile, v.text) }
        end)
        :totable()
    end),
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

builtins.colorschemes = function()
  local files = vim.api.nvim_get_runtime_file("colors/*.{vim,lua}", true)
  local lst = vim.tbl_map(function(f)
    return vim.fs.basename(f):gsub("%.[^.]+$", "")
  end, files)

  return artio.generic(lst, {
    prompt = "colorschemes",
    on_close = function(text, _)
      vim.schedule(function()
        vim.cmd.colorscheme(text)
      end)
    end,
  })
end

builtins.highlights = function()
  local hlout = vim.split(vim.api.nvim_exec2([[ highlight ]], { output = true }).output, "\n", { trimempty = true })

  local maxw = 0

  local hls = vim
    .iter(hlout)
    :map(function(hl)
      local sp = string.find(hl, "%s", 1)
      maxw = sp > maxw and sp or maxw
      return { hl:sub(1, sp - 1), hl }
    end)
    :fold({}, function(t, hl)
      local pad = math.max(0, math.min(20, maxw) - #hl[1] + 1)
      t[hl[1]] = string.gsub(hl[2], "%s+", (" "):rep(pad), 1)
      return t
    end)

  return artio.generic(vim.tbl_keys(hls), {
    prompt = "highlights",
    on_close = function(line, _)
      vim.schedule(function()
        vim.print(line)
      end)
    end,
    format_item = function(hlname)
      return hls[hlname]
    end,
    hl_item = function(hlname)
      return {
        { { 0, #hlname.v }, hlname.v },
      }
    end,
  })
end

return builtins
