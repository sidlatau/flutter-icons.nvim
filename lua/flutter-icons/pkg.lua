-- Resolves a material_symbols_icons `Symbols.<name>` reference (as seen in code,
-- where there is no dartdoc SVG to lean on) to a codepoint + variant font by
-- parsing the package's `symbols.dart`.

local uv = vim.uv or vim.loop

local M = {}

local FONTS = {
  MaterialSymbolsOutlined = "MaterialSymbolsOutlined.ttf",
  MaterialSymbolsRounded = "MaterialSymbolsRounded.ttf",
  MaterialSymbolsSharp = "MaterialSymbolsSharp.ttf",
}

local root_cache = {} -- project root -> package root | false
local map_cache = {} -- package root -> { name -> { cp, font } }

local function decode_root_uri(uri, project)
  local path = uri:gsub("^file://", "")
  if not path:match("^/") then
    -- rootUri is relative to the .dart_tool directory
    path = vim.fs.normalize(project .. "/.dart_tool/" .. path)
  end
  return path
end

--- Locate the material_symbols_icons package root for a buffer's project.
---@param bufnr? integer
---@return string?
function M.find(bufnr)
  local project = vim.fs.root(bufnr or 0, { "pubspec.yaml", ".git" })
    or vim.fn.getcwd()
  if root_cache[project] ~= nil then
    return root_cache[project] or nil
  end

  local root
  local cfg = io.open(project .. "/.dart_tool/package_config.json")
  if cfg then
    local ok, data = pcall(vim.json.decode, cfg:read("*a"))
    cfg:close()
    if ok and type(data) == "table" and data.packages then
      for _, p in ipairs(data.packages) do
        if p.name == "material_symbols_icons" and p.rootUri then
          root = decode_root_uri(p.rootUri, project)
          break
        end
      end
    end
  end
  if not root then
    -- fall back to the newest copy in the pub cache
    local home = uv.os_homedir() or vim.env.HOME or "~"
    local globs = vim.fn.glob(
      home .. "/.pub-cache/hosted/*/material_symbols_icons-*",
      false,
      true
    )
    table.sort(globs)
    root = globs[#globs]
  end
  if root and not uv.fs_stat(root .. "/lib/symbols.dart") then
    root = nil
  end
  root_cache[project] = root or false
  return root
end

--- Parse `symbols.dart` into { name -> { cp, font } } (cached per package).
--- Streamed line-by-line: the file is several MB (huge SVG doc comments) but the
--- two declaration lines we want are cheap to match.
---@param root string
---@return table<string, { cp: integer, font: string }>?
function M.map(root)
  if map_cache[root] then
    return map_cache[root]
  end
  local file = root .. "/lib/symbols.dart"
  local fh = io.open(file)
  if not fh then
    return nil
  end
  local map = {}
  local fonts_dir = root .. "/lib/fonts/"
  local function record(name, hex, fam)
    local font = FONTS[fam]
    if font then
      map[name] = { cp = tonumber(hex, 16), font = fonts_dir .. font }
    end
  end
  local pending
  for line in fh:lines() do
    if pending then
      local hex, fam =
        line:match("IconData%(0x(%x+),%s*fontFamily:%s*'([^']+)'")
      if hex then
        record(pending, hex, fam)
      end
      pending = nil
    else
      local name = line:match("^%s*static const IconData ([%w_]+) =%s*$")
      if name then
        pending = name -- constructor is on the next line
      else
        local n, hex, fam = line:match(
          "static const IconData ([%w_]+) = IconData%(0x(%x+),%s*fontFamily:%s*'([^']+)'"
        )
        if n then
          record(n, hex, fam)
        end
      end
    end
  end
  fh:close()
  map_cache[root] = map
  return map
end

--- Resolve a `Symbols.<name>` to { font, codepoint } for a buffer.
---@param name string
---@param bufnr? integer
---@return string? font, integer? codepoint
function M.resolve(name, bufnr)
  local root = M.find(bufnr)
  if not root then
    return nil
  end
  local map = M.map(root)
  local entry = map and map[name]
  if not entry then
    return nil
  end
  return entry.font, entry.cp
end

return M
