return [[
.tealdoc-home-hero {
    margin: 0 0 4rem;
}

.tealdoc-hero-main {
    display: grid;
    min-height: 360px;
    align-items: center;
    gap: 3rem;
    grid-template-columns: minmax(0, 1fr);
}

.tealdoc-hero-main.has-image {
    grid-template-columns: minmax(0, 1fr) minmax(280px, 0.8fr);
}

.tealdoc-hero-copy {
    position: relative;
    z-index: 1;
}

.tealdoc-hero-copy h1 {
    max-width: 720px;
    margin: 0;
    color: var(--tealdoc-accent);
    font-size: var(--tealdoc-hero-name-size);
    letter-spacing: -0.04em;
    line-height: 0.95;
}

.tealdoc-hero-text {
    max-width: 650px;
    margin: 1.5rem 0 0;
    color: var(--tealdoc-text-muted);
    font-size: var(--tealdoc-hero-text-size);
    line-height: 1.35;
}

.tealdoc-hero-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    margin-top: 2rem;
}

.tealdoc-hero-action {
    display: inline-flex;
    min-height: 44px;
    align-items: center;
    justify-content: center;
    padding: 0.6rem 1.15rem;
    border: 1px solid transparent;
    border-radius: 22px;
    font-size: 0.9rem;
    font-weight: 650;
    text-decoration: none;
}

.tealdoc-hero-action.brand {
    color: var(--tealdoc-accent-contrast);
    background: var(--tealdoc-button-brand-background);
}

.tealdoc-hero-action.brand:hover {
    color: var(--tealdoc-accent-contrast);
    background: var(--tealdoc-button-brand-hover-background);
}

.tealdoc-hero-action.alt {
    color: var(--tealdoc-text);
    border-color: var(--tealdoc-border);
    background: var(--tealdoc-button-alt-background);
}

.tealdoc-hero-action.alt:hover {
    color: var(--tealdoc-text);
    border-color: var(--tealdoc-border);
    background: var(--tealdoc-button-alt-hover-background);
}

.tealdoc-hero-image {
    position: relative;
    display: grid;
    min-height: 340px;
    place-items: center;
    transform: translateY(-12px);
}

.tealdoc-hero-starburst {
    position: absolute;
    width: var(--tealdoc-hero-glow-size);
    aspect-ratio: 1;
    border-radius: 50%;
    background: radial-gradient(
        circle,
        color-mix(in srgb, var(--tealdoc-hero-glow-color) 38%, transparent) 0,
        color-mix(in srgb, var(--tealdoc-hero-glow-color) 20%, transparent) 34%,
        color-mix(in srgb, var(--tealdoc-hero-glow-color) 8%, transparent) 58%,
        transparent 76%
    );
    filter: blur(var(--tealdoc-hero-glow-blur));
    opacity: var(--tealdoc-hero-glow-opacity);
}

.tealdoc-hero-image img {
    position: relative;
    z-index: 1;
    width: min(100%, 390px);
    max-height: 330px;
    object-fit: contain;
}

.tealdoc-features {
    position: relative;
    z-index: 2;
    display: grid;
    margin-top: var(--tealdoc-hero-features-gap);
    gap: 1rem;
    grid-template-columns: repeat(4, minmax(0, 1fr));
}

.tealdoc-feature {
    margin: 0;
    padding: 1.4rem;
    border: 1px solid var(--tealdoc-border);
    border-radius: 12px;
    background: var(--tealdoc-background-alt);
}

.tealdoc-feature-icon,
.tealdoc-feature-image {
    display: inline-grid;
    width: 40px;
    height: 40px;
    place-items: center;
    margin-bottom: 1rem;
    border-radius: 8px;
    background: var(--tealdoc-accent-soft);
    font-size: 1.25rem;
    object-fit: contain;
}

.tealdoc-feature h2 {
    margin: 0 0 0.55rem;
    padding: 0;
    color: var(--tealdoc-text);
    border: 0;
    font-size: 1rem;
    letter-spacing: 0;
}

.tealdoc-feature-details {
    margin: 0;
    color: var(--tealdoc-text-muted);
    font-size: 0.86rem;
    line-height: 1.55;
}

.tealdoc-feature-details p {
    margin: 0;
}

]]
