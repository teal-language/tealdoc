local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local log = require("tealdoc.log")
local tealdoc = require("tealdoc")
local TealParser = require("tealdoc.parser.teal")
local MarkdownInput = require("tealdoc.parser.markdown")


local Generator = require("tealdoc.generator")
local signatures = require("tealdoc.generator.signatures")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local HTMLGenerator = require("tealdoc.generator.html.generator")
local detailed_signature_phase = require("tealdoc.generator.html.detailed_signature_phase")

local DefaultEnv = {}


local attr = Generator.attr

function DefaultEnv.init()
   local env = tealdoc.Env.init()

   env:add_parser(TealParser.init())
   env:add_parser(MarkdownInput)




   local param_tag_handler = {
      name = "param",
      has_param = true,
      has_description = true,
      handle = function(ctx)
         local item = ctx.item
         if not (item.kind == "function") then
            log:error(
            "@param tag can only exist in function comments (%s:%s:%s)",
            item.location.filename,
            item.location.y,
            item.location)

            return
         end

         local param
         if item.params then
            for _, p in ipairs(item.params) do
               if p.description == nil then
                  param = p
                  break
               end
            end
         end
         if not param then
            log:warning(
            "Found more @param tags than declared parameters in function '%s' (%s:%s:%s)",
            item.name,
            item.location.filename,
            item.location.y,
            item.location.x)

            return
         end

         if param.name and param.name ~= ctx.param then
            log:warning(
            "Parameter name mismatch: expected '%s', got '%s' in function '%s' (%s:%s:%s)",
            param.name,
            ctx.param,
            item.name,
            item.location.filename,
            item.location.y,
            item.location.x)

            return
         end
         param.name = ctx.param
         param.description = ctx.description
      end,
   }

   local typearg_tag_handler = {
      name = "typearg",
      has_param = true,
      has_description = true,
      handle = function(ctx)
         local item = ctx.item
         if not (item.kind == "function") and not (item.kind == "type") then
            log:error(
            "@typearg tag can only exist in function or type comments (%s:%s:%s)",
            item.location.filename,
            item.location.y,
            item.location)

            return
         end

         local typearg
         if item.typeargs then
            for _, t in ipairs(item.typeargs) do
               if t.description == nil then
                  typearg = t
                  break
               end
            end
         end
         if not typearg then
            log:warning(
            "Found more @typearg tags than declared type arguments in '%s' (%s:%s:%s)",
            item.name,
            item.location.filename,
            item.location.y,
            item.location.x)

            return
         end

         if typearg.name and typearg.name ~= ctx.param then
            log:warning(
            "Typearg name mismatch: expected '%s', got '%s' in '%s' (%s:%s:%s)",
            typearg.name,
            ctx.param,
            item.name,
            item.location.filename,
            item.location.y,
            item.location.x)

            return
         end
         typearg.name = ctx.param
         typearg.description = ctx.description
      end,
   }

   local return_tag_handler = {
      name = "return",
      has_description = true,
      handle = function(ctx)
         local item = ctx.item
         if not (item.kind == "function") then
            log:error("return tag can only exist in function comments")
            return
         end

         local matched = false
         if item.returns then
            for _, ret in ipairs(item.returns) do
               if not ret.description then
                  ret.description = ctx.description
                  matched = true
                  break
               end
            end
         end
         if not matched then
            log:error(
            "Found more @return tags than declared return values in function '%s'. Each @return tag should correspond to a return value in the function signature.",
            item.name)

         end
      end,
   }

   local local_tag_handler = {
      name = "local",
      handle = function(ctx)
         local item = ctx.item
         if not item.attributes then
            item.attributes = {}
         end
         item.attributes["local"] = true
      end,
   }

   env:add_tag(return_tag_handler)
   env:add_tag(param_tag_handler)
   env:add_tag(typearg_tag_handler)
   env:add_tag(local_tag_handler)


   local function strip_module_prefix(path, module_name)
      return path:sub(#module_name + 2)
   end

   local module_header_phase = {
      name = "module_header",
      run = function(ctx, item)
         assert(item.kind == "module")
         ctx.builder:h1(attr("name"), "Module: " .. item.name)
         ctx.builder:line(attr("text"), item.text or "")
      end,
   }

   local header_phase = {
      name = "header",
      run = function(ctx, item)
         local path = item.path

         if ctx.path_mode == "full" then
            local display_path = path:gsub("%$[^%.]*%.", "")
            ctx.builder:h2(attr("path"), display_path)
         else
            ctx.builder:h2(attr("path"), strip_module_prefix(item.path, ctx.module_name))
         end
      end,
   }

   local text_phase = {
      name = "text",
      run = function(ctx, item)
         if item.text then
            ctx.builder:paragraph(attr("text"), function()
               ctx.builder:md(item.text)
            end)
         end
      end,
   }

   local function_signature_phase = {
      name = "function_signature",
      run = function(ctx, item)
         assert(item.kind == "function")
         ctx.builder:code_block(function()
            signatures.for_function(ctx, item)
            ctx.builder:line()
         end)
      end,
   }

   local variable_signature_phase = {
      name = "variable_signature",
      run = function(ctx, item)
         assert(item.kind == "variable")

         ctx.builder:code_block(function()
            signatures.for_variable(ctx, item)
            ctx.builder:line()
         end)
      end,
   }

   local type_signature_phase = {
      name = "type_signature",
      run = function(ctx, item)
         assert(item.kind == "type")

         ctx.builder:code_block(function()
            signatures.for_type(ctx, item)
            ctx.builder:line()
         end)
      end,
   }

   local type_params_phase = {
      name = "type_params",
      run = function(ctx, item)
         assert(item.kind == "type" or item.kind == "function")

         if not item.typeargs or #item.typeargs == 0 then
            return
         end

         ctx.builder:h4(attr("header"), "Type Parameters")
         ctx.builder:unordered_list(function(list_item)
            for _, typearg in ipairs(item.typeargs) do
               list_item(function()
                  ctx.builder:b(function()
                     ctx.builder:code(attr("name"), typearg.name or "?")
                  end)

                  if typearg.constraint then
                     ctx.builder:text(attr("constraint"), " ( is ", function() ctx.builder:code(typearg.constraint) end, ")")
                  end

                  if typearg.description then
                     ctx.builder:text(attr("description"), " — ", function() ctx.builder:md(typearg.description) end)
                  end
               end)
            end
         end)
      end,
   }

   local function_params_phase = {
      name = "function_params",
      run = function(ctx, item)
         assert(item.kind == "function")

         if not item.params or #item.params == 0 then
            return
         end

         ctx.builder:h4(attr("name"), "Parameters")
         ctx.builder:unordered_list(function(list_item)
            for _, param in ipairs(item.params) do
               list_item(function()
                  if param.name then
                     ctx.builder:b(function()
                        ctx.builder:code(attr("name"), param.name)
                     end)
                  end
                  ctx.builder:text(attr("type"), " (", function() ctx.builder:code(param.type or "?") end, ")")
                  if param.description then
                     ctx.builder:text(attr("description"), " — ", function()
                        ctx.builder:md(param.description)
                     end)
                  end
               end)
            end
         end)
      end,
   }

   local function_returns_phase = {
      name = "function_returns",
      run = function(ctx, item)
         assert(item.kind == "function")

         if not item.returns or #item.returns == 0 then
            return
         end

         ctx.builder:h4(attr("header"), "Returns")

         ctx.builder:ordered_list(function(list_item)
            for _, ret in ipairs(item.returns) do
               list_item(function()
                  ctx.builder:text(attr("type"), "(", function() ctx.builder:code(ret.type or "?") end, ")")
                  if ret.description then
                     ctx.builder:text(attr("description"), " — ", function() ctx.builder:md(ret.description) end)
                  end
               end)
            end
         end)
      end,
   }

   MarkdownGenerator.item_phases["module"] = { module_header_phase }
   MarkdownGenerator.item_phases["function"] = { header_phase, function_signature_phase, text_phase, type_params_phase, function_params_phase, function_returns_phase }
   MarkdownGenerator.item_phases["variable"] = { header_phase, variable_signature_phase, text_phase }
   MarkdownGenerator.item_phases["type"] = { header_phase, type_signature_phase, text_phase, type_params_phase }
   MarkdownGenerator.item_phases["enumvalue"] = { header_phase, text_phase }
   MarkdownGenerator.item_phases["markdown"] = { text_phase }

   HTMLGenerator.item_phases["module"] = { module_header_phase, detailed_signature_phase }
   HTMLGenerator.item_phases["function"] = { header_phase, function_signature_phase, text_phase, type_params_phase, function_params_phase, function_returns_phase }
   HTMLGenerator.item_phases["variable"] = { header_phase, variable_signature_phase, text_phase }
   HTMLGenerator.item_phases["type"] = { header_phase, detailed_signature_phase, text_phase, type_params_phase }
   HTMLGenerator.item_phases["enumvalue"] = { header_phase, text_phase }
   HTMLGenerator.item_phases["markdown"] = { text_phase }

   return env
end

return DefaultEnv
