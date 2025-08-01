local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local type = type; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local log = require("tealdoc.log")

local MarkdownBuilder = {}



function MarkdownBuilder.init()
   local builder = {
      output = {},
   }

   local self = setmetatable(builder, { __index = MarkdownBuilder })

   return self
end



MarkdownBuilder.h1 = function(self, content)
   self:rawtext("# ")
   self:line(content)
   return self
end
MarkdownBuilder.h2 = function(self, content)
   self:rawtext("## ")
   self:line(content)
   return self
end
MarkdownBuilder.h3 = function(self, content)
   self:rawtext("### ")
   self:line(content)
   return self
end
MarkdownBuilder.h4 = function(self, content)
   self:rawtext("#### ")
   self:line(content)
   return self
end
MarkdownBuilder.h5 = function(self, content)
   self:rawtext("##### ")
   self:line(content)
   return self
end
MarkdownBuilder.h6 = function(self, content)
   self:rawtext("###### ")
   self:line(content)
   return self
end
MarkdownBuilder.line = function(self, ...)
   self:text(...)
   self:rawtext("\n")
   return self
end

MarkdownBuilder.link = function(self, to, ...)

   self:text(...)
   return self
end


local function escape_markdown(text)
   return text
end

MarkdownBuilder.text = function(self, ...)
   for i = 1, select("#", ...) do
      local c = select(i, ...)
      if type(c) == "string" then
         table.insert(self.output, escape_markdown(c))
      else
         c(self)
      end
   end
   return self
end

MarkdownBuilder.rawline = function(self, ...)
   self:rawtext(...)
   self:rawtext("\n")
   return self
end

MarkdownBuilder.rawtext = function(self, ...)
   for i = 1, select("#", ...) do
      local c = select(i, ...)
      if type(c) == "string" then
         table.insert(self.output, c)
      else
         c(self)
      end
   end
   return self
end


MarkdownBuilder.paragraph = function(self, ...)
   self:line()
   self:text(...)
   self:line()
   return self
end

MarkdownBuilder.code_block = function(self, content)
   self:rawline("```")
   content()
   self:rawline("```")
   return self
end
MarkdownBuilder.ordered_list = function(self, content)
   local cnt = 1
   local item = function(item_content)
      self:rawtext(tostring(cnt), ". ")
      cnt = cnt + 1
      item_content()
      self:line()
   end

   self:line()
   content(item)
   self:line()
   return self
end
MarkdownBuilder.unordered_list = function(self, content)
   local item = function(item_content)
      self:rawtext("- ")
      item_content()
      self:line()
   end

   self:line()
   content(item)
   self:line()
   return self
end

MarkdownBuilder.b = function(self, text)
   self:rawtext("**")
   self:text(text)
   self:rawtext("**")
   return self
end
MarkdownBuilder.i = function(self, text)
   self:rawtext("*")
   self:text(text)
   self:rawtext("*")
   return self
end
MarkdownBuilder.code = function(self, text)
   self:rawtext("`")
   self:text(text)
   self:rawtext("`")
   return self
end
MarkdownBuilder.md = function(self, text)
   self:rawtext(text)
   return self
end
MarkdownBuilder.build = function(self)
   return table.concat(self.output, "")
end

local MarkdownGenerator = {}




MarkdownGenerator.builder = MarkdownBuilder.init()


MarkdownGenerator.item_phases = {}

MarkdownGenerator.generate_for_item = function(self, item, env)
   local is_module = env.registry["$" .. (item.path)]

   if not env.include_all then
      local has_local_tag = item.attributes and item.attributes["local"]
      local is_declared_as_local = type(item) == "table" and item.visibility == "local"
      if has_local_tag or (is_declared_as_local and not is_module) then
         return
      end
   end
   local phases = self.item_phases[item.kind]

   if item.kind == "function" and item.function_kind == "metamethod" and item.name == "__is" then
      return
   end
   if not item.text and not is_module and (item.kind == "function" or item.kind == "type" or item.kind == "variable" or item.kind == "enumvalue") and not env.no_warnings_on_missing then
      log:warning("Documentation missing for item: " .. item.path)
   end

   local penv = {
      builder = self.builder,
      path_mode = "full",
      env = env,
   }

   if phases and not is_module then
      for _, phase in ipairs(phases) do
         phase.run(penv, item)
      end
   end

   if item.children and not (item.kind == "function") then
      for _, child_name in ipairs(item.children) do
         local child_item = env.registry[child_name]
         assert(child_item)
         self:generate_for_item(child_item, env)
      end
   end
end

MarkdownGenerator.run = function(self, filename, env)
   for _, module in ipairs(env.modules) do
      local module_item = env.registry["$" .. module]
      assert(module_item)
      self:generate_for_item(module_item, env)
   end

   local file = io.open(filename, "w")
   assert(file)
   file:write(self.builder:build())
   file:close()
end

return MarkdownGenerator
