return [[
    * {
        box-sizing: border-box;
    }
    html, body {
        height: 100%;
        margin: 0;
        padding: 0;
    }
    body {
        font-family: Arial, sans-serif;
        line-height: 1.6;
        /* fixes safari resizing some parts of the page */
        -moz-text-size-adjust: none;
        -webkit-text-size-adjust: none;
        text-size-adjust: none;
    }
    h1, h2, h3, h4, h5, h6 {
        color: #111;
    }
    code {
        background-color: #f4f4f4;
        padding: 0.2em 0.4em;
        border-radius: 4px;
    }
    ul, ol {
        margin: 1em 0;
    }
    li {
        margin: 0.5em 0;
    }
    a {
        color: #007bff;
        text-decoration: none;
    }
    a:hover {
        text-decoration: underline;
    }
    pre code {
        display: block;
        width: 100%;
        background-color: #d0f0f0;
        padding: 1em;
        overflow-x: auto;
    }

    summary {
        list-style: none; /* remove default triangle */
        position: relative;
        cursor: pointer;
    }

    details > summary::after {
        position: absolute;
        content: "❯";
        transform-origin: center;
        margin-left: 0.5em;
    }
    details[open] > summary::after {
        transform: rotate(90deg);
    }

    /* Breadcrumb navigation styles */
    main > nav ul {
        list-style: none;
        padding: 0;
        margin: 0;
    }
    main > nav ul li {
        display: inline;
    }
    main > nav ul li a {
        text-decoration: none;
    }
    main > nav ul li a:hover {
        text-decoration: underline;
    }

    ul.tree-list {
        list-style: outside ;
        line-height: 1.5rem;
        padding-left: 1.5em;
        margin: 0;
    }

    .tree-list li {
        margin: 0;
    }

    main {
        max-width: 800px;
        width: 100%;
        margin: 1em auto;
        padding: 0 10px;
    }
    footer {
        width: 100%;
        text-align: center;
        padding: 10px 0;
    }
]]
