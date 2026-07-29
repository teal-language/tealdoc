return [[
.tealdoc-content {
    width: min(
        100% - calc(2 * var(--tealdoc-content-gutter)),
        var(--tealdoc-content-width)
    );
    margin: 0 auto;
    padding: var(--tealdoc-content-padding-top) 0
        var(--tealdoc-content-padding-bottom);
    border-radius: 0;
}

.tealdoc-content {
    font-size: var(--tealdoc-content-font-size);
}

.tealdoc-breadcrumbs {
    margin: 0 0 0.75rem;
}

.tealdoc-breadcrumbs ol {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0;
    margin: 0;
    padding: 0;
    list-style: none;
}

.tealdoc-breadcrumbs li {
    display: inline-flex;
    align-items: center;
    margin: 0;
    color: var(--tealdoc-text-faint);
    font-size: 0.82rem;
    line-height: 1.2;
}

.tealdoc-breadcrumbs li + li::before {
    margin: 0 0.45rem;
    color: var(--tealdoc-border);
    content: "/";
}

.tealdoc-breadcrumbs a {
    color: var(--tealdoc-text-faint);
    text-decoration-color: currentColor;
    text-decoration-line: underline !important;
    text-decoration-thickness: 1px;
    text-underline-offset: 0.16em;
}

.tealdoc-breadcrumbs a:hover {
    color: var(--tealdoc-accent-hover);
    text-decoration-line: underline !important;
}

.tealdoc-breadcrumbs [aria-current="page"] {
    color: var(--tealdoc-text-muted);
}

.tealdoc-content h1 {
    margin-top: 0;
    letter-spacing: -0.025em;
}

.tealdoc-content h1,
.tealdoc-content h2,
.tealdoc-content h3,
.tealdoc-content h4,
.tealdoc-content h5,
.tealdoc-content h6,
.tealdoc-hero-copy h1,
.tealdoc-feature h2 {
    font-family: var(--tealdoc-font-heading);
    font-weight: var(--tealdoc-heading-font-weight);
}

.tealdoc-content h1 {
    font-size: var(--tealdoc-heading-1-size);
}

.tealdoc-content h2 {
    font-size: var(--tealdoc-heading-2-size);
}

.tealdoc-content h3 {
    font-size: var(--tealdoc-heading-3-size);
}

.tealdoc-content h4 {
    font-size: var(--tealdoc-heading-4-size);
}

.tealdoc-content h5 {
    font-size: var(--tealdoc-heading-5-size);
}

.tealdoc-content h6 {
    font-size: var(--tealdoc-heading-6-size);
}

.tealdoc-content h2 {
    margin-top: var(--tealdoc-heading-2-spacing);
    padding-top: var(--tealdoc-heading-2-spacing);
    border-top: 1px solid var(--tealdoc-border);
    letter-spacing: -0.015em;
}

.tealdoc-content h3 {
    margin-top: var(--tealdoc-heading-3-spacing);
}

.tealdoc-kind-badge {
    display: inline-flex;
    align-items: center;
    margin-left: 0.45rem;
    padding: 0.12rem 0.42rem;
    color: var(--tealdoc-text-muted);
    border: 1px solid var(--tealdoc-border);
    border-radius: 999px;
    background: var(--tealdoc-background-alt);
    font-family: var(--tealdoc-font);
    font-size: 0.62rem;
    font-weight: 650;
    letter-spacing: 0.035em;
    line-height: 1.2;
    text-transform: uppercase;
    transform: translateY(-0.08em);
    vertical-align: middle;
}

.tealdoc-kind-function,
.tealdoc-kind-method,
.tealdoc-kind-metamethod,
.tealdoc-kind-macro {
    color: var(--tealdoc-accent);
    border-color: color-mix(
        in srgb,
        var(--tealdoc-accent) 35%,
        var(--tealdoc-border)
    );
    background: var(--tealdoc-accent-soft);
}

.tealdoc-header-anchor {
    margin-left: 0.4rem;
    color: var(--tealdoc-accent);
    opacity: 0;
    font-weight: 500;
    text-decoration: none;
    transition: opacity 120ms ease;
}

.tealdoc-content h1:hover .tealdoc-header-anchor,
.tealdoc-content h2:hover .tealdoc-header-anchor,
.tealdoc-content h3:hover .tealdoc-header-anchor,
.tealdoc-content h4:hover .tealdoc-header-anchor,
.tealdoc-header-anchor:focus {
    opacity: 1;
}

/* The wrapper exists to hold the language label still. The `pre` inside it is
 * the horizontal scroll container, and anything positioned against a scroll
 * container travels with its content. */
.tealdoc-content .tealdoc-code-block {
    position: relative;
}

/* The label is a pseudo-element's content rather than an element of its own,
 * so it is neither in the text a reader copies out of the block nor in what
 * the search index reads. */
.tealdoc-content .tealdoc-code-block[data-lang]::before {
    position: absolute;
    z-index: 1;
    top: var(--tealdoc-code-lang-top);
    right: var(--tealdoc-code-lang-right);
    padding: var(--tealdoc-code-lang-padding);
    background: var(--tealdoc-code-background);
    color: var(--tealdoc-code-lang-color);
    content: attr(data-lang);
    font-family: var(--tealdoc-font-mono);
    font-size: var(--tealdoc-code-lang-font-size);
    line-height: 1;
    pointer-events: none;
    user-select: none;
}


.tealdoc-content pre {
    overflow: auto;
    padding: var(--tealdoc-code-block-padding);
    border: 1px solid var(--tealdoc-border);
    border-radius: var(--tealdoc-code-block-radius);
    background: var(--tealdoc-code-background);
    font-family: var(--tealdoc-font-mono);
    line-height: 1.55;
}

/* The block's padding is the pre's, once. Pico pads the inner code as well,
 * which doubles it and leaves the two halves impossible to tune apart. */
.tealdoc-content pre > code {
    padding: 0;
}

.tealdoc-content code[class*="language-"] {
    color: var(--tealdoc-syntax-foreground);
    background: transparent;
    font-family: var(--tealdoc-font-mono);
    font-size: var(--tealdoc-code-block-font-size);
    text-shadow: none;
}

.tealdoc-content :not(pre) > code {
    padding: var(--tealdoc-inline-code-padding);
    border-radius: var(--tealdoc-inline-code-radius);
    background: var(--tealdoc-inline-code-background);
    font-size: var(--tealdoc-inline-code-font-size);
    font-weight: 550;
}

.tealdoc-content :is(h1, h2, h3, h4, h5, h6) code {
    padding: 0;
    background: transparent;
    font-size: 1em;
    font-weight: inherit;
}

.tealdoc-content a > code {
    color: var(--tealdoc-link);
}

.tealdoc-content a:hover > code {
    color: var(--tealdoc-link-hover);
}

.token.comment,
.tealdoc-token-comment {
    color: var(--tealdoc-syntax-comment);
    font-style: italic;
}

.token.boolean,
.tealdoc-token-boolean {
    color: var(--tealdoc-syntax-boolean);
}

.token.keyword,
.tealdoc-token-keyword {
    color: var(--tealdoc-syntax-keyword);
}

.token.directive,
.tealdoc-token-meta {
    color: var(--tealdoc-syntax-meta);
}

.token.number,
.tealdoc-token-number {
    color: var(--tealdoc-syntax-number);
}

.token.function,
.tealdoc-token-function {
    color: var(--tealdoc-syntax-function);
}

.token.operator,
.tealdoc-token-operator {
    color: var(--tealdoc-syntax-operator);
}

.token.property,
.tealdoc-token-property {
    color: var(--tealdoc-syntax-property);
}

.token.punctuation,
.tealdoc-token-punctuation {
    color: var(--tealdoc-syntax-punctuation);
}

.token.string,
.tealdoc-token-string {
    color: var(--tealdoc-syntax-string);
}

.token.class-name,
.tealdoc-token-type {
    color: var(--tealdoc-syntax-type);
}

.token.variable,
.tealdoc-token-variable {
    color: var(--tealdoc-syntax-variable);
}

.tealdoc-code-link {
    color: var(--tealdoc-link);
    border-bottom: 1px dotted currentColor;
    text-decoration: none;
    text-underline-offset: 0.18em;
}

.tealdoc-code-link .tealdoc-token-type {
    color: inherit;
}

.tealdoc-code-link:hover {
    color: var(--tealdoc-link-hover);
    border-bottom-style: solid;
}

.tealdoc-content table {
    display: block;
    overflow-x: auto;
    width: 100%;
}

.tealdoc-content th,
.tealdoc-content td {
    padding: 0.4em 0.9em 0.4em 0;
    vertical-align: top;
}

.tealdoc-content thead th {
    color: var(--tealdoc-text-muted);
    font-size: 0.82em;
    letter-spacing: 0.04em;
    text-transform: uppercase;
}

/* A parameter row is as tall as its description, and the name and the type it
   belongs to have to stay beside the first line of that description rather
   than float in the middle of it. Every column but the last holds one of those
   short values, so it keeps to one line and lets the description take the
   width that is left. */
.tealdoc-content td:not(:last-child) {
    white-space: nowrap;
}

]]
