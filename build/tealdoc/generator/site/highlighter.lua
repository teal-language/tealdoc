local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tl = require("tl")

local Highlighter = {}












local type_names = {
   ["any"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["number"] = true,
   ["string"] = true,
   ["thread"] = true,
   ["unknown"] = true,
   ["userdata"] = true,
}

local contextual_keywords = {
   ["as"] = true,
   ["close"] = true,
   ["const"] = true,
   ["enum"] = true,
   ["global"] = true,
   ["interface"] = true,
   ["is"] = true,
   ["macroexp"] = true,
   ["metamethod"] = true,
   ["record"] = true,
   ["total"] = true,
   ["type"] = true,
   ["userdata"] = true,
   ["where"] = true,
}

local literal_keywords = {
   ["false"] = true,
   ["nil"] = true,
   ["true"] = true,
}

local punctuation = {
   ["("] = true,
   [")"] = true,
   ["["] = true,
   ["]"] = true,
   ["{"] = true,
   ["}"] = true,
   [","] = true,
   [";"] = true,
   [":"] = true,
   ["."] = true,
   ["?"] = true,
}

local function escape_html(text)
   return (text:gsub("([&<>'\"])", {
      ["&"] = "&amp;",
      ["<"] = "&lt;",
      [">"] = "&gt;",
      ["'"] = "&#39;",
      ['"'] = "&quot;",
   }))
end

local function token_style(tokens, index)
   local token = tokens[index]
   local kind = token.kind
   local text = token.tk
   local previous = tokens[index - 1]
   local following = tokens[index + 1]

   if kind == "keyword" and literal_keywords[text] then
      return "boolean"
   elseif kind == "keyword" then
      return "keyword"
   elseif kind == "string" then
      return "string"
   elseif kind == "number" or kind == "integer" then
      return "number"
   elseif kind == "op" then
      return "operator"
   elseif kind == "pragma" or kind == "pragma_identifier" or kind == "hashbang" then
      return "meta"
   elseif kind == "identifier" then
      if contextual_keywords[text] then
         return "keyword"
      elseif type_names[text] or text:match("^%u") then
         return "type"
      elseif following and following.tk == "(" then
         return "function"
      elseif previous and (previous.tk == "." or previous.tk == ":") then
         return "property"
      end
      return "variable"
   elseif punctuation[text] then
      return "punctuation"
   end
   return nil
end

local function token_classes(style, text)
   if style == "type" then
      return "token class-name tealdoc-token-type"
   elseif style == "meta" then
      return "token directive tealdoc-token-meta"
   elseif style == "keyword" then
      return "token keyword keyword-" ..
      text:gsub("[^%w%-]", "-") ..
      " tealdoc-token-keyword"
   elseif style == "function" then
      return "token function tealdoc-token-function"
   elseif style == "property" then
      return "token property tealdoc-token-property"
   elseif style == "variable" then
      return "token variable tealdoc-token-variable"
   elseif style == "boolean" then
      return "token boolean tealdoc-token-boolean"
   elseif style == "punctuation" then
      return "token punctuation tealdoc-token-punctuation"
   end
   return "token " .. style .. " tealdoc-token-" .. style
end

local function is_declaration_name(tokens, index)
   local cursor = index - 1
   while cursor >= 1 do
      local token = tokens[cursor]
      if token.tk == "record" or
         token.tk == "interface" or
         token.tk == "enum" or
         token.tk == "type" then

         return true
      elseif token.kind == "identifier" or token.tk == "." then
         cursor = cursor - 1
      else
         return false
      end
   end
   return false
end

function Highlighter.highlight(code, links)
   local offsets = { 1 }
   for position = 1, #code do
      if code:byte(position) == 10 then
         table.insert(offsets, position + 1)
      end
   end

   local tokens = tl.lex(code, "tealdoc-code-block.tl")
   local segments = {}
   for index, token in ipairs(tokens) do
      for _, comment in ipairs(token.comments or {}) do
         local first = offsets[comment.y] + comment.x - 1
         table.insert(segments, {
            first = first,
            last = first + #comment.text - 1,
            style = "comment",
         })
      end

      if token.kind ~= "$EOF$" and token.kind ~= "$ERR$" then
         local style = token_style(tokens, index)
         if style then
            local first = offsets[token.y] + token.x - 1
            local url
            if style == "type" and
               not is_declaration_name(tokens, index) and
               links then

               url = links[token.tk]
            end
            table.insert(segments, {
               first = first,
               last = first + #token.tk - 1,
               style = style,
               url = url,
            })
         end
      end
   end
   table.sort(segments, function(a, b)
      if a.first == b.first then
         return a.last > b.last
      end
      return a.first < b.first
   end)

   local output = {}
   local cursor = 1
   for _, segment in ipairs(segments) do
      if segment.first >= cursor and segment.first <= #code then
         table.insert(output, escape_html(code:sub(cursor, segment.first - 1)))
         local text = code:sub(segment.first, segment.last)
         local token = '<span class="' ..
         token_classes(segment.style, text) ..
         '">' ..
         escape_html(text) ..
         "</span>"
         if segment.url then
            token = '<a class="tealdoc-code-link" href="' ..
            escape_html(segment.url) ..
            '">' ..
            token ..
            "</a>"
         end
         table.insert(output, token)
         cursor = segment.last + 1
      end
   end
   table.insert(output, escape_html(code:sub(cursor)))
   return table.concat(output)
end

return Highlighter
