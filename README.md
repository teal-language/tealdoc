# Tealdoc

> [!WARNING]
> Tealdoc is currently in alpha. Expect bugs, missing functionality, and breaking changes.
>
> As of now, only Markdown output is implemented.

A documentation generator written in [Teal](github.com/teal-language/tl/tree/master).

Its primary function is to generate documentation for programs written in Teal, but it is extensible enough to support other languages.
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

### Modules

Every file you wish to generate documentation for must contain a module.
To document a module, add a detached comment at the top-level containing the `@module` tag.

**Note:** The module comment must be separated from any subsequent declarations by at least one blank line.

```teal
--- A test module for demonstrating Tealdoc.
-- @module test

local record test
    ...
end

function test.foo()
    ...
end

return test
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
# Module: tealdoc
This module exposes the public API of Tealdoc.  You can use it to programmatically interact with Tealdoc. You can also use it to extend Tealdoc using plugins.
## tealdoc.Plugin
```
interface tealdoc.Plugin
```
Plugin is an abstract base interface for tealdoc plugins. Plugins can be used to extend Tealdoc functionality. When using the CLI you can load plugins using the `--plugin` option followed by the plugin package name, which will be resolved the same way as Lua modules.
## tealdoc.Plugin.name
```
tealdoc.Plugin.name: string
```
The name of the plugin used for identification purposes.
## tealdoc.Plugin.run
```
tealdoc.Plugin.run(env: tealdoc.Env)
```
Run the plugin. This function is called when the plugin is loaded. You may use this function to modify the environment in order to extend the Tealdoc functionality.
#### Parameters

- **`env`** (`tealdoc.Env`) — The environment in which the plugin is running.

## tealdoc.Parser
```
interface tealdoc.Parser
```
Parser is an abstract base interface for Tealdoc parsers. Parsers are used to process source files and extract documentation items from them. Parsers must add the items to the `env.registry` table. Each parser is responsible for a specific set of file extensions. You can register a parser using the `add_parser` method of the `tealdoc.Env` interface.
## tealdoc.Parser.process
```
tealdoc.Parser.process(text: string, filename: string, env: tealdoc.Env)
```
Process file contents. This function is called by Tealdoc when a file with a registered extension is processed.
#### Parameters

- **`text`** (`string`) — The contents of the file as a string.
- **`filename`** (`string`) — The name of the file being processed.
- **`env`** (`tealdoc.Env`) — The environment in which the parser is running.

## tealdoc.Parser.file_extensions
```
tealdoc.Parser.file_extensions: {string}
```
A list of file extensions that this parser can handle. This is used to register the parser in the `tealdoc.Env` environment. Each extension should start with a dot (e.g. ".lua", ".md").
## tealdoc.Tag
```
interface tealdoc.Tag
```
Tag is an abstract base interface for Tealdoc tags. Tags are used to annotate items with additional metadata. Tags can be used to provide additional information about an item, such as parameters, descriptions, or other attributes. Tags can be registered in the `tealdoc.Env` environment using the `add_tag` method.
## tealdoc.Tag.Context
```
interface tealdoc.Tag.Context
```
Context is the context in which the tag is encountered.
## tealdoc.Tag.Context.item
```
tealdoc.Tag.Context.item: Item
```
The item to which the tag belongs.
## tealdoc.Tag.Context.param
```
tealdoc.Tag.Context.param: string
```
The parameter of the tag if any. Only applicable if has_param of the tag is true.
## tealdoc.Tag.Context.description
```
tealdoc.Tag.Context.description: string
```
The description of the tag if any. Only applicable if has_description of the tag is true.
## tealdoc.Tag.name
```
tealdoc.Tag.name: string
```
The name of the tag, which is used to identify the tag in the comments.
## tealdoc.Tag.handle
```
tealdoc.Tag.handle(ctx: Context)
```
Function which is called when the tag is encountered in the comments.
#### Parameters

- **`ctx`** (`Context`) — The context in which the tag is encountered.

## tealdoc.Tag.has_param
```
tealdoc.Tag.has_param: boolean
```
Whether the tag has a parameter. If true, the tag expects a parameter after the tag name. For example, `@param name description` has a parameter `name`.
## tealdoc.Tag.has_description
```
tealdoc.Tag.has_description: boolean
```
Whether the tag has a description. If true, the tag expects a description after the tag name or parameter. For example, `@description This is a description` has a description `This is a description`.
## tealdoc.Location
```
record tealdoc.Location
```
This record represents a location in a file. It is used to store the location of an item in the source code.
## tealdoc.Location.filename
```
tealdoc.Location.filename: string
```
The path to the file where the item is located.
## tealdoc.Location.x
```
tealdoc.Location.x: integer
```
The column number where the item is located.
## tealdoc.Location.y
```
tealdoc.Location.y: integer
```
The line number where the item is located.
## tealdoc.Item
```
interface tealdoc.Item
```
Item is an abstract base interface for Tealdoc items. Items represent documentation entities such as functions, variables, types, etc. Items can also represent abstract concepts like namespaces or modules.
## tealdoc.Item.kind
```
tealdoc.Item.kind: string
```
The kind of the item, e.g. "function", "variable", "type", etc. This is used to differentiate between different types of items.
## tealdoc.Item.path
```
tealdoc.Item.path: string
```
The path to the item, which is used as a unique identifier.
## tealdoc.Item.name
```
tealdoc.Item.name: string
```
The name of the item, which is used for display purposes. This is usually the same as the last part of the path.
## tealdoc.Item.children
```
tealdoc.Item.children: {string}
```
The children of the item, which are other items that are related to this item. This is used to represent hierarchical relationships between items. For example, a record type may have fields that are also items. The children are stored as an array of paths of the children.
## tealdoc.Item.parent
```
tealdoc.Item.parent: string
```
The parent of the item, which is the path to the parent item.
## tealdoc.Item.text
```
tealdoc.Item.text: string
```
The text of the item, which is the documentation content. This is usually a multiline string that contains the documentation for the item. It may include markdown or other formatting. If the item does not have any documentation, this may be nil.
## tealdoc.Item.attributes
```
tealdoc.Item.attributes: {string : <any type>}
```
The attributes of the item, which are additional metadata.
## tealdoc.Item.location
```
tealdoc.Item.location: Location
```
The location of the item in the source code.
## tealdoc.Env
```
record tealdoc.Env
```
Env is the environment in which Tealdoc operates. It contains the registry of items, parsers, and tag handlers. You can use this environment to add new parsers or tag handlers. You can also use it to access the registry of items.
## tealdoc.Env.registry
```
tealdoc.Env.registry: {string : Item}
```
The registry of items, which is a table mapping paths to items. This is used to store all the items that are processed by Tealdoc. The keys are the paths of the items, and the values are the items themselves.
## tealdoc.Env.modules
```
tealdoc.Env.modules: {string}
```
The list of modules that are processed by Tealdoc. This is used to store the names of the modules that are documented.
## tealdoc.Env.include_all
```
tealdoc.Env.include_all: boolean
```
The option to include all items in the output. If this is true, all items will be included in the output, regardless of whether they are local or global. When using the CLI, you can set this option using the `--all` flag.
## tealdoc.Env.add_parser
```
tealdoc.Env.add_parser(self: self, parser: Parser)
```
Add a parser to the environment. This function registers a parser that can handle specific file extensions. The parser must implement the `tealdoc.Parser` interface.
#### Parameters

- **`self`** (`self`) — The environment to which the parser is added.
- **`parser`** (`Parser`) — The parser to add.

## tealdoc.Env.add_tag
```
tealdoc.Env.add_tag(self: self, tag: Tag)
```
Add a tag to the environment. The tag must implement the `tealdoc.Tag` interface.
#### Parameters

- **`self`** (`self`) — The environment to which the tag is added.
- **`tag`** (`Tag`) — The tag to add.

## tealdoc.Env.init
```
tealdoc.Env.init(): Env
```
Initialize a new environment. This function creates a new environment with empty registries.
#### Returns

1. (`Env`)

## tealdoc.Typearg
```
record tealdoc.Typearg
```
This record represents a type argument for a function or type.
## tealdoc.Typearg.name
```
tealdoc.Typearg.name: string
```
The name of the type argument.
## tealdoc.Typearg.constraint
```
tealdoc.Typearg.constraint: string
```
The constraint of the type argument if any.
## tealdoc.Typearg.description
```
tealdoc.Typearg.description: string
```
The description of the type argument.
## tealdoc.DeclarationItem
```
interface tealdoc.DeclarationItem is tealdoc.Item
```
This interface represents a declaration item in Tealdoc. It is used to represent declarations of functions, variables, and types.
## tealdoc.DeclarationItem.Visibility
```
enum tealdoc.DeclarationItem.Visibility
```
Possible visibilities for declarations.
## tealdoc.DeclarationItem.Visibility.global
Global visibility, for global variables and functions.
## tealdoc.DeclarationItem.Visibility.record
Record visibility, for record fields and nested types.
## tealdoc.DeclarationItem.Visibility.local
Local visibility, for local variables and functions.
## tealdoc.DeclarationItem.visibility
```
tealdoc.DeclarationItem.visibility: Visibility
```
The visibility of the declaration.
## tealdoc.FunctionItem
```
record tealdoc.FunctionItem is tealdoc.DeclarationItem, tealdoc.Item
```
This record represents a function item in Tealdoc.
## tealdoc.FunctionItem.Param
```
record tealdoc.FunctionItem.Param
```
This record represents a parameter of a function.
## tealdoc.FunctionItem.Param.name
```
tealdoc.FunctionItem.Param.name: string
```
The name of the parameter.
## tealdoc.FunctionItem.Param.type
```
tealdoc.FunctionItem.Param.type: string
```
The type of the parameter.
## tealdoc.FunctionItem.Param.description
```
tealdoc.FunctionItem.Param.description: string
```
The description of the parameter.
## tealdoc.FunctionItem.Return
```
record tealdoc.FunctionItem.Return
```
This record represents a return value of a function.
## tealdoc.FunctionItem.Return.type
```
tealdoc.FunctionItem.Return.type: string
```
The type of the return value.
## tealdoc.FunctionItem.Return.description
```
tealdoc.FunctionItem.Return.description: string
```
The description of the return value.
## tealdoc.FunctionItem.FunctionKind
```
enum tealdoc.FunctionItem.FunctionKind
```
Possible function kinds
## tealdoc.FunctionItem.FunctionKind.normal
Normal function, local, global, or in-record.
## tealdoc.FunctionItem.FunctionKind.macroexp
Macro expansion function
## tealdoc.FunctionItem.FunctionKind.metamethod
Record metamethod
## tealdoc.FunctionItem.params
```
tealdoc.FunctionItem.params: {Param}
```
Function parameters.
## tealdoc.FunctionItem.returns
```
tealdoc.FunctionItem.returns: {Return}
```
Function return values.
## tealdoc.FunctionItem.typeargs
```
tealdoc.FunctionItem.typeargs: {Typearg}
```
Function type arguments.
## tealdoc.FunctionItem.function_kind
```
tealdoc.FunctionItem.function_kind: FunctionKind
```
The kind of the function.
## tealdoc.FunctionItem.is_declaration
```
tealdoc.FunctionItem.is_declaration: boolean
```
Whether this function is an in-record declaration.
## tealdoc.VariableItem
```
record tealdoc.VariableItem is tealdoc.DeclarationItem, tealdoc.Item
```
This record represents a variable item in Tealdoc.
## tealdoc.VariableItem.typename
```
tealdoc.VariableItem.typename: string
```
The name of the type of the variable.
## tealdoc.TypeItem
```
record tealdoc.TypeItem is tealdoc.DeclarationItem, tealdoc.Item
```
This record represents a type item in Tealdoc. It is used to represent types, records, interfaces, enums, and type aliases.
## tealdoc.TypeItem.TypeKind
```
enum tealdoc.TypeItem.TypeKind
```
Possible kinds of types.
## tealdoc.TypeItem.TypeKind.type
Type kind for a type alias.
## tealdoc.TypeItem.TypeKind.record
Type kind for a record type.
## tealdoc.TypeItem.TypeKind.interface
Type kind for an interface type.
## tealdoc.TypeItem.TypeKind.enum
Type kind for an enum type.
## tealdoc.TypeItem.typename
```
tealdoc.TypeItem.typename: string
```
The name of the type of the type item.
## tealdoc.TypeItem.typeargs
```
tealdoc.TypeItem.typeargs: {Typearg}
```
The type arguments of the type item. Only used for records and interfaces.
## tealdoc.TypeItem.type_kind
```
tealdoc.TypeItem.type_kind: TypeKind
```
The kind of the type item.
## tealdoc.TypeItem.inherits
```
tealdoc.TypeItem.inherits: {string}
```
Paths of inherited types
## tealdoc.process_file
```
tealdoc.process_file(path: string, env: Env)
```
Process a file with the given path using the parsers registered in the environment. This function reads the file contents and passes it to the appropriate parser based on the file extension. If no parser is found for the file extension, a warning is logged and the file is skipped.
#### Parameters

- **`path`** (`string`) — The path to the file to process.
- **`env`** (`Env`) — The environment in which the file is processed.

## tealdoc.process_text
```
tealdoc.process_text(text: string, filename: string, env: Env)
```
Process the given text as a file with the specified filename using the parsers registered in the environment. This function is useful for processing text that is not read from a file, such as text from a string or a buffer. If no parser is found for the file extension, a warning is logged and the text is skipped.
#### Parameters

- **`text`** (`string`) — The text to process.
- **`filename`** (`string`) — The name of the file being processed, used to determine the file extension.
- **`env`** (`Env`) — The environment in which the text is processed.

## About

This project started as a [Google Summer of Code 2025 project](https://summerofcode.withgoogle.com/programs/2024/projects/MCJkfE3P) from [Miłosz Koczorowski](https://github.com/upedd), mentored by [Hisham Muhammad](https://github.com/hishamhm) and [Loren Segal](https://github.com/lsegal).

Tealdoc is licensed under an MIT license.
