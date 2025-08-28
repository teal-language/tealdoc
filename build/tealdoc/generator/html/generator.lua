local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local default_css = require("tealdoc.generator.html.default_css")
local lfs = require("lfs")

local function strip_module_prefix(path, module_name)
   if path:sub(1, 1) == "$" then
      path = path:sub(2)
   end
   return path:sub(#module_name + 2)
end


local HTMLGenerator = {}




HTMLGenerator.item_phases = {}








local function make_file(path, content)
   local b = HTMLBuilder.init()

   b:rawline("<!DOCTYPE html>")
   b:rawline("<html lang=\"en\">")
   b:rawline("<head>")
   b:rawline("<meta charset=\"UTF-8\">")
   b:rawline("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
   b:rawline("<title>Tealdoc Documentation</title>")
   b:rawline("<style>")
   b:rawline(default_css)
   b:rawline("</style>")
   b:rawline("</head>")
   b:rawline("<body>")
   content(b)
   b:rawline("<footer>")
   b:rawline("<small>generated using <a href=\"https://github.com/teal-language/tealdoc\" target=\"_blank\">tealdoc</a> " .. tealdoc.version .. "</small>")
   b:rawline("</footer>")
   b:rawline("</body>")
   b:rawline("</html>")

   local file = io.open(path .. ".html", "w")
   assert(file)

   file:write(b:build())
   file:close()
end

local function generate_breadcrumbs(b, visited, env)
   b:rawline("<nav>")
   b:unordered_list(function(item)
      local path
      for i, v in ipairs(visited) do
         if i == #visited then
            item(function()
               b:text(v)
            end)
         elseif i == 1 then
            local prefix = string.rep("../", #visited - 2)
            item(function()
               b:rawtext("<a href=\"" .. prefix .. v .. ".html\">")
               b:text(v)
               b:rawtext("</a> / ")
            end)
         else
            if not path then
               path = v
            else
               path = path .. "." .. v
            end
            local prefix = string.rep("../", #visited - i)
            item(function()
               if path and env.registry["$" .. path] then
                  b:rawtext("<a href=\"" .. prefix .. v .. ".html\">")
                  b:text(v)
                  b:rawtext("</a>")
               else
                  b:text(v)
               end
               b:rawtext(" / ")
            end)
         end
      end
   end)
   b:rawline("</nav>")
end

HTMLGenerator.init = function(output)
   local base = Generator.Base.init()

   base.item_phases = HTMLGenerator.item_phases

   local root = {
      name = "",
      path = "",
      children = {},
   }

   local node_map = {}

   local module_name_to_builder = {}

   base.on_context_for_item = function(_, ctx, _, module_name, _)
      ctx.builder = module_name_to_builder[module_name]
      ctx.path_mode = "relative"
   end

   base.on_category_start = function(_, _, category, ctx, _)
      if category ~= "$module_record" then
         local category_name
         if category == "$uncategorized" then
            category_name = ""
         elseif category:sub(1, 1) == "$" then
            category_name = category:sub(2)
         else
            category_name = category
         end


         ctx.builder:rawline("<h2 class=\"category\" id=\"category-" .. category_name .. "\">")
         if category_name ~= "" then
            ctx.builder:rawtext("<span class=\"muted\">")
            ctx.builder:text("Category: ")
            ctx.builder:rawtext("</span>")
            ctx.builder:text(category_name)
            ctx.builder:rawtext("<a class=\"title-link\" href=\"#category-" .. category_name .. "\">")
            ctx.builder:text("🔗")
            ctx.builder:rawtext("</a>")
         end
         ctx.builder:rawline("</h2>")
      end
   end

   base.on_start = function(_, env)
      for _, item in ipairs(env.modules) do
         local parts = {}
         for part in item:gmatch("[^.]+") do
            table.insert(parts, part)
         end

         local current_path = ""
         local current_parent = root

         for i, part in ipairs(parts) do
            if i > 1 then
               current_path = current_path .. "."
            end
            current_path = current_path .. part

            if not node_map[current_path] then
               local new_node = {
                  name = part,
                  path = current_path,
                  children = {},
               }
               node_map[current_path] = new_node
               table.insert(current_parent.children, new_node)
            end

            current_parent = node_map[current_path]
         end

         local builder = HTMLBuilder.init()
         module_name_to_builder[item] = builder
      end
   end
   base.on_item_phase = function(_, item, phase, ctx, _)
      if phase.name == "header" then
         ctx.builder:rawtext("<h3 id=\"" .. item.path .. "\">")
         ctx.builder:text(strip_module_prefix(item.path, ctx.module_name))
         ctx.builder:rawtext("<a class=\"title-link\" href=\"#" .. item.path .. "\">")
         ctx.builder:text("🔗")
         ctx.builder:rawtext("</a>")
         ctx.builder:rawtext("</h3>")
         return false
      elseif phase.name == "module_header" then
         ctx.builder:rawtext("<h1 id=\"" .. item.name .. "\">")
         ctx.builder:rawtext("<span class=\"muted\">")
         ctx.builder:text("Module ")
         ctx.builder:rawtext("</span>")
         ctx.builder:text(item.name)
         ctx.builder:rawtext("<a class=\"title-link\" href=\"#" .. item.name .. "\">")
         ctx.builder:text("🔗")
         ctx.builder:rawtext("</a>")
         ctx.builder:rawtext("</h1>")
         return false
      end
      return true
   end

   base.on_end = function(_, env)
      make_file(output .. "/index", function(b)
         b:rawline("<main>")
         b:h1("Documentation Index")
         local visited = { "index" }

         local function traverse(cur_filename, node)
            local module_item = env.registry["$" .. node.path]

            if node.name ~= "" then
               table.insert(visited, node.name)
            end

            if not module_item then
               b:text(node.name)
            else
               local path = cur_filename .. "/" .. node.name

               make_file(path, function(moduleBuilder)
                  moduleBuilder:rawline("<main>")
                  generate_breadcrumbs(moduleBuilder, visited, env)
                  moduleBuilder:rawtext(module_name_to_builder[node.path]:build())
                  moduleBuilder:rawline("</main>")
               end)

               local link = path:sub(#output + 2)
               b:rawtext("<a href=\"" .. link .. ".html\">")
               b:text(node.name)
               b:rawtext("</a>")
            end

            if #node.children > 0 then
               b:rawline("<ul class=\"tree-list\">")
               for _, child in ipairs(node.children) do
                  b:rawline("<li>")
                  local path = cur_filename
                  if node.name ~= "" then
                     path = path .. "/" .. node.name
                  end
                  lfs.mkdir(path)
                  traverse(path, child)
                  b:rawline("</li>")
               end
               b:rawline("</ul>")
            end

            if node.name ~= "" then
               table.remove(visited)
            end
         end

         traverse(output, root)
         b:rawline("</main>")
      end)
   end

   return base
end

return HTMLGenerator
