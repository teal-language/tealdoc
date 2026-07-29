local HTMLBuilder = require("tealdoc.generator.html.builder")
local Highlighter = require("tealdoc.generator.site.highlighter")
local Text = require("tealdoc.generator.text")

local record SiteMarkdown
    render: function(
        markdown: string,
        type_links: Highlighter.Links
    ): string
end

local escape_html = Text.escape_html
local strip_tags = Text.strip_tags

local admonition_kinds: {string: string} = {
    ["danger"] = "Danger",
    ["info"] = "Info",
    ["note"] = "Note",
    ["tip"] = "Tip",
    ["warning"] = "Warning",
}

local function site_div(
    content: any,
    attributes: {string: string}
): any
    local classes = attributes and attributes.class or ""
    local kind: string
    local title: string
    kind, title = classes:match("^([%w_-]+)%s*(.-)%s*$")
    if kind == "details" then
        if title == "" then
            title = "Details"
        end
        return {
            '<details class="tealdoc-details"><summary>' ..
                escape_html(title) ..
                '</summary><div class="tealdoc-details-content">',
            content,
            "</div></details>",
        }
    elseif kind == "code-group" then
        return {
            '<div class="tealdoc-code-group" role="group">',
            content,
            "</div>",
        }
    elseif kind == "tealdoc-code-label" then
        return {
            '<figure class="tealdoc-labeled-code"><figcaption>' ..
                escape_html(title) ..
                "</figcaption>",
            content,
            "</figure>",
        }
    end
    if kind and admonition_kinds[kind] then
        if title == "" then
            title = admonition_kinds[kind]
        end
        if kind == "info" then
            kind = "note"
        end
        return {
            '<aside class="tealdoc-admonition tealdoc-admonition-' ..
                escape_html(kind) ..
                '" role="note"><p class="tealdoc-admonition-title">' ..
                escape_html(title) ..
                "</p>",
            content,
            "</aside>",
        }
    end

    local class_attribute = classes ~= ""
        and ' class="' .. escape_html(classes) .. '"'
        or ""
    local id_attribute = attributes
        and attributes.id
        and ' id="' .. escape_html(attributes.id) .. '"'
        or ""
    return {"<div" .. id_attribute .. class_attribute .. ">", content, "</div>"}
end

local github_admonition_kinds: {string: string} = {
    ["CAUTION"] = "danger",
    ["IMPORTANT"] = "important",
    ["NOTE"] = "note",
    ["TIP"] = "tip",
    ["WARNING"] = "warning",
}

local function rope_to_string(rope: any): string
    local output: {string} = {}
    local walk: function(any)
    walk = function(value: any)
        local value_type = type(value)
        if value_type == "table" then
            for _, child in ipairs(value as {any}) do
                walk(child)
            end
        elseif value_type == "function" then
            local callback = value as function(): any
            local ok: boolean
            local result: any
            ok, result = pcall(callback)
            if ok then
                walk(result)
            end
        elseif value ~= nil then
            table.insert(output, tostring(value))
        end
    end
    walk(rope)
    return table.concat(output)
end

local function site_blockquote(content: any): any
    local rendered = rope_to_string(content)
    local marker: string
    local body: string
    marker, body = rendered:match("^%s*%[!([A-Z]+)%]%s*(.*)$")
    if not marker then
        local paragraph: string
        local following: string
        marker, paragraph, following = rendered:match(
            "^%s*<p>%s*%[!([A-Z]+)%]%s*(.-)</p>(.*)$"
        )
        if marker then
            body = paragraph .. following
        end
    end
    local kind = marker and github_admonition_kinds[marker]
    if not kind then
        return {"<blockquote>", content, "</blockquote>"}
    end
    local title = marker:sub(1, 1) .. marker:sub(2):lower()
    return {
        '<aside class="tealdoc-admonition tealdoc-admonition-' ..
            kind ..
            '" role="note"><p class="tealdoc-admonition-title">' ..
            title ..
            "</p>",
        body,
        "</aside>",
    }
end

local function mark_inline_code_spacing(rendered: string): string
    local output: {string} = {}
    local position = 1
    while true do
        local opening_start, opening_end = rendered:find(
            "<code>",
            position,
            true
        )
        if not opening_start then
            table.insert(output, rendered:sub(position))
            break
        end
        local closing_start, closing_end = rendered:find(
            "</code>",
            opening_end + 1,
            true
        )
        if not closing_start then
            table.insert(output, rendered:sub(position))
            break
        end

        table.insert(output, rendered:sub(position, opening_start - 1))
        local classes: {string} = {}
        if strip_tags(rendered:sub(1, opening_start - 1)):match("%S") then
            table.insert(classes, "tealdoc-inline-code-before")
        end
        if strip_tags(rendered:sub(closing_end + 1)):match("%S") then
            table.insert(classes, "tealdoc-inline-code-after")
        end
        if #classes > 0 then
            table.insert(
                output,
                '<code class="' .. table.concat(classes, " ") .. '">'
            )
        else
            table.insert(output, "<code>")
        end
        table.insert(output, rendered:sub(opening_end + 1, closing_end))
        position = closing_end + 1
    end
    return table.concat(output)
end

local function site_paragraph(content: any): any
    return {
        "<p>",
        mark_inline_code_spacing(rope_to_string(content)),
        "</p>",
    }
end

function SiteMarkdown.render(
    markdown: string,
    type_links: Highlighter.Links
): string
    local prepared: {string} = {}
    local fence: string
    local labeled_fence = false
    for line in (markdown .. "\n"):gmatch("(.-)\n") do
        if fence then
            table.insert(prepared, line)
            if line:match("^%s*" .. fence .. "%s*$") then
                fence = nil
                if labeled_fence then
                    table.insert(prepared, "::::")
                    labeled_fence = false
                end
            end
        else
            local indentation, opening, language, label = line:match(
                "^(%s*)(`+)([%w_+%-]+)%s+%[([^%]]+)%]%s*$"
            )
            if opening and #opening >= 3 then
                table.insert(
                    prepared,
                    indentation .. ":::: tealdoc-code-label " .. label
                )
                table.insert(prepared, indentation .. opening .. language)
                fence = opening
                labeled_fence = true
            else
                local plain_fence = line:match("^%s*(```+)")
                if plain_fence then
                    fence = plain_fence
                end
                table.insert(prepared, line)
            end
        end
    end
    markdown = table.concat(prepared, "\n")

    local builder = HTMLBuilder.init({
        fenced_divs = true,
        blockquote = site_blockquote,
        div = site_div,
        paragraph = site_paragraph,
    })
    builder:md(markdown)
    local html = builder:build()
    local function highlight_code(
        language: string,
        links?: Highlighter.Links
    )
        html = html:gsub(
            '<pre><code class="language%-' .. language .. '">(.-)</code></pre>',
            function(code: string): string
                code = code:gsub("&lt;", "<")
                    :gsub("&gt;", ">")
                    :gsub("&quot;", '"')
                    :gsub("&#39;", "'")
                    :gsub("&amp;", "&")
                return '<pre class="language-' ..
                    language ..
                    '"><code class="language-' ..
                    language ..
                    '">' ..
                    Highlighter.highlight(code, links) ..
                    "</code></pre>"
            end
        )
    end
    highlight_code("teal", type_links)
    highlight_code("lua")
    return html
end

return SiteMarkdown
