local util = require("spec.util")

describe("teal support in tealdoc: interfaces", function()
    describe("declarations", function()
        it("should parse a local interface", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    }
                }
            })
        end)

        it("should parse a global interface", function()
            util.check_registry([[
                --- my interface
                global interface MyInterface
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "global",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    }
                }
            })
        end)

        it("should parse a local interface with generics", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface<T>
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface<T>",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T"} },
                }
            })
        end)

        it("should parse a global interface with generics", function()
            util.check_registry([[
                --- my interface
                global interface MyInterface<T>
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface<T>",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "global",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T"} },
                }
            })
        end)

        it("should parse a local interface with a constrained generic", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface<T is math.Numeric>
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface<T is math.Numeric>",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    typeargs = { { name = "T", constraint = "math.Numeric" } },
                }
            })
        end)

        it("should parse a global interface with a constrained generic", function()
            util.check_registry([[
                --- my interface
                global interface MyInterface<T is math.Numeric>
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface<T is math.Numeric>",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "global",
                    parent = "$test",
                    path = "test~MyInterface",
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
                --- my interface
                local interface MyInterface
                    --- my field
                    a: integer
                    --- my other field
                    b: string
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.a",
                        "test~MyInterface.b",
                    },
                },
                ["test~MyInterface.a"] = {
                    kind = "variable",
                    name = "a",
                    typename = "integer",
                    text = "my field",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.a",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 8,
                    },
                },
                ["test~MyInterface.b"] = {
                    kind = "variable",
                    name = "b",
                    typename = "string",
                    text = "my other field",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.b",
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
                --- my interface
                local interface MyInterface
                    --- my function
                    my_function: function()
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.my_function",
                    },
                },
                ["test~MyInterface.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.my_function",
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
                --- my interface
                local interface MyInterface
                    --- my function
                    my_function: function(integer, integer): integer, integer
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.my_function",
                    },
                },
                ["test~MyInterface.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.my_function",
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
                --- my interface
                local interface MyInterface
                    --- my function
                    my_function: function<T>(x: T): T
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.my_function",
                    },
                },
                ["test~MyInterface.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.my_function",
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
                --- my interface
                local interface MyInterface
                    --- my function
                    my_function: function<T is math.Numeric>(x: T): T
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.my_function",
                    },
                },
                ["test~MyInterface.my_function"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.my_function",
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
                --- my interface
                local interface MyInterface
                    --- my function
                    my_function: function(integer, integer): integer

                    --- my overloaded function
                    my_function: function(string, string): string

                    --- my other overloaded function
                    my_function: function(boolean, boolean): boolean
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.my_function",
                    },
                },
                ["test~MyInterface.my_function"] = {
                    kind = "overload",
                    name = "my_function",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.my_function",
                    children = {
                        "test~MyInterface.my_function(integer, integer)",
                        "test~MyInterface.my_function(string, string)",
                        "test~MyInterface.my_function(boolean, boolean)",
                    },
                },
                ["test~MyInterface.my_function(integer, integer)"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my function",
                    visibility = "record",
                    parent = "test~MyInterface.my_function",
                    path = "test~MyInterface.my_function(integer, integer)",
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
                ["test~MyInterface.my_function(string, string)"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my overloaded function",
                    visibility = "record",
                    parent = "test~MyInterface.my_function",
                    path = "test~MyInterface.my_function(string, string)",
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
                ["test~MyInterface.my_function(boolean, boolean)"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "my_function",
                    text = "my other overloaded function",
                    visibility = "record",
                    parent = "test~MyInterface.my_function",
                    path = "test~MyInterface.my_function(boolean, boolean)",
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
    describe("metamethods", function()
        it("should parse metamethods", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my __add metamethod
                    metamethod __add: function(a: MyInterface, b: MyInterface): MyInterface
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.$meta",
                    },
                },
                ["test~MyInterface.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.$meta",
                    children = {
                        "test~MyInterface.$meta.__add",
                    },
                },
                ["test~MyInterface.$meta.__add"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my __add metamethod",
                    visibility = "record",
                    parent = "test~MyInterface.$meta",
                    path = "test~MyInterface.$meta.__add",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    },
                    params = {
                        { type = "MyInterface" },
                        { type = "MyInterface" }
                    },
                    returns = {
                        { type = "MyInterface" }
                    }
                }
            })
        end)
        it("normal functions and metamethods should not conflict", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my __add metamethod
                    metamethod __add: function(a: MyInterface, b: MyInterface): MyInterface

                    --- my normal function
                    __add: function(a: MyInterface): MyInterface
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.__add",
                        "test~MyInterface.$meta"
                    },
                },
                ["test~MyInterface.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.$meta",
                    children = {
                        "test~MyInterface.$meta.__add"
                    },
                },
                ["test~MyInterface.$meta.__add"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my __add metamethod",
                    visibility = "record",
                    parent = "test~MyInterface.$meta",
                    path = "test~MyInterface.$meta.__add",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    },
                    params = {
                        { type = "MyInterface" },
                        { type = "MyInterface" }
                    },
                    returns = {
                        { type = "MyInterface" }
                    }
                },
                ["test~MyInterface.__add"] = {
                    kind = "function",
                    function_kind = "normal",
                    is_declaration = true,
                    name = "__add",
                    text = "my normal function",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.__add",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 12,
                    },
                    params = {
                        { type = "MyInterface" }
                    },
                    returns = {
                        { type = "MyInterface" }
                    }
                }
            })
        end)
        it("should parse overloaded metamethods", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my __add metamethod
                    metamethod __add: function(a: MyInterface, b: MyInterface): MyInterface

                    --- my overloaded __add metamethod
                    metamethod __add: function(a: MyInterface, b: string): MyInterface
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.$meta",
                    },
                },
                ["test~MyInterface.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.$meta",
                    children = {
                        "test~MyInterface.$meta.__add",
                    },
                },
                ["test~MyInterface.$meta.__add"] = {
                    kind = "overload",
                    name = "__add",
                    parent = "test~MyInterface.$meta",
                    path = "test~MyInterface.$meta.__add",
                    children = {
                        "test~MyInterface.$meta.__add(MyInterface, MyInterface)",
                        "test~MyInterface.$meta.__add(MyInterface, string)",
                    },
                },
                ["test~MyInterface.$meta.__add(MyInterface, MyInterface)"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my __add metamethod",
                    visibility = "record",
                    parent = "test~MyInterface.$meta.__add",
                    path = "test~MyInterface.$meta.__add(MyInterface, MyInterface)",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    },
                    params = {
                        { type = "MyInterface" },
                        { type = "MyInterface" }
                    },
                    returns = {
                        { type = "MyInterface" }
                    }
                },
                ["test~MyInterface.$meta.__add(MyInterface, string)"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my overloaded __add metamethod",
                    visibility = "record",
                    parent = "test~MyInterface.$meta.__add",
                    path = "test~MyInterface.$meta.__add(MyInterface, string)",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 23,
                    },
                    params = {
                        { type = "MyInterface" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "MyInterface" }
                    }
                }
            })
        end)
    end)
    describe("nested types", function()
        it("should parse a interface with a nested interface", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my nested interface
                    interface NestedInterface
                    end
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.NestedInterface"
                    },
                },
                ["test~MyInterface.NestedInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "NestedInterface",
                    name = "NestedInterface",
                    text = "my nested interface",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.NestedInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                }
            })
        end)
        it("should parse a interface with a nested interface with generics", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my nested interface
                    interface NestedInterface<T>
                    end
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.NestedInterface"
                    },
                },
                ["test~MyInterface.NestedInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "NestedInterface<T>",
                    name = "NestedInterface",
                    text = "my nested interface",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.NestedInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    typeargs = { { name = "T" } }
                }
            })
        end)
        it("should parse a interface with a nested interface with a constrained generic", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my nested interface
                    interface NestedInterface<T is math.Numeric>
                    end
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.NestedInterface"
                    },
                },
                ["test~MyInterface.NestedInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "NestedInterface<T is math.Numeric>",
                    name = "NestedInterface",
                    text = "my nested interface",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.NestedInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    typeargs = { { name = "T", constraint = "math.Numeric" } }
                }
            })
        end)
        it("should parse a interface with a nested interface with a nested interface", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my nested interface
                    interface NestedInterface
                        --- my deeply nested interface
                        interface DeeplyNestedInterface
                        end
                    end
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.NestedInterface"
                    },
                },
                ["test~MyInterface.NestedInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "NestedInterface",
                    name = "NestedInterface",
                    text = "my nested interface",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.NestedInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    children = {
                        "test~MyInterface.NestedInterface.DeeplyNestedInterface"
                    },
                },
                ["test~MyInterface.NestedInterface.DeeplyNestedInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "DeeplyNestedInterface",
                    name = "DeeplyNestedInterface",
                    text = "my deeply nested interface",
                    visibility = "record",
                    parent = "test~MyInterface.NestedInterface",
                    path = "test~MyInterface.NestedInterface.DeeplyNestedInterface",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 9,
                    }
                }
            })
        end)
        it("should parse a interface with a nested enum", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my nested enum
                    enum NestedEnum
                        "A"
                        "B"
                    end
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.NestedEnum"
                    },
                },
                ["test~MyInterface.NestedEnum"] = {
                    kind = "type",
                    type_kind = "enum",
                    typename = "NestedEnum",
                    name = "NestedEnum",
                    text = "my nested enum",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.NestedEnum",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    children = {
                        "test~MyInterface.NestedEnum.\"A\"",
                        "test~MyInterface.NestedEnum.\"B\""
                    }
                },
                ["test~MyInterface.NestedEnum.\"A\""] = {
                    kind = "enumvalue",
                    name = "\"A\"",
                    parent = "test~MyInterface.NestedEnum",
                    path = "test~MyInterface.NestedEnum.\"A\"",
                    
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                },
                ["test~MyInterface.NestedEnum.\"B\""] = {
                    kind = "enumvalue",
                    name = "\"B\"",
                    parent = "test~MyInterface.NestedEnum",
                    path = "test~MyInterface.NestedEnum.\"B\"",
                    
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                }
            })
        end)
        it("should parse a interface with a nested type alias", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface
                    --- my nested type alias
                    type NestedType = string
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.NestedType"
                    },
                },
                ["test~MyInterface.NestedType"] = {
                    kind = "type",
                    type_kind = "type",
                    typename = "string",
                    name = "NestedType",
                    text = "my nested type alias",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.NestedType",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    }
                }
            })
        end)
    end)
    describe("inheritance", function()
        it("should parse a interface that inherits from interface", function()
            util.check_registry([[
                local interface A
                end
                local interface MyInterface is A
                end
            ]], {
                ["test~A"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "A",
                    name = "A",
                    visibility = "local",
                    parent = "$test",
                    path = "test~A",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    }
                },
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 3,
                        x = 1,
                    },
                    inherits = { "A" }
                }
            })
        end)
        it("should handle fields from interface", function()
            util.check_registry([[
                local interface A
                    myField: string
                end
                local interface MyInterface is A
                end
            ]], {
                ["test~A"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "A",
                    name = "A",
                    visibility = "local",
                    parent = "$test",
                    path = "test~A",
                    children = {
                        "test~A.myField"
                    },
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    }
                },
                ["test~A.myField"] = {
                    kind = "variable",
                    typename = "string",
                    name = "myField",
                    visibility = "record",
                    parent = "test~A",
                    path = "test~A.myField",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 14,
                    }
                },
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "A" }
                },
            })
        end)
        it("should handle metamethods from interface", function()
            util.check_registry([[
                local interface A
                    metamethod __add: function(a: A, b: A): A
                end
                local interface MyInterface is A
                end
            ]], {
                ["test~A"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "A",
                    name = "A",
                    visibility = "local",
                    parent = "$test",
                    path = "test~A",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~A.$meta"
                    }
                },
                ["test~A.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~A",
                    path = "test~A.$meta",
                    children = {
                        "test~A.$meta.__add"
                    }
                },
                ["test~A.$meta.__add"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    
                    visibility = "record",
                    parent = "test~A.$meta",
                    path = "test~A.$meta.__add",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 23,
                    },
                    params = {
                        { type = "A" },
                        { type = "A" }
                    },
                    returns = {
                        { type = "A" }
                    }
                },
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "A" }
                }
            })
        end)
        it("should handle duplicate interfaces", function()
            util.check_registry([[
                local interface A
                end
                local interface B is A
                end
                local interface C is A
                end
                local interface MyInterface is B, C
                end
            ]], {
                ["test~A"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "A",
                    name = "A",
                    visibility = "local",
                    parent = "$test",
                    path = "test~A",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    }
                },
                ["test~B"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "B",
                    name = "B",
                    visibility = "local",
                    parent = "$test",
                    path = "test~B",
                    location = {
                        filename = "test.tl",
                        y = 3,
                        x = 1,
                    },
                    inherits = { "A" }
                },
                ["test~C"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "C",
                    name = "C",
                    visibility = "local",
                    parent = "$test",
                    path = "test~C",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    inherits = { "A" }
                },
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 1,
                    },
                    inherits = { "B", "A", "C" }
                }
            })
        end)
        it("should handle inheritance from array", function()
            util.check_registry([[
                --- my interface
                local interface MyInterface is { MyInterface }
                end
            ]], {
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    text = "my interface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 1,
                    },
                    inherits = { "{MyInterface}" }
                }
            })
        end)
        it("should handle shadowed fields from interfaces", function()
            util.check_registry([[
                local interface A
                    myField: string
                end
                local interface MyInterface is A
                    myField: string
                end
            ]], {
                ["test~A"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "A",
                    name = "A",
                    visibility = "local",
                    parent = "$test",
                    path = "test~A",
                    children = {
                        "test~A.myField"
                    },
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    }
                },
                ["test~A.myField"] = {
                    kind = "variable",
                    typename = "string",
                    name = "myField",
                    visibility = "record",
                    parent = "test~A",
                    path = "test~A.myField",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 14,
                    }
                },
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "A" },
                }
            })
        end)
        it("should handle commented shadowed fields from interfaces", function()
            util.check_registry([[
                local interface A
                    myField: string
                end
                local interface MyInterface is A
                    --- my shadowed field
                    myField: string
                end
            ]], {
                ["test~A"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "A",
                    name = "A",
                    visibility = "local",
                    parent = "$test",
                    path = "test~A",
                    children = {
                        "test~A.myField"
                    },
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    }
                },
                ["test~A.myField"] = {
                    kind = "variable",
                    typename = "string",
                    name = "myField",
                    visibility = "record",
                    parent = "test~A",
                    path = "test~A.myField",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 14,
                    }
                },
                ["test~MyInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "MyInterface",
                    name = "MyInterface",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyInterface",
                    children = {
                        "test~MyInterface.myField"
                    },
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "A" },
                },
                ["test~MyInterface.myField"] = {
                    kind = "variable",
                    typename = "string",
                    name = "myField",
                    text = "my shadowed field",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.myField",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 14,
                    }
                }
            })
        end)
        -- TODO: check for conflicts with shadowed fields
    end)
end)