-- Locates the active Flutter SDK for a buffer and builds the built-in
-- `Icons.*` name -> codepoint table from its `icons.dart`.

local uv = vim.uv or vim.loop

local M = {}

local cache = {} -- sdk root -> { map = {name=cp}, otf = path } | false

--- Find the Flutter SDK root for a buffer (fvm-aware).
---@param bufnr? integer
---@return string?
function M.find(bufnr)
  local root = vim.fs.root(bufnr or 0, { "pubspec.yaml", ".git" })
  if root then
    local link = root .. "/.fvm/flutter_sdk"
    if uv.fs_stat(link) then
      local real = uv.fs_realpath(link)
      if real then
        return real
      end
    end
  end
  local env = vim.env.FLUTTER_ROOT
  if env and uv.fs_stat(env) then
    return env
  end
  local exe = vim.fn.exepath("flutter")
  if exe ~= "" then
    return vim.fn.fnamemodify(exe, ":h:h")
  end
  return nil
end

--- Built-in icon table + font path for an SDK root (cached per session).
---@param sdk string
---@return { map: table<string, integer>, otf: string }?
function M.icons(sdk)
  if cache[sdk] ~= nil then
    return cache[sdk] or nil
  end
  local icons_dart = sdk .. "/packages/flutter/lib/src/material/icons.dart"
  local otf = sdk
    .. "/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
  if not (uv.fs_stat(icons_dart) and uv.fs_stat(otf)) then
    cache[sdk] = false
    return nil
  end
  local map = {}
  for line in io.lines(icons_dart) do
    local name, hex =
      line:match("static const IconData ([%w_]+) = IconData%(0x(%x+)")
    if name and hex then
      map[name] = tonumber(hex, 16)
    end
  end
  cache[sdk] = { map = map, otf = otf }
  return cache[sdk]
end

--- Forget the cached SDK lookup + icon table (e.g. after switching fvm version).
function M.clear_cache()
  cache = {}
end

--- Resolve a built-in icon name to { otf, codepoint } for a buffer.
---@param name string
---@param bufnr? integer
---@return string? otf, integer? codepoint
function M.builtin(name, bufnr)
  local sdk = M.find(bufnr)
  if not sdk then
    return nil
  end
  local entry = M.icons(sdk)
  local cp = entry and entry.map[name]
  if not cp then
    return nil
  end
  return entry.otf, cp
end

return M
