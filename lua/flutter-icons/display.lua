-- Draws cached icon PNGs over the `{{flicon:<key>}}` markers in a buffer using
-- snacks' low-level image placement API.
--
-- Passing `height = 1` explicitly is deliberate: it forces snacks' single-row
-- inline code path, which sidesteps its document-level size fitting (DPI/scale
-- guessing, the <=2 cell "collapse", the decorative anchor glyph and the
-- duplicate placements those heuristics produced). One placement, one row.
--
-- Rendering is asynchronous, so a marker's PNG may not exist yet when the doc is
-- first shown. Until it does we conceal the raw marker text (so it never leaks
-- into the popup) and re-draw when `render.on_done` fires.

local detect = require("flutter-icons.detect")
local render = require("flutter-icons.render")

local M = {}

local ns = vim.api.nvim_create_namespace("flutter-icons.display")
local pending = {} -- buf -> true (has markers awaiting their PNG)
local unsub -- render.on_done unsubscriber while anything is pending

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

local function set_buf_win_opts(buf)
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    set_win_opts(w)
  end
end

-- hide a marker span until its image is ready
local function conceal(buf, row, s, e)
  pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, s - 1, {
    end_col = e,
    conceal = "",
  })
end

local function ensure_subscription()
  if unsub then
    return
  end
  unsub = render.on_done(function()
    for buf in pairs(vim.deepcopy(pending)) do
      if vim.api.nvim_buf_is_valid(buf) then
        M.render(buf)
      else
        pending[buf] = nil
      end
    end
    if not next(pending) and unsub then
      unsub()
      unsub = nil
    end
  end)
end

--- Sync icon placements with the buffer's markers. Ready icons are drawn;
--- markers still rendering are concealed and redrawn once ready.
---@param buf integer
---@return boolean drew_any
function M.render(buf)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    pending[buf] = nil
    return false
  end
  local P = placement()
  if P then
    P.clean(buf)
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local drew, waiting = false, false
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for row, line in ipairs(lines) do
    local from = 1
    while true do
      local s, e, key = line:find(detect.PATTERN, from)
      if not s then
        break
      end
      local path = P and render.path(key)
      if path then
        pcall(P.new, buf, path, {
          pos = { row, s - 1 },
          range = { row, s - 1, row, e },
          inline = true,
          conceal = true,
          height = 1,
        })
        drew = true
      else
        -- always hide the raw marker; keep waiting only while its PNG renders
        conceal(buf, row, s, e)
        if not render.path(key) then
          waiting = true
        end
      end
      from = e + 1
    end
  end

  if waiting then
    pending[buf] = true
    ensure_subscription()
  else
    pending[buf] = nil
  end
  if drew or waiting then
    set_buf_win_opts(buf)
  end
  return drew
end

--- One-shot rendering for a buffer whose contents do not change (LSP hovers).
---@param buf integer
---@param win? integer
function M.attach_static(buf, win)
  set_win_opts(win)
  M.render(buf)
end

--- Rendering for a buffer that is reused/rewritten in place (blink's docs
--- window), re-syncing placements whenever the contents change.
---@param buf integer
function M.attach_dynamic(buf)
  local timer
  local function refresh()
    if vim.api.nvim_buf_is_valid(buf) then
      M.render(buf)
    end
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
      pending[buf] = nil
    end,
  })
end

return M
