-- blink.cmp integration.
--
-- `transform_items` injects an icon marker into the resolved item's
-- documentation; the FileType autocmd draws it in blink's documentation window.

local M = {}

--- Install the documentation-window renderer. Call from `setup()`.
function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "blink-cmp-documentation",
    group = vim.api.nvim_create_augroup(
      "flutter-icons.blink",
      { clear = true }
    ),
    callback = function(ev)
      require("flutter-icons.display").attach_dynamic(ev.buf)
    end,
  })
end

--- blink `sources.transform_items` provider.
---
--- blink runs this on the full completion list and again on the single item it
--- resolves before showing its docs. dartls sends the icon docs inline for the
--- whole `Symbols.*` list (thousands of items), so we only act on the
--- single-item resolve pass -- rendering the whole list would be far too slow.
---@param _ any blink context (unused)
---@param items table[]
---@return table[]
function M.transform_items(_, items)
  if #items ~= 1 then
    return items
  end
  local item = items[1]
  local doc = item.documentation
  local value = type(doc) == "table" and doc.value or doc
  local out = require("flutter-icons.detect").transform(
    value,
    item.label,
    vim.api.nvim_get_current_buf()
  )
  if out then
    if type(doc) == "table" then
      doc.value = out
      doc.kind = doc.kind or "markdown"
    else
      item.documentation = { kind = "markdown", value = out }
    end
  end
  return items
end

return M
