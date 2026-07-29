local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local type = type; local Generator = require("tealdoc.generator")
local Text = require("tealdoc.generator.text")

local lunamark = require("lunamark")

local HTMLBuilder = { Options = {} }













function HTMLBuilder.init(options)
   local writer = lunamark.writer.html.new()
   local dynamic_writer = writer
   if options and options.blockquote then
      writer.blockquote = options.blockquote
   end
   if options and options.div then
      writer.div = options.div
   end
   if options and options.header then
      dynamic_writer["header"] = options.header
   end
   if options and options.paragraph then
      dynamic_writer["paragraph"] = options.paragraph
   end
   local reader_options = {
      fenced_code_blocks = true,
      fenced_divs = options and options.fenced_divs or false,
      header_attributes = true,
      pipe_tables = true,
   }
   local markdown_reader = lunamark.reader.markdown
   local create_reader = markdown_reader["new"]



   local parse = create_reader(writer, reader_options)

   local builder = {
      output = {},
      parse_md = parse,
   }

   local self = setmetatable(builder, { __index = HTMLBuilder })

   return self
end



function HTMLBuilder:tag(tag, ...)
   self:rawtext("<", tag, ">")
   self:text(...)
   self:rawline("</", tag, ">")
   return self
end

HTMLBuilder.h1 = function(self, ...)
   self:rawtext("<h1>")
   self:text(...)
   self:rawline("</h1>")
   return self
end
HTMLBuilder.h2 = function(self, ...)
   self:rawtext("<h2>")
   self:text(...)
   self:rawline("</h2>")
   return self
end
HTMLBuilder.h3 = function(self, ...)
   self:rawtext("<h3>")
   self:text(...)
   self:rawline("</h3>")
   return self
end
HTMLBuilder.h4 = function(self, ...)
   self:rawtext("<h4>")
   self:text(...)
   self:rawline("</h4>")
   return self
end
HTMLBuilder.h5 = function(self, ...)
   self:rawtext("<h5>")
   self:text(...)
   self:rawline("</h5>")
   return self
end
HTMLBuilder.h6 = function(self, ...)
   self:rawtext("<h6>")
   self:text(...)
   self:rawline("</h6>")
   return self
end
HTMLBuilder.line = function(self, ...)
   self:text(...)
   self:rawtext("\n")
   return self
end


HTMLBuilder.link = function(self, to, ...)
   self:rawtext("<a href=\"#", to, "\">")
   self:text(...)
   self:rawtext("</a>")
   return self
end

HTMLBuilder.link_url = function(self, url, ...)
   self:rawtext("<a href=\"", url, "\">")
   self:text(...)
   self:rawtext("</a>")
   return self
end

HTMLBuilder.text = function(self, ...)
   for i = 1, select("#", ...) do
      local c = select(i, ...)
      if type(c) == "string" then
         table.insert(self.output, Text.escape_html(c))
      elseif type(c) == "function" then
         c(self)
      end
   end
   return self
end

HTMLBuilder.rawline = function(self, ...)
   self:rawtext(...)
   self:rawtext("\n")
   return self
end

HTMLBuilder.rawtext = function(self, ...)
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

HTMLBuilder.paragraph = function(self, ...)
   self:rawline("<p>")
   self:text(...)
   self:rawline("</p>")
   return self
end

HTMLBuilder.code_block = function(self, content)
   self:rawtext("<pre><code class=\"code-block\">")
   self:text(content)
   self:rawline("</code></pre>")
   return self
end
HTMLBuilder.ordered_list = function(self, content)
   local item = function(item_content)
      self:rawtext("<li>")
      item_content()
      self:rawline("</li>")
   end

   self:rawline("<ol>")
   content(item)
   self:rawline("</ol>")
   return self
end
HTMLBuilder.unordered_list = function(self, content)
   local item = function(item_content)
      self:rawtext("<li>")
      item_content()
      self:rawline("</li>")
   end

   self:rawline("<ul>")
   content(item)
   self:rawline("</ul>")
   return self
end

HTMLBuilder.table = function(self, headers, content)
   local row = function(...)
      self:rawtext("<tr>")
      for i = 1, select("#", ...) do
         self:rawtext("<td>")
         local write = (select(i, ...))
         write()
         self:rawtext("</td>")
      end
      self:rawline("</tr>")
   end

   self:rawline("<table>")
   self:rawtext("<thead><tr>")
   for _, header in ipairs(headers) do
      self:rawtext("<th>")
      self:text(header)
      self:rawtext("</th>")
   end
   self:rawline("</tr></thead>")
   self:rawline("<tbody>")
   content(row)
   self:rawline("</tbody>")
   self:rawline("</table>")
   return self
end

HTMLBuilder.b = function(self, ...)
   self:rawtext("<b>")
   self:text(...)
   self:rawtext("</b>")
   return self
end
HTMLBuilder.i = function(self, ...)
   self:rawtext("<i>")
   self:text(...)
   self:rawtext("</i>")
   return self
end
HTMLBuilder.code = function(self, ...)
   self:rawtext("<code>")
   self:text(...)
   self:rawtext("</code>")
   return self
end
HTMLBuilder.md = function(self, text)
   local parsed = self.parse_md(text)
   self:rawtext(parsed)
   return self
end

HTMLBuilder.build = function(self)
   return table.concat(self.output, "")
end

return HTMLBuilder
