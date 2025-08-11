local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local type = type; local Generator = require("tealdoc.generator")
local tealdoc = require("tealdoc")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local signatures = require("tealdoc.generator.signatures")

local signature


local function detailed_signature_for_structure_type(ctx, item, indent, open)
   assert(item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum", "Expected record or interface type, got: " .. item.type_kind)

   ctx.builder:rawtext("<details style=\"display: inline-block;\"" .. ((ctx.module_name == item.path or open) and " open" or "") .. ">")
   ctx.builder:rawtext("<summary>")
   signatures.for_type(ctx, item)
   ctx.builder:rawtext("</summary>")
   local old_path_mode = ctx.path_mode
   ctx.path_mode = "none"
   if item.children then
      for _, child in ipairs(item.children) do
         local child_item = ctx.env.registry[child]
         assert(child_item, "Child item not found: " .. child)
         signature(ctx, child_item, indent .. "  ")
         ctx.builder:line()
      end
   end
   ctx.path_mode = old_path_mode
   ctx.builder:rawtext("end")
   ctx.builder:rawtext("</details>")
end

signature = function(ctx, item, indent)
   if not indent then
      indent = ""
   end

   if item.kind == "function" then
      ctx.builder:rawtext(indent)
      signatures.for_function(ctx, item, indent ~= "")
   elseif item.kind == "variable" then
      ctx.builder:rawtext(indent)
      signatures.for_variable(ctx, item)
   elseif item.kind == "type" then
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
         assert(child_item.kind == "function", "Expected function item, got: " .. child_item.kind)
         if not ctx.filter or ctx.filter(child_item, ctx.env) then
            signature(ctx, child_item, indent)
         end
         if i ~= #item.children then
            ctx.builder:line()
         end
      end
   end
end


local detailed_signature_phase = {
   name = "detailed_signature",
   run = function(ctx, item)
      assert(item.kind == "type" or item.kind == "module")
      local builder = ctx.builder
      assert(type(builder) == "table", "Expected HTMLBuilder")
      builder:code_block(function()
         if item.kind == "type" then
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
   end,
}

return detailed_signature_phase
