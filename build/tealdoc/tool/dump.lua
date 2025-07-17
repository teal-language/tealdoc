local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local tealdoc = require("tealdoc")

local DumpTool = {}



DumpTool.run = function(registry)
   for path, item in pairs(registry) do
      print(path .. ":")
      if item.kind then
         print("\tkind: " .. item.kind)
      end

      if item.location then
         print("\tlocation: " .. item.location.filename .. ":" .. item.location.y .. ":" .. item.location.x)
      end
      if item.text then
         print("\ttext: " .. item.text)
      end
      if item.attributes then
         print("\tattributes: ")
         for k, v in pairs(item.attributes) do
            print("\t\t" .. k .. " = " .. tostring(v))
         end
      end
      if item.kind == "function" then
         print("\tname: " .. tostring(item.name))
         if item.params then
            print("\tparams:")
            for _, param in ipairs(item.params) do
               print("\t\t" .. tostring(param.name) .. ":")
               print("\t\t\tdescription = " .. tostring(param.description))
               print("\t\t\ttype = " .. tostring(param.type))
            end
         end
         if item.returns then
            print("\treturns:")
            for i, ret in ipairs(item.returns) do
               print("\t\t" .. i .. ":")
               print("\t\t\tdescription = " .. tostring(ret.description))
               print("\t\t\ttype = " .. tostring(ret.type))
            end
         end
         if item.typeargs then
            print("\ttypeargs:")
            for i, typearg in ipairs(item.typeargs) do
               print("\t\t" .. i .. ":")
               print("\t\t\tname = " .. tostring(typearg.name))
               print("\t\t\tconstraint = " .. tostring(typearg.constraint))
            end
         end
      end
      if item.kind == "variable" then
         print("\tname: " .. item.name)
         if item.typename then
            print("\ttypename: " .. tostring(item.typename))
         end
      end
      if item.kind == "type" then
         print("\tname: " .. item.name)
         if item.typename then
            print("\ttypename: " .. tostring(item.typename))
         end
         if item.typeargs then
            print("\ttypeargs:")
            for i, typearg in ipairs(item.typeargs) do
               print("\t\t" .. i .. ":")
               print("\t\t\tname = " .. tostring(typearg.name))
               print("\t\t\tconstraint = " .. tostring(typearg.constraint))
            end
         end
         if item.inherits then
            print("\tinherits: ")
            for _, inherit in ipairs(item.inherits) do
               print("\t\t" .. inherit)
            end
         end
      end
      if item.parent then
         print("\tparent: " .. item.parent)
      end
      if item.children then
         print("\tchildren: ")
         for _, child in ipairs(item.children) do
            print("\t\t" .. child)
         end
      end
   end
end

return DumpTool
