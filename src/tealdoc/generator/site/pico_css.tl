local source = assert(
    debug.getinfo(1, "S").source:match("^@(.+)$"),
    "Could not locate Tealdoc's Pico CSS asset"
)
local directory = assert(
    source:match("^(.*)[/\\][^/\\]+$"),
    "Could not locate Tealdoc's site generator directory"
)
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
