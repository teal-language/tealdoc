local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local log = require("tealdoc.log")
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
               if p.name == ctx.param and p.description == nil then
                  param = p
                  break
               end
            end




            if not param then
               for _, p in ipairs(item.params) do
                  if p.name == nil and p.description == nil then
                     param = p
                     break
                  end
               end
            end




            if not param then
               for _, p in ipairs(item.params) do
                  if p.description == nil then
                     param = p
                     break
                  end
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

   local public_tag_handler = {
      name = "public",
      handle = function(ctx)
         local item = ctx.item
         if not item.attributes then
            item.attributes = {}
         end
         item.attributes["public"] = true
      end,
   }

   local category_tag_handler = {
      name = "category",
      has_param = true,
      handle = function(ctx)
         local item = ctx.item
         if not item.attributes then
            item.attributes = {}
         end
         item.attributes["category"] = ctx.param
      end,
   }

   env:add_tag(return_tag_handler)
   env:add_tag(param_tag_handler)
   env:add_tag(typearg_tag_handler)
   env:add_tag(local_tag_handler)
   env:add_tag(public_tag_handler)
   env:add_tag(category_tag_handler)


   local function strip_module_prefix(path, module_name)
      if path:sub(1, 1) == "$" then
         path = path:sub(2)
      end
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

   local function display_path(ctx, item)
      if ctx.path_mode == "full" then
         local path = item.path:gsub("%$[^%.]*%.", "")
         return path
      end
      return strip_module_prefix(item.path, ctx.module_name)
   end

   local function overload_parent(ctx, item)
      if not item.parent then
         return nil
      end
      local parent = ctx.env.registry[item.parent]
      if parent and (parent.kind == "overload" or parent.kind == "overloaded") then
         return parent
      end
      return nil
   end

   local function markdown_item_level(ctx, item)
      local level = 2
      local current = item
      while current.parent do
         local parent = ctx.env.registry[current.parent]
         if not parent or parent.kind == "module" or parent.path == ctx.module_name then
            break
         end
         level = math.min(level + 1, 5)
         current = parent
      end
      return level
   end

   local function markdown_heading(
      ctx,
      level,
      attribute,
      title)

      if level == 2 then
         ctx.builder:h2(attribute, title)
      elseif level == 3 then
         ctx.builder:h3(attribute, title)
      elseif level == 4 then
         ctx.builder:h4(attribute, title)
      elseif level == 5 then
         ctx.builder:h5(attribute, title)
      else
         ctx.builder:h6(attribute, title)
      end
   end

   local markdown_header_phase = {
      name = "markdown_header",
      run = function(ctx, item)
         local parent = overload_parent(ctx, item)
         if parent then
            if parent.children and parent.children[1] == item.path then
               markdown_heading(
               ctx,
               markdown_item_level(ctx, parent),
               attr("path"),
               display_path(ctx, parent))

            end
            markdown_heading(
            ctx,
            markdown_item_level(ctx, item),
            attr("header"),
            "Function")

         else
            markdown_heading(
            ctx,
            markdown_item_level(ctx, item),
            attr("path"),
            display_path(ctx, item))

         end
      end,
   }

   local function markdown_section(ctx, item, title)
      markdown_heading(
      ctx,
      markdown_item_level(ctx, item) + 1,
      attr("header"),
      title)

   end

   local function markdown_type(
      ctx,
      typename,
      references)

      if not ctx.url_for_type or not references or #references == 0 then
         ctx.builder:code(typename)
         return
      end

      local urls = {}
      for _, reference in ipairs(references) do
         local url = ctx.url_for_type(reference.path)
         if url then
            urls[reference.name] = url
         end
      end
      if next(urls) == nil then
         ctx.builder:code(typename)
         return
      end

      local position = 1
      local plain = {}
      local function flush_plain()
         if #plain > 0 then
            ctx.builder:code(table.concat(plain))
            plain = {}
         end
      end
      while position <= #typename do
         local first, last = typename:find("[%a_][%w_%.]*", position)
         if not first then
            table.insert(plain, typename:sub(position))
            break
         end
         if first > position then
            table.insert(plain, typename:sub(position, first - 1))
         end

         local name = typename:sub(first, last)
         local url = urls[name]
         if url then
            flush_plain()
            ctx.builder:link_url(url, function()
               ctx.builder:code(name)
            end)
         else
            table.insert(plain, name)
         end
         position = last + 1
      end
      flush_plain()
   end

   local function markdown_type_path(
      ctx,
      target)

      local direct = ctx.env.registry[target]
      if direct and direct.kind == "type" then
         return target
      end

      local found
      for path, item in pairs(ctx.env.registry) do
         if item.kind == "type" and
            item.name == target and
            Generator.filter(item, ctx.env) then

            if found and found ~= path then
               return nil
            end
            found = path
         end
      end
      return found
   end

   local function markdown_with_type_links(
      ctx,
      text)

      return (text:gsub(
      "%]%(%s*tealdoc:([^%)%s]+)%s*%)",
      function(target)
         local path = markdown_type_path(ctx, target)
         if not path then
            log:warning(
            "Could not resolve Tealdoc Markdown type link: " ..
            target)

            return "](tealdoc:" .. target .. ")"
         end

         local url
         if ctx.url_for_type then
            url = ctx.url_for_type(path)
         end
         if not url then
            local item = ctx.env.registry[path]
            if item and Generator.filter(item, ctx.env) then
               url = ctx.url_for_path(path)
            end
         end
         if not url then
            log:warning(
            "Type is not public in Tealdoc Markdown link: " ..
            target)

            return "](tealdoc:" .. target .. ")"
         end
         return "](" .. url .. ")"
      end))

   end

   local text_phase = {
      name = "text",
      run = function(ctx, item)
         if item.text then
            ctx.builder:paragraph(attr("text"), function()
               ctx.builder:md(markdown_with_type_links(ctx, item.text))
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

   local structure_signature






   structure_signature = function(
      ctx,
      item,
      indent,
      record_field)

      if item.kind == "variable" then
         ctx.builder:rawtext(indent)
         signatures.for_variable(ctx, item)
         return true
      elseif item.kind == "function" then
         ctx.builder:rawtext(indent)
         signatures.for_function(ctx, item, record_field)
         return true
      elseif item.kind == "type" then
         ctx.builder:rawtext(indent)
         signatures.for_type(ctx, item)
         if item.type_kind ~= "record" and
            item.type_kind ~= "interface" and
            item.type_kind ~= "enum" then

            return true
         end

         local old_path_mode = ctx.path_mode
         ctx.path_mode = "none"
         for _, child_path in ipairs(item.children or {}) do
            local child = assert(
            ctx.env.registry[child_path],
            "Child item not found: " .. child_path)

            if not ctx.filter or ctx.filter(child, ctx.env) then
               ctx.builder:line()
               structure_signature(ctx, child, indent .. "    ", true)
            end
         end
         ctx.path_mode = old_path_mode
         ctx.builder:line()
         ctx.builder:rawtext(indent, "end")
         return true
      elseif item.kind == "enumvalue" then
         ctx.builder:rawtext(indent, item.name)
         return true
      elseif item.children then
         local wrote = false
         for _, child_path in ipairs(item.children) do
            local child = assert(
            ctx.env.registry[child_path],
            "Child item not found: " .. child_path)

            if not ctx.filter or ctx.filter(child, ctx.env) then
               if wrote then
                  ctx.builder:line()
               end
               wrote = structure_signature(
               ctx,
               child,
               indent,
               record_field) or
               wrote
            end
         end
         return wrote
      end
      return false
   end

   local type_signature_phase = {
      name = "type_signature",
      run = function(ctx, item)
         assert(item.kind == "type")

         ctx.builder:code_block(function()
            structure_signature(ctx, item, "", false)
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
                     ctx.builder:text(attr("description"), " — ", function()
                        ctx.builder:md(markdown_with_type_links(
                        ctx,
                        typearg.description))

                     end)
                  end
               end)
            end
         end)
      end,
   }

   local markdown_type_params_phase = {
      name = "markdown_type_params",
      run = function(ctx, item)
         assert(item.kind == "type" or item.kind == "function")

         if not item.typeargs or #item.typeargs == 0 then
            return
         end

         markdown_section(ctx, item, "Type Parameters")
         ctx.builder:unordered_list(function(list_item)
            for _, typearg in ipairs(item.typeargs) do
               list_item(function()
                  ctx.builder:b(function()
                     ctx.builder:code(attr("name"), typearg.name or "?")
                  end)

                  if typearg.constraint then
                     ctx.builder:text(attr("constraint"), " ( is ", function()
                        ctx.builder:code(typearg.constraint)
                     end, ")")
                  end

                  if typearg.description then
                     ctx.builder:text(attr("description"), " — ", function()
                        ctx.builder:md(markdown_with_type_links(
                        ctx,
                        typearg.description))

                     end)
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
                        ctx.builder:md(markdown_with_type_links(
                        ctx,
                        param.description))

                     end)
                  end
               end)
            end
         end)
      end,
   }

   local markdown_function_params_phase = {
      name = "markdown_function_params",
      run = function(ctx, item)
         assert(item.kind == "function")
         markdown_section(ctx, item, "Arguments")

         if not item.params or #item.params == 0 then
            ctx.builder:paragraph("None.")
            return
         end

         ctx.builder:unordered_list(function(list_item)
            for _, param in ipairs(item.params) do
               list_item(function()
                  if param.name then
                     ctx.builder:b(function()
                        ctx.builder:code(attr("name"), param.name)
                     end)
                  end
                  ctx.builder:text(attr("type"), " (", function()
                     markdown_type(ctx, param.type or "?", param.type_references)
                  end, ")")
                  if param.description then
                     ctx.builder:text(attr("description"), " — ", function()
                        ctx.builder:md(markdown_with_type_links(
                        ctx,
                        param.description))

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
                     ctx.builder:text(attr("description"), " — ", function()
                        ctx.builder:md(markdown_with_type_links(
                        ctx,
                        ret.description))

                     end)
                  end
               end)
            end
         end)
      end,
   }

   local markdown_function_returns_phase = {
      name = "markdown_function_returns",
      run = function(ctx, item)
         assert(item.kind == "function")
         markdown_section(ctx, item, "Returns")

         if not item.returns or #item.returns == 0 then
            ctx.builder:paragraph("None.")
            return
         end

         ctx.builder:ordered_list(function(list_item)
            for _, ret in ipairs(item.returns) do
               list_item(function()
                  ctx.builder:text(attr("type"), "(", function()
                     markdown_type(ctx, ret.type or "?", ret.type_references)
                  end, ")")
                  if ret.description then
                     ctx.builder:text(attr("description"), " — ", function()
                        ctx.builder:md(markdown_with_type_links(
                        ctx,
                        ret.description))

                     end)
                  end
               end)
            end
         end)
      end,
   }

   MarkdownGenerator.item_phases["module"] = { module_header_phase }
   MarkdownGenerator.item_phases["function"] = {
      markdown_header_phase,
      text_phase,
      function_signature_phase,
      markdown_type_params_phase,
      markdown_function_params_phase,
      markdown_function_returns_phase,
   }
   MarkdownGenerator.item_phases["variable"] = {
      markdown_header_phase,
      text_phase,
      variable_signature_phase,
   }
   MarkdownGenerator.item_phases["type"] = {
      markdown_header_phase,
      text_phase,
      type_signature_phase,
      markdown_type_params_phase,
   }
   MarkdownGenerator.item_phases["enumvalue"] = { markdown_header_phase, text_phase }
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
