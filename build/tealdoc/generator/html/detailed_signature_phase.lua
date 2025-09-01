local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local type = type; local Generator = require("tealdoc.generator")
local tealdoc = require("tealdoc")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local signatures = require("tealdoc.generator.signatures")

local signature


local function detailed_signature_for_structure_type(ctx, item, indent, force_open)
   assert(item.type_kind == "record" or item.type_kind == "interface" or item.type_kind == "enum", "Expected record or interface type, got: " .. item.type_kind)

   local has_collapsible_children = false
   local is_record_module = ctx.module_name == item.path
   local categories
   local categories_order

   if is_record_module then
      categories_order, categories = Generator.categories_for_module_record(item, ctx.env)
      for _, children in pairs(categories) do
         for _, child in ipairs(children) do
            if child.kind == "type" and (child.type_kind == "record" or child.type_kind == "interface" or child.type_kind == "enum") then
               has_collapsible_children = true
               break
            end
         end
         if has_collapsible_children then break end
      end
   elseif item.children then
      for _, child_path in ipairs(item.children) do
         local child_item = ctx.env.registry[child_path]
         if child_item and child_item.kind == "type" and (child_item.type_kind == "record" or child_item.type_kind == "interface" or child_item.type_kind == "enum") then
            has_collapsible_children = true
            break
         end
      end
   end
   if indent == "" and has_collapsible_children then
      ctx.builder:rawtext("<div class=\"signature-controls\"><button title=\"Expand all\" onclick=\"expandAll(this)\">[Expand All]</button> <button title=\"Collapse all\" onclick=\"collapseAll(this)\">[Collapse All]</button></div>")
   end

   ctx.builder:rawtext("<details style=\"display: inline-block;\"" .. ((indent == "" or force_open) and " open" or "") .. ">")

   ctx.builder:rawtext("<summary>")
   signatures.for_type(ctx, item)
   ctx.builder:rawtext("</summary>")

   local old_path_mode = ctx.path_mode
   ctx.path_mode = "none"

   if is_record_module then
      for idx, category in ipairs(categories_order) do
         if idx ~= 1 then
            ctx.builder:line()
         end
         if category:sub(1, 1) ~= "$" then
            ctx.builder:line(indent .. "  ", "-- ", category)
         end
         for _, child in ipairs(categories[category]) do
            if signature(ctx, child, indent .. "  ", true) then
               ctx.builder:line()
            end
         end
      end
   elseif item.children then
      for _, child in ipairs(item.children) do
         local child_item = ctx.env.registry[child]
         assert(child_item, "Child item not found: " .. child)
         if signature(ctx, child_item, indent .. "  ") then
            ctx.builder:line()
         end
      end
   end
   ctx.path_mode = old_path_mode
   ctx.builder:rawtext("end")
   ctx.builder:rawtext("</details>")
end


signature = function(ctx, item, indent, force_open)
   if not indent then
      indent = ""
   end

   if item.kind == "function" then
      ctx.builder:rawtext(indent)
      signatures.for_function(ctx, item, indent ~= "")
      return true
   elseif item.kind == "variable" then
      ctx.builder:rawtext(indent)
      signatures.for_variable(ctx, item)
      if item.children then
         for _, child in ipairs(item.children) do
            ctx.builder:line()
            local child_item = ctx.env.registry[child]
            assert(child_item, "Child item not found: " .. child)
            assert(child_item.kind == "function", "Expected function item, got: " .. child_item.kind)
            if not ctx.filter or ctx.filter(child_item, ctx.env) then
               signature(ctx, child_item, indent)
            end
         end
      end
      return true
   elseif item.kind == "type" then
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
         assert(child_item.kind == "function", "Expected function item, got: " .. child_item.kind)

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


local detailed_signature_phase = {
   name = "detailed_signature",
   run = function(ctx, item)
      assert(item.kind == "type" or item.kind == "module")
      local builder = ctx.builder
      assert(type(builder) == "table", "Expected HTMLBuilder")
      builder:code_block(function()
         if item.kind == "type" then
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
   end,
}

return detailed_signature_phase
