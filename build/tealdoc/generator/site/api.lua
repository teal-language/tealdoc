local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local Highlighter = require("tealdoc.generator.site.highlighter")
local SiteTypes = require("tealdoc.generator.site.types")

local SiteApi = {}

















local function read_file(path)
   local file = assert(io.open(path, "rb"), "Could not open " .. path)
   local contents = assert(file:read("*a"), "Could not read " .. path)
   file:close()
   return contents
end

function SiteApi.source_markdown(page)
   if page.example_source then
      local code = page.example_code or read_file(page.example_source)
      local language = page.example_language
      if not language then
         language = page.example_source:match("%.tl$") and "teal" or
         page.example_source:match("%.lua$") and "lua" or
         "text"
      end
      local fence = "```"
      while code:find(fence, 1, true) do
         fence = fence .. "`"
      end
      local output = "# " .. page.title .. "\n\n"
      if page.description then
         output = output .. page.description .. "\n\n"
      end
      return output ..
      fence ..
      language ..
      "\n" ..
      code:gsub("\n*$", "") ..
      "\n" ..
      fence ..
      "\n"
   end
   if not page.source then
      return ""
   end

   local text = read_file(page.source)
   if text:sub(1, 4) == "---\n" then
      local ending = text:find("\n---\n", 5, true)
      if ending then
         text = text:sub(ending + 5)
      end
   end

   local generated = text:find("\n<!-- @generated", 1, true)
   if generated then
      text = text:sub(1, generated - 1)
   end
   return text
end

local function add_type_link(
   links,
   ambiguous,
   name,
   url)

   if not name or name == "" or not url then
      return
   end
   local function add(candidate)
      if ambiguous[candidate] then
         return
      end
      if links[candidate] and links[candidate] ~= url then
         links[candidate] = nil
         ambiguous[candidate] = true
      else
         links[candidate] = url
      end
   end
   add(name)
   local basename = name:match("([%w_]+)$")
   if basename and basename ~= name then
      add(basename)
   end
end

function SiteApi.type_links(
   view,
   resolver)

   local links = {}
   local ambiguous = {}
   if not view then
      return links
   end
   local env = view.env

   local function add_reference(reference)
      local url = MarkdownGenerator.resolve_type_url(
      env,
      reference.path,
      resolver,
      false)

      add_type_link(links, ambiguous, reference.name, url)
   end

   for path in pairs(view.public_paths) do
      local item = env.registry[path]
      if item and item.kind == "type" and
         path ~= view.public and
         Generator.filter(item, env) then

         add_type_link(links, ambiguous, item.name, resolver(path))
      elseif item and item.kind == "function" then
         for _, param in ipairs(item.params or {}) do
            for _, reference in ipairs(param.type_references or {}) do
               add_reference(reference)
            end
         end
         for _, result in ipairs(item.returns or {}) do
            for _, reference in ipairs(result.type_references or {}) do
               add_reference(reference)
            end
         end
      end
   end
   return links
end

local function add_kind_badges(markdown, env)
   for path, item in pairs(env.registry) do
      if item.kind ~= "module" and Generator.filter(item, env) then
         local anchor = '<a id="' .. path .. '"></a>'
         local _, anchor_end = markdown:find(anchor, 1, true)
         if anchor_end then
            local heading_start, heading_end = markdown:find(
            "\n##+ [^\n]+",
            anchor_end + 1)

            if heading_start == anchor_end + 1 then
               local kind = Generator.item_kind(item, env)
               local badge = ' <span class="tealdoc-kind-badge ' ..
               'tealdoc-kind-' ..
               kind ..
               '">' ..
               kind ..
               "</span>"
               markdown = markdown:sub(1, heading_end) ..
               badge ..
               markdown:sub(heading_end + 1)
            end
         end
      end
   end
   return markdown
end

function SiteApi.markdown(
   view,
   resolver,
   attached_examples,
   used_examples)

   if not view then
      return ""
   end

   local page_env = view.env

   local markdown = add_kind_badges(
   MarkdownGenerator.render(page_env, resolver, false),
   page_env)


   for item_path, examples in pairs(attached_examples or {}) do
      local anchor = '<a id="' .. item_path .. '"></a>'
      local first, ending = markdown:find(anchor, 1, true)
      if first then
         used_examples[item_path] = true
         local following = markdown:find("\n<a id=\"", ending + 1, true)
         local insertion = following or (#markdown + 1)
         local blocks = {}
         for _, example in ipairs(examples) do
            local fence = "```"
            while example.code:find(fence, 1, true) do
               fence = fence .. "`"
            end
            table.insert(
            blocks,
            "\n### " ..
            example.title ..
            "\n\n" ..
            fence ..
            example.language ..
            "\n" ..
            example.code:gsub("\n*$", "") ..
            "\n" ..
            fence ..
            "\n")

         end
         markdown = markdown:sub(1, insertion - 1) ..
         table.concat(blocks) ..
         markdown:sub(insertion)
      end
   end

   local module_anchor = '<a id="' .. view.public .. '"></a>'
   local _, ending = markdown:find(module_anchor, 1, true)
   if ending then
      markdown = markdown:sub(ending + 1)
   end
   markdown = "\n" .. markdown
   markdown = markdown:gsub("\n(##+) ", function(level)
      return "\n" .. string.rep("#", math.min(#level + 1, 6)) .. " "
   end)
   return markdown:sub(2)
end

local function item_text(item, env)
   if item.text and item.text ~= "" then
      return item.text
   end
   for _, child_path in ipairs(item.children or {}) do
      local child = env.registry[child_path]
      if child and child.text and child.text ~= "" then
         return child.text
      end
   end
   return ""
end

local function item_summary(item, env)
   local text = item_text(item, env)
   if text == "" then
      return "—"
   end
   text = text:gsub("```[%s%S]-```", " ")
   text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
   text = text:gsub("`([^`]*)`", "%1")
   text = text:gsub("<[^>]+>", " ")
   text = text:gsub("[%*~]", "")
   text = text:gsub("^%s*#+%s*", "")
   text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

   for index = 1, #text do
      local character = text:sub(index, index)
      local following = text:sub(index + 1, index + 1)
      if (character == "." or character == "!" or character == "?") and
         (following == "" or following:match("%s")) then

         text = text:sub(1, index)
         break
      end
   end

   local maximum = 120
   if #text > maximum then
      local shortened = text:sub(1, maximum - 3)
      shortened = shortened:match("^(.*)%s+%S*$") or shortened
      text = shortened:gsub("%s+$", "") .. "..."
   end
   return (text:gsub("\\", "\\\\"):gsub("|", "\\|"))
end

function SiteApi.summary(
   view,
   resolver)

   if not view then
      return ""
   end
   local env = view.env
   local module = env.registry[view.public]
   if not module or not module.children then
      return ""
   end

   local items = {}
   for _, path in ipairs(module.children) do
      local item = env.registry[path]
      if item and Generator.filter(item, env) then
         table.insert(items, item)
      end
   end
   table.sort(items, function(a, b)
      local left = a.name:lower()
      local right = b.name:lower()
      if left == right then
         return a.path < b.path
      end
      return left < right
   end)
   if #items == 0 then
      return ""
   end

   local output = {
      "| API | Kind | Description |\n",
      "| --- | --- | --- |\n",
   }
   for _, item in ipairs(items) do
      local url = resolver(item.path) or "#" .. item.path
      local kind = Generator.item_kind(item, env)
      table.insert(
      output,
      "| [`" ..
      item.name ..
      "`](" ..
      url ..
      ') | <span class="tealdoc-kind-badge tealdoc-kind-' ..
      kind ..
      '">' ..
      kind ..
      "</span> | " ..
      item_summary(item, env) ..
      " |\n")

   end
   return table.concat(output)
end

return SiteApi
