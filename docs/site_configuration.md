# Static site configuration

Static site settings live under `tealdoc.site` in `tlconfig.lua`. Paths that
name files or directories are resolved relative to that configuration file.
Tealdoc rejects unknown settings.

Each example below shows the value inside the `site` table:

```lua
return {
    tealdoc = {
        site = {
            title = "My project",
            pages = {
                { path = "", title = "Home", source = "docs/index.md" },
            },
        },
    },
}
```

## title

Required string. It names the site in browser titles, metadata, and the default
header wordmark.

```lua
title = "My project"
```

## name

Optional string, defaulting to `title`. It controls the header wordmark. Use an
empty string for a logo-only header.

```lua
name = "Project API"
```

```lua
name = ""
```

## description

Optional string, defaulting to `""`. It supplies the fallback page, Open Graph,
Twitter, and search description when a page has none.

```lua
description = "Typed networking tools for Teal"
```

## language

Optional string, defaulting to `"en"`. It becomes the HTML `lang` value and
Open Graph locale.

```lua
language = "en-GB"
```

## base

Optional absolute URL path, defaulting to `"/"`. Use it when the site is hosted
below an origin rather than at its root. Tealdoc normalizes repeated separators
and adds the trailing slash.

```lua
base = "/reference/"
```

## site_url

Optional HTTP or HTTPS origin without a path. It is combined with `base` for
canonical URLs, social metadata, the sitemap, and robots output.

```lua
site_url = "https://docs.example.com"
```

## logo

Optional image URL for the header brand. Set `name = ""` to show only the logo,
or provide both values to show a logo and wordmark.

```lua
logo = "/images/logo.svg"
```

## github

Optional repository URL. It adds the GitHub icon link to the header.

```lua
github = "https://github.com/example/my-project"
```

## favicon

Optional favicon URL. Relative values are resolved under `base`; absolute paths
and external URLs are used as written.

```lua
favicon = "favicon.svg"
```

## public

Optional config-relative directory copied recursively to the site output root.
Use it for images, fonts, downloadable files, and other static assets.
Symbolic links are rejected. Public files and generated files claim their
output paths before writing, so a reserved-path collision fails without
overwriting either owner.

```lua
public = "docs/public"
```

## cname

Optional bare DNS name. Tealdoc writes it to a root `CNAME` file for hosts such
as GitHub Pages.

```lua
cname = "docs.example.com"
```

## head

Optional array, defaulting to `{}`. Each entry has a `tag` and an `attributes`
table. `tag` may be `"meta"` or `"link"`; Tealdoc escapes and allowlists the
attributes rather than accepting raw HTML.

```lua
head = {
    {
        tag = "meta",
        attributes = {
            name = "theme-color",
            content = "#137a7f",
        },
    },
    {
        tag = "link",
        attributes = {
            rel = "preconnect",
            href = "https://fonts.example.com",
        },
    },
}
```

Meta entries allow `name`, `property`, and `content`. Link entries allow `rel`,
`href`, `type`, `sizes`, `media`, `hreflang`, `title`, `as`, `crossorigin`, and
`referrerpolicy`.

## author

Optional string emitted as author metadata.

```lua
author = "My project contributors"
```

## social_image

Optional default Open Graph and Twitter image URL. A page may override it with
its own `image`.

```lua
social_image = "/images/social-card.png"
```

## twitter_site

Optional Twitter account emitted in Twitter card metadata.

```lua
twitter_site = "@myproject"
```

## sitemap

Optional boolean. It defaults to `true` when `site_url` is configured and
otherwise to `false`. Set it explicitly to suppress or request `sitemap.xml`.
A sitemap requires `site_url`.

```lua
sitemap = true
```

## robots

Optional boolean, defaulting to `true`. It controls `robots.txt`, including the
sitemap URL when a sitemap is generated.

```lua
robots = false
```

## not_found

Optional page table used to generate `404.html`, `404.md`, and
`404/llms.txt`. It accepts `title`, `description`, `source`, and the visual
page fields. The result is always excluded from indexing and the sitemap.

```lua
not_found = {
    title = "Page not found",
    description = "The requested page does not exist.",
    source = "docs/404.md",
    hero_image = "/images/lost.svg",
    hero_image_alt = "A lost robot",
}
```

## custom_css

Optional config-relative stylesheet. Tealdoc appends it after the built-in
styles, so documented `--tealdoc-*` variables and stable `.tealdoc-*`
selectors can customize the theme without replacing templates.

```lua
custom_css = "docs/site.css"
```

## lexers

Optional directory of [Scintillua](https://github.com/orbitalquark/scintillua)
lexers, used to highlight fenced blocks in languages other than Teal.

Teal and Lua are always highlighted through the Teal compiler's own lexer,
which is what turns a type name in a code block into a link to the page that
documents it. Bash, GLSL, JSON, and XML use their matching Scintillua lexers.
A language Tealdoc does not recognize, or whose lexer is absent from the
configured directory, is emitted exactly as it was written.

Tealdoc neither vendors nor depends on Scintillua: it is not published on
LuaRocks, so a site that wants these languages installs it and says where the
lexers landed. Omit this and nothing changes.

```lua
lexers = "vendor/scintillua/lexers"
```

## templates

Optional config-relative directory containing narrow
`lua-resty-template` overrides. Supported files are `layout.html`,
`header.html`, `content.html`, `home.html`, and `footer.html`; each missing
file falls back independently to Tealdoc's built-in template.

```lua
templates = "docs/templates"
```

## copyright

Optional escaped plain text shown in the footer.

```lua
copyright = "Copyright 2026 My project contributors"
```

## license

Optional escaped plain text shown in the footer. Use `footer_links` when the
license needs to be clickable.

```lua
license = "MIT License"
```

## footer_links

Optional ordered array, defaulting to `{}`. Each entry requires `text` and
`path`. Relative routes use `base`; absolute paths, fragments, HTTP(S), and
`mailto:` destinations are preserved.

```lua
footer_links = {
    { text = "MIT License", path = "license" },
    { text = "Security", path = "https://example.com/security" },
}
```

## redirects

Optional map, defaulting to `{}`. Keys are old output routes and values are
new site routes, absolute paths, or external URLs. Routes are normalized and
checked for traversal and collisions.

```lua
redirects = {
    ["old-api.html"] = "reference/api",
    ["v1/guide"] = "https://archive.example.com/v1/guide",
}
```

## sources

Optional ordered array, defaulting to `{}`. Each value is a config-relative
Teal file or directory. Directories are discovered recursively and
deterministically.

```lua
sources = {
    "src/my/api.tl",
    "src/my/modules",
}
```

## pages

Optional ordered array, defaulting to `{}`. Each page requires `title`; `path`
defaults to the home route. `source` adds handwritten Markdown, while `api`
selects one processed Teal module or an ordered list of modules whose generated
reference is appended.

```lua
pages = {
    {
        path = "",
        title = "My project",
        description = "Project documentation",
        source = "docs/index.md",
        layout = "home",
        hero_title = "Build with Teal",
        hero_text = "Typed APIs with generated documentation.",
        hero_image = "/images/project.png",
        hero_image_alt = "My project",
        hero_actions = {
            { text = "Get started", path = "guide", theme = "brand" },
            { text = "API", path = "reference/api", theme = "alt" },
        },
        features = {
            {
                title = "Typed",
                details = "Signatures come directly from Teal source.",
                icon = "T",
            },
        },
    },
    {
        path = "reference/api",
        title = "API",
        description = "Public API reference",
        source = "docs/api.md",
        api = "my.api",
        public = "my.api",
        canonical = "/reference/api",
        image = "/images/api-card.png",
        noindex = false,
    },
    {
        path = "reference/graphics",
        title = "Graphics",
        api = {
            "my.components",
            "my.camera",
            "my.renderer",
            {
                module = "my.types",
                public = "my",
                include = { "World", "Query" },
            },
        },
        public = "my.graphics",
    },
}
```

Page fields are `path`, `title`, `description`, `source`, `api`, `public`,
`layout`, `hero_title`, `hero_text`, `hero_image`, `hero_image_alt`,
`hero_actions`, `features`, `canonical`, `image`, and `noindex`.
`hero_actions` is an array of `{ text, path, theme? }` links. `features` is an
array of `{ title, details?, icon?, image? }` tables.

When `api` is a list, `public` is required. Tealdoc projects every contributing
module's direct public children under that public namespace without changing
the parsed registry. Compatible re-exports coalesce at the same public path;
unrelated collisions fail the build. Type and alias links are emitted only for
exact items rendered by a configured API page.

An API source may be a table with `module`, `public`, and `include` fields.
`public` overrides the page namespace for that source. `include` selects direct
children by name. This lets one page document declarations that live together
in source but occupy different public namespaces.

Lowercase module basenames contribute their public children directly.
Uppercase module basenames, conventionally record or class modules, retain that
basename below `public`. Thus `my.components` contributes `my.graphics.Sprite`
while `my.Camera` contributes `my.graphics.Camera` and its members. A dedicated
page for a nested public namespace owns its links in preference to the parent
page's summary item.

## sidebar

Optional recursively nested array. When omitted, Tealdoc derives its sidebar
from page routes. Each explicit item accepts `text`, `path`, nested `items`,
and `collapsed`. A page item may omit `text`, in which case its configured page
title is used. A group may omit `path`; when it has one, its section label
links directly to that page.

```lua
sidebar = {
    {
        text = "CLI",
        path = "docs/cli",
        collapsed = true,
        items = {
            { path = "docs/cli/configuration" },
        },
    },
    {
        text = "my.ecs",
        path = "docs/ecs",
        items = {
            {
                path = "docs/ecs/components",
                items = {
                    { path = "docs/ecs/components/bundles" },
                },
            },
        },
    },
}
```

Every `path` must name a configured page. The group containing the current
page opens even when `collapsed = true`.

## sidebar_open

Optional array selecting the sidebar sections that start open. Omit it to keep
all sections open by default. Select an explicit group by its `path`, or by its
`text` when it has no path. Route-derived groups accept their first route
segment or displayed title. Sections containing the current page always open,
and an explicit item’s `collapsed` value takes precedence.

```lua
sidebar_open = {
    "Introduction",
    "modules/ecs",
}
```

Each page writes composed Markdown beside its HTML route. Non-home pages also
write a page-local `llms.txt`; the home page uses `index.md`. Root `llms.txt`
indexes those documents, and root `llms-full.txt` aggregates every ordinary
page's composed Markdown.

Tealdoc records generated, public, and registered `after_build` files as safe
relative paths in `.tealdoc-manifest`. A later build removes only old manifest
entries absent from its new output plan and removes directories only when they
become empty. It never prunes untracked files, rejects an unowned file at a
planned path, and replaces the manifest only after link validation succeeds.

## examples

Optional ordered array, defaulting to `{}`. Each entry requires `source` and
exactly one of `path` or `attach_to`. A `path` creates a complete example page;
`attach_to` adds the checked example to a generated API item.

```lua
examples = {
    {
        path = "examples/client",
        title = "HTTP client",
        description = "Make a typed request.",
        source = "examples/client.tl",
        region = "basic-request",
    },
    {
        attach_to = "my.http.Client.get",
        title = "Request a document",
        source = "examples/client.tl",
        region = "get-document",
        language = "teal",
        check = true,
    },
}
```

Example fields are `path`, `attach_to`, `region`, `title`, `description`,
`source`, `language`, and `check`. `language` defaults from `.tl` or `.lua`;
`check` defaults to `true`.

## validate_links

Optional boolean, defaulting to `true`. After the build and `after_build` hook,
Tealdoc checks every generated internal link and heading anchor. Disable it
only when another build step deliberately owns unresolved links.

```lua
validate_links = false
```

## format_generated_code

Optional boolean, defaulting to `false`. When enabled, Tealdoc formats the Teal
declarations it synthesizes for API references with Cerulean before syntax
highlighting them. It also formats handwritten Teal fences and configured Teal
examples. Add `no-format` after a fence's `teal` language when an example's
intentional layout must be preserved; Tealdoc removes the marker from its
output:

````markdown
```teal no-format
operation()
    :map(transform)
    :recover(fallback)
```
````

Cerulean remains an optional runtime dependency. Tealdoc loads it from the
standard Lua `package.path` and `package.cpath`; install it normally with
LuaRocks or set `LUA_PATH` and `LUA_CPATH` when invoking Tealdoc. Enabling this
setting fails the build with a clear error when Cerulean cannot be loaded or
cannot safely format a generated declaration. Cerulean is initialized once per
site build, and identical generated declarations reuse the formatted result.

```lua
format_generated_code = true
```

## nav

Optional ordered array, defaulting to `{}`. Each top-level header link requires
`text` and `path`. Paths may be site routes, absolute paths, or external URLs.

```lua
nav = {
    { text = "Guide", path = "guide" },
    { text = "API", path = "reference/api" },
    { text = "Community", path = "https://example.com/community" },
}
```

## before_build

Optional trusted Lua function. It receives the build context after
configuration, source processing, page assembly, and example attachment, but
before the output directory is created. The context contains `output`, `env`,
`settings`, `pages`, `attached_examples`, and an empty `files` array.

```lua
before_build = function(context)
    table.insert(context.pages, {
        path = "generated",
        title = "Generated page",
        description = "Added by the project build.",
    })
end
```

## after_build

Optional trusted Lua function. It runs after normal artifacts are written and
receives the same context, with `files` populated by every generated path.
Link and anchor validation runs after this hook. Append every file the hook
writes to `context.files`; Tealdoc then validates it and records its safe
relative path in `.tealdoc-manifest` for ownership and stale-file pruning.

```lua
after_build = function(context)
    local path = context.output .. "/build-metadata.txt"
    local file = assert(io.open(path, "w"))
    file:write("generated by the project\n")
    file:close()
    table.insert(context.files, path)
    io.stderr:write(
        string.format("Tealdoc wrote %d files\n", #context.files)
    )
end
```
