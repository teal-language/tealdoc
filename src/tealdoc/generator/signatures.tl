local Generator = require("tealdoc.generator")
local tealdoc = require("tealdoc")

local attr = Generator.attr

local record signatures
end

local function visibility(item: tealdoc.DeclarationItem): string
    if item.visibility ~= "record" then
        return item.visibility.." "
    end
    return ""
end

local function strip_module_prefix(path: string, module_name: string): string
    if path:sub(1, 1) == "$" then
        path = path:sub(2)
    end
    return path:sub(#module_name + 2) -- +2 for the dot after module name
end


local function get_name(ctx: Generator.Phase.Context, item: tealdoc.Item): string
    if ctx.path_mode == "full" then
        return item.path
    elseif ctx.path_mode == "relative" then
        return ctx.module_name == item.path and item.name or strip_module_prefix(item.path, ctx.module_name)
    else -- "none"
        return item.name
    end
end

function signatures.for_function(ctx: Generator.Phase.Context, fn: tealdoc.FunctionItem, as_record_field?: boolean)
    local params: {string} = {}
    if fn.params then
        for _, param in ipairs(fn.params) do
            if not param.name then
                table.insert(params, param.type or "?")
            else
                table.insert(params, param.name .. ": " .. (param.type or "?"))
            end
        end
    end
    local returns: {string} = {}
    if fn.returns then
        for _, ret in ipairs(fn.returns) do
            table.insert(returns, ret.type or "?")
        end
    end

    local typeargs: {string} = {}
    if fn.typeargs and #fn.typeargs > 0 then
        for _, typearg in ipairs(fn.typeargs) do
            if typearg.constraint then
                table.insert(typeargs, typearg.name .. " is " .. typearg.constraint or "?")
            else
                table.insert(typeargs, typearg.name)
            end
        end
    end

    local name = get_name(ctx, fn)

    -- fix overloaded functions names
    local parent_item = ctx.env.registry[fn.parent]
    assert(parent_item)
    if parent_item.kind == "overloaded" then
        name = get_name(ctx, parent_item)
    end

    if as_record_field then
        if fn.function_kind == "metamethod" then
            ctx.builder:text("metamethod ")
        end
        ctx.builder:link(fn.path, attr("name"), name)
        ctx.builder:text(": function")
    else
        ctx.builder:text(attr("signature"), visibility(fn), fn.function_kind, " ", function()
            ctx.builder:link(fn.path, attr("name"), name)
        end)
    end
    if #typeargs > 0 then
        ctx.builder:text(attr("typeargs"), "<", table.concat(typeargs, ", "), ">")
    end

    ctx.builder:text(attr("params"), "(", table.concat(params, ", "), ")")
    if #returns > 0 then
        ctx.builder:text(attr("returns"), ": ", table.concat(returns, ", "))
    end
end

function signatures.for_variable(ctx: Generator.Phase.Context, var: tealdoc.VariableItem)
    ctx.builder:text(attr("variable"), visibility(var), function() ctx.builder:link(var.path, get_name(ctx, var)) end, ": ", var.typename)
end

function signatures.for_type(ctx: Generator.Phase.Context, item: tealdoc.TypeItem)
    ctx.builder:text(attr("name"), visibility(item), item.type_kind, " ", function () ctx.builder:link(item.path, get_name(ctx, item)) end)
    if item.type_kind == "type" then
        ctx.builder:text(attr("type"), " = ", item.typename)
    elseif item.typeargs and #item.typeargs > 0 then
        local typeargs: {string} = {}
        for _, typearg in ipairs(item.typeargs) do
            if typearg.constraint then
                table.insert(typeargs, typearg.name .. " is " .. typearg.constraint or "?")
            else
                table.insert(typeargs, typearg.name)
            end
        end
        ctx.builder:text(attr("typeargs"), "<", table.concat(typeargs, ", "), ">")

        if item.inherits and #item.inherits > 0 then
            ctx.builder:text(attr("inherits"), " is ", table.concat(item.inherits, ", "))
        end
    end
end

return signatures