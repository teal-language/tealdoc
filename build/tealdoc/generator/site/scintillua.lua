local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local loadfile = _tl_compat and _tl_compat.loadfile or loadfile; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table






















local Highlighter = require("tealdoc.generator.site.highlighter")

local Scintillua = {}














local LEXERS = {
   bash = true,
   json = true,
   xml = true,
}








local STYLES = {
   keyword = "keyword",
   comment = "comment",
   string = "string",
   number = "number",
   operator = "operator",
   identifier = "variable",
   ["function"] = "function",
   type = "type",
   class = "type",
   constant = "boolean",
   variable = "variable",
   preprocessor = "meta",
   annotation = "meta",
   label = "meta",
   embedded = "meta",
   regex = "string",

   tag = "keyword",
   attribute = "property",
   entity = "boolean",
   property = "property",
}





local directory = nil













local library_module = nil
local loaded = {}
local searched = false

function Scintillua.configure(lexers)
   if lexers == directory then
      return
   end
   directory = lexers
   library_module = nil
   loaded = {}
   searched = false
end

local function library()
   if searched then
      return library_module
   end
   searched = true
   if not directory then
      return nil
   end
   local chunk = loadfile(directory .. "/lexer.lua")
   if not chunk then
      return nil
   end
   local ok, module = pcall(chunk)
   if not ok or not module then
      return nil
   end
   library_module = module


   library_module.property = setmetatable(
   { ["scintillua.lexers"] = directory },
   { __index = function() return "" end })

   return library_module
end

function Scintillua.supports(language)
   return LEXERS[language] == true
end

function Scintillua.segments(
   language,
   code)

   if not LEXERS[language] then
      return nil
   end
   local module = library()
   if not module then
      return nil
   end
   local lexer = loaded[language]
   if not lexer then
      local ok, result = pcall(module.load, language)
      if not ok or not result then
         return nil
      end
      lexer = result
      loaded[language] = lexer
   end
   local ok, tags = pcall(lexer.lex, lexer, code)
   if not ok or not tags then
      return nil
   end





   local list = tags
   local segments = {}
   local cursor = 1
   for index = 1, #list - 1, 2 do
      local tag = list[index]
      local stop = list[index + 1]
      local first, last = cursor, stop - 1
      cursor = stop
      local style = STYLES[(tag:match("^[^.]+") or tag)]
      if style and last >= first then
         table.insert(segments, {
            first = first,
            last = last,
            style = style,
         })
      end
   end
   return segments
end

return Scintillua
