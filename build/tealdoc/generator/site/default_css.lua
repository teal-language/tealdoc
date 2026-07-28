local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local tokens = require("tealdoc.generator.site.css.tokens")
local base = require("tealdoc.generator.site.css.base")
local navigation = require("tealdoc.generator.site.css.navigation")
local content = require("tealdoc.generator.site.css.content")
local components = require("tealdoc.generator.site.css.components")
local home = require("tealdoc.generator.site.css.home")
local search_footer = require("tealdoc.generator.site.css.search_footer")
local responsive = require("tealdoc.generator.site.css.responsive")

return table.concat({
   tokens,
   base,
   navigation,
   content,
   components,
   home,
   search_footer,
   responsive,
})
