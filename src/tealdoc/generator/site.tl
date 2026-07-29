local tealdoc = require("tealdoc")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local Text = require("tealdoc.generator.text")
local default_css = require("tealdoc.generator.site.default_css")
local default_js = require("tealdoc.generator.site.default_js")
local pico_css = require("tealdoc.generator.site.pico_css")
local Highlighter = require("tealdoc.generator.site.highlighter")
local PageTemplate = require("tealdoc.generator.site.page_template")
local SiteApi = require("tealdoc.generator.site.api")
local SiteConfig = require("tealdoc.generator.site.config")
local SiteExamples = require("tealdoc.generator.site.examples")
local SiteMarkdown = require("tealdoc.generator.site.markdown")
local SiteTypes = require("tealdoc.generator.site.types")
local SiteValidator = require("tealdoc.generator.site.validator")
local SiteView = require("tealdoc.generator.site.view")
local lfs = require("lfs")

local record SiteGenerator
    type Link = SiteTypes.Link
    type Feature = SiteTypes.Feature
    type HeadEntry = SiteTypes.HeadEntry
    type Page = SiteTypes.Page
    type Example = SiteTypes.Example
    type Settings = SiteTypes.Settings
    type Context = SiteTypes.Context

    build: function(
        output: string,
        env: tealdoc.Env,
        settings: Settings,
        config_directory?: string
    )
    source_files: function(settings: Settings, config_directory?: string): {string}
end

local record Heading
    id: string
    title: string
    level: integer
end

local record SearchEntry
    title: string
    url: string
    text: string
end

local type PreparedExample = SiteTypes.PreparedExample

local function read_file(path: string): string
    local file = assert(io.open(path, "rb"), "Could not open " .. path)
    local contents = assert(file:read("*a"), "Could not read " .. path)
    file:close()
    return contents
end

local function append_custom_css(css: string, custom: string): string
    local imports: {string} = {}
    while true do
        local first, last, statement = custom:find(
            "^%s*(@import%s+[^;]+;)"
        )
        if not first then
            break
        end
        table.insert(imports, statement)
        custom = custom:sub(last + 1)
    end
    local prefix = ""
    if #imports > 0 then
        prefix = table.concat(imports, "\n") .. "\n\n"
    end
    return prefix .. css .. "\n" .. custom:gsub("^%s+", "")
end

local function write_file(path: string, contents: string)
    local file = assert(io.open(path, "wb"), "Could not write " .. path)
    file:write(contents)
    file:close()
end

local function mkdir_p(path: string)
    local separator = package.config:sub(1, 1)
    local current = path:match("^[/\\]") and separator or ""
    for part in path:gmatch("[^/\\]+") do
        if current == "" or current == separator then
            current = current .. part
        else
            current = current .. separator .. part
        end
        lfs.mkdir(current)
    end
end

local function copy_public_directory(
    source: string,
    destination: string,
    files: {string}
)
    local attributes = assert(
        lfs.symlinkattributes(source),
        "Could not read public path " .. source
    )
    assert(
        attributes.mode == "directory",
        "tealdoc.site.public must name a directory"
    )

    local entries: {string} = {}
    for entry in lfs.dir(source) do
        if entry ~= "." and entry ~= ".." then
            table.insert(entries, entry)
        end
    end
    table.sort(entries)

    for _, entry in ipairs(entries) do
        local source_path = source .. "/" .. entry
        local destination_path = destination .. "/" .. entry
        local entry_attributes = assert(
            lfs.symlinkattributes(source_path),
            "Could not read public path " .. source_path
        )
        assert(
            entry_attributes.mode ~= "link",
            "public assets may not contain symbolic links: " .. source_path
        )
        if entry_attributes.mode == "directory" then
            mkdir_p(destination_path)
            copy_public_directory(source_path, destination_path, files)
        elseif entry_attributes.mode == "file" then
            write_file(destination_path, read_file(source_path))
            table.insert(files, destination_path)
        else
            error("unsupported public asset: " .. source_path)
        end
    end
end

local escape_html = Text.escape_html
local strip_tags = Text.strip_tags
local plain_text = Text.plain_text
local slug = Text.slug

local function page_url(base: string, path: string): string
    local root = base or "/"
    if root:sub(-1) ~= "/" then
        root = root .. "/"
    end
    if path == "" then
        return root
    end
    return root .. path:gsub("^/+", "") .. "/"
end

local function root_file_url(base: string, path: string): string
    if path:match("^https?://")
        or path:match("^data:")
        or path:sub(1, 1) == "/"
    then
        return path
    end
    local root = page_url(base, "")
    return root .. path:gsub("^/+", "")
end

local function absolute_url(site_url: string, path: string): string
    if not path or path == "" then
        return nil
    end
    if path:match("^https?://") then
        return path
    end
    if not site_url or site_url == "" then
        return path
    end
    local origin = site_url:gsub("/+$", "")
    return origin .. "/" .. path:gsub("^/+", "")
end

local function canonical_url(
    settings: SiteGenerator.Settings,
    page: SiteGenerator.Page
): string
    if page.canonical and page.canonical ~= "" then
        return absolute_url(settings.site_url, page.canonical)
    end
    if settings.site_url and settings.site_url ~= "" then
        return absolute_url(
            settings.site_url,
            page_url(settings.base, page.path)
        )
    end
    return nil
end

local function link_url(base: string, path: string): string
    if path:match("^%a[%w+.-]*:")
        or path:sub(1, 2) == "//"
        or path:sub(1, 1) == "#"
        or path:sub(1, 1) == "?"
    then
        return path
    end
    local target, suffix = path:match("^([^?#]*)(.*)$")
    local filename = target:match("([^/]+)$")
    if filename and filename:find("%.") then
        return root_file_url(base, target) .. suffix
    end
    return page_url(base, target) .. suffix
end

local function markdown_url(base: string, path: string): string
    local root = page_url(base, "")
    if not path or path == "" then
        return root .. "index.md"
    end
    return root .. path:gsub("^/+", ""):gsub("/+$", "") .. ".md"
end

local function validated_redirects(
    pages: {SiteGenerator.Page},
    redirects: {string: string}
): {string: string}
    local routes: {string: string} = {}
    for _, page in ipairs(pages) do
        local original = page.path or ""
        local normalized = SiteConfig.normalize_route(
            original,
            "page route",
            true
        )
        assert(
            routes[normalized] == nil,
            "duplicate normalized page or example route: " .. original
        )
        routes[normalized] = "page"
        page.path = normalized
    end

    local normalized_redirects: {string: string} = {}
    for source, target in pairs(redirects or {}) do
        local normalized = SiteConfig.normalize_route(
            source,
            "redirect source",
            false
        )
        assert(
            routes[normalized] == nil,
            "duplicate normalized page, example, or redirect route: " .. source
        )
        routes[normalized] = "redirect"
        if not target:match("^https?://") then
            local target_route = target
            if target_route:sub(1, 1) == "/" then
                target_route = target_route:sub(2)
            end
            SiteConfig.normalize_route(
                target_route,
                "redirect target",
                true
            )
        end
        normalized_redirects[normalized] = target
    end
    return normalized_redirects
end

local function validate_output_routes(
    pages: {SiteGenerator.Page},
    redirects: {string: string},
    has_not_found: boolean
)
    local outputs: {string: string} = {}
    local function claim(path: string, owner: string)
        assert(
            outputs[path] == nil,
            owner ..
                " conflicts with " ..
                tostring(outputs[path]) ..
                " at output path " ..
                path
        )
        outputs[path] = owner
    end
    for _, page in ipairs(pages) do
        local route = page.path or ""
        local owner = route == "" and "home page" or "page " .. route
        claim(route == "" and "index.html" or route .. "/index.html", owner)
        claim(route == "" and "index.md" or route .. ".md", owner)
        claim(route == "" and "llms.txt" or route .. "/llms.txt", owner)
    end
    for route in pairs(redirects or {}) do
        local path = route:match("%.html$")
            and route
            or route .. "/index.html"
        claim(path, "redirect " .. route)
    end
    if has_not_found then
        claim("404.html", "custom 404 page")
        claim("404.md", "custom 404 page")
        claim("404/llms.txt", "custom 404 page")
    end
end

local function discover_source(path: string, files: {string})
    local attributes = lfs.symlinkattributes(path)
    assert(attributes, "configured Teal source does not exist: " .. path)
    assert(
        attributes.mode ~= "link",
        "configured Teal sources may not be symbolic links: " .. path
    )
    if attributes.mode == "file" then
        assert(
            path:match("%.tl$"),
            "configured Teal source is not a .tl file: " .. path
        )
        table.insert(files, path)
        return
    end
    assert(
        attributes.mode == "directory",
        "configured Teal source is not a file or directory: " .. path
    )
    local entries: {string} = {}
    for entry in lfs.dir(path) do
        if entry ~= "." and entry ~= ".." then
            table.insert(entries, entry)
        end
    end
    table.sort(entries)
    for _, entry in ipairs(entries) do
        local child = SiteConfig.join_path(path, entry)
        local child_attributes = lfs.symlinkattributes(child)
        assert(
            not child_attributes or child_attributes.mode ~= "link",
            "configured Teal sources may not be symbolic links: " .. child
        )
        if child_attributes and child_attributes.mode == "directory" then
            discover_source(child, files)
        elseif child_attributes
            and child_attributes.mode == "file"
            and child:match("%.tl$")
        then
            table.insert(files, child)
        end
    end
end

function SiteGenerator.source_files(
    raw: SiteGenerator.Settings,
    config_directory?: string
): {string}
    local settings = SiteConfig.configure(raw, config_directory)
    local files: {string} = {}
    local seen: {string: boolean} = {}
    for _, source in ipairs(settings.sources) do
        local discovered: {string} = {}
        discover_source(source, discovered)
        for _, file in ipairs(discovered) do
            if not seen[file] then
                seen[file] = true
                table.insert(files, file)
            end
        end
    end
    return files
end

local function routes_for_pages(
    pages: {SiteGenerator.Page},
    views: {string: SiteTypes.ApiView},
    base: string
): MarkdownGenerator.URLResolver
    local routes: {string: string} = {}
    local owners: {string: string} = {}
    local function add(path: string, url: string, owner: string)
        if routes[path] then
            assert(
                routes[path] == url,
                "public API path " ..
                    path ..
                    " is rendered by both " ..
                    owners[path] ..
                    " and " ..
                    owner
            )
            return
        end
        routes[path] = url
        owners[path] = owner
    end

    for _, page in ipairs(pages) do
        local view = views[page.path]
        if view then
            local page_root = page_url(base, page.path)
            add(view.public, page_root, page.path)
            for source_path, public_path in pairs(view.source_to_public) do
                local url = page_root
                if public_path ~= view.public then
                    url = url .. "#" .. public_path
                end
                add(source_path, url, page.path)
                add(public_path, url, page.path)
            end
        end
    end

    return function(path: string): string
        return routes[path]
    end
end

local function headings(html: string): string, string, {Heading}
    local outline: {string} = {}
    local found: {Heading} = {}
    local used: {string: boolean} = {}
    local explicit: {string: boolean} = {}
    for attributes in html:gmatch("<h[1-6]([^>]*)>") do
        local id = attributes:match(' id="([^"]+)"')
        if id then
            assert(not explicit[id], "duplicate explicit heading id: " .. id)
            explicit[id] = true
            used[id] = true
        end
    end
    local parent = ""
    local outline_prefix = ""
    local with_ids = html:gsub(
        "<h([1-4])([^>]*)>(.-)</h%1>",
        function(
            level_text: string,
            attributes: string,
            content: string
        ): string
            local level = tonumber(level_text) as integer
            local id = attributes:match(' id="([^"]+)"')
            local natural = attributes:match(
                ' data%-tealdoc%-heading%-slug="([^"]*)"'
            )
            attributes = attributes:gsub('%s+id="[^"]*"', "")
                :gsub('%s+data%-tealdoc%-heading%-slug="[^"]*"', "")
            if not id then
                id = natural or slug(content)
                if level == 4
                    and (id == "arguments" or id == "returns")
                    and parent ~= ""
                then
                    id = parent .. "-" .. id
                end
                if id == "" then
                    id = "section"
                end
                local base = id
                local suffix = 1
                while used[id] do
                    suffix = suffix + 1
                    id = base .. "-" .. tostring(suffix)
                end
                used[id] = true
            end
            if level == 2 or level == 3 then
                parent = id
                local title = strip_tags(content)
                local outline_title = title
                if level == 2 then
                    outline_prefix = ""
                elseif outline_prefix ~= ""
                    and title:sub(1, #outline_prefix + 1)
                        == outline_prefix .. "."
                then
                    outline_title = "↳ " ..
                        title:sub(#outline_prefix + 2)
                else
                    outline_prefix = title:match("^(.*)%.") or ""
                end
                table.insert(found, {
                    id = id,
                    title = title,
                    level = level,
                })
                table.insert(
                    outline,
                    '<li class="level-' ..
                        level_text ..
                        '"><a href="#' ..
                        escape_html(id) ..
                        '\" title=\"' ..
                        escape_html(title) ..
                        '\" aria-label=\"' ..
                        escape_html(title) ..
                        '">' ..
                        escape_html(outline_title) ..
                        "</a></li>"
                )
            end

            local label = "Permalink to " .. strip_tags(content)
            return "<h" ..
                level_text ..
                attributes ..
                ' id="' ..
                escape_html(id) ..
                '" tabindex="-1">' ..
                content ..
                '<a class="tealdoc-header-anchor" href="#' ..
                escape_html(id) ..
                '" aria-label="' ..
                escape_html(label) ..
                '"><span aria-hidden="true">#</span></a></h' ..
                level_text ..
                ">"
        end
    )
    return with_ids, table.concat(outline, "\n"), found
end

local function navigation(
    links: {SiteGenerator.Link},
    current: string,
    base: string
): string
    local output: {string} = {}
    for _, link in ipairs(links or {}) do
        local selected = link.path == current and ' aria-current="page"' or ""
        table.insert(
            output,
            '<a href="' ..
                escape_html(page_url(base, link.path)) ..
                '"' ..
                selected ..
                ">" ..
                escape_html(link.text) ..
                "</a>"
        )
    end
    return table.concat(output, "\n")
end

local function sidebar_page(
    page: SiteGenerator.Page,
    current: string,
    base: string
): string
    local selected = page.path == current and ' aria-current="page"' or ""
    return '<li><a href="' ..
        escape_html(page_url(base, page.path)) ..
        '"' ..
        selected ..
        ">" ..
        escape_html(page.title) ..
        "</a></li>"
end

local function group_title(path: string): string
    local title = path:gsub("[_-]+", " ")
    return title:sub(1, 1):upper() .. title:sub(2)
end

local function sidebar(
    pages: {SiteGenerator.Page},
    current: string,
    base: string,
    configured: {SiteTypes.SidebarItem}
): string
    if configured and #configured > 0 then
        local contains_current: function(SiteTypes.SidebarItem): boolean
        contains_current = function(item: SiteTypes.SidebarItem): boolean
            if item.path == current then
                return true
            end
            for _, child in ipairs(item.items or {}) do
                if contains_current(child) then
                    return true
                end
            end
            return false
        end

        local render_item: function(SiteTypes.SidebarItem): string
        render_item = function(item: SiteTypes.SidebarItem): string
            if not item.items or #item.items == 0 then
                local selected = item.path == current
                    and ' aria-current="page"'
                    or ""
                return '<li><a href="' ..
                    escape_html(page_url(base, item.path)) ..
                    '"' ..
                    selected ..
                    ">" ..
                    escape_html(item.text) ..
                    "</a></li>"
            end

            local children: {string} = {}
            if item.path then
                local selected = item.path == current
                    and ' aria-current="page"'
                    or ""
                table.insert(
                    children,
                    '<li><a href="' ..
                        escape_html(page_url(base, item.path)) ..
                        '"' ..
                        selected ..
                        ">Overview</a></li>"
                )
            end
            for _, child in ipairs(item.items) do
                table.insert(children, render_item(child))
            end
            local open = not item.collapsed or contains_current(item)
            return '<li class="tealdoc-sidebar-section"><details' ..
                (open and " open" or "") ..
                "><summary>" ..
                escape_html(item.text) ..
                "</summary><ul>" ..
                table.concat(children, "\n") ..
                "</ul></details></li>"
        end

        local explicit: {string} = {}
        for _, item in ipairs(configured) do
            table.insert(explicit, render_item(item))
        end
        return table.concat(explicit, "\n")
    end

    local output: {string} = {}
    local groups: {string: {SiteGenerator.Page}} = {}
    local group_order: {string} = {}
    for _, page in ipairs(pages) do
        if page.path and page.path ~= "" then
            local group = page.path:match("^([^/]+)/")
            if group then
                if not groups[group] then
                    groups[group] = {}
                    table.insert(group_order, group)
                end
                table.insert(groups[group], page)
            else
                table.insert(output, sidebar_page(page, current, base))
            end
        end
    end
    for _, group in ipairs(group_order) do
        local children: {string} = {}
        for _, page in ipairs(groups[group]) do
            table.insert(children, sidebar_page(page, current, base))
        end
        table.insert(
            output,
            '<li class="tealdoc-sidebar-section"><details open><summary>' ..
                escape_html(group_title(group)) ..
                "</summary><ul>" ..
                table.concat(children, "\n") ..
                "</ul></details></li>"
        )
    end
    return table.concat(output, "\n")
end

local function breadcrumbs(
    page: SiteGenerator.Page,
    pages: {SiteGenerator.Page},
    base: string
): string
    if not page.path or page.path == "" then
        return ""
    end

    local pages_by_path: {string: SiteGenerator.Page} = {}
    for _, candidate in ipairs(pages) do
        pages_by_path[candidate.path or ""] = candidate
    end

    local items: {string} = {
        '<li><a href="' ..
            escape_html(page_url(base, "")) ..
            '">Home</a></li>',
    }
    local segments: {string} = {}
    for segment in page.path:gmatch("[^/]+") do
        table.insert(segments, segment)
    end
    local path = ""
    for index, segment in ipairs(segments) do
        path = path == "" and segment or path .. "/" .. segment
        if index == #segments then
            table.insert(
                items,
                '<li><span aria-current="page">' ..
                    escape_html(page.title) ..
                    "</span></li>"
            )
        else
            local ancestor = pages_by_path[path]
            if ancestor then
                table.insert(
                    items,
                    '<li><a href="' ..
                        escape_html(page_url(base, ancestor.path)) ..
                        '">' ..
                        escape_html(ancestor.title) ..
                        "</a></li>"
                )
            else
                table.insert(
                    items,
                    "<li><span>" ..
                        escape_html(group_title(segment)) ..
                        "</span></li>"
                )
            end
        end
    end
    return '<nav class="tealdoc-breadcrumbs" aria-label="Breadcrumb"><ol>' ..
        table.concat(items) ..
        "</ol></nav>"
end

local function search_dialog(search_index_url: string): string
    return [[
<dialog class="tealdoc-search-dialog" aria-label="Search documentation" data-tealdoc-search-index="]] ..
        escape_html(search_index_url) ..
        [[">
<section class="tealdoc-search-panel">
<header><label><span aria-hidden="true">⌕</span><input type="search" placeholder="Search documentation" autocomplete="off" aria-label="Search documentation"></label><button type="button" data-tealdoc-search-close aria-label="Close search">Esc</button></header>
<nav class="tealdoc-search-results" aria-live="polite"></nav>
</section>
</dialog>
]]
end

local function page_navigation(
    page: SiteGenerator.Page,
    pages: {SiteGenerator.Page},
    base: string
): string
    local previous: SiteGenerator.Page
    local following: SiteGenerator.Page
    for index, candidate in ipairs(pages) do
        if candidate == page then
            previous = pages[index - 1]
            following = pages[index + 1]
            break
        end
    end
    if not previous and not following then
        return ""
    end

    local output: {string} = {
        '<nav class="tealdoc-page-nav" aria-label="Adjacent pages">',
    }
    if previous then
        table.insert(
            output,
            '<a class="previous" href="' ..
                escape_html(page_url(base, previous.path)) ..
                '"><span>Previous page</span><strong>← ' ..
                escape_html(previous.title) ..
                "</strong></a>"
        )
    else
        table.insert(output, "<span></span>")
    end
    if following then
        table.insert(
            output,
            '<a class="next" href="' ..
                escape_html(page_url(base, following.path)) ..
                '"><span>Next page</span><strong>' ..
                escape_html(following.title) ..
                " →</strong></a>"
        )
    end
    table.insert(output, "</nav>")
    return table.concat(output)
end

local safe_head_attributes: {string: {string: boolean}} = {
    ["link"] = {
        ["as"] = true,
        ["crossorigin"] = true,
        ["href"] = true,
        ["hreflang"] = true,
        ["media"] = true,
        ["referrerpolicy"] = true,
        ["rel"] = true,
        ["sizes"] = true,
        ["title"] = true,
        ["type"] = true,
    },
    ["meta"] = {
        ["content"] = true,
        ["name"] = true,
        ["property"] = true,
    },
}

local function custom_head_entry(entry: SiteGenerator.HeadEntry): string
    assert(
        entry.tag == "link" or entry.tag == "meta",
        "tealdoc.site.head entries must use the link or meta tag"
    )
    assert(
        type(entry.attributes) == "table",
        "tealdoc.site.head entry attributes must be a table"
    )
    local allowed = safe_head_attributes[entry.tag]
    local names: {string} = {}
    for name, value in pairs(entry.attributes) do
        assert(
            allowed[name] == true,
            "unsafe " .. entry.tag .. " head attribute: " .. tostring(name)
        )
        assert(
            type(value) == "string",
            "head attribute values must be strings"
        )
        assert(
            not value:find("[%z\1-\31]"),
            "head attribute values may not contain control characters"
        )
        if name == "href" then
            assert(
                not value:lower():match("^%s*javascript:"),
                "javascript URLs are not allowed in head entries"
            )
        end
        table.insert(names, name)
    end
    table.sort(names)
    if entry.tag == "link" then
        assert(
            entry.attributes.rel and entry.attributes.href,
            "link head entries require rel and href"
        )
    else
        assert(
            entry.attributes.content
                and (
                    entry.attributes.name
                    or entry.attributes.property
                ),
            "meta head entries require content and name or property"
        )
    end

    local output: {string} = {"<", entry.tag}
    for _, name in ipairs(names) do
        table.insert(
            output,
            " " ..
                name ..
                '="' ..
                escape_html(entry.attributes[name]) ..
                '"'
        )
    end
    table.insert(output, ">")
    return table.concat(output)
end

local function page_head(
    settings: SiteGenerator.Settings,
    page: SiteGenerator.Page
): string
    local output: {string} = {}
    local description = page.description or settings.description or ""
    local canonical = canonical_url(settings, page)
    local markdown = markdown_url(settings.base, page.path)
    local image = page.image or settings.social_image

    if settings.favicon and settings.favicon ~= "" then
        table.insert(
            output,
            '<link rel="icon" href="' ..
                escape_html(root_file_url(settings.base, settings.favicon)) ..
                '">'
        )
    end
    if canonical then
        table.insert(
            output,
            '<link rel="canonical" href="' ..
                escape_html(canonical) ..
                '">'
        )
    end
    table.insert(
        output,
        '<link rel="alternate" type="text/markdown" href="' ..
            escape_html(absolute_url(settings.site_url, markdown)) ..
            '" title="' ..
            escape_html(page.title .. " as Markdown") ..
            '">'
    )
    if settings.author and settings.author ~= "" then
        table.insert(
            output,
            '<meta name="author" content="' ..
                escape_html(settings.author) ..
                '">'
        )
    end
    if page.noindex then
        table.insert(output, '<meta name="robots" content="noindex, nofollow">')
    end
    table.insert(
        output,
        '<meta property="og:site_name" content="' ..
            escape_html(settings.title) ..
            '">'
    )
    table.insert(
        output,
        '<meta property="og:title" content="' ..
            escape_html(page.title) ..
            '">'
    )
    table.insert(
        output,
        '<meta property="og:description" content="' ..
            escape_html(description) ..
            '">'
    )
    table.insert(
        output,
        '<meta property="og:locale" content="' ..
            escape_html(((settings.language or "en"):gsub("%-", "_"))) ..
            '">'
    )
    table.insert(
        output,
        '<meta property="og:type" content="' ..
            (page.layout == "home" and "website" or "article") ..
            '">'
    )
    if canonical then
        table.insert(
            output,
            '<meta property="og:url" content="' ..
                escape_html(canonical) ..
                '">'
        )
    end
    if image and image ~= "" then
        local image_url = absolute_url(
            settings.site_url,
            root_file_url(settings.base, image)
        )
        table.insert(
            output,
            '<meta property="og:image" content="' ..
                escape_html(image_url) ..
                '">'
        )
    end
    table.insert(
        output,
        '<meta name="twitter:card" content="' ..
            (image and image ~= "" and "summary_large_image" or "summary") ..
            '">'
    )
    table.insert(
        output,
        '<meta name="twitter:title" content="' ..
            escape_html(page.title) ..
            '">'
    )
    table.insert(
        output,
        '<meta name="twitter:description" content="' ..
            escape_html(description) ..
            '">'
    )
    if image and image ~= "" then
        local image_url = absolute_url(
            settings.site_url,
            root_file_url(settings.base, image)
        )
        table.insert(
            output,
            '<meta name="twitter:image" content="' ..
                escape_html(image_url) ..
                '">'
        )
    end
    if settings.twitter_site and settings.twitter_site ~= "" then
        table.insert(
            output,
            '<meta name="twitter:site" content="' ..
                escape_html(settings.twitter_site) ..
                '">'
        )
    end
    for _, entry in ipairs(settings.head or {}) do
        table.insert(output, custom_head_entry(entry))
    end
    return table.concat(output, "\n")
end

local function footer_items(
    settings: SiteGenerator.Settings,
    page: SiteGenerator.Page
): string
    local parts: {string} = {}
    if settings.copyright then
        table.insert(
            parts,
            '<span class="tealdoc-footer-copyright">' ..
                escape_html(settings.copyright) ..
                "</span>"
        )
    end
    if settings.license then
        table.insert(
            parts,
            '<span class="tealdoc-footer-license">' ..
                escape_html(settings.license) ..
                "</span>"
        )
    end
    for _, link in ipairs(settings.footer_links or {}) do
        table.insert(
            parts,
            '<a class="tealdoc-footer-link" href="' ..
                escape_html(link_url(settings.base, link.path)) ..
                '">' ..
                escape_html(link.text) ..
                "</a>"
        )
    end
    table.insert(
        parts,
        '<a class="tealdoc-footer-llms" href="' ..
            escape_html(page_url(settings.base, page.path) .. "llms.txt") ..
            '">llms.txt</a>'
    )
    table.insert(
        parts,
        '<span class="tealdoc-footer-credit">Generated by <a href="https://github.com/teal-language/tealdoc">Tealdoc</a></span>'
    )
    return table.concat(parts, '<span aria-hidden="true">·</span>')
end

local function icon(name: string): string
    if name == "github" then
        return [[<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 .7a11.5 11.5 0 0 0-3.64 22.4c.58.1.79-.25.79-.56v-2.23c-3.24.7-3.92-1.38-3.92-1.38-.53-1.35-1.29-1.71-1.29-1.71-1.06-.72.08-.71.08-.71 1.17.08 1.79 1.2 1.79 1.2 1.04 1.79 2.73 1.27 3.4.97.1-.76.41-1.27.74-1.56-2.58-.29-5.3-1.29-5.3-5.7 0-1.26.45-2.29 1.2-3.1-.12-.3-.52-1.48.11-3.07 0 0 .98-.31 3.16 1.18a10.9 10.9 0 0 1 5.76 0c2.18-1.49 3.15-1.18 3.15-1.18.64 1.59.24 2.77.12 3.07.74.81 1.19 1.84 1.19 3.1 0 4.42-2.72 5.4-5.31 5.69.42.36.79 1.07.79 2.16v3.2c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .7Z"/></svg>]]
    elseif name == "markdown" then
        return [[<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M2.5 5.25h19A2.5 2.5 0 0 1 24 7.75v8.5a2.5 2.5 0 0 1-2.5 2.5h-19A2.5 2.5 0 0 1 0 16.25v-8.5a2.5 2.5 0 0 1 2.5-2.5Zm.5 3v7.5h2v-4l2 2 2-2v4h2v-7.5H9l-2 2-2-2H3Zm11 3.75h2.5v3.75h2V12H21l-3.5-3.5L14 12Z"/></svg>]]
    elseif name == "sun" then
        return [[<svg class="tealdoc-theme-icon-sun" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 4a1 1 0 0 1-1-1V1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1Zm0 19a1 1 0 0 1-1-1v-2a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1ZM4.22 5.64a1 1 0 0 1-.71-.29L2.1 3.93a1 1 0 0 1 1.41-1.41l1.42 1.41a1 1 0 0 1-.71 1.71Zm16.97 16.97a1 1 0 0 1-.71-.29l-1.41-1.42a1 1 0 0 1 1.41-1.41l1.42 1.41a1 1 0 0 1-.71 1.71ZM1 13a1 1 0 1 1 0-2h2a1 1 0 1 1 0 2H1Zm20 0a1 1 0 1 1 0-2h2a1 1 0 1 1 0 2h-2ZM2.81 22.61a1 1 0 0 1-.71-1.71l1.41-1.41a1 1 0 0 1 1.42 1.41l-1.42 1.42a1 1 0 0 1-.7.29ZM19.78 5.64a1 1 0 0 1-.71-1.71l1.41-1.41a1 1 0 0 1 1.42 1.41l-1.42 1.42a1 1 0 0 1-.7.29ZM12 18a6 6 0 1 1 0-12 6 6 0 0 1 0 12Zm0-10a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"/></svg>]]
    elseif name == "moon" then
        return [[<svg class="tealdoc-theme-icon-moon" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M21.64 15.36A9 9 0 0 1 8.64 2.36 10 10 0 1 0 21.64 15.36ZM12 22A8 8 0 0 1 7.45 7.42a11 11 0 0 0 9.13 9.13A7.94 7.94 0 0 1 12 22Z"/></svg>]]
    end
    return ""
end

local function brand(settings: SiteGenerator.Settings): string
    local contents: {string} = {}
    if settings.logo then
        table.insert(
            contents,
            '<img class="tealdoc-logo" src="' ..
                escape_html(settings.logo) ..
                '" alt="">'
        )
    end
    local name = settings.name
    if name == nil then
        name = settings.title
    end
    if name ~= "" then
        table.insert(
            contents,
            '<span class="tealdoc-brand-name">' ..
                escape_html(name) ..
                "</span>"
        )
    end
    return '<a class="tealdoc-brand" href="' ..
        escape_html(page_url(settings.base, "")) ..
        '">' ..
        table.concat(contents) ..
        "</a>"
end

local function header_actions(
    settings: SiteGenerator.Settings,
    page: SiteGenerator.Page
): string
    local output: {string} = {}
    table.insert(
        output,
        '<a class="tealdoc-icon-link" href="' ..
            escape_html(markdown_url(settings.base, page.path)) ..
            '" aria-label="View this page as Markdown" title="View Markdown">' ..
            icon("markdown") ..
            "</a>"
    )
    table.insert(
        output,
        '<label class="tealdoc-icon-link tealdoc-theme-toggle" for="tealdoc-theme-input" aria-label="Toggle light and dark theme" title="Toggle theme">' ..
            icon("sun") ..
            icon("moon") ..
            "</label>"
    )
    if settings.github then
        table.insert(
            output,
            '<a class="tealdoc-icon-link" href="' ..
                escape_html(settings.github) ..
                '" aria-label="View this project on GitHub" title="GitHub">' ..
                icon("github") ..
                "</a>"
        )
    end
    return table.concat(output, "\n")
end

local function home_hero(
    page: SiteGenerator.Page,
    base: string,
    type_links: Highlighter.Links
): string
    local hero_main_class = "tealdoc-hero-main"
    if page.hero_image and page.hero_image ~= "" then
        hero_main_class = hero_main_class .. " has-image"
    end
    local output: {string} = {
        '<section class="tealdoc-home-hero"><div class="' ..
            hero_main_class ..
            '"><div class="tealdoc-hero-copy"><h1>',
        escape_html(page.hero_title or page.title),
        "</h1>",
    }
    if page.hero_text then
        table.insert(
            output,
            '<p class="tealdoc-hero-text">' ..
                escape_html(page.hero_text) ..
                "</p>"
        )
    end
    if page.hero_actions and #page.hero_actions > 0 then
        table.insert(output, '<div class="tealdoc-hero-actions">')
        for _, action in ipairs(page.hero_actions) do
            local theme = action.theme == "brand" and "brand" or "alt"
            table.insert(
                output,
                '<a class="tealdoc-hero-action ' ..
                    theme ..
                    '" href="' ..
                    escape_html(link_url(base, action.path)) ..
                    '">' ..
                    escape_html(action.text) ..
                    "</a>"
            )
        end
        table.insert(output, "</div>")
    end
    table.insert(output, "</div>")
    if page.hero_image and page.hero_image ~= "" then
        table.insert(
            output,
            '<div class="tealdoc-hero-image"><div class="tealdoc-hero-starburst" aria-hidden="true"></div><img src="' ..
                escape_html(page.hero_image) ..
                '" alt="' ..
                escape_html(page.hero_image_alt or "") ..
                '"></div>'
        )
    end
    table.insert(output, "</div>")
    if page.features and #page.features > 0 then
        table.insert(output, '<div class="tealdoc-features">')
        for _, feature in ipairs(page.features) do
            table.insert(output, '<section class="tealdoc-feature">')
            if feature.image and feature.image ~= "" then
                table.insert(
                    output,
                    '<img class="tealdoc-feature-image" src="' ..
                        escape_html(feature.image) ..
                        '" alt="">'
                )
            elseif feature.icon then
                table.insert(
                    output,
                    '<span class="tealdoc-feature-icon" aria-hidden="true">' ..
                        escape_html(feature.icon) ..
                        "</span>"
                )
            end
            table.insert(
                output,
                "<h2>" ..
                    escape_html(feature.title) ..
                    '</h2><div class="tealdoc-feature-details">' ..
                    SiteMarkdown.render(feature.details or "", type_links) ..
                    "</div></section>"
            )
        end
        table.insert(output, "</div>")
    end
    table.insert(output, "</section>")
    return table.concat(output)
end

local function render_page(
    page: SiteGenerator.Page,
    view: SiteTypes.ApiView,
    context: SiteGenerator.Context,
    resolver: MarkdownGenerator.URLResolver,
    attached_examples: {string: {PreparedExample}},
    used_examples: {string: boolean}
): string, {SearchEntry}, string
    local markdown = SiteApi.source_markdown(page)
    local api = SiteApi.markdown(
        view,
        resolver,
        attached_examples,
        used_examples
    )
    if api ~= "" then
        local summary = SiteApi.summary(
            view,
            resolver
        )
        local introduction = ""
        local public_name = view.public
        if not markdown:match("%S") then
            introduction = "\n\nPublic APIs in `" .. public_name .. "`."
        end
        markdown = markdown ..
            "\n\n## " ..
            public_name ..
            " Reference" ..
            introduction ..
            "\n\n" ..
            summary ..
            "\n" ..
            api
    end

    local type_links = SiteApi.type_links(view, resolver)
    local content = SiteMarkdown.render(markdown, type_links)
    local outline: string
    local page_headings: {Heading}
    content, outline, page_headings = headings(content)

    local settings = context.settings
    local hero_region = ""
    if page.layout == "home" then
        hero_region = home_hero(page, settings.base, type_links)
    end
    local entries: {SearchEntry} = {
        {
            title = page.title,
            url = page_url(settings.base, page.path),
            text = (page.description or "") ..
                " " ..
                plain_text(hero_region .. content),
        },
    }
    for _, heading in ipairs(page_headings) do
        table.insert(entries, {
            title = page.title .. " › " .. heading.title,
            url = page_url(settings.base, page.path) .. "#" .. heading.id,
            text = heading.title .. " " .. page.title,
        })
    end

    local assets = page_url(settings.base, "assets")
    local title = page.title .. " | " .. settings.title
    local sidebar_html = sidebar(
        context.pages,
        page.path,
        settings.base,
        settings.sidebar
    )
    local shell_class = "tealdoc-shell"
    local content_class = "tealdoc-content"
    local sidebar_region = '<aside class="tealdoc-sidebar" aria-label="Page navigation"><ul>' ..
        sidebar_html ..
        "</ul></aside>"
    local breadcrumb_region = breadcrumbs(
        page,
        context.pages,
        settings.base
    )
    local mobile_outline = '<details class="tealdoc-mobile-outline"><summary>On this page</summary><ol>' ..
        outline ..
        "</ol></details>"
    local outline_region = '<aside class="tealdoc-outline" aria-label="On this page"><div class="tealdoc-outline-title">On this page</div><ol>' ..
        outline ..
        "</ol></aside>"
    local page_navigation_region = page_navigation(
        page,
        context.pages,
        settings.base
    )
    local content_template = "content.html"
    local footer_class = ""
    if page.layout == "home" then
        shell_class = shell_class .. " tealdoc-home-shell"
        content_class = content_class .. " tealdoc-home-content"
        sidebar_region = ""
        breadcrumb_region = ""
        mobile_outline = ""
        outline_region = ""
        page_navigation_region = ""
        footer_class = " tealdoc-home-footer"
        content_template = "home.html"
    end
    local top_navigation = navigation(
        settings.nav,
        page.path,
        settings.base
    )
    local html = PageTemplate.render({
        language = escape_html(settings.language or "en"),
        title = escape_html(title),
        description = escape_html(page.description or settings.description),
        head = page_head(settings, page),
        stylesheet_url = escape_html(assets .. "tealdoc.css"),
        pico_stylesheet_url = escape_html(
            assets .. "pico.classless.min.css"
        ),
        search_index_url = escape_html(assets .. "search-index.js"),
        script_url = escape_html(assets .. "tealdoc.js"),
        brand = brand(settings),
        top_navigation = top_navigation,
        header_actions = header_actions(settings, page),
        sidebar_links = sidebar_html,
        shell_class = shell_class,
        sidebar = sidebar_region,
        content_class = content_class,
        breadcrumbs = breadcrumb_region,
        mobile_outline = mobile_outline,
        content = content,
        page_navigation = page_navigation_region,
        outline = outline_region,
        search_dialog = search_dialog(assets .. "search-index.js"),
        footer_class = footer_class,
        footer_items = footer_items(settings, page),
        home_hero = hero_region,
        content_template = content_template,
    }, settings.templates)
    return html, entries, markdown
end

local function escape_js(text: string): string
    return (text:gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\r", "\\r")
        :gsub("\n", "\\n")
        :gsub("</", "<\\/"))
end

local function search_index_js(entries: {SearchEntry}): string
    local output: {string} = {"window.TEALDOC_SEARCH_INDEX = [\n"}
    for _, entry in ipairs(entries) do
        table.insert(
            output,
            '  {title:"' ..
                escape_js(entry.title) ..
                '",url:"' ..
                escape_js(entry.url) ..
                '",text:"' ..
                escape_js(entry.text) ..
                '"},\n'
        )
    end
    table.insert(output, "];\n")
    return table.concat(output)
end

local function redirect_url(base: string, target: string): string
    if target:match("^https?://") or target:sub(1, 1) == "/" then
        return target
    end
    return page_url(base, target)
end

local function redirect_html(target: string): string
    local escaped = escape_html(target)
    return "<!DOCTYPE html>\n" ..
        '<html lang="en">\n<head>\n<meta charset="utf-8">\n' ..
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n' ..
        '<meta http-equiv="refresh" content="0; url=' ..
        escaped ..
        '">\n<link rel="canonical" href="' ..
        escaped ..
        '">\n<title>Moved</title>\n</head>\n<body>\n' ..
        '<p>This page moved to <a href="' ..
        escaped ..
        '">' ..
        escaped ..
        "</a>.</p>\n</body>\n</html>\n"
end

local function sitemap_xml(
    settings: SiteGenerator.Settings,
    pages: {SiteGenerator.Page}
): string
    local output: {string} = {
        '<?xml version="1.0" encoding="UTF-8"?>\n',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n',
    }
    for _, page in ipairs(pages) do
        if not page.noindex then
            local url = canonical_url(settings, page)
            if url then
                table.insert(
                    output,
                    "    <url><loc>" ..
                        escape_html(url) ..
                        "</loc></url>\n"
                )
            end
        end
    end
    table.insert(output, "</urlset>\n")
    return table.concat(output)
end

local function robots_txt(settings: SiteGenerator.Settings): string
    local base = page_url(settings.base, "")
    local output = "User-agent: *\nAllow: " .. base .. "\n"
    if settings.site_url
        and settings.site_url ~= ""
        and settings.sitemap ~= false
    then
        output = output ..
            "Sitemap: " ..
            absolute_url(
                settings.site_url,
                root_file_url(settings.base, "sitemap.xml")
            ) ..
            "\n"
    end
    return output
end

local function not_found_page(
    configured: SiteGenerator.Page
): SiteGenerator.Page
    return {
        path = "404",
        title = configured.title or "Page not found",
        description = configured.description or "The requested page was not found.",
        source = configured.source,
        layout = configured.layout,
        hero_title = configured.hero_title,
        hero_text = configured.hero_text,
        hero_image = configured.hero_image,
        hero_image_alt = configured.hero_image_alt,
        hero_actions = configured.hero_actions,
        features = configured.features,
        image = configured.image,
        noindex = true,
    }
end

local function valid_cname(name: string): boolean
    if #name == 0 or #name > 253 or name:find("%.%.", 1, true) then
        return false
    end
    local length = 0
    for label in name:gmatch("[^%.]+") do
        length = length + #label + (length > 0 and 1 or 0)
        if #label == 0
            or #label > 63
            or not label:match("^[A-Za-z0-9][A-Za-z0-9%-]*[A-Za-z0-9]$")
                and not label:match("^[A-Za-z0-9]$")
        then
            return false
        end
    end
    return length == #name
end

function SiteGenerator.build(
    output: string,
    env: tealdoc.Env,
    raw_settings: SiteGenerator.Settings,
    config_directory?: string
)
    local settings = SiteConfig.configure(raw_settings, config_directory)
    local pages: {SiteGenerator.Page}
    local attached_examples: {string: {PreparedExample}}
    pages, attached_examples = SiteExamples.prepare(settings, env)
    settings.redirects = validated_redirects(pages, settings.redirects)

    local used_examples: {string: boolean} = {}
    local context: SiteGenerator.Context = {
        output = output,
        env = env,
        settings = settings,
        pages = pages,
        files = {},
    }
    if settings.before_build then
        settings.before_build(context)
    end
    settings.redirects = validated_redirects(context.pages, settings.redirects)
    validate_output_routes(
        context.pages,
        settings.redirects,
        settings.not_found ~= nil
    )
    mkdir_p(output)
    mkdir_p(output .. "/assets")

    if settings.public then
        copy_public_directory(settings.public, output, context.files)
    end

    local css = default_css
    if settings.custom_css then
        css = append_custom_css(css, read_file(settings.custom_css))
    end
    local css_path = output .. "/assets/tealdoc.css"
    write_file(css_path, css)
    table.insert(context.files, css_path)

    local pico_path = output .. "/assets/pico.classless.min.css"
    write_file(pico_path, pico_css)
    table.insert(context.files, pico_path)

    local js_path = output .. "/assets/tealdoc.js"
    write_file(js_path, default_js)
    table.insert(context.files, js_path)

    local views: {string: SiteTypes.ApiView} = {}
    for _, page in ipairs(context.pages) do
        if page.api then
            views[page.path] = SiteView.prepare(page, context.env)
        end
    end
    local resolver = routes_for_pages(context.pages, views, settings.base)
    local search_entries: {SearchEntry} = {}
    for _, page in ipairs(context.pages) do
        local directory = output
        if page.path and page.path ~= "" then
            directory = output .. "/" .. page.path:gsub("^/+", ""):gsub("/+$", "")
            mkdir_p(directory)
        end
        local path = directory .. "/index.html"
        local html: string
        local page_entries: {SearchEntry}
        local markdown: string
        html, page_entries, markdown = render_page(
            page,
            views[page.path],
            context,
            resolver,
            attached_examples,
            used_examples
        )
        write_file(path, html)
        table.insert(context.files, path)
        local markdown_path = output .. "/index.md"
        if page.path and page.path ~= "" then
            markdown_path = output ..
                "/" ..
                page.path:gsub("^/+", ""):gsub("/+$", "") ..
                ".md"
        end
        write_file(markdown_path, markdown)
        table.insert(context.files, markdown_path)
        local llms_path = directory .. "/llms.txt"
        write_file(llms_path, markdown)
        table.insert(context.files, llms_path)
        for _, entry in ipairs(page_entries) do
            table.insert(search_entries, entry)
        end
    end

    for item_path in pairs(attached_examples) do
        assert(
            used_examples[item_path],
            "example attach_to is not a public API item: " .. item_path
        )
    end

    for old_path, target in pairs(settings.redirects or {}) do
        local path: string
        if old_path:match("%.html$") then
            local parent = old_path:match("^(.*)/[^/]+$")
            if parent then
                mkdir_p(output .. "/" .. parent)
            end
            path = output .. "/" .. old_path
        else
            local directory = output .. "/" .. old_path
            mkdir_p(directory)
            path = directory .. "/index.html"
        end
        write_file(path, redirect_html(redirect_url(settings.base, target)))
        table.insert(context.files, path)
    end

    if settings.not_found then
        local missing = not_found_page(settings.not_found)
        local missing_directory = output .. "/404"
        mkdir_p(missing_directory)
        local html: string
        local _: {SearchEntry}
        local markdown: string
        html, _, markdown = render_page(
            missing,
            nil,
            context,
            resolver,
            attached_examples,
            used_examples
        )
        local html_path = output .. "/404.html"
        write_file(html_path, html)
        table.insert(context.files, html_path)
        local markdown_path = output .. "/404.md"
        write_file(markdown_path, markdown)
        table.insert(context.files, markdown_path)
        local llms_path = missing_directory .. "/llms.txt"
        write_file(llms_path, markdown)
        table.insert(context.files, llms_path)
    end

    if settings.cname then
        assert(
            valid_cname(settings.cname),
            "tealdoc.site.cname must be a bare DNS name"
        )
        local cname_path = output .. "/CNAME"
        write_file(cname_path, settings.cname .. "\n")
        table.insert(context.files, cname_path)
    end

    if settings.site_url
        and settings.site_url ~= ""
        and settings.sitemap ~= false
    then
        assert(
            settings.site_url:match("^https?://[^/%?#]+/?$"),
            "tealdoc.site.site_url must be an HTTP origin without a path"
        )
        local sitemap_path = output .. "/sitemap.xml"
        write_file(sitemap_path, sitemap_xml(settings, context.pages))
        table.insert(context.files, sitemap_path)
    end

    if settings.robots ~= false then
        local robots_path = output .. "/robots.txt"
        write_file(robots_path, robots_txt(settings))
        table.insert(context.files, robots_path)
    end

    local search_path = output .. "/assets/search-index.js"
    write_file(search_path, search_index_js(search_entries))
    table.insert(context.files, search_path)

    if settings.after_build then
        settings.after_build(context)
    end
    if settings.validate_links ~= false then
        SiteValidator.validate(output, settings.base, context.files)
    end
end

return SiteGenerator
