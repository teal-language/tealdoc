local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string






local log = require("tealdoc.log")

local tealdoc = { Location = {}, Env = {}, Typearg = {}, FunctionItem = { Param = {}, Return = {} }, VariableItem = {}, TypeItem = {} }






























































































































































































































































































function tealdoc.Env.init()
   local env = {
      parser_registry = {},
      tag_registry = {},
      registry = {},
      modules = {},
      add_parser = tealdoc.Env.add_parser,
      add_tag = tealdoc.Env.add_tag,
   }

   return env
end

function tealdoc.Env:add_tag(tag)
   assert(tag.name and tag.handle)
   if self.tag_registry[tag.name] then

      log:error("duplicate tag name detected: '" .. tag.name .. "'. Each tag must have a unique name.")
   end
   self.tag_registry[tag.name] = tag
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
