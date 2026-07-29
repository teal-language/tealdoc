--- Syntax highlighting for languages that are not Teal, through Scintillua's
--- LPeg lexers.
---
--- Teal keeps its own tokenizer: `tl.lex` is the compiler's, and it is what
--- lets a type name in a code block become a link to the page that documents
--- it. No general grammar can do that. Everything else is a language whose
--- grammar this project has no business writing, so it does not: the lexers
--- are Scintillua's, vendored unmodified, and what is written here is the
--- adapter between them and the emitter every block already goes through.
---
--- Nothing is vendored and nothing is depended on. Scintillua is not on
--- LuaRocks, and copying a hundred kilobytes of somebody else's grammars into
--- a documentation generator is not what a documentation generator is for. A
--- site that wants languages beyond Teal installs Scintillua itself and says
--- where it put the lexers, through `tealdoc.site.lexers`. A site that says
--- nothing loses nothing: a block in a language nothing here reads is emitted
--- exactly as it was written, which is what happened before any of this.
---
--- Scintillua answers a flat list alternating tag name and start offset,
--- `{"keyword", 2, "whitespace.lua", 3}`, where a run reaches to the next
--- offset. That converts to the segments the emitter already consumes, so a
--- highlighted shell block reaches the same spans, the same classes and the
--- same theme as a highlighted Teal one.
local Highlighter = require("tealdoc.generator.site.highlighter")

local record Scintillua
    --- Answers the segments a language's lexer reads out of `code`, or nil
    --- when no lexer is vendored for that language.
    segments: function(string, string): {Highlighter.Segment}
    --- Points the adapter at a directory of Scintillua lexers, or at nothing.
    --- Called once for a build, before any page is rendered.
    configure: function(string)
end

--- The languages to try a lexer for. Teal and Lua are absent on purpose: they
--- go through the compiler's own lexer, which is better at them than any
--- general grammar and is what carries the type links.
---
--- A name here is asked of Scintillua and dropped if it has no such lexer, so
--- this list costs nothing when the directory is unset or incomplete.
local LEXERS: {string: boolean} = {
    bash = true,
    json = true,
    xml = true,
}

--- Scintillua's tag names against the styles the emitter already knows.
---
--- The tags are matched on their first component, because Scintillua names a
--- subtype with a dot, `function.builtin`, and suffixes whitespace with the
--- language, `whitespace.bash`. A tag with no entry here draws no span and
--- reads as ordinary code, which is the right answer for `default` and for
--- anything a lexer names that this theme has no colour for.
local STYLES: {string: string} = {
    keyword = "keyword",
    comment = "comment",
    string = "string",
    number = "number",
    operator = "operator",
    identifier = "variable",
    ["function"] = "function",
    type = "type",
    class = "type",
    constant = "boolean",
    variable = "variable",
    preprocessor = "meta",
    annotation = "meta",
    label = "meta",
    embedded = "meta",
    regex = "string",
    -- Markup, which is what the XML lexer answers in.
    tag = "keyword",
    attribute = "property",
    entity = "boolean",
    property = "property",
}

--- Where the lexers are, as the site said. Scintillua reads its own directory
--- out of `scintillua.lexers` and loads a lexer with `loadfile` against a
--- sandboxed environment, so nothing goes onto `package.path` and a lexer
--- named `json` cannot be mistaken for anybody's JSON module.
local directory: string = nil

--- The shape of Scintillua this reaches for, which is two calls and one
--- property. Naming it keeps the casting to the one place the library crosses
--- into typed code.
local record Lexer
    lex: function(Lexer, string): {any}
end

local record Library
    property: {string: string}
    load: function(string): Lexer
end

local library_module: Library = nil
local loaded: {string: Lexer} = {}
local searched = false

function Scintillua.configure(lexers: string)
    if lexers == directory then
        return
    end
    directory = lexers
    library_module = nil
    loaded = {}
    searched = false
end

local function library(): Library
    if searched then
        return library_module
    end
    searched = true
    if not directory then
        return nil
    end
    local chunk = loadfile(directory .. "/lexer.lua")
    if not chunk then
        return nil
    end
    local ok, module = pcall(chunk)
    if not ok or not module then
        return nil
    end
    library_module = module as Library
    -- Set explicitly rather than left to the library's own default, which is
    -- every directory on `package.path`. A lexer is found here or not at all.
    library_module.property = setmetatable(
        { ["scintillua.lexers"] = directory } as {string: string},
        { __index = function(): string return "" end }
    )
    return library_module
end

function Scintillua.supports(language: string): boolean
    return LEXERS[language] == true
end

function Scintillua.segments(
    language: string,
    code: string
): {Highlighter.Segment}
    if not LEXERS[language] then
        return nil
    end
    local module = library()
    if not module then
        return nil
    end
    local lexer = loaded[language]
    if not lexer then
        local ok, result = pcall(module.load, language)
        if not ok or not result then
            return nil
        end
        lexer = result as Lexer
        loaded[language] = lexer
    end
    local ok, tags = pcall(lexer.lex, lexer, code)
    if not ok or not tags then
        return nil
    end

    -- The offset beside a tag is where the run *ends*, one past its last
    -- byte, so a run reaches from wherever the previous one stopped. Reading
    -- them as starts puts every span one token out of place, which is a thing
    -- that looks almost right on a short line and falls apart on a real one.
    local list = tags as {any}
    local segments: {Highlighter.Segment} = {}
    local cursor = 1
    for index = 1, #list - 1, 2 do
        local tag = list[index] as string
        local stop = list[index + 1] as integer
        local first, last = cursor, stop - 1
        cursor = stop
        local style = STYLES[(tag:match("^[^.]+") or tag)]
        if style and last >= first then
            table.insert(segments, {
                first = first,
                last = last,
                style = style,
            })
        end
    end
    return segments
end

return Scintillua
