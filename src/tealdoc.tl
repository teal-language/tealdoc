--- @module tealdoc
local log = require("log")

local record tealdoc
    
    interface Parser
        process: function(text: string, filename: string, env: tealdoc.Env)

        file_extensions: {string}
    end

    record TagHandler
        record Context
            item: Item
            param: string
            description: string
        end
        name: string
        handle: function(ctx: Context)
        has_param: boolean
        has_description: boolean
    end

     record Location
        filename: string 
        x: integer
        y: integer
    end

    interface Item 
        kind: string
        path: string
        name: string
        is_namespace: boolean
        children: {string}
        parent: string
        text: string
        attributes: {string: any}
        location: Location
    end 

    record Env
        parser_registry: {string: Parser} -- file extension to parser
        tag_handler_registry: {string: TagHandler} -- tag name to handler
        registry: {string: Item} 
        modules: {string}

        add_parser: function(self, parser: Parser)
        add_tag_handler: function(self, handler: TagHandler)

        init: function(): Env
    end

    record Typearg 
        name: string
        constraint: string
        description: string
    end

    record FunctionItem 
        is Item 
        where self.kind == "function"

        record Param 
            name: string
            type: string
            description: string
        end

        record Return 
            type: string
            description: string
        end

        enum Type
            "local"
            "global"
            "record"
            "macroexp"
            "metamethod"
        end
        
        params: {Param}
        returns: {Return}
        typeargs: {Typearg}
        type: Type
        is_declaration: boolean -- maybe better name?      
    end

    record DirectiveItem 
        is Item
        where self.kind == "directive"

        module_name: string
    end

    record VariableItem
        is Item
        where self.kind == "variable"

        enum Type
            "local"
            "global"
            "record"
        end
    
        typename: string

        type: Type
    end

    record TypeItem 
        is Item
        where self.kind == "type"
        enum Type 
            "local"
            "global"
            "record"
        end

        enum TypeKind -- TODO: better name?
            "record"
            "interface"
            "enum"
            "type"
        end

        typename: string
        type: Type
        typeargs: {Typearg}
        typekind: TypeKind
    end

    process_file: function(path: string, env: Env)
    process_text: function(text: string, filename: string, env: Env)
end

function tealdoc.Env.init(): tealdoc.Env
    local env: tealdoc.Env = {
        parser_registry = {},
        tag_handler_registry = {},
        registry = {},
        modules = {},
        add_parser = tealdoc.Env.add_parser,
        add_tag_handler = tealdoc.Env.add_tag_handler,
    }

    return env
end

function tealdoc.Env:add_tag_handler(handler: tealdoc.TagHandler)
    assert(handler.name and handler.handle)
    if self.tag_handler_registry[handler.name] then
        -- better errors?
        log:error("duplicate tag name detected: '" .. handler.name .. "'. Each tag must have a unique name.")
    end
    self.tag_handler_registry[handler.name] = handler
end

function tealdoc.Env:add_parser(parser: tealdoc.Parser)
    assert(parser.file_extensions)
    for _, ext in ipairs(parser.file_extensions) do
        self.parser_registry[ext] = parser
    end
end


function tealdoc.process_file(path: string, env: tealdoc.Env)
    local filename = path:match("([^/\\]*)$") or path
    local file = io.open(path, "r")
    if not file then
        log:error("Could not open file: " .. path)
        return
    end
    local text = file:read("*a")
    file:close()

    tealdoc.process_text(text, filename, env)
end 

function tealdoc.process_text(text: string, filename: string, env: tealdoc.Env)
    local ext = filename:match("%..*$")
    local parser = env.parser_registry[ext]
    if not parser then
        log:warning("No parser found for file '%s' (extension '%s'). File will be skipped.", filename, ext)
        return
    end 
    parser.process(text, filename, env)
end

return tealdoc