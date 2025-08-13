local tealdoc = require("tealdoc")

local record MarkdownInput is tealdoc.Parser
end

MarkdownInput.file_extensions = {".md"}
function MarkdownInput:process(text: string, filename: string, env: tealdoc.Env)
   local module_name = filename:gsub("/", "."):gsub("%.md$", "")
   local item: tealdoc.Item = {
        path = "$"..module_name,
        kind = "markdown",
        text = text,
        name = module_name,
   }
   env.registry[item.path] = item

   table.insert(env.modules, module_name)
end

return MarkdownInput