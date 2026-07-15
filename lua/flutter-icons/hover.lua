-- LSP hover integration: wraps vim.lsp.util.open_floating_preview so a Flutter
-- icon hover gets a marker injected and then rendered in the float.
--
-- The wrapper chains whatever is already installed (e.g. a dotfiles wrapper that
-- adds borders), so it is safe to layer on top.

local M = {}

local installed = false

--- Install the hover wrapper (idempotent). Call from `setup()`.
function M.setup()
  if installed then
    return
  end
  installed = true

  local orig = vim.lsp.util.open_floating_preview
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.util.open_floating_preview = function(contents, syntax, opts, ...)
    contents = M.transform(contents)
    local buf, win = orig(contents, syntax, opts, ...)
    pcall(require("flutter-icons.display").attach_static, buf, win)
    return buf, win
  end
end

--- Rewrite floating-preview `contents` (string or list of lines) to carry an
--- icon marker. Unchanged when there is no icon. Exposed for reuse/testing.
---@param contents string|string[]|nil
---@return string|string[]|nil
function M.transform(contents)
  if contents == nil then
    return contents
  end
  local is_list = type(contents) == "table"
  local md = is_list and table.concat(contents, "\n") or contents
  if type(md) ~= "string" then
    return contents
  end
  local out = require("flutter-icons.detect").transform(
    md,
    nil,
    vim.api.nvim_get_current_buf()
  )
  if not out then
    return contents
  end
  return is_list and vim.split(out, "\n") or out
end

return M
