local tealdoc = require('tealdoc')

local record CommentParser
    parse_lines: function(lines: {string}, item: tealdoc.Item, env: tealdoc.Env)
    parse_text: function(text: string, item: tealdoc.Item, env: tealdoc.Env)
end

function CommentParser.parse_text(text: string, item: tealdoc.Item, env: tealdoc.Env)
    local lines = {}
    for line in text:gmatch("[^\n]*") do
        table.insert(lines, line)
    end
    CommentParser.parse_lines(lines, item, env)
end

function CommentParser.parse_lines(lines: {string}, item: tealdoc.Item, env: tealdoc.Env)
    local in_text = true
    local current_context: tealdoc.Tag.Context
    local current_tag: string

    local function end_tag()
        if not current_context or not current_tag then 
            return
        end
        env.tag_registry[current_tag].handle(current_context)
        current_context = nil
        current_tag = nil
    end

    local function start_tag(handler: tealdoc.Tag, param: string, description: string)
        in_text = false
        end_tag()
        current_tag = handler.name
        current_context = {
            item = item,
            param = param,
            description = handler.has_description and description 
        }
    end

    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        local has_tag = false
        for tag_name, handler in pairs(env.tag_registry) do
            if handler.has_param then
                local pattern = "^@" .. tag_name .. "%s+(%w+)%s*(.*)"
                local param, rest = trimmed:match(pattern)
                if param then 
                    has_tag = true
                    start_tag(handler, param, rest)
                end
            elseif handler.has_description then
                local pattern = "^@" .. tag_name .. "%s+(.*)"
                local description = trimmed:match(pattern)
                if description then 
                    has_tag = true
                    start_tag(handler, nil, description)
                end
            else 
                local pattern = "^@" .. tag_name
                if trimmed:match(pattern) then
                    has_tag = true
                    start_tag(handler, nil, nil)
                end
            end
        end

        if has_tag and in_text then
            in_text = false
        end

        if in_text then
            if not item.text then
                item.text = line
            else 
                item.text = item.text.." "..line
            end 
        elseif not has_tag and current_context and current_context.description then
            current_context.description = current_context.description.." "..line
        end
    end

    end_tag()
end

return CommentParser