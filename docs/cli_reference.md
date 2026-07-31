## CLI Reference

To use the Tealdoc command-line interface:

```
tealdoc <command> [options]
```

You can view all available commands and options with:

```
tealdoc --help
```

### Commands
*   `md`: Generate documentation as a Markdown file.
*   `html`: Generate documentation as an HTML file.
*   `site`: Generate an opt-in static documentation site.
*   `dump`: Print the internal documentation registry to the console for debugging.

### Options
*   `--output <file>`: Specifies the output file for the generated documentation.
*   `--all`: Includes local definitions in the output.
*   `--plugin <plugins>`: Plugins to load; plugin names are resolved the same way as lua requires.
*   `--no-warn-missing`: Suppresses warnings about missing documentation for items.
*   `-V, --version`: Prints the Tealdoc version and exits.

Command and configuration errors are written as concise diagnostics without a
Lua traceback, and the process exits with a nonzero status.

### Project Configuration

Tealdoc reads its project settings from the `tealdoc` table in the nearest
`tlconfig.lua`, using the same current-directory and parent-directory search as
Teal. The namespace lets Tealdoc add settings without colliding with compiler
or other tool settings.

`tealdoc.doc_precedence` controls duplicate function documentation across
ordinary and record functions. It accepts `"declaration"`, `"definition"`, or
`"error"` and defaults to `"declaration"`:

```lua
return {
    tealdoc = {
        doc_precedence = "declaration",
    },
}
```

When both a function declaration and its definition have Tealdoc comments,
`"declaration"` retains the declaration comment and `"definition"` retains the
definition comment. Both modes warn with the canonical item path and the
comment retained. `"error"` stops generation with the item path instead of
choosing one. A declaration remains documented when only its comment exists,
and a definition remains documented when only its comment exists.

Programmatic users set the same policy on an environment before processing
source:

```lua
local env = tealdoc.Env.init()
env.doc_precedence = "definition"
```

`Env.init()` defaults to `"declaration"`. The CLI reads `tlconfig.lua` only
after handling `--version`, so version reporting never executes project
configuration.

For Markdown output, `markdown.type_links` can map canonical Tealdoc path
prefixes to URL prefixes:

```lua
local base = os.getenv("DOCS_BASE") or ""

return {
    source_dir = "src",
    tealdoc = {
        markdown = {
            type_links = {
                ["my.http"] = base .. "/modules/http#my.http",
                ["my.Future"] = base .. "/modules/future#my.future.Future",
            },
        },
    },
}
```

The exact path links to the page before `#`. A descendant appends its suffix
to the complete URL prefix, so `my.http.Response` above links to
`/modules/http#my.http.Response`. Types with no route remain plain code.

For complete control, the configuration can instead return a resolver
function. It receives a canonical type path and returns its URL, or `nil` when
the type should remain unlinked:

```lua
return {
    tealdoc = {
        markdown = {
            type_links = function(path)
                if path == "external.Widget" then
                    return "https://example.com/widget"
                end
            end,
        },
    },
}
```

`tlconfig.lua` is loaded and executed as trusted Lua code. Markdown cannot
contain links inside fenced code blocks, so Tealdoc keeps signatures as valid,
syntax-highlighted Teal and applies type links in the structured Arguments and
Returns sections.

### Static Site Output

`tealdoc site` composes handwritten Markdown and generated API reference into
a responsive static site. It does not replace `tealdoc md`; site generation is
an explicit command with its own `tealdoc.site` configuration:

```lua
return {
    tealdoc = {
        site = {
            title = "My project",
            -- Set name = "" for a logo-only header.
            name = "My project",
            description = "Project documentation",
            language = "en",
            base = "/",
            site_url = "https://docs.example.com",
            logo = "/images/logo.svg",
            github = "https://github.com/example/my-project",
            favicon = "favicon.svg",
            public = "docs/public",
            cname = "docs.example.com",
            author = "My project contributors",
            social_image = "/images/social-card.png",
            twitter_site = "@myproject",
            head = {
                {
                    tag = "meta",
                    attributes = {
                        name = "theme-color",
                        content = "#137a7f",
                    },
                },
            },
            custom_css = "docs/site.css",
            format_generated_code = true,
            templates = "docs/templates",
            copyright = "Copyright My project contributors",
            license = "MIT licensed",
            sources = {
                "src/my/api.tl",
                "src/my/widgets",
            },
            footer_links = {
                { text = "Notices", path = "notices" },
                { text = "MIT License", path = "license" },
            },
            not_found = {
                title = "Page not found",
                description = "The requested page does not exist.",
                source = "docs/404.md",
            },
            redirects = {
                ["old-api.html"] = "api",
            },
            nav = {
                { text = "Home", path = "" },
                { text = "API", path = "api" },
            },
            pages = {
                {
                    path = "",
                    title = "Home",
                    source = "docs/index.md",
                    layout = "home",
                    hero_title = "My project",
                    hero_text = "A short introduction.",
                    hero_image = "/images/project.png",
                    hero_image_alt = "My project",
                    hero_actions = {
                        { text = "Get started", path = "guide", theme = "brand" },
                        { text = "API", path = "api", theme = "alt" },
                    },
                    features = {
                        {
                            icon = "✓",
                            title = "Typed",
                            details = "Checked examples and linked API types.",
                        },
                    },
                },
                {
                    path = "api",
                    title = "API",
                    source = "docs/api.md",
                    api = "my.api",
                },
            },
            before_build = function(context)
                -- Adjust page metadata before rendering.
            end,
            after_build = function(context)
                -- Generate a sitemap or other final artifact.
            end,
        },
    },
}
```

`sources` accepts Teal files and directories. Directories are searched
recursively for `.tl` files in deterministic order. Command-line files are
added to the configured sources, so a project can keep its normal inputs in
configuration and add a one-off module for a particular build:

```sh
tealdoc site --output site src/my/experimental.tl
```

All configured filesystem paths are relative to the discovered
`tlconfig.lua`, not the directory from which `tealdoc` was invoked. This
includes `sources`, page and example `source` values, `custom_css`, and
`templates`, plus `public` and the custom 404 `source`. The `--output` path
and command-line Teal files remain relative to the invoking directory.

#### Site settings

Tealdoc rejects unknown setting names. Every setting below links to its own
reference section with its type, behavior, and a minimal example. Compound
settings document their complete nested table shape.

| Setting | Default | Meaning |
| --- | --- | --- |
| [`title`](site_configuration.md#title) | required | Project name used in document titles. |
| [`name`](site_configuration.md#name) | `title` | Header wordmark; use `""` for a logo-only header. |
| [`description`](site_configuration.md#description) | `""` | Fallback page description. |
| [`language`](site_configuration.md#language) | `"en"` | HTML language and Open Graph locale. |
| [`base`](site_configuration.md#base) | `"/"` | Root URL path. |
| [`site_url`](site_configuration.md#site_url) | omitted | HTTP(S) origin used for canonical URLs and the sitemap. |
| [`logo`](site_configuration.md#logo) | omitted | Header logo URL. |
| [`github`](site_configuration.md#github) | omitted | GitHub repository URL shown in the header. |
| [`favicon`](site_configuration.md#favicon) | omitted | Favicon URL. |
| [`public`](site_configuration.md#public) | omitted | Config-relative static asset directory. |
| [`cname`](site_configuration.md#cname) | omitted | Bare DNS name written to `CNAME`. |
| [`head`](site_configuration.md#head) | `{}` | Escaped `meta` and `link` entries. |
| [`author`](site_configuration.md#author) | omitted | Author metadata. |
| [`social_image`](site_configuration.md#social_image) | omitted | Default social image. |
| [`twitter_site`](site_configuration.md#twitter_site) | omitted | Twitter account metadata. |
| [`sitemap`](site_configuration.md#sitemap) | `site_url ~= nil` | Generate `sitemap.xml`. |
| [`robots`](site_configuration.md#robots) | `true` | Generate `robots.txt`. |
| [`not_found`](site_configuration.md#not_found) | omitted | Custom 404 page. |
| [`custom_css`](site_configuration.md#custom_css) | omitted | Project stylesheet. |
| [`lexers`](site_configuration.md#lexers) | omitted | Scintillua lexers for non-Teal blocks. |
| [`templates`](site_configuration.md#templates) | omitted | Template override directory. |
| [`copyright`](site_configuration.md#copyright) | omitted | Escaped footer copyright. |
| [`license`](site_configuration.md#license) | omitted | Escaped footer license. |
| [`footer_links`](site_configuration.md#footer_links) | `{}` | Structured footer links. |
| [`redirects`](site_configuration.md#redirects) | `{}` | Old route to destination mappings. |
| [`sources`](site_configuration.md#sources) | `{}` | Teal source files and directories. |
| [`pages`](site_configuration.md#pages) | `{}` | Handwritten and API pages. |
| [`examples`](site_configuration.md#examples) | `{}` | Page and attached examples. |
| [`validate_links`](site_configuration.md#validate_links) | `true` | Validate internal links and anchors. |
| [`format_generated_code`](site_configuration.md#format_generated_code) | `false` | Format generated Teal with Cerulean. |
| [`constructor_pattern`](site_configuration.md#constructor_pattern) | omitted | Lua pattern that classifies constructor functions. |
| [`nav`](site_configuration.md#nav) | `{}` | Header navigation link tables. |
| [`before_build`](site_configuration.md#before_build) | omitted | Pre-render build hook. |
| [`after_build`](site_configuration.md#after_build) | omitted | Post-render build hook. |

At least one page is required, but Teal sources are not. A
Markdown-only site is a supported zero-Teal build.

Page settings are `path`, required `title`, `description`, `source`, `api`,
`public`, `layout`, `hero_title`, `hero_text`, `hero_image`,
`hero_image_alt`, `hero_actions`, `features`, `canonical`, `image`, and
`noindex`. An action or navigation link has required `text` and `path`, plus
optional `theme`. A feature has required `title` and optional `details`,
`icon`, and `image`.

Page paths are clean URL routes rather than filesystem paths.
Leading and trailing slashes and repeated separators normalize away. A route
cannot contain `.`, `..`, a query, or a fragment. Page and redirect
sources must remain unique after normalization. Tealdoc rejects a conflict
before writing page output. Relative redirect destinations use `base`;
absolute paths and HTTP(S) destinations are preserved.

The default layout provides desktop navigation, a left page sidebar, a right
page outline, breadcrumbs, previous and next links, heading permalinks, and
JavaScript-free mobile navigation and light/dark controls. The optional logo is
a URL, while `github` adds the GitHub header action. Set `name` to an empty
string for a logo-only header, omit `logo` for text only, or provide both.
`nav` is an ordered array of link tables. Each entry requires `text` and
`path`; paths may be site routes, absolute paths, or external URLs:

```lua
nav = {
    { text = "Guide", path = "guide" },
    { text = "API", path = "reference/api" },
    { text = "Community", path = "https://example.com/community" },
}
```

Tealdoc emits the composed Markdown beside every HTML page and always links it
from the header.
Every non-home page also emits the same composed Markdown as a page-local
`llms.txt` and links it from the footer. A page at `modules/window` therefore
writes `modules/window/llms.txt`. The home page uses and links `index.md`
instead. The root `llms.txt` is a site index linking those documents, and
`llms-full.txt` aggregates every ordinary page's composed Markdown. Every page
head links its composed Markdown with `rel="alternate"` and
`type="text/markdown"`.

The site identity and output settings are:

- `title` is required and names the site in page titles and social metadata.
- `description` is required as the default page and social description.
- `name` defaults to `title`; set it to `""` for a logo-only header.
- `language` defaults to `"en"` and becomes the document's `lang` value.
- `base` defaults to `"/"` and is the deployment path prefix. It does not
  contain an origin.
- `site_url` has no default. Set it to an HTTP or HTTPS origin without a path,
  such as `https://docs.example.com`, to emit absolute canonical and social
  URLs and `sitemap.xml`. Tealdoc combines it with `base`.
- `logo` and `github` have no defaults and add their respective header items.
- `favicon` has no default. Absolute paths and URLs are used as written;
  relative paths are resolved under `base`.
- `public` has no default. When set, Tealdoc recursively copies the contents
  of that directory to the output root before writing generated files.
  Symbolic links and non-file, non-directory entries are rejected. A public
  asset that conflicts with a generated output is rejected before either file
  is written.
- `cname` has no default. It must be a bare DNS name and writes a root `CNAME`
  file for hosts such as GitHub Pages.
- `author`, `social_image`, and `twitter_site` have no defaults. `author`
  emits author metadata; `social_image` is the default Open Graph image; and
  `twitter_site` emits the corresponding Twitter card field.
- `sitemap` defaults to `true` when `site_url` is set. Set it to `false` to
  suppress `sitemap.xml`.
- `robots` defaults to `true` and writes `robots.txt`, including the sitemap
  URL when one is generated. Set it to `false` to suppress the file.
- `not_found` has no default. When set, it accepts `title`, `description`,
  `source`, and the ordinary visual page fields, and writes `404.html`,
  `404.md`, and `404/llms.txt`. The page is marked `noindex` and omitted from
  the sitemap.

Tealdoc records owned output files as safe relative paths in
`.tealdoc-manifest`. Before a later build it removes files present in the old
manifest but absent from the new output plan, then removes only directories
left empty by those deletions. Files not listed in the previous manifest are
never pruned, and an unowned file at a planned output path is an error rather
than an overwrite. The replacement manifest is written only after link
validation succeeds.

Each ordinary page may set `canonical` to replace its derived canonical URL,
`image` to replace `social_image`, and `noindex = true` to emit robots
metadata and omit the page from the sitemap. Canonical values may be absolute
URLs or paths relative to `site_url`. Tealdoc emits Open Graph title,
description, locale, type, URL, and image fields where their inputs are
available, plus explicit Twitter title, description, image, site, and summary
or large-image card fields.

`head` defaults to an empty list and provides a narrow, escaped extension for
additional metadata. Each entry has `tag = "meta"` or `tag = "link"` and a
string `attributes` table. Meta entries allow `name`, `property`, and
`content`; link entries allow `rel`, `href`, `type`, `sizes`, `media`,
`hreflang`, `title`, `as`, `crossorigin`, and `referrerpolicy`. Scripts, event
handlers, raw HTML, control characters, and `javascript:` URLs are rejected.

`copyright` and `license` remain optional escaped plain text for backward
compatibility. `footer_links` defaults to an empty list and adds structured
`{ text, path }` links before the page-local `llms.txt` (or home `index.md`)
and Tealdoc credit.
Relative paths use `base`; HTTP, HTTPS, `mailto:`, and fragment destinations
are used as written.

Tealdoc renders the document shell with the dependency-free
`lua-resty-template` package. Set `templates` to an optional directory
containing any of these narrowly supported overrides:

- `layout.html` owns the document shell and asset tags.
- `header.html` owns the brand, search, top navigation and header actions.
- `content.html` owns the main region on ordinary pages.
- `home.html` owns the main region on the home page.
- `footer.html` owns the footer wrapper.

Missing files fall back independently to Tealdoc's built-in templates, so a
project can replace only the region it needs. Includes outside those five
names are rejected. Templates run as trusted build-time Lua and use
lua-resty-template syntax: `{{value}}` escapes text, `{*value*}` emits prepared
HTML, `{(header.html)}` includes a fixed template, and
`{[content_template]}` includes the selected content template. The generated
site still uses four-space-indented HTML, and fenced code contents are not
re-indented.

Home-page structure stays in `tlconfig.lua` rather than YAML frontmatter, so
the handwritten source remains ordinary portable Markdown. A `layout = "home"`
page renders its title, text and actions on the left. `hero_image` opts into a
right-hand image over a theme-colored starburst; when it is absent, the right
column is not emitted. `features` renders the compact feature badges below the
hero. Feature `details` accepts Markdown.

Tealdoc discovers Teal and Lua regions below `docs/examples`. A region's
canonical name selects the generated API item that receives it:

```teal
-- #region my.api.open
local value: string = "example"
my.api.open(value)
-- #endregion my.api.open
```

The markers are omitted from the rendered example. Regions may be nested;
Tealdoc tracks every open marker so an inner region cannot end an outer
selection early. CRLF files and trailing whitespace on markers are accepted.
Tealdoc checks the selected region, not the surrounding file, with the
project's configured Teal compiler environment; Lua regions receive a syntax
check. The code a reader sees is the code Tealdoc checked. Set `check = false`
only for an intentionally incomplete example. Examples are listed explicitly
rather than discovered with globs, so the site configuration is also the list
of examples the site publishes.

Handwritten pages accept VitePress's `::: code-group` container, labeled
fences such as `` ```teal [Components] ``, and
`::: details Optional title`. Code groups remain a JavaScript-free stack of
labeled blocks, while details use the browser's native disclosure element.
The same Teal and Lua syntax highlighting applies to labeled fences.

Internal link validation runs after pages and the `after_build` hook are
written. It checks generated links and fragments, understands the configured
`base`, skips external URL schemes, and fails the build with every missing
target it finds. Set `validate_links = false` only when another build step
owns the site's internal links.

Search and current-section outline highlighting use a small dependency-free
script. Tealdoc writes a static search index and loads it only when search is
first opened. A query returns at most 50 ranked results. Home-page hero,
action, feature, and Markdown content are part of the page entry. Navigation,
theme switching, syntax highlighting, and disclosure controls work without
JavaScript, and the page outline remains a usable list of links when scripting
is unavailable. When scripting is available, the selected light or dark theme
persists across pages.

Generated reference headings write an instance method with a colon before its
name, such as `Future:wait`, and add a compact semantic badge such as `method`,
`function`, `field`, `record`, or `enum`. Tealdoc treats a callable whose first
parsed parameter is `self` as a method; record variables are fields. Each generated module reference starts
with a linked API table using the same kinds. Its description is the first
documentation sentence, shortened to 120 characters with `...` when needed.
The section heading includes the public module name, such as
`tecs.window.Window Reference`. A generic “Public APIs in …” introduction is
only added when the configured module page has no handwritten documentation.

Set `format_generated_code = true` to run synthesized API declarations through
Cerulean. Tealdoc loads Cerulean from Lua's existing package paths at runtime;
it remains an optional dependency. The setting also formats authored Teal
fences and configured Teal examples. Write `` ```teal no-format `` when an
example's intentional layout must be preserved; Tealdoc removes `no-format`
from the generated fence.

Set `constructor_pattern = "^new"` to collect matching public functions under
Constructors. Generated references order their groups as Constructors, Types,
Functions, Macros, then Values. Methods and metamethods remain under Functions;
Teal macros appear under Macros.

Documentation comments can cross-link public types with ordinary Markdown by
using a `tealdoc:` destination:

```markdown
See [`Window`](tealdoc:tecs.platform.Window).
```

The destination may be a canonical type path or an unambiguous type name.
Tealdoc resolves it through the same public-alias rules as signature links and
writes the real site URL into both HTML and downloadable Markdown.

Tealdoc uses Teal's compiler lexer at build time to syntax-highlight fenced
`teal` and `lua` blocks. Teal is a Lua superset, so the same lexer handles Lua
without another runtime dependency. Resolved public types become links in Teal
signatures, using the same alias visibility rules as structured Arguments and
Returns; Lua blocks are highlighted without type links. Token markup follows
Prism's standard classes, and the default theme accepts VitePress `--vp-*`
variables as fallbacks in addition to Tealdoc's `--tealdoc-*` properties. Pico
CSS 2.1.1 provides the semantic element baseline; its minified MIT-licensed
stylesheet is pinned in the repository and copied into every site, so a build
does not depend on a CDN. Tealdoc's stylesheet owns the documentation layout.
`custom_css` appends one project stylesheet after those defaults. Set
`--tealdoc-font-heading` there to give every content, hero, and feature
heading a project typeface without repeating selectors.
Leading `@import` rules are hoisted ahead of the bundled defaults so imported
fonts remain valid while the project rules themselves retain final cascade
priority.
`--tealdoc-heading-font-weight` controls their weight, and
`--tealdoc-content-font-size` controls reference-page body text. The default
`--tealdoc-content-width` cap is `688px`, matching VitePress; set it in
`custom_css` to choose a wider measure. The default base stack matches
VitePress's Inter and system-font stack, including its color emoji fallbacks,
with optical sizing enabled. Fenced code defaults to a fixed `14px`;
set `--tealdoc-code-block-font-size` to change it without affecting inline
code. Its `--tealdoc-font-mono` stack prefers a locally installed JetBrains
Mono and falls back through common system monospace fonts; Tealdoc does not
download a code font.

Links use the active accent color by default. Override
`--tealdoc-light-link`, `--tealdoc-light-link-hover`,
`--tealdoc-dark-link`, and `--tealdoc-dark-link-hover` to give them an
independent palette. Link underlines inherit the rendered link color.

The supported theme API consists of the documented custom-property families:

- `--tealdoc-light-*` and `--tealdoc-dark-*` source palette tokens;
- semantic colors `--tealdoc-accent*`, `--tealdoc-link*`,
  `--tealdoc-background*`,
  `--tealdoc-border`, `--tealdoc-code-background`, and `--tealdoc-text*`;
- `--tealdoc-font*`, `--tealdoc-content-*`, `--tealdoc-heading-*`, and the
  layout width and gutter properties;
- `--tealdoc-sidebar-*` and `--tealdoc-outline-*`;
- `--tealdoc-home-*`, `--tealdoc-hero-*`, `--tealdoc-button-*`,
  `--tealdoc-admonition-*`, and `--tealdoc-footer-*`;
- every `--tealdoc-syntax-*` token.

The stable selector surface for narrow structural overrides is
`.tealdoc-site`, `.tealdoc-header`, `.tealdoc-brand`, `.tealdoc-nav`,
`.tealdoc-shell`, `.tealdoc-sidebar`, `.tealdoc-sidebar-section`,
`.tealdoc-content`, `.tealdoc-breadcrumbs`, `.tealdoc-outline`,
`.tealdoc-home-content`, `.tealdoc-home-hero`, `.tealdoc-hero-*`,
`.tealdoc-features`, `.tealdoc-feature`, `.tealdoc-admonition`,
`.tealdoc-details`, `.tealdoc-code-group`, `.tealdoc-labeled-code`,
`.tealdoc-kind-badge`, `.tealdoc-page-nav`, and `.tealdoc-footer`.
Other selectors are implementation details. Prefer custom properties over
selector overrides whenever a token exists.

`redirects` maps an old site route to a new route. Relative destinations are
resolved against `base`; absolute paths and `http://` or `https://` URLs are
used as written. Tealdoc emits a JavaScript-free redirect page with a canonical
link, immediate meta refresh, and visible fallback link. A redirect source may
not collide with a configured page. Sources ending in `.html` are emitted as
files; other sources are emitted as clean routes with an `index.html`.

The site reader enables Lunamark's native fenced-Div extension for
admonitions. The body is ordinary Markdown, and text after the kind is an
optional title:

```markdown
::: warning One thread
Settle a future on the same thread that pumps its source.
:::
```

Built-in kinds are `note` (or `info`), `tip`, `warning`, and `danger`.
GitHub-style alerts use the same component:

```markdown
> [!IMPORTANT]
> Futures settle in source order.
```

The supported GitHub markers are `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, and
`CAUTION`.

The two hooks are ordinary trusted Lua functions. Tealdoc validates settings,
resolves config-relative paths, validates examples, assembles example pages,
and then calls `before_build` before creating the output directory.
Its context contains `output`, `env`, resolved `settings`, the mutable combined
`pages` list, and an initially empty `files` list. A hook may adjust page
metadata or add pages; routes are normalized and validated again after it
returns. Tealdoc then renders pages, redirects, assets, and the search index,
adding every generated path to `files`. `after_build` runs last with that
completed context and may write additional artifacts. Files it writes are not
added automatically; append each path to `context.files` to include it in link
validation and Tealdoc's ownership manifest.

#### Compatibility policy

The `tealdoc` CLI and `tlconfig.lua` configuration are public interfaces.
Changes to them are backward compatible; a renamed setting gets a deprecation
period. Tealdoc also makes a best effort to preserve documented template
overrides, stable CSS custom properties, and stable CSS selectors.
Experimental site features may still change while they bake. Intentional
exceptions are called out in release notes.

Tealdoc's source-code modules and internal Lua or Teal APIs provide **zero
backward compatibility guarantees**. They may change without notice. Integrate
through the CLI, configuration, documented hooks, templates, and CSS extension
surface rather than importing generator internals.
