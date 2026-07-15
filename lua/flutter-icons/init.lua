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

  -- auto-enable inline code decorations for Dart buffers
  if cfg.virtual_text then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "dart",
      group = vim.api.nvim_create_augroup(
        "flutter-icons.code.ft",
        { clear = true }
      ),
      callback = function(ev)
        require("flutter-icons.code").enable(ev.buf)
      end,
    })
  end

  vim.api.nvim_create_user_command("FlutterIconsToggle", function()
    require("flutter-icons.code").toggle()
  end, { desc = "Toggle inline Flutter icon decorations in this buffer" })

  return M
end

--- blink `sources.transform_items` provider (see the module header).
function M.transform_items(...)
  return require("flutter-icons.blink").transform_items(...)
end

--- Inline code decorations control (see also `:FlutterIconsToggle`).
function M.enable_code(buf)
  require("flutter-icons.code").enable(buf)
end

function M.disable_code(buf)
  require("flutter-icons.code").disable(buf)
end

function M.toggle_code(buf)
  require("flutter-icons.code").toggle(buf)
end

return M
