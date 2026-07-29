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

### Project Configuration

Tealdoc reads its project settings from the `tealdoc` table in the nearest
`tlconfig.lua`, using the same current-directory and parent-directory search as
Teal. The namespace lets Tealdoc add settings without colliding with compiler
or other tool settings.

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
            show_markdown_link = true,
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
            examples = {
                {
                    path = "examples/basic",
                    title = "Basic usage",
                    description = "A complete, compiler-checked example.",
                    source = "examples/basic.tl",
                },
                {
                    attach_to = "my.api.open",
                    title = "Open a basic value",
                    source = "examples/all.tl",
                    region = "open-basic",
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

Tealdoc rejects unknown setting names. Site settings and defaults are:

| Setting | Default | Meaning |
| --- | --- | --- |
| `title` | required | Project name used in document titles. |
| `name` | `title` | Header wordmark; use `""` for a logo-only header. |
| `description` | `""` | Fallback page description. |
| `language` | `"en"` | HTML language and Open Graph locale. |
| `base` | `"/"` | Root URL path. It must begin with `/`; Tealdoc adds the trailing slash. |
| `site_url` | omitted | HTTP(S) origin used for canonical URLs and the sitemap. |
| `logo` | omitted | Header logo URL. |
| `github` | omitted | GitHub repository URL shown in the header. |
| `show_markdown_link` | `false` | Show a header link to the Markdown Tealdoc always emits. |
| `favicon` | omitted | Favicon URL; relative values use `base`. |
| `public` | omitted | Config-relative directory copied to the output root. |
| `cname` | omitted | Bare DNS name written to `CNAME`. |
| `head` | `{}` | Escaped, allowlisted `meta` and `link` entries. |
| `author` | omitted | Author metadata. |
| `social_image` | omitted | Default Open Graph and Twitter image. |
| `twitter_site` | omitted | Twitter account metadata. |
| `sitemap` | `site_url ~= nil` | Generate `sitemap.xml`. |
| `robots` | `true` | Generate `robots.txt`. |
| `not_found` | omitted | Custom 404 page definition. |
| `custom_css` | omitted | Project stylesheet appended after the defaults. |
| `templates` | omitted | Directory containing supported template overrides. |
| `copyright` | omitted | Escaped copyright text in the footer. |
| `license` | omitted | Escaped license text in the footer. |
| `footer_links` | `{}` | Structured footer links. |
| `redirects` | `{}` | Old route to destination mappings. |
| `sources` | `{}` | Teal files or directories to process for API pages. |
| `pages` | `{}` | Handwritten and API page definitions. |
| `examples` | `{}` | Complete page examples or examples attached to API items. |
| `validate_links` | `true` | Validate generated internal links and anchors. |
| `nav` | `{}` | Header navigation links. |
| `before_build` | omitted | Trusted Lua hook run immediately before rendering. |
| `after_build` | omitted | Trusted Lua hook run after all normal artifacts are written. |

At least one page or example is required, but Teal sources are not. A
Markdown-only site is a supported zero-Teal build.

Page settings are `path`, required `title`, `description`, `source`, `api`,
`public`, `layout`, `hero_title`, `hero_text`, `hero_image`,
`hero_image_alt`, `hero_actions`, `features`, `canonical`, `image`, and
`noindex`. An action or navigation link has required `text` and `path`, plus
optional `theme`. A feature has required `title` and optional `details`,
`icon`, and `image`.

Every example requires `source` and exactly one of `path` or `attach_to`.
Page examples also require `title`; attached examples default it to
`"Example"`. Optional settings are `description`, `region`, `language`, and
`check`. `language` defaults from the source extension and `check` defaults
to `true`.

Page and example paths are clean URL routes rather than filesystem paths.
Leading and trailing slashes and repeated separators normalize away. A route
cannot contain `.`, `..`, a query, or a fragment. Page, example, and redirect
sources must remain unique after normalization. Tealdoc rejects a conflict
before writing page output. Relative redirect destinations use `base`;
absolute paths and HTTP(S) destinations are preserved.

The default layout provides desktop navigation, a left page sidebar, a right
page outline, breadcrumbs, previous and next links, heading permalinks, and
JavaScript-free mobile navigation and light/dark controls. The optional logo is
a URL, while `github` adds the GitHub header action. Set `name` to an empty
string for a logo-only header, omit `logo` for text only, or provide both.
Tealdoc emits the composed Markdown beside every HTML page regardless of
`show_markdown_link`; that setting controls only its header link.
Every page also emits the same composed Markdown as a page-local `llms.txt`
and links it from the footer. A page at `modules/window` therefore writes
`modules/window/llms.txt`; the home page writes the root `llms.txt`. Every
page head links its composed Markdown with `rel="alternate"` and
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
  Symbolic links and non-file, non-directory entries are rejected. Generated
  files win if a public asset uses a reserved generated path.
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
`{ text, path }` links before the page-local `llms.txt` and Tealdoc credit.
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

`examples` accepts exact source files in two forms. `path` creates an ordinary
site page. `attach_to` places the example under that canonical public API item
in its generated reference. Use one or the other. Tealdoc infers `teal` from
`.tl` and `lua` from `.lua`, or accepts an explicit `language`.

An optional `region` extracts the lines between matching source comments:

```teal
-- #region open-basic
local value: string = "example"
my.api.open(value)
-- #endregion open-basic
```

The markers are omitted from the rendered example. Tealdoc checks the selected
region, not the surrounding file, with the project's configured Teal compiler
environment; Lua regions receive a syntax check. The code a reader sees is the
code Tealdoc checked. Set `check = false` only for an intentionally incomplete
example. Examples are listed explicitly rather than discovered with globs, so
the site configuration is also the list of examples the site publishes.

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
is unavailable.

Generated reference headings keep canonical item names unchanged and add a
compact semantic badge such as `method`, `function`, `field`, `record`, or
`enum`. Tealdoc treats a callable whose first parsed parameter is `self` as a
method; record variables are fields. Each generated module reference starts
with a linked API table using the same kinds. Its description is the first
documentation sentence, shortened to 120 characters with `...` when needed.
The section heading includes the public module name, such as
`tecs.window.Window Reference`. A generic “Public APIs in …” introduction is
only added when the configured module page has no handwritten documentation.

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
with optical sizing enabled. Fenced code defaults to `0.8rem`;
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
added automatically.

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
