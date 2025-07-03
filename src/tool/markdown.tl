local tealdoc = require("tealdoc")
local Generator = require("tool.generator")

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

MarkdownBuilder.h1 = function(self, text: string): MarkdownBuilder
    self:line("# ", text)
    return self
end
MarkdownBuilder.h2 = function(self, text: string): MarkdownBuilder
    self:line("## ", text)
    return self
end
MarkdownBuilder.h3 = function(self, text: string): MarkdownBuilder
    self:line("### ", text)
    return self
end 
MarkdownBuilder.h4 = function(self, text: string): MarkdownBuilder
    self:line("#### ", text)
    return self
end
MarkdownBuilder.h5 = function(self, text: string): MarkdownBuilder
    self:line("##### ", text)
    return self
end
MarkdownBuilder.h6 = function(self, text: string): MarkdownBuilder
    self:line("###### ", text)
    return self
end
MarkdownBuilder.line = function(self, ...: string): MarkdownBuilder
    self:text(...)
    self:text("\n")
    return self
end
MarkdownBuilder.text = function(self, ...: string): MarkdownBuilder
    for i = 1, select("#", ...) do
        table.insert(self.output, (select(i, ...)))
    end
    return self
end
MarkdownBuilder.code_block = function(self, content: function): MarkdownBuilder
    self:line("```")
    content()
    self:line("```")
    return self
end
MarkdownBuilder.ordered_list = function(self, content: function(item: function(content: function))): MarkdownBuilder
    local cnt = 1
    local item = function(item_content: function)
        self:text(tostring(cnt), ". ")
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
        self:text("- ")
        item_content()
        self:line()
    end

    self:line() 
    content(item)
    self:line()
    return self
end

MarkdownBuilder.b = function(self, text: string): string
    return "**" .. text .. "**"
end
MarkdownBuilder.i = function(self, text: string): string
    return "*" .. text .. "*"
end
MarkdownBuilder.code = function(self, text: string): string
    return "`" .. text .. "`"
end

MarkdownBuilder.build = function(self): string
    return table.concat(self.output, "")
end

local record MarkdownGenerator is Generator.Base
    
end

MarkdownGenerator.builder = MarkdownBuilder.init()

MarkdownGenerator.run = function(self: MarkdownGenerator, filename: string, env: tealdoc.Env)
    for _, module in ipairs(env.modules) do
        local module_item = env.registry["$"..module] as tealdoc.DirectiveItem
        assert(module_item)
        Generator.generate_for_item(self, module_item, env)
    end

    local file = io.open(filename, "w")
    assert(file)
    file:write(self.builder:build())
    file:close()
end

return MarkdownGenerator