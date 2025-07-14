local log = require("tealdoc.log")
local tealdoc = require("tealdoc")
local TealParser = require("tealdoc.parser.teal")
local MarkdownInput = require("tealdoc.parser.markdown")

local Generator = require("tealdoc.tool.generator")

local record DefaultEnv
end

function DefaultEnv.init(): tealdoc.Env
    local env = tealdoc.Env.init()

    env:add_parser(TealParser)
    env:add_parser(MarkdownInput)

    -- TODO: better place for this
    local module_tag_handler: tealdoc.Tag = {
        name = "module",
        has_param = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not (item.kind == "directive") then
                log:error("module tag can only exists in directives")
                return
            end
            if item.attributes and item.attributes["module_name"] then
                log:error(
                    "Multiple @module tags found in the same comment block: previously defined as '%s', now found as '%s'. Only one @module tag is allowed per top-level comment.",
                    ctx.item.attributes["module"],
                    ctx.param
                )
            end
            if not item.attributes then
                item.attributes = {}
            end
            -- TODO: validate module name?
            item.attributes["module_name"] = ctx.param
        end
    }

    -- TODO: should we check if all params and typeargs are documented?

    local param_tag_handler: tealdoc.Tag = {
        name = "param",
        has_param = true,
        has_description = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem then
                log:error(
                    "@param tag can only exist in function comments (%s:%s:%s)",
                    item.location.filename,
                    item.location.y,
                    item.location
                )
                return
            end

            local param: tealdoc.FunctionItem.Param
            if item.params then
                for _, p in ipairs(item.params) do
                    if p.description == nil then
                        param = p
                        break
                    end
                end
            end
            if not param then
                log:warning(
                    "Found more @param tags than declared parameters in function '%s' (%s:%s:%s)",
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return 
            end

            if param.name and param.name ~= ctx.param then
                log:warning(
                    "Parameter name mismatch: expected '%s', got '%s' in function '%s' (%s:%s:%s)",
                    param.name,
                    ctx.param,
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
            end
            param.name = ctx.param
            param.description = ctx.description
        end
    }

    local typearg_tag_handler: tealdoc.Tag = { -- TODO: improve!
        name = "typearg",
        has_param = true,
        has_description = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem and not item is tealdoc.TypeItem then
                log:error(
                    "@typearg tag can only exist in function or type comments (%s:%s:%s)",
                    item.location.filename,
                    item.location.y,
                    item.location
                )
                return
            end

            local typearg: tealdoc.Typearg
            if item.typeargs then
                for _, t in ipairs(item.typeargs) do
                    if t.description == nil then
                        typearg = t
                        break
                    end
                end
            end
            if not typearg then
                log:warning(
                    "Found more @typearg tags than declared type arguments in '%s' (%s:%s:%s)",
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return 
            end

            if typearg.name and typearg.name ~= ctx.param then
                log:warning(
                    "Typearg name mismatch: expected '%s', got '%s' in '%s' (%s:%s:%s)",
                    typearg.name,
                    ctx.param,
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
            end
            typearg.name = ctx.param
            typearg.description = ctx.description
        end
    }

    local return_tag_handler: tealdoc.Tag = {
        name = "return",
        has_description = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem then
                log:error("return tag can only exist in function comments")
                return
            end
            
            local matched = false
            if item.returns then
                for _, ret in ipairs(item.returns) do
                    if not ret.description then
                        ret.description = ctx.description
                        matched = true
                        break
                    end
                end 
            end
            if not matched then
                log:error(
                "Found more @return tags than declared return values in function '%s'. Each @return tag should correspond to a return value in the function signature.",
                item.name
                )
            end
        end
    }

    local local_tag_handler: tealdoc.Tag = {
        name = "local",
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item.attributes then
                item.attributes = {}
            end
            item.attributes["local"] = true
        end
    }

    env:add_tag(module_tag_handler)
    env:add_tag(return_tag_handler)
    env:add_tag(param_tag_handler)
    env:add_tag(typearg_tag_handler)
    env:add_tag(local_tag_handler)
    
    -- TODO: better place for this
    local module_header_phase: Generator.Phase = {
        name = "module_header",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item.kind == "directive" and item.attributes["module_name"])

            local b = generator.builder

            b:h1("Module: " .. (item.attributes["module_name"] as string))
            b:line(item.text or "")
        end
    }

    local header_phase: Generator.Phase = {
        name = "header",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            local path = item.path
            -- should we construct the display path in parser?
            local display_path = path:gsub("%$[^%.]*%.", "")

            generator.builder:h2(display_path)
        end
    }

    local text_phase: Generator.Phase = {
        name = "text",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            if item.text then
                generator.builder:line(item.text)
            end
        end
    }

    local function_signature_phase: Generator.Phase = {
        name = "function_signature",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)

            local params: {string} = {}
            for _, param in ipairs(item.params) do
                if not param.name then
                    table.insert(params, param.type or "?")
                else
                    table.insert(params, param.name .. ": " .. (param.type or "?"))
                end
            end
            local returns: {string} = {}
            for _, ret in ipairs(item.returns) do
                table.insert(returns, ret.type or "?")
            end

            local typeargs: {string} = {}
            if item.typeargs and #item.typeargs > 0 then
                for _, typearg in ipairs(item.typeargs) do
                    if typearg.constraint then
                        table.insert(typeargs, typearg.name .. " is " .. typearg.constraint or "?")
                    else
                        table.insert(typeargs, typearg.name)
                    end
                end
            end

            local b = generator.builder

            b:code_block(function()
                if item.visibility ~= "record" then
                    b:text(item.visibility, " ")
                end

                if item.visibility == "record" then -- TODO: metamethods!
                    local parent = item.parent
                    local parent_item = env.registry[parent]
                    if parent_item and parent_item.kind == "overload" then 
                        -- signature fix for overloaded functions so we don't repeat the params
                        b:text(parent_item.path)
                    else
                        b:text(item.path)
                    end
                else
                    b:text(item.visibility, " ", item.name)
                end

                if #typeargs > 0 then
                    b:text("<", table.concat(typeargs, ", "), ">")
                end

                b:text("(", table.concat(params, ", "), ")")
                if #returns > 0 then
                    b:text(": ", table.concat(returns, ", "))
                end
                b:line()
            end)
        end
    }

    local variable_signature_phase: Generator.Phase = {
        name = "variable_signature",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item is tealdoc.VariableItem)

            local b = generator.builder
            b:code_block(function()
                if item.visibility ~= "record" then
                    b:text(item.visibility, " ", item.name)
                else
                    b:text(item.path)
                end
                b:text(": ", item.typename)
                b:line()
            end)
        end
    }

    local type_signature_phase: Generator.Phase = {
        name = "type_signature",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem)

            local b = generator.builder
            b:code_block(function()
                if item.visibility ~= "record" then
                    b:text(item.visibility, " ")
                end

                b:text(item.type_kind, " ")

                if item.visibility == "record" then
                    b:text(item.path)
                else
                    b:text(item.name)
                end

                if item.type_kind == "type" then
                    b:text(" = ", item.typename)
                end

                if item.typeargs and item.type_kind ~= "type" then -- don't repeat typeargs from type
                    local typeargs: {string} = {}
                    for _, typearg in ipairs(item.typeargs) do
                        if typearg.constraint then
                            table.insert(typeargs, typearg.name .. " is " .. typearg.constraint or "?")
                        else
                            table.insert(typeargs, typearg.name)
                        end
                    end
                    b:text("<", table.concat(typeargs, ", "), ">")
                end

                if item.type_kind == "interface" or item.type_kind == "record" then
                    if item.inherits and #item.inherits > 0 then
                        b:text(" is ", table.concat(item.inherits, ", "))
                    end
                end

                b:line("")
            end)
        end
    }

    local type_params_phase: Generator.Phase = {
        name = "type_params",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem or item is tealdoc.FunctionItem)

            if not item.typeargs or #item.typeargs == 0 then
                return
            end

            local b = generator.builder

            b:h4("Type Parameters")
            b:unordered_list(function(list_item: function(content: function))
                for _, typearg in ipairs(item.typeargs) do
                    list_item(function()
                        b:text(b:b(b:code(typearg.name or "?")))

                        if typearg.constraint then
                            b:text(" ( is ", b:code(typearg.constraint), ")")
                        end                                 
                    
                        if typearg.description then
                            b:text(" — ",typearg.description)
                        end
                    end)
                end
            end)
        end
    }

    local function_params_phase: Generator.Phase = {
        name = "function_params",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)

            if not item.params or #item.params == 0 then
                return
            end

            local b = generator.builder

            b:h4("Parameters")
            b:unordered_list(function(list_item: function(content: function)) -- TODO!
                for _, param in ipairs(item.params) do
                    list_item(function()
                        if param.name then
                            b:text(b:b(b:code(param.name)))
                        end
                        b:text(" (", b:code(param.type or "?"), ")")
                        if param.description then
                            b:text(" — ", param.description)
                        end
                    end)
                end
            end)
        end
    }

    local function_returns_phase: Generator.Phase = {
        name = "function_returns",
        run = function(generator: Generator.Base, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)

            if not item.returns or #item.returns == 0 then
                return
            end

            local b = generator.builder

            b:h4("Returns")

            b:ordered_list(function(list_item: function(content: function))
                for _, ret in ipairs(item.returns) do
                    list_item(function()
                        b:text("(", b:code(ret.type or "?"), ")")
                        
                        if ret.description then
                            b:text(" — ", ret.description)
                        end
                    end)
                end
            end)
        end
    }

    Generator.item_phases["directive"] = {module_header_phase}
    Generator.item_phases["function"] = {header_phase, function_signature_phase, text_phase, type_params_phase, function_params_phase, function_returns_phase}
    Generator.item_phases["variable"] = {header_phase, variable_signature_phase, text_phase}
    Generator.item_phases["type"] = {header_phase, type_signature_phase, text_phase, type_params_phase}
    Generator.item_phases["enumvalue"] = {header_phase, text_phase}
    Generator.item_phases["markdown"] = {text_phase}

    return env
end

return DefaultEnv