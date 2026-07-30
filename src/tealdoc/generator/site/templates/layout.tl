return [[<!DOCTYPE html>
<html lang="{*language*}">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{*title*}</title>
        <meta name="description" content="{*description*}">
{*block(head, "        ")*}
        <script>
            try {
                const theme = window.localStorage.getItem("tealdoc-theme");
                if (theme === "light" || theme === "dark") {
                    document.documentElement.dataset.tealdocTheme = theme;
                }
            } catch {}
        </script>
        <link rel="stylesheet" href="{*pico_stylesheet_url*}">
        <link rel="stylesheet" href="{*stylesheet_url*}">
        <script src="{*script_url*}" defer></script>
    </head>
    <body>
        <input class="tealdoc-theme-input" id="tealdoc-theme-input" type="checkbox" aria-label="Use alternate color theme">
        <div class="tealdoc-site">
{(header.html)}
            <div class="{*shell_class*}">
{*block(sidebar, "                ")*}
{[content_template]}
{*block(outline, "                ")*}
            </div>
{*block(search_dialog, "            ")*}
{(footer.html)}
        </div>
    </body>
</html>
]]
