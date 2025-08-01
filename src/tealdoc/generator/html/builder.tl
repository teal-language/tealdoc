local Generator = require("tealdoc.generator")

local lunamark = require("lunamark")

local record HTMLBuilder is Generator.Builder
    output: {string}

    parse_md: function(text: string): string
end

function HTMLBuilder.init(): HTMLBuilder
    local writer = lunamark.writer.html.new()
    local parse = lunamark.reader.markdown.new(writer, {
        fenced_code_blocks = true
    })

    local builder: HTMLBuilder = {
        output = {},
        parse_md = parse
    }

    local self = setmetatable(builder, {__index = HTMLBuilder})

    return self
end

local type Content = Generator.Builder.Content

function HTMLBuilder:tag(tag: string, content: Content): HTMLBuilder
    self:rawtext("<", tag, ">")
    self:text(content)
    self:rawline("</", tag, ">")
    return self
end

HTMLBuilder.h1 = function(self, content: Content): HTMLBuilder
    self:rawtext("<h1>")
    self:text(content)
    self:rawline("</h1>")
    return self
end
HTMLBuilder.h2 = function(self, content: Content): HTMLBuilder
    self:rawtext("<h2>")
    self:text(content)
    self:rawline("</h2>")
    return self
end
HTMLBuilder.h3 = function(self, content: Content): HTMLBuilder
    self:rawtext("<h3>")
    self:text(content)
    self:rawline("</h3>")
    return self
end
HTMLBuilder.h4 = function(self, content: Content): HTMLBuilder
    self:rawtext("<h4>")
    self:text(content)
    self:rawline("</h4>")
    return self
end
HTMLBuilder.h5 = function(self, content: Content): HTMLBuilder
    self:rawtext("<h5>")
    self:text(content)
    self:rawline("</h5>")
    return self
end
HTMLBuilder.h6 = function(self, content: Content): HTMLBuilder
    self:rawtext("<h6>")
    self:text(content)
    self:rawline("</h6>")
    return self
end
HTMLBuilder.line = function(self, ...: Content): HTMLBuilder
    self:text(...)
    self:rawtext("\n")
    return self
end


HTMLBuilder.link = function(self, to: string, ...: Content): HTMLBuilder
    self:rawtext("<a href=\"#", to, "\">")
    self:text(...)
    self:rawtext("</a>")
    return self
end

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

HTMLBuilder.text = function(self, ...: Content): HTMLBuilder
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c is string then
            table.insert(self.output, escape_html(c))
        else
            c(self)
        end
    end
    return self
end

HTMLBuilder.rawline = function(self, ...: Content): HTMLBuilder
    self:rawtext(...)
    self:rawtext("\n")
    return self
end

HTMLBuilder.rawtext = function(self, ...: Content): HTMLBuilder
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c is string then
            table.insert(self.output, c)
        else
            c(self)
        end
    end
    return self
end

HTMLBuilder.paragraph = function(self, ...: Content): HTMLBuilder
    self:rawline("<p>")
    self:text(...)
    self:rawline("</p>")
    return self
end

HTMLBuilder.code_block = function(self, content: Content): HTMLBuilder
    self:rawtext("<pre><code class=\"code-block\">")
    self:text(content)
    self:rawline("</code></pre>")
    return self
end
HTMLBuilder.ordered_list = function(self, content: function(item: function(content: function))): HTMLBuilder
    local item = function(item_content: function)
        self:rawtext("<li>")
        item_content()
        self:rawline("</li>")
    end

    self:rawline("<ol>")
    content(item)
    self:rawline("</ol>")
    return self
end
HTMLBuilder.unordered_list = function(self, content: function(item: function(content: function))): HTMLBuilder
    local item = function(item_content: function)
        self:rawtext("<li>")
        item_content()
        self:rawline("</li>")
    end

    self:rawline("<ul>")
    content(item)
    self:rawline("</ul>")
    return self
end

HTMLBuilder.b = function(self, text: Content): HTMLBuilder
    self:rawtext("<b>")
    self:text(text)
    self:rawtext("</b>")
    return self
end
HTMLBuilder.i = function(self, text: Content): HTMLBuilder
    self:rawtext("<i>")
    self:text(text)
    self:rawtext("</i>")
    return self
end
HTMLBuilder.code = function(self, text: Content): HTMLBuilder
    self:rawtext("<code>")
    self:text(text)
    self:rawtext("</code>")
    return self
end
HTMLBuilder.md = function(self, text: string): HTMLBuilder
    local parsed = self.parse_md(text)
    self:rawtext(parsed)
    return self
end

HTMLBuilder.build = function(self): string
    return table.concat(self.output, "")
end

return HTMLBuilder