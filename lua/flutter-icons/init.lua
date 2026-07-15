-- flutter-icons.nvim
--
-- Inline Material icon previews for Flutter in blink.cmp completion docs and LSP
-- hovers. Supports the material_symbols_icons `Symbols.*` package and Flutter's
-- built-in `Icons.*`.
--
-- Wire the completion provider into blink yourself:
--
--   require("blink.cmp").setup({
--     sources = { transform_items = require("flutter-icons").transform_items },
--   })
--
-- and enable snacks' image module (`opts.image.enabled = true`).

local M = {}

--- @param opts? FlutterIcons.Config
function M.setup(opts)
  local cfg = require("flutter-icons.config").setup(opts)
  if cfg.hover then
    require("flutter-icons.hover").setup()
  end
  if cfg.blink then
    require("flutter-icons.blink").setup()
  end
  return M
end

--- blink `sources.transform_items` provider (see the module header).
function M.transform_items(...)
  return require("flutter-icons.blink").transform_items(...)
end

return M
