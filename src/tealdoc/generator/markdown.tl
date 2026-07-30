local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local Text = require("tealdoc.generator.text")
local log = require("tealdoc.log")

local record MarkdownBuilder is Generator.Builder
    output: {string}
    in_code: boolean
    format_code: function(string): string
end

function MarkdownBuilder.init(
    format_code?: function(string): string
): MarkdownBuilder
    local builder: MarkdownBuilder = {
        output = {},
        in_code = false,
        format_code = format_code,
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
    local outer = self.output
    self.output = {}
    content()
    local code = table.concat(self.output, "")
    self.output = outer
    self.in_code = false
    if self.format_code then
        code = self.format_code(code):gsub("\n*$", "") .. "\n"
    end
    self:rawtext(code)
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

-- A pipe table rather than a raw `<table>` element, because Markdown renders
-- the contents of a cell and passes the contents of a raw HTML block through
-- untouched, and a description is Markdown.
MarkdownBuilder.table = function(self, headers: {string}, content: function(row: function(...: function))): MarkdownBuilder
    -- Each cell is written into a buffer of its own so the row separator can be
    -- taken out of it. A union type is spelled with `|`, and a literal one
    -- would end the cell in the middle of the type. The entity is what survives
    -- the readers that consume this, which take a backslash before a pipe as an
    -- ordinary backslash and end the cell anyway. A code span carrying one has
    -- to become a `code` element for the same reason: a span renders what is
    -- inside it literally, entity and all.
    local function cell(write: function): string
        local outer = self.output
        self.output = {}
        write()
        local written = table.concat(self.output, "")
        self.output = outer

        written = written:gsub("`([^`]*)`", function(inner: string): string
            if not inner:find("|", 1, true) then
                return "`" .. inner .. "`"
            end
            return "<code>" ..
                (Text.escape_html(inner):gsub("|", "&#124;")) ..
                "</code>"
        end)

        -- A row is one line, so a description written over several is folded
        -- onto one here.
        return (written:gsub("|", "&#124;"):gsub("%s*\n%s*", " "))
    end

    local row = function(...: function)
        local cells: {string} = {}
        for i = 1, select("#", ...) do
            table.insert(cells, cell((select(i, ...)) as function))
        end
        self:rawline("| ", table.concat(cells, " | "), " |")
    end

    local rule: {string} = {}
    for _ = 1, #headers do
        table.insert(rule, "---")
    end

    self:line()
    self:rawline("| ", table.concat(headers, " | "), " |")
    self:rawline("| ", table.concat(rule, " | "), " |")
    content(row)
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

    init: function(
        output: string,
        type_url_for_path?: URLResolver,
        allow_local_type_links?: boolean
    ): Generator.Base
    --- Renders documentation and answers with it rather than writing a file.
    render: function(
        env: tealdoc.Env,
        type_url_for_path?: URLResolver,
        allow_local_type_links?: boolean,
        format_code?: function(string): string
    ): string
    resolve_type_url: function(
        env: tealdoc.Env,
        path: string,
        type_url_for_path: URLResolver,
        allow_local_type_links?: boolean
    ): string
    resolve_markdown_type_links: function(
        env: tealdoc.Env,
        text: string,
        url_for_type?: URLResolver,
        url_for_path?: URLResolver
    ): string
    private_alias_target: function(
        env: tealdoc.Env,
        item: tealdoc.TypeItem,
        type_url_for_path: URLResolver,
        allow_local_type_links?: boolean
    ): tealdoc.TypeItem
    item_phases: {string: {Generator.Phase}}
end

MarkdownGenerator.item_phases = {}

function MarkdownGenerator.resolve_type_url(
    env: tealdoc.Env,
    path: string,
    type_url_for_path: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean
): string
    local seen: {string: boolean} = {}
    while path and not seen[path] do
        seen[path] = true
        local item = env.registry[path]
        if not item then
            return type_url_for_path(path)
        end
        if Generator.filter(item, env) then
            local url = type_url_for_path(path)
            if url then
                return url
            end
            if allow_local_type_links ~= false then
                return "#" .. path
            end
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

local function markdown_type_path(
    env: tealdoc.Env,
    target: string
): string
    local direct = env.registry[target]
    if direct and direct is tealdoc.TypeItem then
        return target
    end

    local found: string
    for path, item in pairs(env.registry) do
        if item is tealdoc.TypeItem
            and item.name == target
            and Generator.filter(item, env)
        then
            if found and found ~= path then
                return nil
            end
            found = path
        end
    end
    return found
end

--- Resolves explicit `tealdoc:` destinations in authored Markdown.
---
--- Module introductions do not pass through the ordinary item text phase, so
--- site generation calls this directly for them. Keeping the resolver here
--- gives introductions and item comments identical lookup and warning rules.
function MarkdownGenerator.resolve_markdown_type_links(
    env: tealdoc.Env,
    text: string,
    url_for_type?: MarkdownGenerator.URLResolver,
    url_for_path?: MarkdownGenerator.URLResolver
): string
    return (text:gsub(
        "%]%(%s*tealdoc:([^%)%s]+)%s*%)",
        function(target: string): string
            local path = markdown_type_path(env, target)
            if not path then
                local routed = url_for_type
                    and url_for_type(target)
                    or nil
                if routed then
                    return "](" .. routed .. ")"
                end
                log:warning(
                    "Could not resolve Tealdoc Markdown type link: " ..
                        target
                )
                return "](tealdoc:" .. target .. ")"
            end

            local url = url_for_type and url_for_type(path) or nil
            if not url then
                local item = env.registry[path]
                if item and Generator.filter(item, env) and url_for_path then
                    url = url_for_path(path)
                end
            end
            if not url then
                log:warning(
                    "Type is not public in Tealdoc Markdown link: " ..
                        target
                )
                return "](tealdoc:" .. target .. ")"
            end
            return "](" .. url .. ")"
        end
    ))
end

--- Finds the concrete private alias whose type expression should replace a
--- public alias's nominal right-hand side.
---
--- A target with a URL remains a nominal expression for the highlighter to
--- link. Without one, following private aliases until the first structural
--- expression lets a declaration say what the public name actually means.
--- Records, interfaces and enums keep their nominal spelling: expanding one
--- requires projecting its children, not replacing one expression.
function MarkdownGenerator.private_alias_target(
    env: tealdoc.Env,
    item: tealdoc.TypeItem,
    type_url_for_path: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean
): tealdoc.TypeItem
    if not item.alias_target
        or MarkdownGenerator.resolve_type_url(
            env,
            item.alias_target,
            type_url_for_path,
            allow_local_type_links
        )
    then
        return nil
    end

    local seen: {string: boolean} = {}
    local path = item.alias_target
    while path and not seen[path] do
        seen[path] = true
        local target = env.registry[path]
        if not target
            or not target is tealdoc.TypeItem
            or target.type_kind ~= "type"
        then
            return nil
        end
        if not target.alias_target then
            return target
        end
        path = target.alias_target
    end
    return nil
end

local function copy_item(item: tealdoc.Item): tealdoc.Item
    local values: {string: any} = {}
    for key, value in pairs(item as {string: any}) do
        values[key] = value
    end
    return values as tealdoc.Item
end

--- Finds the record, interface or enum at the end of an exact private alias
--- chain. Unlike a type-expression alias, one of these has children that must
--- be projected under the public name to inline its definition.
local function private_alias_structure_target(
    env: tealdoc.Env,
    item: tealdoc.TypeItem,
    type_url_for_path: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean
): tealdoc.TypeItem
    if not item.alias_target
        or MarkdownGenerator.resolve_type_url(
            env,
            item.alias_target,
            type_url_for_path,
            allow_local_type_links
        )
    then
        return nil
    end

    local seen: {string: boolean} = {}
    local path = item.alias_target
    while path and not seen[path] do
        seen[path] = true
        local target = env.registry[path]
        if not target or not target is tealdoc.TypeItem then
            return nil
        end
        if target.type_kind ~= "type" then
            return target
        end
        if not target.alias_target then
            return nil
        end
        path = target.alias_target
    end
    return nil
end

--- Rehomes an exact private structural target beneath each public alias that
--- reaches it. The parser has already resolved `alias_target`, so no name
--- lookup or suffix matching is involved. Rehoming the children makes an
--- interface or record genuinely inline: its fields and methods are rendered
--- under the public alias rather than leaving a private nominal spelling.
local function inline_private_structural_aliases(
    env: tealdoc.Env,
    type_url_for_path: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean
)
    local aliases: {tealdoc.TypeItem} = {}
    local visited: {string: boolean} = {}
    local visit: function(tealdoc.Item)
    visit = function(item: tealdoc.Item)
        if not item or visited[item.path] then
            return
        end
        visited[item.path] = true
        if item is tealdoc.TypeItem
            and item.type_kind == "type"
            and item.alias_target
            and Generator.filter(item, env)
        then
            table.insert(aliases, item)
        end
        for _, child_path in ipairs(item.children or {}) do
            visit(env.registry[child_path])
        end
    end
    for _, module_name in ipairs(env.modules) do
        visit(env.registry["$" .. module_name])
    end

    local clone_subtree: function(
        string,
        string,
        string,
        string
    ): tealdoc.Item
    clone_subtree = function(
        source_path: string,
        source_prefix: string,
        public_prefix: string,
        parent: string
    ): tealdoc.Item
        local source = assert(env.registry[source_path])
        local clone = copy_item(source)
        clone.path = public_prefix .. source_path:sub(#source_prefix + 1)
        clone.parent = parent
        clone.children = {}
        env.registry[clone.path] = clone
        for _, child_path in ipairs(source.children or {}) do
            local child = clone_subtree(
                child_path,
                source_prefix,
                public_prefix,
                clone.path
            )
            table.insert(clone.children, child.path)
        end
        return clone
    end

    for _, alias in ipairs(aliases) do
        local target = private_alias_structure_target(
            env,
            alias,
            type_url_for_path,
            allow_local_type_links
        )
        if target then
            local projected = clone_subtree(
                target.path,
                target.path,
                alias.path,
                alias.parent
            ) as tealdoc.TypeItem
            projected.name = alias.name
            projected.text = alias.text or target.text
            projected.attributes = alias.attributes
            projected.location = alias.location
            projected.visibility = alias.visibility
            projected.typeargs = alias.typeargs or target.typeargs
            env.registry[alias.path] = projected
        end
    end
end

--- Builds a generator and hands back the builder it writes into.
---
--- Shared by `init`, which writes the result to a file, and `render`, which
--- answers with it. The two differ only in what happens once the walk is done.
--- @param type_url_for_path Resolves a type's path to a URL, or nil to leave
---     types unlinked.
--- @param allow_local_type_links Whether a type may link to an anchor on the
---     page being rendered.
--- @return The generator, and the builder holding what it wrote.
local function generator_for(
    type_url_for_path?: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean,
    format_code?: function(string): string
): Generator.Base, MarkdownBuilder
    local builder = MarkdownBuilder.init(format_code)
    local base = Generator.Base.init()
    base.item_phases = MarkdownGenerator.item_phases
    if type_url_for_path then
        base.on_start = function(_, env: tealdoc.Env)
            inline_private_structural_aliases(
                env,
                type_url_for_path,
                allow_local_type_links
            )
        end
    end
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
                    type_url_for_path,
                    allow_local_type_links
                )
            end
            ctx.private_alias_target = function(
                item: tealdoc.TypeItem
            ): tealdoc.TypeItem
                return MarkdownGenerator.private_alias_target(
                    env,
                    item,
                    type_url_for_path,
                    allow_local_type_links
                )
            end
        end
    end
    return base, builder
end

--- Renders documentation to a file.
--- @param output The path written when the walk ends.
--- @param type_url_for_path Resolves a type's path to a URL, or nil to leave
---     types unlinked.
--- @param allow_local_type_links Whether a type may link to an anchor on the
---     page being rendered.
--- @return A generator that writes `output` when it finishes.
MarkdownGenerator.init = function(
    output: string,
    type_url_for_path?: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean
): Generator.Base
    local base, builder = generator_for(type_url_for_path, allow_local_type_links)
    base.on_end = function(_, _: tealdoc.Env)
        local file = io.open(output, "w")
        assert(file, "Could not open file for writing: " .. output)
        file:write(builder:build())
        file:close()
        log:info("Markdown documentation generated to " .. output)
    end
    return base
end

--- Renders documentation and answers with it.
---
--- The site generator composes a page from Markdown it renders here, so it
--- wants the text rather than a file. Writing one to read it back costs a
--- temporary file per API page, and the caller then has to remove it, which a
--- raised error skips.
--- @param env The environment to walk.
--- @param type_url_for_path Resolves a type's path to a URL, or nil to leave
---     types unlinked.
--- @param allow_local_type_links Whether a type may link to an anchor on the
---     page being rendered.
--- @return The rendered Markdown.
MarkdownGenerator.render = function(
    env: tealdoc.Env,
    type_url_for_path?: MarkdownGenerator.URLResolver,
    allow_local_type_links?: boolean,
    format_code?: function(string): string
): string
    local base, builder = generator_for(
        type_url_for_path,
        allow_local_type_links,
        format_code
    )
    base:run(env)
    return builder:build()
end

return MarkdownGenerator
