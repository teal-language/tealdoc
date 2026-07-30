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
    --- Every documented type on the site, against the page documenting it. A
    --- page's own view is the better answer where it has one, so this is what
    --- a page falls back to rather than what it starts from.
    site_type_links: function(
        env: tealdoc.Env,
        resolver: MarkdownGenerator.URLResolver,
        public_paths?: {string: string}
    ): Highlighter.Links
    markdown: function(
        view: SiteTypes.ApiView,
        resolver: MarkdownGenerator.URLResolver,
        attached_examples: {string: {SiteTypes.PreparedExample}},
        used_examples: {string: boolean},
        format_code?: function(string): string
    ): string, string
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

--- One spelling against one type, and nothing against a spelling two types
--- answer to. A highlighted token is looked up under the whole dotted
--- expression it ends rather than its last segment, so what is registered here
--- is what a code block may write and mean this type.
local function add_spelling(
    links: Highlighter.Links,
    ambiguous: {string: boolean},
    spelling: string,
    url: string
)
    if not spelling or spelling == "" or not url then
        return
    end
    if ambiguous[spelling] then
        return
    end
    if links[spelling] and links[spelling] ~= url then
        links[spelling] = nil
        ambiguous[spelling] = true
    else
        links[spelling] = url
    end
end

--- A qualified name and every shorter tail of it: `tecs.gfx.Camera` registers
--- itself, `gfx.Camera` and `Camera`. Code inside a module writes a type under
--- as much of its path as the enclosing scope leaves it needing, and a page is
--- the scope its own names are relative to, so all three mean this one type
--- there.
---
--- Site-wide this is not true, which is why the site's map registers exact
--- names instead. `events.Event` is the ECS event on the page documenting it
--- and the platform event on the page documenting that one, and a tail nobody
--- qualified is a guess between them.
local function add_type_link(
    links: Highlighter.Links,
    ambiguous: {string: boolean},
    name: string,
    url: string
)
    if not name or name == "" or not url then
        return
    end
    add_spelling(links, ambiguous, name, url)
    local tail = name
    while true do
        local shorter = tail:match("^[%w_]+%.(.+)$")
        if not shorter then
            break
        end
        tail = shorter
        add_spelling(links, ambiguous, tail, url)
    end
    add_spelling(links, ambiguous, name:match("([%w_]+)$"), url)
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
            -- A page's registry is keyed by public path, so `path` is the
            -- spelling the documentation gives this type and the one a code
            -- block writes it under.
            add_type_link(links, ambiguous, item.name, resolver(path))
            add_type_link(links, ambiguous, path, resolver(path))
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

-- The kinds `Generator.item_kind` answers for something a caller calls. What
-- is left over after these and the types is a value: a field, a variable, an
-- enum member.
local FUNCTION_KINDS: {string: boolean} = {
    ["function"] = true,
    method = true,
    metamethod = true,
    macro = true,
}

local function rebase_headings(text: string, target: integer): string
    local lines: {string} = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, (line:gsub("\r$", "")))
    end

    local shallowest: integer
    local fence_character: string
    local fence_length = 0
    for _, line in ipairs(lines) do
        local fence = line:match("^%s*(```+)")
            or line:match("^%s*(~~~+)")
        if fence then
            local character = fence:sub(1, 1)
            if not fence_character then
                fence_character = character
                fence_length = #fence
            elseif character == fence_character and #fence >= fence_length then
                fence_character = nil
                fence_length = 0
            end
        elseif not fence_character then
            local hashes = line:match("^%s*(#+)%s+")
            if hashes and #hashes <= 6
                and (not shallowest or #hashes < shallowest)
            then
                shallowest = #hashes
            end
        end
    end
    if not shallowest then
        return text
    end

    local shift = target - shallowest
    fence_character = nil
    fence_length = 0
    for index, line in ipairs(lines) do
        local fence = line:match("^%s*(```+)")
            or line:match("^%s*(~~~+)")
        if fence then
            local character = fence:sub(1, 1)
            if not fence_character then
                fence_character = character
                fence_length = #fence
            elseif character == fence_character and #fence >= fence_length then
                fence_character = nil
                fence_length = 0
            end
        elseif not fence_character then
            local indentation, hashes, rest =
                line:match("^(%s*)(#+)(%s+.*)$")
            if hashes and #hashes <= 6 then
                local level = math.min(6, #hashes + shift)
                lines[index] = indentation ..
                    string.rep("#", level) ..
                    rest
            end
        end
    end
    return table.concat(lines, "\n")
end

--- The whole site's types, so a page documenting none of its own still links
--- the ones it mentions.
---
--- A guide is prose with code in it and declares no API, so it had no view,
--- and with no view no links: every example on every guide page went unlinked
--- while the module pages beside them were fully linked. The names come from
--- the registry rather than from the pages, because the registry is what the
--- pages are rendered from.
---
--- A name two modules both declare resolves to neither. That is
--- `add_spelling`'s rule, and it matters more here than on a page, where a
--- name is usually unambiguous inside one module and only collides across the
--- site: `Event` is three different records.
---
--- `public_paths` carries a source path to the path the site publishes it
--- under, because this registry is the one the parser filled and its keys are
--- where a type is declared rather than where a reader reaches it. The public
--- path is the qualified spelling registered, and the source path is not: a
--- route through internals is not something a page describes, and a reader
--- who follows one arrives at a page that never mentions it.
---
--- Only the whole public path and the bare name, with nothing in between. A
--- page carries the scope its own shorter spellings are relative to and
--- `type_links` registers those; a page reaching another module's type has no
--- such scope, and a tail like `Window.Options` names one type on the window
--- page and is a coincidence anywhere else.
function SiteApi.site_type_links(
    env: tealdoc.Env,
    resolver: MarkdownGenerator.URLResolver,
    public_paths?: {string: string}
): Highlighter.Links
    local links: Highlighter.Links = {}
    local ambiguous: {string: boolean} = {}
    for path, item in pairs(env.registry) do
        if item is tealdoc.TypeItem and Generator.filter(item, env) then
            add_spelling(links, ambiguous, item.name, resolver(path))
            add_spelling(
                links,
                ambiguous,
                public_paths and public_paths[path],
                resolver(path)
            )
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

local function group_details(
    markdown: string,
    view: SiteTypes.ApiView
): string
    local env = view.env
    local module = env.registry[view.public]
    if not module or not module.children then
        return ""
    end

    local positioned: {{tealdoc.Item, integer}} = {}
    for _, path in ipairs(module.children) do
        local item = env.registry[path]
        if item and Generator.filter(item, env) then
            local anchor = '<a id="' .. path .. '"></a>'
            local start = markdown:find(anchor, 1, true)
            if start then
                table.insert(positioned, {item, start})
            end
        end
    end
    table.sort(
        positioned,
        function(
            left: {tealdoc.Item, integer},
            right: {tealdoc.Item, integer}
        ): boolean
            return left[2] < right[2]
        end
    )

    local details: {string: string} = {}
    for index, entry in ipairs(positioned) do
        local ending = index < #positioned
            and positioned[index + 1][2] - 1
            or #markdown
        details[entry[1].path] = markdown:sub(entry[2], ending)
            :gsub("^%s+", "")
            :gsub("%s+$", "")
    end

    local items: {tealdoc.Item} = {}
    for _, entry in ipairs(positioned) do
        table.insert(items, entry[1])
    end
    table.sort(items, function(a: tealdoc.Item, b: tealdoc.Item): boolean
        local left = a.name:lower()
        local right = b.name:lower()
        if left == right then
            return a.path < b.path
        end
        return left < right
    end)

    local groups: {{string, {tealdoc.Item}}} = {
        { "Functions", {} },
        { "Types", {} },
        { "Values", {} },
    }
    for _, item in ipairs(items) do
        local kind = Generator.item_kind(item, env)
        local group = 3
        if FUNCTION_KINDS[kind] then
            group = 1
        elseif item is tealdoc.TypeItem then
            group = 2
        end
        table.insert(groups[group][2], item)
    end

    local output: {string} = {}
    for _, group in ipairs(groups) do
        if #group[2] > 0 then
            table.insert(output, "## " .. group[1])
            for _, item in ipairs(group[2]) do
                table.insert(output, details[item.path])
            end
        end
    end
    return table.concat(output, "\n\n")
end

function SiteApi.markdown(
    view: SiteTypes.ApiView,
    resolver: MarkdownGenerator.URLResolver,
    attached_examples: {string: {SiteTypes.PreparedExample}},
    used_examples: {string: boolean},
    format_code?: function(string): string
): string, string
    if not view then
        return "", ""
    end

    local page_env = view.env

    local original_texts: {{tealdoc.Item, string}} = {}
    for _, item in pairs(page_env.registry) do
        if item.kind ~= "module" and item.text and item.text ~= "" then
            table.insert(original_texts, {item, item.text})
            item.text = rebase_headings(item.text, 3)
        end
    end
    local markdown = add_kind_badges(
        MarkdownGenerator.render(page_env, resolver, false, format_code),
        page_env
    )
    for _, entry in ipairs(original_texts) do
        entry[1].text = entry[2]
    end

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

    local public_anchor = '<a id="' .. view.public .. '"></a>'
    local _, public_end = markdown:find(public_anchor, 1, true)
    if public_end then
        markdown = markdown:sub(public_end + 1)
    end
    local module_item = page_env.registry["$" .. view.public]
    local introduction = module_item and module_item.text
        and rebase_headings(module_item.text, 2)
        or ""
    markdown = "\n" .. markdown
    markdown = markdown:gsub("\n(##+) ", function(level: string): string
        return "\n" .. string.rep("#", math.min(#level + 1, 6)) .. " "
    end)
    return group_details(markdown:sub(2), view), introduction
end

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
    local prefix = item is tealdoc.VariableItem
        and item.is_const
        and "`<const>` "
        or ""
    local text = item_text(item, env)
    if text == "" then
        return prefix .. "—"
    end
    text = text:gsub("```[%s%S]-```", " ")
    text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
    text = text:gsub("`([^`]*)`", "%1")
    text = text:gsub("<[^>]+>", " ")
    text = text:gsub("[%*~]", "")
    text = text:gsub("^%s*#+%s*", "")
    text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    local sentences = 1
    if text:match("^Read%-only%.%s")
        or text:match("^Caller%-writable%.%s")
        or text:match("^Engine%-owned%.%s")
    then
        sentences = 2
    end
    local found = 0
    for index = 1, #text do
        local character = text:sub(index, index)
        local following = text:sub(index + 1, index + 1)
        if (character == "." or character == "!" or character == "?")
            and (following == "" or following:match("%s"))
        then
            found = found + 1
            if found == sentences then
                text = text:sub(1, index)
                break
            end
        end
    end

    local maximum = 120
    if #text > maximum then
        local shortened = text:sub(1, maximum - 3)
        shortened = shortened:match("^(.*)%s+%S*$") or shortened
        text = shortened:gsub("%s+$", "") .. "..."
    end
    return prefix .. (text:gsub("\\", "\\\\"):gsub("|", "\\|"))
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
    -- A kind column earns its place where the group holds more than one kind:
    -- a type is a record or an interface or an enum, a value is a field or a
    -- variable. Everything under Functions is called the same way whatever
    -- `item_kind` names it, and the detail below carries the badge anyway, so
    -- a column there would repeat the heading on every row.
    local groups: {{string, string, boolean, {tealdoc.Item}}} = {
        { "Functions", "Function", false, {} },
        { "Types", "Type", true, {} },
        { "Values", "Value", true, {} },
    }
    for _, item in ipairs(items) do
        local kind = Generator.item_kind(item, env)
        local group = 3
        if FUNCTION_KINDS[kind] then
            group = 1
        elseif item is tealdoc.TypeItem then
            group = 2
        end
        table.insert(groups[group][4], item)
    end

    local output: {string} = {}
    for _, group in ipairs(groups) do
        local heading, column = group[1], group[2]
        local show_kind, group_items = group[3], group[4]
        if #group_items > 0 then
            if #output > 0 then
                table.insert(output, "\n")
            end
            table.insert(output, "**" .. heading .. "**\n\n")
            if show_kind then
                table.insert(
                    output,
                    "| " .. column .. " | Kind | Description |\n"
                )
                table.insert(output, "| --- | --- | --- |\n")
            else
                table.insert(output, "| " .. column .. " | Description |\n")
                table.insert(output, "| --- | --- |\n")
            end
            for _, item in ipairs(group_items) do
                local url = resolver(item.path) or "#" .. item.path
                local cells = "| [`" .. item.name .. "`](" .. url .. ") | "
                if show_kind then
                    local kind = Generator.item_kind(item, env)
                    cells = cells ..
                        '<span class="tealdoc-kind-badge tealdoc-kind-' ..
                        kind ..
                        '">' ..
                        kind ..
                        "</span> | "
                end
                table.insert(
                    output,
                    cells ..
                        item_summary(item, env) ..
                        " |\n"
                )
            end
        end
    end
    return table.concat(output)
end

return SiteApi
