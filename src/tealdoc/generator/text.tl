local record Text
    escape_html: function(text: string): string
    strip_tags: function(text: string): string
    plain_text: function(html: string): string
    slug: function(text: string): string
end

function Text.escape_html(text: string): string
    return ((text or ""):gsub("([&<>'\"])", {
        ["&"] = "&amp;",
        ["<"] = "&lt;",
        [">"] = "&gt;",
        ["'"] = "&#39;",
        ['"'] = "&quot;",
    }))
end

function Text.strip_tags(text: string): string
    local stripped = text:gsub(
        '%s*<span class="tealdoc%-kind%-badge[^"]*">.-</span>',
        ""
    )
    stripped = stripped:gsub("<[^>]+>", "")
    stripped = stripped:gsub("&quot;", '"')
        :gsub("&#39;", "'")
        :gsub("&lt;", "<")
        :gsub("&gt;", ">")
        :gsub("&amp;", "&")
    return stripped
end

function Text.plain_text(html: string): string
    return (Text.strip_tags(html)
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", ""))
end

function Text.slug(text: string): string
    local value = Text.strip_tags(text):lower()
    local output: {string} = {}
    local separator = false
    for index = 1, #value do
        local byte = value:byte(index)
        local alphanumeric = byte >= 48 and byte <= 57
            or byte >= 97 and byte <= 122
            or byte >= 128
        if alphanumeric then
            if separator and #output > 0 then
                table.insert(output, "-")
            end
            table.insert(output, value:sub(index, index))
            separator = false
        elseif byte == 32
            or byte == 9
            or byte == 10
            or byte == 13
            or byte == 45
            or byte == 46
            or byte == 95
        then
            separator = true
        end
    end
    return table.concat(output)
end

return Text
