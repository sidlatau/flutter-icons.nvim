# flutter-icons.nvim

Inline **Material icon previews for Flutter** in Neovim — see the actual glyph
next to `IconData` completions and in LSP hovers, the way JetBrains does.

Works with both:

- the [`material_symbols_icons`](https://pub.dev/packages/material_symbols_icons)
  package (`Symbols.*`), and
- Flutter's built-in `Icons.*`.

The icon is rendered as a real image (kitty graphics protocol) directly in
blink.cmp's documentation window and in `K` hovers. Optionally, it can also draw
the glyph **inline in your source code** next to every `Symbols.`/`Icons.` usage.

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
vim.pack.add({ "https://github.com/sidlatau/flutter-icons.nvim" })
```

or lazy.nvim:

```lua
{ "sidlatau/flutter-icons.nvim", dependencies = { "folke/snacks.nvim" } }
```

## Setup

```lua
-- snacks: the image module must be enabled
require("snacks").setup({ image = { enabled = true } })

require("flutter-icons").setup({
  -- builtin_icons = true,   -- also render Icons.* (not just Symbols.*)
  -- color = nil,            -- "#rrggbb"; nil follows the Normal fg
  -- png_size = 64,          -- source PNG px (display is one text row)
  -- virtual_text = true,    -- auto-enable inline icons in Dart source
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

### Inline decorations in code (opt-in)

To draw the icon next to `Symbols.`/`Icons.` references in your Dart source, set
`virtual_text = true` to auto-enable for Dart buffers, or toggle it per buffer:

- `:FlutterIconsToggle` — toggle in the current buffer
- `require("flutter-icons").toggle_virtual_text()` / `.enable_virtual_text()` /
  `.disable_virtual_text()`

This is purely a visual overlay — your buffer text is never modified.

## How it works

- **Completion / hover docs** carry the icon reference: `material_symbols_icons`
  embeds an SVG data-uri in each constant's dartdoc; built-in `Icons.*` expose a
  codepoint via `icons.dart`.
- The icon is rasterised **in the background** (`rsvg-convert` for SVGs,
  `magick -font` for glyphs) to a cached PNG, and a `{{flicon:<key>}}` marker is
  injected into the documentation; the marker is drawn as a one-row inline image
  using snacks' image placement API once the render finishes.

## Notes

- Run `:checkhealth flutter-icons` to verify tools, the snacks backend and
  terminal graphics support.
- Rendering is async and cached on disk, so icons appear a moment after a doc/
  buffer opens the first time, then instantly.
- **Inline decorations** decorate the whole buffer (not just visible lines) so
  scrolling never re-renders; a very large, icon-dense file therefore places all
  its icons up front.
- Flutter SDK / package lookups are cached per session. After switching fvm
  version or running `flutter pub get`, call `require("flutter-icons").refresh()`.

## License

MIT
