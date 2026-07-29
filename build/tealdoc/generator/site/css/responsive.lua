return [[
@media (max-width: 1100px) {
    .tealdoc-shell {
        grid-template-columns: var(--tealdoc-sidebar-width) minmax(0, 1fr);
    }

    .tealdoc-outline {
        display: none;
    }

    .tealdoc-features {
        grid-template-columns: repeat(2, minmax(0, 1fr));
    }

}

@media (max-width: 760px) {
    .tealdoc-nav {
        position: relative;
        gap: 0.65rem;
        padding: 0 1rem;
    }

    .tealdoc-top-nav {
        display: none;
    }

    .tealdoc-brand {
        flex: 1;
    }

    .tealdoc-search-button span:nth-child(2),
    .tealdoc-search-button kbd {
        display: none;
    }

    .tealdoc-search-button {
        width: 34px;
        margin-left: auto;
        padding: 0;
        border-color: transparent;
        background: transparent;
        font-size: 1rem;
    }

    .tealdoc-mobile-menu {
        display: block;
        margin: 0;
    }

    .tealdoc-mobile-menu[open] {
        position: absolute;
        z-index: 40;
        top: var(--tealdoc-header-height);
        right: 0;
        left: 0;
        padding: 0.8rem 1rem 1rem;
        border-bottom: 1px solid var(--tealdoc-border);
        background: var(--tealdoc-background);
        box-shadow: 0 14px 30px rgb(0 0 0 / 12%);
    }

    .tealdoc-mobile-top-nav {
        display: grid;
        gap: 0.2rem;
        margin: 0;
        padding: 0 0 0.65rem;
        border-bottom: 1px solid var(--tealdoc-border);
    }

    .tealdoc-mobile-top-nav a {
        display: block;
        padding: 0.45rem 0.6rem;
        color: var(--tealdoc-text-muted);
        border-radius: 6px;
        text-decoration: none;
    }

    .tealdoc-mobile-top-nav a[aria-current="page"] {
        color: var(--tealdoc-accent);
        background: var(--tealdoc-accent-soft);
    }

    .tealdoc-mobile-menu > ul {
        margin: 0.75rem 0 0;
        padding: 0.65rem 0 0;
        border-top: 1px solid var(--tealdoc-border);
        list-style: none;
    }

    .tealdoc-mobile-menu a {
        display: block;
        padding: 0.45rem 0.6rem;
        color: var(--tealdoc-text-muted);
        border-radius: 6px;
        text-decoration: none;
    }

    .tealdoc-mobile-menu a[aria-current="page"] {
        color: var(--tealdoc-accent);
        background: var(--tealdoc-accent-soft);
    }

    .tealdoc-mobile-menu .tealdoc-sidebar-section ul {
        list-style: none;
    }

    .tealdoc-shell {
        display: block;
    }

    .tealdoc-sidebar {
        display: none;
    }

    .tealdoc-mobile-outline {
        display: block;
        margin-bottom: 1.5rem;
        padding: 0.75rem 1rem;
        border: 1px solid var(--tealdoc-border);
        border-radius: 8px;
        background: var(--tealdoc-background-alt);
    }

    .tealdoc-mobile-outline summary {
        color: var(--tealdoc-text-muted);
        cursor: pointer;
        font-size: 0.85rem;
        font-weight: 600;
    }

    .tealdoc-mobile-outline ol {
        margin: 0.75rem 0 0;
        padding: 0.75rem 0 0.25rem 0.85rem;
        border-left: 1px solid var(--tealdoc-border);
        list-style: none;
    }

    .tealdoc-mobile-outline li {
        margin: 0.2rem 0;
    }

    .tealdoc-mobile-outline a {
        color: var(--tealdoc-text-muted);
        font-size: 0.8rem;
        text-decoration: none;
    }

    .tealdoc-mobile-outline .level-3 a {
        padding-left: 0.65rem;
    }

    .tealdoc-content {
        width: min(100% - 2rem, var(--tealdoc-content-width));
        padding-top: 1rem;
    }

    .tealdoc-home-content {
        width: min(100% - 2rem, var(--tealdoc-home-width));
        padding-top: 2.5rem;
    }

    .tealdoc-hero-main.has-image {
        grid-template-columns: minmax(0, 1fr);
    }

    .tealdoc-hero-main {
        min-height: 0;
        gap: 2rem;
    }

    .tealdoc-hero-copy h1 {
        font-size: var(--tealdoc-hero-name-size-narrow);
    }

    .tealdoc-hero-image {
        min-height: 280px;
    }

    .tealdoc-hero-starburst {
        width: min(78vw, 340px);
    }

    .tealdoc-features {
        grid-template-columns: minmax(0, 1fr);
    }

    .tealdoc-footer-inner {
        padding: 1rem;
    }

    .tealdoc-footer-inner::before {
        display: none;
    }

    .tealdoc-page-nav {
        grid-template-columns: 1fr;
    }

    .tealdoc-page-nav > span {
        display: none;
    }
}

@media (max-width: 520px) {
    .tealdoc-brand-name {
        display: none;
    }

    .tealdoc-nav {
        gap: 0.35rem;
    }
}
]]
