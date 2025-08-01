local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local default_css = require("tealdoc.generator.html.default_css")
local log = require("tealdoc.log")
local lfs = require("lfs")



local function strip_module_prefix(path, module_name)
   return path:sub(#module_name + 2)
end

local HTMLGenerator = {}




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

HTMLGenerator.item_phases = {}

function HTMLGenerator.generate_item(self, builder, item, env, module_name)
   if not filter(item, env) then
      return
   end

   if not item.text and not (item.kind == "overload" or item.kind == "metafields") and not env.no_warnings_on_missing then
      log:warning("Documentation missing for item: " .. item.path)
   end

   local ctx = {
      builder = builder,
      module_name = module_name,
      env = env,
      filter = filter,
      path_mode = "relative",
   }
   local phases = self.item_phases[item.kind]
   if phases and not (item.path == module_name) then
      for _, phase in ipairs(phases) do
         if phase.name == "header" then
            builder:rawtext("<h3 id=\"" .. item.path .. "\">")
            builder:text(strip_module_prefix(item.path, module_name))
            builder:rawtext("</h3>")
         elseif phase.name == "module_header" then
            builder:rawtext("<h1 id=\"" .. item.name .. "\">")
            builder:text("Module " .. (item.name))
            builder:rawtext("</h1>")
         else
            phase.run(ctx, item)
         end
      end
   end

   if item.children and not (item.kind == "function") then
      for _, child_name in ipairs(item.children) do
         local child_item = env.registry[child_name]
         assert(child_item)
         self:generate_item(builder, child_item, env, module_name)
      end
   end
end

function HTMLGenerator:generate_breadcrumbs(b, visited, env)
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

function HTMLGenerator:file(path, content)
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













local function convert_modules_to_tree(modules)
   local root = {
      name = "",
      path = "",
      children = {},
   }

   local node_map = {}


   for _, module_path in ipairs(modules) do
      local parts = {}
      for part in module_path:gmatch("[^.]+") do
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
   end

   return root
end

function HTMLGenerator:generate_modules(filename, index_builder, modules, env)
   local module_tree = convert_modules_to_tree(modules)

   local visited = { "index" }

   local function traverse(cur_filename, node)
      local module_item = env.registry["$" .. node.path]

      if node.name ~= "" then
         table.insert(visited, node.name)
      end

      if not module_item then
         index_builder:text(node.name)
      else
         local path = cur_filename .. "/" .. node.name

         self:file(path, function(b)
            b:rawline("<main>")
            self:generate_breadcrumbs(b, visited, env)
            self:generate_item(b, module_item, env, node.path)
            b:rawline("</main>")
         end)

         local link = path:sub(#filename + 2)
         index_builder:rawtext("<a href=\"" .. link .. ".html\">")
         index_builder:text(node.name)
         index_builder:rawtext("</a>")
      end

      if #node.children > 0 then
         index_builder:rawline("<ul class=\"tree-list\">")
         for _, child in ipairs(node.children) do
            index_builder:rawline("<li>")
            local path = cur_filename
            if node.name ~= "" then
               path = path .. "/" .. node.name
            end
            lfs.mkdir(path)
            traverse(path, child)
            index_builder:rawline("</li>")
         end
         index_builder:rawline("</ul>")
      end

      if node.name ~= "" then
         table.remove(visited)
      end
   end

   traverse(filename, module_tree)
end


HTMLGenerator.run = function(self, filename, env)

   lfs.mkdir(filename)
   local path = filename .. "/index"
   self:file(path, function(b)
      b:rawline("<main>")
      b:h1("Documentation Index")
      self:generate_modules(filename, b, env.modules, env)
      b:rawline("</main>")
   end)
end

return HTMLGenerator
