local cmdline = require("vim._extui.cmdline")
local ext = require("vim._extui.shared")

local prompt_hl_id = vim.api.nvim_get_hl_id_by_name("ArtioPrompt")

--- Set the 'cmdheight' and cmdline window height. Reposition message windows.
---
---@param win integer Cmdline window in the current tabpage.
---@param hide boolean Whether to hide or show the window.
---@param height integer (Text)height of the cmdline window.
local function win_config(win, hide, height)
  if ext.cmdheight == 0 and vim.api.nvim_win_get_config(win).hide ~= hide then
    vim.api.nvim_win_set_config(win, { hide = hide, height = not hide and height or nil })
  elseif vim.api.nvim_win_get_height(win) ~= height then
    vim.api.nvim_win_set_height(win, height)
  end
  if vim.o.cmdheight ~= height then
    -- Avoid moving the cursor with 'splitkeep' = "screen", and altering the user
    -- configured value with noautocmd.
    vim._with({ noautocmd = true, o = { splitkeep = "screen" } }, function()
      vim.o.cmdheight = height
    end)
    ext.msg.set_pos()
  end
end

---@class artio.View
---@field picker artio.Picker
---@field closed boolean
---@field win artio.View.win
---@field preview_win integer
local View = {}
View.__index = View

---@param picker artio.Picker
function View:new(picker)
  return setmetatable({
    picker = picker,
    closed = false,
    win = {
      height = 0,
    },
  }, View)
end

---@class artio.View.win
---@field height integer

local prompthl_id = -1

local cmdbuff = "" ---@type string Stored cmdline used to calculate translation offset.
local promptlen = 0 -- Current length of the last line in the prompt.
local promptidx = 0
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@param content CmdContent
---@param prompt string
function View:setprompttext(content, prompt)
  local lines = {} ---@type string[]
  for line in (prompt .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = vim.fn.strtrans(line)
  end

  local promptstr = lines[#lines]
  promptlen = #lines[#lines]

  cmdbuff = ""
  for _, chunk in ipairs(content) do
    cmdbuff = cmdbuff .. chunk[2]
  end
  lines[#lines] = ("%s%s"):format(promptstr, vim.fn.strtrans(cmdbuff))
  self:setlines(promptidx, promptidx + 1, lines)
  vim.fn.prompt_setprompt(ext.bufs.cmd, promptstr)
  vim.schedule(function()
    local ok, result = pcall(vim.api.nvim_buf_set_mark, ext.bufs.cmd, ":", promptidx + 1, 0, {})
    if not ok then
      vim.notify(("Failed to set mark %d:%d\n\t%s"):format(promptidx, promptlen, result), vim.log.levels.ERROR)
      return
    end
  end)
end

--- Set the cmdline buffer text and cursor position.
---
---@param content CmdContent
---@param pos? integer
---@param firstc string
---@param prompt string
---@param indent integer
---@param level integer
---@param hl_id integer
function View:show(content, pos, firstc, prompt, indent, level, hl_id)
  cmdline.level, cmdline.indent, cmdline.prompt = level, indent, cmdline.prompt or #prompt > 0
  if cmdline.highlighter and cmdline.highlighter.active then
    cmdline.highlighter.active[ext.bufs.cmd] = nil
  end
  if ext.msg.cmd.msg_row ~= -1 then
    ext.msg.msg_clear()
  end
  ext.msg.virt.last = { {}, {}, {}, {} }

  self:clear()

  local cmd_text = ""
  for _, chunk in ipairs(content) do
    cmd_text = cmd_text .. chunk[2]
  end

  self.picker:getmatches(cmd_text)
  self:showmatches()

  self:promptpos()
  self:setprompttext(content, ("%s%s%s"):format(firstc, prompt, (" "):rep(indent)))
  self:updatecursor(pos)

  local height = math.max(1, vim.api.nvim_win_text_height(ext.wins.cmd, {}).all)
  height = math.min(height, self.win.height)
  win_config(ext.wins.cmd, false, height)

  prompthl_id = hl_id
  self:drawprompt()
  self:hlselect()
end

function View:saveview()
  self.save = vim.fn.winsaveview()
  self.prevwin = vim.api.nvim_get_current_win()
end

function View:restoreview()
  vim.api.nvim_set_current_win(self.prevwin)
  vim.fn.winrestview(self.save)
end

local ext_winhl = "Search:,CurSearch:,IncSearch:"

function View:setopts()
  local opts = {
    win = {
      eventignorewin = "all,-FileType,-InsertCharPre,-TextChangedI,-CursorMovedI",
      winhighlight = "Normal:ArtioNormal," .. ext_winhl,
      signcolumn = "no",
      wrap = false,
    },
    buf = {
      filetype = "artio-picker",
      buftype = "prompt",
      autocomplete = false,
    },
    g = {
      laststatus = self.picker.win.hidestatusline and 0 or nil,
    },
  }

  ---@type table<'win'|'buf'|'g',table<string,any>>
  self.opts = {}

  for level, o in pairs(opts) do
    self.opts[level] = self.opts[level] or {}
    local props = {
      scope = level == "g" and "global" or "local",
      buf = level == "buf" and ext.bufs.cmd or nil,
      win = level == "win" and ext.wins.cmd or nil,
    }

    for name, value in pairs(o) do
      self.opts[level][name] = vim.api.nvim_get_option_value(name, props)
      vim.api.nvim_set_option_value(name, value, props)
    end
  end
end

function View:revertopts()
  for level, o in pairs(self.opts) do
    for name, value in pairs(o) do
      vim.api.nvim_set_option_value(name, value, {
        scope = level == "g" and "global" or "local",
        buf = level == "buf" and ext.bufs.cmd or nil,
        win = level == "win" and ext.wins.cmd or nil,
      })
    end
  end
end

local maxlistheight = 0 -- Max height of the matches list (`self.win.height - 1`)

function View:on_resized()
  if self.picker.win.height > 1 then
    self.win.height = self.picker.win.height
  else
    self.win.height = vim.o.lines * self.picker.win.height
  end
  self.win.height = math.max(math.ceil(self.win.height), 1)

  maxlistheight = self.win.height - 1
end

function View:open()
  if not self.picker then
    return
  end

  ext.check_targets()

  self.prev_show = cmdline.cmdline_show

  self.augroup = vim.api.nvim_create_augroup("artio:view", {})

  vim.schedule(function()
    vim.api.nvim_create_autocmd({ "CmdlineLeave", "ModeChanged" }, {
      group = self.augroup,
      once = true,
      callback = function()
        self:close()
      end,
    })

    vim.api.nvim_create_autocmd("VimResized", {
      group = self.augroup,
      callback = function()
        self:on_resized()
      end,
    })

    vim.api.nvim_create_autocmd("TextChangedI", {
      group = self.augroup,
      buffer = ext.bufs.cmd,
      callback = function()
        self:update()
      end,
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
      group = self.augroup,
      buffer = ext.bufs.cmd,
      callback = function()
        self:updatecursor()
      end,
    })
  end)

  self:on_resized()

  cmdline.cmdline_show = function(...)
    return self:show(...)
  end

  self:saveview()

  cmdline.cmdline_show(
    { self.picker.defaulttext and { 0, self.picker.defaulttext } or nil },
    -1,
    "",
    self.picker.prompttext,
    1,
    0,
    prompt_hl_id
  )

  vim._with({ noautocmd = true }, function()
    vim.api.nvim_set_current_win(ext.wins.cmd)
  end)

  self:setopts()

  vim.schedule(function()
    self:clear()
    self:updatecursor()
  end)

  vim._with({ noautocmd = true }, function()
    vim.cmd.startinsert()
  end)

  vim._with({ win = ext.wins.cmd, wo = { eventignorewin = "" } }, function()
    vim.api.nvim_exec_autocmds("WinEnter", {})
  end)
end

function View:close()
  if self.closed then
    return
  end
  cmdline.cmdline_show = self.prev_show
  self:closepreview()
  vim.schedule(function()
    pcall(vim.api.nvim_del_augroup_by_id, self.augroup)

    vim.cmd.stopinsert()

    -- prepare state
    self:revertopts()

    -- reset state
    self:clear()
    cmdline.srow = 0
    cmdline.erow = 0

    -- restore ui
    self:hide()
    self:restoreview()
    vim.cmd.redraw()

    self.closed = true
  end)
end

function View:hide()
  vim.fn.clearmatches(ext.wins.cmd) -- Clear matchparen highlights.
  vim.api.nvim_win_set_cursor(ext.wins.cmd, { 1, 0 })
  vim.api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})

  local clear = vim.schedule_wrap(function(was_prompt)
    -- Avoid clearing prompt window when it is re-entered before the next event
    -- loop iteration. E.g. when a non-choice confirm button is pressed.
    if was_prompt and not cmdline.prompt then
      pcall(function()
        vim.api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(ext.bufs.dialog, 0, -1, false, {})
        vim.api.nvim_win_set_config(ext.wins.dialog, { hide = true })
        vim.on_key(nil, ext.msg.dialog_on_key)
      end)
    end
    -- Messages emitted as a result of a typed command are treated specially:
    -- remember if the cmdline was used this event loop iteration.
    -- NOTE: Message event callbacks are themselves scheduled, so delay two iterations.
    vim.schedule(function()
      cmdline.level = -1
    end)
  end)
  clear(cmdline.prompt)

  cmdline.prompt, cmdline.level = false, 0
  win_config(ext.wins.cmd, true, ext.cmdheight)
end

function View:update()
  local text = vim.api.nvim_get_current_line()
  text = text:sub(promptlen + 1)

  cmdline.cmdline_show({ { 0, text } }, -1, "", self.picker.prompttext, cmdline.indent, cmdline.level, prompt_hl_id)
end

local curpos = { 0, 0 } -- Last drawn cursor position. absolute
---@param pos? integer relative to prompt
function View:updatecursor(pos)
  self:promptpos()

  if not pos or pos < 0 then
    local cursorpos = vim.api.nvim_win_get_cursor(ext.wins.cmd)
    pos = cursorpos[2] - promptlen
  end

  curpos[2] = math.max(curpos[2], promptlen)

  if curpos[1] == promptidx + 1 and curpos[2] == promptlen + pos then
    return
  end

  if pos < 0 then
    -- reset to last known position
    pos = curpos[2] - promptlen
  end

  curpos[1], curpos[2] = promptidx + 1, promptlen + pos

  vim._with({ noautocmd = true }, function()
    local ok, _ = pcall(vim.api.nvim_win_set_cursor, ext.wins.cmd, curpos)
    if not ok then
      vim.notify(("Failed to set cursor %d:%d"):format(curpos[1], curpos[2]), vim.log.levels.ERROR)
    end
  end)
end

function View:clear()
  cmdline.srow = self.picker.opts.bottom and 0 or 1
  cmdline.erow = 0
  self:setlines(0, -1, {})
end

function View:promptpos()
  promptidx = self.picker.opts.bottom and cmdline.erow or 0
end

function View:setlines(posstart, posend, lines)
  vim._with({ noautocmd = true }, function()
    vim.api.nvim_buf_set_lines(ext.bufs.cmd, posstart, posend, false, lines)
  end)
end

local view_ns = vim.api.nvim_create_namespace("artio:view:ns")
local ext_priority = {
  prompt = 1,
  info = 2,
  select = 4,
  marker = 8,
  hl = 16,
  icon = 32,
  match = 64,
}

---@param line integer 0-based
---@param col integer 0-based
---@param opts vim.api.keyset.set_extmark
---@return integer
function View:mark(line, col, opts)
  opts.hl_mode = "combine"
  opts.invalidate = true

  local ok, result
  vim._with({ noautocmd = true }, function()
    ok, result = pcall(vim.api.nvim_buf_set_extmark, ext.bufs.cmd, view_ns, line, col, opts)
  end)
  if not ok then
    vim.notify(("Failed to add extmark %d:%d\n\t%s"):format(line, col, result), vim.log.levels.ERROR)
    return -1
  end

  return result
end

function View:drawprompt()
  if promptlen > 0 and prompthl_id > 0 then
    self:mark(promptidx, 0, { hl_group = prompthl_id, end_col = promptlen, priority = ext_priority.prompt })
    self:mark(promptidx, 0, {
      virt_text = {
        {
          ("[%d] (%d/%d)"):format(self.picker.idx, #self.picker.matches, #self.picker.items),
          "InfoText",
        },
      },
      virt_text_pos = "eol_right_align",
      priority = ext_priority.info,
    })
  end
end

local offset = 0

function View:updateoffset()
  self.picker:fix()
  if self.picker.idx == 0 then
    offset = 0
    return
  end

  local _offset = self.picker.idx - maxlistheight
  if _offset > offset then
    offset = _offset
  elseif self.picker.idx <= offset then
    offset = self.picker.idx - 1
  end

  offset = math.min(math.max(0, offset), math.max(0, #self.picker.matches - maxlistheight))
end

local icon_pad = 2

function View:showmatches()
  local indent = vim.fn.strdisplaywidth(self.picker.opts.pointer) + 1
  local prefix = (" "):rep(indent)
  local icon_pad_str = (" "):rep(icon_pad)

  self:updateoffset()

  local lines = {} ---@type string[]
  local hls = {}
  local icons = {} ---@type ([string, string]|false)[]
  local custom_hls = {} ---@type (artio.Picker.hl[]|false)[]
  local marks = {} ---@type boolean[]
  for i = 1 + offset, math.min(#self.picker.matches, maxlistheight + offset) do
    local match = self.picker.matches[i]
    local item = self.picker.items[match[1]]

    local icon, icon_hl = item.icon, item.icon_hl
    if not (icon and icon_hl) and vim.is_callable(self.picker.get_icon) then
      icon, icon_hl = self.picker.get_icon(item)
      item.icon, item.icon_hl = icon, icon_hl
    end
    icons[#icons + 1] = icon and { icon, icon_hl } or false
    icon = icon and ("%s%s"):format(item.icon, icon_pad_str) or ""

    local hl = item.hls
    if not hl and vim.is_callable(self.picker.hl_item) then
      hl = self.picker.hl_item(item)
      item.hls = hl
    end
    custom_hls[#custom_hls + 1] = hl or false

    marks[#marks + 1] = self.picker.marked[item.id] or false

    lines[#lines + 1] = ("%s%s%s"):format(prefix, icon, item.text)
    hls[#hls + 1] = match[2]
  end

  if not self.picker.opts.shrink then
    for _ = 1, (maxlistheight - #lines) do
      lines[#lines + 1] = ""
    end
  end
  cmdline.erow = cmdline.srow + #lines
  self:setlines(cmdline.srow, cmdline.erow, lines)

  for i = 1, #lines do
    local has_icon = icons[i] and icons[i][1] and true
    local icon_indent = has_icon and (#icons[i][1] + icon_pad) or 0

    if has_icon and icons[i][2] then
      self:mark(cmdline.srow + i - 1, indent, {
        end_col = indent + icon_indent,
        hl_group = icons[i][2],
        priority = ext_priority.icon,
      })
    end

    local line_hls = custom_hls[i]
    if line_hls then
      for j = 1, #line_hls do
        local hl = line_hls[j]
        self:mark(cmdline.srow + i - 1, indent + icon_indent + hl[1][1], {
          end_col = indent + icon_indent + hl[1][2],
          hl_group = hl[2],
          priority = ext_priority.hl,
        })
      end
    end

    if marks[i] then
      self:mark(cmdline.srow + i - 1, indent - 1, {
        virt_text = { { self.picker.opts.marker, "ArtioMarker" } },
        virt_text_pos = "overlay",
        priority = ext_priority.marker,
      })
    end

    if hls[i] then
      for j = 1, #hls[i] do
        local col = indent + icon_indent + hls[i][j]
        self:mark(cmdline.srow + i - 1, col, {
          hl_group = "ArtioMatch",
          end_col = col + 1,
          priority = ext_priority.match,
        })
      end
    end
  end
end

function View:hlselect()
  if self.select_ext then
    vim._with({ noautocmd = true }, function()
      vim.api.nvim_buf_del_extmark(ext.bufs.cmd, view_ns, self.select_ext)
    end)
  end

  self:softupdatepreview()

  self.picker:fix()
  local idx = self.picker.idx
  if idx == 0 then
    return
  end

  self:updateoffset()
  local row = math.max(0, math.min(cmdline.srow + (idx - offset), cmdline.erow) - 1)
  if row == promptidx then
    return
  end

  local extid = self:mark(row, 0, {
    virt_text = { { self.picker.opts.pointer, "ArtioPointer" } },
    virt_text_pos = "overlay",

    hl_group = "ArtioSel",
    hl_eol = true,
    end_row = row + 1,
    end_col = 0,

    priority = ext_priority.select,
  })
  if extid ~= -1 then
    self.select_ext = extid
  end
end

function View:togglepreview()
  if self.preview_win then
    self:closepreview()
    return
  end

  self:updatepreview()
end

---@return integer
---@return fun(win: integer)?
function View:openpreview()
  if self.picker.idx == 0 then
    return -1
  end

  local match = self.picker.matches[self.picker.idx]
  local item = self.picker.items[match[1]]

  if not item or not (self.picker.preview_item and vim.is_callable(self.picker.preview_item)) then
    return -1
  end

  return self.picker.preview_item(item.v)
end

function View:updatepreview()
  local buf, on_win = self:openpreview()
  if buf < 0 then
    return
  end

  if not self.preview_win then
    self.preview_win = vim.api.nvim_open_win(
      buf,
      false,
      vim.tbl_extend("force", self.picker.win.preview_opts(self), {
        relative = "editor",
        style = "minimal",
      })
    )
  else
    vim.api.nvim_win_set_buf(self.preview_win, buf)
  end

  vim.api.nvim_set_option_value("previewwindow", true, { scope = "local", win = self.preview_win })

  if on_win and vim.is_callable(on_win) then
    on_win(self.preview_win)
  end
end

function View:softupdatepreview()
  if self.picker.idx == 0 then
    self:closepreview()
  end

  if not self.preview_win then
    return
  end

  self:updatepreview()
end

function View:closepreview()
  if not self.preview_win then
    return
  end

  vim.api.nvim_win_close(self.preview_win, true)
  self.preview_win = nil
end

return View
