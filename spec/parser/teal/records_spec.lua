local util = require("spec.util")

describe("teal support in tealdoc: records", function()
    describe("declarations", function()
        it("should parse a local record", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    }
                }
            })
        end)

        it("should parse a global record", function()
            util.check_registry([[
                --- my record
                global record MyRecord
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "global",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    }
                }
            })
        end)

        it("should parse a local record with generics", function()
            util.check_registry([[
                --- my record
                local record MyRecord<T>
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord<T>",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T"} },
                }
            })
        end)

        it("should parse a global record with generics", function()
            util.check_registry([[
                --- my record
                global record MyRecord<T>
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord<T>",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "global",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T"} },
                }
            })
        end)

        it("should parse a local record with a constrained generic", function()
            util.check_registry([[
                --- my record
                local record MyRecord<T is math.Numeric>
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord<T is math.Numeric>",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T", constraint = "math.Numeric" } },
                }
            })
        end)

        it("should parse a global record with a constrained generic", function()
            util.check_registry([[
                --- my record
                global record MyRecord<T is math.Numeric>
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord<T is math.Numeric>",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "global",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T", constraint = "math.Numeric" } },
                }
            })
        end)
    end)

    describe("fields", function()
        it("should parse fields", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my field
                    a: integer
                    --- my other field
                    b: string
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.a",
                        "test~MyRecord.b",
                    },
                },
                ["test~MyRecord.a"] = {
                    kind = "variable",
                    name = "a",
                    typename = "integer",
                    text = "my field",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.a",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 8,
                    },
                },
                ["test~MyRecord.b"] = {
                    kind = "variable",
                    name = "b",
                    typename = "string",
                    text = "my other field",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.b",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 8,
                    },
                }
            })
        end)
    end)

    describe("functions", function()
        it("should parse a function without params and returns", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my function
                    my_function: function()
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 18,
                    },
                }
            })
        end)

        it("should parse a function with params and returns", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my function
                    my_function: function(integer, integer): integer, integer
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 18,
                    },
                    params = {
                        { type = "integer" },
                        { type = "integer" },
                    },
                    returns = {
                        { type = "integer" },
                        { type = "integer" },
                    }
                }
            })
        end)

        it("should parse a function with generics", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my function
                    my_function: function<T>(x: T): T
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                    typeargs = {
                        { name = "T" }
                    }
                }
            })
        end)

        it("should parse a function with a constrained generic", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my function
                    my_function: function<T is math.Numeric>(x: T): T
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                    typeargs = {
                        { name = "T", constraint = "math.Numeric" }
                    }
                }
            })
        end)

        it("should parse overloaded functions", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my function
                    my_function: function(integer, integer): integer

                    --- my overloaded function
                    my_function: function(string, string): string

                    --- my other overloaded function
                    my_function: function(boolean, boolean): boolean
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    text = "my record",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    kind = "overload",
                    name = "my_function",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    children = {
                        "test~MyRecord.my_function(integer, integer)",
                        "test~MyRecord.my_function(string, string)",
                        "test~MyRecord.my_function(boolean, boolean)",
                    },
                },
                ["test~MyRecord.my_function(integer, integer)"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyRecord.my_function",
                    path = "test~MyRecord.my_function(integer, integer)",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 18,
                    },
                    params = {
                        { type = "integer" },
                        { type = "integer" },
                    },
                    returns = {
                        { type = "integer" },
                    }
                },
                ["test~MyRecord.my_function(string, string)"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my overloaded function",
                    visibility = "record",
                    parent = "test~MyRecord.my_function",
                    path = "test~MyRecord.my_function(string, string)",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 18,
                    },
                    params = {
                        { type = "string" },
                        { type = "string" },
                    },
                    returns = {
                        { type = "string" },
                    }
                },
                ["test~MyRecord.my_function(boolean, boolean)"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my other overloaded function",
                    visibility = "record",
                    parent = "test~MyRecord.my_function",
                    path = "test~MyRecord.my_function(boolean, boolean)",
                    location = {
                        filename = "test.tl",
                        y = 10,
                        x = 18,
                    },
                    params = {
                        { type = "boolean" },
                        { type = "boolean" },
                    },
                    returns = {
                        { type = "boolean" },
                    }
                }
            })
        end)
    end)
end)