local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local HTMLBuilder = require("tealdoc.generator.html.builder")
local Highlighter = require("tealdoc.generator.site.highlighter")
local Scintillua = require("tealdoc.generator.site.scintillua")
local Text = require("tealdoc.generator.text")

local SiteMarkdown = {}






local escape_html = Text.escape_html

local admonition_kinds = {
   ["danger"] = "Danger",
   ["info"] = "Info",
   ["note"] = "Note",
   ["tip"] = "Tip",
   ["warning"] = "Warning",
}

local function rope_to_string(rope)
   local output = {}
   local walk
   walk = function(value)
      local value_type = type(value)
      if value_type == "table" then
         for _, child in ipairs(value) do
            walk(child)
         end
      elseif value_type == "function" then
         local callback = value
         local ok
         local result
         ok, result = pcall(callback)
         if ok then
            walk(result)
         end
      elseif value ~= nil then
         table.insert(output, tostring(value))
      end
   end
   walk(rope)
   return table.concat(output)
end




local group_index = 0

local function site_div(
   content,
   attributes)

   local classes = attributes and attributes.class or ""
   local kind
   local title
   kind, title = classes:match("^([%w_-]+)%s*(.-)%s*$")
   if kind == "details" then
      if title == "" then
         title = "Details"
      end
      return {
         '<details class="tealdoc-details"><summary>' ..
         escape_html(title) ..
         '</summary><div class="tealdoc-details-content">',
         content,
         "</div></details>",
      }
   elseif kind == "code-group" then







      local rendered = rope_to_string(content)
      local tabs = {}
      local count = 0
      group_index = group_index + 1
      local name = "tealdoc-code-group-" .. tostring(group_index)
      for caption, body in rendered:gmatch(
         '<figure class="tealdoc%-labeled%-code"><figcaption>(.-)</figcaption>(.-)</figure>') do

         count = count + 1
         local id = name .. "-" .. tostring(count)
         table.insert(
         tabs,
         '<input class="tealdoc-code-tab-input" type="radio" name="' ..
         name ..
         '" id="' ..
         id ..
         '"' ..
         (count == 1 and " checked" or "") ..
         '><label class="tealdoc-code-tab" for="' ..
         id ..
         '">' ..
         caption ..
         '</label><figure class="tealdoc-code-panel">' ..
         body ..
         "</figure>")

      end


      if count == 0 then
         return {
            '<div class="tealdoc-code-group" role="group">',
            content,
            "</div>",
         }
      end
      return {
         '<div class="tealdoc-code-group" role="radiogroup"' ..
         ' aria-label="Code examples">' ..
         table.concat(tabs) ..
         "</div>",
      }
   elseif kind == "tealdoc-code-label" then
      return {
         '<figure class="tealdoc-labeled-code"><figcaption>' ..
         escape_html(title) ..
         "</figcaption>",
         content,
         "</figure>",
      }
   end
   if kind and admonition_kinds[kind] then
      if title == "" then
         title = admonition_kinds[kind]
      end
      if kind == "info" then
         kind = "note"
      end
      return {
         '<aside class="tealdoc-admonition tealdoc-admonition-' ..
         escape_html(kind) ..
         '" role="note"><p class="tealdoc-admonition-title">' ..
         escape_html(title) ..
         "</p>",
         content,
         "</aside>",
      }
   end

   local class_attribute = classes ~= "" and
   ' class="' .. escape_html(classes) .. '"' or
   ""
   local id_attribute = attributes and
   attributes.id and
   ' id="' .. escape_html(attributes.id) .. '"' or
   ""
   return { "<div" .. id_attribute .. class_attribute .. ">", content, "</div>" }
end

local github_admonition_kinds = {
   ["CAUTION"] = "danger",
   ["IMPORTANT"] = "important",
   ["NOTE"] = "note",
   ["TIP"] = "tip",
   ["WARNING"] = "warning",
}

local function site_blockquote(content)
   local rendered = rope_to_string(content)
   local marker
   local body
   marker, body = rendered:match("^%s*%[!([A-Z]+)%]%s*(.*)$")
   if not marker then
      local paragraph
      local following
      marker, paragraph, following = rendered:match(
      "^%s*<p>%s*%[!([A-Z]+)%]%s*(.-)</p>(.*)$")

      if marker then
         body = paragraph .. following
      end
   end
   local kind = marker and github_admonition_kinds[marker]
   if not kind then
      return { "<blockquote>", content, "</blockquote>" }
   end
   local title = marker:sub(1, 1) .. marker:sub(2):lower()
   return {
      '<aside class="tealdoc-admonition tealdoc-admonition-' ..
      kind ..
      '" role="note"><p class="tealdoc-admonition-title">' ..
      title ..
      "</p>",
      body,
      "</aside>",
   }
end

local function heading_slug(text)
   local value = text:gsub("!?%[([^%]]+)%]%b()", "%1"):
   gsub("!?%[([^%]]+)%]%s*%[[^%]]*%]", "%1"):
   gsub("`+", ""):
   gsub("\\(.)", "%1")
   return Text.slug(value)
end

local function markdown_heading_slugs(markdown)
   local slugs = {}
   local previous = ""
   local fence_character = ""
   local fence_length = 0
   for line in (markdown .. "\n"):gmatch("(.-)\n") do
      local next_previous = ""
      if fence_character ~= "" then
         local closing = line:match("^%s*([`~]+)%s*$")
         if closing and
            closing:sub(1, 1) == fence_character and
            #closing >= fence_length then

            fence_character = ""
            fence_length = 0
         end
      else
         local opening = line:match("^%s*([`~]+)")
         if opening and #opening >= 3 then
            fence_character = opening:sub(1, 1)
            fence_length = #opening
         else
            local hashes, heading_text = line:match("^%s*(#+)%s+(.+)$")
            if hashes and #hashes <= 6 then
               heading_text = heading_text:gsub("%s+#+%s*$", ""):
               gsub("%s+{[^}]*}%s*$", "")
               table.insert(slugs, heading_slug(heading_text))
            elseif previous:match("%S") and
               line:match("^%s*[=-]+%s*$") then

               local setext_text = previous:gsub(
               "%s+{[^}]*}%s*$",
               "")

               table.insert(slugs, heading_slug(setext_text))
            else
               next_previous = line
            end
         end
      end
      previous = next_previous
   end
   return slugs
end

function SiteMarkdown.render(
   markdown,
   type_links)

   local heading_slugs = markdown_heading_slugs(markdown)
   local heading_index = 0
   local prepared = {}
   local fence
   local labeled_fence = false
   for line in (markdown .. "\n"):gmatch("(.-)\n") do
      if fence then
         table.insert(prepared, line)
         if line:match("^%s*" .. fence .. "%s*$") then
            fence = nil
            if labeled_fence then
               table.insert(prepared, "::::")
               labeled_fence = false
            end
         end
      else
         local indentation, opening, language, label = line:match(
         "^(%s*)(`+)([%w_+%-]+)%s+%[([^%]]+)%]%s*$")

         if opening and #opening >= 3 then
            table.insert(
            prepared,
            indentation .. ":::: tealdoc-code-label " .. label)

            table.insert(prepared, indentation .. opening .. language)
            fence = opening
            labeled_fence = true
         else
            local plain_fence = line:match("^%s*(```+)")
            if plain_fence then
               fence = plain_fence
            end
            table.insert(prepared, line)
         end
      end
   end
   markdown = table.concat(prepared, "\n")

   local builder = HTMLBuilder.init({
      fenced_divs = true,
      blockquote = site_blockquote,
      div = site_div,
      header = function(
         content,
         level,
         attributes)

         heading_index = heading_index + 1
         local id = attributes.id and
         ' id="' .. escape_html(attributes.id) .. '"' or
         ""
         local class = attributes.class and attributes.class ~= "" and
         ' class="' .. escape_html(attributes.class) .. '"' or
         ""
         local lang = attributes.lang and
         ' lang="' .. escape_html(attributes.lang) .. '"' or
         ""
         local natural = heading_slugs[heading_index]
         local identity = level <= 4 and natural and natural ~= "" and
         ' data-tealdoc-heading-slug="' ..
         escape_html(natural) ..
         '"' or
         ""
         return {
            "<h",
            level,
            id,
            class,
            lang,
            identity,
            ">",
            content,
            "</h",
            level,
            ">",
         }
      end,
   })
   builder:md(markdown)
   local html = builder:build()


   html = html:gsub("\n+(</code></pre>)", "%1")
















   local links_for = {
      teal = type_links or {},
      lua = {},
   }
   html = html:gsub(
   '<pre><code class="language%-([^"]+)">(.-)</code></pre>',
   function(info, code)
      local language = info:match("^([%w_#+-]+)") or info
      code = code:gsub("&lt;", "<"):
      gsub("&gt;", ">"):
      gsub("&quot;", '"'):
      gsub("&#39;", "'"):
      gsub("&amp;", "&")




      local links = links_for[language]
      local body
      if links then
         body = Highlighter.highlight(code, links)
      else
         local segments = Scintillua.segments(language, code)
         body = segments and
         Highlighter.render(code, segments) or
         escape_html(code)
      end
      return '<div class="tealdoc-code-block" data-lang="' ..
      escape_html(language) ..
      '"><pre class="language-' ..
      escape_html(info) ..
      '"><code class="language-' ..
      escape_html(info) ..
      '">' ..
      body ..
      "</code></pre></div>"
   end)

   return html
end

return SiteMarkdown
