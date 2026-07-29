local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local Text = require("tealdoc.generator.text")
local log = require("tealdoc.log")

local record MarkdownBuilder is Generator.Builder
    output: {string}
    in_code: boolean
end

function MarkdownBuilder.init(): MarkdownBuilder
    local builder: MarkdownBuilder = {
        output = {},
        in_code = false
    }

    local self = setmetatable(builder, {__index = MarkdownBuilder})

    return self
end

local type Content = Generator.Builder.Content

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
    if self.in_code then
        self:text(...)
        return self
    end
    self:rawtext("<a href=\"#", Text.escape_html(to), "\">")
    self:text(...)
    self:rawtext("</a>")
    return self
end

MarkdownBuilder.link_url = function(self, url: string, ...: Content): MarkdownBuilder
    if self.in_code then
        self:text(...)
        return self
    end
    self:rawtext("[")
    self:text(...)
    self:rawtext("](", url:gsub("([%s%)])", "\\%1"), ")")
    return self
end

MarkdownBuilder.text = function(self, ...: Content): MarkdownBuilder
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c is string then
            table.insert(self.output, self.in_code and c or Text.escape_html(c))
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
    self:line()
    return self
end

MarkdownBuilder.code_block = function(self, content: function): MarkdownBuilder
    self:line()
    self:rawline("```teal")
    self.in_code = true
    content()
    self.in_code = false
    self:rawline("```")
    self:line()
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
    local was_in_code = self.in_code
    self.in_code = true
    self:text(...)
    self.in_code = was_in_code
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
    type URLResolver = function(path: string): string

    init: function(output: string, type_url_for_path?: URLResolver): Generator.Base
    resolve_type_url: function(
        env: tealdoc.Env,
        path: string,
        type_url_for_path: URLResolver
    ): string
    item_phases: {string: {Generator.Phase}}
end

MarkdownGenerator.item_phases = {}

function MarkdownGenerator.resolve_type_url(
    env: tealdoc.Env,
    path: string,
    type_url_for_path: MarkdownGenerator.URLResolver
): string
    local seen: {string: boolean} = {}
    while path and not seen[path] do
        seen[path] = true
        local item = env.registry[path]
        if not item then
            return type_url_for_path(path)
        end
        if Generator.filter(item, env) then
            return type_url_for_path(path) or "#" .. path
        end
        if item is tealdoc.TypeItem
            and item.type_kind == "type"
            and item.alias_target
        then
            path = item.alias_target
        else
            return nil
        end
    end
    return nil
end

MarkdownGenerator.init = function(output: string, type_url_for_path?: MarkdownGenerator.URLResolver): Generator.Base
    local builder = MarkdownBuilder.init()
    local base = Generator.Base.init()
    base.item_phases = MarkdownGenerator.item_phases
    base.on_item_start = function(_, item: tealdoc.Item, _: string, _: tealdoc.Env)
        builder:rawline("<a id=\"", Text.escape_html(item.path), "\"></a>")
    end
    base.on_context_for_item = function(_, ctx: Generator.Phase.Context, _: tealdoc.Item, _: string, env: tealdoc.Env)
        ctx.builder = builder
        ctx.path_mode = "full"
        ctx.url_for_path = function(path: string): string
            return env.registry[path] and "#" .. path or nil
        end
        if type_url_for_path then
            ctx.url_for_type = function(path: string): string
                return MarkdownGenerator.resolve_type_url(
                    env,
                    path,
                    type_url_for_path
                )
            end
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
