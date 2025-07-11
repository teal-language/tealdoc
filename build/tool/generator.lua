local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local tealdoc = require("tealdoc")
local log = require("log")

local Generator = {}




































Generator.item_phases = {}

Generator.generate_for_item = function(generator, item, env)


   if not env.include_all then
      local is_module = env.registry["$" .. (item.path)]

      local has_local_tag = item.attributes and item.attributes["local"]
      if has_local_tag or (tealdoc.is_item_local(item) and not is_module) then
         return
      end
   end
   local phases = Generator.item_phases[item.kind]

   if not item.text then
      log:warning("Documentation missing for item: " .. item.path)
   end

   if phases then
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
