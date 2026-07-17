local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local log = require("tealdoc.log")

local record MarkdownBuilder is Generator.Builder
    output: {string}
end

function MarkdownBuilder.init(): MarkdownBuilder
    local builder: MarkdownBuilder = {
        output = {}
    }

    local self = setmetatable(builder, {__index = MarkdownBuilder})

    return self
end

local type Content = Generator.Builder.Content

local function escape_html(text: string): string
    local output = text:gsub("([&<>'\"])", {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ["'"] = "&#39;",
        ['"'] = "&quot;"
    })
    return output
end

MarkdownBuilder.h1 = function(self, ...: Content): MarkdownBuilder
    self:rawtext("# ")
    self:line(...)
    return self
end
MarkdownBuilder.h2 = function(self, ...: Content): MarkdownBuilder
    self:rawtext("## ")
    self:line(...)
    return self
end
MarkdownBuilder.h3 = function(self, ...: Content): MarkdownBuilder
    self:rawtext("### ")
    self:line(...)
    return self
end
MarkdownBuilder.h4 = function(self, ...: Content): MarkdownBuilder
    self:rawtext("#### ")
    self:line(...)
    return self
end
MarkdownBuilder.h5 = function(self, ...: Content): MarkdownBuilder
    self:rawtext("##### ")
    self:line(...)
    return self
end
MarkdownBuilder.h6 = function(self, ...: Content): MarkdownBuilder
    self:rawtext("###### ")
    self:line(...)
    return self
end
MarkdownBuilder.line = function(self, ...: Content): MarkdownBuilder
    self:text(...)
    self:rawtext("\n")
    return self
end

MarkdownBuilder.link = function(self, to: string, ...: Content): MarkdownBuilder
    self:rawtext("<a href=\"#", escape_html(to), "\">")
    self:text(...)
    self:rawtext("</a>")
    return self
end

MarkdownBuilder.link_url = function(self, url: string, ...: Content): MarkdownBuilder
    self:rawtext("<a href=\"", escape_html(url), "\">")
    self:text(...)
    self:rawtext("</a>")
    return self
end

MarkdownBuilder.text = function(self, ...: Content): MarkdownBuilder
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c is string then
            table.insert(self.output, escape_html(c))
        elseif c is function then
            c(self)
        end
    end
    return self
end

MarkdownBuilder.rawline = function(self, ...: Content): MarkdownBuilder
    self:rawtext(...)
    self:rawtext("\n")
    return self
end

MarkdownBuilder.rawtext = function(self, ...: Content): MarkdownBuilder
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c is string then
            table.insert(self.output, c)
        elseif c is function then
            c(self)
        end
    end
    return self
end


MarkdownBuilder.paragraph = function(self, ...: Content): MarkdownBuilder
    self:line()
    self:text(...)
    self:line()
    return self
end

MarkdownBuilder.code_block = function(self, content: function): MarkdownBuilder
    self:rawtext("<pre><code>")
    content()
    self:rawline("</code></pre>")
    return self
end
MarkdownBuilder.ordered_list = function(self, content: function(item: function(content: function))): MarkdownBuilder
    local cnt = 1
    local item = function(item_content: function)
        self:rawtext(tostring(cnt), ". ")
        cnt = cnt + 1
        item_content()
        self:line()
    end

    self:line()
    content(item)
    self:line()
    return self
end
MarkdownBuilder.unordered_list = function(self, content: function(item: function(content: function))): MarkdownBuilder
    local item = function(item_content: function)
        self:rawtext("- ")
        item_content()
        self:line()
    end

    self:line()
    content(item)
    self:line()
    return self
end

MarkdownBuilder.b = function(self, ...: Content): MarkdownBuilder
    self:rawtext("**")
    self:text(...)
    self:rawtext("**")
    return self
end
MarkdownBuilder.i = function(self, ...: Content): MarkdownBuilder
    self:rawtext("*")
    self:text(...)
    self:rawtext("*")
    return self
end
MarkdownBuilder.code = function(self, ...: Content): MarkdownBuilder
    self:rawtext("`")
    self:text(...)
    self:rawtext("`")
    return self
end
MarkdownBuilder.md = function(self, text: string): MarkdownBuilder
    self:rawtext(text)
    return self
end
MarkdownBuilder.build = function(self): string
    return table.concat(self.output, "")
end

local record MarkdownGenerator 
    init: function(output: string): Generator.Base
    item_phases: {string: {Generator.Phase}}
end

MarkdownGenerator.item_phases = {}

MarkdownGenerator.init = function(output: string): Generator.Base
    local builder = MarkdownBuilder.init()
    local base = Generator.Base.init()
    base.item_phases = MarkdownGenerator.item_phases
    base.on_item_start = function(_, item: tealdoc.Item, _: string, _: tealdoc.Env)
        builder:rawline("<a id=\"", escape_html(item.path), "\"></a>")
    end
    base.on_context_for_item = function(_, ctx: Generator.Phase.Context, _: tealdoc.Item, _: string, env: tealdoc.Env)
        ctx.builder = builder
        ctx.path_mode = "full"
        ctx.url_for_path = function(path: string): string
            return env.registry[path] and "#" .. path or nil
        end
    end
    base.on_end = function(_, _: tealdoc.Env)
        local file = io.open(output, "w")
        assert(file, "Could not open file for writing: " .. output)
        file:write(builder:build())
        file:close()
        log:info("Markdown documentation generated to " .. output)
    end
    return base
end

return MarkdownGenerator
