local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local type = type; local tealdoc = require("tealdoc")
local log = require("tealdoc.log")

local Generator = {}




































Generator.item_phases = {}

Generator.generate_for_item = function(generator, item, env)
   local is_module = env.registry["$" .. (item.path)]



   if not env.include_all then
      local has_local_tag = item.attributes and item.attributes["local"]
      local is_declared_as_local = type(item) == "table" and item.visibility == "local"
      if has_local_tag or (is_declared_as_local and not is_module) then
         return
      end
   end
   local phases = Generator.item_phases[item.kind]

   if item.kind == "function" and item.function_kind == "metamethod" and item.name == "__is" then
      return
   end
   if not item.text and not is_module and (item.kind == "function" or item.kind == "type" or item.kind == "variable" or item.kind == "enumvalue") then
      log:warning("Documentation missing for item: " .. item.path)
   end

   if phases and not is_module then
      for _, phase in ipairs(phases) do
         phase.run(generator, item)
      end
   end

   if item.children and not (item.kind == "function") then
      for _, child_name in ipairs(item.children) do
         local child_item = env.registry[child_name]
         assert(child_item)
         Generator.generate_for_item(generator, child_item, env)
      end
   end
end

return Generator
