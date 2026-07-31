return {
    build_dir = "build",
    source_dir = "src",
    include_dir = {
        "src",
        "types"
    },

    -- The site this project publishes, and the worked example of a
    -- configuration. It sets a title, a description and its pages, and
    -- nothing else: no custom stylesheet, no template override, no theme
    -- settings. What it looks like is what the defaults look like, which is
    -- the point of keeping it this short.
    tealdoc = {
        site = {
            title = "Tealdoc",
            description = "A documentation generator for Teal",
            base = "/",
            nav = {
                { text = "Install", path = "installation" },
                { text = "Tutorial", path = "tutorial" },
                { text = "API", path = "api" },
            },
            pages = {
                {
                    path = "",
                    title = "Tealdoc",
                    description = "A documentation generator for Teal",
                    source = "docs/header.md",
                },
                {
                    path = "installation",
                    title = "Installation",
                    description = "Installing tealdoc with LuaRocks",
                    source = "docs/installation.md",
                },
                {
                    path = "tutorial",
                    title = "Tutorial",
                    description = "How to document your code",
                    source = "docs/tutorial.md",
                },
                {
                    path = "cli",
                    title = "CLI reference",
                    description = "Commands, flags and configuration",
                    source = "docs/cli_reference.md",
                },
                {
                    path = "site",
                    title = "Site configuration",
                    description = "Every tealdoc.site setting",
                    source = "docs/site_configuration.md",
                },
                {
                    path = "architecture",
                    title = "Architecture",
                    description = "How tealdoc is put together",
                    source = "docs/architecture.md",
                },
                {
                    path = "about",
                    title = "About",
                    description = "Where tealdoc came from",
                    source = "docs/about.md",
                },
                {
                    path = "api",
                    title = "API",
                    description = "The tealdoc module",
                    source = "docs/api_reference_header.md",
                    api = "tealdoc",
                },
            },
        },
    },
}
