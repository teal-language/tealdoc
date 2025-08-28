local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local type = type; local tealdoc = require("tealdoc")
local log = require("tealdoc.log")

local Generator = { Attribute = {}, Base = {} }














































































Generator.attr = function(name)
   return { name = name }
end

local function is_local(item)
   if item.attributes and item.attributes["local"] then
      return true
   end
   return type(item) == "table" and item.visibility == "local"
end

local function filter(item, env)
   local is_module_record = env.registry["$" .. item.path] ~= nil

   if not env.include_all and is_local(item) and not is_module_record then
      return false
   end


   if item.kind == "function" and item.function_kind == "metamethod" and item.name == "__is" then
      return false
   end

   return true
end

function Generator.categories_for_module_record(item, env)
   local categories_order = {}
   local categories = {}
   local uncategorized

   local categorize = function(child)
      if filter(child, env) then
         if child.attributes and child.attributes["category"] then
            local category = child.attributes["category"]
            if not categories[category] then
               categories[category] = {}
               table.insert(categories_order, category)
            end
            table.insert(categories[category], child)
         else
            if not uncategorized then
               uncategorized = {}
            end
            table.insert(uncategorized, child)
         end
      end
   end

   for _, child_name in ipairs(item.children) do
      local child_item = env.registry[child_name]
      assert(child_item)
      if child_item.kind == "overloaded" or child_item.kind == "metamethods" then
         local nested = child_item.children
         if nested then
            for _, nested_name in ipairs(nested) do
               local nested_item = env.registry[nested_name]
               assert(nested_item)
               categorize(nested_item)
            end
         end
      else
         categorize(child_item)
      end
   end

   table.sort(categories_order)

   for _, category_name in ipairs(categories_order) do
      table.sort(categories[category_name], function(a, b)
         return a.name < b.name
      end)
   end
   table.insert(categories_order, "$uncategorized")
   table.sort(uncategorized, function(a, b)
      return a.name < b.name
   end)
   categories["$uncategorized"] = uncategorized

   return categories_order, categories
end

function Generator.categories_for_module(item, module_name, env)
   local categories_order = { "$module_record", "$locals", "$globals" }
   local categories = {}

   for _, child_name in ipairs(item.children) do

      local child_item = env.registry[child_name]
      assert(child_item)
      if filter(child_item, env) then
         if child_item.path == module_name then
            categories["$module_record"] = { child_item }
         elseif is_local(child_item) then
            if not categories["$locals"] then
               categories["$locals"] = {}
            end
            table.insert(categories["$locals"], child_item)
         elseif (type(child_item) == "table" and child_item.visibility == "global") then
            if not categories["$globals"] then
               categories["$globals"] = {}
            end
            table.insert(categories["$globals"], child_item)
         end
      end
   end
   return categories_order, categories
end



local function visit_item(generator, module_name, item, env)
   if not filter(item, env) then
      return
   end

   if generator.on_item_start then
      generator:on_item_start(item, module_name, env)
   end

   if not item.text and not (item.kind == "overload" or item.kind == "metafields") and not env.no_warnings_on_missing then
      log:warning("Documentation missing for item: " .. item.path)
   end

   local ctx = {
      module_name = module_name,
      env = env,
      filter = filter,
   }

   if generator.on_context_for_item then
      generator:on_context_for_item(ctx, item, module_name, env)
   end

   local phases = generator.item_phases[item.kind]
   if phases and not (item.path == module_name) then
      for _, phase in ipairs(phases) do
         if generator.on_item_phase then
            if generator:on_item_phase(item, phase, ctx, env) then
               phase.run(ctx, item)
            end
         else
            phase.run(ctx, item)
         end
      end
   end


   if item.path == module_name then
      local categories_order, categories = Generator.categories_for_module_record(item, env)
      for _, category in ipairs(categories_order) do
         local category_items = categories[category]
         if category_items then
            if generator.on_category_start then
               generator:on_category_start(item, category, ctx, env)
            end
            for _, child_item in ipairs(category_items) do
               visit_item(generator, module_name, child_item, env)
            end
         end
      end
   elseif item.kind == "module" then
      local categories_order, categories = Generator.categories_for_module(item, module_name, env)
      for _, category in ipairs(categories_order) do
         local category_items = categories[category]
         if category_items then
            if generator.on_category_start then
               generator:on_category_start(item, category, ctx, env)
            end
            for _, child_item in ipairs(category_items) do
               visit_item(generator, module_name, child_item, env)
            end
         end
      end
   elseif item.children and not (item.kind == "function") then
      for _, child_name in ipairs(item.children) do
         local child_item = env.registry[child_name]
         assert(child_item)
         visit_item(generator, module_name, child_item, env)
      end
   end

   if generator.on_item_end then
      generator:on_item_end(item, module_name, env)
   end
end

Generator.Base.run = function(self, env)
   if self.on_start then
      self:on_start(env)
   end
   for _, item in ipairs(env.modules) do
      local module_item = env.registry["$" .. item]
      visit_item(self, item, module_item, env)
   end
   if self.on_end then
      self:on_end(env)
   end
end

Generator.Base.init = function()
   return {
      item_phases = {},
      run = Generator.Base.run,
   }
end



return Generator
