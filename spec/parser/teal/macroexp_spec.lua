local util = require("spec.util")

describe("teal support in tealdoc: macroexps", function()
    it("should parse a local macroexp", function()
        util.check_registry([[
            --- my macroexp
            local macroexp my_macroexp()
                return nil
            end
        ]], {
            ["test~my_macroexp"] = {
                kind = "function",
                function_kind = "macroexp",
                name = "my_macroexp",
                text = "my macroexp",
                visibility = "local",
                parent = "$test",
                path = "test~my_macroexp",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)

    it("should parse a local macroexp with params and returns", function()
        util.check_registry([[
            --- my macroexp
            local macroexp my_macroexp(x: integer, y: integer): integer
                return x + y
            end
        ]], {
            ["test~my_macroexp"] = {
                kind = "function",
                function_kind = "macroexp",
                name = "my_macroexp",
                text = "my macroexp",
                visibility = "local",
                parent = "$test",
                path = "test~my_macroexp",
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
                    { type = "integer" }
                },
            }
        })
    end)

    -- wait for teal bugfix!

    -- it("should parse a local macroexp with generics", function()
    --     util.check_registry([[
    --         --- my macroexp
    --         local macroexp my_macroexp<T>(x: T): T
    --             return x
    --         end
    --     ]], {
    --         ["test~my_macroexp"] = {
    --             kind = "function",
    --             function_kind = "macroexp",
    --             name = "my_macroexp",
    --             text = "my macroexp",
    --             visibility = "local",
    --             parent = "$test",
    --             path = "test~my_macroexp",
    --             location = {
    --                 filename = "test.tl",
    --                 y = 2,
    --                 x = 1,
    --             },
    --             params = { { name = "x", type = "T" } },
    --             returns = { { type = "T" } },
    --             typeargs = { { name = "T" } },
    --         }
    --     })
    -- end)

    -- it("should parse a local macroexp with a constrained generic", function()
    --     util.check_registry([[
    --         --- my macroexp
    --         local macroexp my_macroexp<T is math.Numeric>(x: T): T
    --             return x
    --         end
    --     ]], {
    --         ["test~my_macroexp"] = {
    --             kind = "function",
    --             function_kind = "macroexp",
    --             name = "my_macroexp",
    --             text = "my macroexp",
    --             visibility = "local",
    --             parent = "$test",
    --             path = "test~my_macroexp",
    --             location = {
    --                 filename = "test.tl",
    --                 y = 2,
    --                 x = 1,
    --             },
    --             params = { { name = "x", type = "T" } },
    --             returns = { { type = "T" } },
    --             typeargs = { { name = "T", constraint = "math.Numeric" } },
    --         }
    --     })
    -- end)
end)