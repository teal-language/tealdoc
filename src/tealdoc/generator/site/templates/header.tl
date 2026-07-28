return [[            <header class="tealdoc-header">
                <div class="tealdoc-nav">
{*block(brand, "                    ")*}
                    <button class="tealdoc-search-button" type="button" data-tealdoc-search aria-label="Search documentation">
                        <span aria-hidden="true">⌕</span>
                        <span>Search</span>
                        <kbd>⌘ K</kbd>
                    </button>
                    <nav class="tealdoc-top-nav" aria-label="Main navigation">
{*block(top_navigation, "                        ")*}
                    </nav>
{*block(header_actions, "                    ")*}
                    <details class="tealdoc-mobile-menu">
                        <summary aria-label="Open navigation">
                            <span class="tealdoc-hamburger" aria-hidden="true"></span>
                        </summary>
                        <nav class="tealdoc-mobile-top-nav">
{*block(top_navigation, "                            ")*}
                        </nav>
                        <ul>
{*block(sidebar_links, "                            ")*}
                        </ul>
                    </details>
                </div>
            </header>
]]
