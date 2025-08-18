local util = require("spec.util")

describe("should support functions attached to tables", function()
    it("should parse a function attached to a table", function()
       util.check_registry([[
            local x = {}

            --- my function
            function x.y(a: integer, b: string): boolean
                return true
            end
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "{}",
                name = "x",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 7,
                },
                children = {
                    "test~x.y",
                },
            },
            ["test~x.y"] = {
                kind = "function",
                function_kind = "function",
                name = "y",
                visibility = "record",
                parent = "test~x",
                path = "test~x.y",
                text = "my function",
                location = {
                    filename = "test.tl",
                    y = 4,
                    x = 1,
                },
                params = {
                    { name = "a", type = "integer" },
                    { name = "b", type = "string" },
                },
                returns = {
                    { type = "boolean" }
                },
            }
        })
    end)
    it("should parse a function with generics attached to a table", function()
       util.check_registry([[
            local x = {}

            --- my function
            function x.y<T is math.Numeric>(a: T): T
                return a
            end
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "{}",
                name = "x",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 7,
                },
                children = {
                    "test~x.y",
                },
            },
            ["test~x.y"] = {
                kind = "function",
                function_kind = "function",
                name = "y",
                visibility = "record",
                parent = "test~x",
                path = "test~x.y",
                text = "my function",
                location = {
                    filename = "test.tl",
                    y = 4,
                    x = 1,
                },
                typeargs = { { name = "T", constraint = "math.Numeric" } },
                params = {
                    { name = "a", type = "T" },
                },
                returns = {
                    { type = "T" }
                },
            }
        })
    end)
    it("should parse a function attached to a table via assignment", function()
       util.check_registry([[
            local x = {}

            x.y = function(a: integer, b: string): boolean
                return true
            end
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "{}",
                name = "x",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 7,
                },
                children = {
                    "test~x.y",
                },
            },
            ["test~x.y"] = {
                kind = "function",
                function_kind = "function",
                name = "y",
                visibility = "record",
                parent = "test~x",
                path = "test~x.y",
                location = {
                    filename = "test.tl",
                    y = 3,
                    x = 7,
                },
                params = {
                    { name = "a", type = "integer" },
                    { name = "b", type = "string" },
                },
                returns = {
                    { type = "boolean" }
                },
            }
        })
    end)
    it("should parse a function attached to a table via assignment with generics", function()
       util.check_registry([[
            local x = {}

            x.y = function<T is math.Numeric>(a: T): T
                return a
            end
        ]], {
            ["test~x"] = {
                kind = "variable",
                typename = "{}",
                name = "x",
                visibility = "local",
                parent = "$test",
                path = "test~x",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 7,
                },
                children = {
                    "test~x.y",
                },
            },
            ["test~x.y"] = {
                kind = "function",
                function_kind = "function",
                name = "y",
                visibility = "record",
                parent = "test~x",
                path = "test~x.y",
                location = {
                    filename = "test.tl",
                    y = 3,
                    x = 7,
                },
                typeargs = { { name = "T", constraint = "math.Numeric" } },
                params = {
                    { name = "a", type = "T" },
                },
                returns = {
                    { type = "T" }
                },
            }
        })  
    end)
end)