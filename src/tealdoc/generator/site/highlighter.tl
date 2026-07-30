local tl = require("tl")
local Text = require("tealdoc.generator.text")

local record Highlighter
    type Links = {string: string}

    record Segment
        first: integer
        last: integer
        style: string
        url: string
    end

    highlight: function(string, Links): string
    --- Emits the spans a list of segments describes over the code they were
    --- read from. Segments come from a tokenizer; this is the half that does
    --- not care which one, so a lexer that is not Teal's reaches the same
    --- markup and the same theme.
    render: function(string, {Segment}): string
end

local type Segment = Highlighter.Segment

local type_names: {string: boolean} = {
    ["any"] = true,
    ["boolean"] = true,
    ["integer"] = true,
    ["number"] = true,
    ["string"] = true,
    ["thread"] = true,
    ["unknown"] = true,
    ["userdata"] = true,
}

local contextual_keywords: {string: boolean} = {
    ["as"] = true,
    ["close"] = true,
    ["const"] = true,
    ["enum"] = true,
    ["global"] = true,
    ["interface"] = true,
    ["is"] = true,
    ["macroexp"] = true,
    ["metamethod"] = true,
    ["record"] = true,
    ["total"] = true,
    ["type"] = true,
    ["userdata"] = true,
    ["where"] = true,
}

local literal_keywords: {string: boolean} = {
    ["false"] = true,
    ["nil"] = true,
    ["true"] = true,
}

local punctuation: {string: boolean} = {
    ["("] = true,
    [")"] = true,
    ["["] = true,
    ["]"] = true,
    ["{"] = true,
    ["}"] = true,
    [","] = true,
    [";"] = true,
    [":"] = true,
    ["."] = true,
    ["?"] = true,
}

local function token_style(tokens: {tl.Token}, index: integer): string
    local token = tokens[index]
    local kind = token.kind
    local text = token.tk
    local previous = tokens[index - 1]
    local following = tokens[index + 1]

    if kind == "keyword" and literal_keywords[text] then
        return "boolean"
    elseif kind == "keyword" then
        return "keyword"
    elseif kind == "string" then
        return "string"
    elseif kind == "number" or kind == "integer" then
        return "number"
    elseif kind == "op" then
        return "operator"
    elseif kind == "pragma" or kind == "pragma_identifier" or kind == "hashbang" then
        return "meta"
    elseif kind == "identifier" then
        if contextual_keywords[text] then
            return "keyword"
        elseif type_names[text] or text:match("^%u") then
            return "type"
        elseif following and following.tk == "(" then
            return "function"
        elseif previous and (previous.tk == "." or previous.tk == ":") then
            return "property"
        end
        return "variable"
    elseif punctuation[text] then
        return "punctuation"
    end
    return nil
end

local function token_classes(style: string, text: string): string
    if style == "type" then
        return "token class-name tealdoc-token-type"
    elseif style == "meta" then
        return "token directive tealdoc-token-meta"
    elseif style == "keyword" then
        return "token keyword keyword-" ..
            text:gsub("[^%w%-]", "-") ..
            " tealdoc-token-keyword"
    elseif style == "function" then
        return "token function tealdoc-token-function"
    elseif style == "property" then
        return "token property tealdoc-token-property"
    elseif style == "variable" then
        return "token variable tealdoc-token-variable"
    elseif style == "boolean" then
        return "token boolean tealdoc-token-boolean"
    elseif style == "punctuation" then
        return "token punctuation tealdoc-token-punctuation"
    end
    return "token " .. style .. " tealdoc-token-" .. style
end

local function is_declaration_name(tokens: {tl.Token}, index: integer): boolean
    local cursor = index - 1
    while cursor >= 1 do
        local token = tokens[cursor]
        if token.tk == "record"
            or token.tk == "interface"
            or token.tk == "enum"
            or token.tk == "type"
        then
            return true
        elseif token.kind == "identifier" or token.tk == "." then
            cursor = cursor - 1
        else
            return false
        end
    end
    return false
end

--- The whole dotted expression a type token ends, so `EventListener` read
--- from `types.events.EventListener` answers all three segments. A qualified
--- name is not its last segment: the two name different types as often as
--- they name the same one, and the link map holds the basename of every
--- documented type, so looking one up by its final token alone finds an
--- unrelated public type and links to it.
local function qualified_name(tokens: {tl.Token}, index: integer): string
    local name = tokens[index].tk
    local cursor = index - 1
    while cursor > 1
        and tokens[cursor].tk == "."
        and tokens[cursor - 1].kind == "identifier"
    do
        name = tokens[cursor - 1].tk .. "." .. name
        cursor = cursor - 2
    end
    return name
end

function Highlighter.highlight(code: string, links?: Highlighter.Links): string
    local offsets: {integer} = {1}
    for position = 1, #code do
        if code:byte(position) == 10 then
            table.insert(offsets, position + 1)
        end
    end

    local tokens = tl.lex(code, "tealdoc-code-block.tl")
    local segments: {Segment} = {}
    for index, token in ipairs(tokens) do
        for _, comment in ipairs(token.comments or {}) do
            local first = offsets[comment.y] + comment.x - 1
            table.insert(segments, {
                first = first,
                last = first + #comment.text - 1,
                style = "comment",
            })
        end

        if token.kind ~= "$EOF$" and token.kind ~= "$ERR$" then
            local style = token_style(tokens, index)
            if style then
                local first = offsets[token.y] + token.x - 1
                local url: string
                if style == "type"
                    and not is_declaration_name(tokens, index)
                    and links
                then
                    url = links[qualified_name(tokens, index)]
                end
                table.insert(segments, {
                    first = first,
                    last = first + #token.tk - 1,
                    style = style,
                    url = url,
                })
            end
        end
    end
    table.sort(segments, function(a: Segment, b: Segment): boolean
        if a.first == b.first then
            return a.last > b.last
        end
        return a.first < b.first
    end)

    return Highlighter.render(code, segments)
end

function Highlighter.render(code: string, segments: {Segment}): string
    local output: {string} = {}
    local cursor = 1
    for _, segment in ipairs(segments) do
        if segment.first >= cursor and segment.first <= #code then
            table.insert(output, Text.escape_html(code:sub(cursor, segment.first - 1)))
            local text = code:sub(segment.first, segment.last)
            local token = '<span class="' ..
                token_classes(segment.style, text) ..
                '">' ..
                Text.escape_html(text) ..
                "</span>"
            if segment.url then
                token = '<a class="tealdoc-code-link" href="' ..
                    Text.escape_html(segment.url) ..
                    '">' ..
                    token ..
                    "</a>"
            end
            table.insert(output, token)
            cursor = segment.last + 1
        end
    end
    table.insert(output, Text.escape_html(code:sub(cursor)))
    return table.concat(output)
end

return Highlighter
