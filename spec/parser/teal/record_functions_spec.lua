local util = require("spec.util")

describe("teal support in tealdoc: record functions", function()
    describe("functions without declarations", function()
        it("should parse a record function", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record function
                function MyRecord.my_function()
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                },
            })
        end)
        
        it("should parse a record function with parameters and returns", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record function with parameters and returns
                function MyRecord.my_function(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record function with typeargs", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record function with typeargs
                function MyRecord.my_function<T>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T" }
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
        it("should parse a record function with constrained typeargs", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record function with constrained typeargs
                function MyRecord.my_function<T is math.Numeric>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with constrained typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T", constraint = "math.Numeric" }
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
    end)
    describe("functions with declarations", function()
        it("should parse a record function", function()
            util.check_registry([[
                local record MyRecord
                    my_function: function()
                end

                --- My record function
                function MyRecord.my_function()
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                },
            })
        end)
        
        it("should parse a record function with parameters and returns", function()
            util.check_registry([[
                local record MyRecord
                    my_function: function(x: integer, y: string): number
                end

                --- My record function with parameters and returns
                function MyRecord.my_function(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record function with typeargs", function()
            util.check_registry([[
                local record MyRecord
                    my_function: function<T>(x: T): T
                end

                --- My record function with typeargs
                function MyRecord.my_function<T>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T" }
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
        it("should parse a record function with constrained typeargs", function()
            util.check_registry([[
                local record MyRecord
                    my_function: function<T is math.Numeric>(x: T): T
                end

                --- My record function with constrained typeargs
                function MyRecord.my_function<T is math.Numeric>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with constrained typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T", constraint = "math.Numeric" }
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
    end)
    describe("functions with declarations with comments", function()
        it("should parse a record function", function()
            util.check_registry([[
                local record MyRecord
                    --- My record function
                    my_function: function()
                end

                function MyRecord.my_function()
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    is_declaration = true,
                    text = "My record function",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 3,
                        x = 18,
                    },
                },
            })
        end)
        
        it("should parse a record function with parameters and returns", function()
            util.check_registry([[
                local record MyRecord
                    --- My record function with parameters and returns
                    my_function: function(x: integer, y: string): number
                end

                function MyRecord.my_function(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    is_declaration = true,
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 3,
                        x = 18,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record function with typeargs", function()
            util.check_registry([[
                local record MyRecord
                    --- My record function with typeargs
                    my_function: function<T>(x: T): T
                end
                
                function MyRecord.my_function<T>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    is_declaration = true,
                    text = "My record function with typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T" }
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
        it("should parse a record function with constrained typeargs", function()
            util.check_registry([[
                local record MyRecord
                    --- My record function with constrained typeargs
                    my_function: function<T is math.Numeric>(x: T): T
                end
                
                function MyRecord.my_function<T is math.Numeric>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    is_declaration = true,
                    text = "My record function with constrained typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T", constraint = "math.Numeric" }
                    },
                    params = {
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
    end)
    describe("methods without declarations", function()
        it("should parse a record method", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record method
                function MyRecord:my_method()
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    params = {
                        { type = "MyRecord" }
                    }
                },
            })
        end)
        it("should parse a record method with parameters and returns", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record method with parameters and returns
                function MyRecord:my_method(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record method with typeargs", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record method with typeargs
                function MyRecord:my_method<T>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T" }
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
        it("should parse a record method with constrained typeargs", function()
            util.check_registry([[
                local record MyRecord
                end

                --- My record method with constrained typeargs
                function MyRecord:my_method<T is math.Numeric>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with constrained typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T", constraint = "math.Numeric" }
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
    end)
    describe("methods with declarations", function()
        it("should parse a record method", function()
            util.check_registry([[
                local record MyRecord
                    my_method: function(self)
                end

                --- My record method
                function MyRecord:my_method()
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    params = {
                        { type = "MyRecord" }
                    },
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                },
            })
        end)
        
        it("should parse a record method with parameters and returns", function()
            util.check_registry([[
                local record MyRecord
                    my_method: function(self, x: integer, y: string): number
                end

                --- My record method with parameters and returns
                function MyRecord:my_method(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record method with typeargs", function()
            util.check_registry([[
                local record MyRecord
                    my_method: function<T>(self, x: T): T
                end

                --- My record method with typeargs
                function MyRecord:my_method<T>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T" }
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
        it("should parse a record method with constrained typeargs", function()
            util.check_registry([[
                local record MyRecord

                    my_method: function<T is math.Numeric>(self, x: T): T
                end
                --- My record method with constrained typeargs
                function MyRecord:my_method<T is math.Numeric>(x: T): T
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    parent = "$test",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with constrained typeargs",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 6,
                        x = 1,
                    },
                    typeargs = {
                        { name = "T", constraint = "math.Numeric" }
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "T" }
                    },
                    returns = {
                        { type = "T" }
                    },
                },
            })
        end)
    end)
    describe("record functions added via alias", function()
        it("should parse a record function added via alias", function()
            util.check_registry([[
                local record MyRecord
                end

                local type alias = MyRecord

                --- My record function with parameters and returns
                function alias.my_function(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~alias"] = {
                    kind = "type",
                    name = "alias",
                    visibility = "local",
                    type_kind = "type",
                    path = "test~alias",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 20,
                    },
                    typename = "MyRecord"
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 1,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record method added via alias", function()
            util.check_registry([[
                local record MyRecord
                end

                local type alias = MyRecord

                --- My record method with parameters and returns
                function alias:my_method(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~alias"] = {
                    kind = "type",
                    name = "alias",
                    visibility = "local",
                    type_kind = "type",
                    path = "test~alias",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 4,
                        x = 20,
                    },
                    typename = "MyRecord"
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 7,
                        x = 1,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record function with declaration added via alias", function()
            util.check_registry([[
                local record MyRecord
                    my_function: function(x: integer, y: string): number
                end

                local type alias = MyRecord

                --- My record function with parameters and returns
                function alias.my_function(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~alias"] = {
                    kind = "type",
                    name = "alias",
                    visibility = "local",
                    type_kind = "type",
                    path = "test~alias",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 20,
                    },
                    typename = "MyRecord"
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 8,
                        x = 1,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record method with declaration added via alias", function()
            util.check_registry([[
                local record MyRecord
                    my_method: function(self, x: integer, y: string): number
                end

                local type alias = MyRecord

                --- My record method with parameters and returns
                function alias:my_method(x: integer, y: string): number
                    return x
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~alias"] = {
                    kind = "type",
                    name = "alias",
                    visibility = "local",
                    type_kind = "type",
                    path = "test~alias",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 5,
                        x = 20,
                    },
                    typename = "MyRecord"
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 8,
                        x = 1,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
    end)

    describe("record functions added conditionally", function()
        it("should parse a record function added conditionally", function()
            util.check_registry([[
                local record MyRecord
                end

                if true then
                    function MyRecord.my_function(x: integer, y: string): number
                        return x
                    end
                else 
                    --- My record function with parameters and returns
                    function MyRecord.my_function(x: integer, y: string): number
                        return x
                    end
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 10,
                        x = 5,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record method added conditionally", function()
            util.check_registry([[
                local record MyRecord
                end

                if true then
                    function MyRecord:my_method(x: integer, y: string): number
                        return x
                    end
                else 
                    --- My record method with parameters and returns
                    function MyRecord:my_method(x: integer, y: string): number
                        return x
                    end
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 10,
                        x = 5,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record function with declaration added conditionally", function()
            util.check_registry([[
                local record MyRecord
                end

                if true then
                    function MyRecord.my_function(x: integer, y: string): number
                        return x
                    end
                else
                    --- My record function with parameters and returns
                    function MyRecord.my_function(x: integer, y: string): number
                        return x
                    end
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_function",
                    },
                },
                ["test~MyRecord.my_function"] = {
                    name = "my_function",
                    text = "My record function with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_function",
                    location = {
                        filename = "test.tl",
                        y = 10,
                        x = 5,
                    },
                    params = {
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
        it("should parse a record method with declaration added conditionally", function()
            util.check_registry([[
                local record MyRecord
                end

                if true then
                    function MyRecord:my_method(x: integer, y: string): number
                        return x
                    end
                else 
                    --- My record method with parameters and returns
                    function MyRecord:my_method(x: integer, y: string): number
                        return x
                    end
                end
            ]], {
                ["test~MyRecord"] = {
                    kind = "type",
                    type_kind = "record",
                    typename = "MyRecord",
                    name = "MyRecord",
                    visibility = "local",
                    path = "test~MyRecord",
                    parent = "$test",
                    location = {
                        filename = "test.tl",
                        y = 1,
                        x = 1,
                    },
                    children = {
                        "test~MyRecord.my_method",
                    },
                },
                ["test~MyRecord.my_method"] = {
                    name = "my_method",
                    text = "My record method with parameters and returns",
                    visibility = "record",
                    kind = "function",
                    function_kind = "normal",
                    parent = "test~MyRecord",
                    path = "test~MyRecord.my_method",
                    location = {
                        filename = "test.tl",
                        y = 10,
                        x = 5,
                    },
                    params = {
                        { type = "MyRecord" },
                        { type = "integer" },
                        { type = "string" }
                    },
                    returns = {
                        { type = "number" }
                    },
                },
            })
        end)
    end)
end)