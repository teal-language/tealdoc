local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.tool.generator")

local MarkdownBuilder = {}



function MarkdownBuilder.init()
   local builder = {
      output = {},
   }

   local self = setmetatable(builder, { __index = MarkdownBuilder })

   return self
end

MarkdownBuilder.h1 = function(self, text)
   self:line("# ", text)
   return self
end
MarkdownBuilder.h2 = function(self, text)
   self:line("## ", text)
   return self
end
MarkdownBuilder.h3 = function(self, text)
   self:line("### ", text)
   return self
end
MarkdownBuilder.h4 = function(self, text)
   self:line("#### ", text)
   return self
end
MarkdownBuilder.h5 = function(self, text)
   self:line("##### ", text)
   return self
end
MarkdownBuilder.h6 = function(self, text)
   self:line("###### ", text)
   return self
end
MarkdownBuilder.line = function(self, ...)
   self:text(...)
   self:text("\n")
   return self
end
MarkdownBuilder.text = function(self, ...)
   for i = 1, select("#", ...) do
      table.insert(self.output, (select(i, ...)))
   end
   return self
end
MarkdownBuilder.code_block = function(self, content)
   self:line("```")
   content()
   self:line("```")
   return self
end
MarkdownBuilder.ordered_list = function(self, content)
   local cnt = 1
   local item = function(item_content)
      self:text(tostring(cnt), ". ")
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
      self:text("- ")
      item_content()
      self:line()
   end

   self:line()
   content(item)
   self:line()
   return self
end

MarkdownBuilder.b = function(self, text)
   return "**" .. text .. "**"
end
MarkdownBuilder.i = function(self, text)
   return "*" .. text .. "*"
end
MarkdownBuilder.code = function(self, text)
   return "`" .. text .. "`"
end

MarkdownBuilder.build = function(self)
   return table.concat(self.output, "")
end

local MarkdownGenerator = {}



MarkdownGenerator.builder = MarkdownBuilder.init()

MarkdownGenerator.run = function(self, filename, env)
   for _, module in ipairs(env.modules) do
      local module_item = env.registry["$" .. module]
      assert(module_item)
      Generator.generate_for_item(self, module_item, env)
   end

   local file = io.open(filename, "w")
   assert(file)
   file:write(self.builder:build())
   file:close()
end

return MarkdownGenerator
