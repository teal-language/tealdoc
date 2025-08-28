local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local Generator = require("tealdoc.generator")
local tealdoc = require("tealdoc")

local attr = Generator.attr

local signatures = {}


local function visibility(item)
   if item.visibility ~= "record" then
      return item.visibility .. " "
   end
   return ""
end

local function strip_module_prefix(path, module_name)
   if path:sub(1, 1) == "$" then
      path = path:sub(2)
   end
   return path:sub(#module_name + 2)
end


local function get_name(ctx, item)
   if ctx.path_mode == "full" then
      return item.path
   elseif ctx.path_mode == "relative" then
      return ctx.module_name == item.path and item.name or strip_module_prefix(item.path, ctx.module_name)
   else
      return item.name
   end
end

function signatures.for_function(ctx, fn, as_record_field)
   local params = {}
   if fn.params then
      for _, param in ipairs(fn.params) do
         if not param.name then
            table.insert(params, param.type or "?")
         else
            table.insert(params, param.name .. ": " .. (param.type or "?"))
         end
      end
   end
   local returns = {}
   if fn.returns then
      for _, ret in ipairs(fn.returns) do
         table.insert(returns, ret.type or "?")
      end
   end

   local typeargs = {}
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

function signatures.for_variable(ctx, var)
   ctx.builder:text(attr("variable"), visibility(var), function() ctx.builder:link(var.path, get_name(ctx, var)) end, ": ", var.typename)
end

function signatures.for_type(ctx, item)
   ctx.builder:text(attr("name"), visibility(item), item.type_kind, " ", function() ctx.builder:link(item.path, get_name(ctx, item)) end)
   if item.type_kind == "type" then
      ctx.builder:text(attr("type"), " = ", item.typename)
   elseif item.typeargs and #item.typeargs > 0 then
      local typeargs = {}
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
