return [[
.tealdoc-search-dialog {
    width: min(94vw, 680px);
    max-width: none;
    padding: 0;
    border: 1px solid var(--tealdoc-border);
    border-radius: 12px;
    background: var(--tealdoc-background-elv);
    box-shadow: 0 24px 80px rgb(0 0 0 / 28%);
}

.tealdoc-search-dialog::backdrop {
    background: rgb(0 0 0 / 46%);
    backdrop-filter: blur(3px);
}

.tealdoc-search-panel {
    margin: 0;
    padding: 0;
}

.tealdoc-search-panel > header {
    display: flex;
    align-items: center;
    gap: 0.65rem;
    margin: 0;
    padding: 0.8rem;
    border-bottom: 1px solid var(--tealdoc-border);
    background: transparent;
}

.tealdoc-search-panel label {
    display: flex;
    flex: 1;
    align-items: center;
    gap: 0.5rem;
    margin: 0;
}

.tealdoc-search-panel input {
    height: 42px;
    margin: 0;
    padding: 0 0.75rem;
    border: 1px solid var(--tealdoc-accent);
    border-radius: 7px;
    background: var(--tealdoc-background);
    box-shadow: 0 0 0 3px var(--tealdoc-accent-soft);
}

.tealdoc-search-panel [data-tealdoc-search-close] {
    width: auto;
    margin: 0;
    padding: 0.32rem 0.5rem;
    color: var(--tealdoc-text-muted);
    border: 1px solid var(--tealdoc-border);
    border-radius: 5px;
    background: var(--tealdoc-background-alt);
    box-shadow: none;
    font-size: 0.72rem;
}

.tealdoc-search-results {
    display: grid;
    overflow: auto;
    max-height: min(60vh, 520px);
    gap: 0.35rem;
    padding: 0.65rem;
}

.tealdoc-search-results a {
    display: grid;
    gap: 0.15rem;
    padding: 0.7rem 0.8rem;
    color: var(--tealdoc-text);
    border: 1px solid transparent;
    border-radius: 7px;
    text-decoration: none;
}

.tealdoc-search-results a:hover,
.tealdoc-search-results a:focus {
    border-color: var(--tealdoc-border);
    background: var(--tealdoc-accent-soft);
}

.tealdoc-search-results strong {
    font-size: 0.9rem;
}

.tealdoc-search-results small {
    overflow: hidden;
    color: var(--tealdoc-text-faint);
    font-size: 0.72rem;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.tealdoc-search-empty {
    margin: 0;
    padding: 1.5rem;
    color: var(--tealdoc-text-muted);
    text-align: center;
}

.tealdoc-footer {
    margin: 0;
    padding: 0;
    color: var(--tealdoc-footer-text);
    border-top: 1px solid var(--tealdoc-footer-border);
    background: var(--tealdoc-footer-background);
    font-size: 0.72rem;
}

.tealdoc-footer-inner {
    position: relative;
    display: flex;
    width: 100%;
    max-width: var(--tealdoc-layout-max-width);
    flex-direction: column;
    align-items: center;
    gap: 0.35rem;
    margin: 0 auto;
    padding: 1rem 1.5rem 1rem calc(var(--tealdoc-sidebar-width) + 1.5rem);
    text-align: center;
}

/* A group is a row, and wraps within itself when it has to. The column above
 * puts one group under the last, which is the break a reader expects. */
.tealdoc-footer-group {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 0.35rem 0.75rem;
}

/* What built the page is the smallest claim in here, and reads as a footnote
 * under the two rows that are about the work itself. */
.tealdoc-footer-meta {
    color: var(--tealdoc-text-faint);
    font-size: 0.92em;
}

.tealdoc-footer-inner::before {
    position: absolute;
    top: 0;
    bottom: 0;
    left: var(--tealdoc-sidebar-width);
    width: 1px;
    background: var(--tealdoc-border);
    content: "";
}

.tealdoc-home-footer .tealdoc-footer-inner {
    padding-inline: 1.5rem;
}

.tealdoc-home-footer .tealdoc-footer-inner::before {
    content: none;
}

.tealdoc-footer a {
    color: var(--tealdoc-footer-link);
    text-decoration: none;
}

.tealdoc-footer a:hover {
    color: var(--tealdoc-accent);
}

]]
