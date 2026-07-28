local tokens = require("tealdoc.generator.site.css.tokens")
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
