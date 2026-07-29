local lfs = require("lfs")
local DefaultEnv = require("tealdoc.default_env")
local SiteGenerator = require("tealdoc.generator.site")
local Highlighter = require("tealdoc.generator.site.highlighter")
local PageTemplate = require("tealdoc.generator.site.page_template")
local tealdoc = require("tealdoc")

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local contents = assert(file:read("*a"))
    file:close()
    return contents
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
            local record second
                --- An alias that remains linked after projection.
                type WidgetAlias = first.Widget

                --- The same shared alias re-exported here.
                type Shared = first.Widget

                --- Returns the same widget.
                copy: function(widget: first.Widget): first.Widget

                --- Mentions an internal type which has no public page.
                conceal: function(secret: hidden.Secret)
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
                    api = {"first", "second", "Camera"},
                    public = "public.api",
                },
            },
        })

        local html = read_file(output .. "/api/index.html")
        assert.is_truthy(html:find('id="public.api.Widget"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.WidgetAlias"', 1, true), html)
        assert.equals(
            1,
            select(2, html:gsub('id="public.api.Shared"', ""))
        )
        assert.is_truthy(html:find('id="public.api.copy"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.Camera"', 1, true), html)
        assert.is_truthy(html:find('id="public.api.Camera.x"', 1, true), html)
        assert.is_falsy(html:find('id="public.api.x"', 1, true))
        assert.is_truthy(html:find('href="/api/#public.api.Widget"', 1, true), html)
        assert.is_falsy(html:find("#public.api.Secret", 1, true))
        assert.is_falsy(html:find("#hidden.Secret", 1, true))

        remove_tree(output)
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
            "<td><code>string | nil</code></td>",
            1,
            true
        ), html)

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
        assert.is_truthy(html:find(
            'href="/filesystem/watch/#public.filesystem.watch.Options"',
            1,
            true
        ), html)
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
            sidebar = {
                {
                    text = "CLI",
                    path = "docs/cli",
                    collapsed = true,
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

        local html = read_file(output .. "/docs/ecs/components/bundles/index.html")
        assert.is_truthy(html:find("<summary>CLI</summary>", 1, true), html)
        assert.is_truthy(html:find("<summary>tecs.ecs</summary>", 1, true), html)
        assert.is_truthy(html:find("<summary>Components</summary>", 1, true), html)
        assert.is_truthy(html:find(">Overview</a>", 1, true), html)
        assert.is_truthy(html:find(
            'href="/docs/ecs/components/bundles/" aria-current="page">Bundles</a>',
            1,
            true
        ), html)
        assert.is_falsy(html:find("<summary>Docs</summary>", 1, true))

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
        tealdoc.process_text([[
            local type Window = require("window")
            local record api
                record Options
                    window: Window
                end

                --- Opens a window.
                --- @param options Window options.
                open: function(options: Options)

                --- Shows a [`Window`](tealdoc:Window).
                --- @param window Parent window.
                messageBox: function(window: Window)

                --- Resets this API after clearing every cached value, pending
                --- operation, registered listener, and retained handle so a
                --- caller can start again from a completely clean state.
                reset: function(self: api)
            end

            return api
        ]], "api.tl", env)

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
        local js = read_file(output .. "/assets/tealdoc.js")
        local search = read_file(output .. "/assets/search-index.js")
        local markdown = read_file(output .. "/modules/api.md")
        local llms = read_file(output .. "/modules/api/llms.txt")
        local llms_index = read_file(output .. "/llms.txt")
        local llms_full = read_file(output .. "/llms-full.txt")
        local manifest = read_file(output .. "/.tealdoc-manifest")
        local window_html = read_file(output .. "/modules/window/index.html")
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
        assert.is_truthy(home:find(
            '<div class="tealdoc-code-group" role="group">',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            '<figcaption>Components</figcaption>',
            1,
            true
        ), home)
        assert.is_truthy(home:find(
            '<figcaption>Lua</figcaption>',
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
        assert.is_falsy(api:find("Public APIs in", 1, true))
        assert.is_falsy(api:find("Every public item", 1, true))
        assert.is_truthy(api:find("<th>API</th>", 1, true), api)
        assert.is_truthy(markdown:find(
            "| [`reset`](/modules/api/#api.reset) | <span class=\"tealdoc-kind-badge tealdoc-kind-method\">method</span> |",
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
        assert.is_truthy(api:find(
            'class="tealdoc-breadcrumbs"',
            1,
            true
        ))
        assert.is_truthy(api:find("api Reference", 1, true))
        assert.is_truthy(api:find("Open a checked value", 1, true), api)
        assert.is_truthy(api:find(
            'tealdoc-token-string">&quot;checked&quot;</span>',
            1,
            true
        ), api)
        assert.is_falsy(api:find("#region", 1, true), api)
        assert.is_falsy(api:find("Public APIs in", 1, true))
        assert.is_truthy(window_html:find("window Reference", 1, true))
        assert.is_truthy(window_html:find(
            "Public APIs in <code>window</code>.",
            1,
            true
        ))
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
            "--tealdoc-code-block-font-size: 0.8rem",
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
            ".tealdoc-code-link .tealdoc-token-type {\n    color: inherit;",
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
            ".tealdoc-sidebar-section summary {\n    position: relative;\n    margin: 0;\n    padding: 0.22rem 1.2rem 0 0.55rem;",
            1,
            true
        ))
        assert.is_truthy(css:find(
            ".tealdoc-sidebar-section details[open] > summary {\n    margin-bottom: 0;",
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
            ".tealdoc-outline ol {\n    position: relative;\n    padding-left: 1.55rem;",
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
        assert.is_truthy(api:find('title="api Reference"', 1, true), api)
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
        assert.is_falsy(js:find("localStorage", 1, true))
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
        assert.is_truthy(llms_full:find("api Reference", 1, true), llms_full)
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

    it("rejects unknown settings and requires a site title", function()
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
