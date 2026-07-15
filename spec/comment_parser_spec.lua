local CommentParser = require("tealdoc.comment_parser")

describe("comment parser", function()
    it("preserves newlines in item descriptions", function()
        local item = {}
        local env = {tag_registry = {}}

        CommentParser.parse_lines({
            "First paragraph.",
            "",
            "Second paragraph.",
        }, item, env)

        assert.equal(
            "First paragraph.\n\nSecond paragraph.",
            item.text
        )
    end)

    it("preserves newlines in tag descriptions", function()
        local description
        local item = {}
        local env = {
            tag_registry = {
                note = {
                    name = "note",
                    has_description = true,
                    handle = function(ctx)
                        description = ctx.description
                    end,
                },
            },
        }

        CommentParser.parse_lines({
            "@note First paragraph.",
            "",
            "Second paragraph.",
        }, item, env)

        assert.equal(
            "First paragraph.\n\nSecond paragraph.",
            description
        )
    end)
end)
