local log = require("log")
local tealdoc = require("tealdoc")
local TealParser = require("parser.teal")

local record DefaultEnv
end

function DefaultEnv.init(): tealdoc.Env
    local env = tealdoc.Env.init()

    env:add_parser(TealParser)

    -- TODO: better place for this
    local module_tag_handler: tealdoc.TagHandler = {
        name = "module",
        has_param = true,
        handle = function(ctx: tealdoc.TagHandler.Context)
            local item = ctx.item
            if not item is tealdoc.DirectiveItem then
                log:error("module tag can only exists in directives")
                return
            end
            if item.module_name then
                log:error(
                    "Multiple @module tags found in the same comment block: previously defined as '%s', now found as '%s'. Only one @module tag is allowed per top-level comment.",
                    ctx.item.attributes["module"],
                    ctx.param
                )
            end
            -- TODO: validate module name?
            item.module_name = ctx.param
        end
    }

    local param_tag_handler: tealdoc.TagHandler = {
        name = "param",
        has_param = true,
        has_description = true,
        handle = function(ctx: tealdoc.TagHandler.Context)
            local item = ctx.item
            if not item is tealdoc.FunctionItem then
                -- better error!
                log:error("param tag can only exists in function comments")
                return
            end

            local param: tealdoc.FunctionItem.Param
            if item.params then
                for _, p in ipairs(item.params) do
                    if p.name == nil or p.name == ctx.param then -- TODO: temp!
                        param = p
                        break
                    end
                end
            end
            param.name = ctx.param
            if not param then
                log:error(
                    "param tag for parameter '%s' does not match any parameter in function '%s' declaration!",
                    ctx.param,
                    ctx.item.attributes and ctx.item.attributes["name"] or "<unknown>"
                )
            end
            if param.description then
                log:error(
                    "Duplicate @param tag for parameter '%s' in function '%s'. Each parameter should only have one @param tag.",
                    ctx.param,
                    ctx.item.attributes and ctx.item.attributes["name"] or "<unknown>"
                )
            end
            param.description = ctx.description
        end
    }

    local return_tag_handler: tealdoc.TagHandler = {
        name = "return",
        has_description = true,
        handle = function(ctx: tealdoc.TagHandler.Context)
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


    local typearg_tag_handler: tealdoc.TagHandler = { -- TODO: improve!
        name = "typearg",
        has_param = true,
        has_description = true,
        handle = function(ctx: tealdoc.TagHandler.Context)
            local item = ctx.item
            if not (item is tealdoc.TypeItem or item is tealdoc.FunctionItem)  then
                -- better error!
                log:error("typearg tag can only exists in function comments")
                return
            end

            local param: tealdoc.Typearg
            if item.typeargs then
                for _, p in ipairs(item.typeargs) do
                    if p.name == nil or p.name == ctx.param then -- TODO: temp!
                        param = p
                        break
                    end
                end
            end
            if param then
                param.name = ctx.param
            end
            if not param then
                log:error(
                    "typearg tag for parameter '%s' does not match any type argument in function '%s' declaration!",
                    ctx.param,
                    ctx.item.attributes and ctx.item.attributes["name"] or "<unknown>"
                )
            end
            if param.description then
                log:error(
                    "Duplicate @typearg tag for parameter '%s' in function '%s'. Each type argument should only have one @typearg tag.",
                    ctx.param,
                    ctx.item.attributes and ctx.item.attributes["name"] or "<unknown>"
                )
            end
            param.description = ctx.description
        end
    }

    env:add_tag_handler(module_tag_handler)
    env:add_tag_handler(return_tag_handler)
    env:add_tag_handler(param_tag_handler)
    env:add_tag_handler(typearg_tag_handler)
    
    return env
end

return DefaultEnv