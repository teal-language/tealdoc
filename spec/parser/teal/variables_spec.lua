local util = require("spec.util")

describe("teal support in tealdoc: variables", function()
    it("should parse a local variable", function()
        util.check_registry([[
            --- my variable
            local x: integer = 42
        ]], {
            ["$test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
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
            ["$test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
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
            ["$test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "global",
                parent = "$test",
                path = "$test~x",
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
            ["$test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variable",
                visibility = "global",
                parent = "$test",
                path = "$test~x",
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
            ["$test~x"] = {
                kind = "variable",
                typename = "integer",
                name = "x",
                text = "my variables",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 7,
                }
            },
            ["$test~y"] = {
                kind = "variable",
                typename = "integer",
                name = "y",
                text = "my variables",
                visibility = "local",
                parent = "$test",
                path = "$test~y",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 10,
                }
            }
        })
    end)
    it("should parse a local variable with function type", function()
        util.check_registry([[
            --- my function variable
            local x: function()
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                is_declaration = true,
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 10,
                }
            }
        })
    end)
    it("should parse a local variable with function type with parameters and returns", function()
        util.check_registry([[
            --- my function variable
            local x: function(a: integer, b: string): boolean
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                is_declaration = true,
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 10,
                },
                params = {
                    { type = "integer" },
                    { type = "string" }
                },
                returns = { { type = "boolean" } }
            }
        })
    end)
    it("should parse a local variable with function type with type arguments", function()
        util.check_registry([[
            --- my function variable
            local x: function<T>(a: T): T
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                is_declaration = true,
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 4,
                    x = 1,
                },
                typeargs = { { name = "T" } },
                params = { { type = "T" } },
                returns = { { type = "T" } }
            }
        })
    end)
    it("should parse a local variable with function type with constrained type arguments", function()
        util.check_registry([[
            --- my function variable
            local x: function<T is tl.Numeric>(a: T): T
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                is_declaration = true,
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 4,
                    x = 1,
                },
                typeargs = { { name = "T", constraint = "tl.Numeric" } },
                params = { { type = "T" } },
                returns = { { type = "T" } }
            }
        })
    end)
    it("should parse a local variable with function value", function()
        util.check_registry([[
            --- my function variable
            local x = function() 
            end
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 11,
                }
            }
        })
    end)
    it("should parse a local variable with function value with parameters and returns", function()
        util.check_registry([[
            --- my function variable
            local x = function(a: integer, b: string): boolean
            end
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 11,
                },
                params = {
                    { type = "integer" },
                    { type = "string" }
                },
                returns = { { type = "boolean" } }
            }
        })
    end)
    it("should parse a local variable with function value with type arguments", function()
        util.check_registry([[
            --- my function variable
            local x = function<T>(a: T): T
            end
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 11,
                },
                typeargs = { { name = "T" } },
                params = { {  type = "T" } },
                returns = { { type = "T" } }
            }
        })
    end)
    it("should parse a local variable with function value with constrained type arguments", function()
        util.check_registry([[
            --- my function variable
            local x = function<T is tl.Numeric>(a: T): T
            end
        ]], {
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 11,
                },
                typeargs = { { name = "T", constraint = "tl.Numeric" } },
                params = { { type = "T" } },
                returns = { { type = "T" } }
            }
        })
    end)

    it("should parse a local variable with inferred function type", function()
        util.check_registry([[
            local function make_function(): function(integer, string): boolean
            end
            --- my function variable
            local x = make_function()
        ]], {
            ["$test~make_function"] = {
                kind = "function",
                function_kind = "function",
                name = "make_function",
                visibility = "local",
                parent = "$test",
                path = "$test~make_function",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 1,
                },
                returns = { { type = "function(integer, string): boolean" } }
            },
            ["$test~x"] = {
                kind = "function",
                function_kind = "function",
                name = "x",
                text = "my function variable",
                visibility = "local",
                parent = "$test",
                path = "$test~x",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 33,
                },
                params = {
                    { type = "integer" },
                    { type = "string" }
                },
                returns = { { type = "boolean" } }
            }
        })
    end)
end)
