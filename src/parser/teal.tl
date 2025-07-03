local tl <const> = require("tl")
local tealdoc = require("tealdoc")
local log = require("log")
local CommentParser = require("comment_parser")
local record VisitState
    env: tealdoc.Env 
    path: string
    module_name: string
    type_report: tl.TypeReport
    typenum_to_path: {integer: string}
    parent_item: tealdoc.Item
end


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
local visit_type: function(t: tl.Type, state: VisitState)

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
    if item is tealdoc.FunctionItem then
        return item.type == "local" or item.type == "macroexp"
    elseif item is tealdoc.VariableItem then
        return item.type == "local"
    elseif item is tealdoc.TypeItem then
        return item.type == "local"
    else
        return false
    end
end

local function is_item_global(item: tealdoc.Item): boolean
    if item is tealdoc.FunctionItem then
        return item.type == "global"
    elseif item is tealdoc.VariableItem then
        return item.type == "global"
    elseif item is tealdoc.TypeItem then
        return item.type == "global"
    else
        return false
    end
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
            assert(old_item.type == "record")  
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
                        "A record function named '%s' is being redefined. The previous definition's comment will be discarded.",
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

local function get_path(item: tealdoc.Item, state: VisitState): string
    assert(item.name)
    if state.module_name == item.name and state.path == state.module_name.."~" then
        return state.module_name
    end
    return state.path..item.name
end

local function store_item(item: tealdoc.Item, state: VisitState): string
    local path = store_item_at_path(item, get_path(item, state), state)
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

local function function_item_for_node(node: tl.Node, typ: tealdoc.FunctionItem.Type, state: VisitState): tealdoc.FunctionItem
    local item: tealdoc.FunctionItem = {
        kind = "function",
        type = typ,
        location = location_for_node(node)
    }
    
    if node.args then 
        item.params = {}
        for i, ar in ipairs(node.args) do 
            item.params[i] = {
                name = ar.tk,
                type = ar.argtype and type_to_string(state.type_report, ar.argtype)
            }
        end
    end
    

    if node.rets then
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

local function item_for_function_type(t: tl.FunctionType | tl.GenericType, typ: tealdoc.FunctionItem.Type, state: VisitState): tealdoc.FunctionItem 
    local item: tealdoc.FunctionItem = {
        kind = "function",
        type = typ,
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

    
    if t.args then 
        item.params = {}
        for i, ar in ipairs(t.args.tuple) do 
            item.params[i] = {
                type = type_to_string(state.type_report, ar)
            }
        end
    end
    

    if t.rets then
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

    local function_type: tealdoc.FunctionItem.Type
    if node.kind == "local_function" then
        function_type = "local"
    elseif node.kind == "global_function" then
        function_type = "global"
    else
        function_type = "record" 
    end
    local item = function_item_for_node(node, function_type, state)
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
    
    local item = function_item_for_node(macrodef, "macroexp", state)
    item.name = name 
    process_comments(node.comments, item, state.env)
    store_item(item, state)
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
        

        local item: tealdoc.VariableItem = {
            kind = "variable",
            name = name.tk,
            typename = typename,
            type = node.kind == "local_declaration" and "local" or "global",
            location = location_for_node(name)
        }

        process_comments(node.comments, item, state.env) 
        store_item(item, state)
    end
end


local record_like_visitor: function(tl.RecordLikeType, VisitState) 

local function enum_visitor(t: tl.EnumType, state: VisitState)
    for value, _ in pairs(t.enumset) do
        local comments = t.value_comments and t.value_comments[value]

        local item: tealdoc.Item = {
            kind = "enumvalue",
            name = value,
            location = location_for_type(t) -- TODO: more specific?
        }

        process_comments(comments, item, state.env)
        store_item(item, state)
    end
end

local function typedecl_visitor(name: string, comments: {tl.Comment}, t: tl.TypeDeclType, typ: tealdoc.TypeItem.Type, state: VisitState)
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
    
    local typekind: tealdoc.TypeItem.TypeKind
    if def is tl.RecordType then
        typekind = "record"
    elseif def is tl.EnumType then
        typekind = "enum"
    elseif def is tl.InterfaceType then
        typekind = "interface"
    else
        typekind = "type"
    end

    local item: tealdoc.TypeItem = {
        kind = "type",
        name = name,
        typename = type_to_string(state.type_report, def),
        typeargs = typeargs,
        type = typ,
        location = location_for_type(t),
        typekind = typekind,
    }

    local path = store_item(item, state)
    
    local typenum = typenum_for_type(state.type_report, t)
    if typenum then
       state.typenum_to_path[typenum] = path 
    end

    process_comments(comments, item, state.env)

    if def is tl.RecordLikeType or def is tl.EnumType then
        local old_path = state.path
        local old_parent = state.parent_item
        state.path = path.."."
        state.parent_item = item
        visit_type(def, state)
        state.path = old_path
        state.parent_item = old_parent
    end
end

local function type_is_function(t: tl.Type): boolean
    if t is tl.GenericType then
        local base = t.t
        return base is tl.FunctionType
    end
    return t is tl.FunctionType
end

record_like_visitor = function(t: tl.RecordLikeType, state: VisitState)
    local function field_visitor(name: string, field_type: tl.Type, comments: {{tl.Comment}}, meta?: boolean)
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
                local item = item_for_function_type(function_type, "record", state)
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
            item = item_for_function_type(field_type as tl.FunctionType | tl.GenericType, meta and "metamethod" or "record", state)
        else
            local field_item: tealdoc.VariableItem = {
                kind = "variable",
                type = "record",
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
        typedecl_visitor(name, node.comments, newtype, node.kind == "local_type" and "local" or "global", state)
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
    if node_visitors[node.kind] then
        node_visitors[node.kind](node, state)
    end
end

local type_visitors: {tl.TypeName: function(t: tl.Type, state: VisitState)} = {
    ["record"] = record_like_visitor,
    ["interface"] = record_like_visitor,
    ["enum"] = enum_visitor
}

visit_type = function(t: tl.Type, state: VisitState) 
    if type_visitors[t.typename] then
        type_visitors[t.typename](t, state)
    end
end

local function parse_toplevel_comments(comments: {tl.Comment}, env: tealdoc.Env): {tealdoc.DirectiveItem}
    if not comments then
        return nil
    end
    local items: {tealdoc.DirectiveItem} = {}

    local in_comment_block = false
    local current_block: {tl.Comment} = {}

    local function end_block() 
        local item: tealdoc.DirectiveItem = {
            kind = "directive",
            location = {
                filename = "", -- TODO!
                x = current_block[1].x,
                y = current_block[1].y
            }
        }
        process_comments(current_block, item, env)
        table.insert(items, item)
        in_comment_block = false
        current_block = {}
    end

    for _, comment in ipairs(comments) do
        if is_long_comment(comment) then
            if in_comment_block then
                end_block()
            end
            table.insert(current_block, comment)
            end_block()
        elseif in_comment_block then
            -- only single line consecutive comments are a block
            if comment.y - current_block[#current_block].y > 1 then
                end_block()
            else
                table.insert(current_block, comment)
            end
        elseif comment.text:match("^%-%-%-") then
            in_comment_block = true     
            table.insert(current_block, comment)
        end
    end

    if in_comment_block then
        end_block()
    end

    return items
end

--- Validates directive comments and finds the module directive
-- @return module item if there is one 
local function validate_directives(items: {tealdoc.DirectiveItem}): tealdoc.DirectiveItem
    local module_item: tealdoc.DirectiveItem
    if items then
        for _, item in ipairs(items) do
            if item.module_name then
                if module_item then 
                    log:error(
                        "Multiple @module directives found: previously defined as '%s', now found as '%s'. Only one @module directive is allowed per file.",
                        module_item.module_name or "<unknown>",
                        item.module_name
                    )
                end
                module_item = item
            end 
        end 
    end
    if not module_item then
        log:error("No @module directive found in the file. Please add a top-level comment with '@module <name>' to specify the module name.")
    end
    return module_item
end

local record TealParser is tealdoc.Parser
end

TealParser.file_extensions = {".tl", ".d.tl"}


function TealParser.process(text: string, filename: string, env: tealdoc.Env)
    -- TODO: handle errors
    local tl_env = tl.new_env()
    tl_env.report_types = true
    local result = tl.check_string(text, tl_env, filename)
    local reporter = result.env.reporter
    local directives = parse_toplevel_comments(result.ast.unattached_comments, env)
    local module_item = validate_directives(directives)
    if not module_item then
        return
    end
    module_item.path = "$"..module_item.module_name
    local state: VisitState = {
        env = env,
        path = module_item.module_name.."~",
        module_name = module_item.module_name,
        type_report = reporter.tr,
        typenum_to_path = {},
        parent_item = module_item
    }
    table.insert(env.modules, module_item.module_name)
    env.registry[module_item.path] = module_item
    visit_node(result.ast, state)
end

return TealParser