-- Draws cached icon PNGs over the `{{flicon:<key>}}` markers in a buffer using
-- snacks' low-level image placement API.
--
-- Passing `height = 1` explicitly is deliberate: it forces snacks' single-row
-- inline code path, which sidesteps its document-level size fitting (DPI/scale
-- guessing, the <=2 cell "collapse", the decorative anchor glyph and the
-- duplicate placements those heuristics produced). One placement, one row.

local detect = require("flutter-icons.detect")
local render = require("flutter-icons.render")

local M = {}

local function placement()
  local ok, p = pcall(require, "snacks.image.placement")
  return ok and p or nil
end

local function set_win_opts(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.wo[win].conceallevel = 3
    vim.wo[win].concealcursor = "n"
    vim.wo[win].wrap = false -- markers/urls must not wrap into extra rows
  end
end

--- Replace this buffer's markers with icon placements. Returns true if any were
--- drawn. Existing placements on the buffer are cleared first so repeated calls
--- (e.g. as blink swaps the documented item) stay in sync.
---@param buf integer
---@return boolean
function M.render(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return false
  end
  local P = placement()
  if not P then
    return false
  end
  P.clean(buf)
  local any = false
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for row, line in ipairs(lines) do
    local from = 1
    while true do
      local s, e, key = line:find(detect.PATTERN, from)
      if not s then
        break
      end
      local path = render.path(key)
      if path then
        pcall(P.new, buf, path, {
          pos = { row, s - 1 },
          range = { row, s - 1, row, e },
          inline = true,
          conceal = true,
          height = 1,
        })
        any = true
      end
      from = e + 1
    end
  end
  return any
end

local function set_all_win_opts(buf)
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    set_win_opts(w)
  end
end

--- One-shot rendering for a buffer whose contents do not change (LSP hovers).
---@param buf integer
---@param win? integer
function M.attach_static(buf, win)
  set_win_opts(win)
  if M.render(buf) then
    set_all_win_opts(buf)
  end
end

--- Rendering for a buffer that is reused/rewritten in place (blink's docs
--- window), re-syncing placements whenever the contents change.
---@param buf integer
function M.attach_dynamic(buf)
  local timer
  local function refresh()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    M.render(buf)
    set_all_win_opts(buf)
  end
  vim.schedule(refresh)
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return true
      end
      if timer then
        timer:stop()
      end
      timer = vim.defer_fn(refresh, 30)
    end,
    on_detach = function()
      if timer then
        timer:stop()
      end
    end,
  })
end

return M
