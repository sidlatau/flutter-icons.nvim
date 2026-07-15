-- Turns an LSP documentation string into one that carries an icon marker
-- (`{{flicon:<key>}}`) where the icon should be drawn. The display layer later
-- finds these markers and renders the cached PNG over them.

local render = require("flutter-icons.render")
local sdk = require("flutter-icons.sdk")
local config = require("flutter-icons.config")

local M = {}

-- literal marker + a Lua pattern to find it again
M.MARKER = "{{flicon:%s}}"
M.PATTERN = "{{flicon:([%w_%-%.]+)}}"

--- Rewrite `doc` so a Flutter icon reference becomes an icon marker.
--- Returns the new string, or nil when there is nothing to render.
---@param doc string|nil
---@param label string|nil completion label (nil for hovers)
---@param bufnr integer|nil
---@return string?
function M.transform(doc, label, bufnr)
  if type(doc) ~= "string" or doc == "" then
    return nil
  end
  if doc:find("{{flicon:", 1, true) then
    return nil -- already processed
  end

  -- 1) material_symbols_icons: an embedded (percent-encoded) SVG data url
  local link = doc:match("!%[[^%]]*%]%(data:image/svg%+xml,.-%)")
  if link then
    local encoded = link:match("data:image/svg%+xml,(.-)%)$")
    local key = encoded and render.symbol(encoded)
    if not key then
      return nil
    end
    local s, e = doc:find(link, 1, true)
    return doc:sub(1, s - 1) .. M.MARKER:format(key) .. doc:sub(e + 1)
  end

  -- 2) Flutter built-in Icons: an <i class="material-icons"> tag, no image
  if config.options.builtin_icons and doc:find('class="material%-icons') then
    -- completions give us the label; hovers fall back to the "IconData <name>"
    -- signature line in the hover markdown
    local name = label
      or doc:match("IconData%s+get%s+([%w_]+)")
      or doc:match("IconData%s+([%w_]+)")
    if not name then
      return nil
    end
    name = vim.trim(name)
    local otf, cp = sdk.builtin(name, bufnr)
    if not (otf and cp) then
      return nil
    end
    local key = render.glyph(otf, cp, name)
    if not key then
      return nil
    end
    return M.MARKER:format(key) .. " " .. doc
  end

  return nil
end

return M
