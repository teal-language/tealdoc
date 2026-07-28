<a id="$docs.header"></a>

# Tealdoc

> [!WARNING]
> Tealdoc is currently in alpha. Expect bugs, missing functionality, and breaking changes.

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

<a id="$docs.installation"></a>

## Installation

Tealdoc can be installed using [Luarocks](https://luarocks.org/):

```
luarocks install tealdoc
```

<a id="$docs.tutorial"></a>

## How to Document Your Code

### Tealdoc Comments

Documentation can be written in special comments that begin with three hyphens (`---`).

```
--- This is a Tealdoc summary line.
--- The rest of the comment forms the detailed description.
--- It can span multiple lines.

---
-- This is also a valid Tealdoc comment.
```

You can also use a block comment.

```
--[[--
    This is a Tealdoc block comment.
    ...
]]--
```

### Anatomy of a Comment

All documentation comments start with a brief summary sentence that ends with a period. The text that follows the summary becomes the detailed description.

After the description, you can add tags, which start with an `@`. Tags may optionally include a parameter and a description.

```
--- This is the summary. This is the detailed description.
-- @tag_name parameter The description for this tag.
-- @another_tag
```

### Functions

Document functions by placing a Tealdoc comment directly above them. Parameter and return types are inferred automatically from the function's type annotations.

```
--- Adds two integers.
-- This function adds two integers together.
-- @param a The first integer to add.
-- @param b The second integer to add.
-- @return The sum of the two integers.
function test.foo(a: integer, b: integer): integer
    return a + b
end
```

Function types used in declarations and record fields may not provide
parameter names to Tealdoc. Put `@param` tags on the declaration instead of
placing documentation comments inside the function type:

```
global record script
    --- Registers a function to run during mod initialization.
    --- @param handler The event handler. Passing nil unregisters it.
    on_init: function(function())
end
```

Tealdoc matches tags for unnamed parameters by declaration order and uses each
tag's parameter name in the generated documentation. When a function type has
multiple unnamed parameters, write its `@param` tags in the same order.

You can use multiple `@return` tags to document functions with multiple return values:

```
--- Fetches messages from the server.
-- @return A table of messages if successful.
-- @return An error message on failure.
function client.fetch_messages(): {Message}, string
    ...
end
```

Use the `@typearg` tag to document generic type variables:

```
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

```
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

```
--- Multiplies the length of all sides of the square.
-- @param x The factor to multiply by.
function Square:multiply_sides(x: number)
    ...
end
```

**Note:** If a function has documentation at both its declaration (inside the record) and its definition, the definition's documentation will be prioritized, and a warning will be emitted.

### Enums

Enum types and their values can be documented:

```
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

```
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

### Categories
You can add `@category <category_name>` tags to your module members to group them into categories. This can help organize your documentation and make it easier to navigate.
```
local record Logger
    --- @category callbacks
    on_message: function(message: string)

    --- @category methods
    log: function(self, message: string)

    --- @category methods
    error: function(self, message: string)
end
```


<a id="$docs.cli_reference"></a>

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

### Project Configuration

Tealdoc reads its project settings from the `tealdoc` table in the nearest
`tlconfig.lua`, using the same current-directory and parent-directory search as
Teal. The namespace lets Tealdoc add settings without colliding with compiler
or other tool settings.

For Markdown output, `markdown.type_links` can map canonical Tealdoc path
prefixes to URL prefixes:

```lua
local base = os.getenv("DOCS_BASE") or ""

return {
    source_dir = "src",
    tealdoc = {
        markdown = {
            type_links = {
                ["my.http"] = base .. "/modules/http#my.http",
                ["my.Future"] = base .. "/modules/future#my.future.Future",
            },
        },
    },
}
```

The exact path links to the page before `#`. A descendant appends its suffix
to the complete URL prefix, so `my.http.Response` above links to
`/modules/http#my.http.Response`. Types with no route remain plain code.

For complete control, the configuration can instead return a resolver
function. It receives a canonical type path and returns its URL, or `nil` when
the type should remain unlinked:

```lua
return {
    tealdoc = {
        markdown = {
            type_links = function(path)
                if path == "external.Widget" then
                    return "https://example.com/widget"
                end
            end,
        },
    },
}
```

`tlconfig.lua` is loaded and executed as trusted Lua code. Markdown cannot
contain links inside fenced code blocks, so Tealdoc keeps signatures as valid,
syntax-highlighted Teal and applies type links in the structured Arguments and
Returns sections.


<a id="$docs.architecture"></a>

## Architecture

Tealdoc features a flexible, input-language-agnostic architecture.

*   **Registry**: The central piece is the `registry`, which stores all discovered documentation `items`.
*   **Item**: An `item` is a piece of data in the registry representing a code entity (like a function or record) or an abstract concept. Each item has a unique path and can contain child items.
*   **Parser**: The input layer that processes source files and populates the registry with items.
*   **Consumers**: Built-in consumers (like the Markdown generator) that process the registry to create output.

This design allows you to extend Tealdoc with custom tags, parsers for other languages, or new output generators.

### Using Tealdoc Programmatically

You can use the Tealdoc API to process files and access the registry directly.

```
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


<a id="$docs.api_reference_header"></a>

## API Reference
> [!NOTE]
> The API reference is generated from the source code using tealdoc itself.

<a id="$tealdoc"></a>
# Module: tealdoc
This module exposes the public API of Tealdoc.

You can use it to programmatically interact with Tealdoc.
You can also use it to extend Tealdoc using plugins.
<a id="tealdoc"></a>
<a id="tealdoc.DeclarationItem"></a>
## tealdoc.DeclarationItem

This interface represents a declaration item in Tealdoc.
It is used to represent declarations of functions, variables, and types.


```teal
interface tealdoc.DeclarationItem
```

<a id="tealdoc.DeclarationItem.Visibility"></a>
### tealdoc.DeclarationItem.Visibility

Possible visibilities for declarations.


```teal
enum tealdoc.DeclarationItem.Visibility
```

<a id="tealdoc.DeclarationItem.Visibility.&quot;global&quot;"></a>
#### tealdoc.DeclarationItem.Visibility.&quot;global&quot;

Global visibility, for global variables and functions.

<a id="tealdoc.DeclarationItem.Visibility.&quot;local&quot;"></a>
#### tealdoc.DeclarationItem.Visibility.&quot;local&quot;

Local visibility, for local variables and functions.

<a id="tealdoc.DeclarationItem.Visibility.&quot;record&quot;"></a>
#### tealdoc.DeclarationItem.Visibility.&quot;record&quot;

Record visibility, for record fields and nested types.

<a id="tealdoc.DeclarationItem.visibility"></a>
### tealdoc.DeclarationItem.visibility

The visibility of the declaration.


```teal
tealdoc.DeclarationItem.visibility: Visibility
```

<a id="tealdoc.Env"></a>
## tealdoc.Env

Env is the environment in which Tealdoc operates.
It contains the registry of items, parsers, and tag handlers.
You can use this environment to add new parsers or tag handlers.
You can also use it to access the registry of items.


```teal
record tealdoc.Env
```

<a id="tealdoc.Env.registry"></a>
### tealdoc.Env.registry

The registry of items, which is a table mapping paths to items.
This is used to store all the items that are processed by Tealdoc.
The keys are the paths of the items, and the values are the items themselves.


```teal
tealdoc.Env.registry: {string : Item}
```

<a id="tealdoc.Env.modules"></a>
### tealdoc.Env.modules

The list of modules that are processed by Tealdoc.
This is used to store the names of the modules that are documented.


```teal
tealdoc.Env.modules: {string}
```

<a id="tealdoc.Env.include_all"></a>
### tealdoc.Env.include_all

The option to include all items in the output.
If this is true, all items will be included in the output,
regardless of whether they are local or global.
When using the CLI, you can set this option using the `--all` flag.


```teal
tealdoc.Env.include_all: boolean
```

<a id="tealdoc.Env.no_warnings_on_missing"></a>
### tealdoc.Env.no_warnings_on_missing

Whether to skip warnings about missing items.
If this is true, Tealdoc will not log warnings about missing items.


```teal
tealdoc.Env.no_warnings_on_missing: boolean
```

<a id="tealdoc.Env.add_parser"></a>
### tealdoc.Env.add_parser

Add a parser to the environment.
This function registers a parser that can handle specific file extensions.
The parser must implement the `tealdoc.Parser` interface.


```teal
function tealdoc.Env.add_parser(self: Env, parser: Parser)
```

#### Arguments

- **`self`** (`Env`) — The environment to which the parser is added.
- **`parser`** (`Parser`) — The parser to add.

#### Returns

None.

<a id="tealdoc.Env.add_tag"></a>
### tealdoc.Env.add_tag

Add a tag to the environment.
The tag must implement the `tealdoc.Tag` interface.


```teal
function tealdoc.Env.add_tag(self: Env, tag: Tag)
```

#### Arguments

- **`self`** (`Env`) — The environment to which the tag is added.
- **`tag`** (`Tag`) — The tag to add.

#### Returns

None.

<a id="tealdoc.Env.init"></a>
### tealdoc.Env.init

Initialize a new environment.
This function creates a new environment with empty registries.


```teal
function tealdoc.Env.init(): Env
```

#### Arguments

None.

#### Returns

1. (`Env`)

<a id="tealdoc.FunctionItem"></a>
## tealdoc.FunctionItem

This record represents a function item in Tealdoc.


```teal
record tealdoc.FunctionItem
```

<a id="tealdoc.FunctionItem.Param"></a>
### tealdoc.FunctionItem.Param

This record represents a parameter of a function.


```teal
record tealdoc.FunctionItem.Param
```

<a id="tealdoc.FunctionItem.Param.name"></a>
#### tealdoc.FunctionItem.Param.name

The name of the parameter.


```teal
tealdoc.FunctionItem.Param.name: string
```

<a id="tealdoc.FunctionItem.Param.type"></a>
#### tealdoc.FunctionItem.Param.type

The type of the parameter.


```teal
tealdoc.FunctionItem.Param.type: string
```

<a id="tealdoc.FunctionItem.Param.type_references"></a>
#### tealdoc.FunctionItem.Param.type_references

Named types contained in the parameter type.


```teal
tealdoc.FunctionItem.Param.type_references: {TypeReference}
```

<a id="tealdoc.FunctionItem.Param.description"></a>
#### tealdoc.FunctionItem.Param.description

The description of the parameter.


```teal
tealdoc.FunctionItem.Param.description: string
```

<a id="tealdoc.FunctionItem.Return"></a>
### tealdoc.FunctionItem.Return

This record represents a return value of a function.


```teal
record tealdoc.FunctionItem.Return
```

<a id="tealdoc.FunctionItem.Return.type"></a>
#### tealdoc.FunctionItem.Return.type

The type of the return value.


```teal
tealdoc.FunctionItem.Return.type: string
```

<a id="tealdoc.FunctionItem.Return.type_references"></a>
#### tealdoc.FunctionItem.Return.type_references

Named types contained in the return type.


```teal
tealdoc.FunctionItem.Return.type_references: {TypeReference}
```

<a id="tealdoc.FunctionItem.Return.description"></a>
#### tealdoc.FunctionItem.Return.description

The description of the return value.


```teal
tealdoc.FunctionItem.Return.description: string
```

<a id="tealdoc.FunctionItem.FunctionKind"></a>
### tealdoc.FunctionItem.FunctionKind

Possible function kinds


```teal
enum tealdoc.FunctionItem.FunctionKind
```

<a id="tealdoc.FunctionItem.FunctionKind.&quot;function&quot;"></a>
#### tealdoc.FunctionItem.FunctionKind.&quot;function&quot;

Normal function, local, global, or in-record.

<a id="tealdoc.FunctionItem.FunctionKind.&quot;macroexp&quot;"></a>
#### tealdoc.FunctionItem.FunctionKind.&quot;macroexp&quot;

Macro expansion function

<a id="tealdoc.FunctionItem.FunctionKind.&quot;metamethod&quot;"></a>
#### tealdoc.FunctionItem.FunctionKind.&quot;metamethod&quot;

Record metamethod

<a id="tealdoc.FunctionItem.params"></a>
### tealdoc.FunctionItem.params

Function parameters.


```teal
tealdoc.FunctionItem.params: {Param}
```

<a id="tealdoc.FunctionItem.returns"></a>
### tealdoc.FunctionItem.returns

Function return values.


```teal
tealdoc.FunctionItem.returns: {Return}
```

<a id="tealdoc.FunctionItem.typeargs"></a>
### tealdoc.FunctionItem.typeargs

Function type arguments.


```teal
tealdoc.FunctionItem.typeargs: {Typearg}
```

<a id="tealdoc.FunctionItem.function_kind"></a>
### tealdoc.FunctionItem.function_kind

The kind of the function.


```teal
tealdoc.FunctionItem.function_kind: FunctionKind
```

<a id="tealdoc.FunctionItem.is_declaration"></a>
### tealdoc.FunctionItem.is_declaration

Whether this function is only a declaration (it does not contain a body).


```teal
tealdoc.FunctionItem.is_declaration: boolean
```

<a id="tealdoc.FunctionItem.$meta"></a>
<a id="tealdoc.Item"></a>
## tealdoc.Item

Item is an abstract base interface for Tealdoc items.
Items represent documentation entities such as functions, variables, types, etc.
Items can also represent abstract concepts like namespaces or modules.


```teal
interface tealdoc.Item
```

<a id="tealdoc.Item.kind"></a>
### tealdoc.Item.kind

The kind of the item, e.g. "function", "variable", "type", etc.
This is used to differentiate between different types of items.


```teal
tealdoc.Item.kind: string
```

<a id="tealdoc.Item.path"></a>
### tealdoc.Item.path

The path to the item, which is used as a unique identifier.


```teal
tealdoc.Item.path: string
```

<a id="tealdoc.Item.name"></a>
### tealdoc.Item.name

The name of the item, which is used for display purposes.
This is usually the same as the last part of the path.


```teal
tealdoc.Item.name: string
```

<a id="tealdoc.Item.children"></a>
### tealdoc.Item.children

The children of the item, which are other items that are related to this item.
This is used to represent hierarchical relationships between items.
For example, a record type may have fields that are also items.
The children are stored as an array of paths of the children.


```teal
tealdoc.Item.children: {string}
```

<a id="tealdoc.Item.parent"></a>
### tealdoc.Item.parent

The parent of the item, which is the path to the parent item.


```teal
tealdoc.Item.parent: string
```

<a id="tealdoc.Item.text"></a>
### tealdoc.Item.text

The text of the item, which is the documentation content.
This is usually a multiline string that contains the documentation for the item.
It may include markdown or other formatting.
If the item does not have any documentation, this may be nil.


```teal
tealdoc.Item.text: string
```

<a id="tealdoc.Item.attributes"></a>
### tealdoc.Item.attributes

The attributes of the item, which are additional metadata.


```teal
tealdoc.Item.attributes: {string : <any type>}
```

<a id="tealdoc.Item.location"></a>
### tealdoc.Item.location

The location of the item in the source code.


```teal
tealdoc.Item.location: Location
```

<a id="tealdoc.Location"></a>
## tealdoc.Location

This record represents a location in a file.
It is used to store the location of an item in the source code.


```teal
record tealdoc.Location
```

<a id="tealdoc.Location.filename"></a>
### tealdoc.Location.filename

The path to the file where the item is located.


```teal
tealdoc.Location.filename: string
```

<a id="tealdoc.Location.x"></a>
### tealdoc.Location.x

The column number where the item is located.


```teal
tealdoc.Location.x: integer
```

<a id="tealdoc.Location.y"></a>
### tealdoc.Location.y

The line number where the item is located.


```teal
tealdoc.Location.y: integer
```

<a id="tealdoc.Parser"></a>
## tealdoc.Parser

Parser is an abstract base interface for Tealdoc parsers.
Parsers are used to process source files and extract documentation items from them.
Parsers must add the items to the `env.registry` table.
Each parser is responsible for a specific set of file extensions.
You can register a parser using the `add_parser` method of the `tealdoc.Env` interface.


```teal
interface tealdoc.Parser
```

<a id="tealdoc.Parser.process"></a>
### tealdoc.Parser.process

Process file contents.
This function is called by Tealdoc when a file with a registered extension is processed.


```teal
function tealdoc.Parser.process(self: Parser, text: string, path: string, env: tealdoc.Env)
```

#### Arguments

- **`self`** (`Parser`) — The parser instance.
- **`text`** (`string`) — The contents of the file as a string.
- **`path`** (`string`) — The path of the file being processed.
- **`env`** (`tealdoc.Env`) — The environment in which the parser is running.

#### Returns

None.

<a id="tealdoc.Parser.file_extensions"></a>
### tealdoc.Parser.file_extensions

A list of file extensions that this parser can handle.
This is used to register the parser in the `tealdoc.Env` environment.
Each extension should start with a dot (e.g. ".lua", ".md").


```teal
tealdoc.Parser.file_extensions: {string}
```

<a id="tealdoc.Plugin"></a>
## tealdoc.Plugin

Plugin is an abstract base interface for tealdoc plugins.
Plugins can be used to extend Tealdoc functionality.
When using the CLI you can load plugins using the `--plugin` option
followed by the plugin package name, which will be resolved the same way as Lua modules.


```teal
interface tealdoc.Plugin
```

<a id="tealdoc.Plugin.name"></a>
### tealdoc.Plugin.name

The name of the plugin used for identification purposes.


```teal
tealdoc.Plugin.name: string
```

<a id="tealdoc.Plugin.run"></a>
### tealdoc.Plugin.run

Run the plugin.
This function is called when the plugin is loaded.
You may use this function to modify the environment in order to extend the Tealdoc functionality.


```teal
function tealdoc.Plugin.run(env: tealdoc.Env)
```

#### Arguments

- **`env`** (`tealdoc.Env`) — The environment in which the plugin is running.

#### Returns

None.

<a id="tealdoc.Tag"></a>
## tealdoc.Tag

Tag is an abstract base interface for Tealdoc tags.
Tags are used to annotate items with additional metadata.
Tags can be used to provide additional information about an item,
such as parameters, descriptions, or other attributes.
Tags can be registered in the `tealdoc.Env` environment
using the `add_tag` method.


```teal
interface tealdoc.Tag
```

<a id="tealdoc.Tag.Context"></a>
### tealdoc.Tag.Context

Context is the context in which the tag is encountered.


```teal
interface tealdoc.Tag.Context
```

<a id="tealdoc.Tag.Context.item"></a>
#### tealdoc.Tag.Context.item

The item to which the tag belongs.


```teal
tealdoc.Tag.Context.item: Item
```

<a id="tealdoc.Tag.Context.param"></a>
#### tealdoc.Tag.Context.param

The parameter of the tag if any.
Only applicable if has_param of the tag is true.


```teal
tealdoc.Tag.Context.param: string
```

<a id="tealdoc.Tag.Context.description"></a>
#### tealdoc.Tag.Context.description

The description of the tag if any.
Only applicable if has_description of the tag is true.


```teal
tealdoc.Tag.Context.description: string
```

<a id="tealdoc.Tag.name"></a>
### tealdoc.Tag.name

The name of the tag, which is used to identify the tag in the comments.


```teal
tealdoc.Tag.name: string
```

<a id="tealdoc.Tag.handle"></a>
### tealdoc.Tag.handle

Function which is called when the tag is encountered in the comments.


```teal
function tealdoc.Tag.handle(ctx: Context)
```

#### Arguments

- **`ctx`** (`Context`) — The context in which the tag is encountered.

#### Returns

None.

<a id="tealdoc.Tag.has_param"></a>
### tealdoc.Tag.has_param

Whether the tag has a parameter.
If true, the tag expects a parameter after the tag name.
For example, `@param name description` has a parameter `name`.


```teal
tealdoc.Tag.has_param: boolean
```

<a id="tealdoc.Tag.has_description"></a>
### tealdoc.Tag.has_description

Whether the tag has a description.
If true, the tag expects a description after the tag name or parameter.
For example, `@description This is a description` has a description `This is a description`.


```teal
tealdoc.Tag.has_description: boolean
```

<a id="tealdoc.TypeItem"></a>
## tealdoc.TypeItem

This record represents a type item in Tealdoc.
It is used to represent types, records, interfaces, enums, and type aliases.


```teal
record tealdoc.TypeItem
```

<a id="tealdoc.TypeItem.TypeKind"></a>
### tealdoc.TypeItem.TypeKind

Possible kinds of types.


```teal
enum tealdoc.TypeItem.TypeKind
```

<a id="tealdoc.TypeItem.TypeKind.&quot;enum&quot;"></a>
#### tealdoc.TypeItem.TypeKind.&quot;enum&quot;

Type kind for an enum type.

<a id="tealdoc.TypeItem.TypeKind.&quot;interface&quot;"></a>
#### tealdoc.TypeItem.TypeKind.&quot;interface&quot;

Type kind for an interface type.

<a id="tealdoc.TypeItem.TypeKind.&quot;record&quot;"></a>
#### tealdoc.TypeItem.TypeKind.&quot;record&quot;

Type kind for a record type.

<a id="tealdoc.TypeItem.TypeKind.&quot;type&quot;"></a>
#### tealdoc.TypeItem.TypeKind.&quot;type&quot;

Type kind for a type alias.

<a id="tealdoc.TypeItem.typename"></a>
### tealdoc.TypeItem.typename

The name of the type of the type item.


```teal
tealdoc.TypeItem.typename: string
```

<a id="tealdoc.TypeItem.alias_target"></a>
### tealdoc.TypeItem.alias_target

Canonical item path for a nominal type alias target, when known.


```teal
tealdoc.TypeItem.alias_target: string
```

<a id="tealdoc.TypeItem.typeargs"></a>
### tealdoc.TypeItem.typeargs

The type arguments of the type item.
Only used for records and interfaces.


```teal
tealdoc.TypeItem.typeargs: {Typearg}
```

<a id="tealdoc.TypeItem.type_kind"></a>
### tealdoc.TypeItem.type_kind

The kind of the type item.


```teal
tealdoc.TypeItem.type_kind: TypeKind
```

<a id="tealdoc.TypeItem.inherits"></a>
### tealdoc.TypeItem.inherits

Names of inherited types


```teal
tealdoc.TypeItem.inherits: {string}
```

<a id="tealdoc.TypeItem.$meta"></a>
<a id="tealdoc.TypeReference"></a>
## tealdoc.TypeReference

A named type referenced inside a rendered type expression.


```teal
record tealdoc.TypeReference
```

<a id="tealdoc.TypeReference.name"></a>
### tealdoc.TypeReference.name

The spelling used in the source type expression.


```teal
tealdoc.TypeReference.name: string
```

<a id="tealdoc.TypeReference.path"></a>
### tealdoc.TypeReference.path

The canonical Tealdoc item path for the referenced type.


```teal
tealdoc.TypeReference.path: string
```

<a id="tealdoc.Typearg"></a>
## tealdoc.Typearg

This record represents a type argument for a function or type.


```teal
record tealdoc.Typearg
```

<a id="tealdoc.Typearg.name"></a>
### tealdoc.Typearg.name

The name of the type argument.


```teal
tealdoc.Typearg.name: string
```

<a id="tealdoc.Typearg.constraint"></a>
### tealdoc.Typearg.constraint

The constraint of the type argument if any.


```teal
tealdoc.Typearg.constraint: string
```

<a id="tealdoc.Typearg.description"></a>
### tealdoc.Typearg.description

The description of the type argument.


```teal
tealdoc.Typearg.description: string
```

<a id="tealdoc.VariableItem"></a>
## tealdoc.VariableItem

This record represents a variable item in Tealdoc.


```teal
record tealdoc.VariableItem
```

<a id="tealdoc.VariableItem.typename"></a>
### tealdoc.VariableItem.typename

The name of the type of the variable.


```teal
tealdoc.VariableItem.typename: string
```

<a id="tealdoc.VariableItem.$meta"></a>
<a id="tealdoc.process_file"></a>
## tealdoc.process_file

Process a file with the given path using the parsers registered in the environment.
This function reads the file contents and passes it to the appropriate parser based on the file extension.
If no parser is found for the file extension, a warning is logged and the file is skipped.


```teal
function tealdoc.process_file(path: string, env: Env)
```

### Arguments

- **`path`** (`string`) — The path to the file to process.
- **`env`** (`Env`) — The environment in which the file is processed.

### Returns

None.

<a id="tealdoc.process_text"></a>
## tealdoc.process_text

Process the given text as a file with the specified filename using the parsers registered in the environment.
This function is useful for processing text that is not read from a file, such as
text from a string or a buffer.
If no parser is found for the file extension, a warning is logged and the text is skipped.


```teal
function tealdoc.process_text(text: string, filename: string, env: Env)
```

### Arguments

- **`text`** (`string`) — The text to process.
- **`filename`** (`string`) — The name of the file being processed, used to determine the file extension.
- **`env`** (`Env`) — The environment in which the text is processed.

### Returns

None.

<a id="tealdoc.version"></a>
## tealdoc.version

Current version of Tealdoc.


```teal
tealdoc.version: string
```

<a id="$docs.about"></a>

## About

This project started as a [Google Summer of Code 2025 project](https://summerofcode.withgoogle.com/programs/2024/projects/MCJkfE3P) from [Miłosz Koczorowski](https://github.com/upedd), mentored by [Hisham Muhammad](https://github.com/hishamhm) and [Loren Segal](https://github.com/lsegal).

Tealdoc is licensed under an MIT license.
