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
local Scintillua = require("tealdoc.generator.site.scintillua")
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

local record PublicFile
    source: string
    path: string
end

local type PreparedExample = SiteTypes.PreparedExample
local MANIFEST_PATH = ".tealdoc-manifest"
local MANIFEST_HEADER = "tealdoc-manifest-v1\n"
local CERULEAN_WRAPPER = "-- tealdoc:generated-declaration-end"

--- Quotes a literal so it matches only itself.
local function escape_pattern(text: string): string
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function cerulean_formatter(): function(string): string
    local function load_module(name: string): any
        return require(name)
    end
    local options_ok: boolean
    local options_module: any
    options_ok, options_module = pcall(load_module, "cerulean.options")
    assert(
        options_ok,
        "tealdoc.site.format_generated_code requires Cerulean on Lua's " ..
            "package path: " ..
            tostring(options_module)
    )
    local rewriter_ok: boolean
    local rewriter_module: any
    rewriter_ok, rewriter_module = pcall(load_module, "cerulean.rewriter")
    assert(
        rewriter_ok,
        "tealdoc.site.format_generated_code requires Cerulean on Lua's " ..
            "package path: " ..
            tostring(rewriter_module)
    )

    local options_values = options_module as {string: any}
    local rewriter_values = rewriter_module as {string: any}
    assert(
        type(options_values["default"]) == "function"
            and type(rewriter_values["rewrite"]) == "function",
        "tealdoc.site.format_generated_code found an incompatible Cerulean"
    )
    local default_options = options_values["default"] as function(): any
    local rewrite = rewriter_values["rewrite"] as function(
        string,
        string,
        any
    ): any
    local formatter_options = default_options()
    local formatted_cache: {string: string} = {}

    local function result_errors(result: {string: any}): {any}
        return result["parse_errors"] as {any} or {}
    end

    local function failure_message(result: {string: any}): string
        local reason = result["failure_reason"]
        if type(reason) == "string" and reason ~= "" then
            return reason as string
        end
        local messages: {string} = {}
        for _, error_value in ipairs(result_errors(result)) do
            local message: any
            if type(error_value) == "table" then
                message = (error_value as {string: any})["msg"]
            end
            table.insert(messages, tostring(message or error_value))
        end
        if #messages > 0 then
            return table.concat(messages, "; ")
        end
        return "unknown formatter failure"
    end

    -- Generated declarations are not statements. They name what they declare
    -- by its whole path -- `record tecs.Application.Config`, the field
    -- `tecs.Application.Config.window: Window.Options`, a metamethod spelled
    -- through `$meta` -- and none of that is something Teal accepts where a
    -- declaration is written, so a formatter parsing whole units rejects
    -- every one.
    --
    -- Each declaration borrows a name Teal will take and whatever keyword
    -- makes the line a statement, and the pair is remembered. The whole
    -- prefix goes back at once afterwards, so the borrowed keyword leaves
    -- with the borrowed name and neither is left behind.
    local function complete_declarations(
        code: string
    ): string, integer, {{string, string}}
        local output: {string} = {}
        local restorations: {{string, string}} = {}
        local wrapper_count = 0
        local placeholder_count = 0
        local normalized = code:gsub("\n*$", "")
        local qualified = "[%a_][%w_]*[%.:][%w_%.:%$]*"

        local function borrow(
            indent: string,
            keyword: string,
            declared: string,
            rest: string,
            tail?: string
        ): string
            placeholder_count = placeholder_count + 1
            local borrowed = indent ..
                keyword ..
                "TealdocGenerated" ..
                tostring(placeholder_count) ..
                (tail or "")
            table.insert(restorations, {borrowed, indent .. declared})
            return borrowed .. rest
        end

        -- A type argument list ends at the `>` that closes the `<` it opened
        -- with, and a constraint can name a generic type of its own, so the
        -- close has to be counted for rather than searched for. Answers the
        -- list and whatever follows it, or nothing if the list never closes.
        local function typeargs(text: string): string, string
            local depth = 0
            for index = 1, #text do
                local char = text:sub(index, index)
                if char == "<" then
                    depth = depth + 1
                elseif char == ">" then
                    depth = depth - 1
                    if depth == 0 then
                        return text:sub(1, index), text:sub(index + 1)
                    end
                end
            end
            return nil, nil
        end

        for line in (normalized .. "\n"):gmatch("(.-)\n") do
            local emitted = line
            local indent, body = line:match("^(%s*)(.*)$")

            local meta_name, meta_rest = body:match(
                "^metamethod%s+(" .. qualified .. ")(%(.*)$"
            )
            -- A generic type alias is spelled the way the compiler shows a
            -- type rather than the way Teal writes one: the parameters
            -- arrive after the `=`, introduced by `generic`, and the type
            -- they parameterize follows them. Teal puts the same parameters
            -- on the name being declared, so the borrowed name takes them
            -- and the `generic<...>` marker goes back with the path.
            local alias_params, alias_rest: string, string
            local alias_dotted, alias_generic = body:match(
                "^type%s+(" .. qualified .. ")%s*=%s*generic(<.*)$"
            )
            if alias_generic then
                alias_params, alias_rest = typeargs(alias_generic)
                if not alias_rest or not alias_rest:match("^%s%S") then
                    alias_params, alias_rest = nil, nil
                end
            end

            local kind, dotted, rest: string, string, string
            if not meta_name and not alias_params then
                for _, word in ipairs({"record", "interface", "enum"}) do
                    if not kind then
                        kind, dotted, rest = body:match(
                            "^(" .. word .. "%s+)(" .. qualified .. ")(.*)$"
                        )
                    end
                end
                if not kind then
                    kind, dotted, rest = body:match(
                        "^(type%s+)(" .. qualified .. ")(%s*=.*)$"
                    )
                end
            end

            if meta_name then
                emitted = borrow(
                    indent,
                    "local function ",
                    "metamethod " .. meta_name,
                    meta_rest
                )
            elseif alias_params then
                emitted = borrow(
                    indent,
                    "local type ",
                    "type " .. alias_dotted .. " = generic" .. alias_params,
                    alias_rest,
                    alias_params .. " ="
                )
            elseif kind then
                emitted = borrow(indent, "local " .. kind, kind .. dotted, rest)
            else
                local scope, scoped_kind, scoped_dotted, scoped_rest =
                    body:match(
                        "^([%a]+%s+)([%a]+%s+)(" .. qualified .. ")(.*)$"
                    )
                if scope == "local " or scope == "global " then
                    emitted = borrow(
                        indent,
                        scope .. scoped_kind,
                        scope .. scoped_kind .. scoped_dotted,
                        scoped_rest
                    )
                else
                    local field, field_rest = body:match(
                        "^(" .. qualified .. ")(%s*:.*)$"
                    )
                    if field then
                        emitted = borrow(indent, "local ", field, field_rest)
                    end
                end
            end

            table.insert(output, emitted .. "\n")

            local first_word, second_word = emitted:match("^%s*(%S+)%s*(%S*)")
            local needs_body = first_word == "function"
                or first_word == "macroexp"
            if first_word == "local" or first_word == "global" then
                needs_body = second_word == "function"
                    or second_word == "macroexp"
            end
            if needs_body then
                wrapper_count = wrapper_count + 1
                table.insert(output, "end " .. CERULEAN_WRAPPER .. "\n")
            end
        end
        return table.concat(output), wrapper_count, restorations
    end

    return function(code: string): string
        local cached = formatted_cache[code]
        if cached then
            return cached
        end

        -- API function signatures are declarations without bodies. Complete
        -- every one independently so later declarations cannot become part
        -- of an earlier function while Cerulean parses the generated block.
        local input: string
        local wrapper_count: integer
        local restorations: {{string, string}}
        input, wrapper_count, restorations = complete_declarations(code)
        local result = rewrite(
            input,
            "tealdoc-generated.tl",
            formatter_options
        ) as {string: any}
        -- A block the formatter cannot read is left as it was written.
        --
        -- Formatting a signature is a courtesy, and no courtesy is worth a
        -- documentation build. Generated declarations are open-ended -- a
        -- shape nobody anticipated arrives the day somebody writes one -- so
        -- the failure a reader should get is a slightly less tidy signature,
        -- not a site that does not exist. The reason is reported once so it
        -- can be fixed rather than silently tolerated forever.
        if #result_errors(result) > 0
            or result["status"] == "failed"
            or type(result["output"]) ~= "string"
        then
            io.stderr:write(
                "tealdoc: Cerulean could not format a generated " ..
                    "declaration, which is left unformatted: " ..
                    failure_message(result) ..
                    "\n"
            )
            formatted_cache[code] = code
            return code
        end
        local formatted = result["output"] as string
        if wrapper_count > 0 then
            local removed: integer
            formatted, removed = formatted:gsub(
                "[ \t]*end[ \t]+%-%- tealdoc:" ..
                    "generated%-declaration%-end[ \t]*\n?",
                "",
                wrapper_count
            )
            assert(
                removed == wrapper_count,
                "Cerulean changed Tealdoc's temporary declaration wrappers"
            )
        end
        for index = #restorations, 1, -1 do
            local pair = restorations[index]
            local found: integer
            formatted, found = formatted:gsub(
                escape_pattern(pair[1]),
                function(): string return pair[2] end,
                1
            )
            assert(
                found == 1,
                "Cerulean changed a name Tealdoc borrowed: " .. pair[1]
            )
        end
        formatted = formatted:gsub("\n*$", "") .. "\n"
        formatted_cache[code] = formatted
        return formatted
    end
end

local function read_file(path: string): string
    local file = assert(io.open(path, "rb"), "Could not open " .. path)
    local contents = assert(file:read("*a"), "Could not read " .. path)
    file:close()
    return contents
end

-- A custom sheet is appended to the generated one, so its `@import` rules move
-- to the front: an import that follows a style rule is dropped by the browser,
-- and a web font asked for that way would silently never arrive. CSS lets a
-- comment stand before an import, and a sheet worth reading opens with one, so
-- the scan reads past comments rather than stopping at the first, and carries
-- them along so the author keeps what they wrote.
local function append_custom_css(css: string, custom: string): string
    local preamble: {string} = {}
    local imports: {string} = {}
    local body = custom
    while true do
        local remainder = body:gsub("^%s+", "")
        local comment = remainder:match("^(/%*.-%*/)")
        if comment then
            table.insert(preamble, comment)
            body = remainder:sub(#comment + 1)
        else
            local first, last, statement = remainder:find("^(@import%s+[^;]+;)")
            if not first then
                break
            end
            table.insert(imports, statement)
            body = remainder:sub(last + 1)
        end
    end
    if #imports == 0 then
        return css .. "\n" .. custom:gsub("^%s+", "")
    end
    local prefix = table.concat(preamble, "\n\n")
    if prefix ~= "" then
        prefix = prefix .. "\n\n"
    end
    prefix = prefix .. table.concat(imports, "\n") .. "\n\n"
    return prefix .. css .. "\n" .. body:gsub("^%s+", "")
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

local function safe_relative_path(path: string, name: string): string
    assert(path ~= "", name .. " must not be empty")
    assert(
        path:sub(1, 1) ~= "/"
            and not path:match("^%a:")
            and not path:find("\\", 1, true),
        name .. " must be a relative path using '/' separators: " .. path
    )
    assert(
        not path:find("[%z\1-\31\127]"),
        name .. " must not contain control characters: " .. path
    )
    assert(
        path:sub(-1) ~= "/" and not path:find("//", 1, true),
        name .. " is not normalized: " .. path
    )
    for segment in path:gmatch("[^/]+") do
        assert(
            segment ~= "." and segment ~= "..",
            name .. " contains an unsafe path segment: " .. path
        )
    end
    return path
end

local function collect_public_directory(
    source: string,
    prefix: string,
    files: {PublicFile}
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
        local relative_path = prefix == "" and entry or prefix .. "/" .. entry
        safe_relative_path(relative_path, "public asset path")
        local entry_attributes = assert(
            lfs.symlinkattributes(source_path),
            "Could not read public path " .. source_path
        )
        assert(
            entry_attributes.mode ~= "link",
            "public assets may not contain symbolic links: " .. source_path
        )
        if entry_attributes.mode == "directory" then
            collect_public_directory(source_path, relative_path, files)
        elseif entry_attributes.mode == "file" then
            table.insert(files, {
                source = source_path,
                path = relative_path,
            })
        else
            error("unsupported public asset: " .. source_path)
        end
    end
end

local function copy_public_files(
    output: string,
    public_files: {PublicFile},
    files: {string}
)
    for _, public_file in ipairs(public_files) do
        local parent = public_file.path:match("^(.*)/[^/]+$")
        if parent then
            mkdir_p(output .. "/" .. parent)
        end
        local destination = output .. "/" .. public_file.path
        write_file(destination, read_file(public_file.source))
        table.insert(files, destination)
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

local function planned_output_paths(
    settings: SiteGenerator.Settings,
    pages: {SiteGenerator.Page},
    redirects: {string: string},
    public_files: {PublicFile}
): {string: string}
    local outputs: {string: string} = {}
    local function claim(path: string, owner: string)
        safe_relative_path(path, owner .. " output path")
        assert(
            outputs[path] == nil,
            owner ..
                " conflicts with " ..
                tostring(outputs[path]) ..
                " at output path " ..
                path
        )
        for claimed_path, claimed_owner in pairs(outputs) do
            local conflict: string
            if path:sub(1, #claimed_path + 1) == claimed_path .. "/" then
                conflict = claimed_path
            elseif claimed_path:sub(1, #path + 1) == path .. "/" then
                conflict = path
            end
            assert(
                conflict == nil,
                owner ..
                    " conflicts with " ..
                    claimed_owner ..
                    " at output path " ..
                    tostring(conflict)
            )
        end
        outputs[path] = owner
    end
    claim(MANIFEST_PATH, "Tealdoc manifest")
    claim("assets/tealdoc.css", "Tealdoc stylesheet")
    claim("assets/pico.classless.min.css", "Pico stylesheet")
    claim("assets/tealdoc.js", "Tealdoc script")
    claim("assets/search-index.js", "search index")
    claim("llms.txt", "site LLM index")
    claim("llms-full.txt", "full LLM documentation")
    if settings.cname then
        claim("CNAME", "CNAME")
    end
    if settings.site_url
        and settings.site_url ~= ""
        and settings.sitemap ~= false
    then
        claim("sitemap.xml", "sitemap")
    end
    if settings.robots ~= false then
        claim("robots.txt", "robots file")
    end
    for _, page in ipairs(pages) do
        local route = page.path or ""
        local owner = route == "" and "home page" or "page " .. route
        claim(route == "" and "index.html" or route .. "/index.html", owner)
        claim(route == "" and "index.md" or route .. ".md", owner)
        if route ~= "" then
            claim(route .. "/llms.txt", owner)
        end
    end
    for route in pairs(redirects or {}) do
        local path = route:match("%.html$")
            and route
            or route .. "/index.html"
        claim(path, "redirect " .. route)
    end
    if settings.not_found then
        claim("404.html", "custom 404 page")
        claim("404.md", "custom 404 page")
        claim("404/llms.txt", "custom 404 page")
    end
    for _, public_file in ipairs(public_files) do
        claim(public_file.path, "public asset " .. public_file.path)
    end
    return outputs
end

local function read_manifest(output: string): {string: boolean}
    local path = output .. "/" .. MANIFEST_PATH
    local attributes = lfs.symlinkattributes(path)
    if not attributes then
        return {}
    end
    assert(
        attributes.mode == "file",
        "Tealdoc manifest must be a regular file: " .. path
    )
    local contents = read_file(path)
    assert(
        contents:sub(1, #MANIFEST_HEADER) == MANIFEST_HEADER,
        "invalid Tealdoc manifest header: " .. path
    )
    local owned: {string: boolean} = {}
    local body = contents:sub(#MANIFEST_HEADER + 1)
    for entry in (body .. "\n"):gmatch("(.-)\n") do
        if entry ~= "" then
            safe_relative_path(entry, "Tealdoc manifest entry")
            assert(
                entry ~= MANIFEST_PATH,
                "Tealdoc manifest may not own itself"
            )
            assert(
                not owned[entry],
                "duplicate Tealdoc manifest entry: " .. entry
            )
            owned[entry] = true
        end
    end
    return owned
end

local function remove_empty_parents(output: string, relative_path: string)
    local parent = relative_path:match("^(.*)/[^/]+$")
    while parent and parent ~= "" do
        if not lfs.rmdir(output .. "/" .. parent) then
            return
        end
        parent = parent:match("^(.*)/[^/]+$")
    end
end

local function prune_previous_outputs(
    output: string,
    previous: {string: boolean},
    current: {string: string}
)
    local stale: {string} = {}
    for path in pairs(previous) do
        if not current[path] then
            table.insert(stale, path)
        end
    end
    table.sort(stale)
    for _, path in ipairs(stale) do
        local destination = output .. "/" .. path
        local attributes = lfs.symlinkattributes(destination)
        if attributes then
            assert(
                attributes.mode == "file" or attributes.mode == "link",
                "refusing to prune non-file manifest entry: " .. path
            )
            assert(os.remove(destination), "Could not remove " .. destination)
        end
        remove_empty_parents(output, path)
    end
end

local function validate_output_destinations(
    output: string,
    current: {string: string},
    previous: {string: boolean}
)
    for path, owner in pairs(current) do
        if path ~= MANIFEST_PATH then
            local parent = ""
            for segment in path:gmatch("[^/]+") do
                local candidate = parent == "" and segment
                    or parent .. "/" .. segment
                local attributes = lfs.symlinkattributes(
                    output .. "/" .. candidate
                )
                if candidate == path then
                    if attributes then
                        assert(
                            previous[path]
                                and attributes.mode == "file",
                            owner ..
                                " would overwrite an unowned output path: " ..
                                path
                        )
                    end
                elseif attributes then
                    assert(
                        attributes.mode == "directory",
                        owner ..
                            " cannot create output beneath non-directory path: " ..
                            candidate
                    )
                end
                parent = candidate
            end
        end
    end
end

local function recorded_output_paths(
    output: string,
    files: {string},
    planned: {string: string}
): {string: boolean}, {string}
    local prefix = output .. "/"
    local owned: {string: boolean} = {}
    for path in pairs(planned) do
        if path ~= MANIFEST_PATH then
            local absolute = prefix .. path
            local attributes = lfs.symlinkattributes(absolute)
            assert(
                attributes and attributes.mode == "file",
                "planned output is not a regular file: " .. absolute
            )
            owned[path] = true
        end
    end
    for _, path in ipairs(files) do
        assert(
            path:sub(1, #prefix) == prefix,
            "generated file is outside the site output: " .. path
        )
        local relative = safe_relative_path(
            path:sub(#prefix + 1):gsub("\\", "/"),
            "generated file path"
        )
        assert(
            relative ~= MANIFEST_PATH,
            "after_build may not claim the Tealdoc manifest"
        )
        local attributes = lfs.symlinkattributes(path)
        assert(
            attributes and attributes.mode == "file",
            "generated file must be a regular file: " .. path
        )
        owned[relative] = true
    end
    local relative_paths: {string} = {}
    local absolute_paths: {string} = {}
    for path in pairs(owned) do
        table.insert(relative_paths, path)
    end
    table.sort(relative_paths)
    for _, path in ipairs(relative_paths) do
        table.insert(absolute_paths, prefix .. path)
    end
    return owned, absolute_paths
end

local function write_manifest(output: string, paths: {string: boolean})
    local sorted: {string} = {}
    for path in pairs(paths) do
        table.insert(sorted, path)
    end
    table.sort(sorted)
    write_file(
        output .. "/" .. MANIFEST_PATH,
        MANIFEST_HEADER .. table.concat(sorted, "\n") .. "\n"
    )
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
    local priorities: {string: integer} = {}
    local function add(
        path: string,
        url: string,
        owner: string,
        priority: integer
    )
        if routes[path] then
            if routes[path] == url then
                priorities[path] = math.max(priorities[path], priority)
                return
            end
            if priority > priorities[path] then
                routes[path] = url
                owners[path] = owner
                priorities[path] = priority
                return
            end
            if priority < priorities[path] then
                return
            end
            assert(
                false,
                "public API path " ..
                    path ..
                    " is rendered by both " ..
                    owners[path] ..
                    " and " ..
                    owner
            )
        end
        routes[path] = url
        owners[path] = owner
        priorities[path] = priority
    end

    for _, page in ipairs(pages) do
        local view = views[page.path]
        if view then
            local page_root = page_url(base, page.path)
            local priority = #view.public
            add(view.public, page_root, page.path, priority)
            for source_path, public_path in pairs(view.source_to_public) do
                local url = page_root
                if public_path ~= view.public then
                    url = url .. "#" .. public_path
                end
                add(source_path, url, page.path, priority)
                add(public_path, url, page.path, priority)
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
                else
                    -- Every entry under a section drops the namespace its
                    -- siblings share, the first one included. The prefix comes
                    -- from whichever entry opens the section, and applies to
                    -- that entry too: abbreviating all but the first is what
                    -- made the first read as the parent of the rest.
                    if outline_prefix == "" then
                        outline_prefix = title:match("^(.*)%.") or ""
                    end
                    if outline_prefix ~= ""
                        and title:sub(1, #outline_prefix + 1)
                            == outline_prefix .. "."
                    then
                        outline_title = title:sub(#outline_prefix + 2)
                    end
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

-- The footer in three groups: who owns the work, what a reader can open, and
-- what built the page. Each group is a row of its own, so a footer carrying
-- more than a couple of items breaks along the lines a reader would draw
-- anyway rather than wherever the width happens to run out. A group with
-- nothing in it is not emitted, so a site that configures none of this still
-- gets one row.
local function footer_items(
    settings: SiteGenerator.Settings,
    page: SiteGenerator.Page
): string
    local groups: {string} = {}

    local function group(name: string, parts: {string})
        if #parts == 0 then
            return
        end
        table.insert(
            groups,
            '<div class="tealdoc-footer-group tealdoc-footer-' ..
                name ..
                '">' ..
                table.concat(parts, '<span aria-hidden="true">·</span>') ..
                "</div>"
        )
    end

    local legal: {string} = {}
    if settings.copyright then
        table.insert(
            legal,
            '<span class="tealdoc-footer-copyright">' ..
                escape_html(settings.copyright) ..
                "</span>"
        )
    end
    if settings.license then
        table.insert(
            legal,
            '<span class="tealdoc-footer-license">' ..
                escape_html(settings.license) ..
                "</span>"
        )
    end
    group("legal", legal)

    local links: {string} = {}
    for _, link in ipairs(settings.footer_links or {}) do
        table.insert(
            links,
            '<a class="tealdoc-footer-link" href="' ..
                escape_html(link_url(settings.base, link.path)) ..
                '">' ..
                escape_html(link.text) ..
                "</a>"
        )
    end
    local llms_url = page_url(settings.base, page.path) .. "llms.txt"
    local llms_label = "llms.txt"
    if not page.path or page.path == "" then
        llms_url = markdown_url(settings.base, "")
        llms_label = "index.md"
    end
    table.insert(
        links,
        '<a class="tealdoc-footer-llms" href="' ..
            escape_html(llms_url) ..
            '">' ..
            llms_label ..
            "</a>"
    )
    group("links", links)

    group("meta", {
        '<span class="tealdoc-footer-credit">Generated by <a href="https://github.com/teal-language/tealdoc">Tealdoc</a></span>',
    })

    return table.concat(groups, "\n")
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

--- The pages routed directly beneath this one, which is what a submodule is
--- from the site's point of view.
---
--- Not read from the type graph, because a namespace and a module do not have
--- to be the same thing: a page assembled from four modules has no single
--- record whose fields are its submodules, and a module documented on its own
--- page is not a field of anything. What does hold is the routing. A page at
--- `modules/gfx/layers` is inside the one at `modules/gfx`, and that is true
--- of any site whose routes nest, without it having to say so twice.
local function submodule_summary(
    page: SiteGenerator.Page,
    context: SiteGenerator.Context,
    base: string
): string
    local route = (page.path or ""):gsub("/+$", "")
    if route == "" then
        return ""
    end
    local children: {SiteGenerator.Page} = {}
    for _, other in ipairs(context.pages or {}) do
        local candidate = (other.path or ""):gsub("/+$", "")
        local rest = candidate:match("^" .. route:gsub("%p", "%%%0") .. "/(.+)$")
        if rest and not rest:find("/") then
            table.insert(children, other)
        end
    end
    if #children == 0 then
        return ""
    end
    table.sort(children, function(
        left: SiteGenerator.Page,
        right: SiteGenerator.Page
    ): boolean
        return (left.title or "") < (right.title or "")
    end)

    local output: {string} = {
        "**Submodules**\n\n",
        "| Submodule | Description |\n",
        "| --- | --- |\n",
    }
    for _, child in ipairs(children) do
        table.insert(
            output,
            "| [`" ..
                escape_html(child.title or child.path) ..
                "`](" ..
                escape_html(page_url(base, child.path)) ..
                ") | " ..
                escape_html(child.description or "") ..
                " |\n"
        )
    end
    table.insert(output, "\n")
    return table.concat(output)
end

local function render_page(
    page: SiteGenerator.Page,
    view: SiteTypes.ApiView,
    context: SiteGenerator.Context,
    resolver: MarkdownGenerator.URLResolver,
    attached_examples: {string: {PreparedExample}},
    used_examples: {string: boolean},
    site_links: Highlighter.Links,
    format_code?: function(string): string
): string, {SearchEntry}, string
    local markdown = SiteApi.source_markdown(page)
    local api, module_introduction = SiteApi.markdown(
        view,
        resolver,
        attached_examples,
        used_examples,
        format_code
    )
    if view then
        local summary = submodule_summary(page, context, context.settings.base) ..
            SiteApi.summary(view, resolver)
        if summary ~= "" then
            summary = "## Module contents\n\n" .. summary
        end
        local public_name = view.public
        if not markdown:match("%S") then
            markdown = "# " .. public_name
        end
        markdown = markdown ..
            "\n\n" ..
            (
                module_introduction ~= ""
                    and module_introduction .. "\n\n"
                    or ""
            ) ..
            summary ..
            "\n" ..
            api
    end

    -- The page's own types first, because a name most likely means the one
    -- this page documents, and the rest of the site behind them. Layered
    -- rather than replaced: a name unambiguous inside one module is often
    -- ambiguous across the site, and preferring the site's answer would drop
    -- links a module page has today.
    local type_links = SiteApi.type_links(view, resolver)
    for name, url in pairs(site_links or {}) do
        if type_links[name] == nil then
            type_links[name] = url
        end
    end
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

local function llms_index_txt(
    settings: SiteGenerator.Settings,
    pages: {SiteGenerator.Page}
): string
    local name = settings.name ~= "" and settings.name or settings.title
    local output: {string} = {"# " .. name .. "\n"}
    if settings.description and settings.description ~= "" then
        table.insert(output, "\n> " .. settings.description .. "\n")
    end
    table.insert(output, "\n## Documentation\n")
    for _, page in ipairs(pages) do
        local target = page.path and page.path ~= ""
            and page_url(settings.base, page.path) .. "llms.txt"
            or markdown_url(settings.base, "")
        local line = "\n- [" .. page.title .. "](" .. target .. ")"
        if page.description and page.description ~= "" then
            line = line .. ": " .. page.description
        end
        table.insert(output, line)
    end
    table.insert(
        output,
        "\n\n- [Complete documentation](" ..
            root_file_url(settings.base, "llms-full.txt") ..
            ")\n"
    )
    return table.concat(output)
end

local function llms_full_txt(
    settings: SiteGenerator.Settings,
    pages: {SiteGenerator.Page},
    markdown: {string}
): string
    local name = settings.name ~= "" and settings.name or settings.title
    local output: {string} = {"# " .. name .. "\n"}
    if settings.description and settings.description ~= "" then
        table.insert(output, "\n> " .. settings.description .. "\n")
    end
    for index, page in ipairs(pages) do
        table.insert(
            output,
            "\n---\n\n## " ..
                page.title ..
                "\n\n" ..
                (markdown[index] or ""):gsub("^%s+", ""):gsub("%s+$", "") ..
                "\n"
        )
    end
    return table.concat(output)
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
    local format_code = settings.format_generated_code
        and cerulean_formatter()
        or nil
    -- Where a site keeps its Scintillua lexers, if it keeps any. Set once for
    -- the build rather than threaded through every render, because it is a
    -- property of the installation and not of a page.
    Scintillua.configure(settings.lexers)
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
    if settings.cname then
        assert(
            valid_cname(settings.cname),
            "tealdoc.site.cname must be a bare DNS name"
        )
    end
    local public_files: {PublicFile} = {}
    if settings.public then
        collect_public_directory(settings.public, "", public_files)
    end
    local planned = planned_output_paths(
        settings,
        context.pages,
        settings.redirects,
        public_files
    )
    local output_attributes = lfs.symlinkattributes(output)
    assert(
        not output_attributes or output_attributes.mode == "directory",
        "site output must be a directory and may not be a symbolic link"
    )
    local previous = read_manifest(output)
    prune_previous_outputs(output, previous, planned)
    validate_output_destinations(output, planned, previous)
    mkdir_p(output)
    mkdir_p(output .. "/assets")

    -- Everything that writes runs inside this, so a build that fails partway
    -- takes its own output back out with it.
    --
    -- The manifest is published only by a build that finished, which is what
    -- keeps a failure from claiming files it never wrote. Left alone, though,
    -- that is half a transaction: the record rolls back and the files do not,
    -- so the next run met output nothing claimed to own and refused to touch
    -- it, naming a different file each time depending on which the iteration
    -- reached first. Removing what this build wrote makes the two halves
    -- agree.
    local function render_everything()
    mkdir_p(output .. "/assets")

    copy_public_files(output, public_files, context.files)

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
    -- Built once for the whole site: it is the same table every time and
    -- walking the registry is not free.
    local public_paths: {string: string} = {}
    for _, view in pairs(views) do
        for source_path, public_path in pairs(view.source_to_public) do
            public_paths[source_path] = public_path
        end
    end
    local site_links = SiteApi.site_type_links(env, resolver, public_paths)
    local search_entries: {SearchEntry} = {}
    local page_markdown: {string} = {}
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
            used_examples,
            site_links,
            format_code
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
        table.insert(page_markdown, markdown)
        if page.path and page.path ~= "" then
            local llms_path = directory .. "/llms.txt"
            write_file(llms_path, markdown)
            table.insert(context.files, llms_path)
        end
        for _, entry in ipairs(page_entries) do
            table.insert(search_entries, entry)
        end
    end

    local llms_index_path = output .. "/llms.txt"
    write_file(
        llms_index_path,
        llms_index_txt(settings, context.pages)
    )
    table.insert(context.files, llms_index_path)
    local llms_full_path = output .. "/llms-full.txt"
    write_file(
        llms_full_path,
        llms_full_txt(settings, context.pages, page_markdown)
    )
    table.insert(context.files, llms_full_path)

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
            used_examples,
            site_links,
            format_code
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
    local owned: {string: boolean}
    local validation_files: {string}
    owned, validation_files = recorded_output_paths(
        output,
        context.files,
        planned
    )
    if settings.validate_links ~= false then
        SiteValidator.validate(output, settings.base, validation_files)
    end
    write_manifest(output, owned)
    end

    local failure: any
    local ok = xpcall(render_everything, function(message: any): any
        failure = message
        return message
    end)
    if not ok then
        for path in pairs(planned) do
            if path ~= MANIFEST_PATH and not previous[path] then
                local destination = output .. "/" .. path
                local attributes = lfs.symlinkattributes(destination)
                if attributes and attributes.mode == "file" then
                    os.remove(destination)
                end
                remove_empty_parents(output, path)
            end
        end
        error(failure, 0)
    end
end

return SiteGenerator
