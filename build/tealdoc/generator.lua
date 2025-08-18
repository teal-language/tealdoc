local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local type = type; local tealdoc = require("tealdoc")
local log = require("tealdoc.log")

local Generator = { Base = {} }


































































local function filter(item, env)
   local is_module_record = env.registry["$" .. item.path] ~= nil

   if not env.include_all then
      local has_local_tag = item.attributes and item.attributes["local"]
      local is_declared_as_local = type(item) == "table" and item.visibility == "local"
      if has_local_tag or (is_declared_as_local and not is_module_record) then
         return false
      end
   end


   if item.kind == "function" and item.function_kind == "metamethod" and item.name == "__is" then
      return false
   end

   return true
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

   if item.children and not (item.kind == "function") then
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
