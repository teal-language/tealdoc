# Tealdoc

> [!WARNING]
> Tealdoc is currently in alpha. Expect bugs, missing functionality, and breaking changes.
>
> As of now, only Markdown output is implemented.

A documentation generator written in [Teal](github.com/teal-language/tl/tree/master).

Its primary function is to generate documentation for programs written in Teal, but it is extensible enough to support other languages.

## Table of Contents

- [Installation](#installation)
- [How to Document Your Code](#how-to-document-your-code)
    - [Tealdoc Comments](#tealdoc-comments)
    - [Anatomy of a Comment](#anatomy-of-a-comment)
    - [Functions](#functions)
    - [Records and Interfaces](#records-and-interfaces)
    - [Enums](#enums)
    - [Variables and Types](#variables-and-types)
    - [Controlling Visibility](#controlling-visibility)
- [CLI Reference](#cli-reference)
    - [Commands](#commands)
    - [Options](#options)
- [Architecture](#architecture)
    - [Using Tealdoc Programmatically](#using-tealdoc-programmatically)
    - [Adding Custom Tags](#adding-custom-tags)
    - [Plugins](#plugins)
- [API Reference](#api-reference)
- [About](#about)

## Installation

Tealdoc can be installed using [Luarocks](https://luarocks.org/):

```
luarocks install --server=https://luarocks.org/dev tealdoc
```

## How to Document Your Code

### Tealdoc Comments

Documentation can be written in special comments that begin with three hyphens (`---`).

```teal
--- This is a Tealdoc summary line.
--- The rest of the comment forms the detailed description.
--- It can span multiple lines.

---
-- This is also a valid Tealdoc comment.
```

You can also use a block comment.

```teal
--[[--
    This is a Tealdoc block comment.
    ...
]]--
```

### Anatomy of a Comment

All documentation comments start with a brief summary sentence that ends with a period. The text that follows the summary becomes the detailed description.

After the description, you can add tags, which start with an `@`. Tags may optionally include a parameter and a description.

```teal
--- This is the summary. This is the detailed description.
-- @tag_name parameter The description for this tag.
-- @another_tag
```

### Functions

Document functions by placing a Tealdoc comment directly above them. Parameter and return types are inferred automatically from the function's type annotations.

```teal
--- Adds two integers.
-- This function adds two integers together.
-- @param a The first integer to add.
-- @param b The second integer to add.
-- @return The sum of the two integers.
function test.foo(a: integer, b: integer): integer
    return a + b
end
```

You can use multiple `@return` tags to document functions with multiple return values:

```teal
--- Fetches messages from the server.
-- @return A table of messages if successful.
-- @return An error message on failure.
function client.fetch_messages(): {Message}, string
    ...
end
```

Use the `@typearg` tag to document generic type variables:

```teal
--[[--
    Calculates the area of a shape.
    @typearg S The type of the shape, which must implement `Shape`.
    @param shape The shape object.
    @return The area of the shape.
]]
local function area<S is Shape>(shape: S): number
    ...
end
```

### Records and Interfaces

You can document records, interfaces, and all of their fields and nested types.

```teal
--- An abstract representation of a shape.
interface Shape
    --- The result type of any geometric calculation.
    --- Either a `double` value or an error string.
    type calculation_result = double | string

    --- The number of sides.
    sides: integer
end

--- A square shape.
record Square is Shape
    --- The length of the square's side in cm.
    side_length: double

    --- Calculates the square's diagonal.
    --- @return The diagonal length in cm.
    get_diagonal: function(shape): calculation_result
end
```

Functions can also be documented where they are defined, if outside the initial record definition:

```teal
--- Multiplies the length of all sides of the square.
-- @param x The factor to multiply by.
function Square:multiply_sides(x: number)
    ...
end
```

**Note:** If a function has documentation at both its declaration (inside the record) and its definition, the definition's documentation will be prioritized, and a warning will be emitted.

### Enums

Enum types and their values can be documented:

```teal
--- Classifies a triangle by its side lengths.
enum TriangleType
    --- All sides are equal.
    "equilateral"
    --- Two sides are equal.
    "isosceles"
    --- No sides are equal.
    "scalene"
end
```

### Variables and Types

You can also document variables and type declarations:

```teal
--- The mathematical constant PI, rounded to two decimal places.
global PI = 3.14

--- A type alias for a numeric value.
local type Numeric = number | integer
```

### Controlling Visibility

By default, Tealdoc includes all of the module's contents and all global functions in the generated documentation.

*   To **exclude** an item, add the `@local` tag to its documentation comment.
*   To **include** local items that would normally be excluded, use the `--all` command-line flag or set `env.include_all = true` when using the API.

If there are multiple conflicting declarations (e.g., two global functions with the same name), the last one processed is chosen, and a warning is emitted if a Tealdoc comment from a previous declaration is ignored as a result.

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
*   `dump`: Print the internal documentation registry to the console for debugging.

### Options
*   `--output <file>`: Specifies the output file for the generated documentation.
*   `--all`: Includes local definitions in the output.
*   `--plugin <plugins>`: Plugins to load; plugin names are resolved the same way as lua requires.
*   `--no-warn-missing`: Suppresses warnings about missing documentation for items.

## Architecture

Tealdoc features a flexible, input-language-agnostic architecture.

*   **Registry**: The central piece is the `registry`, which stores all discovered documentation `items`.
*   **Item**: An `item` is a piece of data in the registry representing a code entity (like a function or record) or an abstract concept. Each item has a unique path and can contain child items.
*   **Parser**: The input layer that processes source files and populates the registry with items.
*   **Consumers**: Built-in consumers (like the Markdown generator) that process the registry to create output.

This design allows you to extend Tealdoc with custom tags, parsers for other languages, or new output generators.

### Using Tealdoc Programmatically

You can use the Tealdoc API to process files and access the registry directly.

```teal
local tealdoc = require("tealdoc")
local DefaultEnv = require("tealdoc.default_env")

-- Create a default environment, which registers all built-in
-- parsers, tags, and generator phases.
local env = DefaultEnv.create()

-- You can configure the environment programmatically
-- env.include_all = true

tealdoc.process_file("hello.tl", env)

for path, item in env.registry:each() do
    print(path, item.name)
end
```

### Adding Custom Tags

You can extend Tealdoc with your own tags by creating a custom tag handler.

```
local my_tag_handler: tealdoc.TagHandler = {
    name = "my_tag",
    with_param = true,
    with_description = true,
    handle = function(ctx: tealdoc.TagHandler.Context)
        -- `ctx` contains the item, param, description, etc.
        print("Parameter:", ctx.param)
        print("Description:", ctx.description)
        ctx.item.attributes["my_attribute"] = "hello world!"
    end,
}

-- Then register it with the environment:
-- env.tag_handlers:add(my_tag_handler)
```

### Plugins

You can easily extend Tealdoc with plugins. A plugin is a Lua module that implements the `tealdoc.Plugin` interface. These can be loaded via the command line, using the `--plugin` option, or programmatically.

```
local MyPlugin: tealdoc.Plugin = {
    name = "my_plugin",
    
    run = function(env: tealdoc.Env)
        --- This function is called when the plugin is loaded.
        --- You can access the environment and modify it.
        --- For example, you can add custom tags or parsers.
    end,
}

--- Note that the plugins loaded via the command line must behave like Lua modules.
return MyPlugin
```

## API Reference
> [!NOTE]
> The API reference is generated from the source code using tealdoc itself.