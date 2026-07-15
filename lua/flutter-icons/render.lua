-- Rasterises icons to PNG files on disk (asynchronously) and hands back a short,
-- deterministic cache key. The key is known before the PNG exists, so callers
-- can inject their marker immediately; when the background render finishes,
-- `on_done` listeners fire so the display layer can draw it.
--
--   * material_symbols_icons ships a self-contained SVG (referencing an installed
--     "Material Symbols *" font) in each constant's dartdoc; we recolour it and
--     rasterise with `rsvg-convert` (ImageMagick on many machines has no librsvg,
--     so it can't render these SVGs itself).
--   * Flutter's built-in icons only expose a codepoint, so we draw the glyph from
--     the matching font with `magick -font`.

local config = require("flutter-icons.config")

local uv = vim.uv or vim.loop

local M = {}

local inflight = {} -- key -> true (render in progress)
local path_cache = {} -- key -> absolute png path (positive results only)
local listeners = {} -- token -> fn
local warned = {} -- exe -> true (missing-tool notice shown once)
local scheduled = false

local function opts()
  return config.options
end

--- Subscribe to "a background render finished". Returns an unsubscribe function.
---@param fn fun()
---@return fun()
function M.on_done(fn)
  local token = {}
  listeners[token] = fn
  return function()
    listeners[token] = nil
  end
end

local function notify_done()
  if scheduled then
    return
  end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    for _, fn in pairs(listeners) do
      pcall(fn)
    end
  end)
end

-- glyph fill colour, from config or the Normal highlight
local function fg_color()
  if opts().color then
    return opts().color
  end
  local ok, hl =
    pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  if ok and hl and hl.fg then
    return string.format("#%06x", hl.fg)
  end
  return "#c8c8c8"
end

-- make an arbitrary string safe to use as a filename / marker key
local function slug(s)
  return (s:gsub("[^%w_%-%.]", "_"))
end

local function png_path(key)
  return opts().cache_dir .. "/" .. key .. ".png"
end

--- Absolute path of a rendered icon, or nil if it is not on disk yet. Positive
--- results are memoised (a rendered icon never disappears mid-session).
---@param key string
---@return string?
function M.path(key)
  if path_cache[key] then
    return path_cache[key]
  end
  local p = png_path(key)
  if uv.fs_stat(p) then
    path_cache[key] = p
    return p
  end
  return nil
end

local function url_decode(s)
  return (
    s:gsub("%%(%x%x)", function(h)
      return string.char(tonumber(h, 16))
    end)
  )
end

-- one-time warning when a required external tool is missing
local function tool_available(exe)
  if vim.fn.executable(exe) == 1 then
    return true
  end
  if not warned[exe] then
    warned[exe] = true
    vim.schedule(function()
      vim.notify(
        ("flutter-icons: `%s` not found on PATH; icons will not render"):format(
          exe
        ),
        vim.log.levels.WARN
      )
    end)
  end
  return false
end

-- start a background render for `key` unless it is cached or already running
local function ensure(key, cmd, stdin)
  if M.path(key) or inflight[key] then
    return key
  end
  if not tool_available(cmd[1]) then
    return key
  end
  inflight[key] = true
  vim.fn.mkdir(opts().cache_dir, "p")
  local ok = pcall(vim.system, cmd, { stdin = stdin }, function(res)
    inflight[key] = nil
    if res.code == 0 then
      notify_done()
    end
  end)
  if not ok then
    inflight[key] = nil
  end
  return key
end

--- Render a material_symbols_icons SVG (percent-encoded dartdoc data-uri).
--- Returns the cache key (rendering happens in the background).
---@param encoded_svg string
---@return string
function M.symbol(encoded_svg)
  local color = fg_color()
  local svg = url_decode(encoded_svg):gsub("fill:%s*grey", "fill:" .. color)
  local key = "sym_" .. vim.fn.sha256(svg .. color)
  local size = tostring(opts().png_size)
  return ensure(key, {
    "rsvg-convert",
    "-w",
    size,
    "-h",
    size,
    "-b",
    "none",
    "-o",
    png_path(key),
  }, svg)
end

--- Render a single glyph from a font file. Returns the cache key.
---@param otf string path to the icon font
---@param codepoint integer
---@param name string icon name (only used to build a readable cache key)
---@return string
function M.glyph(otf, codepoint, name)
  local color = fg_color()
  -- include the font in the key so e.g. Icons.home and Symbols.home (different
  -- fonts, same name) never collide
  local font = vim.fn.fnamemodify(otf, ":t:r")
  local key = ("ic_%s_%s_%s"):format(slug(font), slug(name), slug(color))
  local px = opts().png_size
  return ensure(key, {
    "magick",
    "-background",
    "none",
    "-fill",
    color,
    "-font",
    otf,
    "-pointsize",
    tostring(math.floor(px * 0.82)),
    "-gravity",
    "center",
    "-size",
    px .. "x" .. px,
    "label:" .. vim.fn.nr2char(codepoint, true),
    png_path(key),
  })
end

--- Forget memoised render paths (used by `flutter-icons.refresh`).
function M.clear_cache()
  path_cache = {}
end

return M
