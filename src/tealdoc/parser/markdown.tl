local tealdoc = require("tealdoc")

local record MarkdownInput is tealdoc.Parser
end

MarkdownInput.file_extensions = {".md"}
function MarkdownInput:process(text: string, filename: string, env: tealdoc.Env)
   local item: tealdoc.Item = {
        path = "$"..filename,
        kind = "markdown",
        text = text     
   } 
   env.registry[item.path] = item

   table.insert(env.modules, filename)
end

return MarkdownInput