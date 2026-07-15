local M = {}

local h = vim.health

function M.check()
  h.start("flutter-icons.nvim")

  -- external tools
  if vim.fn.executable("rsvg-convert") == 1 then
    h.ok("`rsvg-convert` found (renders Symbols.* SVGs)")
  else
    h.error(
      "`rsvg-convert` not found",
      "install librsvg (e.g. `brew install librsvg`)"
    )
  end
  if vim.fn.executable("magick") == 1 then
    h.ok("`magick` found (renders built-in Icons.* glyphs)")
  else
    h.warn(
      "`magick` not found",
      "install ImageMagick to render built-in Icons.*"
    )
  end

  -- snacks image backend
  local ok_snacks = pcall(require, "snacks.image.placement")
  if ok_snacks then
    h.ok("snacks.nvim image module available")
  else
    h.error(
      "snacks.nvim image module not available",
      "install folke/snacks.nvim and enable `opts.image.enabled = true`"
    )
  end

  -- terminal graphics support
  local ok_term, term = pcall(require, "snacks.image.terminal")
  if ok_term and term.env then
    local env = term.env()
    if env.placeholders then
      h.ok(
        "terminal supports the kitty graphics protocol (unicode placeholders)"
      )
    else
      h.warn(
        "terminal does not report unicode-placeholder support",
        "use Kitty, Ghostty or WezTerm for inline images"
      )
    end
  end

  -- optional: blink.cmp for completion previews
  if pcall(require, "blink.cmp") then
    h.ok("blink.cmp available (completion previews enabled)")
  else
    h.info("blink.cmp not found (hover/inline previews still work)")
  end

  -- Flutter SDK discovery from the current directory
  local sdk = require("flutter-icons.sdk").find(0)
  if sdk then
    h.ok("Flutter SDK: " .. sdk)
  else
    h.warn(
      "no Flutter SDK found for the current directory",
      "open a Flutter project, set $FLUTTER_ROOT, or put `flutter` on PATH"
    )
  end
end

return M
