local tealdoc = require("tealdoc")
local SiteConfig = require("tealdoc.generator.site.config")
local SiteTypes = require("tealdoc.generator.site.types")
local lfs = require("lfs")

local record SiteExamples
    prepare: function(
        views: {string: SiteTypes.ApiView},
        config_directory: string,
        env: tealdoc.Env
    ): {string: {SiteTypes.PreparedExample}}
end

local record TealValidator
    validate: function(self, text: string, path: string): {string}
end

local record ExampleReference
    source: string
    region: string
end

local function example_files(directory: string, files: {string})
    for name in lfs.dir(directory) do
        if name ~= "." and name ~= ".." then
            local path = SiteConfig.join_path(directory, name)
            local attributes = lfs.attributes(path)
            if attributes and attributes.mode == "directory" then
                example_files(path, files)
            elseif path:match("%.tl$") or path:match("%.lua$") then
                table.insert(files, path)
            end
        end
    end
end

local function description_and_code(code: string): string, string
    local _, description, closing = code:match("^%s*%-%-%[(=*)%[(.-)%](=*)%]%s*\n")
    if description and closing then
        local ending = code:find("%]" .. closing .. "%]", 1)
        return description, (code:sub(assert(ending) + #closing + 3):gsub("^%s*\n", ""))
    end
    return "", code
end

local function read_file(path: string): string
    local file = assert(io.open(path, "rb"), "Could not open " .. path)
    local contents = assert(file:read("*a"), "Could not read " .. path)
    file:close()
    return contents
end

local function extract_region(
    code: string,
    source: string,
    region: string
): string
    if not region or region == "" then
        return code
    end

    code = code:gsub("\r\n", "\n"):gsub("\r", "\n")
    local output: {string} = {}
    local stack: {string} = {}
    local found = 0
    local target_depth = 0
    for line in (code .. "\n"):gmatch("(.-)\n") do
        local opening = line:match("^%s*%-%-%s*#region%s+(%S.-)%s*$")
        local closing = line:match("^%s*%-%-%s*#endregion%s*(.-)%s*$")
        if opening then
            table.insert(stack, opening)
            if opening == region then
                assert(
                    target_depth == 0,
                    "nested example region '" .. region .. "' in " .. source
                )
                found = found + 1
                target_depth = #stack
            end
        elseif closing ~= nil and #stack > 0 then
            local opened = stack[#stack]
            assert(
                closing == "" or closing == opened,
                "example region '" ..
                    opened ..
                    "' in " ..
                    source ..
                    " closes as '" ..
                    closing ..
                    "'"
            )
            if target_depth == #stack then
                target_depth = 0
            end
            table.remove(stack)
        elseif target_depth > 0 then
            table.insert(output, line)
        end
    end
    assert(
        found == 1 and target_depth == 0,
        found == 0
            and "example region '" .. region .. "' was not found in " .. source
            or "example region '" ..
                region ..
                "' must occur once and have an end marker in " ..
                source
    )
    return table.concat(output, "\n"):gsub("\n*$", "") .. "\n"
end

local function validate_example(
    example: ExampleReference,
    code: string,
    language: string,
    env: tealdoc.Env
)
    local errors: {string} = {}
    if language == "teal" then
        local parser = env.parser_registry[".tl"] as TealValidator
        assert(parser and parser.validate, "Teal parser cannot validate examples")
        errors = parser:validate(code, example.source)
    elseif language == "lua" then
        local chunk, load_error = load(code, "@" .. example.source)
        if not chunk then
            table.insert(errors, tostring(load_error))
        end
    end
    assert(
        #errors == 0,
        "invalid example '" ..
            example.source ..
            (example.region and "#" .. example.region or "") ..
            "':\n" ..
            table.concat(errors, "\n")
    )
end

function SiteExamples.prepare(
    _views: {string: SiteTypes.ApiView},
    config_directory: string,
    env: tealdoc.Env
): {string: {SiteTypes.PreparedExample}}
    local attached: {string: {SiteTypes.PreparedExample}} = {}
    local files: {string} = {}
    local directory = SiteConfig.join_path(config_directory, "docs/examples")
    if lfs.attributes(directory, "mode") == "directory" then
        example_files(directory, files)
    end
    table.sort(files)
    for _, source in ipairs(files) do
        local text = read_file(source)
        for region in text:gmatch("%-%-%s*#region%s+(tecs%.[%w%.]+)%s*\n") do
            local code = extract_region(text, source, region)
            local description = ""
            description, code = description_and_code(code)
            local language = source:match("%.tl$") and "teal" or "lua"
            validate_example({source = source, region = region}, code, language, env)
            attached[region] = attached[region] or {}
            table.insert(attached[region], {
                title = "Example",
                description = description,
                language = language,
                code = code,
            })
        end
    end
    return attached
end

return SiteExamples
