local function lzrq(modname)
  return setmetatable({}, {
    __index = function(_, key)
      return require(modname)[key]
    end,
  })
end

local artio = lzrq("artio")
local config = lzrq("artio.config")
local utils = lzrq("artio.utils")

local function extend(t1, ...)
  return vim.tbl_deep_extend("force", t1, ...)
end

local builtins = {}

builtins.builtins = function(props)
  props = props or {}

  return artio.generic(
    vim.tbl_keys(builtins),
    extend({
      prompt = "builtins",
      on_close = function(fname, _)
        if not builtins[fname] then
          return
        end

        artio.schedule(builtins[fname])
      end,
    }, props)
  )
end

local findprg = vim.fn.executable("fd") == 1 and "fd -H -p -a -t f --color=never --"
  or "find . -type f -iregex '.*$*.*'"

---@class artio.picker.files.Props : artio.Picker.config
---@field findprg? string

---@param props? artio.picker.files.Props
builtins.files = function(props)
  props = props or {}
  props.findprg = props.findprg or findprg

  local base_dir = vim.fn.getcwd(0)
  local lst = utils.make_cmd(props.findprg, {
    cwd = base_dir,
  })()

  return artio.generic(
    lst,
    extend({
      prompt = "files",
      on_close = function(text, _)
        vim.schedule(function()
          vim.cmd.edit(text)
        end)
      end,
      format_item = function(item)
        return vim.fs.relpath(base_dir, item) or item
      end,
      get_icon = config.get().opts.use_icons and function(item)
        return require("mini.icons").get("file", item.v)
      end or nil,
      preview_item = function(item)
        return vim.fn.bufadd(item)
      end,
      actions = extend(
        {},
        utils.make_setqflistactions(function(item)
          return { filename = item.v }
        end),
        utils.make_fileactions(function(item)
          return vim.fn.bufnr(item.v, true)
        end)
      ),
    }, props)
  )
end

---@class artio.picker.grep.Props : artio.Picker.config
---@field grepprg? string

---@param props? artio.picker.grep.Props
builtins.grep = function(props)
  props = props or {}
  props.grepprg = props.grepprg or vim.o.grepprg

  local base_dir = vim.fn.getcwd(0)
  local ui2 = require("vim._core.ui2")
  local grepcmd = utils.make_cmd(props.grepprg, {
    cwd = base_dir,
  })

  return artio.pick(extend({
    items = {},
    prompt = "grep",
    get_items = function(input)
      if input == "" then
        return {}
      end

      local lines = grepcmd(input)

      vim.fn.setloclist(ui2.wins.cmd, {}, " ", {
        title = "grep[" .. input .. "]",
        lines = lines,
        efm = vim.o.grepformat,
        nr = "$",
      })

      return vim
        .iter(ipairs(vim.fn.getloclist(ui2.wins.cmd)))
        :map(function(i, locitem)
          local name = vim.fs.abspath(vim.fn.bufname(locitem.bufnr))
          return {
            id = i,
            v = { name, locitem.lnum, locitem.col },
            text = ("%s:%d:%d:%s"):format(vim.fs.relpath(base_dir, name), locitem.lnum, locitem.col, locitem.text),
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
      return vim.fn.bufadd(item[1]),
        function(w)
          vim.api.nvim_set_option_value("cursorline", true, { scope = "local", win = w })
          vim.api.nvim_win_set_cursor(w, { item[2], 0 })
        end
    end,
    get_icon = config.get().opts.use_icons and function(item)
      return require("mini.icons").get("file", item.v[1])
    end or nil,
    hl_item = function(item)
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
    end,
    actions = extend(
      {},
      utils.make_setqflistactions(function(item)
        return { filename = item.v[1], lnum = item.v[2], col = item.v[3], text = item.text }
      end)
    ),
  }, props))
end

local function find_oldfiles()
  return vim
    .iter(vim.v.oldfiles)
    :filter(function(v)
      return vim.uv.fs_stat(v) --[[@as boolean]]
    end)
    :totable()
end

builtins.oldfiles = function(props)
  props = props or {}
  local lst = find_oldfiles()

  return artio.generic(
    lst,
    extend({
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
      actions = extend(
        {},
        utils.make_setqflistactions(function(item)
          return { filename = item.v }
        end)
      ),
    }, props)
  )
end

builtins.buffergrep = function(props)
  props = props or {}
  local win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local n = vim.api.nvim_buf_line_count(buf)
  local lst = {} ---@type integer[]
  for i = 1, n do
    lst[#lst + 1] = i
  end

  local pad = #tostring(lst[#lst])

  return artio.generic(
    lst,
    extend({
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
      actions = extend(
        {},
        utils.make_setqflistactions(function(item)
          return { filename = vim.api.nvim_buf_get_name(buf), lnum = item.v }
        end)
      ),
    }, props)
  )
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

builtins.helptags = function(props)
  props = props or {}
  local lst = find_helptags()

  return artio.generic(
    lst,
    extend({
      prompt = "helptags",
      on_close = function(text, _)
        vim.schedule(function()
          vim.cmd.help(text)
        end)
      end,
    }, props)
  )
end

local function find_buffers()
  return vim
    .iter(vim.api.nvim_list_bufs())
    :filter(function(bufnr)
      return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
    end)
    :totable()
end

builtins.buffers = function(props)
  props = props or {}
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
  }, props)
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
builtins.smart = function(props)
  props = props or {}
  local currentfile = vim.api.nvim_buf_get_name(0)
  currentfile = vim.fs.abspath(currentfile)

  props.findprg = props.findprg or findprg
  local base_dir = vim.fn.getcwd(0)
  local lst = utils.make_cmd(props.findprg, {
    cwd = base_dir,
  })()

  local pwd = vim.fn.getcwd()
  local recentlst = vim
    .iter(find_buffers())
    :map(function(buf)
      local v = vim.api.nvim_buf_get_name(buf)
      return vim.fs.relpath(pwd, v) or v
    end)
    :totable()

  return artio.pick(extend({
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
    format_item = function(item)
      return vim.fs.relpath(base_dir, item) or item
    end,
    get_icon = config.get().opts.use_icons and function(item)
      return require("mini.icons").get("file", item.v)
    end or nil,
    preview_item = function(item)
      return vim.fn.bufadd(item)
    end,
    actions = extend(
      {},
      utils.make_setqflistactions(function(item)
        return { filename = item.v }
      end)
    ),
  }, props))
end

builtins.colorschemes = function(props)
  props = props or {}
  local files = vim.api.nvim_get_runtime_file("colors/*.{vim,lua}", true)
  local lst = vim.tbl_map(function(f)
    return vim.fs.basename(f):gsub("%.[^.]+$", "")
  end, files)

  return artio.generic(
    lst,
    extend({
      prompt = "colorschemes",
      on_close = function(text, _)
        vim.schedule(function()
          vim.cmd.colorscheme(text)
        end)
      end,
    }, props)
  )
end

builtins.highlights = function(props)
  props = props or {}
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
      local pad = math.max(1, math.min(20, maxw) - #hl[1] + 1)
      t[hl[1]] = string.gsub(hl[2], "%s+", (" "):rep(pad), 1)
      return t
    end)

  return artio.generic(
    vim.tbl_keys(hls),
    extend({
      prompt = "highlights",
      on_close = function(hlname, _)
        vim.schedule(function()
          vim.cmd(("verbose hi %s"):format(hlname))
        end)
      end,
      format_item = function(hlname)
        return hls[hlname]
      end,
      hl_item = function(hlname)
        local x_start, x_end = string.find(hlname.text, "%sxxx")

        return {
          { { 0, #hlname.v }, hlname.v },
          { { x_start, x_end }, hlname.v },
        }
      end,
    }, props)
  )
end

---@private
---@param severity vim.diagnostic.Severity
---@return string
local function get_severity_hl(severity)
  if severity == vim.diagnostic.severity.ERROR then
    return "DiagnosticError"
  elseif severity == vim.diagnostic.severity.WARN then
    return "DiagnosticWarn"
  elseif severity == vim.diagnostic.severity.INFO then
    return "DiagnosticInfo"
  elseif severity == vim.diagnostic.severity.HINT then
    return "DiagnosticHint"
  end
  return ""
end

---@class artio.picker.diagnostics.Props : artio.Picker.config
---@field buf? integer defaults to workspace

---@param props? artio.picker.diagnostics.Props
builtins.diagnostics = function(props)
  props = props or {}
  local lst = vim.diagnostic.get(props.buf)

  return artio.generic(
    lst,
    extend({
      prompt = "diagnostics",
      format_item = function(item)
        local text = item.message
        if item.code then
          text = ("%s [%s]"):format(text, item.code)
        end
        return ("%d:%d :: %s"):format(item.end_lnum, item.end_col, text)
      end,
      on_close = function(item, _)
        vim.schedule(function()
          local win = vim.fn.bufwinid(item.bufnr)
          if win < 0 then
            vim.api.nvim_win_set_buf(0, item.bufnr)
            win = 0
          end
          vim.api.nvim_set_current_win(win)
          vim.api.nvim_win_set_cursor(win, { item.end_lnum + 1, item.end_col })
        end)
      end,
      hl_item = function(item)
        return {
          { { 0, #item.text }, get_severity_hl(item.v.severity) },
        }
      end,
      get_icon = function(item)
        if item.v.severity == vim.diagnostic.severity.ERROR then
          return "E", get_severity_hl(item.v.severity)
        elseif item.v.severity == vim.diagnostic.severity.WARN then
          return "W", get_severity_hl(item.v.severity)
        elseif item.v.severity == vim.diagnostic.severity.INFO then
          return "I", get_severity_hl(item.v.severity)
        elseif item.v.severity == vim.diagnostic.severity.HINT then
          return "H", get_severity_hl(item.v.severity)
        end
        return " "
      end,
    }, props)
  )
end

---@param props? artio.picker.diagnostics.Props
builtins.diagnostics_buffer = function(props)
  props = props or {}
  props.buf = props.buf or vim.api.nvim_get_current_buf()
  return builtins.diagnostics(props)
end

---@class artio.picker.keymaps.Props : artio.Picker.config
---@field modes? string[] defaults to all

---@param props? artio.picker.keymaps.Props
builtins.keymaps = function(props)
  props = props or {}
  props.modes = props.modes or { "n", "i", "c", "v", "x", "s", "o", "t", "l" }

  ---@type vim.api.keyset.get_keymap[]
  local lst = vim.iter(props.modes):fold({}, function(keymaps, mode)
    vim.iter(vim.api.nvim_get_keymap(mode)):each(function(km)
      keymaps[#keymaps + 1] = km
    end)
    return keymaps
  end)

  return artio.generic(
    lst,
    extend({
      prompt = "keymaps",
      format_item = function(km)
        return ("%s %s %s | %s"):format(km.mode, km.lhs, km.rhs, km.desc)
      end,
      ---@param km vim.api.keyset.get_keymap
      on_close = function(km, _)
        vim.schedule(function()
          local out = vim.api.nvim_cmd({
            cmd = ("%smap"):format(km.mode),
            args = { km.lhs },
          }, {
            output = true,
          })
          vim.print(out)
        end)
      end,
    }, props)
  )
end

return builtins
