local util = require("spec.util")

describe("teal support in tealdoc: functions", function()
    it("should parse a local function", function()
        util.check_registry([[
            --- my function
            local function my_function()
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "local",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)

    it("should parse a local function with params and returns", function()
        util.check_registry([[
            --- my function
            local function my_function(x: integer, y: integer): integer, integer
                return x + y, x * y
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "local",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                params = {
                    { name = "x", type = "integer" },
                    { name = "y", type = "integer" }
                },
                returns = {
                    { type = "integer" },
                    { type = "integer" }
                },
            }
        })
    end)

    it("should parse a local function with generics", function()
        util.check_registry([[
            --- my function
            local function my_function<T>(x: T): T
                return x
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "local",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                params = { { name = "x", type = "T" } },
                returns = { { type = "T" } },
                typeargs = { { name = "T" } },
            }
        })
    end)

    it("should parse a local function with a constrained generic", function()
        util.check_registry([[
            --- my function
            local function my_function<T is math.Numeric>(x: T): T
                return x
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "local",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                params = { { name = "x", type = "T" } },
                returns = { { type = "T" } },
                typeargs = { { name = "T", constraint = "math.Numeric" } },
            }
        })
    end)

    it("should parse a global function", function()
        util.check_registry([[
            --- my function
            global function my_function()
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "global",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 8,
                },
            }
        })
    end)

    it("should parse a global function with params and returns", function()
        util.check_registry([[
            --- my function
            global function my_function(x: integer, y: integer): integer, integer
                return x + y, x * y
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "global",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 8,
                },
                params = {
                    { name = "x", type = "integer" },
                    { name = "y", type = "integer" }
                },
                returns = {
                    { type = "integer" },
                    { type = "integer" }
                },
            }
        })
    end)

    it("should parse a global function with generics", function()
        util.check_registry([[
            --- my function
            global function my_function<T>(x: T): T
                return x
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "global",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 8,
                },
                params = { { name = "x", type = "T" } },
                returns = { { type = "T" } },
                typeargs = { { name = "T" } },
            }
        })
    end)

    it("should parse a global function with a constrained generic", function()
        util.check_registry([[
            --- my function
            global function my_function<T is math.Numeric>(x: T): T
                return x
            end
        ]], {
            ["test~my_function"] = {
                kind = "function",
                function_kind = "normal",
                name = "my_function",
                text = "my function",
                visibility = "global",
                parent = "$test",
                path = "test~my_function",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 8,
                },
                params = { { name = "x", type = "T" } },
                returns = { { type = "T"} },
                typeargs = { { name = "T", constraint = "math.Numeric" } },
            }
        })
    end)
end)