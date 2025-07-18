local util = require("spec.util")

describe("teal support in tealdoc: variables", function()
    it("should parse a local variable", function()
        util.check_registry([[
            --- my variable
            local x: integer = 42
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 7,
                }
            }
        })
    end)

    it("should parse a local variable with inferred type", function()
        util.check_registry([[
            --- my variable
            local x = 42
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 7,
                }
            }
        })
    end)

    it("should parse a global variable", function()
        util.check_registry([[
            --- my variable
            global x: integer = 42
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "global",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 8,
                }
            }
        })
    end)

    it("should parse a global variable with inferred type", function()
        util.check_registry([[
            --- my variable
            global x = 42
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "global",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 8,
                }
            }
        })
    end)

    it("should parse multiple variables in a single declaration", function()
        util.check_registry([[
            --- my variables
            local x, y = 42, 43
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variables",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 7,
                }
            },
            ["test~y"] = {
                kind = "variable",
                typename = "integer",
                name = "y",
                text = "my variables",
                visibility = "local",
                parent = "$test",
                path = "test~y",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 10,
                }
            }
        })
    end)
end)
