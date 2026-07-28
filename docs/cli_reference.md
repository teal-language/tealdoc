## CLI Reference

To use the Tealdoc command-line interface:

```
tealdoc <command> [options]
```

You can view all available commands and options with:

```
tealdoc --help
```

### Commands
*   `md`: Generate documentation as a Markdown file.
*   `html`: Generate documentation as an HTML file.
*   `dump`: Print the internal documentation registry to the console for debugging.

### Options
*   `--output <file>`: Specifies the output file for the generated documentation.
*   `--all`: Includes local definitions in the output.
*   `--plugin <plugins>`: Plugins to load; plugin names are resolved the same way as lua requires.
*   `--no-warn-missing`: Suppresses warnings about missing documentation for items.
*   `--type-links <file>`: For Markdown output, links named types with routes from a map file.

A type-link map contains a canonical Tealdoc path and URL prefix on each line:

```
my.http /modules/http#my.http
my.Future /modules/future#my.future.Future
```

The exact path links to the page before `#`. A descendant appends its suffix
to the complete URL prefix, so `my.http.Response` above links to
`/modules/http#my.http.Response`. Blank lines and lines starting with `#` are
ignored. Types with no route remain plain code.
