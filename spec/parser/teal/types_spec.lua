local util = require("spec.util")

describe("teal support in tealdoc: types", function()
    -- TODO: fix types x locations
    it("should parse a local type alias", function()
        util.check_registry([[
            --- my type
            local type MyType = integer
        ]], {
            ["test~MyType"] = {
                kind = "type",
                name = "MyType",
                typename = "integer",
                text = "my type",
                visibility = "local",
                parent = "$test",
                path = "test~MyType",
                type_kind = "type",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 21,
                }
            }
        })
    end)

    it("should parse a global type alias", function()
        util.check_registry([[
            --- my type
            global type MyType = integer
        ]], {
            ["test~MyType"] = {
                kind = "type",
                name = "MyType",
                typename = "integer",
                text = "my type",
                visibility = "global",
                parent = "$test",
                path = "test~MyType",
                type_kind = "type",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 22,
                }
            }
        })
    end)
end)