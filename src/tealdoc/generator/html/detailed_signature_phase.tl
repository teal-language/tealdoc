local Generator = require("tealdoc.generator")
local tealdoc = require("tealdoc")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local signatures = require("tealdoc.generator.signatures")

local signature: function(ctx: Generator.Phase.Context, item: tealdoc.Item, indent?: string, force_open?: boolean): boolean

-- potentially we could cache partials of signatures in order to improve performance
local function detailed_signature_for_structure_type(ctx: Generator.Phase.Context, item: tealdoc.TypeItem, indent: string, force_open?: boolean)
    assert(item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum", "Expected record or interface type, got: " .. item.type_kind)

    local has_collapsible_children = false
    local is_record_module = ctx.module_name == item.path
    local categories: {string: {tealdoc.Item}}
    local categories_order: {string}

    if is_record_module then
        categories_order, categories = Generator.categories_for_module_record(item, ctx.env)
        for _, children in pairs(categories) do
            for _, child in ipairs(children) do
                if child is tealdoc.TypeItem and (child.type_kind == "record" or child.type_kind == "interface" or child.type_kind == "enum") then
                    has_collapsible_children = true
                    break
                end
            end
            if has_collapsible_children then break end
        end
    elseif item.children then
        for _, child_path in ipairs(item.children) do
            local child_item = ctx.env.registry[child_path]
            if child_item and child_item is tealdoc.TypeItem and (child_item.type_kind == "record" or child_item.type_kind == "interface" or child_item.type_kind == "enum") then
                has_collapsible_children = true
                break
            end
        end
    end
    if indent == "" and has_collapsible_children then
        ctx.builder:rawtext("<div class=\"signature-controls\"><button title=\"Expand all\" onclick=\"expandAll(this)\">[Expand All]</button> <button title=\"Collapse all\" onclick=\"collapseAll(this)\">[Collapse All]</button></div>")
    end

    ctx.builder:rawtext("<details style=\"display: inline-block;\""..((indent == "" or force_open) and " open" or "")..">")    
    
    ctx.builder:rawtext("<summary>")
    signatures.for_type(ctx, item)
    ctx.builder:rawtext("</summary>")

    local old_path_mode = ctx.path_mode
    ctx.path_mode = "none" -- no need to show full path in detailed signature

    if is_record_module then
        for idx, category in ipairs(categories_order) do
            if idx ~= 1 then -- prevent record members starting with empty line
                ctx.builder:line()
            end
            if category:sub(1, 1) ~= "$" then -- skip special categories
                ctx.builder:line(indent.."  ", "-- ", category)
            end
            for _, child in ipairs(categories[category]) do
                if signature(ctx, child, indent.."  ", true) then
                    ctx.builder:line()
                end
            end
        end
    elseif item.children then
        for _, child in ipairs(item.children) do
            local child_item = ctx.env.registry[child]
            assert(child_item, "Child item not found: " .. child)
            if signature(ctx, child_item, indent.."  ") then
                ctx.builder:line()
            end
        end
    end
    ctx.path_mode = old_path_mode -- restore mode
    ctx.builder:rawtext("end")
    ctx.builder:rawtext("</details>")
end


signature = function(ctx: Generator.Phase.Context, item: tealdoc.Item, indent?: string, force_open?: boolean): boolean
    if not indent then
        indent = ""
    end

    if item is tealdoc.FunctionItem then
        ctx.builder:rawtext(indent)
        signatures.for_function(ctx, item, indent ~= "")
        return true
    elseif item is tealdoc.VariableItem then
        ctx.builder:rawtext(indent)
        signatures.for_variable(ctx, item)
        if item.children then -- table variables may contain functions attached functions
            for _, child in ipairs(item.children) do
                ctx.builder:line()
                local child_item = ctx.env.registry[child]
                assert(child_item, "Child item not found: " .. child)
                assert(child_item is tealdoc.FunctionItem, "Expected function item, got: " .. child_item.kind)
                if not ctx.filter or ctx.filter(child_item, ctx.env) then
                    signature(ctx, child_item, indent)
                end
            end
        end
        return true
    elseif item is tealdoc.TypeItem then
        ctx.builder:rawtext(indent)
        if item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum" then
            detailed_signature_for_structure_type(ctx, item, indent, force_open)
        else
            signatures.for_type(ctx, item)
        end
        return true
    elseif item.kind == "enumvalue" then
        ctx.builder:rawtext(indent)
        ctx.builder:link(item.path, item.name)
        return true
    elseif item.kind == "overload" or item.kind == "metafields" then
        local any_has_signature = false
        for i, child in ipairs(item.children) do
            local child_item = ctx.env.registry[child]
            assert(child_item, "Child item not found: " .. child)
            assert(child_item is tealdoc.FunctionItem, "Expected function item, got: " .. child_item.kind)
            
            if not ctx.filter or ctx.filter(child_item, ctx.env) then
                any_has_signature = any_has_signature or signature(ctx, child_item, indent)
            end
            if i ~= #item.children then
                ctx.builder:line()
            end

        end
        return any_has_signature
    end
    return false
end

--- Generator.Phase for html generator that creates detailed signatures
local detailed_signature_phase: Generator.Phase = {
    name = "detailed_signature",
    run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
        assert(item is tealdoc.TypeItem or item.kind == "module")
        local builder = ctx.builder
        assert(builder is HTMLBuilder, "Expected HTMLBuilder")
        builder:code_block(function()
            if item is tealdoc.TypeItem then
                if item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum" then
                    detailed_signature_for_structure_type(ctx, item, "")
                else
                    signature(ctx, item)
                end
            else
                local category_order, categories = Generator.categories_for_module(item, ctx.module_name, ctx.env)
                for _, category in ipairs(category_order) do
                    if categories[category] then
                        for _, child in ipairs(categories[category]) do
                            signature(ctx, child)
                            builder:line()
                        end
                    end
                end
            end
        end)
    end
}

return detailed_signature_phase