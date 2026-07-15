# flutter-icons.nvim

Inline **Material icon previews for Flutter** in Neovim — see the actual glyph
next to `IconData` completions and in LSP hovers, the way JetBrains does.

Works with both:

- the [`material_symbols_icons`](https://pub.dev/packages/material_symbols_icons)
  package (`Symbols.*`), and
- Flutter's built-in `Icons.*`.

The icon is rendered as a real image (kitty graphics protocol) directly in
blink.cmp's documentation window and in `K` hovers.

## Requirements

- Neovim 0.10+
- A terminal that supports the **kitty graphics protocol** with unicode
  placeholders (Kitty, Ghostty, WezTerm).
- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) with the image
  module enabled — it provides the image placement backend.
- [`saghen/blink.cmp`](https://github.com/saghen/blink.cmp) for completion
  previews (hovers work without it).
- External tools on `PATH`:
  - `rsvg-convert` (librsvg) — renders the `Symbols.*` SVGs.
  - `magick` (ImageMagick) — renders built-in `Icons.*` glyphs.
- A Flutter SDK on the machine (auto-detected; fvm-aware).

## Install

With [vim.pack](https://neovim.io/doc/user/pack.html):

```lua
vim.pack.add({ "https://github.com/YOUR_GH_USER/flutter-icons.nvim" })
```

or lazy.nvim:

```lua
{ "YOUR_GH_USER/flutter-icons.nvim", dependencies = { "folke/snacks.nvim" } }
```

## Setup

```lua
-- snacks: the image module must be enabled
require("snacks").setup({ image = { enabled = true } })

require("flutter-icons").setup({
  -- builtin_icons = true,   -- also render Icons.* (not just Symbols.*)
  -- color = nil,            -- "#rrggbb"; nil follows the Normal fg
  -- png_size = 64,          -- source PNG px (display is one text row)
})

-- register the completion-doc provider with blink
require("blink.cmp").setup({
  sources = {
    transform_items = require("flutter-icons").transform_items,
  },
})
```

That's it — trigger completion on `Symbols.` / `Icons.` or hover a constant
with `K`.

## How it works

- **Completion / hover docs** carry the icon reference: `material_symbols_icons`
  embeds an SVG data-uri in each constant's dartdoc; built-in `Icons.*` expose a
  codepoint via `icons.dart`.
- On the single item blink resolves (or on a hover), the icon is rasterised to a
  cached PNG (`rsvg-convert` for SVGs, `magick -font` for glyphs) and a
  `{{flicon:<key>}}` marker is injected into the documentation.
- The marker is drawn as a one-row inline image using snacks' image placement
  API.

## License

MIT
