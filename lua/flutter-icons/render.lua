-- Rasterises icons to PNG files on disk and hands back a short cache key.
--
--   * material_symbols_icons ships a self-contained SVG (referencing an
--     installed "Material Symbols *" font) in each constant's dartdoc; we
--     recolour it and rasterise with `rsvg-convert` (ImageMagick on many
--     machines has no librsvg, so it can't render these SVGs itself).
--   * Flutter's built-in icons only expose a codepoint, so we draw the glyph
--     from the matching `MaterialIcons-Regular.otf` with `magick -font`.

local config = require("flutter-icons.config")

local M = {}

local function opts()
  return config.options
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

---@return string path
local function png_path(key)
  return opts().cache_dir .. "/" .. key .. ".png"
end

--- Absolute path of a rendered icon, or nil if the key was never rendered.
---@param key string
---@return string?
function M.path(key)
  local p = png_path(key)
  if (vim.uv or vim.loop).fs_stat(p) then
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

--- Render a material_symbols_icons SVG (percent-encoded, as found in the
--- dartdoc) to a PNG. Returns a cache key or nil on failure.
---@param encoded_svg string percent-encoded svg document
---@return string?
function M.symbol(encoded_svg)
  local svg = url_decode(encoded_svg)
  svg = svg:gsub("fill:%s*grey", "fill:" .. fg_color())
  local key = "sym_" .. vim.fn.sha256(svg .. fg_color())
  if M.path(key) then
    return key
  end
  vim.fn.mkdir(opts().cache_dir, "p")
  local svg_file = opts().cache_dir .. "/" .. key .. ".svg"
  local wf = io.open(svg_file, "w")
  if not wf then
    return nil
  end
  wf:write(svg)
  wf:close()
  local size = tostring(opts().png_size)
  vim.fn.system({
    "rsvg-convert",
    "-w",
    size,
    "-h",
    size,
    "-b",
    "none",
    svg_file,
    "-o",
    png_path(key),
  })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return key
end

--- Render a single glyph from a font file. Returns a cache key or nil.
---@param otf string path to the icon font
---@param codepoint integer
---@param name string icon name (only used to build a readable cache key)
---@return string?
function M.glyph(otf, codepoint, name)
  -- include the font in the key so e.g. Icons.home and Symbols.home (different
  -- fonts, same name) never collide
  local font = vim.fn.fnamemodify(otf, ":t:r")
  local key = ("ic_%s_%s_%s"):format(slug(font), slug(name), slug(fg_color()))
  if M.path(key) then
    return key
  end
  vim.fn.mkdir(opts().cache_dir, "p")
  local px = opts().png_size
  vim.fn.system({
    "magick",
    "-background",
    "none",
    "-fill",
    fg_color(),
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
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return key
end

return M
