local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local table = _tl_compat and _tl_compat.table or table; local type = type; local tealdoc = require("tealdoc")
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




MarkdownGenerator.item_phases = {}

MarkdownGenerator.init = function(output)
   local builder = MarkdownBuilder.init()
   local base = Generator.Base.init()
   base.item_phases = MarkdownGenerator.item_phases
   base.on_context_for_item = function(_, ctx, _, _, _)
      ctx.builder = builder
      ctx.path_mode = "full"
   end
   base.on_end = function(_, _)
      local file = io.open(output, "w")
      assert(file, "Could not open file for writing: " .. output)
      file:write(builder:build())
      file:close()
      log:info("Markdown documentation generated to " .. output)
   end
   return base
end

return MarkdownGenerator
