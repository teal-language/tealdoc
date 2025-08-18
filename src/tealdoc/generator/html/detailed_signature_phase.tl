local Generator = require("tealdoc.generator")
local tealdoc = require("tealdoc")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local signatures = require("tealdoc.generator.signatures")

local signature: function(ctx: Generator.Phase.Context, item: tealdoc.Item, indent?: string)

-- potentially we could cache partials of signatures in order to improve performance
local function detailed_signature_for_structure_type(ctx: Generator.Phase.Context, item: tealdoc.TypeItem, indent: string, open?: boolean)
    assert(item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum", "Expected record or interface type, got: " .. item.type_kind)

    ctx.builder:rawtext("<details style=\"display: inline-block;\""..((ctx.module_name == item.path or open) and " open" or "")..">")
    ctx.builder:rawtext("<summary>")
    signatures.for_type(ctx, item)
    ctx.builder:rawtext("</summary>")
    local old_path_mode = ctx.path_mode
    ctx.path_mode = "none" -- no need to show full path in detailed signature
    if item.children then
        for _, child in ipairs(item.children) do
            local child_item = ctx.env.registry[child]
            assert(child_item, "Child item not found: " .. child)
            signature(ctx, child_item, indent.."  ")
            ctx.builder:line()
        end
    end
    ctx.path_mode = old_path_mode -- restore mode
    ctx.builder:rawtext("end")
    ctx.builder:rawtext("</details>")
end

signature = function(ctx: Generator.Phase.Context, item: tealdoc.Item, indent?: string)
    if not indent then
        indent = ""
    end

    if item is tealdoc.FunctionItem then
        ctx.builder:rawtext(indent)
        signatures.for_function(ctx, item, indent ~= "")
    elseif item is tealdoc.VariableItem then
        ctx.builder:rawtext(indent)
        signatures.for_variable(ctx, item)
    elseif item is tealdoc.TypeItem then
        ctx.builder:rawtext(indent)
        if item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum" then
            detailed_signature_for_structure_type(ctx, item, indent)
        else
            signatures.for_type(ctx, item)
        end
    elseif item.kind == "enumvalue" then
        ctx.builder:rawtext(indent)
        ctx.builder:link(item.path, item.name)
    elseif item.kind == "overload" or item.kind == "metafields" then
        for i, child in ipairs(item.children) do
            local child_item = ctx.env.registry[child]
            assert(child_item, "Child item not found: " .. child)
            assert(child_item is tealdoc.FunctionItem, "Expected function item, got: " .. child_item.kind)
            if not ctx.filter or ctx.filter(child_item, ctx.env) then
                signature(ctx, child_item, indent)
            end
            if i ~= #item.children then
                ctx.builder:line()
            end
        end
    end
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
                    detailed_signature_for_structure_type(ctx, item, "", true)
                else
                    signature(ctx, item)
                end
            else
                for _, child in ipairs(item.children) do
                    local child_item = ctx.env.registry[child]
                    assert(child_item, "Child item not found: " .. child)
                    if not ctx.filter or ctx.filter(child_item, ctx.env) then
                        signature(ctx, child_item)
                        builder:line()
                    end
                end
            end
        end)
    end
}

return detailed_signature_phase