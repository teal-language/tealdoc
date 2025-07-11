local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string



local log = require("log")

local tealdoc = { TagHandler = { Context = {} }, Location = {}, Env = {}, Typearg = {}, FunctionItem = { Param = {}, Return = {} }, DirectiveItem = {}, VariableItem = {}, TypeItem = {} }







































































































































function tealdoc.is_item_local(item)
   if item.kind == "function" then
      return item.type == "local" or item.type == "macroexp"
   elseif item.kind == "variable" then
      return item.type == "local"
   elseif item.kind == "type" then
      return item.type == "local"
   else
      return false
   end
end

function tealdoc.is_item_global(item)
   if item.kind == "function" then
      return item.type == "global"
   elseif item.kind == "variable" then
      return item.type == "global"
   elseif item.kind == "type" then
      return item.type == "global"
   else
      return false
   end
end

function tealdoc.Env.init()
   local env = {
      parser_registry = {},
      tag_handler_registry = {},
      registry = {},
      modules = {},
      add_parser = tealdoc.Env.add_parser,
      add_tag_handler = tealdoc.Env.add_tag_handler,
   }

   return env
end

function tealdoc.Env:add_tag_handler(handler)
   assert(handler.name and handler.handle)
   if self.tag_handler_registry[handler.name] then

      log:error("duplicate tag name detected: '" .. handler.name .. "'. Each tag must have a unique name.")
   end
   self.tag_handler_registry[handler.name] = handler
end

function tealdoc.Env:add_parser(parser)
   assert(parser.file_extensions)
   for _, ext in ipairs(parser.file_extensions) do
      self.parser_registry[ext] = parser
   end
end


function tealdoc.process_file(path, env)
   local filename = path:match("([^/\\]*)$") or path
   local file = io.open(path, "r")
   if not file then
      log:error("Could not open file: " .. path)
      return
   end
   local text = file:read("*a")
   file:close()

   tealdoc.process_text(text, filename, env)
end

function tealdoc.process_text(text, filename, env)
   local ext = filename:match("%..*$")
   local parser = env.parser_registry[ext]
   if not parser then
      log:warning("No parser found for file '%s' (extension '%s'). File will be skipped.", filename, ext)
      return
   end
   parser.process(text, filename, env)
end

return tealdoc
