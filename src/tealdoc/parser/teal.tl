local tl <const> = require("tl")
local tealdoc = require("tealdoc")
local log = require("tealdoc.log")
local CommentParser = require("tealdoc.comment_parser")
local record VisitState
    env: tealdoc.Env 
    path: string
    module_name: string
    type_report: tl.TypeReport
    typenum_to_path: {integer: string}
    parent_item: tealdoc.Item
    module_item_typeid: integer
end

-- TODO: the locations are wrong for most of the items!


local function typenum_for_position(report: tl.TypeReport, filename: string, x: integer, y: integer): integer
    local rf = report.by_pos[filename]
    if not rf then return end
    local ry = rf[y]
    if not rf then return end
    local typenum = ry[x]
    return typenum
end

local function typeinfo_for_position(report: tl.TypeReport, filename: string, x: integer, y: integer): tl.TypeInfo
    local typenum = typenum_for_position(report, filename, x, y)
    if not typenum then return end
    local typeinfo = report.types[typenum]
    return typeinfo
end

local function typenum_for_global(report: tl.TypeReport, name: string): integer
    local typenum = report.globals[name]
    if not typenum then return end
    return typenum
end

local function typeinfo_for_global(report: tl.TypeReport, name: string): tl.TypeInfo
    local typenum = typenum_for_global(report, name)
    if not typenum then return end
    local typeinfo = report.types[typenum]
    return typeinfo
end

local function typenum_for_node(report: tl.TypeReport, node: tl.Node): integer
    return typenum_for_position(report, node.f, node.x, node.y)
end

local function typeinfo_for_node(report: tl.TypeReport, node: tl.Node): tl.TypeInfo
    return typeinfo_for_position(report, node.f, node.x, node.y)
end

local function typenum_for_type(report: tl.TypeReport, t: tl.Type): integer
    return typenum_for_position(report, t.f, t.x, t.y)
end

local function typeinfo_for_type(report: tl.TypeReport, t: tl.Type): tl.TypeInfo
    return typeinfo_for_position(report, t.f, t.x, t.y)
end

local function location_for_node(node: tl.Node): tealdoc.Location
    return {
        filename = node.f,
        x = node.x,
        y = node.y
    }
end


local function location_for_type(t: tl.Type): tealdoc.Location
    return {
        filename = t.f,
        x = t.x,
        y = t.y
    }
end



-- TODO: improve errors with filenames and locations!

local visit_node: function(node: tl.Node, state: VisitState)
local visit_type: function(t: tl.Type, item: tealdoc.TypeItem, state: VisitState)

local function children_visitor(node: tl.Node, state: VisitState)
    for _, child in ipairs(node) do
        visit_node(child, state)
    end
end

local function is_long_comment(c: tl.Comment): boolean 
    return c.text:match("^%-%-%[(=*)%[") ~= nil
end

local function process_comments(comments: {tl.Comment}, item: tealdoc.Item, env: tealdoc.Env): boolean
    local function strip_long_comment(c: tl.Comment): string
        local text = c.text:gsub("^%-%-%[=*%[", ""):gsub("%]=*%]$", "")
        return text
    end

    local function strip_short_comment(c: tl.Comment): string
        local text = c.text:gsub("^%-+%s*(.-)%s*$", "%1")
        return text
    end

    if not comments then
        return
    end

    local first_comment = comments[1]

    if first_comment and is_long_comment(first_comment) then
        CommentParser.parse_text(strip_long_comment(first_comment), item, env)
        return true
    end

    local lines: {string} = {}
    local in_block = false
    for _, comment in ipairs(comments) do
        if not in_block and comment.text:match("^%-%-%-") then 
           in_block = true 
        end 
        if in_block then
            table.insert(lines, strip_short_comment(comment))
        end
    end
    
    CommentParser.parse_lines(lines, item, env)
    return #lines > 0
end


-- TODO: temporary for now?
local function typeinfo_to_string(typeinfo: tl.TypeInfo): string
    return typeinfo and typeinfo.str
end

local function type_to_string(report: tl.TypeReport, typ: tl.Type): string 
    return typeinfo_to_string(typeinfo_for_type(report, typ))
end


local function is_item_local(item: tealdoc.Item): boolean
    return item is tealdoc.DeclarationItem and item.visibility == "local"
end

local function is_item_global(item: tealdoc.Item): boolean
    return item is tealdoc.DeclarationItem and item.visibility == "global"
end

local function store_item_at_path(item: tealdoc.Item, path: string, state: VisitState): string
    -- this code is a mess!
    local old_item = state.env.registry[path]
    if old_item then
        if is_item_local(item) then
            if old_item.kind == "shadowed" then -- TODO: better name?
                assert(old_item.children)
                path = path.."#"..tostring(#old_item.children + 1)
                table.insert(old_item.children, path)
            else 
                assert(is_item_local(old_item))
                local shadowed_path = old_item.path
                old_item.path = old_item.path.."#1"
                path = path.."#2"
                local shadowed_item: tealdoc.Item = {
                    path = shadowed_path,
                    kind = "shadowed",
                    children = {old_item.path, path},
                    parent = old_item.parent
                }
                
                state.env.registry[old_item.path] = old_item
                state.env.registry[shadowed_path] = shadowed_item
                
                old_item.parent = shadowed_path
                item.parent = shadowed_path
            end
        elseif is_item_global(item) then
            assert(is_item_global(old_item))
            if old_item.text then
                -- TODO: better warning message
                log:warning(
                    "Global declaration of '%s' shadows a previous global declaration with the same name. The comment from the previous declaration will be discarded.",
                    item.name,
                    path
                )
            end
        elseif old_item is tealdoc.FunctionItem and item is tealdoc.FunctionItem then
            -- assert that old_item and item are the same function?

            if old_item.is_declaration then
                if old_item.text and item.text then
                    log:warning("Both the function declaration and definition for this record function contain tealdoc comments. The comment from the declaration will be discarded.")
                elseif not item.text then 
                    return nil -- don't overwrite item we've got from declaration as it was commented so it contains more information
                end    
            else 
                if old_item.text then
                    log:warning(
                        "A function named '%s' is being redefined. The previous definition's comment will be discarded.",
                        item.name
                    )
                end
            end
        else
            assert(false) -- TODO: better error handling
        end
    end
 
    state.env.registry[path] = item
    item.path = path
    return path
end

local function get_path(item: tealdoc.Item, state: VisitState, typ?: tl.Type): string
    assert(item.name)
    if typ and typ.typeid == state.module_item_typeid then
        state.env.registry["$"..state.module_name].text = item.text
        return state.module_name
    end
    return state.path..item.name
end

local function store_item(item: tealdoc.Item, state: VisitState, typ?: tl.Type): string
    local path = store_item_at_path(item, get_path(item, state, typ), state)
    if not path then return end
    if not item.parent then
        if not state.parent_item.children then
            state.parent_item.children = {}
        end
        table.insert(state.parent_item.children, path)
        item.parent = state.parent_item.path
    end
    return path
end

local function function_item_for_node(node: tl.Node, visibility: tealdoc.DeclarationItem.Visibility, kind: tealdoc.FunctionItem.FunctionKind, state: VisitState): tealdoc.FunctionItem
    local item: tealdoc.FunctionItem = {
        kind = "function",
        function_kind = kind,
        visibility = visibility,
        location = location_for_node(node)
    }
    
    if node.args and #node.args > 0 then 
        item.params = {}
        for i, ar in ipairs(node.args) do 
            if node.is_method and i == 1 then
                item.params[i] = {
                    name = "self",
                    type = typeinfo_to_string(typeinfo_for_node(state.type_report, node.fn_owner))
                }
            else
                item.params[i] = {
                    name = ar.tk,
                    type = ar.argtype and type_to_string(state.type_report, ar.argtype)
                }
            end
        end
    end
    

    if node.rets and #node.rets.tuple > 0 then
        item.returns = {}
        for i, ret in ipairs(node.rets.tuple) do
            item.returns[i] = {
                type = type_to_string(state.type_report, ret)
            }
        end
    end

    if node.typeargs then
        item.typeargs = {}
        for i, typearg in ipairs(node.typeargs) do
            item.typeargs[i] = {
                name = typearg.typearg,
                constraint = typearg.constraint and type_to_string(state.type_report, typearg.constraint)
            }
        end 
    end

    return item
end

local function item_for_function_type(t: tl.FunctionType | tl.GenericType, visibility: tealdoc.DeclarationItem.Visibility, kind: tealdoc.FunctionItem.FunctionKind, state: VisitState, owner?: tl.Type): tealdoc.FunctionItem 
    local item: tealdoc.FunctionItem = {
        kind = "function",
        function_kind = kind,
        visibility = visibility,
        is_declaration = true,
        location = location_for_type(t)
    }
    
    if t is tl.GenericType then
        local base = t.t
        assert(base is tl.FunctionType)
        
        item.typeargs = {}
        for i, typearg in ipairs(t.typeargs) do
            local normalized = typearg.typearg:gsub("@.*", "") -- ?
            item.typeargs[i] = {
                name = normalized,
                constraint = typearg.constraint and type_to_string(state.type_report, typearg.constraint)
            }
        end 

        t = base   
    end
    t = t as tl.FunctionType

    
    if t.args and #t.args.tuple > 0 then 
        item.params = {}
        for i, ar in ipairs(t.args.tuple) do 
            if t.is_method and i == 1 and owner then
                item.params[i] = {
                    name = "self",
                    type = typeinfo_to_string(typeinfo_for_type(state.type_report, owner))
                }
            else
                item.params[i] = {
                    type = type_to_string(state.type_report, ar)
                }
            end
        end
    end
    

    if t.rets and #t.rets.tuple > 0 then
        item.returns = {}
        for i, ret in ipairs(t.rets.tuple) do
            item.returns[i] = {
                type = type_to_string(state.type_report, ret)
            }
        end
    end
    
    return item
end

local function function_visitor(node: tl.Node, state: VisitState)
    assert(node.kind == "local_function" or node.kind == "global_function" or node.kind == "record_function")

    local old_path = state.path
    local old_parent = state.parent_item

    local is_record = node.kind == "record_function"
    if is_record then
        assert(node.fn_owner)
        local typenum = typenum_for_node(state.type_report, node.fn_owner)
        assert(typenum)
        local parent_path = state.typenum_to_path[typenum]
        assert(parent_path)
        state.path = parent_path.."."
        local parent = state.env.registry[parent_path]
        assert(parent)
        state.parent_item = parent
    end

    assert(node.name.kind == "identifier")
    local name = node.name.tk

    local visibility: tealdoc.DeclarationItem.Visibility
    if node.kind == "local_function" then
        visibility = "local"
    elseif node.kind == "global_function" then
        visibility = "global"
    else
        visibility = "record" 
    end
    local item = function_item_for_node(node, visibility, "normal", state)
    item.name = name
    process_comments(node.comments, item, state.env)
    local path = store_item(item, state)
    
    local parent_item: tealdoc.Item = item
    if is_record and not path then 
        -- in some cases we don't store the item we created here and discard it
        -- so we need to get the currently store item with this path
        -- TODO: kinda hacky?
        parent_item = state.env.registry[state.path..name]
    end

    state.path = state.path..name.."~"
    state.parent_item = parent_item
    visit_node(node.body, state)
    state.path = old_path
    state.parent_item = old_parent
end

local function macroexp_visitor(node: tl.Node, state: VisitState)
    assert(node.kind == "local_macroexp")
    
    assert(node.name.kind == "identifier")
    local name = node.name.tk     

    local macrodef = node.macrodef
    assert(macrodef.kind == "macroexp")
    
    local item = function_item_for_node(macrodef, "local", "macroexp", state)
    item.name = name 
    process_comments(node.comments, item, state.env)
    store_item(item, state)
end

local function type_is_function(t: tl.Type): boolean
    if t is tl.GenericType then
        local base = t.t
        return base is tl.FunctionType
    end
    return t is tl.FunctionType
end


local function variable_declarations_visitor(node: tl.Node, state: VisitState) 
    assert(node.kind == "local_declaration" or node.kind == "global_declaration")
    for i, name in ipairs(node.vars) do 
        assert(name.kind == "identifier")
        local decltype = node.decltuple.tuple[i] 
        local typename: string

        if decltype then
            typename = type_to_string(state.type_report, decltype)
        elseif node.kind == "local_declaration" then
            typename = typeinfo_to_string(typeinfo_for_node(state.type_report, name)) 
        elseif node.kind == "global_declaration" then
            typename = typeinfo_to_string(typeinfo_for_global(state.type_report, name.tk))
        end
        
        local item: tealdoc.Item
        if decltype and type_is_function(decltype) then -- what about inferred types??
            item = item_for_function_type(decltype as tl.FunctionType | tl.GenericType, node.kind == "local_declaration" and "local" or "global", "normal", state)
            item.is_declaration = true
        else
            local variable_item = {
                kind = "variable",
                typename = typename,
                visibility = node.kind == "local_declaration" and "local" or "global",
                location = location_for_node(name)
            }
            item = variable_item
        end
        item.name = name.tk

        process_comments(node.comments, item, state.env) 
        store_item(item, state)
    end
end


local record_like_visitor: function(tl.RecordLikeType, tealdoc.TypeItem, VisitState) 

local function enum_visitor(t: tl.EnumType, _: tealdoc.TypeItem, state: VisitState)
    -- Extract enum values into a sorted array for stable order
    local values: {string} = {}
    for value, _ in pairs(t.enumset) do
        table.insert(values, value)
    end
    table.sort(values)

    for _, value in ipairs(values) do
        local comments = t.value_comments and t.value_comments[value]
        
        local item: tealdoc.Item = {
            kind = "enumvalue",
            name = "\""..value.."\"",
            location = location_for_type(t) -- TODO: more specific?
        }

        process_comments(comments, item, state.env)
        store_item(item, state)
    end
end

local function typedecl_visitor(name: string, comments: {tl.Comment}, t: tl.TypeDeclType, visibility: tealdoc.DeclarationItem.Visibility, state: VisitState)
    local def = t.def
    local typeargs: {tealdoc.Typearg}
    
    if def is tl.GenericType and def.typeargs then
        typeargs = {}
        for i, typearg in ipairs(def.typeargs) do
            typeargs[i] = {
                name = typearg.typearg,
                constraint = typearg.constraint and type_to_string(state.type_report, typearg.constraint) 
            }
        end
        def = def.t
    end
    
    local typekind: tealdoc.TypeItem.TypeKind = "type"
    if def.typename == "record" then
        typekind = "record"
    elseif def.typename == "enum" then
        typekind = "enum"
    elseif def.typename == "interface" then
        typekind = "interface"
    end

    local item: tealdoc.TypeItem = {
        kind = "type",
        name = name,
        typename = type_to_string(state.type_report, def),
        typeargs = typeargs,
        visibility = visibility,
        location = location_for_type(t),
        type_kind = typekind,
    }
    process_comments(comments, item, state.env)

    local path = store_item(item, state, t)
    
    local typenum = typenum_for_type(state.type_report, t)
    if typenum then
       state.typenum_to_path[typenum] = path 
    end

    if def is tl.RecordLikeType or def is tl.EnumType then
        local old_path = state.path
        local old_parent = state.parent_item
        state.path = path.."."
        state.parent_item = item
        visit_type(def, item, state)
        state.path = old_path
        state.parent_item = old_parent
    end
end



record_like_visitor = function(t: tl.RecordLikeType, declaration: tealdoc.TypeItem, state: VisitState)
    -- TODO: should we somehow store the contents of where clause to generate more matching signatures? 

    -- TODO: mess!
    local inherited_field_has_comments: {string: boolean} = {}
    local inherited_metafield_has_comments: {string: boolean} = {}

    -- to avoid duplicated interfaces in the interface_list
    local visited_typeids: {integer: boolean} = {}
    if t.interface_list then
        if not declaration.inherits then
            declaration.inherits = {}
        end
        for _, iface in ipairs(t.interface_list) do
            if iface is tl.NominalType then
                local resolved = iface.resolved
                if not visited_typeids[resolved.typeid] then
                    visited_typeids[resolved.typeid] = true
                    table.insert(declaration.inherits, type_to_string(state.type_report, iface))
            
                    if resolved is tl.RecordLikeType then
                        for field_name, _ in pairs(resolved.fields) do
                            inherited_field_has_comments[field_name] = resolved.field_comments and resolved.field_comments[field_name] ~= nil or false
                        end
                        if resolved.meta_fields then
                            for field_name, _ in pairs(resolved.meta_fields) do
                                inherited_metafield_has_comments[field_name] = resolved.meta_field_comments and resolved.meta_field_comments[field_name] ~= nil or false
                            end
                        end
                    end
                end
            elseif iface is tl.ArrayType then
                table.insert(declaration.inherits, type_to_string(state.type_report, iface))
            end
        end
    end

    local function field_visitor(name: string, field_type: tl.Type, comments: {{tl.Comment}}, meta?: boolean)
        -- here we assume that if the inherited field is shadowed that it has the same type 
        if inherited_field_has_comments[name] ~= nil then -- is a inherited field 
            if comments and inherited_field_has_comments[name] then
                log:warning("Field '%s' in record '%s' has comments both in the record and in the interface it inherits from. The comments from the interface will be discarded.", name, t.typename)
            elseif not comments then
                return
            end
        end 
        -- inner type declarations
        if field_type is tl.TypeDeclType then
            local c: {tl.Comment}
            if comments then
                assert(#comments == 1)
                c = comments[1]
            end
            
            typedecl_visitor(name, c, field_type, "record", state)
            return
        end

        -- polymorphic functions
        if field_type is tl.PolyType then
             local overload_item: tealdoc.Item = {
                kind = "overload",
                name = name,
                children = {}
            }

            local base_path = store_item(overload_item, state)
            
            for i, function_type in ipairs(field_type.types) do
                local item = item_for_function_type(function_type, "record", "normal", state, t)
                item.name = name
                local param_types: {string} = {}
                for param_idx, param in ipairs(item.params) do
                    param_types[param_idx] = param.type
                end
                 
                local path = base_path.."("..table.concat(param_types, ", ")..")"
                store_item_at_path(item, path, state)
                item.parent = base_path
                table.insert(overload_item.children, path)
                if comments then
                    process_comments(comments[i], item, state.env)
                end
                
            end
            return
        end

        local item: tealdoc.Item

        if type_is_function(field_type) then
            item = item_for_function_type(field_type as tl.FunctionType | tl.GenericType, "record", meta and "metamethod" or "normal", state, t)
                
        else
            local field_item: tealdoc.VariableItem = {
                kind = "variable",
                visibility = "record",
                typename = type_to_string(state.type_report, field_type),
                location = location_for_type(field_type)
            }
            item = field_item
        end
        item.name = name

        if comments then
            assert(#comments == 1)
            process_comments(comments[1], item, state.env)
        end

        store_item(item, state)
    end

    for _, field_name in ipairs(t.field_order) do
        local field_type = t.fields[field_name]
        local comments: {{tl.Comment}}
        if t.field_comments then
            comments = t.field_comments[field_name]
        end

        field_visitor(field_name, field_type, comments)
    end
    if t.meta_fields then
        local metafields_item: tealdoc.Item = { -- we need a special item for metafields to avoid name conflicts
            kind = "metafields",
            name = "$meta",
        }
        local old_path = state.path
        local old_parent = state.parent_item 
        state.path = store_item(metafields_item, state) .. "."
        state.parent_item = metafields_item
        for _, field_name in ipairs(t.meta_field_order) do
            local field_type = t.meta_fields[field_name]
            local comments: {{tl.Comment}}
            if t.field_comments then
                comments = t.field_comments[field_name]
            end

            field_visitor(field_name, field_type, comments, true)
        end
        state.path = old_path
        state.parent_item = old_parent
    end
end 



local function type_declaration_visitor(node: tl.Node, state: VisitState)
    assert(node.kind == "local_type" or node.kind == "global_type")
    assert(node.var.kind == "identifier")
    local name = node.var.tk
    if node.value then -- what to do for types without values! 
        local newtype = node.value.newtype
        if newtype then
            typedecl_visitor(name, node.comments, newtype, node.kind == "local_type" and "local" or "global", state)
        end
    end 
end


local function if_visitor(node: tl.Node, state: VisitState)
    assert(node.kind == "if")
    for _, block in ipairs(node.if_blocks) do
        visit_node(block, state)
    end
end

local function body_visitor(node: tl.Node, state: VisitState) 
    assert(node.body)
    visit_node(node.body, state)
end

local node_visitors: {tl.NodeKind: function(node: tl.Node, state: VisitState)}  = {
    ["statements"] = children_visitor,
    ["local_function"] = function_visitor,
    ["global_function"] = function_visitor,
    ["record_function"] = function_visitor,
    ["local_declaration"] = variable_declarations_visitor,
    ["global_declaration"] = variable_declarations_visitor,
    ["local_type"] = type_declaration_visitor,
    ["global_type"] = type_declaration_visitor,
    ["local_macroexp"] = macroexp_visitor,
    ["do"] = body_visitor,
    ["if"] = if_visitor,
    ["if_block"] = body_visitor,
    ["forin"] = body_visitor,
    ["fornum"] = body_visitor,
    ["while"] = body_visitor,
    ["repeat"] = body_visitor
}

visit_node = function(node: tl.Node, state: VisitState) 
    if node.f == "@internal" then
        return
    end
    if node_visitors[node.kind] then
        node_visitors[node.kind](node, state)
    end
end

local type_visitors: {tl.TypeName: function(t: tl.Type, item: tealdoc.TypeItem, state: VisitState)} = {
    ["record"] = record_like_visitor,
    ["interface"] = record_like_visitor,
    ["enum"] = enum_visitor
}

visit_type = function(t: tl.Type, item: tealdoc.TypeItem, state: VisitState) 
    if type_visitors[t.typename] then
        type_visitors[t.typename](t, item, state)
    end
end

local record TealParser is tealdoc.Parser
    source_dir: string
    tl_env: tl.Env
    typenum_to_path: {integer: string}
end

local function get_sourcedir_from_config(): string
    local path_separator = package.config:sub(1, 1)
    local filename = "tlconfig.lua"
    local file: FILE = nil
    for _ = 1, 20 do
        file = io.open(filename, "r")
        if file then
            break
        end
        filename = ".." .. path_separator .. filename
    end

    if not file then
        log:debug("Could not find tlconfig.tl in the current directory or any parent directory.")
        return ""
    end

    local contents = file:read("*a")
    if contents then
        local load_config, err = load(contents)
        if not load_config then
            log:error("Error loading tlconfig.lua:\n" .. err)
            return ""
        end
        local ok, config = pcall(load_config)
        if not ok then
            log:error("Error executing tlconfig.lua:\n" .. tostring(config))
            return ""
        end

        if config is table then
            local source_dir = config.source_dir
            if source_dir and source_dir is string then
                return source_dir
            else
                log:debug("tlconfig.lua does not contain 'source_dir' field.")
                return ""
            end
        else
            log:error("tlconfig.lua did not return a table.")
            return ""
        end
    end
end 

function TealParser.init(source_dir?: string): TealParser
    source_dir = source_dir or get_sourcedir_from_config()

    log:debug("TealParser initialized with source directory: \"" .. tostring(source_dir).."\"")

    local parser: TealParser = {
        source_dir = source_dir,
        file_extensions = TealParser.file_extensions,
        tl_env = tl.new_env(),
        typenum_to_path = {}
    }
    parser.tl_env.report_types = true

    local self = setmetatable(parser, {__index = TealParser})
    return self
end

TealParser.file_extensions = {".tl", ".d.tl"}


local function get_module_name_from_path(path: string, source_dir: string): string
    local path_separator = package.config:sub(1, 1)
        
    -- Remove source_dir prefix if present
    local relative_path = path
    if source_dir and  source_dir ~= "" then
        local source_dir_pattern = source_dir:gsub("([^%w])", "%%%1")
        if path:find("^" .. source_dir_pattern) then
            relative_path = path:sub(#source_dir + 1)
            -- Remove leading path separator
            if relative_path:sub(1, 1) == path_separator then
                relative_path = relative_path:sub(2)
            end
        end
    end
    
    -- Split path into components
    local components: {string} = {}
    for component in relative_path:gmatch("[^" .. path_separator .. "]+") do
        table.insert(components, component)
    end
    
    if #components == 0 then
        return ""
    end
    
    -- Remove file extension from last component
    local last = components[#components]
    components[#components] = last:match("^([^%.]+)") or last
    
    return table.concat(components, ".")
end

function TealParser:process(text: string, path: string, env: tealdoc.Env)
    -- TODO: handle errors
    local result = tl.check_string(text, self.tl_env, path)
    
    local reporter = result.env.reporter

    local module_name = get_module_name_from_path(path, self.source_dir)
    log:info("Processing Teal module '%s' from file '%s'", module_name, path)

    local module_item: tealdoc.Item = {
        kind = "module",
        name = module_name,
        location = {
            filename = path,
            x = 1,
            y = 1
        },
        children = {},
        path = "$"..module_name,
    }

    local state: VisitState = {
        env = env,
        path = module_name.."~",
        module_name = module_name,
        type_report = reporter.tr,
        typenum_to_path = self.typenum_to_path,
        parent_item = module_item,
        module_item_typeid = result.type.typeid
    }
    table.insert(env.modules, module_name)
    env.registry[module_item.path] = module_item
    visit_node(result.ast, state)
end

return TealParser