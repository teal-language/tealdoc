local tealdoc = require("tealdoc")

local record SiteTypes
    record ApiSource
        module: string
        public: string
        include: {string}
    end

    record Link
        text: string
        path: string
        theme: string
    end

    record Feature
        title: string
        details: string
        icon: string
        image: string
    end

    record HeadEntry
        tag: string
        attributes: {string: string}
    end

    record Page
        path: string
        title: string
        description: string
        source: string
        api: string | {string | ApiSource}
        public: string
        layout: string
        hero_title: string
        hero_text: string
        hero_image: string
        hero_image_alt: string
        hero_actions: {Link}
        features: {Feature}
        example_source: string
        example_language: string
        example_code: string
        canonical: string
        image: string
        noindex: boolean
    end

    record SidebarItem
        text: string
        path: string
        items: {SidebarItem}
        collapsed: boolean
    end

    record Example
        path: string
        attach_to: string
        region: string
        title: string
        description: string
        source: string
        language: string
        check: boolean
    end

    record Settings
        title: string
        name: string
        description: string
        language: string
        base: string
        site_url: string
        logo: string
        github: string
        favicon: string
        public: string
        cname: string
        head: {HeadEntry}
        author: string
        social_image: string
        twitter_site: string
        sitemap: boolean
        robots: boolean
        not_found: Page
        custom_css: string
        lexers: string
        templates: string
        copyright: string
        license: string
        footer_links: {Link}
        redirects: {string: string}
        examples: {Example}
        validate_links: boolean
        format_generated_code: boolean
        pages: {Page}
        sidebar: {SidebarItem}
        sidebar_open: {string: boolean}
        nav: {Link}
        sources: {string}
        before_build: function(Context)
        after_build: function(Context)
    end

    record Context
        output: string
        env: tealdoc.Env
        settings: Settings
        pages: {Page}
        files: {string}
    end

    record PreparedExample
        attach_to: string
        title: string
        source: string
        language: string
        code: string
    end

    record ApiView
        public: string
        modules: {string}
        env: tealdoc.Env
        source_to_public: {string: string}
        public_paths: {string: boolean}
        source_paths: {string}
    end
end

return SiteTypes
