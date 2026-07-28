local RestyTemplate = require("resty.template")
local layout = require("tealdoc.generator.site.templates.layout")
local header = require("tealdoc.generator.site.templates.header")
local content = require("tealdoc.generator.site.templates.content")
local home = require("tealdoc.generator.site.templates.home")
local footer = require("tealdoc.generator.site.templates.footer")

local record PageTemplate
    render: function({string: string}, string): string
end

local defaults: {string: string} = {
    ["layout.html"] = layout,
    ["header.html"] = header,
    ["content.html"] = content,
    ["home.html"] = home,
    ["footer.html"] = footer,
}

local required = {
    "language",
    "title",
    "description",
    "head",
    "stylesheet_url",
    "pico_stylesheet_url",
    "search_index_url",
    "script_url",
    "brand",
    "top_navigation",
    "header_actions",
    "sidebar_links",
    "shell_class",
    "sidebar",
    "content_class",
    "breadcrumbs",
    "mobile_outline",
    "content",
    "home_hero",
    "page_navigation",
    "outline",
    "search_dialog",
    "footer_class",
    "footer_items",
    "content_template",
}

local function read_optional(path: string): string
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local contents = assert(file:read("*a"), "Could not read " .. path)
    file:close()
    return contents
end

local function indent_block(block: string, indent: string): string
    if block == "" then
        return ""
    end
    local output: {string} = {}
    local position = 1
    local in_pre = false
    while true do
        local newline = block:find("\n", position, true)
        local line: string
        if newline then
            line = block:sub(position, newline - 1)
        else
            line = block:sub(position)
        end
        table.insert(output, in_pre and line or indent .. line)
        if line:find("<pre[%s>]") then
            in_pre = true
        end
        if line:find("</pre>", 1, true) then
            in_pre = false
        end
        if not newline then
            break
        end
        table.insert(output, "\n")
        position = newline + 1
    end
    return table.concat(output)
end

function PageTemplate.render(
    values: {string: string},
    override_root: string
): string
    for _, name in ipairs(required) do
        assert(values[name] ~= nil, "missing page template value: " .. name)
    end

    local engine = RestyTemplate.new({})
    engine.load = function(name: string, plain: boolean): string
        if plain == true then
            return name
        end
        local fallback = assert(
            defaults[name],
            "unknown site template: " .. name
        )
        if override_root and override_root ~= "" then
            local separator = package.config:sub(1, 1)
            local custom = read_optional(override_root .. separator .. name)
            if custom then
                return custom
            end
        end
        return fallback
    end

    local context: {string: any} = {}
    for name, value in pairs(values) do
        context[name] = value
    end
    context.block = indent_block
    return engine.process_file("layout.html", context, "no-cache")
end

return PageTemplate
