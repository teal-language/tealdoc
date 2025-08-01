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

MarkdownBuilder.h1 = function(self, content: Content): MarkdownBuilder
    self:rawtext("# ")
    self:line(content)
    return self
end
MarkdownBuilder.h2 = function(self, content: Content): MarkdownBuilder
    self:rawtext("## ")
    self:line(content)
    return self
end
MarkdownBuilder.h3 = function(self, content: Content): MarkdownBuilder
    self:rawtext("### ")
    self:line(content)
    return self
end 
MarkdownBuilder.h4 = function(self, content: Content): MarkdownBuilder
    self:rawtext("#### ")
    self:line(content)
    return self
end
MarkdownBuilder.h5 = function(self, content: Content): MarkdownBuilder
    self:rawtext("##### ")
    self:line(content)
    return self
end
MarkdownBuilder.h6 = function(self, content: Content): MarkdownBuilder
    self:rawtext("###### ")
    self:line(content)
    return self
end
MarkdownBuilder.line = function(self, ...: Content): MarkdownBuilder
    self:text(...)
    self:rawtext("\n")
    return self
end

MarkdownBuilder.link = function(self, to: string, ...: Content): MarkdownBuilder
    -- TODO TODO TODO!!!!
    self:text(...)
    return self
end

-- TODO: this isn't so trivial, as markdown automatically escapes some characters in codeblocks and it gets messy
local function escape_markdown(text: string): string 
    return text
end

MarkdownBuilder.text = function(self, ...: Content): MarkdownBuilder
    for i = 1, select("#", ...) do
        local c = select(i, ...)
        if c is string then
            table.insert(self.output, escape_markdown(c))
        else 
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
        else
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
    self:rawline("```")
    content()
    self:rawline("```")
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

MarkdownBuilder.b = function(self, text: Content): MarkdownBuilder
    self:rawtext("**")
    self:text(text)
    self:rawtext("**")
    return self
end
MarkdownBuilder.i = function(self, text: Content): MarkdownBuilder
    self:rawtext("*")
    self:text(text)
    self:rawtext("*")
    return self
end
MarkdownBuilder.code = function(self, text: Content): MarkdownBuilder
    self:rawtext("`")
    self:text(text)
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

local record MarkdownGenerator is Generator.Base
    item_phases: {string: {Generator.Phase}}
    generate_for_item: function(self, item: tealdoc.Item, env: tealdoc.Env)
end

MarkdownGenerator.builder = MarkdownBuilder.init()


MarkdownGenerator.item_phases = {}

MarkdownGenerator.generate_for_item = function(self: MarkdownGenerator, item: tealdoc.Item, env: tealdoc.Env)
    local is_module = env.registry["$"..(item.path)] -- TODO: is this a good way to check if an item is a module?

    if not env.include_all then
        local has_local_tag = item.attributes and item.attributes["local"]
        local is_declared_as_local = item is tealdoc.DeclarationItem and item.visibility == "local"
        if has_local_tag or (is_declared_as_local and not is_module) then
            return
        end
    end
    local phases = self.item_phases[item.kind]
     -- hack for not for not including autogenerated __is metamethod from where clause
    if item is tealdoc.FunctionItem and item.function_kind == "metamethod" and item.name == "__is" then
        return 
    end
    if not item.text and not is_module and (item.kind == "function" or item.kind == "type" or item.kind == "variable" or item.kind == "enumvalue") and not env.no_warnings_on_missing then
        log:warning("Documentation missing for item: " .. item.path)
    end

    local penv: Generator.Phase.Context = {
        builder = self.builder,
        path_mode = "full",
        env = env,
    } 

    if phases and not is_module then
        for _, phase in ipairs(phases) do
            phase.run(penv, item)
        end
    end

    if item.children and not (item.kind == "function") then -- we skip inner declarations currently
        for _, child_name in ipairs(item.children) do
            local child_item = env.registry[child_name]
            assert(child_item)
            self:generate_for_item(child_item, env)
        end
    end
end

MarkdownGenerator.run = function(self: MarkdownGenerator, filename: string, env: tealdoc.Env)
    for _, module in ipairs(env.modules) do
        local module_item = env.registry["$"..module]
        assert(module_item)
        self:generate_for_item(module_item, env)
    end

    local file = io.open(filename, "w")
    assert(file)
    file:write(self.builder:build())
    file:close()
end

return MarkdownGenerator