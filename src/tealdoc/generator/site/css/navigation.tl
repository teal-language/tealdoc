return [[
.tealdoc-shell {
    display: grid;
    width: 100%;
    max-width: var(--tealdoc-layout-max-width);
    min-height: calc(100vh - var(--tealdoc-header-height));
    grid-template-columns:
        var(--tealdoc-sidebar-width)
        minmax(0, 1fr)
        var(--tealdoc-outline-width);
    margin: 0 auto;
    transition: grid-template-columns 160ms ease;
}

.tealdoc-sidebar,
.tealdoc-outline {
    position: sticky;
    top: var(--tealdoc-header-height);
    overflow: auto;
    max-height: calc(100vh - var(--tealdoc-header-height));
}

.tealdoc-sidebar {
    padding: 1.25rem 1rem 2rem;
    border-right: 1px solid var(--tealdoc-border);
    background: var(--tealdoc-sidebar-background);
    box-shadow: -100vw 0 0 100vw var(--tealdoc-sidebar-background);
}

/* The weight is a token because the family is one: a site that puts its own
 * face here may have only the one weight, and a browser asked for a heavier
 * one it does not have synthesizes it by smearing the outlines. */
.tealdoc-outline-title {
    margin: 0 0 0.75rem;
    color: var(--tealdoc-text-muted);
    font-family: var(--tealdoc-outline-font-family);
    font-size: var(--tealdoc-outline-title-font-size);
    font-weight: var(--tealdoc-outline-title-font-weight);
}

.tealdoc-sidebar ul,
.tealdoc-outline ol {
    margin: 0;
    padding: 0;
    list-style: none;
}

.tealdoc-sidebar li {
    margin: 0;
    padding: 0;
}

.tealdoc-sidebar a {
    display: block;
    padding: var(--tealdoc-sidebar-item-padding);
    color: var(--tealdoc-sidebar-item-color);
    border-radius: 6px;
    font-family: var(--tealdoc-sidebar-font-family);
    font-size: var(--tealdoc-sidebar-font-size);
    font-weight: var(--tealdoc-sidebar-font-weight);
    line-height: 1.3;
    text-decoration: none;
}

.tealdoc-sidebar a:hover {
    color: var(--tealdoc-text);
    background: color-mix(in srgb, var(--tealdoc-accent-soft) 55%, transparent);
}

.tealdoc-sidebar a[aria-current="page"] {
    color: var(--tealdoc-accent);
    background: transparent;
    font-weight: var(--tealdoc-sidebar-active-font-weight);
}

/* The rule and the space around it divide the top level, and only the top
 * level. A nested group is already inside the one above it, indented under a
 * heading that names it, so a second divider inside that space says the same
 * thing twice and reads as a break between peers rather than a group within a
 * group. */
.tealdoc-sidebar > ul > li.tealdoc-sidebar-section {
    margin-top: var(--tealdoc-sidebar-section-gap) !important;
    padding-top: var(--tealdoc-sidebar-section-padding);
    border-top: 1px solid var(--tealdoc-sidebar-section-border);
}

/* The first section opens the sidebar, so it carries neither the rule that
 * separates one group from the last nor the space that rule needs. */
.tealdoc-sidebar > ul > li.tealdoc-sidebar-section:first-child {
    margin-top: 0 !important;
    padding-top: 0;
    border-top: 0;
}

.tealdoc-sidebar-section details {
    margin: 0;
    padding: 0;
    border: 0;
    background: transparent;
}

.tealdoc-sidebar-section summary {
    position: relative;
    margin: 0;
    padding: 0.22rem 1.2rem 0 0.55rem;
    cursor: pointer;
    font-family: var(--tealdoc-sidebar-font-family);
    font-size: var(--tealdoc-sidebar-heading-font-size);
    font-weight: var(--tealdoc-sidebar-heading-font-weight);
    list-style: none;
}

/* Pico colors an accordion summary through
 * `details[open] > summary:not([role]):not(:focus)`, and a class and an
 * element name do not outweigh that, so the theme's own color has to be
 * claimed at the same specificity or the heading is Pico's slate on every
 * site. Both states, because the closed one is out-specified too. */
.tealdoc-sidebar-section details > summary:not([role]),
.tealdoc-sidebar-section details[open] > summary:not([role]) {
    color: var(--tealdoc-sidebar-heading-color);
}

/* A group nested inside another is one row among the rows it sits with, so it
 * reads in their color. The heading color belongs to the top level, which is
 * what the rule and the space above it already divide. */
.tealdoc-sidebar-section .tealdoc-sidebar-section > details > summary:not([role]) {
    color: var(--tealdoc-sidebar-item-color);
}

.tealdoc-sidebar-section details[open] > summary {
    margin-bottom: 0;
}

.tealdoc-sidebar-section summary::after {
    position: absolute;
    top: 0.35rem;
    right: 0.35rem;
    color: var(--tealdoc-text-faint);
    width: auto;
    height: auto;
    margin: 0;
    background-image: none !important;
    content: "›";
    font-size: 1rem;
    transform: rotate(90deg);
    transition: transform 120ms ease;
}

.tealdoc-sidebar-section details:not([open]) summary::after {
    transform: rotate(0);
}

.tealdoc-sidebar-section ul {
    margin: 0;
    padding: var(--tealdoc-sidebar-nested-top-padding) 0 0
        var(--tealdoc-sidebar-nested-indent);
    border-left: 0;
}

.tealdoc-sidebar-section li a {
    padding: var(--tealdoc-sidebar-item-padding);
}

.tealdoc-outline {
    padding: 1.25rem 1.35rem 2rem 1.25rem;
}

.tealdoc-outline ol {
    position: relative;
    padding-left: 1.55rem;
    border-left: 1px solid var(--tealdoc-border);
}

.tealdoc-outline li {
    margin: 0;
    padding: 0;
}

/* A heading that does not fit wraps rather than being cut off: the outline is
 * a reader's map of the page, and half a title is not one. Two lines is the
 * limit, after which the rest is elided. */
.tealdoc-outline a {
    position: relative;
    display: -webkit-box;
    overflow: hidden;
    padding: var(--tealdoc-outline-item-padding);
    color: var(--tealdoc-text-muted);
    font-family: var(--tealdoc-outline-font-family);
    font-size: var(--tealdoc-outline-font-size);
    font-weight: var(--tealdoc-outline-font-weight);
    line-height: 1.3;
    text-decoration: none;
    text-overflow: ellipsis;
    transition: color 120ms ease;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
}

.tealdoc-outline a:hover,
.tealdoc-outline a[aria-current="location"] {
    color: var(--tealdoc-accent);
}

.tealdoc-outline a[aria-current="location"]::before {
    position: absolute;
    top: 0.08rem;
    bottom: 0.08rem;
    left: -0.91rem;
    width: 2px;
    border-radius: 2px;
    background: var(--tealdoc-accent);
    content: "";
}

.tealdoc-outline .level-3 a {
    padding-left: 0.75rem;
    color: var(--tealdoc-text-faint);
    font-size: var(--tealdoc-outline-nested-font-size);
}

.tealdoc-outline .level-3 a:hover,
.tealdoc-outline .level-3 a[aria-current="location"] {
    color: var(--tealdoc-accent);
}

]]
