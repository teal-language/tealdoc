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




local FUNCTION_KINDS = {
   ["function"] = true,
   method = true,
   metamethod = true,
   macro = true,
}

local function rebase_headings(text, target)
   local lines = {}
   for line in (text .. "\n"):gmatch("(.-)\n") do
      table.insert(lines, (line:gsub("\r$", "")))
   end

   local shallowest
   local fence_character
   local fence_length = 0
   for _, line in ipairs(lines) do
      local fence = line:match("^%s*(```+)") or
      line:match("^%s*(~~~+)")
      if fence then
         local character = fence:sub(1, 1)
         if not fence_character then
            fence_character = character
            fence_length = #fence
         elseif character == fence_character and #fence >= fence_length then
            fence_character = nil
            fence_length = 0
         end
      elseif not fence_character then
         local hashes = line:match("^%s*(#+)%s+")
         if hashes and #hashes <= 6 and
            (not shallowest or #hashes < shallowest) then

            shallowest = #hashes
         end
      end
   end
   if not shallowest then
      return text
   end

   local shift = target - shallowest
   fence_character = nil
   fence_length = 0
   for index, line in ipairs(lines) do
      local fence = line:match("^%s*(```+)") or
      line:match("^%s*(~~~+)")
      if fence then
         local character = fence:sub(1, 1)
         if not fence_character then
            fence_character = character
            fence_length = #fence
         elseif character == fence_character and #fence >= fence_length then
            fence_character = nil
            fence_length = 0
         end
      elseif not fence_character then
         local indentation, hashes, rest =
         line:match("^(%s*)(#+)(%s+.*)$")
         if hashes and #hashes <= 6 then
            local level = math.min(6, #hashes + shift)
            lines[index] = indentation ..
            string.rep("#", level) ..
            rest
         end
      end
   end
   return table.concat(lines, "\n")
end














function SiteApi.site_type_links(
   env,
   resolver)

   local links = {}
   local ambiguous = {}
   for path, item in pairs(env.registry) do
      if item.kind == "type" and Generator.filter(item, env) then
         add_type_link(links, ambiguous, item.name, resolver(path))
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

local function group_details(
   markdown,
   view)

   local env = view.env
   local module = env.registry[view.public]
   if not module or not module.children then
      return ""
   end

   local positioned = {}
   for _, path in ipairs(module.children) do
      local item = env.registry[path]
      if item and Generator.filter(item, env) then
         local anchor = '<a id="' .. path .. '"></a>'
         local start = markdown:find(anchor, 1, true)
         if start then
            table.insert(positioned, { item, start })
         end
      end
   end
   table.sort(
   positioned,
   function(
      left,
      right)

      return left[2] < right[2]
   end)


   local details = {}
   for index, entry in ipairs(positioned) do
      local ending = index < #positioned and
      positioned[index + 1][2] - 1 or
      #markdown
      details[entry[1].path] = markdown:sub(entry[2], ending):
      gsub("^%s+", ""):
      gsub("%s+$", "")
   end

   local items = {}
   for _, entry in ipairs(positioned) do
      table.insert(items, entry[1])
   end
   table.sort(items, function(a, b)
      local left = a.name:lower()
      local right = b.name:lower()
      if left == right then
         return a.path < b.path
      end
      return left < right
   end)

   local groups = {
      { "Functions", {} },
      { "Types", {} },
      { "Values", {} },
   }
   for _, item in ipairs(items) do
      local kind = Generator.item_kind(item, env)
      local group = 3
      if FUNCTION_KINDS[kind] then
         group = 1
      elseif item.kind == "type" then
         group = 2
      end
      table.insert(groups[group][2], item)
   end

   local output = {}
   for _, group in ipairs(groups) do
      if #group[2] > 0 then
         table.insert(output, "## " .. group[1])
         for _, item in ipairs(group[2]) do
            table.insert(output, details[item.path])
         end
      end
   end
   return table.concat(output, "\n\n")
end

function SiteApi.markdown(
   view,
   resolver,
   attached_examples,
   used_examples)

   if not view then
      return "", ""
   end

   local page_env = view.env

   local original_texts = {}
   for _, item in pairs(page_env.registry) do
      if item.kind ~= "module" and item.text and item.text ~= "" then
         table.insert(original_texts, { item, item.text })
         item.text = rebase_headings(item.text, 3)
      end
   end
   local markdown = add_kind_badges(
   MarkdownGenerator.render(page_env, resolver, false),
   page_env)

   for _, entry in ipairs(original_texts) do
      entry[1].text = entry[2]
   end

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

   local public_anchor = '<a id="' .. view.public .. '"></a>'
   local _, public_end = markdown:find(public_anchor, 1, true)
   if public_end then
      markdown = markdown:sub(public_end + 1)
   end
   local module_item = page_env.registry["$" .. view.public]
   local introduction = module_item and module_item.text and
   rebase_headings(module_item.text, 2) or
   ""
   markdown = "\n" .. markdown
   markdown = markdown:gsub("\n(##+) ", function(level)
      return "\n" .. string.rep("#", math.min(#level + 1, 6)) .. " "
   end)
   return group_details(markdown:sub(2), view), introduction
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
   local prefix = item.kind == "variable" and
   item.is_const and
   "`<const>` " or
   ""
   local text = item_text(item, env)
   if text == "" then
      return prefix .. "—"
   end
   text = text:gsub("```[%s%S]-```", " ")
   text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
   text = text:gsub("`([^`]*)`", "%1")
   text = text:gsub("<[^>]+>", " ")
   text = text:gsub("[%*~]", "")
   text = text:gsub("^%s*#+%s*", "")
   text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

   local sentences = 1
   if text:match("^Read%-only%.%s") or
      text:match("^Caller%-writable%.%s") or
      text:match("^Engine%-owned%.%s") then

      sentences = 2
   end
   local found = 0
   for index = 1, #text do
      local character = text:sub(index, index)
      local following = text:sub(index + 1, index + 1)
      if (character == "." or character == "!" or character == "?") and
         (following == "" or following:match("%s")) then

         found = found + 1
         if found == sentences then
            text = text:sub(1, index)
            break
         end
      end
   end

   local maximum = 120
   if #text > maximum then
      local shortened = text:sub(1, maximum - 3)
      shortened = shortened:match("^(.*)%s+%S*$") or shortened
      text = shortened:gsub("%s+$", "") .. "..."
   end
   return prefix .. (text:gsub("\\", "\\\\"):gsub("|", "\\|"))
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










   local groups = {
      { "Functions", "Function", false, {} },
      { "Types", "Type", true, {} },
      { "Values", "Value", true, {} },
   }
   for _, item in ipairs(items) do
      local kind = Generator.item_kind(item, env)
      local group = 3
      if FUNCTION_KINDS[kind] then
         group = 1
      elseif item.kind == "type" then
         group = 2
      end
      table.insert(groups[group][4], item)
   end

   local output = {}
   for _, group in ipairs(groups) do
      local heading, column = group[1], group[2]
      local show_kind, group_items = group[3], group[4]
      if #group_items > 0 then
         if #output > 0 then
            table.insert(output, "\n")
         end
         table.insert(output, "**" .. heading .. "**\n\n")
         if show_kind then
            table.insert(
            output,
            "| " .. column .. " | Kind | Description |\n")

            table.insert(output, "| --- | --- | --- |\n")
         else
            table.insert(output, "| " .. column .. " | Description |\n")
            table.insert(output, "| --- | --- |\n")
         end
         for _, item in ipairs(group_items) do
            local url = resolver(item.path) or "#" .. item.path
            local cells = "| [`" .. item.name .. "`](" .. url .. ") | "
            if show_kind then
               local kind = Generator.item_kind(item, env)
               cells = cells ..
               '<span class="tealdoc-kind-badge tealdoc-kind-' ..
               kind ..
               '">' ..
               kind ..
               "</span> | "
            end
            table.insert(
            output,
            cells ..
            item_summary(item, env) ..
            " |\n")

         end
      end
   end
   return table.concat(output)
end

return SiteApi
