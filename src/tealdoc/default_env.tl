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

    local typearg_tag_handler: tealdoc.Tag = { -- TODO: improve!
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

            local typearg: tealdoc.Typearg
            if item.typeargs then
                for _, t in ipairs(item.typeargs) do
                    if t.description == nil then
                        typearg = t
                        break
                    end
                end
            end
            if not typearg then
                log:warning(
                    "Found more @typearg tags than declared type arguments in '%s' (%s:%s:%s)",
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
            end

            if typearg.name and typearg.name ~= ctx.param then
                log:warning(
                    "Typearg name mismatch: expected '%s', got '%s' in '%s' (%s:%s:%s)",
                    typearg.name,
                    ctx.param,
                    item.name,
                    item.location.filename,
                    item.location.y,
                    item.location.x
                )
                return
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

    local markdown_header_phase: Generator.Phase = {
        name = "markdown_header",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            local parent = overload_parent(ctx, item)
            if parent then
                if parent.children and parent.children[1] == item.path then
                    ctx.builder:h2(attr("path"), display_path(ctx, parent))
                end
                ctx.builder:h3(attr("header"), "Function")
            else
                ctx.builder:h2(attr("path"), display_path(ctx, item))
            end
        end
    }

    local function markdown_section(ctx: Generator.Phase.Context, item: tealdoc.Item, title: string)
        if overload_parent(ctx, item) then
            ctx.builder:h4(attr("header"), title)
        else
            ctx.builder:h3(attr("header"), title)
        end
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
        while position <= #typename do
            local first, last = typename:find("[%a_][%w_%.]*", position)
            if not first then
                ctx.builder:code(typename:sub(position))
                break
            end
            if first > position then
                ctx.builder:code(typename:sub(position, first - 1))
            end

            local name = typename:sub(first, last)
            local url = urls[name]
            if url then
                ctx.builder:link_url(url, function()
                    ctx.builder:code(name)
                end)
            else
                ctx.builder:code(name)
            end
            position = last + 1
        end
    end

    local text_phase: Generator.Phase = {
        name = "text",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            if item.text then
                ctx.builder:paragraph(attr("text"), function()
                    ctx.builder:md(item.text)
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

    local markdown_function_signature_phase: Generator.Phase = {
        name = "markdown_function_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.FunctionItem)
            markdown_section(ctx, item, "Synopsis")
            function_signature_phase.run(ctx, item)
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

    local markdown_variable_signature_phase: Generator.Phase = {
        name = "markdown_variable_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            markdown_section(ctx, item, "Synopsis")
            variable_signature_phase.run(ctx, item)
        end
    }

    local type_signature_phase: Generator.Phase = {
        name = "type_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem)

            ctx.builder:code_block(function()
                signatures.for_type(ctx, item)
                ctx.builder:line()
            end)
        end
    }

    local markdown_type_signature_phase: Generator.Phase = {
        name = "markdown_type_signature",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            markdown_section(ctx, item, "Synopsis")
            type_signature_phase.run(ctx, item)
        end
    }

    local type_params_phase: Generator.Phase = {
        name = "type_params",
        run = function(ctx: Generator.Phase.Context, item: tealdoc.Item)
            assert(item is tealdoc.TypeItem or item is tealdoc.FunctionItem)

            if not item.typeargs or #item.typeargs == 0 then
                return
            end

            ctx.builder:h4(attr("header"), "Type Parameters")
            ctx.builder:unordered_list(function(list_item: function(content: function))
                for _, typearg in ipairs(item.typeargs) do
                    list_item(function()
                        ctx.builder:b(function()
                            ctx.builder:code(attr("name"), typearg.name or "?")
                        end)

                        if typearg.constraint then
                            ctx.builder:text(attr("constraint"), " ( is ", function() ctx.builder:code(typearg.constraint) end, ")")
                        end

                        if typearg.description then
                            ctx.builder:text(attr("description"), " — ", function() ctx.builder:md(typearg.description) end)
                        end
                    end)
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
            ctx.builder:unordered_list(function(list_item: function(content: function)) -- TODO!
                for _, param in ipairs(item.params) do
                    list_item(function()
                        if param.name then
                            ctx.builder:b(function()
                                ctx.builder:code(attr("name"), param.name)
                            end)
                        end
                        ctx.builder:text(attr("type"), " (", function() ctx.builder:code(param.type or "?") end, ")")
                        if param.description then
                            ctx.builder:text(attr("description"), " — ", function()
                                ctx.builder:md(param.description)
                            end)
                        end
                    end)
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

            ctx.builder:unordered_list(function(list_item: function(content: function))
                for _, param in ipairs(item.params) do
                    list_item(function()
                        if param.name then
                            ctx.builder:b(function()
                                ctx.builder:code(attr("name"), param.name)
                            end)
                        end
                        ctx.builder:text(attr("type"), " (", function()
                            markdown_type(ctx, param.type or "?", param.type_references)
                        end, ")")
                        if param.description then
                            ctx.builder:text(attr("description"), " — ", function()
                                ctx.builder:md(param.description)
                            end)
                        end
                    end)
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

            ctx.builder:ordered_list(function(list_item: function(content: function))
                for _, ret in ipairs(item.returns) do
                    list_item(function()
                        ctx.builder:text(attr("type"), "(", function() ctx.builder:code(ret.type or "?") end, ")")
                        if ret.description then
                            ctx.builder:text(attr("description"), " — ", function() ctx.builder:md(ret.description) end)
                        end
                    end)
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

            ctx.builder:ordered_list(function(list_item: function(content: function))
                for _, ret in ipairs(item.returns) do
                    list_item(function()
                        ctx.builder:text(attr("type"), "(", function()
                            markdown_type(ctx, ret.type or "?", ret.type_references)
                        end, ")")
                        if ret.description then
                            ctx.builder:text(attr("description"), " — ", function() ctx.builder:md(ret.description) end)
                        end
                    end)
                end
            end)
        end
    }

    MarkdownGenerator.item_phases["module"] = {module_header_phase}
    MarkdownGenerator.item_phases["function"] = {
        markdown_header_phase,
        text_phase,
        markdown_function_signature_phase,
        type_params_phase,
        markdown_function_params_phase,
        markdown_function_returns_phase
    }
    MarkdownGenerator.item_phases["variable"] = {
        markdown_header_phase,
        text_phase,
        markdown_variable_signature_phase
    }
    MarkdownGenerator.item_phases["type"] = {
        markdown_header_phase,
        text_phase,
        markdown_type_signature_phase,
        type_params_phase
    }
    MarkdownGenerator.item_phases["enumvalue"] = {header_phase, text_phase}
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
