local lfs = require("lfs")

local record Config
    record Loaded
        filename: string
        directory: string
        values: any
    end

    discover: function(): string
    load: function(filename?: string): Loaded
    resolve_path: function(directory: string, path: string): string
end

local discovered_cache: {string: Config.Loaded} = {}

function Config.discover(): string
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

function Config.load(filename?: string): Config.Loaded
    local selected = filename or Config.discover()
    if not selected then
        return {
            filename = nil,
            directory = ".",
            values = {},
        }
    end
    local cache_key: string
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
            tostring(load_error)
    )

    local ok, settings = pcall(chunk)
    assert(
        ok,
        "Could not execute Teal configuration '" ..
            selected ..
            "': " ..
            tostring(settings)
    )
    assert(
        type(settings) == "table",
        "Teal configuration '" .. selected .. "' must return a table"
    )
    local loaded: Config.Loaded = {
        filename = selected,
        directory = selected:match("^(.*)[/\\][^/\\]+$") or ".",
        values = settings,
    }
    if cache_key then
        discovered_cache[cache_key] = loaded
    end
    return loaded
end

function Config.resolve_path(directory: string, path: string): string
    if path:match("^[/\\]") or path:match("^%a:[/\\]") then
        return path
    end
    if directory == "." then
        return path
    end
    return directory .. package.config:sub(1, 1) .. path
end

return Config
