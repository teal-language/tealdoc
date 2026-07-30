return [[
html {
    scroll-padding-top: calc(var(--tealdoc-header-height) + 1rem);
}

body {
    margin: 0;
    background: var(--tealdoc-background);
    font-family: var(--tealdoc-font);
    font-optical-sizing: auto;
}

.tealdoc-theme-input {
    position: fixed;
    width: 1px;
    height: 1px;
    clip-path: inset(50%);
    opacity: 0;
}

.tealdoc-site {
    --pico-background-color: var(--tealdoc-background);
    --pico-card-background-color: var(--tealdoc-background-elv);
    --pico-card-border-color: var(--tealdoc-border);
    --pico-code-background-color: var(--tealdoc-code-background);
    --pico-color: var(--tealdoc-text);
    --pico-form-element-background-color: var(--tealdoc-background-elv);
    --pico-form-element-border-color: var(--tealdoc-border);
    --pico-form-element-color: var(--tealdoc-text);
    --pico-form-element-placeholder-color: var(--tealdoc-text-faint);
    --pico-h1-color: var(--tealdoc-text);
    --pico-h2-color: var(--tealdoc-text);
    --pico-h3-color: var(--tealdoc-text);
    --pico-h4-color: var(--tealdoc-text);
    --pico-h5-color: var(--tealdoc-text);
    --pico-h6-color: var(--tealdoc-text);
    --pico-muted-border-color: var(--tealdoc-border);
    --pico-muted-color: var(--tealdoc-text-muted);
    --pico-primary: var(--tealdoc-link);
    --pico-primary-hover: var(--tealdoc-link-hover);
    --pico-table-border-color: var(--tealdoc-border);
    min-height: 100vh;
    overflow-x: clip;
    color: var(--tealdoc-text);
    background: var(--tealdoc-background);
}

.tealdoc-site a {
    text-decoration-color: currentColor;
}

button,
input {
    font-family: inherit;
}

.tealdoc-header {
    position: sticky;
    z-index: 30;
    top: 0;
    min-height: var(--tealdoc-header-height);
    margin: 0;
    padding: 0;
    border-bottom: 1px solid var(--tealdoc-header-border);
    background: var(--tealdoc-header-background);
    backdrop-filter: blur(12px);
}

.tealdoc-nav {
    display: flex;
    width: 100%;
    max-width: var(--tealdoc-layout-max-width);
    min-height: var(--tealdoc-header-height);
    align-items: center;
    gap: 1rem;
    margin: 0 auto;
    padding: 0 1.5rem;
}

.tealdoc-brand {
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 0.6rem;
    color: var(--tealdoc-header-color);
    font-size: 1rem;
    font-weight: 650;
    letter-spacing: -0.01em;
    text-decoration: none;
}

.tealdoc-logo {
    width: auto;
    height: 28px;
}

.tealdoc-brand:hover {
    color: var(--tealdoc-accent);
}

.tealdoc-top-nav {
    display: flex;
    flex: 1;
    justify-content: flex-start;
    gap: 0.25rem;
}

.tealdoc-top-nav a {
    position: relative;
    padding: 0.45rem 0.65rem;
    color: var(--tealdoc-header-muted-color);
    border-radius: 7px;
    font-size: 0.875rem;
    font-weight: 500;
    text-decoration: none;
}

.tealdoc-top-nav a:hover {
    color: var(--tealdoc-header-color);
    background: var(--tealdoc-header-control-background);
}

.tealdoc-top-nav a[aria-current="page"] {
    color: var(--tealdoc-accent);
}

.tealdoc-top-nav a[aria-current="page"]::after {
    position: absolute;
    right: 0.65rem;
    bottom: -0.82rem;
    left: 0.65rem;
    height: 2px;
    border-radius: 2px;
    background: var(--tealdoc-accent);
    content: "";
}

.tealdoc-search-button {
    display: inline-flex;
    width: min(190px, 18vw);
    min-width: 0;
    min-height: 30px;
    align-items: center;
    justify-content: flex-start;
    gap: 0.35rem;
    margin: 0;
    padding: 0.25rem 0.5rem;
    color: var(--tealdoc-header-muted-color);
    border: 1px solid var(--tealdoc-header-border);
    border-radius: 6px;
    background: var(--tealdoc-header-control-background);
    box-shadow: none;
    font-size: 0.76rem;
}

.tealdoc-header-actions {
    display: flex;
    flex: none;
    align-items: center;
    gap: 0.2rem;
}

.tealdoc-search-button:hover {
    color: var(--tealdoc-header-color);
    border-color: var(--tealdoc-header-muted-color);
    background: var(--tealdoc-header-control-background);
}

.tealdoc-icon-link {
    display: inline-flex;
    width: 34px;
    height: 34px;
    flex: none;
    align-items: center;
    justify-content: center;
    margin: 0;
    padding: 0;
    color: var(--tealdoc-header-muted-color);
    border-radius: 7px;
    cursor: pointer;
    text-decoration: none;
}

.tealdoc-icon-link:hover {
    color: var(--tealdoc-header-color);
    background: var(--tealdoc-header-control-background);
}

.tealdoc-theme-input:focus-visible ~ .tealdoc-site .tealdoc-theme-toggle {
    outline: 2px solid var(--tealdoc-accent);
    outline-offset: 2px;
}

.tealdoc-icon-link svg {
    width: 18px;
    height: 18px;
}

.tealdoc-theme-icon-sun {
    display: none;
}

.tealdoc-theme-input:checked ~ .tealdoc-site .tealdoc-theme-icon-sun {
    display: block;
}

.tealdoc-theme-input:checked ~ .tealdoc-site .tealdoc-theme-icon-moon {
    display: none;
}

@media (prefers-color-scheme: dark) {
    .tealdoc-theme-icon-sun {
        display: block;
    }

    .tealdoc-theme-icon-moon {
        display: none;
    }

    .tealdoc-theme-input:checked ~ .tealdoc-site .tealdoc-theme-icon-sun {
        display: none;
    }

    .tealdoc-theme-input:checked ~ .tealdoc-site .tealdoc-theme-icon-moon {
        display: block;
    }
}

.tealdoc-search-button kbd {
    margin-left: auto;
    padding: 0.06rem 0.28rem;
    color: var(--tealdoc-header-muted-color);
    border: 1px solid var(--tealdoc-header-border);
    border-radius: 4px;
    background: transparent;
    box-shadow: none;
    font-size: 0.62rem;
}

.tealdoc-mobile-menu,
.tealdoc-mobile-outline {
    display: none;
}

.tealdoc-mobile-menu summary {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    cursor: pointer;
    list-style: none;
}

.tealdoc-mobile-menu summary::-webkit-details-marker,
.tealdoc-sidebar-section summary::-webkit-details-marker {
    display: none;
}

.tealdoc-hamburger,
.tealdoc-hamburger::before,
.tealdoc-hamburger::after {
    display: block;
    width: 18px;
    height: 2px;
    border-radius: 2px;
    background: currentColor;
}

.tealdoc-hamburger {
    position: relative;
}

.tealdoc-hamburger::before,
.tealdoc-hamburger::after {
    position: absolute;
    left: 0;
    content: "";
}

.tealdoc-hamburger::before {
    top: -6px;
}

.tealdoc-hamburger::after {
    top: 6px;
}

]]
