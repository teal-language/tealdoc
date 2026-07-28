local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local source = assert(
debug.getinfo(1, "S").source:match("^@(.+)$"),
"Could not locate Tealdoc's Pico CSS asset")

local directory = assert(
source:match("^(.*)[/\\][^/\\]+$"),
"Could not locate Tealdoc's site generator directory")

local filename = "pico.classless-2.1.1.min.css"
local path = directory .. "/" .. filename
local file = io.open(path, "rb")
if not file then
   path = directory .. "/assets/" .. filename
   file = io.open(path, "rb")
end
assert(file, "Could not open Tealdoc's vendored " .. filename)
local contents = assert(file:read("*a"), "Could not read " .. path)
file:close()

return contents
