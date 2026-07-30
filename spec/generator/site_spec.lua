local lfs = require("lfs")
local DefaultEnv = require("tealdoc.default_env")
local SiteGenerator = require("tealdoc.generator.site")
local Highlighter = require("tealdoc.generator.site.highlighter")
local PageTemplate = require("tealdoc.generator.site.page_template")
local SiteMarkdown = require("tealdoc.generator.site.markdown")
local tealdoc = require("tealdoc")

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local contents = assert(file:read("*a"))
    file:close()
    return contents
end

local function count_occurrences(haystack, needle)
    local found = 0
    local cursor = 1
    while true do
        local first, last = haystack:find(needle, cursor, true)
        if not first then
            return found
        end
        found = found + 1
        cursor = last + 1
    end
end

local function remove_tree(path)
    local attributes = lfs.symlinkattributes(path)
    if not attributes then
        return
    end
    if attributes.mode == "directory" then
        for entry in lfs.dir(path) do
            if entry ~= "." and entry ~= ".." then
                remove_tree(path .. "/" .. entry)
            end
        end
        assert(lfs.rmdir(path))
    else
        assert(os.remove(path))
    end
end

local function write_file(path, contents)
    local file = assert(io.open(path, "w"))
    file:write(contents)
    file:close()
end

local function write_nested_file(root, path, contents)
    local current = root
    local parent = path:match("^(.*)/[^/]+$")
    if parent then
        for segment in parent:gmatch("[^/]+") do
            current = current .. "/" .. segment
            local attributes = lfs.attributes(current)
            if not attributes then
                assert(lfs.mkdir(current))
            else
                assert.are.equal("directory", attributes.mode)
            end
        end
    end
    write_file(root .. "/" .. path, contents)
end

local function with_preloaded_modules(modules, run)
    local previous_preload = {}
    local previous_loaded = {}
    local had_preload = {}
    local had_loaded = {}
    for name, loader in pairs(modules) do
        had_preload[name] = package.preload[name] ~= nil
        had_loaded[name] = package.loaded[name] ~= nil
        previous_preload[name] = package.preload[name]
        previous_loaded[name] = package.loaded[name]
        package.preload[name] = loader
        package.loaded[name] = nil
    end
    local ok, message = pcall(run)
    for name in pairs(modules) do
        package.preload[name] = had_preload[name]
            and previous_preload[name]
            or nil
        package.loaded[name] = had_loaded[name]
            and previous_loaded[name]
            or nil
    end
    assert.is_true(ok, message)
end

describe("Site generator", function()
    it("requires every page template value", function()
        assert.has_error(function()
            PageTemplate.render({})
        end)
    end)

    it("loads narrow site template overrides from a directory", function()
        local root = os.tmpname()
        os.remove(root)
        assert(lfs.mkdir(root))
        local overrides = {
            ["layout.html"] = [[<html>
{(header.html)}
{[content_template]}
{(footer.html)}
</html>
]],
            ["header.html"] = [[<header class="project-header">{*brand*}</header>
]],
            ["content.html"] = [[<main class="project-content">{*content*}</main>
]],
            ["home.html"] = [[<main class="project-home">{*home_hero*}{*content*}</main>
]],
            ["footer.html"] = [[<footer class="project-footer">{*footer_items*}</footer>
]],
        }
        for name, source in pairs(overrides) do
            local file = assert(io.open(root .. "/" .. name, "w"))
            file:write(source)
            file:close()
        end

        local values = {
            language = "en",
            title = "Template test",
            description = "Template test",
            head = '<meta name="theme-color" content="#123456">',
            stylesheet_url = "/assets/tealdoc.css",
            pico_stylesheet_url = "/assets/pico.classless.min.css",
            search_index_url = "/assets/search-index.js",
            script_url = "/assets/tealdoc.js",
            brand = '<a href="/">Project</a>',
            top_navigation = "",
            header_actions = "",
            sidebar_links = "",
            shell_class = "tealdoc-shell",
            sidebar = "",
            content_class = "tealdoc-content",
            breadcrumbs = "",
            mobile_outline = "",
            content = "<h1>Content</h1>",
            home_hero = "<h1>Hero</h1>",
            page_navigation = "",
            outline = "",
            search_dialog = "",
            footer_class = "",
            footer_items = "<span>Project footer</span>",
            content_template = "content.html",
        }
        local html = PageTemplate.render(values, root)
        assert.is_truthy(html:find(
            '<header class="project-header">',
            1,
            true
        ))
        assert.is_truthy(html:find('<a href="/">Project</a>', 1, true))
        assert.is_truthy(html:find("<h1>Content</h1>", 1, true))
        assert.is_falsy(html:find("tealdoc-search-button", 1, true))

        values.content_template = "home.html"
        local home_html = PageTemplate.render(values, root)
        assert.is_truthy(home_html:find(
            '<main class="project-home"><h1>Hero</h1><h1>Content</h1></main>',
            1,
            true
        ))
        assert.is_truthy(home_html:find(
            '<footer class="project-footer"><span>Project footer</span></footer>',
            1,
            true
        ))

        for name in pairs(overrides) do
            assert(os.remove(root .. "/" .. name))
        end
        assert(lfs.rmdir(root))
    end)

    it("syntax highlights Teal without changing its text", function()
        local html = Highlighter.highlight(
            "local count: integer = math.floor(42) -- total\n" ..
                'return true, window.title, "safe <text>"\n'
        )
        assert.is_truthy(html:find(
            'class="token keyword keyword-local tealdoc-token-keyword"',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token class-name tealdoc-token-type">integer</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token number tealdoc-token-number">42</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token variable tealdoc-token-variable">math</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token function tealdoc-token-function">floor</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token boolean tealdoc-token-boolean">true</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token property tealdoc-token-property">title</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token punctuation tealdoc-token-punctuation">(</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token comment tealdoc-token-comment">-- total</span>',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'class="token string tealdoc-token-string">&quot;safe &lt;text&gt;&quot;</span>',
            1,
            true
        ))

        local linked = Highlighter.highlight(
            "function api.open(window: Window): Window\n",
            {Window = "/modules/window/"}
        )
        assert.is_truthy(linked:find(
            '<a class="tealdoc-code-link" href="/modules/window/"><span class="token class-name tealdoc-token-type">Window</span></a>',
            1,
            true
        ))
        local declaration = Highlighter.highlight(
            "record api.Window\n",
            {Window = "/modules/window/"}
        )
        assert.is_falsy(declaration:find("tealdoc-code-link", 1, true))

        local member = Highlighter.highlight(
            "interface api.Options is BaseOptions\n" ..
                "    window: Window\n" ..
                "end\n",
            {
                ["api.Options.window"] =
                    "/modules/api/#api.Options.window",
                Window = "/modules/window/",
            }
        )
        assert.is_truthy(member:find(
            '<a class="tealdoc-code-link tealdoc-code-link-variable" ' ..
                'href="/modules/api/#api.Options.window">' ..
                '<span class="token variable tealdoc-token-variable">' ..
                "window</span></a>",
            1,
            true
        ), member)
    end)

    it("links a qualified type by the whole path it is written under",
        function()
            local links = {
                Window = "/modules/window/",
                ["shell.Window"] = "/modules/shell/#shell.Window",
            }

            -- The qualifier decides, so the two spellings answer differently
            -- and neither answers for the other.
            local qualified = Highlighter.highlight(
                "local frame: shell.Window = nil\n",
                links
            )
            assert.is_truthy(qualified:find(
                '<a class="tealdoc-code-link" ' ..
                    'href="/modules/shell/#shell.Window">' ..
                    '<span class="token class-name tealdoc-token-type">' ..
                    "Window</span></a>",
                1,
                true
            ), qualified)

            local bare = Highlighter.highlight(
                "local frame: Window = nil\n",
                links
            )
            assert.is_truthy(bare:find(
                '<a class="tealdoc-code-link" href="/modules/window/">' ..
                    '<span class="token class-name tealdoc-token-type">' ..
                    "Window</span></a>",
                1,
                true
            ), bare)

            -- A path the site documents nothing under stays unlinked rather
            -- than falling back to whatever public type shares its last
            -- segment. `type Window = internal.platform.Window` reads as a
            -- declaration linking to itself when it does.
            local foreign = Highlighter.highlight(
                "type Window = internal.platform.Window\n",
                links
            )
            assert.is_falsy(foreign:find("tealdoc-code-link", 1, true), foreign)
        end)

    it("labels a fenced block and highlights it through its attributes",
        function()
            local html = SiteMarkdown.render(
                "```teal{2}\nlocal a = 1\nlocal b = 2\n```\n",
                {}
            )
            -- The attributes are cut before the language is looked up, so the
            -- block highlights, and the label reads the language rather than
            -- the whole info string.
            assert.is_truthy(html:find(
                '<div class="tealdoc-code-block" data-lang="teal">',
                1,
                true
            ), html)
            assert.is_truthy(html:find("tealdoc-token-keyword", 1, true), html)
            -- What was written stays on the class, so a site can style it.
            assert.is_truthy(html:find('class="language-teal{2}"', 1, true), html)

            -- A language with no tokenizer is labelled and left alone.
            local shell = SiteMarkdown.render("```bash\nls -l\n```\n", {})
            assert.is_truthy(shell:find(
                '<div class="tealdoc-code-block" data-lang="bash">',
                1,
                true
            ), shell)
            assert.is_falsy(shell:find("tealdoc-token-", 1, true))
        end)

    it("leaves a block alone when no lexer directory is configured", function()
        -- The whole point of the setting being optional: a site that says
        -- nothing about lexers gets exactly what it got before there were
        -- any, rather than a hard dependency on a library that is not on
        -- LuaRocks.
        local Scintillua = require("tealdoc.generator.site.scintillua")
        assert.is_true(Scintillua.supports("glsl"))
        Scintillua.configure(nil)
        local html = SiteMarkdown.render("```bash\nls -l # note\n```\n", {})
        assert.is_truthy(html:find(
            '<div class="tealdoc-code-block" data-lang="bash">',
            1,
            true
        ), html)
        assert.is_falsy(html:find("tealdoc-token-", 1, true), html)
        Scintillua.configure("/tealdoc-spec/no/such/directory")
        local missing = SiteMarkdown.render("```bash\nls -l\n```\n", {})
        assert.is_falsy(missing:find("tealdoc-token-", 1, true), missing)
        Scintillua.configure(nil)
    end)

    it("assembles one public API page from several source modules", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local type Camera = require("Camera")
            local record first
                --- A projected widget.
                record Widget
                    name: string
                end

                --- A shared alias exported by more than one module.
                type Shared = Widget

                --- A class exported from its own source module.
                Camera: Camera
            end

            return first
        ]], "first.tl", env)
        tealdoc.process_text([[
            local type first = require("first")
            local record hidden
                record Secret
                end
            end

            return hidden
        ]], "hidden.tl", env)
        tealdoc.process_text([[
            local type first = require("first")
            local type hidden = require("hidden")
            local record KindTypes
                --- The value for this kind.
                widget: first.Widget
            end
            local enum Status
                "ready"
                "waiting"
            end
            local record second
                --- An alias that remains linked after projection.
                type WidgetAlias = first.Widget

                --- The same shared alias re-exported here.
                type Shared = first.Widget

                --- Returns the same widget.
                copy: function(widget: first.Widget): first.Widget

                --- Mentions an internal type which has no public page.
                conceal: function(secret: hidden.Secret)

                --- Exposes one type per kind.
                on: KindTypes

                --- Publishes a same-named structural type.
                type Status = Status

                --- Reports the current status.
                status: Status
            end

            return second
        ]], "second.tl", env)
        tealdoc.process_text([[
            local record Camera
                --- Horizontal position.
                x: number
            end

            return Camera
        ]], "Camera.tl", env)
        tealdoc.process_text([[
            local record types
                --- A type published at another root.
                record Root
                    --- Copies this value.
                    copy: function(self): Root
                end

                --- A type omitted from the projection.
                record Hidden
                end
            end

            return types
        ]], "types.tl", env)

        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, env, {
            title = "Combined API",
            pages = {
                {
                    path = "",
                    title = "Home",
                },
                {
                    path = "api",
                    title = "Combined",
                    api = {
                        "first",
                        "second",
                        "Camera",
                        {
                            module = "types",
                            public = "public",
                            include = {"Root"},
                        },
                    },
                    public = "public.api",
                },
            },
        })

        local html = read_file(output .. "/api/index.html")
        local markdown = read_file(output .. "/api.md")
        assert.is_truthy(html:find('id="public.api.Widget"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.WidgetAlias"', 1, true), html)
        assert.equals(
            1,
            select(2, html:gsub('id="public.api.Shared"', ""))
        )
        assert.is_truthy(html:find('id="public.api.copy"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.Camera"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.Camera.x"', 1, true), html)
        assert.is_truthy(html:find('id="public.Root"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.KindTypes"', 1, true), html)
        assert.is_truthy(html:find(
            'id="public.api.KindTypes.widget"',
            1,
            true
        ), html)
        assert.is_truthy(html:find('id="public.api.Status"', 1, true), html)
        assert.is_truthy(html:find(
            'id="public.api.Status.&quot;ready&quot;"',
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            'href="/api/#public.api.KindTypes"',
            1,
            true
        ), html)
        assert.is_truthy(markdown:find(
            "| [`on`](/api/#public.api.on) | " ..
                "[`KindTypes`](/api/#public.api.KindTypes) |",
            1,
            true
        ), markdown)
        assert.is_truthy(html:find('href="/api/#public.Root"', 1, true), html)
        assert.is_falsy(html:find('id="public.Hidden"', 1, true))
        assert.is_falsy(html:find('id="public.api.x"', 1, true))
        assert.is_truthy(html:find('href="/api/#public.api.Widget"', 1, true), html)
        assert.is_falsy(html:find("#public.api.Secret", 1, true))
        assert.is_falsy(html:find("#hidden.Secret", 1, true))

        remove_tree(output)
    end)

    it("links code by the path a type is published under", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record internal
                --- A shape only its public alias documents.
                type Circle = {radius: number}

                record Event
                end

                --- A listener only its public alias documents.
                type EventListener = function<E is Event>(event: E)

                --- A scalar component only its public alias documents.
                interface ScalarComponent<T>
                    --- The value stored when no value is supplied.
                    scalarDefault: T
                    --- Reads the stored scalar explicitly.
                    read: function(self: ScalarComponent<T>): T
                    --- Reads the stored scalar.
                    metamethod __call:
                        function(self: ScalarComponent<T>): T
                end

                --- Scalar component configuration.
                interface ScalarComponentOptions<T>
                    --- The component this configuration creates.
                    component: ScalarComponent<T>
                end
            end

            return internal
        ]], "internal.tl", env)
        tealdoc.process_text([[
            local record targets
                --- A listener with its own public definition.
                type Listener = function(message: string)
            end

            return targets
        ]], "targets.tl", env)
        tealdoc.process_text([[
            local type internal = require("internal")
            local type targets = require("targets")
            local record shapes
                --- The shape, under the name the site publishes it as.
                type Circle = internal.Circle

                --- A private listener rendered as its concrete function type.
                type EventListener = internal.EventListener

                --- A public listener linked to its definition.
                type Listener = targets.Listener

                --- A private generic interface projected under this alias.
                type ScalarComponent<T> = internal.ScalarComponent<T>

                --- Another private generic interface projected here.
                type ScalarComponentOptions<T> =
                    internal.ScalarComponentOptions<T>

                --- A relationship constraint documented on this page.
                interface Relationship
                end

                --- Options constrained to the exact relationship above.
                type RelationshipOptions<R is Relationship> = {value: R}

                --- Grows one.
                grow: function(circle: Circle): Circle
            end

            return shapes
        ]], "shapes.tl", env)

        local guide = os.tmpname()
        write_file(guide, "# Guide\n\n" ..
            "```teal\n" ..
            "local a: public.shapes.Circle = nil\n" ..
            "local b: internal.Circle = nil\n" ..
            "local c: Circle = nil\n" ..
            "```\n")
        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, env, {
            title = "Shapes",
            pages = {
                {path = "", title = "Home", source = guide},
                {
                    path = "shapes",
                    title = "shapes",
                    api = "shapes",
                    public = "public.shapes",
                },
                {
                    path = "targets",
                    title = "targets",
                    api = "targets",
                    public = "public.targets",
                },
            },
        })

        local link = '<a class="tealdoc-code-link" ' ..
            'href="/shapes/#public.shapes.Circle">' ..
            '<span class="token class-name tealdoc-token-type">' ..
            "Circle</span></a>"
        local guide_html = read_file(output .. "/index.html")
        -- The published path and the bare name, and nothing for the source
        -- path the site says nothing about.
        assert.are.equal(2, count_occurrences(guide_html, link), guide_html)
        assert.is_truthy(guide_html:find(
            '<span class="token property tealdoc-token-property">internal' ..
                '</span><span class="token punctuation ' ..
                'tealdoc-token-punctuation">.</span>' ..
                '<span class="token class-name tealdoc-token-type">' ..
                "Circle</span>",
            1,
            true
        ), guide_html)

        -- Authored code still says what it says: the source path is private
        -- and therefore has nowhere honest to link.
        --
        -- A generated declaration is different. Tealdoc knows that it is an
        -- alias and can say what a private target means instead of publishing
        -- an internal spelling.
        local shapes_html = read_file(output .. "/shapes/index.html")
        local shapes_markdown = read_file(output .. "/shapes.md")
        assert.is_falsy(shapes_markdown:find(
            "type public.shapes.Circle = internal.Circle",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "type public.shapes.Circle = {radius : number}",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "type public.shapes.EventListener = " ..
                "function<E is Event>(E)",
            1,
            true
        ), shapes_markdown)
        assert.is_falsy(shapes_markdown:find(
            "generic<T> internal.ScalarComponent",
            1,
            true
        ), shapes_markdown)
        assert.is_falsy(shapes_markdown:find(
            "generic<T> internal.ScalarComponentOptions",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "interface public.shapes.ScalarComponent<T>",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "public.shapes.ScalarComponent.scalarDefault",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "#### public.shapes.ScalarComponent.__call",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "    scalarDefault: T\n\n" ..
                "    read: function(self): T\n" ..
                "    metamethod __call: function",
            1,
            true
        ), shapes_markdown)
        assert.is_falsy(shapes_markdown:find(
            "##### public.shapes.ScalarComponent.__call",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "interface public.shapes.ScalarComponentOptions<T>",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_html:find(
            '<a class="tealdoc-code-link tealdoc-code-link-variable" ' ..
                'href="/shapes/#public.shapes.ScalarComponentOptions.' ..
                'component">' ..
                '<span class="token variable tealdoc-token-variable">' ..
                "component</span></a>",
            1,
            true
        ), shapes_html)
        assert.is_truthy(shapes_html:find(
            '<a class="tealdoc-code-link tealdoc-code-link-property" ' ..
                'href="/shapes/#public.shapes.ScalarComponentOptions.' ..
                'component">' ..
                '<span class="token property tealdoc-token-property">' ..
                "component</span></a>",
            1,
            true
        ), shapes_html)
        assert.is_truthy(shapes_html:find(
            '<a class="tealdoc-code-link tealdoc-code-link-variable" ' ..
                'href="/shapes/#public.shapes.ScalarComponent.read">' ..
                '<span class="token variable tealdoc-token-variable">' ..
                "read</span></a>",
            1,
            true
        ), shapes_html)
        assert.is_truthy(shapes_html:find(
            '<a class="tealdoc-code-link tealdoc-code-link-variable" ' ..
                'href="/shapes/#public.shapes.ScalarComponent.' ..
                '$meta.__call">' ..
                '<span class="token variable tealdoc-token-variable">' ..
                "__call</span></a>",
            1,
            true
        ), shapes_html)
        assert.is_falsy(shapes_markdown:find(
            "function(self: ScalarComponent<T>)",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "function(self): T",
            1,
            true
        ), shapes_markdown)
        assert.is_truthy(shapes_markdown:find(
            "| `R` | " ..
                "[`Relationship`](/shapes/#public.shapes.Relationship) |",
            1,
            true
        ), shapes_markdown)

        -- A target another page documents keeps the alias spelling and links
        -- through the import name to that target rather than to this page's
        -- same-named declaration.
        assert.is_truthy(shapes_html:find(
            '<a class="tealdoc-code-link" ' ..
                'href="/targets/#public.targets.Listener">' ..
                '<span class="token class-name tealdoc-token-type">' ..
                "Listener</span></a>",
            1,
            true
        ), shapes_html)
        assert.are.equal(2, count_occurrences(shapes_html, link), shapes_html)

        remove_tree(output)
        os.remove(guide)
    end)

    it("carries a union type through a parameter table to the page", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                --- Finds a thing by name.
                --- @param name What to look for.
                --- @return The thing, or nil when there is none.
                find: function(name: string): string | nil
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, env, {
            title = "Union",
            pages = {
                {path = "", title = "Home"},
                {path = "api", title = "API", api = "api"},
            },
        })

        local html = read_file(output .. "/api/index.html")

        -- The pipe that spells the union is also the cell separator, so it only
        -- reaches the page if the row it was written into kept it out of the way.
        assert.is_truthy(html:find("<th>Name</th>", 1, true), html)
        assert.is_truthy(html:find(
            "<td><code>name</code></td>",
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            "<td><code>string | nil</code></td>",
            1,
            true
        ), html)

        remove_tree(output)
    end)

    it("formats generated code and Teal examples with Cerulean", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                --- Runs a generated operation.
                ---
                --- ```teal
                --- if ready then
                --- run()
                --- end
                --- ```
                run: function(first: string, second: string): boolean
                --- Stops a generated operation.
                stopWithAnExtremelyLongName: function(string)
            end

            return api
        ]], "api.tl", env)

        local source = os.tmpname()
        write_file(source, [[
# Authored page

```teal
local authored  =  true
```

```teal no-format
local preserved  =  true
```
]])
        local example = os.tmpname()
        write_file(example, "local example  =  true\n")
        local output = os.tmpname()
        os.remove(output)

        local calls = 0
        local initializations = 0
        local handed = {}
        with_preloaded_modules({
            ["cerulean.options"] = function()
                return {
                    default = function()
                        initializations = initializations + 1
                        return {max_line_width = 88}
                    end,
                }
            end,
            ["cerulean.rewriter"] = function()
                return {
                    rewrite = function(code, _, options)
                        calls = calls + 1
                        table.insert(handed, code)
                        assert.are.equal(72, options.max_line_width)
                        if code:match("^function ")
                            and not code:find(
                                "end -- tealdoc:generated-declaration-end",
                                1,
                                true
                            )
                        then
                            return {
                                output = code,
                                status = "unchanged",
                                parse_errors = {
                                    {msg = "expected 'end'"},
                                },
                            }
                        end
                        local output = code:gsub(
                            "\nrun%(%)\n",
                            "\n    run()\n"
                        )
                        return {
                            output = "-- formatted by Cerulean\n" .. output,
                            status = "reformatted",
                            parse_errors = {},
                        }
                    end,
                }
            end,
        }, function()
            SiteGenerator.build(output, env, {
                title = "Formatting",
                format_generated_code = true,
                validate_links = false,
                pages = {
                    {
                        path = "api",
                        title = "API",
                        source = source,
                        api = "api",
                    },
                },
                examples = {
                    {
                        attach_to = "api.run",
                        source = example,
                        language = "teal",
                    },
                },
            })
        end)

        local markdown = read_file(output .. "/api.md")
        assert.are.equal(1, initializations)
        assert.are.equal(5, calls)
        assert.is_truthy(table.concat(handed, "\n"):find(
            "local TealdocGenerated1XXXXXXX: function(string)",
            1,
            true
        ), table.concat(handed, "\n"))
        assert.is_truthy(markdown:find(
            "```teal\n-- formatted by Cerulean\nfunction api.run",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "\nfunction api.stopWithAnExtremelyLongName",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "| `#1` | `string` |",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "tealdoc:generated-declaration-end",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "```teal\n-- formatted by Cerulean\n" ..
                "local authored  =  true\n```",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "```teal\nlocal preserved  =  true\n```",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find("no-format", 1, true), markdown)
        assert.is_truthy(markdown:find(
            "```teal\n-- formatted by Cerulean\n" ..
                "if ready then\n" ..
                "    run()\n" ..
                "end\n```",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "```teal\n-- formatted by Cerulean\n" ..
                "local example  =  true\n```",
            1,
            true
        ), markdown)

        remove_tree(output)
        os.remove(source)
        os.remove(example)
    end)

    it("hands Cerulean a generic type alias Teal will take", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                --- Holds one value.
                interface Holder<T>
                    item: T
                end

                --- Names a keyed lookup.
                type Key<T> = {T}

                --- Names a constrained option set.
                type Options<C is Holder<string>> = {string: C}
            end

            return api
        ]], "api.tl", env)

        local source = os.tmpname()
        write_file(source, "# Generics\n")
        local output = os.tmpname()
        os.remove(output)

        local handed = {}
        with_preloaded_modules({
            ["cerulean.options"] = function()
                return {
                    default = function()
                        return {max_line_width = 88}
                    end,
                }
            end,
            ["cerulean.rewriter"] = function()
                return {
                    rewrite = function(code)
                        table.insert(handed, code)
                        return {
                            output = code,
                            status = "unchanged",
                            parse_errors = {},
                        }
                    end,
                }
            end,
        }, function()
            SiteGenerator.build(output, env, {
                title = "Generics",
                format_generated_code = true,
                validate_links = false,
                pages = {
                    {
                        path = "api",
                        title = "API",
                        source = source,
                        api = "api",
                    },
                },
            })
        end)

        -- The parameters move onto the borrowed name, which is where Teal
        -- writes them, and the `generic` marker the compiler shows a type
        -- with is gone from everything the formatter reads.
        local seen = table.concat(handed, "\n")
        assert.is_truthy(seen:find(
            "local type TealdocGenerated1<T> = {T}",
            1,
            true
        ), seen)
        assert.is_truthy(seen:find(
            "local type TealdocGenerated1<C is Holder<string>> = {string : C}",
            1,
            true
        ), seen)
        assert.is_falsy(seen:find("generic<", 1, true), seen)

        -- The path and the marker come back exactly as they were written,
        -- constraint and all, so a signature says what it said before.
        local markdown = read_file(output .. "/api.md")
        assert.is_truthy(markdown:find(
            "```teal\ntype api.Key = generic<T> {T}\n```",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "```teal\ntype api.Options = " ..
                "generic<C is Holder<string>> {string : C}\n```",
            1,
            true
        ), markdown)

        remove_tree(output)
        os.remove(source)
    end)

    it("requires Cerulean only when generated formatting is enabled", function()
        local output = os.tmpname()
        os.remove(output)
        with_preloaded_modules({
            ["cerulean.options"] = function()
                error("Cerulean is unavailable for this test")
            end,
        }, function()
            local ok, message = pcall(function()
                SiteGenerator.build(output, DefaultEnv.init(), {
                    title = "Formatting",
                    format_generated_code = true,
                    pages = {
                        {path = "", title = "Home"},
                    },
                })
            end)
            assert.is_false(ok)
            assert.is_truthy(tostring(message):find(
                "format_generated_code requires Cerulean on Lua's package path",
                1,
                true
            ), tostring(message))
        end)
        remove_tree(output)
    end)

    it("marks projected const variables in module summaries", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            --- Returns the build identifier.
            global Build <const>: string = "dev"
            return Build
        ]], "Build.tl", env)
        tealdoc.process_text([[
            --- Returns the current status.
            global Status: string = "ready"
            return Status
        ]], "Status.tl", env)

        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, env, {
            title = "Constants",
            pages = {
                {path = "", title = "Home"},
                {
                    path = "constants",
                    title = "Constants",
                    api = {"Build", "Status"},
                    public = "api",
                },
            },
        })

        local markdown = read_file(output .. "/constants.md")
        assert.is_truthy(markdown:find("## Module contents", 1, true), markdown)
        assert.is_truthy(markdown:find(
            "| [`Build`](/constants/#api.Build) | " ..
                "`string` | `<const>` Returns the build identifier. |",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "| [`Status`](/constants/#api.Status) | " ..
                "`string` | Returns the current status. |",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "| [`Status`](/constants/#api.Status) | " ..
                "`string` | `<const>`",
            1,
            true
        ))
        remove_tree(output)
    end)

    it("prefers a dedicated page over a parent-page item route", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record watch
                record Options
                    recursive: boolean
                end
            end
            return watch
        ]], "watch.tl", env)
        tealdoc.process_text([[
            local type watch = require("watch")
            local record filesystem
                watch: watch
                current: watch.Options
                observe: function(): watch.Options
            end
            return filesystem
        ]], "filesystem.tl", env)

        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, env, {
            title = "Nested APIs",
            pages = {
                {
                    path = "",
                    title = "Home",
                },
                {
                    path = "filesystem",
                    title = "Filesystem",
                    api = "filesystem",
                    public = "public.filesystem",
                },
                {
                    path = "filesystem/watch",
                    title = "Watch",
                    api = "watch",
                    public = "public.filesystem.watch",
                },
            },
        })

        local html = read_file(output .. "/filesystem/index.html")
        local markdown = read_file(output .. "/filesystem.md")
        assert.is_truthy(html:find(
            'href="/filesystem/watch/#public.filesystem.watch.Options"',
            1,
            true
        ), html)
        assert.is_truthy(markdown:find(
            "| [`Watch`](/filesystem/watch/) |",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "| [`current`](/filesystem/#public.filesystem.current) | " ..
                "[`Options`](/filesystem/watch/" ..
                "#public.filesystem.watch.Options) |",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "### public.filesystem.watch ",
            1,
            true
        ), markdown)
        remove_tree(output)
    end)

    it("rejects collisions between projected API modules", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record first
                --- First value.
                value: string
            end
            return first
        ]], "first.tl", env)
        tealdoc.process_text([[
            local record second
                --- Second value.
                value: string
            end
            return second
        ]], "second.tl", env)

        local output = os.tmpname()
        os.remove(output)
        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Collision",
                pages = {
                    {
                        path = "api",
                        title = "API",
                        api = {"first", "second"},
                        public = "public.api",
                    },
                },
            })
        end, "duplicate public API path public.api.value from first.value and second.value")
        remove_tree(output)
    end)

    it("renders an explicitly titled recursively nested sidebar", function()
        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Navigation",
            pages = {
                {path = "", title = "Home"},
                {path = "docs/cli", title = "Command line"},
                {path = "docs/cli/config", title = "Configuration"},
                {path = "docs/ecs", title = "ECS"},
                {path = "docs/ecs/components", title = "Components"},
                {path = "docs/ecs/components/bundles", title = "Bundles"},
            },
            sidebar_open = {"CLI"},
            sidebar = {
                {
                    text = "CLI",
                    path = "docs/cli",
                    items = {
                        {path = "docs/cli/config"},
                    },
                },
                {
                    text = "tecs.ecs",
                    path = "docs/ecs",
                    items = {
                        {
                            path = "docs/ecs/components",
                            items = {
                                {path = "docs/ecs/components/bundles"},
                            },
                        },
                    },
                },
            },
        })

        local home = read_file(output .. "/index.html")
        local html = read_file(output .. "/docs/ecs/components/bundles/index.html")
        assert.is_truthy(home:find(
            '<details open><summary><a href="/docs/cli/">CLI</a>' ..
                "</summary>",
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            '<details><summary><a href="/docs/ecs/">tecs.ecs</a>' ..
                "</summary>",
            1,
            true
        ), home)
        assert.is_truthy(html:find(
            '<details open><summary><a href="/docs/ecs/">tecs.ecs</a>' ..
                "</summary>",
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            '<details open><summary><a ' ..
                'href="/docs/ecs/components/">Components</a></summary>',
            1,
            true
        ), html)
        assert.is_falsy(html:find(">Overview</a>", 1, true), html)
        assert.is_truthy(html:find(
            'href="/docs/ecs/components/bundles/" aria-current="page">Bundles</a>',
            1,
            true
        ), html)
        assert.is_falsy(html:find("<summary>Docs</summary>", 1, true))

        remove_tree(output)
    end)

    it("selects route-derived sidebar sections to open", function()
        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Navigation",
            pages = {
                {path = "", title = "Home"},
                {path = "guide/start", title = "Start"},
                {path = "api/reference", title = "Reference"},
            },
            sidebar_open = {"api"},
        })

        local home = read_file(output .. "/index.html")
        assert.is_truthy(home:find(
            "<details><summary>Guide</summary>",
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            "<details open><summary>Api</summary>",
            1,
            true
        ), home)

        remove_tree(output)
    end)

    it("preserves heading identities and file link targets", function()
        local source = os.tmpname()
        write_file(source, [[
# Heading identity

## foo_bar_baz

## foo_bar_baz

## _foo_bar_baz_

## Explicit identity {#custom-id .custom-heading}
]])
        local output = os.tmpname()
        os.remove(output)

        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Identity test",
            base = "/docs/",
            validate_links = false,
            footer_links = {
                {
                    text = "Download archive",
                    path = "downloads/archive.zip?download=1#release",
                },
            },
            pages = {
                {
                    path = "",
                    title = "Home",
                    source = source,
                    layout = "home",
                    hero_actions = {
                        {
                            text = "Download archive",
                            path = "downloads/archive.zip?download=1#release",
                        },
                    },
                },
            },
        })

        local html = read_file(output .. "/index.html")
        assert.is_truthy(html:find(
            '<h2 id="foo-bar-baz" tabindex="-1">',
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            '<h2 id="foo-bar-baz-2" tabindex="-1">',
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            '<h2 id="foo-bar-baz-3" tabindex="-1">',
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            '<h2 class="custom-heading" id="custom-id" tabindex="-1">',
            1,
            true
        ), html)
        assert.is_truthy(html:find('href="#custom-id"', 1, true), html)
        assert.is_falsy(html:find("data-tealdoc-heading-slug", 1, true))
        assert.is_falsy(html:find("{#custom-id", 1, true))
        assert.is_truthy(html:find(
            'href="/docs/downloads/archive.zip?download=1#release"',
            1,
            true
        ), html)
        assert.is_falsy(html:find(
            'archive.zip?download=1#release/"',
            1,
            true
        ), html)

        remove_tree(output)
        os.remove(source)
    end)

    it("rejects duplicate explicit heading IDs", function()
        local source = os.tmpname()
        write_file(source, [[
# Duplicate IDs

## First {#repeated}

## Second {#repeated}
]])
        local output = os.tmpname()
        os.remove(output)

        local ok, message = pcall(function()
            SiteGenerator.build(output, DefaultEnv.init(), {
                title = "Duplicate heading test",
                validate_links = false,
                pages = {
                    {
                        path = "",
                        title = "Home",
                        source = source,
                    },
                },
            })
        end)
        assert.is_false(ok)
        assert.is_truthy(tostring(message):find(
            "duplicate explicit heading id: repeated",
            1,
            true
        ), tostring(message))

        remove_tree(output)
        os.remove(source)
    end)

    it("composes source and API docs into a responsive static site", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record Window
            end

            return Window
        ]], "window.tl", env)
        tealdoc.process_text([==[--[=[
[`API`](tealdoc:api) opens windows and reports display changes through
[`Window`](tealdoc:Window).

# Display changes

It keeps wrapped prose
on adjacent source lines.

```teal
# This remains example code.
local options = {}
local window = api.open(options)
```
]=]

local type Window = require("window")
local record api
    --- Read-only. Reports the number of windows awaiting an event.
    pending: integer

    --- Configures [`Options`](tealdoc:Options).
    record Options
        window: Window
    end

    --- Opens a window.
    ---
    --- ## Window lifetime
    ---
    --- The caller owns the returned window.
    ---
    --- ```teal
    --- # This remains example code.
    --- ```
    --- @param options Window options.
    open: function(options: Options)

    --- Creates a window.
    newWindow: function(options: Options): Window

    --- Shows a [`Window`](tealdoc:Window).
    --- @param window Parent window.
    messageBox: function(window: Window)

    --- Resets this API after clearing every cached value, pending
    --- operation, registered listener, and retained handle so a
    --- caller can start again from a completely clean state.
    reset: function(self: api)
end

return api
]==], "api.tl", env)

        local output = os.tmpname()
        os.remove(output)
        local source = os.tmpname()
        local source_file = assert(io.open(source, "w"))
        source_file:write([[
# Guide

::: warning One thread
Keep **work** on the pumping thread.
:::

> [!IMPORTANT]
> Futures settle in source order.

::: details Complete example
This explanation starts collapsed.
:::

`leading` text.

Text `middle` text.

Text `trailing`

`alone`

::: code-group
```teal [Components]
local answer: integer = 42
print(answer)
```

```lua [Lua]
local answer = 42
print(answer)
```
:::

[Open the API reference](/modules/api/#api.open)

| Name | Meaning |
| --- | --- |
| api | Module |
]])
        source_file:close()
        local example = os.tmpname()
        local example_file = assert(io.open(example, "w"))
        example_file:write("local answer: integer = 42\nprint(answer)\n")
        example_file:close()
        local attached_example = os.tmpname()
        local attached_example_file = assert(io.open(attached_example, "w"))
        attached_example_file:write([[
-- #region identity
local value: string = "checked"
print(value)
-- #endregion identity
]])
        attached_example_file:close()
        local custom_css = os.tmpname()
        local custom_css_file = assert(io.open(custom_css, "w"))
        custom_css_file:write([[/* A comment, which CSS lets stand before an import. */
@import url("https://example.test/font.css");

.project-rule {
    color: rebeccapurple;
}
]])
        custom_css_file:close()
        local public = os.tmpname()
        os.remove(public)
        assert(lfs.mkdir(public))
        assert(lfs.mkdir(public .. "/downloads"))
        local favicon_file = assert(io.open(public .. "/favicon.svg", "w"))
        favicon_file:write("<svg><!-- test --></svg>\n")
        favicon_file:close()
        local notice_file = assert(io.open(
            public .. "/downloads/notice.txt",
            "w"
        ))
        notice_file:write("Public notice\n")
        notice_file:close()

        local before_ran = false
        local after_ran = false
        SiteGenerator.build(output, env, {
            title = "Test",
            name = "Test docs",
            description = "Test documentation",
            language = "en-GB",
            base = "/",
            site_url = "https://docs.example.test",
            logo = "/logo.svg",
            github = "https://github.com/example/test",
            favicon = "favicon.svg",
            public = public,
            cname = "docs.example.test",
            author = "Test contributors",
            social_image = "/social.png",
            twitter_site = "@example",
            head = {
                {
                    tag = "meta",
                    attributes = {
                        name = "theme-color",
                        content = "#123456",
                    },
                },
                {
                    tag = "link",
                    attributes = {
                        rel = "preconnect",
                        href = "https://cdn.example.test",
                    },
                },
            },
            copyright = "Copyright Test contributors",
            license = "Test License",
            footer_links = {
                {text = "Notices", path = "legal/notices"},
            },
            custom_css = custom_css,
            not_found = {
                title = "Missing",
                description = "Nothing is here.",
                source = source,
            },
            redirects = {
                ["old-api.html"] = "modules/api",
            },
            examples = {
                {
                    path = "examples/answer",
                    title = "Checked answer",
                    description = "A compiler-checked Teal example.",
                    source = example,
                    language = "teal",
                },
                {
                    attach_to = "api.open",
                    title = "Open a checked value",
                    source = attached_example,
                    region = "identity",
                    language = "teal",
                },
            },
            constructor_pattern = "^new",
            nav = {
                {text = "Home", path = ""},
            },
            pages = {
                {
                    path = "",
                    title = "Home",
                    description = "Home page",
                    source = source,
                    layout = "home",
                    hero_title = "Hello",
                    hero_text = "Static documentation.",
                    hero_image = "/hero.png",
                    hero_image_alt = "Test hero",
                    hero_actions = {
                        {
                            text = "Get started",
                            path = "modules/api",
                            theme = "brand",
                        },
                    },
                    features = {
                        {
                            title = "Checked",
                            details = "Generated from **source**.",
                            icon = "✓",
                        },
                    },
                },
                {
                    path = "modules/api",
                    title = "API",
                    description = "API page",
                    source = source,
                    api = "api",
                    image = "/api-social.png",
                },
                {
                    path = "modules/window",
                    title = "Window",
                    description = "Window page",
                    api = "window",
                    noindex = true,
                },
                {
                    path = "legal/notices",
                    title = "Notices",
                    description = "Project notices.",
                },
            },
            before_build = function(context)
                before_ran = context.output == output
                    and context.attached_examples == nil
                    and context.attached_examples_used == nil
            end,
            after_build = function(context)
                local generated = {}
                for _, path in ipairs(context.files) do
                    generated[path] = true
                end
                after_ran = generated[output .. "/favicon.svg"]
                    and generated[output .. "/assets/pico.classless.min.css"]
                    and generated[output .. "/sitemap.xml"]
                    and generated[output .. "/robots.txt"]
                    and generated[output .. "/404.html"]
            end,
        })

        local home = read_file(output .. "/index.html")
        local api = read_file(output .. "/modules/api/index.html")
        local css = read_file(output .. "/assets/tealdoc.css")
        local pico = read_file(output .. "/assets/pico.classless.min.css")
        local top_nav_at = assert(home:find(
            'class="tealdoc-top-nav"',
            1,
            true
        ))
        local markdown_action_at = assert(home:find(
            'title="View Markdown"',
            top_nav_at,
            true
        ))
        local github_action_at = assert(home:find(
            'title="GitHub"',
            markdown_action_at,
            true
        ))
        local theme_action_at = assert(home:find(
            'title="Toggle theme"',
            github_action_at,
            true
        ))
        local search_action_at = assert(home:find(
            'class="tealdoc-search-button"',
            theme_action_at,
            true
        ))
        assert.is_true(top_nav_at < markdown_action_at)
        assert.is_true(markdown_action_at < github_action_at)
        assert.is_true(github_action_at < theme_action_at)
        assert.is_true(theme_action_at < search_action_at)
        local js = read_file(output .. "/assets/tealdoc.js")
        local search = read_file(output .. "/assets/search-index.js")
        local markdown = read_file(output .. "/modules/api.md")
        local llms = read_file(output .. "/modules/api/llms.txt")
        local llms_index = read_file(output .. "/llms.txt")
        local llms_full = read_file(output .. "/llms-full.txt")
        local manifest = read_file(output .. "/.tealdoc-manifest")
        local window_html = read_file(output .. "/modules/window/index.html")
        local window_markdown = read_file(output .. "/modules/window.md")
        local redirect = read_file(output .. "/old-api.html")
        local example_html = read_file(output .. "/examples/answer/index.html")
        local not_found = read_file(output .. "/404.html")
        local sitemap = read_file(output .. "/sitemap.xml")
        local robots = read_file(output .. "/robots.txt")
        assert.is_true(before_ran)
        assert.is_true(after_ran)
        assert.is_truthy(home:find(
            'href="/assets/pico.classless.min.css"',
            1,
            true
        ))
        assert.is_falsy(home:find("cdn.jsdelivr.net", 1, true))
        assert.is_truthy(pico:find("Pico CSS ✨ v2.1.1", 1, true))
        assert.is_truthy(home:find('<html lang="en-GB">', 1, true))
        assert.is_truthy(home:find(
            '<link rel="icon" href="/favicon.svg">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<link rel="canonical" href="https://docs.example.test/">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<link rel="alternate" type="text/markdown" href="https://docs.example.test/index.md"',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<a class="tealdoc-footer-llms" href="/index.md">index.md</a>',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<meta property="og:type" content="website">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<meta property="og:image" content="https://docs.example.test/social.png">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<meta property="og:locale" content="en_GB">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<meta name="twitter:site" content="@example">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<meta name="twitter:image" content="https://docs.example.test/social.png">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<meta content="#123456" name="theme-color">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<link href="https://cdn.example.test" rel="preconnect">',
            1,
            true
        ))
        assert.is_truthy(home:find('<table>', 1, true))
        assert.is_truthy(home:find("\n    <head>\n", 1, true))
        assert.is_truthy(home:find("\n            <header", 1, true))
        assert.is_truthy(home:find(
            '<span class="token function tealdoc-token-function">print</span>',
            1,
            true
        ))
        assert.is_falsy(home:find("{{", 1, true))
        assert.is_truthy(home:find('class="tealdoc-mobile-menu"', 1, true))
        assert.is_truthy(home:find('class="tealdoc-hamburger"', 1, true))
        assert.is_truthy(home:find('class="tealdoc-sidebar-section"', 1, true))
        assert.is_falsy(home:find("tealdoc-sidebar-title", 1, true))
        assert.is_truthy(home:find('class="tealdoc-home-hero"', 1, true))
        assert.is_truthy(home:find(
            'class="tealdoc-footer tealdoc-home-footer"',
            1,
            true
        ))
        assert.is_truthy(home:find(
            'class="tealdoc-shell tealdoc-home-shell"',
            1,
            true
        ))
        assert.is_falsy(home:find('<aside class="tealdoc-sidebar"', 1, true))
        assert.is_falsy(home:find('<aside class="tealdoc-outline"', 1, true))
        assert.is_falsy(home:find('class="tealdoc-breadcrumbs"', 1, true))
        assert.is_falsy(home:find('class="tealdoc-page-nav"', 1, true))
        assert.is_truthy(home:find('class="tealdoc-hero-image"', 1, true))
        assert.is_truthy(home:find('class="tealdoc-hero-action brand"', 1, true))
        assert.is_truthy(home:find('class="tealdoc-feature"', 1, true))
        assert.is_truthy(home:find("<strong>source</strong>", 1, true))
        assert.is_truthy(home:find(
            "<p><code>leading</code> text.</p>",
            1,
            true
        ))
        assert.is_truthy(home:find(
            "<p>Text <code>middle</code> text.</p>",
            1,
            true
        ))
        assert.is_truthy(home:find(
            "<p>Text <code>trailing</code></p>",
            1,
            true
        ))
        assert.is_truthy(home:find("<p><code>alone</code></p>", 1, true))
        assert.is_truthy(home:find('class="tealdoc-footer-inner"', 1, true))
        assert.is_truthy(home:find('for="tealdoc-theme-input"', 1, true))
        assert.is_truthy(home:find('data-tealdoc-search', 1, true))
        assert.is_truthy(home:find(
            'data-tealdoc-search-index="/assets/search-index.js"',
            1,
            true
        ))
        assert.is_falsy(home:find(
            '<script src="/assets/search-index.js" defer></script>',
            1,
            true
        ))
        assert.is_truthy(home:find('class="tealdoc-logo"', 1, true))
        assert.is_truthy(home:find('href="/index.md"', 1, true))
        assert.is_truthy(home:find(
            'href="https://github.com/example/test"',
            1,
            true
        ))
        assert.is_truthy(home:find(
            'class="tealdoc-admonition tealdoc-admonition-warning"',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            'class="tealdoc-admonition-title">One thread</p>',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            'class="tealdoc-admonition tealdoc-admonition-important"',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            'class="tealdoc-admonition-title">Important</p>',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            '<details class="tealdoc-details"><summary>Complete example</summary>',
            1,
            true
        ), home)
        -- A labelled group is a tab strip: a radio, its label and its panel
        -- in that order, so one CSS rule shows the panel and styles the tab.
        assert.is_truthy(home:find(
            '<div class="tealdoc-code-group" role="radiogroup"',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            '<label class="tealdoc-code-tab" for=',
            1,
            true
        ), home)
        assert.is_truthy(home:find('>Components</label>', 1, true), home)
        assert.is_truthy(home:find('>Lua</label>', 1, true), home)
        -- Only the first is checked, so a group opens on one panel.
        local _, checked = home:gsub('type="radio"[^>]* checked>', '')
        assert.are.equal(1, checked, home)
        assert.is_truthy(home:find(
            '<figure class="tealdoc-code-panel">',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            'href="/modules/api/#api.open"',
            1,
            true
        ), home)
        assert.is_truthy(home:find("Copyright Test contributors", 1, true))
        assert.is_truthy(home:find(
            '<a class="tealdoc-footer-link" href="/legal/notices/">Notices</a>',
            1,
            true
        ))
        assert.is_truthy(home:find(
            '<a href="https://github.com/teal-language/tealdoc">Tealdoc</a>',
            1,
            true
        ))
        assert.is_truthy(api:find("<h3", 1, true))
        assert.is_truthy(api:find("<h4", 1, true))
        assert.is_truthy(api:find(
            '<li class="level-2 tealdoc-outline-section">' ..
                "<details open><summary><a ",
            1,
            true
        ), api)
        assert.is_truthy(api:find(
            "</summary><ol>",
            1,
            true
        ), api)
        assert.is_truthy(markdown:find("## Module contents", 1, true))
        assert.is_falsy(api:find("Public APIs in", 1, true))
        assert.is_falsy(api:find("Every public item", 1, true))
        assert.is_truthy(api:find("<th>Constructor</th>", 1, true), api)
        assert.is_truthy(api:find("<th>Function</th>", 1, true), api)
        assert.is_truthy(markdown:find(
            "**Constructors**",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find("**Functions**", 1, true), markdown)
        assert.is_truthy(markdown:find(
            "Read-only. Reports the number of windows awaiting an event.",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "| [`pending`](/modules/api/#api.pending) | " ..
                '<span class="tealdoc-kind-badge tealdoc-kind-variable">' ..
                "variable</span> | `<const>`",
            1,
            true
        ))
        local introduction_at = assert(markdown:find(
            "opens windows and reports display changes through",
            1,
            true
        ))
        local type_summary_at = assert(markdown:find("**Types**", 1, true))
        local constructor_summary_at = assert(markdown:find(
            "**Constructors**",
            1,
            true
        ))
        local function_summary_at = assert(markdown:find(
            "**Functions**",
            1,
            true
        ))
        local constructors_at = assert(markdown:find(
            "## Constructors",
            constructor_summary_at,
            true
        ))
        local types_at = assert(markdown:find("## Types", type_summary_at, true))
        local functions_at = assert(markdown:find(
            "## Functions",
            function_summary_at,
            true
        ))
        assert.is_true(introduction_at < types_at)
        assert.is_true(introduction_at < functions_at)
        assert.is_true(constructor_summary_at < type_summary_at, markdown)
        assert.is_true(type_summary_at < function_summary_at, markdown)
        assert.is_true(function_summary_at < constructors_at)
        assert.is_true(constructors_at < types_at)
        assert.is_true(type_summary_at < types_at)
        assert.is_true(function_summary_at < functions_at)
        assert.is_true(types_at < functions_at)
        assert.is_truthy(markdown:find("\n## Display changes\n", 1, true))
        assert.is_truthy(
            markdown:find("\n#### Window lifetime\n", 1, true),
            markdown
        )
        assert.is_truthy(markdown:find(
            "\n### api.Options ",
            types_at,
            true
        ))
        assert.is_truthy(markdown:find(
            "\n### api.open ",
            functions_at,
            true
        ))
        assert.is_truthy(markdown:find(
            "\n### api.newWindow ",
            constructors_at,
            true
        ))
        assert.is_falsy(markdown:find(
            "\n### api.newWindow ",
            functions_at,
            true
        ))
        assert.is_truthy(markdown:find(
            "\n## Values\n",
            functions_at,
            true
        ))
        assert.is_truthy(markdown:find(
            "\n### api.pending ",
            functions_at,
            true
        ))
        assert.is_falsy(markdown:find("\n### Types\n", 1, true))
        assert.is_falsy(markdown:find("\n### Functions\n", 1, true))
        assert.is_truthy(markdown:find(
            "It keeps wrapped prose\non adjacent source lines.",
            introduction_at,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "reports display changes through\n" ..
                "[`Window`](/modules/window/).",
            introduction_at,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "`API` opens windows and reports display changes through",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "[`API`](/modules/api/)",
            1,
            true
        ), markdown)
        local options_at = assert(markdown:find(
            "\n### api.Options ",
            1,
            true
        ))
        assert.is_truthy(markdown:find(
            "Configures `Options`.",
            options_at,
            true
        ), markdown)
        local options_end = assert(markdown:find(
            "\n## Functions",
            options_at,
            true
        ))
        assert.is_falsy(markdown:sub(options_at, options_end - 1):find(
            "[`Options`](/modules/api/#api.Options)",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "```teal\n# This remains example code.\n" ..
                "local options = {}\nlocal window = api.open(options)\n```",
            introduction_at,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "```teal\n# This remains example code.\n```",
            functions_at,
            true
        ), markdown)
        -- The functions table carries no kind column, so a row goes straight
        -- from the name to the description.
        assert.is_truthy(markdown:find(
            "| [`reset`](/modules/api/#api.reset) | ",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "| [`reset`](/modules/api/#api.reset) | <span",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "retained handle so a... |",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "Shows a [`Window`](/modules/window/).",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find("tealdoc:", 1, true), markdown)
        assert.is_truthy(api:find(
            'class="tealdoc-kind-badge tealdoc-kind-record">record</span>',
            1,
            true
        ), api)
        assert.is_truthy(api:find(
            'class="tealdoc-kind-badge tealdoc-kind-field">field</span>',
            1,
            true
        ), api)
        assert.is_truthy(api:find(
            'class="tealdoc-kind-badge tealdoc-kind-function">function</span>',
            1,
            true
        ), api)
        assert.is_truthy(api:find(
            'class="tealdoc-kind-badge tealdoc-kind-method">method</span>',
            1,
            true
        ), api)
        assert.is_falsy(markdown:find(
            "function api.reset(self: api)",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "function api.reset(self)",
            1,
            true
        ), markdown)
        assert.is_truthy(api:find(
            'class="tealdoc-breadcrumbs"',
            1,
            true
        ))
        assert.is_falsy(api:find("api Reference", 1, true))
        assert.are.equal(1, select(2, api:gsub("<h1[%s>]", "")))
        assert.is_truthy(api:find("Open a checked value", 1, true), api)
        assert.is_truthy(api:find(
            'tealdoc-token-string">&quot;checked&quot;</span>',
            1,
            true
        ), api)
        assert.is_falsy(api:find("#region", 1, true), api)
        assert.is_falsy(api:find("Public APIs in", 1, true))
        assert.is_falsy(window_html:find("window Reference", 1, true))
        assert.is_falsy(window_markdown:find("## Module contents", 1, true))
        assert.is_truthy(window_html:find(
            '<h1 id="window"',
            1,
            true
        ), window_html)
        assert.are.equal(1, select(2, window_html:gsub("<h1[%s>]", "")))
        assert.is_truthy(window_markdown:match("^# window\n"))
        assert.is_truthy(api:find(
            '<a class="tealdoc-footer-llms" href="/modules/api/llms.txt">llms.txt</a>',
            1,
            true
        ))
        assert.is_truthy(api:find(
            '<meta property="og:image" content="https://docs.example.test/api-social.png">',
            1,
            true
        ))
        assert.is_truthy(window_html:find(
            '<meta name="robots" content="noindex, nofollow">',
            1,
            true
        ))
        assert.is_falsy(api:find(
            'aria-label="Page navigation"><ul><li><a href="/">Home</a></li>',
            1,
            true
        ))
        assert.is_truthy(api:find("<span>Modules</span>", 1, true))
        assert.is_truthy(api:find('class="tealdoc-header-anchor"', 1, true))
        assert.is_truthy(api:find(
            'class="token keyword keyword-record tealdoc-token-keyword">record</span>',
            1,
            true
        ), api)
        assert.is_truthy(api:find(
            '<td><a href="/modules/window/"><code>Window</code></a></td>',
            1,
            true
        ), api)
        -- Every entry under a reference section drops the namespace its
        -- siblings share, the one that opens the section included.
        assert.is_truthy(api:find(">Options</a>", 1, true), api)
        assert.is_truthy(api:find(">messageBox</a>", 1, true), api)
        assert.is_falsy(api:find("↳", 1, true))
        assert.is_truthy(api:find(
            '<a class="tealdoc-code-link" href="/modules/window/"><span class="token class-name tealdoc-token-type">Window</span></a>',
            1,
            true
        ), api)
        assert.is_truthy(api:find(
            '<a class="tealdoc-code-link tealdoc-code-link-variable" ' ..
                'href="/modules/api/#api.Options.window">' ..
                '<span class="token variable tealdoc-token-variable">' ..
                "window</span></a>" ..
                '<span class="token punctuation ' ..
                'tealdoc-token-punctuation">:</span> ' ..
                '<a class="tealdoc-code-link" href="/modules/window/">' ..
                '<span class="token class-name tealdoc-token-type">' ..
                "Window</span></a>",
            1,
            true
        ), api)
        assert.is_falsy(api:find(
            'href="/modules/api/#api.Options"><span class="token class-name tealdoc-token-type">Options</span></a></code>',
            1,
            true
        ), api)
        assert.is_truthy(css:find("@media (max-width: 760px)", 1, true))
        assert.is_truthy(css:find("--vp-c-brand-1", 1, true))
        assert.is_truthy(css:find(
            "--tealdoc-dark-accent-contrast: #102f33",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "color: var(--tealdoc-accent-contrast)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "background: var(--tealdoc-button-alt-hover-background)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "max-width: var(--tealdoc-layout-max-width)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-content-gutter: 5rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-layout-max-width: var(--vp-layout-max-width, 1480px)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-content-width: var(--vp-content-width, 688px)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-search-button {\n" ..
                "    display: inline-flex;\n" ..
                "    width: min(190px, 18vw);\n" ..
                "    min-width: 0;\n" ..
                "    min-height: 30px;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-nav {\n" ..
                "    display: flex;\n" ..
                "    width: 100%;\n" ..
                "    max-width: none;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-top-nav {\n" ..
                "    display: flex;\n" ..
                "    flex: 1;\n" ..
                "    justify-content: flex-start;\n" ..
                "    gap: 0.25rem;\n" ..
                "    margin-left: 0.2rem;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-top-nav a {\n" ..
                "    position: relative;\n" ..
                "    padding: 0.45rem 0.65rem;\n" ..
                "    color: var(--tealdoc-header-muted-color);\n" ..
                "    border-radius: 7px;\n" ..
                "    font-size: 0.68rem;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-content {\n" ..
                "    width: min(\n" ..
                "        100% - calc(2 * var(--tealdoc-content-gutter)),\n" ..
                "        var(--tealdoc-content-width)\n" ..
                "    );",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "    .tealdoc-content {\n" ..
                "        width: min(100% - 2rem, var(--tealdoc-content-width));",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-heading-2-spacing: 2.5rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-home-width: 1152px",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-home-gutter: 2rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "var(--tealdoc-home-width)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "max-width: var(--tealdoc-home-width)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar > ul > li.tealdoc-sidebar-section",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-hero-image {\n" ..
                "    position: relative;\n" ..
                "    display: grid;\n" ..
                "    align-self: center;\n" ..
                "    place-items: center;",
            1,
            true
        ))
        assert.is_falsy(css:find("repeating-conic-gradient", 1, true))
        assert.is_truthy(css:find(
            ".tealdoc-features {\n    position: relative;\n    z-index: 2;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--pico-background-color: var(--tealdoc-background)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-font-heading: var(--tealdoc-font)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-heading-font-weight: 700",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-content-font-size: 0.8rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-code-block-font-size: 0.72rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-code-lang-top: 2px",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-inline-code-font-size: 0.91em",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "/* A comment, which CSS lets stand before an import. */\n\n" ..
                '@import url("https://example.test/font.css");\n\n:root {',
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".project-rule {\n    color: rebeccapurple;\n}\n",
            1,
            true
        ))
        assert.is_truthy(css:find(
            '"Apple Color Emoji",\n        "Segoe UI Emoji",\n        "Segoe UI Symbol",\n        "Noto Color Emoji"',
            1,
            true
        ))
        assert.is_truthy(css:find(
            '"JetBrains Mono",\n' ..
                "        ui-monospace,\n" ..
                "        SFMono-Regular,\n" ..
                '        "Cascadia Code",\n' ..
                '        "Roboto Mono",\n' ..
                "        Menlo,\n" ..
                "        Monaco,\n" ..
                "        Consolas,\n" ..
                '        "Liberation Mono",\n' ..
                '        "Courier New",\n' ..
                "        monospace",
            1,
            true
        ))
        assert.is_truthy(css:find("font-optical-sizing: auto", 1, true))
        assert.is_truthy(css:find(
            "font-family: var(--tealdoc-font-heading)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "font-weight: var(--tealdoc-heading-font-weight)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-heading-1-size: 1.8rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-content :not(pre) > code {\n" ..
                "    padding: var(--tealdoc-inline-code-padding);\n" ..
                "    border-radius: var(--tealdoc-inline-code-radius);\n" ..
                "    background: var(--tealdoc-inline-code-background);\n" ..
                "    font-size: var(--tealdoc-inline-code-font-size);\n" ..
                "    font-weight: 550;",
            1,
            true
        ))
        assert.is_falsy(css:find("tealdoc-inline-code-before", 1, true))
        assert.is_falsy(css:find("tealdoc-inline-code-after", 1, true))
        assert.is_truthy(css:find(
            '.tealdoc-content code[class*="language-"] {\n' ..
                "    color: var(--tealdoc-syntax-foreground);\n" ..
                "    background: transparent;\n" ..
                "    font-family: var(--tealdoc-font-mono);\n" ..
                "    font-size: var(--tealdoc-code-block-font-size);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-content pre {\n" ..
                "    overflow: auto;\n" ..
                "    padding: var(--tealdoc-code-block-padding);\n" ..
                "    border: 1px solid var(--tealdoc-border);\n" ..
                "    border-radius: var(--tealdoc-code-block-radius);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-features {\n" ..
                "    position: relative;\n" ..
                "    z-index: 2;\n" ..
                "    display: grid;\n" ..
                "    margin-top: var(--tealdoc-hero-features-gap);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-content a > code {\n    color: var(--tealdoc-link);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-light-link: var(--tealdoc-light-accent);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-dark-link: var(--tealdoc-dark-accent);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-site a {\n    text-decoration-color: currentColor;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-code-link,\n" ..
                ".tealdoc-code-link:visited,\n" ..
                ".tealdoc-code-link:hover {\n" ..
                "    color: var(--tealdoc-syntax-type);\n" ..
                "    border-bottom: 1px dotted " ..
                "currentColor;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-code-link.tealdoc-code-link-variable,\n" ..
                ".tealdoc-code-link.tealdoc-code-link-variable:visited,\n" ..
                ".tealdoc-code-link.tealdoc-code-link-variable:hover {\n" ..
                "    color: var(--tealdoc-syntax-variable);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-code-link.tealdoc-code-link-property,\n" ..
                ".tealdoc-code-link.tealdoc-code-link-property:visited,\n" ..
                ".tealdoc-code-link.tealdoc-code-link-property:hover {\n" ..
                "    color: var(--tealdoc-syntax-property);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-syntax-function: #2e7de9;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-syntax-function: #7aa2f7;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-token-property {\n    color: var(--tealdoc-syntax-property);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-outline li {\n    margin: 0;\n    padding: 0;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-outline-section details[open] > summary {\n" ..
                "    margin-bottom: 0;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-outline-title {\n    margin: 0 0 0.75rem;\n    color: var(--tealdoc-text-muted);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar a {\n    display: block;\n" ..
                "    padding: var(--tealdoc-sidebar-item-padding);\n" ..
                "    color: var(--tealdoc-sidebar-item-color);\n" ..
                "    border-radius: 6px;\n" ..
                "    font-family: var(--tealdoc-sidebar-font-family);\n" ..
                "    font-size: var(--tealdoc-sidebar-font-size);\n" ..
                "    font-weight: var(--tealdoc-sidebar-font-weight);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            '.tealdoc-sidebar a[aria-current="page"] {\n    color: var(--tealdoc-accent);\n    background: transparent;',
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section {\n" ..
                "    margin-top: var(--tealdoc-sidebar-section-gap) !important;\n" ..
                "    padding-top: var(--tealdoc-sidebar-section-padding);\n" ..
                "    border-top: 1px solid var(--tealdoc-sidebar-section-border);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section summary {\n" ..
                "    position: relative;\n" ..
                "    margin: 0;\n" ..
                "    padding: var(--tealdoc-sidebar-item-padding);\n" ..
                "    padding-right: 1.2rem;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section details[open] > summary {\n    margin-bottom: 0;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section .tealdoc-sidebar-section > " ..
                "details > summary {\n" ..
                "    margin-left: calc(-1 * " ..
                "var(--tealdoc-sidebar-nested-indent));",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-sidebar-item-color: var(--tealdoc-text-muted);\n" ..
                "    --tealdoc-sidebar-heading-color: var(--tealdoc-text);\n" ..
                "    --tealdoc-sidebar-heading-font-size: 0.7rem;\n" ..
                "    --tealdoc-sidebar-heading-font-weight: 700;\n" ..
                "    --tealdoc-sidebar-section-border: var(--tealdoc-border);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section ul {\n" ..
                "    margin: 0;\n" ..
                "    padding: var(--tealdoc-sidebar-nested-top-padding) 0 0\n" ..
                "        var(--tealdoc-sidebar-nested-indent);\n" ..
                "    border-left: 0;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section li a {\n" ..
                "    padding: var(--tealdoc-sidebar-item-padding);",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-outline-font-size: 0.66rem",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-outline {\n    padding: 1.25rem 1.35rem 2rem 1.25rem;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-outline > ol {\n    position: relative;\n    padding-left: 1.55rem;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-outline .level-3 a {\n    padding-left: 0.75rem;\n" ..
                "    color: var(--tealdoc-text-faint);\n" ..
                "    font-size: var(--tealdoc-outline-nested-font-size);",
            1,
            true
        ))
        assert.is_truthy(css:find("text-overflow: ellipsis", 1, true))
        assert.is_truthy(css:find("white-space: nowrap", 1, true))
        assert.is_falsy(css:find("-webkit-line-clamp: 2", 1, true))
        assert.is_truthy(css:find(
            ".tealdoc-outline-section details:not([open]) > " ..
                "summary::after",
            1,
            true
        ))
        assert.is_falsy(api:find('title="api Reference"', 1, true), api)
        assert.is_truthy(css:find(
            "box-shadow: -100vw 0 0 100vw var(--tealdoc-sidebar-background)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-home-footer .tealdoc-footer-inner::before {\n" ..
                "    content: none;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--tealdoc-outline-item-padding: 0.16rem 0",
            1,
            true
        ))
        assert.is_truthy(css:find(
            '.tealdoc-outline .level-3 a[aria-current="location"] {\n    color: var(--tealdoc-accent);',
            1,
            true
        ))
        assert.is_truthy(css:find(
            "--pico-h1-color: var(--tealdoc-text)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            "left: var(--tealdoc-sidebar-width)",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-breadcrumbs a {\n    color: var(--tealdoc-text-faint);\n" ..
                "    text-decoration-color: currentColor;\n" ..
                "    text-decoration-line: underline !important;\n" ..
                "    text-decoration-thickness: 1px;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-breadcrumbs a:hover {\n" ..
                "    color: var(--tealdoc-accent-hover);\n" ..
                "    text-decoration-line: underline !important;",
            1,
            true
        ))
        assert.is_truthy(home:find(
            'class="language-lua"><span class="token keyword keyword-local',
            1,
            true
        ), home)
        assert.is_truthy(js:find("scoreEntry", 1, true))
        assert.is_truthy(js:find(
            'document.createElement("script")',
            1,
            true
        ))
        assert.is_truthy(js:find("const maxSearchResults = 50", 1, true))
        assert.is_truthy(js:find(
            ".slice(0, maxSearchResults)",
            1,
            true
        ))
        assert.is_truthy(js:find("updateOutline", 1, true))
        assert.is_truthy(js:find(
            'link.setAttribute("aria-current", "location")',
            1,
            true
        ))
        assert.is_truthy(js:find(
            'window.localStorage.getItem(themeStorageKey)',
            1,
            true
        ))
        assert.is_truthy(js:find(
            'window.localStorage.setItem(themeStorageKey, storedTheme)',
            1,
            true
        ))
        assert.is_truthy(search:find("API › api.open", 1, true))
        assert.is_truthy(search:find("Hello", 1, true), search)
        assert.is_truthy(search:find("Static documentation.", 1, true), search)
        assert.is_truthy(search:find("Get started", 1, true), search)
        assert.is_truthy(search:find("Checked", 1, true), search)
        assert.is_truthy(search:find("Generated from source.", 1, true), search)
        assert.is_truthy(markdown:find("```teal", 1, true))
        assert.are.equal(markdown, llms)
        assert.is_truthy(llms_index:find(
            "- [Home](/index.md): Home page",
            1,
            true
        ), llms_index)
        assert.is_truthy(llms_index:find(
            "- [API](/modules/api/llms.txt): API page",
            1,
            true
        ), llms_index)
        assert.is_truthy(llms_index:find(
            "- [Complete documentation](/llms-full.txt)",
            1,
            true
        ), llms_index)
        assert.is_falsy(llms_index:find("One thread", 1, true))
        assert.is_truthy(llms_full:find("## Home", 1, true), llms_full)
        assert.is_truthy(llms_full:find("One thread", 1, true), llms_full)
        assert.is_truthy(llms_full:find("## API", 1, true), llms_full)
        assert.is_falsy(llms_full:find("api Reference", 1, true), llms_full)
        assert.is_truthy(manifest:find(
            "tealdoc-manifest-v1\n",
            1,
            true
        ))
        assert.is_truthy(manifest:find(
            "\nassets/search-index.js\n",
            1,
            true
        ))
        assert.is_truthy(manifest:find("\nllms-full.txt\n", 1, true))
        assert.is_truthy(manifest:find(
            "\nmodules/api/llms.txt\n",
            1,
            true
        ))
        assert.is_falsy(manifest:find(output, 1, true))
        assert.is_truthy(redirect:find(
            '<meta http-equiv="refresh" content="0; url=/modules/api/">',
            1,
            true
        ))
        assert.is_falsy(redirect:find("<script", 1, true))
        assert.is_truthy(example_html:find(
            'keyword-local tealdoc-token-keyword">local</span>',
            1,
            true
        ), example_html)
        -- Every block is wrapped, and the wrapper carries the language on its
        -- own so the corner label has something to draw and does not sit on
        -- the element that scrolls.
        assert.is_truthy(example_html:find(
            '<div class="tealdoc-code-block" data-lang="teal"><pre',
            1,
            true
        ), example_html)
        assert.is_truthy(example_html:find(
            "A compiler-checked Teal example.",
            1,
            true
        ))
        assert.is_truthy(not_found:find("<title>Missing | Test</title>", 1, true))
        assert.is_truthy(not_found:find(
            '<meta name="robots" content="noindex, nofollow">',
            1,
            true
        ))
        assert.is_truthy(sitemap:find(
            "<loc>https://docs.example.test/modules/api/</loc>",
            1,
            true
        ))
        assert.is_falsy(sitemap:find("/modules/window/", 1, true))
        assert.is_falsy(sitemap:find("/404", 1, true))
        assert.is_truthy(robots:find(
            "Sitemap: https://docs.example.test/sitemap.xml",
            1,
            true
        ))
        assert.are.equal("docs.example.test\n", read_file(output .. "/CNAME"))
        assert.are.equal(
            "<svg><!-- test --></svg>\n",
            read_file(output .. "/favicon.svg")
        )
        assert.are.equal(
            "Public notice\n",
            read_file(output .. "/downloads/notice.txt")
        )

        remove_tree(output)
        remove_tree(public)
        os.remove(source)
        os.remove(example)
        os.remove(attached_example)
        os.remove(custom_css)
    end)

    it("rejects invalid checked Teal examples before writing output", function()
        local env = DefaultEnv.init()
        local example = os.tmpname()
        local file = assert(io.open(example, "w"))
        file:write('local answer: integer = "wrong"\n')
        file:close()
        local output = os.tmpname()
        os.remove(output)

        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Test",
                description = "Test documentation",
                base = "/",
                pages = {},
                examples = {
                    {
                        path = "examples/invalid",
                        title = "Invalid",
                        source = example,
                        language = "teal",
                    },
                },
            })
        end)
        assert.is_nil(lfs.attributes(output))
        os.remove(example)
    end)
    it("resolves project files and discovers Teal sources from the config", function()
        local root = os.tmpname()
        os.remove(root)
        assert(lfs.mkdir(root))
        assert(lfs.mkdir(root .. "/docs"))
        assert(lfs.mkdir(root .. "/src"))
        assert(lfs.mkdir(root .. "/src/nested"))
        write_file(root .. "/docs/index.md", "# Project\n\nConfig relative.\n")
        write_file(root .. "/docs/site.css", ".project { color: teal; }\n")
        write_file(root .. "/src/api.tl", "local record api\nend\nreturn api\n")
        write_file(
            root .. "/src/nested/helper.tl",
            "local record helper\nend\nreturn helper\n"
        )
        write_file(root .. "/src/ignored.lua", "return {}\n")

        local settings = {
            title = "Project",
            base = "/reference",
            custom_css = "docs/site.css",
            sources = {"src"},
            pages = {
                {
                    path = "",
                    title = "Home",
                    source = "docs/index.md",
                },
            },
        }
        local sources = SiteGenerator.source_files(settings, root)
        assert.are.same({
            root .. "/src/api.tl",
            root .. "/src/nested/helper.tl",
        }, sources)

        local output = root .. "/site"
        SiteGenerator.build(output, DefaultEnv.init(), settings, root)
        local html = read_file(output .. "/index.html")
        local css = read_file(output .. "/assets/tealdoc.css")
        assert.is_truthy(html:find("Config relative.", 1, true))
        assert.is_truthy(html:find(
            'href="/reference/index.md"',
            1,
            true
        ))
        assert.is_truthy(html:find(
            'href="/reference/assets/tealdoc.css"',
            1,
            true
        ))
        assert.is_truthy(css:find(".project { color: teal; }", 1, true))
        remove_tree(root)
    end)

    it("discovers hidden Teal modules from the project source directory", function()
        local root = os.tmpname()
        os.remove(root)
        assert(lfs.mkdir(root))
        assert(lfs.mkdir(root .. "/src"))
        assert(lfs.mkdir(root .. "/src/public"))
        assert(lfs.mkdir(root .. "/src/public/internal"))
        assert(lfs.mkdir(root .. "/src/public/internal/nested"))
        assert(lfs.mkdir(root .. "/src/public/_private"))
        assert(lfs.mkdir(root .. "/src/ordinary"))
        write_file(root .. "/src/public/api.tl", "return {}\n")
        write_file(
            root .. "/src/public/internal/types.tl",
            "return {}\n"
        )
        write_file(
            root .. "/src/public/internal/nested/helpers.tl",
            "return {}\n"
        )
        write_file(
            root .. "/src/public/_private/helpers.tl",
            "return {}\n"
        )
        write_file(root .. "/src/public/_types.tl", "return {}\n")
        write_file(root .. "/src/ordinary/types.tl", "return {}\n")

        assert.are.same({
            root .. "/src/public/_private/helpers.tl",
            root .. "/src/public/_types.tl",
            root .. "/src/public/internal/nested/helpers.tl",
            root .. "/src/public/internal/types.tl",
        }, SiteGenerator.hidden_source_files({
            source_dir = "src",
        }, root))
        remove_tree(root)
    end)

    it("rejects unsafe and duplicate normalized routes before output", function()
        local output = os.tmpname()
        os.remove(output)
        local env = DefaultEnv.init()

        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Unsafe",
                pages = {
                    {path = "../outside", title = "Outside"},
                },
            })
        end, "tealdoc.site.pages[1].path contains an unsafe path segment: ../outside")
        assert.is_nil(lfs.attributes(output))

        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Duplicate",
                pages = {
                    {path = "guide", title = "Guide"},
                    {path = "/guide/", title = "Duplicate guide"},
                },
            })
        end, "duplicate normalized page or example route: guide")
        assert.is_nil(lfs.attributes(output))

        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Redirects",
                pages = {
                    {path = "", title = "Home"},
                },
                redirects = {
                    ["old"] = "new",
                    ["/old/"] = "new",
                },
            })
        end)
        assert.is_nil(lfs.attributes(output))

        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Output collision",
                pages = {
                    {path = "", title = "Home"},
                },
                redirects = {
                    ["index.html"] = "guide",
                },
            })
        end, "redirect index.html conflicts with home page at output path index.html")
        assert.is_nil(lfs.attributes(output))

        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "404 collision",
                pages = {
                    {path = "404", title = "Ordinary page"},
                },
                not_found = {},
            })
        end, "custom 404 page conflicts with page 404 at output path 404.md")
        assert.is_nil(lfs.attributes(output))
    end)

    it("claims every generated and public output before writing", function()
        local reserved = {
            ".tealdoc-manifest",
            "assets/tealdoc.css",
            "assets/pico.classless.min.css",
            "assets/tealdoc.js",
            "assets/search-index.js",
            "robots.txt",
            "sitemap.xml",
            "CNAME",
            "index.html",
            "index.md",
            "llms.txt",
            "llms-full.txt",
            "guide",
            "guide/index.html",
            "guide.md",
            "guide/llms.txt",
            "old/index.html",
            "404.html",
            "404.md",
            "404/llms.txt",
        }
        for _, path in ipairs(reserved) do
            local public = os.tmpname()
            os.remove(public)
            assert(lfs.mkdir(public))
            write_nested_file(public, path, "public\n")
            local output = os.tmpname()
            os.remove(output)
            assert.has_error(function()
                SiteGenerator.build(output, DefaultEnv.init(), {
                    title = "Reserved outputs",
                    site_url = "https://example.test",
                    cname = "docs.example.test",
                    public = public,
                    not_found = {},
                    redirects = {old = "guide"},
                    pages = {
                        {path = "", title = "Home"},
                        {path = "guide", title = "Guide"},
                    },
                })
            end)
            assert.is_nil(
                lfs.attributes(output),
                "created output before rejecting " .. path
            )
            remove_tree(public)
        end

        local output = os.tmpname()
        os.remove(output)
        assert(lfs.mkdir(output))
        write_file(output .. "/robots.txt", "keep me\n")
        assert.has_error(function()
            SiteGenerator.build(output, DefaultEnv.init(), {
                title = "Unowned output",
                pages = {{path = "", title = "Home"}},
            })
        end, "robots file would overwrite an unowned output path: robots.txt")
        assert.are.equal("keep me\n", read_file(output .. "/robots.txt"))
        assert.is_nil(lfs.attributes(output .. "/index.html"))
        remove_tree(output)
    end)

    it("prunes only stale manifested files and records hook output", function()
        local output = os.tmpname()
        os.remove(output)
        local first_public = os.tmpname()
        os.remove(first_public)
        assert(lfs.mkdir(first_public))
        write_file(first_public .. "/retired.txt", "retired\n")

        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "First site",
            site_url = "https://example.test",
            cname = "docs.example.test",
            public = first_public,
            pages = {
                {path = "", title = "Home"},
                {path = "old", title = "Old"},
                {path = "empty", title = "Empty"},
                {path = "gone", title = "Gone"},
            },
            after_build = function(context)
                assert(lfs.mkdir(context.output .. "/hook"))
                local path = context.output .. "/hook/first.txt"
                write_file(path, "first hook\n")
                table.insert(context.files, path)
            end,
        })
        local first_manifest = read_file(output .. "/.tealdoc-manifest")
        assert.is_truthy(first_manifest:find(
            "\nhook/first.txt\n",
            1,
            true
        ))
        write_file(output .. "/keep.txt", "untracked root\n")
        write_file(output .. "/old/keep.txt", "untracked nested\n")

        local second_public = os.tmpname()
        os.remove(second_public)
        assert(lfs.mkdir(second_public))
        write_file(second_public .. "/current.txt", "current\n")
        write_file(second_public .. "/empty", "replaced directory\n")
        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Second site",
            public = second_public,
            robots = false,
            pages = {
                {path = "", title = "Home"},
                {path = "new", title = "New"},
            },
            after_build = function(context)
                assert(lfs.mkdir(context.output .. "/hook"))
                local path = context.output .. "/hook/second.txt"
                write_file(path, "second hook\n")
                table.insert(context.files, path)
            end,
        })

        for _, path in ipairs({
            "CNAME",
            "sitemap.xml",
            "robots.txt",
            "retired.txt",
            "old.md",
            "old/index.html",
            "old/llms.txt",
            "empty.md",
            "empty/index.html",
            "empty/llms.txt",
            "gone.md",
            "gone/index.html",
            "gone/llms.txt",
            "hook/first.txt",
        }) do
            assert.is_nil(
                lfs.symlinkattributes(output .. "/" .. path),
                "did not prune " .. path
            )
        end
        assert.is_nil(lfs.attributes(output .. "/gone"))
        assert.are.equal(
            "replaced directory\n",
            read_file(output .. "/empty")
        )
        assert.are.equal("untracked root\n", read_file(output .. "/keep.txt"))
        assert.are.equal(
            "untracked nested\n",
            read_file(output .. "/old/keep.txt")
        )
        assert.are.equal("current\n", read_file(output .. "/current.txt"))
        assert.are.equal(
            "second hook\n",
            read_file(output .. "/hook/second.txt")
        )
        local manifest = read_file(output .. "/.tealdoc-manifest")
        assert.is_truthy(manifest:find("\ncurrent.txt\n", 1, true))
        assert.is_truthy(manifest:find("\nhook/second.txt\n", 1, true))
        assert.is_truthy(manifest:find("\nnew/llms.txt\n", 1, true))
        assert.is_falsy(manifest:find("keep.txt", 1, true))
        assert.is_falsy(manifest:find("retired.txt", 1, true))
        assert.is_falsy(manifest:find("hook/first.txt", 1, true))

        remove_tree(output)
        remove_tree(first_public)
        remove_tree(second_public)
    end)

    it("publishes a safe manifest only after successful validation", function()
        local output = os.tmpname()
        os.remove(output)
        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Valid site",
            pages = {
                {path = "", title = "Home"},
                {path = "old", title = "Old"},
            },
        })
        local manifest = read_file(output .. "/.tealdoc-manifest")
        local bad_source = os.tmpname()
        write_file(bad_source, "# Home\n\n[Missing](/missing/)\n")
        assert.has_error(function()
            SiteGenerator.build(output, DefaultEnv.init(), {
                title = "Invalid site",
                pages = {
                    {
                        path = "",
                        title = "Home",
                        source = bad_source,
                    },
                },
            })
        end)
        assert.are.equal(
            manifest,
            read_file(output .. "/.tealdoc-manifest")
        )
        assert.is_nil(lfs.attributes(output .. "/old/index.html"))

        remove_tree(output)
        os.remove(bad_source)

        local unsafe = os.tmpname()
        os.remove(unsafe)
        assert(lfs.mkdir(unsafe))
        write_file(
            unsafe .. "/.tealdoc-manifest",
            "tealdoc-manifest-v1\n../outside.txt\n"
        )
        assert.has_error(function()
            SiteGenerator.build(unsafe, DefaultEnv.init(), {
                title = "Unsafe manifest",
                pages = {{path = "", title = "Home"}},
            })
        end, "Tealdoc manifest entry contains an unsafe path segment: ../outside.txt")
        assert.is_nil(lfs.attributes(unsafe .. "/index.html"))
        remove_tree(unsafe)
    end)

    it("rejects invalid top-level site settings", function()
        local output = os.tmpname()
        os.remove(output)
        local env = DefaultEnv.init()
        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Typo",
                pages = {{path = "", title = "Home"}},
                unexpected = true,
            })
        end, "unknown tealdoc.site setting: unexpected")
        assert.has_error(function()
            SiteGenerator.build(output, env, {
                pages = {{path = "", title = "Home"}},
            })
        end, "tealdoc.site.title is required")
        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Formatting",
                format_generated_code = "yes",
                pages = {{path = "", title = "Home"}},
            })
        end, "tealdoc.site.format_generated_code must be a boolean")
        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Constructors",
                constructor_pattern = "[",
                pages = {{path = "", title = "Home"}},
            })
        end, "tealdoc.site.constructor_pattern must be a valid Lua pattern")
        assert.has_error(function()
            SiteGenerator.build(output, env, {
                title = "Navigation",
                sidebar_open = {"Guide", false},
                pages = {{path = "", title = "Home"}},
            })
        end, "tealdoc.site.sidebar_open[2] must be a non-empty string")
        assert.is_nil(lfs.attributes(output))
    end)
    it("validates internal links and anchors under a configured base", function()
        local env = DefaultEnv.init()
        local home_source = os.tmpname()
        local home_file = assert(io.open(home_source, "w"))
        home_file:write([[
# Home

[Guide](/docs/guide/#guide)
[Missing page](/docs/missing/)
[Missing anchor](/docs/guide/#absent)
[External](https://example.test/missing)
]])
        home_file:close()
        local guide_source = os.tmpname()
        local guide_file = assert(io.open(guide_source, "w"))
        guide_file:write("# Guide\n")
        guide_file:close()
        local output = os.tmpname()
        os.remove(output)

        local ok, message = pcall(function()
            SiteGenerator.build(output, env, {
                title = "Test",
                description = "Test documentation",
                base = "/docs/",
                pages = {
                    {
                        path = "",
                        title = "Home",
                        source = home_source,
                    },
                    {
                        path = "guide",
                        title = "Guide",
                        source = guide_source,
                    },
                },
            })
        end)
        assert.is_false(ok)
        assert.is_truthy(tostring(message):find(
            "site link validation failed:",
            1,
            true
        ), tostring(message))
        assert.is_truthy(tostring(message):find(
            "index.html: missing link target /docs/missing/",
            1,
            true
        ), tostring(message))
        assert.is_truthy(tostring(message):find(
            "index.html: missing anchor /docs/guide/#absent",
            1,
            true
        ), tostring(message))
        assert.is_falsy(tostring(message):find(
            "example.test",
            1,
            true
        ), tostring(message))

        os.remove(output .. "/assets/tealdoc.css")
        os.remove(output .. "/assets/tealdoc.js")
        os.remove(output .. "/assets/search-index.js")
        os.remove(output .. "/index.html")
        os.remove(output .. "/index.md")
        os.remove(output .. "/llms.txt")
        os.remove(output .. "/llms-full.txt")
        os.remove(output .. "/guide/index.html")
        os.remove(output .. "/guide.md")
        os.remove(output .. "/guide/llms.txt")
        lfs.rmdir(output .. "/assets")
        lfs.rmdir(output .. "/guide")
        lfs.rmdir(output)
        os.remove(home_source)
        os.remove(guide_source)
    end)

    it("combines a non-root base with canonical site output", function()
        local output = os.tmpname()
        os.remove(output)
        local public = os.tmpname()
        os.remove(public)
        assert(lfs.mkdir(public))
        write_file(public .. "/favicon.svg", "<svg></svg>\n")
        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Reference",
            description = "Reference documentation",
            base = "/reference/",
            site_url = "https://example.test",
            favicon = "favicon.svg",
            public = public,
            pages = {
                {
                    path = "",
                    title = "Home",
                    description = "Home",
                },
                {
                    path = "guide",
                    title = "Guide",
                    description = "Guide",
                    canonical = "/canonical-guide/",
                },
            },
        })

        local home = read_file(output .. "/index.html")
        local guide = read_file(output .. "/guide/index.html")
        local sitemap = read_file(output .. "/sitemap.xml")
        local robots = read_file(output .. "/robots.txt")
        assert.is_truthy(home:find(
            '<link rel="icon" href="/reference/favicon.svg">',
            1,
            true
        ))
        assert.is_truthy(home:find(
            'href="https://example.test/reference/index.md"',
            1,
            true
        ))
        assert.is_truthy(guide:find(
            '<link rel="canonical" href="https://example.test/canonical-guide/">',
            1,
            true
        ))
        assert.is_truthy(sitemap:find(
            "<loc>https://example.test/reference/</loc>",
            1,
            true
        ))
        assert.is_truthy(sitemap:find(
            "<loc>https://example.test/canonical-guide/</loc>",
            1,
            true
        ))
        assert.is_truthy(robots:find("Allow: /reference/", 1, true))
        assert.is_truthy(robots:find(
            "Sitemap: https://example.test/reference/sitemap.xml",
            1,
            true
        ))
        remove_tree(output)
        remove_tree(public)
    end)

    it("extracts nested example regions with CRLF and trailing spaces", function()
        local source = os.tmpname()
        write_file(
            source,
            "-- #region selected   \r\n" ..
                "local keep1 = 1\r\n" ..
                "-- #region nested\r\n" ..
                "local nested = 2\r\n" ..
                "-- #endregion   \r\n" ..
                "local keep2 = 3\r\n" ..
                "-- #endregion selected   \r\n"
        )
        local output = os.tmpname()
        os.remove(output)

        SiteGenerator.build(output, DefaultEnv.init(), {
            title = "Examples",
            validate_links = false,
            examples = {
                {
                    path = "nested",
                    title = "Nested regions",
                    source = source,
                    region = "selected",
                    language = "lua",
                },
            },
        })

        local markdown = read_file(output .. "/nested.md")
        assert.is_truthy(markdown:find("local keep1 = 1", 1, true), markdown)
        assert.is_truthy(markdown:find("local nested = 2", 1, true), markdown)
        assert.is_truthy(markdown:find("local keep2 = 3", 1, true), markdown)
        assert.is_falsy(markdown:find("#region", 1, true), markdown)
        remove_tree(output)
        os.remove(source)
    end)

    it("caps demoted API headings at level six", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                record Outer
                    record Middle
                        record Inner
                            --- Runs deeply nested work.
                            run: function()
                        end
                    end
                end
            end

            return api
        ]], "deep.tl", env)
        local output = os.tmpname()
        os.remove(output)

        SiteGenerator.build(output, env, {
            title = "Deep API",
            validate_links = false,
            pages = {
                {
                    path = "deep",
                    title = "Deep",
                    api = "deep",
                },
            },
        })

        local markdown = read_file(output .. "/deep.md")
        assert.is_falsy(markdown:find("\n####### ", 1, true), markdown)
        assert.is_truthy(markdown:find("\n###### Arguments", 1, true), markdown)
        remove_tree(output)
    end)

    it("rejects executable custom head entries", function()
        local output = os.tmpname()
        os.remove(output)
        assert.has_error(function()
            SiteGenerator.build(output, DefaultEnv.init(), {
                title = "Test",
                description = "Test documentation",
                pages = {
                    {path = "", title = "Home"},
                },
                head = {
                    {
                        tag = "script",
                        attributes = {src = "/unsafe.js"},
                    },
                },
            })
        end, "tealdoc.site.head entries must use the link or meta tag")
        remove_tree(output)
    end)
end)
