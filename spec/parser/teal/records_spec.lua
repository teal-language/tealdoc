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
                    function_kind = "function",
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
                    function_kind = "function",
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
                    function_kind = "function",
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
                    function_kind = "function",
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
                    function_kind = "function",
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
                    function_kind = "function",
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
                    function_kind = "function",
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
    describe("metamethods", function()
        it("should parse metamethods", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my __add metamethod
                    metamethod __add: function(a: MyRecord, b: MyRecord): MyRecord
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
                        "test~MyRecord.$meta",
                    },
                },
                ["test~MyRecord.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.$meta",
                    children = {
                        "test~MyRecord.$meta.__add",
                    },
                },
                ["test~MyRecord.$meta.__add"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my __add metamethod",
                    visibility = "record",
                    parent = "test~MyRecord.$meta",
                    path = "test~MyRecord.$meta.__add",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "MyRecord" }
                    },
                    returns = {
                        { type = "MyRecord" }
                    }
                }
            })
        end)
        it("normal functions and metamethods should not conflict", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my __add metamethod
                    metamethod __add: function(a: MyRecord, b: MyRecord): MyRecord

                    --- my normal function
                    __add: function(a: MyRecord): MyRecord
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
                        "test~MyRecord.__add",
                        "test~MyRecord.$meta"
                    },
                },
                ["test~MyRecord.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.$meta",
                    children = {
                        "test~MyRecord.$meta.__add"
                    },
                },
                ["test~MyRecord.$meta.__add"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my __add metamethod",
                    visibility = "record",
                    parent = "test~MyRecord.$meta",
                    path = "test~MyRecord.$meta.__add",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "MyRecord" }
                    },
                    returns = {
                        { type = "MyRecord" }
                    }
                },
                ["test~MyRecord.__add"] = {
                    kind = "function",
                    function_kind = "function",
                    is_declaration = true,
                    name = "__add",
                    text = "my normal function",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.__add",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 12,
                    },
                    params = {
                        { type = "MyRecord" }
                    },
                    returns = {
                        { type = "MyRecord" }
                    }
                }
            })
        end)
        it("should parse overloaded metamethods", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my __add metamethod
                    metamethod __add: function(a: MyRecord, b: MyRecord): MyRecord

                    --- my overloaded __add metamethod
                    metamethod __add: function(a: MyRecord, b: string): MyRecord
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
                        "test~MyRecord.$meta",
                    },
                },
                ["test~MyRecord.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.$meta",
                    children = {
                        "test~MyRecord.$meta.__add",
                    },
                },
                ["test~MyRecord.$meta.__add"] = {
                    kind = "overload",
                    name = "__add",
                    parent = "test~MyRecord.$meta",
                    path = "test~MyRecord.$meta.__add",
                    children = {
                        "test~MyRecord.$meta.__add(MyRecord, MyRecord)",
                        "test~MyRecord.$meta.__add(MyRecord, string)",
                    },
                },
                ["test~MyRecord.$meta.__add(MyRecord, MyRecord)"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my __add metamethod",
                    visibility = "record",
                    parent = "test~MyRecord.$meta.__add",
                    path = "test~MyRecord.$meta.__add(MyRecord, MyRecord)",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 23,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "MyRecord" }
                    },
                    returns = {
                        { type = "MyRecord" }
                    }
                },
                ["test~MyRecord.$meta.__add(MyRecord, string)"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    text = "my overloaded __add metamethod",
                    visibility = "record",
                    parent = "test~MyRecord.$meta.__add",
                    path = "test~MyRecord.$meta.__add(MyRecord, string)",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 23,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "MyRecord" }
                    }
                }
            })
        end)
    end)
    describe("nested types", function()
        it("should parse a record with a nested record", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested record
                    record NestedRecord
                    end
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
                        "test~MyRecord.NestedRecord"
                    },
                },
                ["test~MyRecord.NestedRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "NestedRecord",
                    name = "NestedRecord",
                    text = "my nested record",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedRecord",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                }
            })
        end)
        it("should parse a record with a nested record with generics", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested record
                    record NestedRecord<T>
                    end
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
                        "test~MyRecord.NestedRecord"
                    },
                },
                ["test~MyRecord.NestedRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "NestedRecord<T>",
                    name = "NestedRecord",
                    text = "my nested record",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedRecord",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    typeargs = { { name = "T" } }
                }
            })
        end)
        it("should parse a record with a nested record with a constrained generic", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested record
                    record NestedRecord<T is math.Numeric>
                    end
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
                        "test~MyRecord.NestedRecord"
                    },
                },
                ["test~MyRecord.NestedRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "NestedRecord<T is math.Numeric>",
                    name = "NestedRecord",
                    text = "my nested record",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedRecord",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    typeargs = { { name = "T", constraint = "math.Numeric" } }
                }
            })
        end)
        it("should parse a record with a nested record with a nested record", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested record
                    record NestedRecord
                        --- my deeply nested record
                        record DeeplyNestedRecord
                        end
                    end
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
                        "test~MyRecord.NestedRecord"
                    },
                },
                ["test~MyRecord.NestedRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "NestedRecord",
                    name = "NestedRecord",
                    text = "my nested record",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedRecord",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    children = {
                        "test~MyRecord.NestedRecord.DeeplyNestedRecord"
                    },
                },
                ["test~MyRecord.NestedRecord.DeeplyNestedRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "DeeplyNestedRecord",
                    name = "DeeplyNestedRecord",
                    text = "my deeply nested record",
                    visibility = "record",
                    parent = "test~MyRecord.NestedRecord",
                    path = "test~MyRecord.NestedRecord.DeeplyNestedRecord",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 9,
                    }
                }
            })
        end)
        it("should parse a record with a nested interface", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested interface
                    interface NestedInterface
                    end
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
                        "test~MyRecord.NestedInterface"
                    },
                },
                ["test~MyRecord.NestedInterface"] = {
                    kind = "type",
                    type_kind = "interface",
                    typename = "NestedInterface",
                    name = "NestedInterface",
                    text = "my nested interface",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedInterface",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                }
            })
        end)
        it("should parse a record with a nested enum", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested enum
                    enum NestedEnum
                        "A"
                        "B"
                    end
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
                        "test~MyRecord.NestedEnum"
                    },
                },
                ["test~MyRecord.NestedEnum"] = {
                    kind = "type",
                    type_kind = "enum",
                    typename = "NestedEnum",
                    name = "NestedEnum",
                    text = "my nested enum",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedEnum",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    },
                    children = {
                        "test~MyRecord.NestedEnum.\"A\"",
                        "test~MyRecord.NestedEnum.\"B\""
                    }
                },
                ["test~MyRecord.NestedEnum.\"A\""] = {
                    kind = "enumvalue",
                    name = "\"A\"",
                    parent = "test~MyRecord.NestedEnum",
                    path = "test~MyRecord.NestedEnum.\"A\"",
                    
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                },
                ["test~MyRecord.NestedEnum.\"B\""] = {
                    kind = "enumvalue",
                    name = "\"B\"",
                    parent = "test~MyRecord.NestedEnum",
                    path = "test~MyRecord.NestedEnum.\"B\"",
                    
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 5,
                    }
                }
            })
        end)
        it("should parse a record with a nested type alias", function()
            util.check_registry([[
                --- my record
                local record MyRecord
                    --- my nested type alias
                    type NestedType = string
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
                        "test~MyRecord.NestedType"
                    },
                },
                ["test~MyRecord.NestedType"] = {
                    kind = "type",
                    type_kind = "type",
                    typename = "string",
                    name = "NestedType",
                    text = "my nested type alias",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.NestedType",
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
        it("should parse a record that inherits from interface", function()
            util.check_registry([[
                local interface MyInterface
                end
                local record MyRecord is MyInterface
                end
            ]], {
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
                        y = 1,
                        x = 1,
                    }
                },
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 3,
                        x = 1,
                    },
                    inherits = { "MyInterface" }
                }
            })
        end)
        it("should handle fields from interface", function()
            util.check_registry([[
                local interface MyInterface
                    myField: string
                end
                local record MyRecord is MyInterface
                end
            ]], {
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
                        y = 1,
                        x = 1,
                    }
                },
                ["test~MyInterface.myField"] = {
                    kind = "variable",
                    typename = "string",
                    name = "myField",
                    visibility = "record",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.myField",
                    location = {
                        filename = "test.tl",
                        y = 2,
                        x = 14,
                    }
                },
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "MyInterface" }
                },
            })
        end)
        it("should handle metamethods from interface", function()
            util.check_registry([[
                local interface MyInterface
                    metamethod __add: function(a: MyInterface, b: MyInterface): MyInterface
                end
                local record MyRecord is MyInterface
                end
            ]], {
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
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyInterface.$meta"
                    }
                },
                ["test~MyInterface.$meta"] = {
                    kind = "metafields",
                    name = "$meta",
                    parent = "test~MyInterface",
                    path = "test~MyInterface.$meta",
                    children = {
                        "test~MyInterface.$meta.__add"
                    }
                },
                ["test~MyInterface.$meta.__add"] = {
                    kind = "function",
                    function_kind = "metamethod",
                    is_declaration = true,
                    name = "__add",
                    
                    visibility = "record",
                    parent = "test~MyInterface.$meta",
                    path = "test~MyInterface.$meta.__add",
                    location = {
                        filename = "test.tl",
                        y = 2,
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
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "MyInterface" }
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
                local record MyRecord is B, C
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
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
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
                --- my record
                local record MyRecord is { MyRecord }
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
                    inherits = { "{MyRecord}" }
                }
            })
        end)
        it("should handle shadowed fields from interfaces", function()
            util.check_registry([[
                local interface A
                    myField: string
                end
                local record MyRecord is A
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
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
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
                local record MyRecord is A
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
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    parent = "$test",
                    path = "test~MyRecord",
                    children = {
                        "test~MyRecord.myField"
                    },
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    inherits = { "A" },
                },
                ["test~MyRecord.myField"] = {
                    kind = "variable",
                    typename = "string",
                    name = "myField",
                    text = "my shadowed field",
                    visibility = "record",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.myField",
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