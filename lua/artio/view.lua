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

local cmdbuff = "" ---@type string Stored cmdline used to calculate translation offset.
local promptlen = 0 -- Current length of the last line in the prompt.
local promptwidth = 0 -- Current width of the prompt in the cmdline buffer.
local promptidx = 0
--- Concatenate content chunks and set the text for the current row in the cmdline buffer.
---
---@param content CmdContent
---@param prompt string
local function set_text(content, prompt)
  local lines = {} ---@type string[]
  for line in (prompt .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = vim.fn.strtrans(line)
  end

  promptlen = #lines[#lines]
  promptwidth = vim.fn.strdisplaywidth(lines[#lines])

  cmdbuff = ""
  for _, chunk in ipairs(content) do
    cmdbuff = cmdbuff .. chunk[2]
  end
  lines[#lines] = ("%s%s"):format(lines[#lines], vim.fn.strtrans(cmdbuff))
  vim.api.nvim_buf_set_lines(ext.bufs.cmd, promptidx, promptidx + 1, false, lines)
end

---@class artio.View
---@field picker artio.Picker
---@field closed boolean
---@field win artio.View.win
local View = {}
View.__index = View

function View:new()
  return setmetatable({
    closed = false,
    win = {
      height = 0,
    },
  }, View)
end

---@class artio.View.win
---@field height integer

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

  self.picker:getitems(cmd_text)
  self:showitems()

  self:promptpos()
  set_text(content, ("%s%s%s"):format(firstc, prompt, (" "):rep(indent)))

  local height = math.max(1, vim.api.nvim_win_text_height(ext.wins.cmd, {}).all)
  height = math.min(height, self.win.height)
  win_config(ext.wins.cmd, false, height)

  self:updatecursor(pos)

  if promptlen > 0 and hl_id > 0 then
    vim.api.nvim_buf_set_extmark(ext.bufs.cmd, ext.ns, promptidx, 0, { hl_group = hl_id, end_col = promptlen })
  end
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

local ext_winhl = "Search:MsgArea,CurSearch:MsgArea,IncSearch:MsgArea"

function View:setopts()
  local opts = {
    eventignorewin = "all,-FileType,-TextChangedI,-CursorMovedI",
    winhighlight = "Normal:ArtioNormal," .. ext_winhl,
    laststatus = self.picker.win.hidestatusline and 0 or nil,
  }

  self.opts = {}

  for name, value in pairs(opts) do
    self.opts[name] = vim.api.nvim_get_option_value(name, { scope = "local" })
    vim.api.nvim_set_option_value(name, value, { scope = "local" })
  end
end

function View:revertopts()
  for name, value in pairs(self.opts) do
    vim.api.nvim_set_option_value(name, value, { scope = "local" })
  end
end

function View:on_resized()
  if self.picker.win.height > 0 then
    self.win.height = self.picker.win.height
  else
    self.win.height = vim.o.lines * self.picker.win.height
  end
  self.win.height = math.max(math.ceil(self.win.height), 1)
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
      callback = function()
        self:update()
      end,
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
      group = self.augroup,
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
    nil,
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

  vim._with({ noautocmd = true }, function()
    vim.cmd.startinsert()
  end)

  vim.schedule(function()
    self:clear()
    self:updatecursor()
  end)

  vim._with({ win = ext.wins.cmd, wo = { eventignorewin = "" } }, function()
    vim.api.nvim_exec_autocmds("WinEnter", {})
  end)
end

function View:close()
  if self.closed then
    return
  end
  self.closed = true
  cmdline.cmdline_show = self.prev_show
  vim.schedule(function()
    vim.cmd.stopinsert()
    self:revertopts()
    self:clear()
    cmdline.srow = 0
    cmdline.erow = 0
    win_config(ext.wins.cmd, true, ext.cmdheight)
    self:restoreview()
    cmdline.cmdline_block_hide()
    pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
  end)
end

function View:update()
  local text = vim.api.nvim_get_current_line()
  text = text:sub(promptlen + 1)

  cmdline.cmdline_show({ { 0, text } }, nil, "", self.picker.prompttext, cmdline.indent, cmdline.level, prompt_hl_id)
end

local curpos = { 0, 0 } -- Last drawn cursor position. absolute
---@param pos? integer relative to prompt
function View:updatecursor(pos)
  self:promptpos()

  if not pos then
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
    vim.api.nvim_win_set_cursor(ext.wins.cmd, curpos)
  end)
end

function View:clear()
  cmdline.srow = self.picker.opts.bottom and 0 or 1
  cmdline.erow = 0
  vim.api.nvim_buf_set_lines(ext.bufs.cmd, 0, -1, false, {})
end

function View:promptpos()
  promptidx = self.picker.opts.bottom and cmdline.erow or 0
end

local view_ns = vim.api.nvim_create_namespace("artio:view:ns")
---@type vim.api.keyset.set_extmark
local ext_match_opts = {
  hl_group = "ArtioMatch",
  hl_mode = "combine",
}

local offset = 0

function View:showitems()
  local indent = vim.fn.strdisplaywidth(self.picker.opts.pointer) + 1
  local prefix = (" "):rep(indent)

  local _offset = math.max(0, self.picker.idx - (self.win.height - 1))
  if _offset > offset then
    offset = _offset
  elseif self.picker.idx <= offset then
    offset = math.max(0, self.picker.idx - 1)
  end

  local lines = {} ---@type string[]
  local hls = {}
  for i = 1 + offset, math.min(#self.picker.items, self.win.height - 1 + offset) do
    lines[#lines + 1] = ("%s%s"):format(prefix, self.picker.items[i][1])
    hls[#hls + 1] = self.picker.items[i][2]
  end
  cmdline.erow = cmdline.srow + #lines
  vim.api.nvim_buf_set_lines(ext.bufs.cmd, cmdline.srow, cmdline.erow, false, lines)

  for i = 1, #hls do
    for j = 1, #hls[i] do
      local col = indent + hls[i][j]
      vim.api.nvim_buf_set_extmark(
        ext.bufs.cmd,
        view_ns,
        cmdline.srow + i - 1,
        col,
        vim.tbl_extend("force", ext_match_opts, { end_col = col + 1 })
      )
    end
  end
end

function View:hlselect()
  if self.select_ext then
    vim.api.nvim_buf_del_extmark(ext.bufs.cmd, view_ns, self.select_ext)
  end

  self.picker:fix()
  local idx = self.picker.idx
  if idx == 0 then
    return
  end

  self.select_ext = vim.api.nvim_buf_set_extmark(ext.bufs.cmd, view_ns, cmdline.srow + idx - offset - 1, 0, {
    virt_text = { { self.picker.opts.pointer, "ArtioPointer" } },
    hl_mode = "combine",
    virt_text_pos = "overlay",
    line_hl_group = "ArtioSel",
  })
end

return View
