local log = require("tealdoc.log")
local tealdoc = require("tealdoc")
local TealParser = require("tealdoc.parser.teal")
local MarkdownInput = require("tealdoc.parser.markdown")


local Generator = require("tealdoc.generator")
local signatures = require("tealdoc.generator.signatures")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local HTMLGenerator = require("tealdoc.generator.html.generator")
local detailed_signature_phase = require("tealdoc.generator.html.detailed_signature_phase")

local record DefaultEnv
end

local attr = Generator.attr

function DefaultEnv.init(): tealdoc.Env
    local env = tealdoc.Env.init()

    env:add_parser(TealParser.init())
    env:add_parser(MarkdownInput)

    -- TODO: better place for this
    -- TODO: should we check if all params and typeargs are documented?

    local param_tag_handler: tealdoc.Tag = {
        name = "param",
        has_param = true,
        has_description = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem then
                log:error(
                    "@param tag can only exist in function comments (%s:%s:%s)",
                    item.location.filename,
                    item.location.y,
                    item.location
                )
                return
            end

            local param: tealdoc.FunctionItem.Param
            if item.params then
                -- Named tags may omit implicit parameters such as a method's
                -- receiver, so prefer an exact name match.
                for _, p in ipairs(item.params) do
                    if p.name == ctx.param and p.description == nil then
                        param = p
                        break
                    end
                end

                -- Function type declarations may not provide parameter names.
                -- Fall back to their declaration order in that case, and only
                -- over the parameters that still need a name.
                if not param then
                    for _, p in ipairs(item.params) do
                        if p.name == nil and p.description == nil then
                            param = p
                            break
                        end
                    end
                end

                -- Every parameter is named, so the tag names one of them
                -- wrongly. Take the next undocumented parameter to report it
                -- against, which keeps the mismatch warning below.
                if not param then
                    for _, p in ipairs(item.params) do
                        if p.description == nil then
                            param = p
                            break
                        end
                    end
                end
            end
            if not param then
                log:warning(
                    "Found more @param tags than declared parameters in function '%s' (%s:%s:%s)",
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
            end

            if param.name and param.name ~= ctx.param then
                log:warning(
                    "Parameter name mismatch: expected '%s', got '%s' in function '%s' (%s:%s:%s)",
                    param.name,
                    ctx.param,
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
            end
            param.name = ctx.param
            param.description = ctx.description
        end
    }

    local typearg_tag_handler: tealdoc.Tag = {
        name = "typearg",
        has_param = true,
        has_description = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem and not item is tealdoc.TypeItem then
                log:error(
                    "@typearg tag can only exist in function or type comments (%s:%s:%s)",
                    item.location.filename,
                    item.location.y,
                    item.location
                )
                return
            end

            -- A tag says which parameter it describes, so it is bound by
            -- that name. Binding by position instead meant the tags had to
            -- be written in declaration order, and a pair written the other
            -- way round was noticed and then thrown away rather than put
            -- where it belonged.
            local typearg: tealdoc.Typearg
            if item.typeargs then
                for _, candidate in ipairs(item.typeargs) do
                    if candidate.name == ctx.param then
                        typearg = candidate
                        break
                    end
                end
                if not typearg then
                    -- A parameter the compiler reported without a name can
                    -- still be described; the first undescribed one is it.
                    for _, candidate in ipairs(item.typeargs) do
                        if not candidate.name and candidate.description == nil then
                            typearg = candidate
                            break
                        end
                    end
                end
            end
            if not typearg then
                log:warning(
                    "No type argument named '%s' is declared by '%s' (%s:%s:%s)",
                    ctx.param,
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
            end
            if typearg.description ~= nil then
                log:warning(
                    "Type argument '%s' of '%s' is described twice (%s:%s:%s)",
                    ctx.param,
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
            end
            typearg.name = ctx.param
            typearg.description = ctx.description
        end
    }

    local return_tag_handler: tealdoc.Tag = {
        name = "return",
        has_description = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem then
                log:error("return tag can only exist in function comments")
                return
            end

            local matched = false
            if item.returns then
                for _, ret in ipairs(item.returns) do
                    if not ret.description then
                        ret.description = ctx.description
                        matched = true
                        break
                    end
                end
            end
            if not matched then
                log:error(
                "Found more @return tags than declared return values in function '%s'. Each @return tag should correspond to a return value in the function signature.",
                item.name
                )
            end
        end
    }

    local local_tag_handler: tealdoc.Tag = {
        name = "local",
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item.attributes then
                item.attributes = {}
            end
            item.attributes["local"] = true
        end
    }

    local public_tag_handler: tealdoc.Tag = {
        name = "public",
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item.attributes then
                item.attributes = {}
            end
            item.attributes["public"] = true
        end
    }

    local category_tag_handler: tealdoc.Tag = {
        name = "category",
        has_param = true,
        handle = function(ctx: tealdoc.Tag.Context)
            local item = ctx.item
            if not item.attributes then
                item.attributes = {}
            end
            item.attributes["category"] = ctx.param
        end
    }

    env:add_tag(return_tag_handler)
    env:add_tag(param_tag_handler)
    env:add_tag(typearg_tag_handler)
    env:add_tag(local_tag_handler)
    env:add_tag(public_tag_handler)
    env:add_tag(category_tag_handler)

    -- TODO: better place for this
    local function strip_module_prefix(path: string, module_name: string): string
        if path:sub(1, 1) == "$" then
            path = path:sub(2)
        end
        return path:sub(#module_name + 2) -- +2 for the dot after module name
    end


    local module_header_phase: Generator.Phase = {
        name = "module_header",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item.kind == "module")
            ctx.builder:h1(attr("name"), "Module: " .. item.name)
            ctx.builder:line(attr("text"), item.text or "")
        end
    }

    local header_phase: Generator.Phase = {
        name = "header",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            local path = item.path
            -- should we construct the display path in parser?
            if ctx.path_mode == "full" then
                local display_path = path:gsub("%$[^%.]*%.", "")
                ctx.builder:h2(attr("path"), display_path)
            else
                ctx.builder:h2(attr("path"), strip_module_prefix(item.path, ctx.module_name))
            end
        end
    }

    local function display_path(ctx: Generator.Phase.Context, item: tealdoc.Item): string
        if ctx.path_mode == "full" then
            local path = item.path:gsub("%$[^%.]*%.", "")
            return path
        end
        return strip_module_prefix(item.path, ctx.module_name)
    end

    local function overload_parent(ctx: Generator.Phase.Context, item: tealdoc.Item): tealdoc.Item
        if not item.parent then
            return nil
        end
        local parent = ctx.env.registry[item.parent]
        if parent and (parent.kind == "overload" or parent.kind == "overloaded") then
            return parent
        end
        return nil
    end

    local function markdown_item_level(ctx: Generator.Phase.Context, item: tealdoc.Item): integer
        local level = 2
        local current = item
        while current.parent do
            local parent = ctx.env.registry[current.parent]
            if not parent or parent.kind == "module" or parent.path == ctx.module_name then
                break
            end
            level = math.min(level + 1, 5)
            current = parent
        end
        return level
    end

    local function markdown_heading(
        ctx: Generator.Phase.Context,
        level: integer,
        attribute: Generator.Attribute,
        title: string
    )
        if level == 2 then
            ctx.builder:h2(attribute, title)
        elseif level == 3 then
            ctx.builder:h3(attribute, title)
        elseif level == 4 then
            ctx.builder:h4(attribute, title)
        elseif level == 5 then
            ctx.builder:h5(attribute, title)
        else
            ctx.builder:h6(attribute, title)
        end
    end

    local markdown_header_phase: Generator.Phase = {
        name = "markdown_header",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            local parent = overload_parent(ctx, item)
            if parent then
                if parent.children and parent.children[1] == item.path then
                    markdown_heading(
                        ctx,
                        markdown_item_level(ctx, parent),
                        attr("path"),
                        display_path(ctx, parent)
                    )
                end
                markdown_heading(
                    ctx,
                    markdown_item_level(ctx, item),
                    attr("header"),
                    "Function"
                )
            else
                markdown_heading(
                    ctx,
                    markdown_item_level(ctx, item),
                    attr("path"),
                    display_path(ctx, item)
                )
            end
        end
    }

    local function markdown_section(ctx: Generator.Phase.Context, item: tealdoc.Item, title: string)
        markdown_heading(
            ctx,
            markdown_item_level(ctx, item) + 1,
            attr("header"),
            title
        )
    end

    local function markdown_type(
        ctx: Generator.Phase.Context,
        typename: string,
        references?: {tealdoc.TypeReference}
    )
        if not ctx.url_for_type or not references or #references == 0 then
            ctx.builder:code(typename)
            return
        end

        local urls: {string: string} = {}
        for _, reference in ipairs(references) do
            local url = ctx.url_for_type(reference.path)
            if url then
                urls[reference.name] = url
            end
        end
        if next(urls) == nil then
            ctx.builder:code(typename)
            return
        end

        local position = 1
        local plain: {string} = {}
        local function flush_plain()
            if #plain > 0 then
                ctx.builder:code(table.concat(plain))
                plain = {}
            end
        end
        while position <= #typename do
            local first, last = typename:find("[%a_][%w_%.]*", position)
            if not first then
                table.insert(plain, typename:sub(position))
                break
            end
            if first > position then
                table.insert(plain, typename:sub(position, first - 1))
            end

            local name = typename:sub(first, last)
            local url = urls[name]
            if url then
                flush_plain()
                ctx.builder:link_url(url, function()
                    ctx.builder:code(name)
                end)
            else
                table.insert(plain, name)
            end
            position = last + 1
        end
        flush_plain()
    end

    local function markdown_type_path(
        ctx: Generator.Phase.Context,
        target: string
    ): string
        local direct = ctx.env.registry[target]
        if direct and direct is tealdoc.TypeItem then
            return target
        end

        local found: string
        for path, item in pairs(ctx.env.registry) do
            if item is tealdoc.TypeItem
                and item.name == target
                and Generator.filter(item, ctx.env)
            then
                if found and found ~= path then
                    return nil
                end
                found = path
            end
        end
        return found
    end

    local function markdown_with_type_links(
        ctx: Generator.Phase.Context,
        text: string
    ): string
        return (text:gsub(
            "%]%(%s*tealdoc:([^%)%s]+)%s*%)",
            function(target: string): string
                local path = markdown_type_path(ctx, target)
                if not path then
                    log:warning(
                        "Could not resolve Tealdoc Markdown type link: " ..
                            target
                    )
                    return "](tealdoc:" .. target .. ")"
                end

                local url: string
                if ctx.url_for_type then
                    url = ctx.url_for_type(path)
                end
                if not url then
                    local item = ctx.env.registry[path]
                    if item and Generator.filter(item, ctx.env) then
                        url = ctx.url_for_path(path)
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

    local text_phase: Generator.Phase = {
        name = "text",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            if item.text then
                ctx.builder:paragraph(attr("text"), function()
                    ctx.builder:md(markdown_with_type_links(ctx, item.text))
                end)
            end
        end
    }

    local function_signature_phase: Generator.Phase = {
        name = "function_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)
            ctx.builder:code_block(function()
                signatures.for_function(ctx, item)
                ctx.builder:line()
            end)
        end
    }

    local variable_signature_phase: Generator.Phase = {
        name = "variable_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.VariableItem)

            ctx.builder:code_block(function()
                signatures.for_variable(ctx, item)
                ctx.builder:line()
            end)
        end
    }

    local structure_signature: function(
        Generator.Phase.Context,
        tealdoc.Item,
        string,
        boolean
    ): boolean

    structure_signature = function(
        ctx: Generator.Phase.Context,
        item: tealdoc.Item,
        indent: string,
        record_field: boolean
    ): boolean
        if item is tealdoc.VariableItem then
            ctx.builder:rawtext(indent)
            signatures.for_variable(ctx, item)
            return true
        elseif item is tealdoc.FunctionItem then
            ctx.builder:rawtext(indent)
            signatures.for_function(ctx, item, record_field)
            return true
        elseif item is tealdoc.TypeItem then
            ctx.builder:rawtext(indent)
            signatures.for_type(ctx, item)
            if item.type_kind ~= "record"
                and item.type_kind ~= "interface"
                and item.type_kind ~= "enum"
            then
                return true
            end

            local old_path_mode = ctx.path_mode
            ctx.path_mode = "none"
            for _, child_path in ipairs(item.children or {}) do
                local child = assert(
                    ctx.env.registry[child_path],
                    "Child item not found: " .. child_path
                )
                if not ctx.filter or ctx.filter(child, ctx.env) then
                    ctx.builder:line()
                    structure_signature(ctx, child, indent .. "    ", true)
                end
            end
            ctx.path_mode = old_path_mode
            ctx.builder:line()
            ctx.builder:rawtext(indent, "end")
            return true
        elseif item.kind == "enumvalue" then
            ctx.builder:rawtext(indent, item.name)
            return true
        elseif item.children then
            local wrote = false
            for _, child_path in ipairs(item.children) do
                local child = assert(
                    ctx.env.registry[child_path],
                    "Child item not found: " .. child_path
                )
                if not ctx.filter or ctx.filter(child, ctx.env) then
                    if wrote then
                        ctx.builder:line()
                    end
                    wrote = structure_signature(
                        ctx,
                        child,
                        indent,
                        record_field
                    ) or wrote
                end
            end
            return wrote
        end
        return false
    end

    local type_signature_phase: Generator.Phase = {
        name = "type_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem)

            ctx.builder:code_block(function()
                structure_signature(ctx, item, "", false)
                ctx.builder:line()
            end)
        end
    }

    -- Parameters, returns and type parameters are tabulated rather than listed,
    -- so that a reader comparing several of them reads down a column instead of
    -- across a sentence each. The first column is whatever names the row, and
    -- the description is last so it takes the width the other columns leave. A
    -- return has no name in Teal, so its table starts at the type and lets row
    -- order say the position a number would have.
    local type_param_columns: {string} = {"Name", "Constraint", "Description"}
    local param_columns: {string} = {"Name", "Type", "Description"}
    local return_columns: {string} = {"Type", "Description"}

    local type_params_phase: Generator.Phase = {
        name = "type_params",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem or item is tealdoc.FunctionItem)

            if not item.typeargs or #item.typeargs == 0 then
                return
            end

            ctx.builder:h4(attr("header"), "Type Parameters")
            ctx.builder:table(type_param_columns, function(row: function(...: function))
                for _, typearg in ipairs(item.typeargs) do
                    row(
                        function()
                            ctx.builder:code(attr("name"), typearg.name or "?")
                        end,
                        function()
                            if typearg.constraint then
                                ctx.builder:text(attr("constraint"), function()
                                    markdown_type(
                                        ctx,
                                        typearg.constraint,
                                        typearg.type_references
                                    )
                                end)
                            end
                        end,
                        function()
                            if typearg.description then
                                ctx.builder:text(attr("description"), function()
                                    ctx.builder:md(markdown_with_type_links(
                                        ctx,
                                        typearg.description
                                    ))
                                end)
                            end
                        end
                    )
                end
            end)
        end
    }

    local markdown_type_params_phase: Generator.Phase = {
        name = "markdown_type_params",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem or item is tealdoc.FunctionItem)

            if not item.typeargs or #item.typeargs == 0 then
                return
            end

            markdown_section(ctx, item, "Type Parameters")
            ctx.builder:table(type_param_columns, function(row: function(...: function))
                for _, typearg in ipairs(item.typeargs) do
                    row(
                        function()
                            ctx.builder:code(attr("name"), typearg.name or "?")
                        end,
                        function()
                            if typearg.constraint then
                                ctx.builder:text(attr("constraint"), function()
                                    markdown_type(
                                        ctx,
                                        typearg.constraint,
                                        typearg.type_references
                                    )
                                end)
                            end
                        end,
                        function()
                            if typearg.description then
                                ctx.builder:text(attr("description"), function()
                                    ctx.builder:md(markdown_with_type_links(
                                        ctx,
                                        typearg.description
                                    ))
                                end)
                            end
                        end
                    )
                end
            end)
        end
    }

    local function_params_phase: Generator.Phase = {
        name = "function_params",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)

            if not item.params or #item.params == 0 then
                return
            end

            ctx.builder:h4(attr("name"), "Parameters")
            ctx.builder:table(param_columns, function(row: function(...: function))
                for _, param in ipairs(item.params) do
                    row(
                        function()
                            if param.name then
                                ctx.builder:code(attr("name"), param.name)
                            end
                        end,
                        function()
                            ctx.builder:code(attr("type"), param.type or "?")
                        end,
                        function()
                            if param.description then
                                ctx.builder:text(attr("description"), function()
                                    ctx.builder:md(markdown_with_type_links(
                                        ctx,
                                        param.description
                                    ))
                                end)
                            end
                        end
                    )
                end
            end)
        end
    }

    local markdown_function_params_phase: Generator.Phase = {
        name = "markdown_function_params",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)
            markdown_section(ctx, item, "Arguments")

            if not item.params or #item.params == 0 then
                ctx.builder:paragraph("None.")
                return
            end

            ctx.builder:table(param_columns, function(row: function(...: function))
                for _, param in ipairs(item.params) do
                    row(
                        function()
                            if param.name then
                                ctx.builder:code(attr("name"), param.name)
                            end
                        end,
                        function()
                            ctx.builder:text(attr("type"), function()
                                markdown_type(
                                    ctx,
                                    param.type or "?",
                                    param.type_references
                                )
                            end)
                        end,
                        function()
                            if param.description then
                                ctx.builder:text(attr("description"), function()
                                    ctx.builder:md(markdown_with_type_links(
                                        ctx,
                                        param.description
                                    ))
                                end)
                            end
                        end
                    )
                end
            end)
        end
    }

    local function_returns_phase: Generator.Phase = {
        name = "function_returns",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)

            if not item.returns or #item.returns == 0 then
                return
            end

            ctx.builder:h4(attr("header"), "Returns")

            ctx.builder:table(return_columns, function(row: function(...: function))
                for _, ret in ipairs(item.returns) do
                    row(
                        function()
                            ctx.builder:code(attr("type"), ret.type or "?")
                        end,
                        function()
                            if ret.description then
                                ctx.builder:text(attr("description"), function()
                                    ctx.builder:md(markdown_with_type_links(
                                        ctx,
                                        ret.description
                                    ))
                                end)
                            end
                        end
                    )
                end
            end)
        end
    }

    local markdown_function_returns_phase: Generator.Phase = {
        name = "markdown_function_returns",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)
            markdown_section(ctx, item, "Returns")

            if not item.returns or #item.returns == 0 then
                ctx.builder:paragraph("None.")
                return
            end

            ctx.builder:table(return_columns, function(row: function(...: function))
                for _, ret in ipairs(item.returns) do
                    row(
                        function()
                            ctx.builder:text(attr("type"), function()
                                markdown_type(
                                    ctx,
                                    ret.type or "?",
                                    ret.type_references
                                )
                            end)
                        end,
                        function()
                            if ret.description then
                                ctx.builder:text(attr("description"), function()
                                    ctx.builder:md(markdown_with_type_links(
                                        ctx,
                                        ret.description
                                    ))
                                end)
                            end
                        end
                    )
                end
            end)
        end
    }

    MarkdownGenerator.item_phases["module"] = {module_header_phase}
    MarkdownGenerator.item_phases["function"] = {
        markdown_header_phase,
        text_phase,
        function_signature_phase,
        markdown_type_params_phase,
        markdown_function_params_phase,
        markdown_function_returns_phase
    }
    MarkdownGenerator.item_phases["variable"] = {
        markdown_header_phase,
        text_phase,
        variable_signature_phase
    }
    MarkdownGenerator.item_phases["type"] = {
        markdown_header_phase,
        text_phase,
        type_signature_phase,
        markdown_type_params_phase
    }
    MarkdownGenerator.item_phases["enumvalue"] = {markdown_header_phase, text_phase}
    MarkdownGenerator.item_phases["markdown"] = {text_phase}

    HTMLGenerator.item_phases["module"] = {module_header_phase, detailed_signature_phase}
    HTMLGenerator.item_phases["function"] = {header_phase, function_signature_phase, text_phase, type_params_phase, function_params_phase, function_returns_phase}
    HTMLGenerator.item_phases["variable"] = {header_phase, variable_signature_phase, text_phase}
    HTMLGenerator.item_phases["type"] = {header_phase, detailed_signature_phase, text_phase, type_params_phase}
    HTMLGenerator.item_phases["enumvalue"] = {header_phase, text_phase}
    HTMLGenerator.item_phases["markdown"] = {text_phase}

    return env
end

return DefaultEnv
