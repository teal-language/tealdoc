local log = require("tealdoc.log")

--- This module exposes the public API of Tealdoc.
---
--- You can use it to programmatically interact with Tealdoc.
--- You can also use it to extend Tealdoc using plugins.
local record tealdoc
    
    --- Plugin is an abstract base interface for tealdoc plugins.
    --- Plugins can be used to extend Tealdoc functionality.
    --- When using the CLI you can load plugins using the `--plugin` option
    --- followed by the plugin package name, which will be resolved the same way as Lua modules.
    interface Plugin
        --- The name of the plugin used for identification purposes.
        name: string

        --- Run the plugin.
        --- This function is called when the plugin is loaded.
        --- You may use this function to modify the environment in order to extend the Tealdoc functionality.
        --- @param env The environment in which the plugin is running.
        run: function(env: tealdoc.Env)
    end

    --- Parser is an abstract base interface for Tealdoc parsers.
    --- Parsers are used to process source files and extract documentation items from them.
    --- Parsers must add the items to the `env.registry` table.
    --- Each parser is responsible for a specific set of file extensions.
    --- You can register a parser using the `add_parser` method of the `tealdoc.Env` interface.
    interface Parser
        
        --- Process file contents.
        --- This function is called by Tealdoc when a file with a registered extension is processed.
        --- @param self The parser instance.
        --- @param text The contents of the file as a string.
        --- @param path The path of the file being processed.
        --- @param env The environment in which the parser is running.
        process: function(self, text: string, path: string, env: tealdoc.Env)

        --- A list of file extensions that this parser can handle.
        --- This is used to register the parser in the `tealdoc.Env` environment.
        --- Each extension should start with a dot (e.g. ".lua", ".md").
        file_extensions: {string}
    end


    --- Tag is an abstract base interface for Tealdoc tags.
    --- Tags are used to annotate items with additional metadata.
    --- Tags can be used to provide additional information about an item,
    --- such as parameters, descriptions, or other attributes.
    --- Tags can be registered in the `tealdoc.Env` environment
    --- using the `add_tag` method.
    interface Tag

        --- Context is the context in which the tag is encountered.
        interface Context
            --- The item to which the tag belongs.  
            item: Item
            --- The parameter of the tag if any.
            --- Only applicable if has_param of the tag is true.
            param: string
            --- The description of the tag if any.
            --- Only applicable if has_description of the tag is true.
            description: string
        end
        --- The name of the tag, which is used to identify the tag in the comments.
        name: string
        --- Function which is called when the tag is encountered in the comments.
        --- @param ctx The context in which the tag is encountered.
        handle: function(ctx: Context)
        --- Whether the tag has a parameter.
        --- If true, the tag expects a parameter after the tag name.
        --- For example, `@param name description` has a parameter `name`.
        has_param: boolean
        --- Whether the tag has a description.
        --- If true, the tag expects a description after the tag name or parameter.
        --- For example, `@description This is a description` has a description `This is a description`.
        has_description: boolean
    end

    --- This record represents a location in a file.
    --- It is used to store the location of an item in the source code.
    record Location
        --- The path to the file where the item is located.
        filename: string 
        --- The column number where the item is located.
        x: integer
        --- The line number where the item is located.
        y: integer
    end


    --- Item is an abstract base interface for Tealdoc items.
    --- Items represent documentation entities such as functions, variables, types, etc.
    --- Items can also represent abstract concepts like namespaces or modules.
    interface Item 
        --- The kind of the item, e.g. "function", "variable", "type", etc.
        --- This is used to differentiate between different types of items.
        kind: string
        --- The path to the item, which is used as a unique identifier.
        path: string
        --- The name of the item, which is used for display purposes.
        --- This is usually the same as the last part of the path.
        name: string
        --- The children of the item, which are other items that are related to this item.
        --- This is used to represent hierarchical relationships between items.
        --- For example, a record type may have fields that are also items.
        --- The children are stored as an array of paths of the children.
        children: {string}
        --- The parent of the item, which is the path to the parent item.
        parent: string
        --- The text of the item, which is the documentation content.
        --- This is usually a multiline string that contains the documentation for the item.
        --- It may include markdown or other formatting.
        --- If the item does not have any documentation, this may be nil.
        text: string
        --- The attributes of the item, which are additional metadata.
        attributes: {string: any}
        --- The location of the item in the source code.
        location: Location
    end 


    --- Env is the environment in which Tealdoc operates.
    --- It contains the registry of items, parsers, and tag handlers.
    --- You can use this environment to add new parsers or tag handlers.
    --- You can also use it to access the registry of items.
    record Env
        --- The registry of items, which is a table mapping paths to items.
        --- This is used to store all the items that are processed by Tealdoc.
        --- The keys are the paths of the items, and the values are the items themselves.
        registry: {string: Item} 

        --- The list of modules that are processed by Tealdoc.
        --- This is used to store the names of the modules that are documented.
        modules: {string}

        --- The option to include all items in the output.
        --- If this is true, all items will be included in the output,
        --- regardless of whether they are local or global.
        --- When using the CLI, you can set this option using the `--all` flag.
        include_all: boolean

        --- Whether to skip warnings about missing items.
        --- If this is true, Tealdoc will not log warnings about missing items.
        no_warnings_on_missing: boolean

        --- Add a parser to the environment.
        --- This function registers a parser that can handle specific file extensions.
        --- The parser must implement the `tealdoc.Parser` interface.
        --- @param self The environment to which the parser is added.
        --- @param parser The parser to add.
        add_parser: function(self, parser: Parser)

        --- Add a tag to the environment.
        --- The tag must implement the `tealdoc.Tag` interface. 
        --- @param self The environment to which the tag is added.
        --- @param tag The tag to add.
        add_tag: function(self, tag: Tag)

        --- Initialize a new environment.
        --- This function creates a new environment with empty registries.
        init: function(): Env

        --- @local
        parser_registry: {string: Parser} -- file extension to parser
        --- @local
        tag_registry: {string: Tag} -- tag name to handler
    end

    --- This record represents a type argument for a function or type.
    record Typearg 
        --- The name of the type argument.
        name: string
        --- The constraint of the type argument if any.
        constraint: string
        --- The description of the type argument.
        description: string
    end

    

    --- This interface represents a declaration item in Tealdoc.
    --- It is used to represent declarations of functions, variables, and types.
    interface DeclarationItem is Item
        --- Possible visibilities for declarations.
        enum Visibility 
            --- Local visibility, for local variables and functions.
            "local"
            --- Global visibility, for global variables and functions.
            "global"
            --- Record visibility, for record fields and nested types.
            "record"
        end
        --- The visibility of the declaration.
        visibility: Visibility
    end

    --- This record represents a function item in Tealdoc.
    record FunctionItem 
        is DeclarationItem 
        where self.kind == "function"

        --- This record represents a parameter of a function.
        record Param 
            --- The name of the parameter.
            name: string
            --- The type of the parameter.
            type: string
            --- The description of the parameter.
            description: string
        end

        --- This record represents a return value of a function.
        record Return 
            --- The type of the return value.
            type: string
            --- The description of the return value.
            description: string
        end

        --- Possible function kinds
        enum FunctionKind
            --- Normal function, local, global, or in-record.
            "function"
            --- Macro expansion function
            "macroexp"
            --- Record metamethod
            "metamethod"
        end
        
        --- Function parameters.
        params: {Param}
        --- Function return values.
        returns: {Return}
        --- Function type arguments.
        typeargs: {Typearg}
        --- The kind of the function.
        function_kind: FunctionKind
        --- Whether this function is only a declaration (it does not contain a body).
        is_declaration: boolean -- maybe better name?      
    end

    --- This record represents a variable item in Tealdoc.
    record VariableItem
        is DeclarationItem
        where self.kind == "variable"

        --- The name of the type of the variable.
        typename: string
    end

    --- This record represents a type item in Tealdoc.
    --- It is used to represent types, records, interfaces, enums, and type aliases.
    record TypeItem 
        is DeclarationItem
        where self.kind == "type"

        --- Possible kinds of types.
        enum TypeKind
            --- Type kind for a record type.
            "record"
            --- Type kind for an interface type.
            "interface"
            --- Type kind for an enum type.
            "enum"
            --- Type kind for a type alias.
            "type"
        end

        --- The name of the type of the type item.
        typename: string
        --- The type arguments of the type item.
        --- Only used for records and interfaces.
        typeargs: {Typearg}
        --- The kind of the type item.
        type_kind: TypeKind

        --- Names of inherited types
        inherits: {string}
    end

    --- Process a file with the given path using the parsers registered in the environment.
    --- This function reads the file contents and passes it to the appropriate parser based on the file extension.
    --- If no parser is found for the file extension, a warning is logged and the file is skipped.
    --- @param path The path to the file to process.
    --- @param env The environment in which the file is processed.
    process_file: function(path: string, env: Env)

    --- Process the given text as a file with the specified filename using the parsers registered in the environment.
    --- This function is useful for processing text that is not read from a file, such as
    --- text from a string or a buffer.
    --- If no parser is found for the file extension, a warning is logged and the text is skipped.
    --- @param text The text to process.
    --- @param filename The name of the file being processed, used to determine the file extension.
    --- @param env The environment in which the text is processed.
    process_text: function(text: string, path: string, env: Env)

    --- Current version of Tealdoc.
    version: string 
end

tealdoc.version = "0.2+dev"

function tealdoc.Env.init(): tealdoc.Env
    local env: tealdoc.Env = {
        parser_registry = {},
        tag_registry = {},
        registry = {},
        modules = {},
        add_parser = tealdoc.Env.add_parser,
        add_tag = tealdoc.Env.add_tag,
    }

    return env
end

function tealdoc.Env:add_tag(tag: tealdoc.Tag)
    assert(tag.name and tag.handle)
    if self.tag_registry[tag.name] then
        -- better errors?
        log:error("duplicate tag name detected: '" .. tag.name .. "'. Each tag must have a unique name.")
    end
    self.tag_registry[tag.name] = tag
end

function tealdoc.Env:add_parser(parser: tealdoc.Parser)
    assert(parser.file_extensions)
    for _, ext in ipairs(parser.file_extensions) do
        self.parser_registry[ext] = parser
    end
end


function tealdoc.process_file(path: string, env: tealdoc.Env)
   
    local file = io.open(path, "r")
    if not file then
        log:error("Could not open file: " .. path)
        return
    end
    local text = file:read("*a")
    file:close()

    tealdoc.process_text(text, path, env)
end 

function tealdoc.process_text(text: string, path: string, env: tealdoc.Env)
    local filename = path:match("([^/\\]*)$") or path
    local ext = filename:match("(%.[^%.]+.*)$") or ""
    local parser = env.parser_registry[ext]
    if not parser then
        log:warning("No parser found for file '%s' (extension '%s'). File will be skipped.", path, ext)
        return
    end
    parser:process(text, path, env)
end

return tealdoc