local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local Highlighter = require("tealdoc.generator.site.highlighter")
local SiteTypes = require("tealdoc.generator.site.types")

local record SiteApi
    source_markdown: function(page: SiteTypes.Page): string
    type_links: function(
        view: SiteTypes.ApiView,
        resolver: MarkdownGenerator.URLResolver
    ): Highlighter.Links
    markdown: function(
        view: SiteTypes.ApiView,
        resolver: MarkdownGenerator.URLResolver,
        attached_examples: {string: {SiteTypes.PreparedExample}},
        used_examples: {string: boolean}
    ): string
    summary: function(
        view: SiteTypes.ApiView,
        resolver: MarkdownGenerator.URLResolver
    ): string
end

local function read_file(path: string): string
    local file = assert(io.open(path, "rb"), "Could not open " .. path)
    local contents = assert(file:read("*a"), "Could not read " .. path)
    file:close()
    return contents
end

function SiteApi.source_markdown(page: SiteTypes.Page): string
    if page.example_source then
        local code = page.example_code or read_file(page.example_source)
        local language = page.example_language
        if not language then
            language = page.example_source:match("%.tl$") and "teal"
                or page.example_source:match("%.lua$") and "lua"
                or "text"
        end
        local fence = "```"
        while code:find(fence, 1, true) do
            fence = fence .. "`"
        end
        local output = "# " .. page.title .. "\n\n"
        if page.description then
            output = output .. page.description .. "\n\n"
        end
        return output ..
            fence ..
            language ..
            "\n" ..
            code:gsub("\n*$", "") ..
            "\n" ..
            fence ..
            "\n"
    end
    if not page.source then
        return ""
    end

    local text = read_file(page.source)
    if text:sub(1, 4) == "---\n" then
        local ending = text:find("\n---\n", 5, true)
        if ending then
            text = text:sub(ending + 5)
        end
    end

    local generated = text:find("\n<!-- @generated", 1, true)
    if generated then
        text = text:sub(1, generated - 1)
    end
    return text
end

local function add_type_link(
    links: Highlighter.Links,
    ambiguous: {string: boolean},
    name: string,
    url: string
)
    if not name or name == "" or not url then
        return
    end
    local function add(candidate: string)
        if ambiguous[candidate] then
            return
        end
        if links[candidate] and links[candidate] ~= url then
            links[candidate] = nil
            ambiguous[candidate] = true
        else
            links[candidate] = url
        end
    end
    add(name)
    local basename = name:match("([%w_]+)$")
    if basename and basename ~= name then
        add(basename)
    end
end

function SiteApi.type_links(
    view: SiteTypes.ApiView,
    resolver: MarkdownGenerator.URLResolver
): Highlighter.Links
    local links: Highlighter.Links = {}
    local ambiguous: {string: boolean} = {}
    if not view then
        return links
    end
    local env = view.env

    local function add_reference(reference: tealdoc.TypeReference)
        local url = MarkdownGenerator.resolve_type_url(
            env,
            reference.path,
            resolver,
            false
        )
        add_type_link(links, ambiguous, reference.name, url)
    end

    for path in pairs(view.public_paths) do
        local item = env.registry[path]
        if item and item is tealdoc.TypeItem
            and path ~= view.public
            and Generator.filter(item, env)
        then
            add_type_link(links, ambiguous, item.name, resolver(path))
        elseif item and item is tealdoc.FunctionItem then
            for _, param in ipairs(item.params or {}) do
                for _, reference in ipairs(param.type_references or {}) do
                    add_reference(reference)
                end
            end
            for _, result in ipairs(item.returns or {}) do
                for _, reference in ipairs(result.type_references or {}) do
                    add_reference(reference)
                end
            end
        end
    end
    return links
end

local function add_kind_badges(markdown: string, env: tealdoc.Env): string
    for path, item in pairs(env.registry) do
        if item.kind ~= "module" and Generator.filter(item, env) then
            local anchor = '<a id="' .. path .. '"></a>'
            local _, anchor_end = markdown:find(anchor, 1, true)
            if anchor_end then
                local heading_start, heading_end = markdown:find(
                    "\n##+ [^\n]+",
                    anchor_end + 1
                )
                if heading_start == anchor_end + 1 then
                    local kind = Generator.item_kind(item, env)
                    local badge = ' <span class="tealdoc-kind-badge ' ..
                        'tealdoc-kind-' ..
                        kind ..
                        '">' ..
                        kind ..
                        "</span>"
                    markdown = markdown:sub(1, heading_end) ..
                        badge ..
                        markdown:sub(heading_end + 1)
                end
            end
        end
    end
    return markdown
end

function SiteApi.markdown(
    view: SiteTypes.ApiView,
    resolver: MarkdownGenerator.URLResolver,
    attached_examples: {string: {SiteTypes.PreparedExample}},
    used_examples: {string: boolean}
): string
    if not view then
        return ""
    end

    local page_env = view.env

    local markdown = add_kind_badges(
        MarkdownGenerator.render(page_env, resolver, false),
        page_env
    )

    for item_path, examples in pairs(attached_examples or {}) do
        local anchor = '<a id="' .. item_path .. '"></a>'
        local first, ending = markdown:find(anchor, 1, true)
        if first then
            used_examples[item_path] = true
            local following = markdown:find("\n<a id=\"", ending + 1, true)
            local insertion = following or (#markdown + 1)
            local blocks: {string} = {}
            for _, example in ipairs(examples) do
                local fence = "```"
                while example.code:find(fence, 1, true) do
                    fence = fence .. "`"
                end
                table.insert(
                    blocks,
                    "\n### " ..
                        example.title ..
                        "\n\n" ..
                        fence ..
                        example.language ..
                        "\n" ..
                        example.code:gsub("\n*$", "") ..
                        "\n" ..
                        fence ..
                        "\n"
                )
            end
            markdown = markdown:sub(1, insertion - 1) ..
                table.concat(blocks) ..
                markdown:sub(insertion)
        end
    end

    local module_anchor = '<a id="' .. view.public .. '"></a>'
    local _, ending = markdown:find(module_anchor, 1, true)
    if ending then
        markdown = markdown:sub(ending + 1)
    end
    markdown = "\n" .. markdown
    markdown = markdown:gsub("\n(##+) ", function(level: string): string
        return "\n" .. string.rep("#", math.min(#level + 1, 6)) .. " "
    end)
    return markdown:sub(2)
end

-- The kinds `Generator.item_kind` answers for something a caller calls. What
-- is left over after these and the types is a value: a field, a variable, an
-- enum member.
local FUNCTION_KINDS: {string: boolean} = {
    ["function"] = true,
    method = true,
    metamethod = true,
    macro = true,
}

local function item_text(item: tealdoc.Item, env: tealdoc.Env): string
    if item.text and item.text ~= "" then
        return item.text
    end
    for _, child_path in ipairs(item.children or {}) do
        local child = env.registry[child_path]
        if child and child.text and child.text ~= "" then
            return child.text
        end
    end
    return ""
end

local function item_summary(item: tealdoc.Item, env: tealdoc.Env): string
    local text = item_text(item, env)
    if text == "" then
        return "—"
    end
    text = text:gsub("```[%s%S]-```", " ")
    text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
    text = text:gsub("`([^`]*)`", "%1")
    text = text:gsub("<[^>]+>", " ")
    text = text:gsub("[%*~]", "")
    text = text:gsub("^%s*#+%s*", "")
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    for index = 1, #text do
        local character = text:sub(index, index)
        local following = text:sub(index + 1, index + 1)
        if (character == "." or character == "!" or character == "?")
            and (following == "" or following:match("%s"))
        then
            text = text:sub(1, index)
            break
        end
    end

    local maximum = 120
    if #text > maximum then
        local shortened = text:sub(1, maximum - 3)
        shortened = shortened:match("^(.*)%s+%S*$") or shortened
        text = shortened:gsub("%s+$", "") .. "..."
    end
    return (text:gsub("\\", "\\\\"):gsub("|", "\\|"))
end

function SiteApi.summary(
    view: SiteTypes.ApiView,
    resolver: MarkdownGenerator.URLResolver
): string
    if not view then
        return ""
    end
    local env = view.env
    local module = env.registry[view.public]
    if not module or not module.children then
        return ""
    end

    local items: {tealdoc.Item} = {}
    for _, path in ipairs(module.children) do
        local item = env.registry[path]
        if item and Generator.filter(item, env) then
            table.insert(items, item)
        end
    end
    table.sort(items, function(a: tealdoc.Item, b: tealdoc.Item): boolean
        local left = a.name:lower()
        local right = b.name:lower()
        if left == right then
            return a.path < b.path
        end
        return left < right
    end)
    if #items == 0 then
        return ""
    end

    -- One table per group rather than one alphabetical list of everything. A
    -- reader arriving at a module wants either the shapes it defines or the
    -- calls it answers, and interleaving them by name means reading the kind
    -- column of every row to find out which of the two a name is.
    local groups: {{string, string, {tealdoc.Item}}} = {
        { "Types", "Type", {} },
        { "Functions", "Function", {} },
        { "Values", "Value", {} },
    }
    for _, item in ipairs(items) do
        local kind = Generator.item_kind(item, env)
        local group = 3
        if FUNCTION_KINDS[kind] then
            group = 2
        elseif item is tealdoc.TypeItem then
            group = 1
        end
        table.insert(groups[group][3], item)
    end

    local output: {string} = {}
    for _, group in ipairs(groups) do
        local heading, column, group_items = group[1], group[2], group[3]
        if #group_items > 0 then
            if #output > 0 then
                table.insert(output, "\n")
            end
            table.insert(output, "### " .. heading .. "\n\n")
            table.insert(output, "| " .. column .. " | Kind | Description |\n")
            table.insert(output, "| --- | --- | --- |\n")
            for _, item in ipairs(group_items) do
                local url = resolver(item.path) or "#" .. item.path
                local kind = Generator.item_kind(item, env)
                table.insert(
                    output,
                    "| [`" ..
                        item.name ..
                        "`](" ..
                        url ..
                        ') | <span class="tealdoc-kind-badge tealdoc-kind-' ..
                        kind ..
                        '">' ..
                        kind ..
                        "</span> | " ..
                        item_summary(item, env) ..
                        " |\n"
                )
            end
        end
    end
    return table.concat(output)
end

return SiteApi
