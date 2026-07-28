local record Config
    record Loaded
        filename: string
        directory: string
        values: any
    end

    load: function(filename?: string): Loaded
end

local function discover(): string
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
        "Teal configuration must return a table"
    )
    return {
        filename = selected,
        directory = selected:match("^(.*)[/\\][^/\\]+$") or ".",
        values = settings,
    }
end

return Config
