local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local tl = require("tl")
local tealdoc = require("tealdoc")
local log = require("tealdoc.log")
local CommentParser = require("tealdoc.comment_parser")













local function typenum_for_position(report, filename, x, y)
   local rf = report.by_pos[filename]
   if not rf then return end
   local ry = rf[y]
   if not rf then return end
   local typenum = ry[x]
   return typenum
end

local function typeinfo_for_position(report, filename, x, y)
   local typenum = typenum_for_position(report, filename, x, y)
   if not typenum then return end
   local typeinfo = report.types[typenum]
   return typeinfo
end

local function typenum_for_global(report, name)
   local typenum = report.globals[name]
   if not typenum then return end
   return typenum
end

local function typeinfo_for_global(report, name)
   local typenum = typenum_for_global(report, name)
   if not typenum then return end
   local typeinfo = report.types[typenum]
   return typeinfo
end

local function typenum_for_node(report, node)
   return typenum_for_position(report, node.f, node.x, node.y)
end

local function typeinfo_for_node(report, node)
   return typeinfo_for_position(report, node.f, node.x, node.y)
end

local function typenum_for_type(report, t)
   return typenum_for_position(report, t.f, t.x, t.y)
end

local function typeinfo_for_type(report, t)
   return typeinfo_for_position(report, t.f, t.x, t.y)
end

local function location_for_node(node)
   return {
      filename = node.f,
      x = node.x,
      y = node.y,
   }
end


local function location_for_type(t)
   return {
      filename = t.f,
      x = t.x,
      y = t.y,
   }
end





local visit_node
local visit_type

local function children_visitor(node, state)
   for _, child in ipairs(node) do
      visit_node(child, state)
   end
end

local function is_long_comment(c)
   return c.text:match("^%-%-%[(=*)%[") ~= nil
end

local function process_comments(comments, item, env)
   local function strip_long_comment(c)
      local text = c.text:gsub("^%-%-%[=*%[", ""):gsub("%]=*%]$", "")
      return text
   end

   local function strip_short_comment(c)
      local text = c.text:gsub("^%-+%s*(.-)%s*$", "%1")
      return text
   end

   if not comments then
      return
   end

   local first_comment = comments[1]

   if first_comment and is_long_comment(first_comment) then
      CommentParser.parse_text(strip_long_comment(first_comment), item, env)
      return true
   end

   local lines = {}
   local in_block = false
   for _, comment in ipairs(comments) do
      if not in_block and comment.text:match("^%-%-%-") then
         in_block = true
      end
      if in_block then
         table.insert(lines, strip_short_comment(comment))
      end
   end

   CommentParser.parse_lines(lines, item, env)
   return #lines > 0
end



local function typeinfo_to_string(typeinfo)
   return typeinfo and typeinfo.str
end

local function type_to_string(report, typ)
   return typeinfo_to_string(typeinfo_for_type(report, typ))
end


local function is_item_local(item)
   return type(item) == "table" and item.visibility == "local"
end

local function is_item_global(item)
   return type(item) == "table" and item.visibility == "global"
end

local function store_item_at_path(item, path, state)

   local old_item = state.env.registry[path]
   if old_item then
      if is_item_local(item) then
         if old_item.kind == "shadowed" then
            assert(old_item.children)
            path = path .. "#" .. tostring(#old_item.children + 1)
            table.insert(old_item.children, path)
         else
            assert(is_item_local(old_item))
            local shadowed_path = old_item.path
            old_item.path = old_item.path .. "#1"
            path = path .. "#2"
            local shadowed_item = {
               path = shadowed_path,
               kind = "shadowed",
               children = { old_item.path, path },
               parent = old_item.parent,
            }

            state.env.registry[old_item.path] = old_item
            state.env.registry[shadowed_path] = shadowed_item

            old_item.parent = shadowed_path
            item.parent = shadowed_path
         end
      elseif is_item_global(item) then
         assert(is_item_global(old_item))
         if old_item.text then

            log:warning(
            "Global declaration of '%s' shadows a previous global declaration with the same name. The comment from the previous declaration will be discarded.",
            item.name,
            path)

         end
      elseif old_item.kind == "function" and item.kind == "function" then


         if old_item.is_declaration then
            if old_item.text and item.text then
               log:warning("Both the function declaration and definition for this record function contain tealdoc comments. The comment from the declaration will be discarded.")
            elseif not item.text then
               return nil
            end
         else
            if old_item.text then
               log:warning(
               "A function named '%s' is being redefined. The previous definition's comment will be discarded.",
               item.name)

            end
         end
      else
         assert(false)
      end
   end

   state.env.registry[path] = item
   item.path = path
   return path
end

local function get_path(item, state, typ)
   assert(item.name)
   if typ and typ.typeid == state.module_item_typeid then
      state.env.registry["$" .. state.module_name].text = item.text
      return state.module_name
   end
   return state.path .. item.name
end

local function store_item(item, state, typ)
   local path = store_item_at_path(item, get_path(item, state, typ), state)
   if not path then return end
   if not item.parent then
      if not state.parent_item.children then
         state.parent_item.children = {}
      end
      item.parent = state.parent_item.path

      for _, child in ipairs(state.parent_item.children) do
         if child == path then
            return path
         end
      end
      table.insert(state.parent_item.children, path)
   end
   return path
end

local function function_item_for_node(node, visibility, kind, state)
   local item = {
      kind = "function",
      function_kind = kind,
      visibility = visibility,
      location = location_for_node(node),
   }

   if node.args and #node.args > 0 then
      item.params = {}
      for i, ar in ipairs(node.args) do
         if node.is_method and i == 1 then
            item.params[i] = {
               type = typeinfo_to_string(typeinfo_for_node(state.type_report, node.fn_owner)),
            }
         else
            item.params[i] = {
               type = ar.argtype and type_to_string(state.type_report, ar.argtype),
            }
            if visibility ~= "record" then
               item.params[i].name = ar.tk
            end
         end
      end
   end


   if node.rets and #node.rets.tuple > 0 then
      item.returns = {}
      for i, ret in ipairs(node.rets.tuple) do
         item.returns[i] = {
            type = type_to_string(state.type_report, ret),
         }
      end
   end

   if node.typeargs then
      item.typeargs = {}
      for i, typearg in ipairs(node.typeargs) do
         item.typeargs[i] = {
            name = typearg.typearg,
            constraint = typearg.constraint and type_to_string(state.type_report, typearg.constraint),
         }
      end
   end

   return item
end

local function item_for_function_type(t, visibility, kind, state, owner)
   local item = {
      kind = "function",
      function_kind = kind,
      visibility = visibility,
      is_declaration = true,
      location = location_for_type(t),
   }

   if t.typename == "generic" then
      local base = t.t
      assert(base.typename == "function")

      item.typeargs = {}
      for i, typearg in ipairs(t.typeargs) do
         local normalized = typearg.typearg:gsub("@.*", "")
         item.typeargs[i] = {
            name = normalized,
            constraint = typearg.constraint and type_to_string(state.type_report, typearg.constraint),
         }
      end

      t = base
   end
   t = t


   if t.args and #t.args.tuple > 0 then
      item.params = {}
      for i, ar in ipairs(t.args.tuple) do
         if t.is_method and i == 1 and owner then
            item.params[i] = {
               type = typeinfo_to_string(typeinfo_for_type(state.type_report, owner)),
            }
         else
            item.params[i] = {
               type = type_to_string(state.type_report, ar),
            }
         end
      end
   end


   if t.rets and #t.rets.tuple > 0 then
      item.returns = {}
      for i, ret in ipairs(t.rets.tuple) do
         item.returns[i] = {
            type = type_to_string(state.type_report, ret),
         }
      end
   end

   return item
end

local function item_for_function_typeinfo(t, visibility, state)
   local item = {
      kind = "function",
      visibility = visibility,
      function_kind = "normal",
      location = {
         filename = t.file,
         x = t.x,
         y = t.y,
      },
   }

   if t.typeargs and #t.typeargs > 0 then
      item.typeargs = {}
      for i, typearg in ipairs(t.typeargs) do
         item.typeargs[i] = {
            name = typearg[1],
            constraint = typearg[2] and typeinfo_to_string(state.type_report.types[typearg[2]]),
         }
      end
   end

   if t.args and #t.args > 0 then
      item.params = {}
      for i, ar in ipairs(t.args) do
         item.params[i] = {
            type = typeinfo_to_string(state.type_report.types[ar[1]]),
         }
      end
   end

   if t.rets and #t.rets > 0 then
      item.returns = {}
      for i, ret in ipairs(t.rets) do
         item.returns[i] = {
            type = typeinfo_to_string(state.type_report.types[ret[1]]),
         }
      end
   end

   return item
end

local function function_visitor(node, state)
   assert(node.kind == "local_function" or node.kind == "global_function" or node.kind == "record_function")

   local old_path = state.path
   local old_parent = state.parent_item

   local is_record = node.kind == "record_function"
   if is_record then
      assert(node.fn_owner)
      local typenum = typenum_for_node(state.type_report, node.fn_owner)
      assert(typenum)
      local parent_path = state.typenum_to_path[typenum]
      assert(parent_path)
      state.path = parent_path .. "."
      local parent = state.env.registry[parent_path]
      assert(parent)
      state.parent_item = parent
   end

   assert(node.name.kind == "identifier")
   local name = node.name.tk

   local visibility
   if node.kind == "local_function" then
      visibility = "local"
   elseif node.kind == "global_function" then
      visibility = "global"
   else
      visibility = "record"
   end
   local item = function_item_for_node(node, visibility, "normal", state)
   item.name = name
   process_comments(node.comments, item, state.env)
   local path = store_item(item, state)

   local parent_item = item
   if is_record and not path then



      parent_item = state.env.registry[state.path .. name]
   end

   state.path = state.path .. name .. "~"
   state.parent_item = parent_item
   visit_node(node.body, state)
   state.path = old_path
   state.parent_item = old_parent
end

local function macroexp_visitor(node, state)
   assert(node.kind == "local_macroexp")

   assert(node.name.kind == "identifier")
   local name = node.name.tk

   local macrodef = node.macrodef
   assert(macrodef.kind == "macroexp")

   local item = function_item_for_node(macrodef, "local", "macroexp", state)
   item.name = name
   process_comments(node.comments, item, state.env)
   store_item(item, state)
end

local function type_is_function(t)
   if t.typename == "generic" then
      local base = t.t
      return base.typename == "function"
   end
   return t.typename == "function"
end


local function variable_declarations_visitor(node, state)
   assert(node.kind == "local_declaration" or node.kind == "global_declaration")
   for i, name in ipairs(node.vars) do
      assert(name.kind == "identifier")
      local decltype = node.decltuple.tuple[i]
      local typeinfo

      local typename
      if decltype then
         typename = type_to_string(state.type_report, decltype)
      elseif node.kind == "local_declaration" then
         typeinfo = typeinfo_for_node(state.type_report, name)
         typename = typeinfo_to_string(typeinfo)
      elseif node.kind == "global_declaration" then
         typeinfo = typeinfo_for_global(state.type_report, name.tk)
         typename = typeinfo_to_string(typeinfo)
      end

      local item
      if typeinfo and typeinfo.t == 0x20 then
         item = item_for_function_typeinfo(typeinfo,
         node.kind == "local_declaration" and "local" or "global",
         state)

      elseif decltype and type_is_function(decltype) then
         item = item_for_function_type(decltype, node.kind == "local_declaration" and "local" or "global", "normal", state)
         item.is_declaration = true
      else
         local variable_item = {
            kind = "variable",
            typename = typename,
            visibility = node.kind == "local_declaration" and "local" or "global",
            location = location_for_node(name),
         }
         item = variable_item
      end
      item.name = name.tk

      process_comments(node.comments, item, state.env)
      store_item(item, state)
   end
end


local record_like_visitor

local function enum_visitor(t, _, state)

   local values = {}
   for value, _ in pairs(t.enumset) do
      table.insert(values, value)
   end
   table.sort(values)

   for _, value in ipairs(values) do
      local comments = t.value_comments and t.value_comments[value]

      local item = {
         kind = "enumvalue",
         name = "\"" .. value .. "\"",
         location = location_for_type(t),
      }

      process_comments(comments, item, state.env)
      store_item(item, state)
   end
end

local function typedecl_visitor(name, comments, t, visibility, state)
   local def = t.def
   local typeargs

   if def.typename == "generic" and def.typeargs then
      typeargs = {}
      for i, typearg in ipairs(def.typeargs) do
         typeargs[i] = {
            name = typearg.typearg,
            constraint = typearg.constraint and type_to_string(state.type_report, typearg.constraint),
         }
      end
      def = def.t
   end

   local typekind = "type"
   if def.typename == "record" then
      typekind = "record"
   elseif def.typename == "enum" then
      typekind = "enum"
   elseif def.typename == "interface" then
      typekind = "interface"
   end

   local item = {
      kind = "type",
      name = name,
      typename = type_to_string(state.type_report, def),
      typeargs = typeargs,
      visibility = visibility,
      location = location_for_type(t),
      type_kind = typekind,
   }
   process_comments(comments, item, state.env)

   local path = store_item(item, state, t)

   local typenum = typenum_for_type(state.type_report, t)
   if typenum then
      state.typenum_to_path[typenum] = path
   end

   if def.fields or def.typename == "enum" then
      local old_path = state.path
      local old_parent = state.parent_item
      state.path = path .. "."
      state.parent_item = item
      visit_type(def, item, state)
      state.path = old_path
      state.parent_item = old_parent
   end
end



record_like_visitor = function(t, declaration, state)



   local inherited_field_has_comments = {}
   local inherited_metafield_has_comments = {}


   local visited_typeids = {}
   if t.interface_list then
      if not declaration.inherits then
         declaration.inherits = {}
      end
      for _, iface in ipairs(t.interface_list) do
         if iface.typename == "nominal" then
            local resolved = iface.resolved
            if not visited_typeids[resolved.typeid] then
               visited_typeids[resolved.typeid] = true
               table.insert(declaration.inherits, type_to_string(state.type_report, iface))

               if resolved.fields then
                  for field_name, _ in pairs(resolved.fields) do
                     inherited_field_has_comments[field_name] = resolved.field_comments and resolved.field_comments[field_name] ~= nil or false
                  end
                  if resolved.meta_fields then
                     for field_name, _ in pairs(resolved.meta_fields) do
                        inherited_metafield_has_comments[field_name] = resolved.meta_field_comments and resolved.meta_field_comments[field_name] ~= nil or false
                     end
                  end
               end
            end
         elseif iface.typename == "array" then
            table.insert(declaration.inherits, type_to_string(state.type_report, iface))
         end
      end
   end

   local has_metafields = false

   local function field_visitor(name, field_type, comments, meta)


      if meta then
         if inherited_metafield_has_comments[name] ~= nil then
            if comments and inherited_metafield_has_comments[name] then
               log:warning("Field '%s' in record '%s' has comments both in the record and in the interface it inherits from. The comments from the interface will be discarded.", name, t.typename)
            elseif not comments then
               return
            end
         end
         if not has_metafields then
            has_metafields = true
            local metafields_item = {
               kind = "metafields",
               name = "$meta",
            }

            state.path = store_item(metafields_item, state) .. "."
            state.parent_item = metafields_item
         end
      else
         if inherited_field_has_comments[name] ~= nil then
            if comments and inherited_field_has_comments[name] then
               log:warning("Field '%s' in record '%s' has comments both in the record and in the interface it inherits from. The comments from the interface will be discarded.", name, t.typename)
            elseif not comments then
               return
            end
         end
      end

      if field_type.typename == "typedecl" then
         local c
         if comments then
            assert(#comments == 1)
            c = comments[1]
         end

         typedecl_visitor(name, c, field_type, "record", state)
         return
      end


      if field_type.typename == "poly" then
         local overload_item = {
            kind = "overload",
            name = name,
            children = {},
         }

         local base_path = store_item(overload_item, state)

         for i, function_type in ipairs(field_type.types) do
            local item = item_for_function_type(function_type, "record", meta and "metamethod" or "normal", state, t)
            item.name = name
            local param_types = {}
            if item.params then
               for param_idx, param in ipairs(item.params) do
                  param_types[param_idx] = param.type
               end
            end

            local path = base_path .. "(" .. table.concat(param_types, ", ") .. ")"
            store_item_at_path(item, path, state)
            item.parent = base_path
            table.insert(overload_item.children, path)
            if comments then
               process_comments(comments[i], item, state.env)
            end

         end
         return
      end

      local item

      if type_is_function(field_type) then
         item = item_for_function_type(field_type, "record", meta and "metamethod" or "normal", state, t)

      else
         local field_item = {
            kind = "variable",
            visibility = "record",
            typename = type_to_string(state.type_report, field_type),
            location = location_for_type(field_type),
         }
         item = field_item
      end
      item.name = name

      if comments then
         assert(#comments == 1)
         process_comments(comments[1], item, state.env)
      end

      store_item(item, state)
   end

   for _, field_name in ipairs(t.field_order) do
      local field_type = t.fields[field_name]
      local comments
      if t.field_comments then
         comments = t.field_comments[field_name]
      end

      field_visitor(field_name, field_type, comments)
   end
   if t.meta_fields then
      local old_path = state.path
      local old_parent = state.parent_item
      for _, field_name in ipairs(t.meta_field_order) do
         local field_type = t.meta_fields[field_name]
         local comments
         if t.meta_field_comments then
            comments = t.meta_field_comments[field_name]
         end

         field_visitor(field_name, field_type, comments, true)
      end
      if has_metafields then
         state.path = old_path
         state.parent_item = old_parent
      end
   end
end



local function type_declaration_visitor(node, state)
   assert(node.kind == "local_type" or node.kind == "global_type")
   assert(node.var.kind == "identifier")
   assert(node.value)
   local name = node.var.tk
   local newtype = node.value.newtype
   if newtype then
      typedecl_visitor(name, node.comments, newtype, node.kind == "local_type" and "local" or "global", state)
   end
end


local function if_visitor(node, state)
   assert(node.kind == "if")
   for _, block in ipairs(node.if_blocks) do
      visit_node(block, state)
   end
end

local function body_visitor(node, state)
   assert(node.body)
   visit_node(node.body, state)
end

local node_visitors = {
   ["statements"] = children_visitor,
   ["local_function"] = function_visitor,
   ["global_function"] = function_visitor,
   ["record_function"] = function_visitor,
   ["local_declaration"] = variable_declarations_visitor,
   ["global_declaration"] = variable_declarations_visitor,
   ["local_type"] = type_declaration_visitor,
   ["global_type"] = type_declaration_visitor,
   ["local_macroexp"] = macroexp_visitor,
   ["do"] = body_visitor,
   ["if"] = if_visitor,
   ["if_block"] = body_visitor,
   ["forin"] = body_visitor,
   ["fornum"] = body_visitor,
   ["while"] = body_visitor,
   ["repeat"] = body_visitor,
}

visit_node = function(node, state)
   if node.f == "@internal" then
      return
   end
   if node_visitors[node.kind] then
      node_visitors[node.kind](node, state)
   end
end

local type_visitors = {
   ["record"] = record_like_visitor,
   ["interface"] = record_like_visitor,
   ["enum"] = enum_visitor,
}

visit_type = function(t, item, state)
   if type_visitors[t.typename] then
      type_visitors[t.typename](t, item, state)
   end
end

local TealParser = {}





local function get_sourcedir_from_config()
   local path_separator = package.config:sub(1, 1)
   local filename = "tlconfig.lua"
   local file = nil
   for _ = 1, 20 do
      file = io.open(filename, "r")
      if file then
         break
      end
      filename = ".." .. path_separator .. filename
   end

   if not file then
      log:debug("Could not find tlconfig.tl in the current directory or any parent directory.")
      return ""
   end

   local contents = file:read("*a")
   if contents then
      local load_config, err = load(contents)
      if not load_config then
         log:error("Error loading tlconfig.lua:\n" .. err)
         return ""
      end
      local ok, config = pcall(load_config)
      if not ok then
         log:error("Error executing tlconfig.lua:\n" .. tostring(config))
         return ""
      end

      if type(config) == "table" then
         local source_dir = config.source_dir
         if source_dir and type(source_dir) == "string" then
            return source_dir
         else
            log:debug("tlconfig.lua does not contain 'source_dir' field.")
            return ""
         end
      else
         log:error("tlconfig.lua did not return a table.")
         return ""
      end
   end
end

function TealParser.init(source_dir)
   source_dir = source_dir or get_sourcedir_from_config()

   log:debug("TealParser initialized with source directory: \"" .. tostring(source_dir) .. "\"")

   local parser = {
      source_dir = source_dir,
      file_extensions = TealParser.file_extensions,
      tl_env = tl.new_env(),
      typenum_to_path = {},
   }
   parser.tl_env.report_types = true

   local self = setmetatable(parser, { __index = TealParser })
   return self
end

TealParser.file_extensions = { ".tl", ".d.tl" }


local function get_module_name_from_path(path, source_dir)
   local path_separator = package.config:sub(1, 1)


   local relative_path = path
   if source_dir and source_dir ~= "" then
      local source_dir_pattern = source_dir:gsub("([^%w])", "%%%1")
      if path:find("^" .. source_dir_pattern) then
         relative_path = path:sub(#source_dir + 1)

         if relative_path:sub(1, 1) == path_separator then
            relative_path = relative_path:sub(2)
         end
      end
   end


   local components = {}
   for component in relative_path:gmatch("[^" .. path_separator .. "]+") do
      table.insert(components, component)
   end

   if #components == 0 then
      return ""
   end


   local last = components[#components]
   components[#components] = last:match("^([^%.]+)") or last

   return table.concat(components, ".")
end

function TealParser:process(text, path, env)

   local result = tl.check_string(text, self.tl_env, path)

   local reporter = result.env.reporter

   local module_name = get_module_name_from_path(path, self.source_dir)
   log:info("Processing Teal module '%s' from file '%s'", module_name, path)

   local module_item = {
      kind = "module",
      name = module_name,
      location = {
         filename = path,
         x = 1,
         y = 1,
      },
      children = {},
      path = "$" .. module_name,
   }

   local state = {
      env = env,
      path = module_name .. "~",
      module_name = module_name,
      type_report = reporter.tr,
      typenum_to_path = self.typenum_to_path,
      parent_item = module_item,
      module_item_typeid = result.type.typeid,
   }
   table.insert(env.modules, module_name)
   env.registry[module_item.path] = module_item
   visit_node(result.ast, state)
end

return TealParser
