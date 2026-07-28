local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local loadfile = _tl_compat and _tl_compat.loadfile or loadfile; local package = _tl_compat and _tl_compat.package or package; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local Config = { Loaded = {} }









local function discover()
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
   local selected = filename or discover()
   if not selected then
      return {
         filename = nil,
         directory = ".",
         values = {},
      }
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
   "Teal configuration must return a table")

   return {
      filename = selected,
      directory = selected:match("^(.*)[/\\][^/\\]+$") or ".",
      values = settings,
   }
end

return Config
