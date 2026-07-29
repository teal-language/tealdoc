local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local loadfile = _tl_compat and _tl_compat.loadfile or loadfile; local package = _tl_compat and _tl_compat.package or package; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local lfs = require("lfs")

local Config = { Loaded = {} }











local discovered_cache = {}

function Config.discover()
   local separator = package.config:sub(1, 1)
   local filename = "tlconfig.lua"
   for _ = 1, 20 do
      local file = io.open(filename, "r")
      if file then
         file:close()
         return filename
      end
      filename = ".." .. separator .. filename
   end
   return nil
end

function Config.load(filename)
   local selected = filename or Config.discover()
   if not selected then
      return {
         filename = nil,
         directory = ".",
         values = {},
      }
   end
   local cache_key
   if not filename then
      cache_key = assert(lfs.currentdir()) ..
      package.config:sub(1, 1) ..
      selected
      if discovered_cache[cache_key] then
         return discovered_cache[cache_key]
      end
   end

   local chunk, load_error = loadfile(selected)
   assert(
   chunk,
   "Could not load Teal configuration '" ..
   selected ..
   "': " ..
   tostring(load_error))


   local ok, settings = pcall(chunk)
   assert(
   ok,
   "Could not execute Teal configuration '" ..
   selected ..
   "': " ..
   tostring(settings))

   assert(
   type(settings) == "table",
   "Teal configuration '" .. selected .. "' must return a table")

   local loaded = {
      filename = selected,
      directory = selected:match("^(.*)[/\\][^/\\]+$") or ".",
      values = settings,
   }
   if cache_key then
      discovered_cache[cache_key] = loaded
   end
   return loaded
end

function Config.resolve_path(directory, path)
   if path:match("^[/\\]") or path:match("^%a:[/\\]") then
      return path
   end
   if directory == "." then
      return path
   end
   return directory .. package.config:sub(1, 1) .. path
end

return Config
