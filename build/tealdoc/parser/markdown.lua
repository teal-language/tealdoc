local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local tealdoc = require("tealdoc")

local MarkdownInput = {}


MarkdownInput.file_extensions = { ".md" }
function MarkdownInput:process(text, filename, env)
   local item = {
      path = "$" .. filename,
      kind = "markdown",
      text = text,
   }
   env.registry[item.path] = item

   table.insert(env.modules, filename)
end

return MarkdownInput
