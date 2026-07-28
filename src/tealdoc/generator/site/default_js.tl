return [[
(() => {
    "use strict";

    const searchDialog = document.querySelector(".tealdoc-search-dialog");
    const searchInput = searchDialog?.querySelector("input");
    const searchResults = searchDialog?.querySelector(".tealdoc-search-results");
    const searchButtons = document.querySelectorAll("[data-tealdoc-search]");
    const maxSearchResults = 50;
    let searchIndex = Array.isArray(window.TEALDOC_SEARCH_INDEX)
        ? window.TEALDOC_SEARCH_INDEX
        : null;
    let searchIndexPromise = null;
    const outlineLinks = Array.from(document.querySelectorAll(
        '.tealdoc-outline a[href^="#"], .tealdoc-mobile-outline a[href^="#"]'
    ));

    const openSearch = () => {
        if (!searchDialog) return;
        if (typeof searchDialog.showModal === "function") {
            searchDialog.showModal();
        } else {
            searchDialog.setAttribute("open", "");
        }
        searchInput.value = "";
        renderSearch("");
        loadSearchIndex().catch(() => {});
        requestAnimationFrame(() => searchInput.focus());
    };

    const closeSearch = () => {
        if (!searchDialog) return;
        if (typeof searchDialog.close === "function") {
            searchDialog.close();
        } else {
            searchDialog.removeAttribute("open");
        }
    };

    const scoreEntry = (entry, terms) => {
        const title = entry.title.toLowerCase();
        const text = entry.text.toLowerCase();
        let score = 0;
        for (const term of terms) {
            if (!title.includes(term) && !text.includes(term)) return -1;
            if (title === term) score += 100;
            else if (title.startsWith(term)) score += 40;
            else if (title.includes(term)) score += 20;
            else score += 2;
        }
        return score;
    };

    const loadSearchIndex = () => {
        if (searchIndex) return Promise.resolve(searchIndex);
        if (searchIndexPromise) return searchIndexPromise;
        const source = searchDialog?.dataset.tealdocSearchIndex;
        if (!source) {
            return Promise.reject(new Error("Search index URL is missing."));
        }
        searchIndexPromise = new Promise((resolve, reject) => {
            const script = document.createElement("script");
            script.src = source;
            script.async = true;
            script.addEventListener("load", () => {
                script.remove();
                if (!Array.isArray(window.TEALDOC_SEARCH_INDEX)) {
                    reject(new Error("Search index did not define an array."));
                    return;
                }
                searchIndex = window.TEALDOC_SEARCH_INDEX;
                resolve(searchIndex);
            });
            script.addEventListener("error", () => {
                script.remove();
                reject(new Error(`Could not load search index from ${source}.`));
            });
            document.head.append(script);
        }).catch((error) => {
            searchIndexPromise = null;
            throw error;
        });
        return searchIndexPromise;
    };

    const renderSearch = async (query) => {
        if (!searchResults) return;
        searchResults.replaceChildren();
        const terms = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
        if (!terms.length) {
            const hint = document.createElement("p");
            hint.className = "tealdoc-search-empty";
            hint.textContent = "Search pages, headings, functions, and types.";
            searchResults.append(hint);
            return;
        }

        const loading = document.createElement("p");
        loading.className = "tealdoc-search-empty";
        loading.textContent = "Loading search index…";
        searchResults.append(loading);
        let entries;
        try {
            entries = await loadSearchIndex();
        } catch {
            if (searchInput?.value !== query) return;
            loading.textContent = "Search index could not be loaded.";
            return;
        }
        if (searchInput?.value !== query) return;
        searchResults.replaceChildren();

        const matches = entries
            .map((entry) => ({ entry, score: scoreEntry(entry, terms) }))
            .filter((match) => match.score >= 0)
            .sort((a, b) => b.score - a.score || a.entry.title.localeCompare(b.entry.title))
            .slice(0, maxSearchResults);

        if (!matches.length) {
            const empty = document.createElement("p");
            empty.className = "tealdoc-search-empty";
            empty.textContent = `No results for “${query}”.`;
            searchResults.append(empty);
            return;
        }

        for (const { entry } of matches) {
            const link = document.createElement("a");
            link.href = entry.url;
            const title = document.createElement("strong");
            title.textContent = entry.title;
            const path = document.createElement("small");
            path.textContent = entry.url;
            link.append(title, path);
            searchResults.append(link);
        }
    };

    searchButtons.forEach((button) => button.addEventListener("click", openSearch));
    searchInput?.addEventListener("input", () => renderSearch(searchInput.value));
    searchDialog?.querySelector("[data-tealdoc-search-close]")
        ?.addEventListener("click", closeSearch);
    searchDialog?.addEventListener("click", (event) => {
        if (event.target === searchDialog) closeSearch();
    });

    document.addEventListener("keydown", (event) => {
        if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
            event.preventDefault();
            openSearch();
        }
    });

    if (outlineLinks.length) {
        const linksById = new Map();
        for (const link of outlineLinks) {
            const id = decodeURIComponent(link.hash.slice(1));
            const links = linksById.get(id) || [];
            links.push(link);
            linksById.set(id, links);
        }
        const headings = Array.from(linksById.keys())
            .map((id) => document.getElementById(id))
            .filter(Boolean);
        let currentId = "";
        let updatePending = false;

        const updateOutline = () => {
            updatePending = false;
            const header = document.querySelector(".tealdoc-header");
            const readingLine = (header?.getBoundingClientRect().bottom || 0) + 24;
            let current = null;
            for (const heading of headings) {
                const top = heading.getBoundingClientRect().top;
                if (top <= readingLine) {
                    current = heading;
                } else {
                    if (!current && top < window.innerHeight) current = heading;
                    break;
                }
            }
            if (!current || current.id === currentId) return;
            currentId = current.id;
            for (const link of outlineLinks) {
                link.removeAttribute("aria-current");
            }
            for (const link of linksById.get(currentId) || []) {
                link.setAttribute("aria-current", "location");
            }
        };

        const scheduleOutlineUpdate = () => {
            if (updatePending) return;
            updatePending = true;
            requestAnimationFrame(updateOutline);
        };

        window.addEventListener("scroll", scheduleOutlineUpdate, { passive: true });
        window.addEventListener("resize", scheduleOutlineUpdate);
        window.addEventListener("hashchange", scheduleOutlineUpdate);
        updateOutline();
    }
})();
]]
