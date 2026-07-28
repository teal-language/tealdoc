local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local log = require("tealdoc.log")

local MarkdownBuilder = {}




function MarkdownBuilder.init()
   local builder = {
      output = {},
      in_code = false,
   }

   local self = setmetatable(builder, { __index = MarkdownBuilder })

   return self
end



local function escape_html(text)
   local output = text:gsub("([&<>'\"])", {
      ["&"] = "&amp;",
      ["<"] = "&lt;",
      [">"] = "&gt;",
      ["'"] = "&#39;",
      ['"'] = "&quot;",
   })
   return output
end

MarkdownBuilder.h1 = function(self, ...)
   self:rawtext("# ")
   self:line(...)
   return self
end
MarkdownBuilder.h2 = function(self, ...)
   self:rawtext("## ")
   self:line(...)
   return self
end
MarkdownBuilder.h3 = function(self, ...)
   self:rawtext("### ")
   self:line(...)
   return self
end
MarkdownBuilder.h4 = function(self, ...)
   self:rawtext("#### ")
   self:line(...)
   return self
end
MarkdownBuilder.h5 = function(self, ...)
   self:rawtext("##### ")
   self:line(...)
   return self
end
MarkdownBuilder.h6 = function(self, ...)
   self:rawtext("###### ")
   self:line(...)
   return self
end
MarkdownBuilder.line = function(self, ...)
   self:text(...)
   self:rawtext("\n")
   return self
end

MarkdownBuilder.link = function(self, to, ...)
   if self.in_code then
      self:text(...)
      return self
   end
   self:rawtext("<a href=\"#", escape_html(to), "\">")
   self:text(...)
   self:rawtext("</a>")
   return self
end

MarkdownBuilder.link_url = function(self, url, ...)
   if self.in_code then
      self:text(...)
      return self
   end
   self:rawtext("[")
   self:text(...)
   self:rawtext("](", url:gsub("([%s%)])", "\\%1"), ")")
   return self
end

MarkdownBuilder.text = function(self, ...)
   for i = 1, select("#", ...) do
      local c = select(i, ...)
      if type(c) == "string" then
         table.insert(self.output, self.in_code and c or escape_html(c))
      elseif type(c) == "function" then
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
      elseif type(c) == "function" then
         c(self)
      end
   end
   return self
end


MarkdownBuilder.paragraph = function(self, ...)
   self:line()
   self:text(...)
   self:line()
   self:line()
   return self
end

MarkdownBuilder.code_block = function(self, content)
   self:line()
   self:rawline("```teal")
   self.in_code = true
   content()
   self.in_code = false
   self:rawline("```")
   self:line()
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

MarkdownBuilder.b = function(self, ...)
   self:rawtext("**")
   self:text(...)
   self:rawtext("**")
   return self
end
MarkdownBuilder.i = function(self, ...)
   self:rawtext("*")
   self:text(...)
   self:rawtext("*")
   return self
end
MarkdownBuilder.code = function(self, ...)
   self:rawtext("`")
   local was_in_code = self.in_code
   self.in_code = true
   self:text(...)
   self.in_code = was_in_code
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

function MarkdownGenerator.resolve_type_url(
   env,
   path,
   type_url_for_path)

   local seen = {}
   while path and not seen[path] do
      seen[path] = true
      local item = env.registry[path]
      if not item then
         return type_url_for_path(path)
      end
      if Generator.filter(item, env) then
         return type_url_for_path(path) or "#" .. path
      end
      if item.kind == "type" and
         item.type_kind == "type" and
         item.alias_target then

         path = item.alias_target
      else
         return nil
      end
   end
   return nil
end

MarkdownGenerator.init = function(output, type_url_for_path)
   local builder = MarkdownBuilder.init()
   local base = Generator.Base.init()
   base.item_phases = MarkdownGenerator.item_phases
   base.on_item_start = function(_, item, _, _)
      builder:rawline("<a id=\"", escape_html(item.path), "\"></a>")
   end
   base.on_context_for_item = function(_, ctx, _, _, env)
      ctx.builder = builder
      ctx.path_mode = "full"
      ctx.url_for_path = function(path)
         return env.registry[path] and "#" .. path or nil
      end
      if type_url_for_path then
         ctx.url_for_type = function(path)
            return MarkdownGenerator.resolve_type_url(
            env,
            path,
            type_url_for_path)

         end
      end
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
