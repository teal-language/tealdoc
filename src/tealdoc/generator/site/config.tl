local SiteTypes = require("tealdoc.generator.site.types")

local record SiteConfig
    configure: function(
        raw: any,
        config_directory?: string
    ): SiteTypes.Settings
    join_path: function(directory: string, path: string): string
    normalize_route: function(
        route: any,
        name: string,
        allow_empty: boolean
    ): string
end

local function join_path(directory: string, path: string): string
    if path:match("^[/\\]")
        or path:match("^%a:[/\\]")
        or directory == ""
        or directory == "."
    then
        return path
    end
    local separator = package.config:sub(1, 1)
    return directory:gsub("[/\\]+$", "") .. separator .. path
end

SiteConfig.join_path = join_path

local function resolve_file_path(
    directory: string,
    path: any,
    name: string
): string
    assert(
        type(path) == "string" and path ~= "",
        name .. " must be a non-empty string"
    )
    return join_path(directory, path as string)
end

local function validate_keys(
    values: any,
    allowed: {string: boolean},
    name: string
)
    assert(type(values) == "table", name .. " must be a table")
    for key in pairs(values as {any: any}) do
        assert(
            type(key) == "string" and allowed[key as string],
            "unknown " .. name .. " setting: " .. tostring(key)
        )
    end
end

local function validate_optional_string(values: {string: any}, key: string)
    assert(
        values[key] == nil or type(values[key]) == "string",
        "tealdoc.site." .. key .. " must be a string"
    )
end

local function validate_optional_table(values: {string: any}, key: string)
    assert(
        values[key] == nil or type(values[key]) == "table",
        "tealdoc.site." .. key .. " must be a table"
    )
end

local function validate_optional_boolean(values: {string: any}, key: string)
    assert(
        values[key] == nil or type(values[key]) == "boolean",
        "tealdoc.site." .. key .. " must be a boolean"
    )
end

local site_keys: {string: boolean} = {
    title = true,
    name = true,
    description = true,
    language = true,
    base = true,
    site_url = true,
    logo = true,
    github = true,
    favicon = true,
    public = true,
    cname = true,
    head = true,
    author = true,
    social_image = true,
    twitter_site = true,
    sitemap = true,
    robots = true,
    not_found = true,
    custom_css = true,
    lexers = true,
    templates = true,
    copyright = true,
    license = true,
    footer_links = true,
    redirects = true,
    examples = true,
    validate_links = true,
    format_generated_code = true,
    pages = true,
    sidebar = true,
    sidebar_open = true,
    nav = true,
    sources = true,
    before_build = true,
    after_build = true,
}

local page_keys: {string: boolean} = {
    path = true,
    title = true,
    description = true,
    source = true,
    api = true,
    public = true,
    layout = true,
    hero_title = true,
    hero_text = true,
    hero_image = true,
    hero_image_alt = true,
    hero_actions = true,
    features = true,
    example_source = true,
    example_language = true,
    canonical = true,
    image = true,
    noindex = true,
}

local api_source_keys: {string: boolean} = {
    module = true,
    public = true,
    include = true,
}

local example_keys: {string: boolean} = {
    path = true,
    attach_to = true,
    region = true,
    title = true,
    description = true,
    source = true,
    language = true,
    check = true,
}

local link_keys: {string: boolean} = {
    text = true,
    path = true,
    theme = true,
}

local feature_keys: {string: boolean} = {
    title = true,
    details = true,
    icon = true,
    image = true,
}

local head_entry_keys: {string: boolean} = {
    tag = true,
    attributes = true,
}

local sidebar_item_keys: {string: boolean} = {
    text = true,
    path = true,
    items = true,
    collapsed = true,
}

local function normalize_base(base: any): string
    if base == nil or base == "" then
        return "/"
    end
    assert(type(base) == "string", "tealdoc.site.base must be a string")
    local normalized = (base as string):gsub("\\", "/")
    assert(
        normalized:sub(1, 1) == "/",
        "tealdoc.site.base must begin with '/'"
    )
    normalized = normalized:gsub("/+", "/")
    if normalized:sub(-1) ~= "/" then
        normalized = normalized .. "/"
    end
    for segment in normalized:gmatch("[^/]+") do
        assert(
            segment ~= "." and segment ~= "..",
            "tealdoc.site.base contains an unsafe path segment"
        )
    end
    return normalized
end

local function normalize_route(
    route: any,
    name: string,
    allow_empty: boolean
): string
    assert(type(route) == "string", name .. " must be a string")
    local normalized = (route as string):gsub("\\", "/")
    assert(
        not normalized:find("[?#]"),
        name .. " must not contain a query or fragment"
    )
    assert(
        not normalized:find("[%z\1-\31\127]"),
        name .. " must not contain control characters"
    )
    normalized = normalized:gsub("^/+", ""):gsub("/+$", ""):gsub("/+", "/")
    assert(allow_empty or normalized ~= "", name .. " must not be empty")
    for segment in normalized:gmatch("[^/]+") do
        assert(
            segment ~= "." and segment ~= "..",
            name .. " contains an unsafe path segment: " .. (route as string)
        )
    end
    return normalized
end

SiteConfig.normalize_route = normalize_route

local function validate_link(link: any, name: string)
    validate_keys(link, link_keys, name)
    local values = link as {string: any}
    assert(
        type(values["text"]) == "string" and values["text"] ~= "",
        name .. ".text is required"
    )
    assert(type(values["path"]) == "string", name .. ".path is required")
end

function SiteConfig.configure(
    raw: any,
    config_directory?: string
): SiteTypes.Settings
    validate_keys(raw, site_keys, "tealdoc.site")
    local values = raw as {string: any}
    assert(
        type(values["title"]) == "string" and values["title"] ~= "",
        "tealdoc.site.title is required"
    )
    for _, key in ipairs({
        "name",
        "description",
        "language",
        "site_url",
        "logo",
        "github",
        "favicon",
        "public",
        "cname",
        "author",
        "social_image",
        "twitter_site",
        "custom_css",
        "lexers",
        "templates",
        "copyright",
        "license",
    }) do
        validate_optional_string(values, key)
    end
    for _, key in ipairs({
        "redirects",
        "examples",
        "pages",
        "sidebar",
        "sidebar_open",
        "nav",
        "sources",
        "head",
        "footer_links",
        "not_found",
    }) do
        validate_optional_table(values, key)
    end
    for _, key in ipairs({
        "sitemap",
        "robots",
        "validate_links",
        "format_generated_code",
    }) do
        validate_optional_boolean(values, key)
    end
    assert(
        values["before_build"] == nil
            or type(values["before_build"]) == "function",
        "tealdoc.site.before_build must be a function"
    )
    assert(
        values["after_build"] == nil
            or type(values["after_build"]) == "function",
        "tealdoc.site.after_build must be a function"
    )

    local directory = config_directory or "."
    local settings: SiteTypes.Settings = {
        title = values["title"] as string,
        name = (values["name"] == nil
            and values["title"]
            or values["name"]) as string,
        description = (values["description"] or "") as string,
        language = (values["language"] or "en") as string,
        base = normalize_base(values["base"]),
        site_url = values["site_url"] as string,
        logo = values["logo"] as string,
        github = values["github"] as string,
        favicon = values["favicon"] as string,
        public = values["public"]
            and resolve_file_path(
                directory,
                values["public"],
                "tealdoc.site.public"
            )
            or nil,
        cname = values["cname"] as string,
        head = {},
        author = values["author"] as string,
        social_image = values["social_image"] as string,
        twitter_site = values["twitter_site"] as string,
        sitemap = values["sitemap"] == nil
            and values["site_url"] ~= nil
            or values["sitemap"] as boolean,
        robots = values["robots"] ~= false,
        not_found = nil,
        custom_css = values["custom_css"]
            and resolve_file_path(
                directory,
                values["custom_css"],
                "tealdoc.site.custom_css"
            )
            or nil,
        lexers = values["lexers"] as string,
        templates = values["templates"]
            and resolve_file_path(
                directory,
                values["templates"],
                "tealdoc.site.templates"
            )
            or nil,
        copyright = values["copyright"] as string,
        license = values["license"] as string,
        footer_links = {},
        redirects = {},
        examples = {},
        validate_links = values["validate_links"] ~= false,
        format_generated_code = values["format_generated_code"] == true,
        pages = {},
        sidebar = {},
        sidebar_open = nil,
        nav = {},
        sources = {},
        before_build = values["before_build"] as function(SiteTypes.Context),
        after_build = values["after_build"] as function(SiteTypes.Context),
    }

    assert(type(settings.name) == "string", "tealdoc.site.name must be a string")
    assert(
        type(settings.description) == "string",
        "tealdoc.site.description must be a string"
    )
    if values["sidebar_open"] ~= nil then
        settings.sidebar_open = {}
        local selectors = values["sidebar_open"] as {any}
        for index, selector in ipairs(selectors) do
            assert(
                type(selector) == "string" and selector ~= "",
                "tealdoc.site.sidebar_open[" ..
                    tostring(index) ..
                    "] must be a non-empty string"
            )
            settings.sidebar_open[selector as string] = true
        end
    end
    if settings.site_url and settings.site_url ~= "" then
        assert(
            settings.site_url:match("^https?://[^/%?#]+/?$"),
            "tealdoc.site.site_url must be an HTTP origin without a path"
        )
        settings.site_url = settings.site_url:gsub("/+$", "")
    end
    for index, entry in ipairs(values["head"] as {any} or {}) do
        local name = "tealdoc.site.head[" .. tostring(index) .. "]"
        validate_keys(entry, head_entry_keys, name)
        local head_entry = entry as {string: any}
        assert(type(head_entry["tag"]) == "string", name .. ".tag is required")
        assert(
            type(head_entry["attributes"]) == "table",
            name .. ".attributes is required"
        )
        table.insert(settings.head, entry as SiteTypes.HeadEntry)
    end
    for _, source in ipairs(values["sources"] as {any} or {}) do
        table.insert(
            settings.sources,
            resolve_file_path(directory, source, "tealdoc.site.sources entry")
        )
    end
    for index, link in ipairs(values["nav"] as {any} or {}) do
        validate_link(link, "tealdoc.site.nav[" .. tostring(index) .. "]")
        table.insert(settings.nav, link as SiteTypes.Link)
    end
    for index, link in ipairs(values["footer_links"] as {any} or {}) do
        validate_link(
            link,
            "tealdoc.site.footer_links[" .. tostring(index) .. "]"
        )
        table.insert(settings.footer_links, link as SiteTypes.Link)
    end
    for index, page_value in ipairs(values["pages"] as {any} or {}) do
        local name = "tealdoc.site.pages[" .. tostring(index) .. "]"
        validate_keys(page_value, page_keys, name)
        local page = page_value as {string: any}
        assert(
            type(page["title"]) == "string" and page["title"] ~= "",
            name .. ".title is required"
        )
        for _, key in ipairs({
            "description",
            "source",
            "public",
            "layout",
            "hero_title",
            "hero_text",
            "hero_image",
            "hero_image_alt",
            "example_source",
            "example_language",
            "canonical",
            "image",
        }) do
            assert(
                page[key] == nil or type(page[key]) == "string",
                name .. "." .. key .. " must be a string"
            )
        end
        assert(
            page["api"] == nil
                or type(page["api"]) == "string"
                or type(page["api"]) == "table",
            name .. ".api must be a string or list of API sources"
        )
        if type(page["api"]) == "string" then
            assert(page["api"] ~= "", name .. ".api must not be empty")
        elseif type(page["api"]) == "table" then
            local seen: {string: boolean} = {}
            local modules = page["api"] as {any}
            assert(#modules > 0, name .. ".api must not be empty")
            assert(
                type(page["public"]) == "string" and page["public"] ~= "",
                name .. ".public is required when api contains several modules"
            )
            for module_index, source_value in ipairs(modules) do
                local source_name = name ..
                    ".api[" ..
                    tostring(module_index) ..
                    "]"
                local module_name: string
                local source_public = ""
                if type(source_value) == "string" then
                    module_name = source_value as string
                    assert(
                        module_name ~= "",
                        source_name .. " must not be empty"
                    )
                else
                    assert(
                        type(source_value) == "table",
                        source_name .. " must be a string or table"
                    )
                    validate_keys(
                        source_value,
                        api_source_keys,
                        source_name
                    )
                    local source = source_value as {string: any}
                    assert(
                        type(source["module"]) == "string"
                            and source["module"] ~= "",
                        source_name .. ".module is required"
                    )
                    assert(
                        source["public"] == nil
                            or type(source["public"]) == "string"
                                and source["public"] ~= "",
                        source_name .. ".public must be a non-empty string"
                    )
                    assert(
                        source["include"] == nil
                            or type(source["include"]) == "table",
                        source_name .. ".include must be a list of names"
                    )
                    local names: {string: boolean} = {}
                    for include_index, include_name in ipairs(
                        source["include"] as {any} or {}
                    ) do
                        assert(
                            type(include_name) == "string"
                                and include_name ~= "",
                            source_name ..
                                ".include[" ..
                                tostring(include_index) ..
                                "] must be a non-empty string"
                        )
                        assert(
                            not names[include_name as string],
                            source_name ..
                                ".include contains duplicate name " ..
                                tostring(include_name)
                        )
                        names[include_name as string] = true
                    end
                    module_name = source["module"] as string
                    source_public = source["public"] as string or ""
                end
                local identity = module_name .. "\0" .. source_public
                assert(
                    not seen[identity],
                    name ..
                        ".api contains duplicate API source " ..
                        tostring(module_name)
                )
                seen[identity] = true
            end
        end
        assert(
            page["hero_actions"] == nil
                or type(page["hero_actions"]) == "table",
            name .. ".hero_actions must be a table"
        )
        assert(
            page["features"] == nil or type(page["features"]) == "table",
            name .. ".features must be a table"
        )
        assert(
            page["noindex"] == nil or type(page["noindex"]) == "boolean",
            name .. ".noindex must be a boolean"
        )
        local normalized_values: {string: any} = {}
        for key, value in pairs(page) do
            normalized_values[key] = value
        end
        local normalized = normalized_values as SiteTypes.Page
        normalized.path = normalize_route(
            page["path"] or "",
            name .. ".path",
            true
        )
        if page["source"] then
            normalized.source = resolve_file_path(
                directory,
                page["source"],
                name .. ".source"
            )
        end
        for action_index, action in ipairs(
            page["hero_actions"] as {any} or {}
        ) do
            validate_link(
                action,
                name .. ".hero_actions[" .. tostring(action_index) .. "]"
            )
        end
        for feature_index, feature in ipairs(page["features"] as {any} or {}) do
            local feature_name = name ..
                ".features[" ..
                tostring(feature_index) ..
                "]"
            validate_keys(feature, feature_keys, feature_name)
            local feature_values = feature as {string: any}
            assert(
                type(feature_values["title"]) == "string"
                    and feature_values["title"] ~= "",
                feature_name .. ".title is required"
            )
        end
        table.insert(settings.pages, normalized)
    end
    local pages_by_path: {string: SiteTypes.Page} = {}
    for _, page in ipairs(settings.pages) do
        pages_by_path[page.path] = page
    end
    local normalize_sidebar_item: function(any, string): SiteTypes.SidebarItem
    normalize_sidebar_item = function(
        item_value: any,
        name: string
    ): SiteTypes.SidebarItem
        validate_keys(item_value, sidebar_item_keys, name)
        local item = item_value as {string: any}
        assert(
            item["text"] == nil or type(item["text"]) == "string",
            name .. ".text must be a string"
        )
        assert(
            item["path"] == nil or type(item["path"]) == "string",
            name .. ".path must be a string"
        )
        assert(
            item["items"] == nil or type(item["items"]) == "table",
            name .. ".items must be a table"
        )
        assert(
            item["collapsed"] == nil or type(item["collapsed"]) == "boolean",
            name .. ".collapsed must be a boolean"
        )
        assert(
            item["path"] ~= nil
                or type(item["text"]) == "string" and item["text"] ~= "",
            name .. " requires text or path"
        )
        local path: string
        if item["path"] ~= nil then
            path = normalize_route(item["path"], name .. ".path", true)
            assert(
                pages_by_path[path] ~= nil,
                name .. ".path does not name a configured page: " .. path
            )
        end
        local collapsed: boolean
        if item["collapsed"] ~= nil then
            collapsed = item["collapsed"] == true
        elseif settings.sidebar_open then
            collapsed = not (
                path and settings.sidebar_open[path]
                    or settings.sidebar_open[item["text"] as string]
            )
        end
        local normalized: SiteTypes.SidebarItem = {
            text = (item["text"]
                or path and pages_by_path[path].title) as string,
            path = path,
            items = {},
            collapsed = collapsed,
        }
        for child_index, child in ipairs(item["items"] as {any} or {}) do
            table.insert(
                normalized.items,
                normalize_sidebar_item(
                    child,
                    name .. ".items[" .. tostring(child_index) .. "]"
                )
            )
        end
        assert(
            normalized.path ~= nil or #normalized.items > 0,
            name .. " without a path requires nested items"
        )
        return normalized
    end
    for index, item in ipairs(values["sidebar"] as {any} or {}) do
        table.insert(
            settings.sidebar,
            normalize_sidebar_item(
                item,
                "tealdoc.site.sidebar[" .. tostring(index) .. "]"
            )
        )
    end
    for index, example_value in ipairs(values["examples"] as {any} or {}) do
        local name = "tealdoc.site.examples[" .. tostring(index) .. "]"
        validate_keys(example_value, example_keys, name)
        local example = example_value as {string: any}
        local has_path = type(example["path"]) == "string"
            and example["path"] ~= ""
        local has_attachment = type(example["attach_to"]) == "string"
            and example["attach_to"] ~= ""
        assert(
            has_path ~= has_attachment,
            name .. " requires exactly one of path or attach_to"
        )
        assert(
            has_attachment
                or type(example["title"]) == "string"
                    and example["title"] ~= "",
            name .. ".title is required for a page example"
        )
        assert(
            type(example["source"]) == "string" and example["source"] ~= "",
            name .. ".source is required"
        )
        assert(
            example["description"] == nil
                or type(example["description"]) == "string",
            name .. ".description must be a string"
        )
        assert(
            example["language"] == nil or type(example["language"]) == "string",
            name .. ".language must be a string"
        )
        assert(
            example["region"] == nil or type(example["region"]) == "string",
            name .. ".region must be a string"
        )
        assert(
            example["check"] == nil or type(example["check"]) == "boolean",
            name .. ".check must be a boolean"
        )
        local normalized_values: {string: any} = {}
        for key, value in pairs(example) do
            normalized_values[key] = value
        end
        local normalized = normalized_values as SiteTypes.Example
        if has_path then
            normalized.path = normalize_route(
                example["path"],
                name .. ".path",
                false
            )
        end
        normalized.source = resolve_file_path(
            directory,
            example["source"],
            name .. ".source"
        )
        table.insert(settings.examples, normalized)
    end
    if values["not_found"] ~= nil then
        local name = "tealdoc.site.not_found"
        validate_keys(values["not_found"], page_keys, name)
        local configured = values["not_found"] as {string: any}
        local normalized_values: {string: any} = {}
        for key, value in pairs(configured) do
            normalized_values[key] = value
        end
        local normalized = normalized_values as SiteTypes.Page
        if configured["source"] then
            normalized.source = resolve_file_path(
                directory,
                configured["source"],
                name .. ".source"
            )
        end
        settings.not_found = normalized
    end
    assert(
        #settings.pages > 0 or #settings.examples > 0,
        "tealdoc.site.pages or tealdoc.site.examples is required"
    )
    if values["redirects"] ~= nil then
        assert(
            type(values["redirects"]) == "table",
            "tealdoc.site.redirects must be a table"
        )
        for source, target in pairs(values["redirects"] as {any: any}) do
            assert(
                type(source) == "string" and type(target) == "string",
                "tealdoc.site.redirects keys and values must be strings"
            )
            settings.redirects[source as string] = target as string
        end
    end
    return settings
end

return SiteConfig
