-- Inline icon decorations in source code: draws the real glyph next to each
-- `Symbols.<name>` / `Icons.<name>` reference in a Dart buffer (opt-in).
--
-- Unlike the completion/hover surfaces this must not modify the buffer, so it
-- resolves the icon by name (via pkg.lua / sdk.lua) and places a one-row inline
-- image directly at the reference with snacks' placement API. Only visible lines
-- are decorated, refreshed on edit and scroll.

local render = require("flutter-icons.render")

local M = {}

local CLASSES = { Symbols = "symbol", Icons = "builtin" }

local enabled = {} -- bufnr -> true
local timers = {} -- bufnr -> timer
local active = {} -- bufnr -> { compositekey -> snacks placement }
local augroup

local function placement()
  local ok, p = pcall(require, "snacks.image.placement")
  return ok and p or nil
end

--- Find `Symbols.x` / `Icons.x` references in a line.
--- Returns a list of { kind, name, col } where `col` is the 0-indexed byte
--- position just after the reference (where the icon is inserted).
---@param line string
---@return { kind: string, name: string, col: integer }[]
function M.detect(line)
  local out = {}
  local i = 1
  while true do
    local s, e, cls, name = line:find("([%w_]+)%.([%w_]+)", i)
    if not s then
      break
    end
    local kind = CLASSES[cls]
    local prev = s > 1 and line:sub(s - 1, s - 1) or ""
    if kind and not prev:match("[%w_.]") then
      out[#out + 1] = { kind = kind, name = name, col = e }
    end
    i = e + 1
  end
  return out
end

local function resolve(ref, buf)
  if ref.kind == "symbol" then
    return require("flutter-icons.pkg").resolve(ref.name, buf)
  end
  return require("flutter-icons.sdk").builtin(ref.name, buf)
end

local function close(pl)
  pcall(function()
    pl:close()
  end)
end

--- Sync icon placements with the buffer's `Symbols.`/`Icons.` references.
---
--- Placements are diffed against the currently active set (keyed by
--- row:col:icon), so an unchanged reference keeps its existing placement rather
--- than being torn down and recreated -- which is what caused flicker. Snacks
--- redraws each placement itself on scroll/resize (`auto_resize`), so there is
--- nothing to do on scroll.
---@param buf integer
function M.render(buf)
  if not (enabled[buf] and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local P = placement()
  if not P then
    return
  end
  local current = active[buf] or {}
  local desired = {} -- compositekey -> { row, col, path }

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for row, line in ipairs(lines) do
    for _, ref in ipairs(M.detect(line)) do
      local font, cp = resolve(ref, buf)
      local key = font and cp and render.glyph(font, cp, ref.name)
      local path = key and render.path(key)
      if path then
        desired[row .. ":" .. ref.col .. ":" .. key] =
          { row = row, col = ref.col, path = path }
      end
    end
  end

  -- drop placements that are no longer wanted
  for ck, pl in pairs(current) do
    if not desired[ck] then
      close(pl)
      current[ck] = nil
    end
  end
  -- add placements that are new
  for ck, d in pairs(desired) do
    if not current[ck] then
      local ok, pl = pcall(P.new, buf, d.path, {
        pos = { d.row, d.col },
        range = { d.row, d.col, d.row, d.col },
        inline = true,
        conceal = false, -- decorate, never hide the code
        height = 1,
        auto_resize = true, -- let snacks redraw on scroll/resize
      })
      if ok then
        current[ck] = pl
      end
    end
  end

  active[buf] = current
end

local function clear(buf)
  for _, pl in pairs(active[buf] or {}) do
    close(pl)
  end
  active[buf] = nil
end

local function schedule(buf)
  if timers[buf] then
    timers[buf]:stop()
  end
  timers[buf] = vim.defer_fn(function()
    M.render(buf)
  end, 60)
end

local function ensure_autocmds()
  if augroup then
    return
  end
  augroup = vim.api.nvim_create_augroup("flutter-icons.code", { clear = true })
  -- Only edits move reference positions; scrolling does not, so we re-sync on
  -- text change only. Snacks redraws existing placements on scroll itself.
  vim.api.nvim_create_autocmd(
    { "TextChanged", "TextChangedI", "InsertLeave" },
    {
      group = augroup,
      callback = function(ev)
        if enabled[ev.buf] then
          schedule(ev.buf)
        end
      end,
    }
  )
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = augroup,
    callback = function(ev)
      enabled[ev.buf] = nil
      if timers[ev.buf] then
        timers[ev.buf]:stop()
        timers[ev.buf] = nil
      end
      clear(ev.buf)
    end,
  })
end

--- Enable inline decorations for a buffer.
---@param buf? integer
function M.enable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  ensure_autocmds()
  enabled[buf] = true
  M.render(buf)
end

--- Disable inline decorations for a buffer.
---@param buf? integer
function M.disable(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  enabled[buf] = nil
  if timers[buf] then
    timers[buf]:stop()
    timers[buf] = nil
  end
  clear(buf)
end

--- Toggle inline decorations for a buffer.
---@param buf? integer
function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if enabled[buf] then
    M.disable(buf)
  else
    M.enable(buf)
  end
end

return M
