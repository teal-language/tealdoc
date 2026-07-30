return [[
:root {
    color-scheme: light;
    --tealdoc-light-accent: var(--vp-c-brand-1, #087f8c);
    --tealdoc-light-accent-contrast: #ffffff;
    --tealdoc-light-accent-hover: var(--vp-c-brand-2, #086a75);
    --tealdoc-light-accent-soft: var(--vp-c-brand-soft, #dff3f5);
    --tealdoc-light-link: var(--tealdoc-light-accent);
    --tealdoc-light-link-hover: var(--tealdoc-light-accent-hover);
    --tealdoc-light-background: var(--vp-c-bg, #ffffff);
    --tealdoc-light-background-alt: var(--vp-c-bg-alt, #f6f6f7);
    --tealdoc-light-background-elv: var(--vp-c-bg-elv, #ffffff);
    --tealdoc-light-border: var(--vp-c-divider, #e2e2e3);
    --tealdoc-light-code-background: var(--vp-code-block-bg, #e9e7ec);
    --tealdoc-light-text: var(--vp-c-text-1, #213547);
    --tealdoc-light-text-muted: var(--vp-c-text-2, #67676c);
    --tealdoc-light-text-faint: var(--vp-c-text-3, #929295);
    --tealdoc-light-sidebar-background: var(--tealdoc-light-background-alt);
    --tealdoc-dark-accent: var(--vp-c-brand-1, #5ad9e0);
    --tealdoc-dark-accent-contrast: #102f33;
    --tealdoc-dark-accent-hover: var(--vp-c-brand-2, #7ce4e9);
    --tealdoc-dark-accent-soft: var(--vp-c-brand-soft, #173a3f);
    --tealdoc-dark-link: var(--tealdoc-dark-accent);
    --tealdoc-dark-link-hover: var(--tealdoc-dark-accent-hover);
    --tealdoc-dark-background: var(--vp-c-bg, #1b1b1f);
    --tealdoc-dark-background-alt: var(--vp-c-bg-alt, #161618);
    --tealdoc-dark-background-elv: var(--vp-c-bg-elv, #202127);
    --tealdoc-dark-border: var(--vp-c-divider, #2e2e32);
    --tealdoc-dark-code-background: var(--vp-code-block-bg, #252330);
    --tealdoc-dark-text: var(--vp-c-text-1, #dfdfd6);
    --tealdoc-dark-text-muted: var(--vp-c-text-2, #a8a8a3);
    --tealdoc-dark-text-faint: var(--vp-c-text-3, #6a6a71);
    --tealdoc-dark-sidebar-background: var(--tealdoc-dark-background-alt);
    --tealdoc-accent: var(--tealdoc-light-accent);
    --tealdoc-accent-contrast: var(--tealdoc-light-accent-contrast);
    --tealdoc-accent-hover: var(--tealdoc-light-accent-hover);
    --tealdoc-accent-soft: var(--tealdoc-light-accent-soft);
    --tealdoc-link: var(--tealdoc-light-link);
    --tealdoc-link-hover: var(--tealdoc-light-link-hover);
    --tealdoc-alt-action-hover: color-mix(
        in srgb,
        var(--tealdoc-background-alt) 90%,
        #000000
    );
    --tealdoc-background: var(--tealdoc-light-background);
    --tealdoc-background-alt: var(--tealdoc-light-background-alt);
    --tealdoc-background-elv: var(--tealdoc-light-background-elv);
    --tealdoc-border: var(--tealdoc-light-border);
    --tealdoc-code-background: var(--tealdoc-light-code-background);
    --tealdoc-code-block-font-size: 14px;
    --tealdoc-code-block-radius: 8px;
    --tealdoc-code-block-padding: 0.8rem 0.9rem;
    --tealdoc-code-tab-text: var(--tealdoc-text-muted);
    --tealdoc-code-tab-hover-text: var(--tealdoc-text);
    --tealdoc-code-tab-active-text: var(--tealdoc-text);
    --tealdoc-code-tab-active-bar: var(--tealdoc-accent);
    --tealdoc-code-tab-divider: var(--tealdoc-border);
    --tealdoc-code-tab-font-size: 0.72rem;
    --tealdoc-code-tab-font-weight: 600;
    --tealdoc-code-tab-padding: 0.45rem 0.75rem;
    --tealdoc-code-lang-color: var(--tealdoc-text-faint);
    --tealdoc-code-lang-font-size: 0.68rem;
    --tealdoc-code-lang-top: 2px;
    --tealdoc-code-lang-right: 0.75rem;
    --tealdoc-code-lang-padding: 0 0 0.2rem 0.4rem;
    --tealdoc-inline-code-font-size: 0.91em;
    --tealdoc-inline-code-padding: 0.1em 0.35em;
    --tealdoc-inline-code-radius: 4px;
    --tealdoc-inline-code-background: var(--tealdoc-code-background);
    --tealdoc-content-font-size: 0.8rem;
    --tealdoc-content-gutter: 5rem;
    --tealdoc-content-padding-top: 1.25rem;
    --tealdoc-content-padding-bottom: 6rem;
    --tealdoc-font: var(
        --vp-font-family-base,
        Inter,
        ui-sans-serif,
        system-ui,
        sans-serif,
        "Apple Color Emoji",
        "Segoe UI Emoji",
        "Segoe UI Symbol",
        "Noto Color Emoji"
    );
    --tealdoc-font-heading: var(--tealdoc-font);
    --tealdoc-heading-font-weight: 700;
    --tealdoc-heading-1-size: 1.8rem;
    --tealdoc-heading-2-size: 1.575rem;
    --tealdoc-heading-3-size: 1.35rem;
    --tealdoc-heading-4-size: 1.125rem;
    --tealdoc-heading-5-size: 1.0125rem;
    --tealdoc-heading-6-size: 0.9rem;
    --tealdoc-heading-2-spacing: 2.5rem;
    --tealdoc-heading-3-spacing: 2.25rem;
    --tealdoc-font-mono: var(
        --vp-font-family-mono,
        "JetBrains Mono",
        ui-monospace,
        SFMono-Regular,
        "Cascadia Code",
        "Roboto Mono",
        Menlo,
        Monaco,
        Consolas,
        "Liberation Mono",
        "Courier New",
        monospace
    );
    --tealdoc-header-height: var(--vp-nav-height, 64px);
    --tealdoc-header-background: color-mix(
        in srgb,
        var(--tealdoc-background) 92%,
        transparent
    );
    --tealdoc-header-color: var(--tealdoc-text);
    --tealdoc-header-muted-color: var(--tealdoc-text-muted);
    --tealdoc-header-border: var(--tealdoc-border);
    --tealdoc-header-control-background: var(--tealdoc-background-alt);
    --tealdoc-sidebar-background: var(--tealdoc-light-sidebar-background);
    --tealdoc-sidebar-font-family: var(--tealdoc-font);
    --tealdoc-outline-font-family: var(--tealdoc-font);
    --tealdoc-layout-max-width: var(--vp-layout-max-width, 1480px);
    --tealdoc-content-width: var(--vp-content-width, 688px);
    --tealdoc-sidebar-width: var(--vp-sidebar-width, 272px);
    --tealdoc-outline-width: var(--vp-aside-width, 256px);
    --tealdoc-sidebar-font-size: 0.7rem;
    --tealdoc-sidebar-font-weight: 500;
    --tealdoc-sidebar-active-font-weight: 600;
    --tealdoc-sidebar-item-padding: 0.24rem 0.55rem;
    --tealdoc-sidebar-item-color: var(--tealdoc-text-muted);
    --tealdoc-sidebar-heading-color: var(--tealdoc-text);
    --tealdoc-sidebar-heading-font-size: 0.7rem;
    --tealdoc-sidebar-heading-font-weight: 700;
    --tealdoc-sidebar-section-border: var(--tealdoc-border);
    --tealdoc-sidebar-section-gap: 1.1rem;
    --tealdoc-sidebar-section-padding: 1.1rem;
    --tealdoc-sidebar-nested-top-padding: 4px;
    --tealdoc-sidebar-nested-indent: 0.5rem;
    --tealdoc-outline-font-size: 0.66rem;
    --tealdoc-outline-font-weight: 600;
    --tealdoc-outline-item-padding: 0.16rem 0;
    --tealdoc-outline-nested-font-size: 0.61rem;
    --tealdoc-outline-title-font-size: 0.66rem;
    --tealdoc-outline-title-font-weight: 600;
    --tealdoc-hero-glow-color: var(--tealdoc-accent);
    --tealdoc-hero-glow-size: 520px;
    --tealdoc-hero-glow-blur: 24px;
    --tealdoc-hero-glow-opacity: 0.68;
    --tealdoc-hero-features-gap: 2rem;
    /* The hero is sized in rem and steps at the breakpoints below, rather than
     * sliding with `vw`. Browser zoom is a change in the viewport, so a `vw`
     * size resizes against the zoom instead of with it: the reader asks for a
     * larger page and the heading and the line under it come apart. A rem
     * scales by exactly the zoom factor, which is what was asked for. */
    --tealdoc-hero-name-size: 5.5rem;
    --tealdoc-hero-text-size: 1.6rem;
    --tealdoc-hero-name-size-narrow: 4rem;
    --tealdoc-hero-text-size-narrow: 1.2rem;
    --tealdoc-home-width: 1152px;
    --tealdoc-home-gutter: 2rem;
    --tealdoc-button-brand-background: var(--tealdoc-accent);
    --tealdoc-button-brand-hover-background: var(--tealdoc-accent-hover);
    --tealdoc-button-alt-background: var(--tealdoc-background-alt);
    --tealdoc-button-alt-hover-background: var(--tealdoc-alt-action-hover);
    --tealdoc-admonition-note: var(--tealdoc-accent);
    --tealdoc-admonition-tip: #2e8b57;
    --tealdoc-admonition-important: #8250df;
    --tealdoc-admonition-warning: #c47f00;
    --tealdoc-admonition-danger: #cf222e;
    --tealdoc-footer-background: var(--tealdoc-background);
    --tealdoc-footer-border: var(--tealdoc-border);
    --tealdoc-footer-text: var(--tealdoc-text-faint);
    --tealdoc-footer-link: var(--tealdoc-text-muted);
    --tealdoc-syntax-foreground: #3760bf;
    --tealdoc-syntax-boolean: #b15c00;
    --tealdoc-syntax-comment: #848cb5;
    --tealdoc-syntax-function: #2e7de9;
    --tealdoc-syntax-keyword: #9854f1;
    --tealdoc-syntax-meta: #007197;
    --tealdoc-syntax-number: #b15c00;
    --tealdoc-syntax-operator: #006a83;
    --tealdoc-syntax-property: #387068;
    --tealdoc-syntax-punctuation: #6172b0;
    --tealdoc-syntax-string: #587539;
    --tealdoc-syntax-type: #007197;
    --tealdoc-syntax-variable: #3760bf;
    --tealdoc-text: var(--tealdoc-light-text);
    --tealdoc-text-muted: var(--tealdoc-light-text-muted);
    --tealdoc-text-faint: var(--tealdoc-light-text-faint);
    --pico-font-family: var(--tealdoc-font);
    --pico-primary: var(--tealdoc-link);
    --pico-primary-hover: var(--tealdoc-link-hover);
}

@media (prefers-color-scheme: dark) {
    :root {
        color-scheme: dark;
        --tealdoc-accent: var(--tealdoc-dark-accent);
        --tealdoc-accent-contrast: var(--tealdoc-dark-accent-contrast);
        --tealdoc-accent-hover: var(--tealdoc-dark-accent-hover);
        --tealdoc-accent-soft: var(--tealdoc-dark-accent-soft);
        --tealdoc-link: var(--tealdoc-dark-link);
        --tealdoc-link-hover: var(--tealdoc-dark-link-hover);
        --tealdoc-alt-action-hover: color-mix(
            in srgb,
            var(--tealdoc-background-alt) 90%,
            #ffffff
        );
        --tealdoc-background: var(--tealdoc-dark-background);
        --tealdoc-background-alt: var(--tealdoc-dark-background-alt);
        --tealdoc-sidebar-background: var(--tealdoc-dark-sidebar-background);
        --tealdoc-background-elv: var(--tealdoc-dark-background-elv);
        --tealdoc-border: var(--tealdoc-dark-border);
        --tealdoc-code-background: var(--tealdoc-dark-code-background);
        --tealdoc-syntax-foreground: #c0caf5;
        --tealdoc-syntax-boolean: #ff9e64;
        --tealdoc-syntax-comment: #565f89;
        --tealdoc-syntax-function: #7aa2f7;
        --tealdoc-syntax-keyword: #bb9af7;
        --tealdoc-syntax-meta: #7dcfff;
        --tealdoc-syntax-number: #ff9e64;
        --tealdoc-syntax-operator: #89ddff;
        --tealdoc-syntax-property: #73daca;
        --tealdoc-syntax-punctuation: #a9b1d6;
        --tealdoc-syntax-string: #9ece6a;
        --tealdoc-syntax-type: #2ac3de;
        --tealdoc-syntax-variable: #c0caf5;
        --tealdoc-text: var(--tealdoc-dark-text);
        --tealdoc-text-muted: var(--tealdoc-dark-text-muted);
        --tealdoc-text-faint: var(--tealdoc-dark-text-faint);
    }
}

/* The toggle repaints the root, not the tree under it, because a custom
 * property resolves where it is declared. Half the tokens above are declared
 * here as indirections onto the theme colors, so a repaint applied to a
 * descendant reaches the ones a rule reads directly and none of the ones read
 * through an indirection: those keep whatever the root resolved them to, and
 * the theme the reader asked for arrives in pieces. Repainting the root itself
 * resolves them all at once, and a site's own `:root` values still cascade
 * against the primitives the same way. */
:root:has(.tealdoc-theme-input:checked) {
    color-scheme: dark;
    --tealdoc-accent: var(--tealdoc-dark-accent);
    --tealdoc-accent-contrast: var(--tealdoc-dark-accent-contrast);
    --tealdoc-accent-hover: var(--tealdoc-dark-accent-hover);
    --tealdoc-accent-soft: var(--tealdoc-dark-accent-soft);
    --tealdoc-link: var(--tealdoc-dark-link);
    --tealdoc-link-hover: var(--tealdoc-dark-link-hover);
    --tealdoc-alt-action-hover: color-mix(
        in srgb,
        var(--tealdoc-background-alt) 90%,
        #ffffff
    );
    --tealdoc-background: var(--tealdoc-dark-background);
    --tealdoc-background-alt: var(--tealdoc-dark-background-alt);
    --tealdoc-sidebar-background: var(--tealdoc-dark-sidebar-background);
    --tealdoc-background-elv: var(--tealdoc-dark-background-elv);
    --tealdoc-border: var(--tealdoc-dark-border);
    --tealdoc-code-background: var(--tealdoc-dark-code-background);
    --tealdoc-syntax-foreground: #c0caf5;
    --tealdoc-syntax-boolean: #ff9e64;
    --tealdoc-syntax-comment: #565f89;
    --tealdoc-syntax-function: #7aa2f7;
    --tealdoc-syntax-keyword: #bb9af7;
    --tealdoc-syntax-meta: #7dcfff;
    --tealdoc-syntax-number: #ff9e64;
    --tealdoc-syntax-operator: #89ddff;
    --tealdoc-syntax-property: #73daca;
    --tealdoc-syntax-punctuation: #a9b1d6;
    --tealdoc-syntax-string: #9ece6a;
    --tealdoc-syntax-type: #2ac3de;
    --tealdoc-syntax-variable: #c0caf5;
    --tealdoc-text: var(--tealdoc-dark-text);
    --tealdoc-text-muted: var(--tealdoc-dark-text-muted);
    --tealdoc-text-faint: var(--tealdoc-dark-text-faint);
}

@media (prefers-color-scheme: dark) {
    :root:has(.tealdoc-theme-input:checked) {
        color-scheme: light;
        --tealdoc-accent: var(--tealdoc-light-accent);
        --tealdoc-accent-contrast: var(--tealdoc-light-accent-contrast);
        --tealdoc-accent-hover: var(--tealdoc-light-accent-hover);
        --tealdoc-accent-soft: var(--tealdoc-light-accent-soft);
        --tealdoc-link: var(--tealdoc-light-link);
        --tealdoc-link-hover: var(--tealdoc-light-link-hover);
        --tealdoc-alt-action-hover: color-mix(
            in srgb,
            var(--tealdoc-background-alt) 90%,
            #000000
        );
        --tealdoc-background: var(--tealdoc-light-background);
        --tealdoc-background-alt: var(--tealdoc-light-background-alt);
        --tealdoc-sidebar-background: var(--tealdoc-light-sidebar-background);
        --tealdoc-background-elv: var(--tealdoc-light-background-elv);
        --tealdoc-border: var(--tealdoc-light-border);
        --tealdoc-code-background: var(--tealdoc-light-code-background);
        --tealdoc-syntax-foreground: #3760bf;
        --tealdoc-syntax-boolean: #b15c00;
        --tealdoc-syntax-comment: #848cb5;
        --tealdoc-syntax-function: #2e7de9;
        --tealdoc-syntax-keyword: #9854f1;
        --tealdoc-syntax-meta: #007197;
        --tealdoc-syntax-number: #b15c00;
        --tealdoc-syntax-operator: #006a83;
        --tealdoc-syntax-property: #387068;
        --tealdoc-syntax-punctuation: #6172b0;
        --tealdoc-syntax-string: #587539;
        --tealdoc-syntax-type: #007197;
        --tealdoc-syntax-variable: #3760bf;
        --tealdoc-text: var(--tealdoc-light-text);
        --tealdoc-text-muted: var(--tealdoc-light-text-muted);
        --tealdoc-text-faint: var(--tealdoc-light-text-faint);
    }
}

]]
