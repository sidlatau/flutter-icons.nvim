local M = {}

---@class FlutterIcons.Config
local defaults = {
  -- Also render Flutter's built-in `Icons.*` (in addition to the
  -- material_symbols_icons `Symbols.*` package).
  builtin_icons = true,
  -- Glyph fill colour as a "#rrggbb" hex string, or nil to derive it from the
  -- `Normal` highlight foreground (so the icon matches your colourscheme).
  color = nil,
  -- Source PNG size in pixels. The image is displayed at a single text row, so
  -- this only affects sharpness; the default is crisp on HiDPI displays.
  png_size = 64,
  -- Where rendered PNGs are cached.
  cache_dir = vim.fn.stdpath("cache") .. "/flutter-icons",
  -- Integrations to install from `setup()`.
  blink = true, -- register the blink.cmp documentation provider
  hover = true, -- wrap vim.lsp.util.open_floating_preview for LSP hovers
}

---@type FlutterIcons.Config
M.options = vim.deepcopy(defaults)

---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return M.options
end

return M
