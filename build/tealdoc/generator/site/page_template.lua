local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local RestyTemplate = require("resty.template")
local layout = require("tealdoc.generator.site.templates.layout")
local header = require("tealdoc.generator.site.templates.header")
local content = require("tealdoc.generator.site.templates.content")
local home = require("tealdoc.generator.site.templates.home")
local footer = require("tealdoc.generator.site.templates.footer")

local PageTemplate = {}



local defaults = {
   ["layout.html"] = layout,
   ["header.html"] = header,
   ["content.html"] = content,
   ["home.html"] = home,
   ["footer.html"] = footer,
}

local required = {
   "language",
   "title",
   "description",
   "head",
   "stylesheet_url",
   "pico_stylesheet_url",
   "search_index_url",
   "script_url",
   "brand",
   "top_navigation",
   "header_actions",
   "sidebar_links",
   "shell_class",
   "sidebar",
   "content_class",
   "breadcrumbs",
   "mobile_outline",
   "content",
   "home_hero",
   "page_navigation",
   "outline",
   "search_dialog",
   "footer_class",
   "footer_items",
   "content_template",
}

local function read_optional(path)
   local file = io.open(path, "rb")
   if not file then
      return nil
   end
   local contents = assert(file:read("*a"), "Could not read " .. path)
   file:close()
   return contents
end

local function indent_block(block, indent)
   if block == "" then
      return ""
   end
   local output = {}
   local position = 1
   local in_pre = false
   while true do
      local newline = block:find("\n", position, true)
      local line
      if newline then
         line = block:sub(position, newline - 1)
      else
         line = block:sub(position)
      end
      table.insert(output, in_pre and line or indent .. line)
      if line:find("<pre[%s>]") then
         in_pre = true
      end
      if line:find("</pre>", 1, true) then
         in_pre = false
      end
      if not newline then
         break
      end
      table.insert(output, "\n")
      position = newline + 1
   end
   return table.concat(output)
end

function PageTemplate.render(
   values,
   override_root)

   for _, name in ipairs(required) do
      assert(values[name] ~= nil, "missing page template value: " .. name)
   end

   local engine = RestyTemplate.new({})
   engine.load = function(name, plain)
      if plain == true then
         return name
      end
      local fallback = assert(
      defaults[name],
      "unknown site template: " .. name)

      if override_root and override_root ~= "" then
         local separator = package.config:sub(1, 1)
         local custom = read_optional(override_root .. separator .. name)
         if custom then
            return custom
         end
      end
      return fallback
   end

   local context = {}
   for name, value in pairs(values) do
      context[name] = value
   end
   context.block = indent_block
   return engine.process_file("layout.html", context, "no-cache")
end

return PageTemplate
