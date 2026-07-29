return [[
.tealdoc-admonition {
    margin: 1.25rem 0;
    padding: 0.9rem 1rem;
    border: 1px solid var(--tealdoc-border);
    border-left: 4px solid var(--tealdoc-admonition-color);
    border-radius: 8px;
    background: color-mix(
        in srgb,
        var(--tealdoc-admonition-color) 8%,
        var(--tealdoc-background)
    );
}

.tealdoc-admonition-note {
    --tealdoc-admonition-color: var(--tealdoc-admonition-note);
}

.tealdoc-admonition-tip {
    --tealdoc-admonition-color: var(--tealdoc-admonition-tip);
}

.tealdoc-admonition-important {
    --tealdoc-admonition-color: var(--tealdoc-admonition-important);
}

.tealdoc-admonition-warning {
    --tealdoc-admonition-color: var(--tealdoc-admonition-warning);
}

.tealdoc-admonition-danger {
    --tealdoc-admonition-color: var(--tealdoc-admonition-danger);
}

.tealdoc-admonition-title {
    margin: 0 0 0.35rem;
    color: var(--tealdoc-admonition-color);
    font-size: 0.82rem;
    font-weight: 700;
    letter-spacing: 0.02em;
}

.tealdoc-admonition > :last-child {
    margin-bottom: 0;
}

.tealdoc-details {
    margin: 1.25rem 0;
    border: 1px solid var(--tealdoc-border);
    background: var(--tealdoc-background-alt);
}

.tealdoc-details > summary {
    padding: 0.7rem 0.9rem;
    color: var(--tealdoc-text);
    font-weight: 600;
    cursor: pointer;
}

.tealdoc-details-content {
    padding: 0 0.9rem 0.8rem;
}

.tealdoc-details-content > :last-child {
    margin-bottom: 0;
}

/* Pico lays a [role="group"] out as an inline flex row, which is right for a
 * button group and wrong for a stack of labelled code blocks, so the display
 * is stated here rather than left to the classless sheet. */
/* One flex container holding input, label and panel triples in that order.
 * The labels are pulled to the first row, so the strip forms itself without
 * being an element of its own, and the panels are full width so each starts a
 * line. Interleaving is what lets one adjacent-sibling rule do everything. */
.tealdoc-code-group {
    position: relative;
    display: flex;
    overflow: hidden;
    flex-wrap: wrap;
    margin: 1.25rem 0;
    border: 1px solid var(--tealdoc-border);
    border-radius: var(--tealdoc-code-block-radius);
    background: var(--tealdoc-code-background);
    box-shadow: none;
}

/* A real radio, kept off the page but not out of it: the arrow keys, the
 * single tab stop and the exclusivity are the browser's.
 *
 * `appearance` has to be said here. Pico turns it off for most controls but
 * exempts radios, so a radio keeps drawing its native dot, and a native
 * control paints at its own size whatever box it is given: in Safari the dot
 * appeared next to every tab. Taking it out of flow rather than shrinking it
 * to a pixel also keeps it from perturbing the strip it sits in, and costs
 * nothing, because a sibling selector reads the document and not the layout. */
.tealdoc-code-tab-input {
    position: absolute;
    width: 1px;
    height: 1px;
    margin: 0;
    padding: 0;
    border: 0;
    opacity: 0;
    appearance: none;
    clip-path: inset(50%);
    pointer-events: none;
    -webkit-appearance: none;
}

.tealdoc-code-tab {
    order: -1;
    padding: var(--tealdoc-code-tab-padding);
    border-bottom: 2px solid transparent;
    color: var(--tealdoc-code-tab-text);
    cursor: pointer;
    font-family: var(--tealdoc-font);
    font-size: var(--tealdoc-code-tab-font-size);
    font-weight: var(--tealdoc-code-tab-font-weight);
}

.tealdoc-code-tab:hover {
    color: var(--tealdoc-code-tab-hover-text);
}

.tealdoc-code-panel {
    display: none;
    width: 100%;
    margin: 0;
    border-top: 1px solid var(--tealdoc-code-tab-divider);
}

/* The whole mechanism. */
.tealdoc-code-tab-input:checked + .tealdoc-code-tab + .tealdoc-code-panel {
    display: block;
}

.tealdoc-code-tab-input:checked + .tealdoc-code-tab {
    border-bottom-color: var(--tealdoc-code-tab-active-bar);
    color: var(--tealdoc-code-tab-active-text);
}

.tealdoc-code-tab-input:focus-visible + .tealdoc-code-tab {
    outline: 2px solid var(--tealdoc-accent);
    outline-offset: -2px;
}

.tealdoc-code-group > .tealdoc-code-panel pre {
    border: 0;
    border-radius: 0;
}

/* Paper has no tabs, so it gets all of them. */
@media print {
    .tealdoc-code-panel {
        display: block;
    }
}

.tealdoc-labeled-code {
    margin: 1.25rem 0;
}

.tealdoc-code-group > .tealdoc-labeled-code {
    margin: 0;
}

.tealdoc-code-group > .tealdoc-labeled-code + .tealdoc-labeled-code {
    border-top: 1px solid var(--tealdoc-border);
}

.tealdoc-labeled-code figcaption {
    padding: 0.45rem 0.6rem;
    color: var(--tealdoc-text-muted);
    font-family: var(--tealdoc-font);
    font-size: 0.72rem;
    font-weight: 600;
}

.tealdoc-labeled-code pre[class*="language-"] {
    margin: 0;
    border-right: 0;
    border-bottom: 0;
    border-left: 0;
}

.tealdoc-code-group > .tealdoc-labeled-code pre {
    border: 0;
    border-radius: 0;
}

.tealdoc-page-nav {
    display: grid;
    margin-top: 4rem;
    padding-top: 1.5rem;
    border-top: 1px solid var(--tealdoc-border);
    gap: 0.75rem;
    grid-template-columns: repeat(2, minmax(0, 1fr));
}

.tealdoc-page-nav a {
    display: grid;
    min-height: 84px;
    align-content: center;
    gap: 0.25rem;
    padding: 0.85rem 1rem;
    color: var(--tealdoc-text);
    border: 1px solid var(--tealdoc-border);
    border-radius: 9px;
    text-decoration: none;
    transition:
        border-color 120ms ease,
        background 120ms ease;
}

.tealdoc-page-nav a:hover {
    border-color: var(--tealdoc-accent);
    background: var(--tealdoc-accent-soft);
}

.tealdoc-page-nav a.next {
    text-align: right;
}

.tealdoc-page-nav span {
    color: var(--tealdoc-text-faint);
    font-size: 0.72rem;
}

.tealdoc-page-nav strong {
    color: var(--tealdoc-accent);
    font-size: 0.9rem;
}

.tealdoc-home-shell {
    display: block;
}

.tealdoc-home-content {
    width: calc(100% - (2 * var(--tealdoc-home-gutter)));
    max-width: var(--tealdoc-home-width);
    padding-top: 4rem;
}

]]
