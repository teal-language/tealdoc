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
.tealdoc-code-group {
    display: block;
    overflow: hidden;
    margin: 1.25rem 0;
    border: 1px solid var(--tealdoc-border);
    border-radius: var(--tealdoc-code-block-radius);
    background: var(--tealdoc-code-background);
    box-shadow: none;
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
