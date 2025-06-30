local util = require("spec.util")

describe("teal support in tealdoc", function()
    it("module detection", function()
        local registry = util.registry_for_text([[
            --- @module test

            local x = 42
        ]])
        assert.is_not_nil(registry)
        assert.is_not_nil(registry["$test"])
        assert.is_same("test", registry["$test"].module_name)
    end)
    describe("variable declarations", function()
        it("local", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my variable
                local x: integer = 42
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~x"])
            assert.is_same("integer", registry["test~x"].typename)
            assert.is_same("x", registry["test~x"].name)
            assert.is_same("my variable", registry["test~x"].text)
            assert.is_same("local", registry["test~x"].type)
            assert.is_same("$test", registry["test~x"].parent)
            assert.is_same("test~x", registry["$test"].children[1])
        end)
        it("local with inferred type", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my variable
                local x = 42
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~x"])
            assert.is_same("integer", registry["test~x"].typename)
            assert.is_same("x", registry["test~x"].name)
            assert.is_same("my variable", registry["test~x"].text)
            assert.is_same("local", registry["test~x"].type)
            assert.is_same("$test", registry["test~x"].parent)
            assert.is_same("test~x", registry["$test"].children[1])
        end)
        it("global", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my variable
                global x: integer = 42
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~x"])
            assert.is_same("integer", registry["test~x"].typename)
            assert.is_same("x", registry["test~x"].name)
            assert.is_same("my variable", registry["test~x"].text)
            assert.is_same("global", registry["test~x"].type)
            assert.is_same("$test", registry["test~x"].parent)
            assert.is_same("test~x", registry["$test"].children[1])
        end)
        it("global with inferred type", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my variable
                global x = 42
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~x"])
            assert.is_same("integer", registry["test~x"].typename)
            assert.is_same("x", registry["test~x"].name)
            assert.is_same("my variable", registry["test~x"].text)
            assert.is_same("global", registry["test~x"].type)
            assert.is_same("$test", registry["test~x"].parent)
            assert.is_same("test~x", registry["$test"].children[1])
        end)
        it("multiple in a single declaration", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my variables
                local x, y = 42, 43
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~x"])
            assert.is_same("integer", registry["test~x"].typename)
            assert.is_same("x", registry["test~x"].name)
            assert.is_same("my variables", registry["test~x"].text)
            assert.is_same("local", registry["test~x"].type)

            assert.is_not_nil(registry["test~y"])
            assert.is_same("integer", registry["test~y"].typename)
            assert.is_same("y", registry["test~y"].name)
            assert.is_same("my variables", registry["test~y"].text)
            assert.is_same("local", registry["test~x"].type)
            assert.is_same("$test", registry["test~x"].parent)
            assert.is_same("$test", registry["test~y"].parent)
            assert.is_same(registry["$test"].children, {"test~x", "test~y"})
        end)
    end)

    describe("type decalartions", function()
        it("local", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my type
                local type MyType = integer
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyType"])
            assert.is_same("MyType", registry["test~MyType"].name)
            assert.is_same("integer", registry["test~MyType"].typename)
            assert.is_same("my type", registry["test~MyType"].text)
            assert.is_same("local", registry["test~MyType"].type)
            assert.is_same("$test", registry["test~MyType"].parent)
            assert.is_same("test~MyType", registry["$test"].children[1])
        end)
        it("global", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my type
                global type MyType = integer
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyType"])
            assert.is_same("MyType", registry["test~MyType"].name)
            assert.is_same("integer", registry["test~MyType"].typename)
            assert.is_same("my type", registry["test~MyType"].text)
            assert.is_same("global", registry["test~MyType"].type)
            assert.is_same("$test", registry["test~MyType"].parent)
            assert.is_same("test~MyType", registry["$test"].children[1])
        end)
    end)
    -- TODO: test errors
    describe("functions", function()
        it("local", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                local function my_function()
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("local", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])
        end)
        it("local with params and returns", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                --- @param x first number
                --- @param y second number
                --- @return sum of x and y
                --- @return product of x and y
                local function my_function(x: integer, y: integer): integer, integer
                    return x + y, x * y
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("local", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])

            assert.is_same({
                { name = "x", type = "integer", description = "first number" },
                { name = "y", type = "integer", description = "second number" }
            }, registry["test~my_function"].params)

            assert.is_same({
                { type = "integer", description = "sum of x and y" },
                { type = "integer", description = "product of x and y" }
            }, registry["test~my_function"].returns)
        end)

        it("local with generics", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                --- @typearg T my generic
                --- @param x my param
                --- @return my return
                local function my_function<T>(x: T): T
                    return x
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("local", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])

            assert.is_same({
                { name = "x", type = "T", description = "my param" }
            }, registry["test~my_function"].params)

            assert.is_same({
                { type = "T", description = "my return" }
            }, registry["test~my_function"].returns)
            
            assert.is_same({
                { name = "T", description = "my generic" }
            }, registry["test~my_function"].typeargs)
        end)

        it("local with constrained generic", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                --- @typearg T my generic
                --- @param x my param
                --- @return my return
                local function my_function<T is math.Numeric>(x: T): T
                    return x
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("local", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])

            assert.is_same({
                { name = "x", type = "T", description = "my param" }
            }, registry["test~my_function"].params)

            assert.is_same({
                { type = "T", description = "my return" }
            }, registry["test~my_function"].returns)

            assert.is_same({
                { name = "T", constraint = "math.Numeric", description = "my generic" }
            }, registry["test~my_function"].typeargs)
        end)

        it("global", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                global function my_function()
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("global", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])
        end)
        it("global with params and returns", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                --- @param x first number
                --- @param y second number
                --- @return sum of x and y
                --- @return product of x and y
                global function my_function(x: integer, y: integer): integer, integer
                    return x + y, x * y
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("global", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])

            assert.is_same({
                { name = "x", type = "integer", description = "first number" },
                { name = "y", type = "integer", description = "second number" }
            }, registry["test~my_function"].params)

            assert.is_same({
                { type = "integer", description = "sum of x and y" },
                { type = "integer", description = "product of x and y" }
            }, registry["test~my_function"].returns)
        end)

        it("global with generics", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                --- @typearg T my generic
                --- @param x my param
                --- @return my return
                global function my_function<T>(x: T): T
                    return x
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("global", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])

            assert.is_same({
                { name = "x", type = "T", description = "my param" }
            }, registry["test~my_function"].params)

            assert.is_same({
                { type = "T", description = "my return" }
            }, registry["test~my_function"].returns)
            
            assert.is_same({
                { name = "T", description = "my generic" }
            }, registry["test~my_function"].typeargs)
        end)

        it("global with constrained generic", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my function
                --- @typearg T my generic
                --- @param x my param
                --- @return my return
                global function my_function<T is math.Numeric>(x: T): T
                    return x
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~my_function"])
            assert.is_same("my function", registry["test~my_function"].text)
            assert.is_same("global", registry["test~my_function"].type)
            assert.is_same("$test", registry["test~my_function"].parent)
            assert.is_same("test~my_function", registry["$test"].children[1])

            assert.is_same({
                { name = "x", type = "T", description = "my param" }
            }, registry["test~my_function"].params)

            assert.is_same({
                { type = "T", description = "my return" }
            }, registry["test~my_function"].returns)

            assert.is_same({
                { name = "T", constraint = "math.Numeric", description = "my generic" }
            }, registry["test~my_function"].typeargs)
        end)
    end)

    describe("enums", function()
        it("local", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my enum
                local enum MyEnum
                    "A"
                    "B"
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyEnum"])
            assert.is_same("MyEnum", registry["test~MyEnum"].name)
            assert.is_same("my enum", registry["test~MyEnum"].text)
            assert.is_same("local", registry["test~MyEnum"].type)
            assert.is_same("$test", registry["test~MyEnum"].parent)
            assert.is_same("test~MyEnum", registry["$test"].children[1])
        end)
        it("local with commented values", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my enum
                local enum MyEnum
                    --- A value
                    "A"
                    --- B value
                    "B"
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyEnum"])
            assert.is_same("MyEnum", registry["test~MyEnum"].name)
            assert.is_same("my enum", registry["test~MyEnum"].text)
            assert.is_same("local", registry["test~MyEnum"].type)
            assert.is_same("$test", registry["test~MyEnum"].parent)
            assert.is_same("test~MyEnum", registry["$test"].children[1])
            assert.is_same({"test~MyEnum.A", "test~MyEnum.B"}, registry["test~MyEnum"].children)
            assert.is_not_nil(registry["test~MyEnum.A"])
            assert.is_same("A", registry["test~MyEnum.A"].name)
            assert.is_same("A value", registry["test~MyEnum.A"].text)
            assert.is_same("test~MyEnum", registry["test~MyEnum.A"].parent)
            assert.is_not_nil(registry["test~MyEnum.B"])
            assert.is_same("B", registry["test~MyEnum.B"].name)
            assert.is_same("B value", registry["test~MyEnum.B"].text) 
            assert.is_same("test~MyEnum", registry["test~MyEnum.B"].parent)
        end)

        it("global", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my enum
                global enum MyEnum
                    "A"
                    "B"
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyEnum"])
            assert.is_same("MyEnum", registry["test~MyEnum"].name)
            assert.is_same("my enum", registry["test~MyEnum"].text)
            assert.is_same("global", registry["test~MyEnum"].type)
            assert.is_same("$test", registry["test~MyEnum"].parent)
            assert.is_same("test~MyEnum", registry["$test"].children[1])
        end)
        it("global with commented values", function()
            local registry = util.registry_for_text([[
                --- @module test

                --- my enum
                global enum MyEnum
                    --- A value
                    "A"
                    --- B value
                    "B"
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyEnum"])
            assert.is_same("MyEnum", registry["test~MyEnum"].name)
            assert.is_same("my enum", registry["test~MyEnum"].text)
            assert.is_same("global", registry["test~MyEnum"].type)
            assert.is_same("$test", registry["test~MyEnum"].parent)
            assert.is_same("test~MyEnum", registry["$test"].children[1])
            assert.is_same({"test~MyEnum.A", "test~MyEnum.B"}, registry["test~MyEnum"].children)
            assert.is_not_nil(registry["test~MyEnum.A"])
            assert.is_same("A", registry["test~MyEnum.A"].name)
            assert.is_same("A value", registry["test~MyEnum.A"].text)
            assert.is_same("test~MyEnum", registry["test~MyEnum.A"].parent)
            assert.is_not_nil(registry["test~MyEnum.B"])
            assert.is_same("B", registry["test~MyEnum.B"].name)
            assert.is_same("B value", registry["test~MyEnum.B"].text) 
            assert.is_same("test~MyEnum", registry["test~MyEnum.B"].parent)
        end)
    end)

    describe("records", function()
        describe("declarations", function()
            it("local", function()
                local registry = util.registry_for_text([[
                    --- @module test

                    --- my record
                    local record MyRecord
                    end
                ]])
                assert.is_not_nil(registry)
                assert.is_not_nil(registry["test~MyRecord"])
                assert.is_same("MyRecord", registry["test~MyRecord"].name)
                assert.is_same("my record", registry["test~MyRecord"].text)
                assert.is_same("local", registry["test~MyRecord"].type)
                assert.is_same("$test", registry["test~MyRecord"].parent)
                assert.is_same("test~MyRecord", registry["$test"].children[1])
            end)
            it("global", function()
                local registry = util.registry_for_text([[
                    --- @module test

                    --- my record
                    global record MyRecord
                    end
                ]])
                assert.is_not_nil(registry)
                assert.is_not_nil(registry["test~MyRecord"])
                assert.is_same("MyRecord", registry["test~MyRecord"].name)
                assert.is_same("my record", registry["test~MyRecord"].text)
                assert.is_same("global", registry["test~MyRecord"].type)
                assert.is_same("$test", registry["test~MyRecord"].parent)
                assert.is_same("test~MyRecord", registry["$test"].children[1])
            end)
            it("local with generics", function()
                local registry = util.registry_for_text([[
                    --- @module test

                    --- my record
                    --- @typearg T my generic
                    local record MyRecord<T>
                    end
                ]])
                assert.is_not_nil(registry)
                assert.is_not_nil(registry["test~MyRecord"])
                assert.is_same("MyRecord", registry["test~MyRecord"].name)
                assert.is_same("my record", registry["test~MyRecord"].text)
                assert.is_same("local", registry["test~MyRecord"].type)
                assert.is_same("$test", registry["test~MyRecord"].parent)
                assert.is_same("test~MyRecord", registry["$test"].children[1])
                assert.is_same({ { name = "T", description = "my generic" } }, registry["test~MyRecord"].typeargs)
            end)
            it("global with generics", function()
                local registry = util.registry_for_text([[
                    --- @module test

                    --- my record
                    --- @typearg T my generic
                    global record MyRecord<T>
                    end
                ]])
                assert.is_not_nil(registry)
                assert.is_not_nil(registry["test~MyRecord"])
                assert.is_same("MyRecord", registry["test~MyRecord"].name)
                assert.is_same("my record", registry["test~MyRecord"].text)
                assert.is_same("global", registry["test~MyRecord"].type)
                assert.is_same("$test", registry["test~MyRecord"].parent)
                assert.is_same("test~MyRecord", registry["$test"].children[1])
                assert.is_same({ { name = "T", description = "my generic" } }, registry["test~MyRecord"].typeargs)
            end)
            it("local with constrained generic", function()
                local registry = util.registry_for_text([[
                    --- @module test

                    --- my record
                    --- @typearg T my generic
                    local record MyRecord<T is math.Numeric>
                    end
                ]])
                assert.is_not_nil(registry)
                assert.is_not_nil(registry["test~MyRecord"])
                assert.is_same("MyRecord", registry["test~MyRecord"].name)
                assert.is_same("my record", registry["test~MyRecord"].text)
                assert.is_same("local", registry["test~MyRecord"].type)
                assert.is_same("$test", registry["test~MyRecord"].parent)
                assert.is_same("test~MyRecord", registry["$test"].children[1])
                assert.is_same({ { name = "T", constraint = "math.Numeric", description = "my generic" } }, registry["test~MyRecord"].typeargs)
            end)
            it("global with constrained generic", function()
                local registry = util.registry_for_text([[
                    --- @module test

                    --- my record
                    --- @typearg T my generic
                    global record MyRecord<T is math.Numeric>
                    end
                ]])
                assert.is_not_nil(registry)
                assert.is_not_nil(registry["test~MyRecord"])
                assert.is_same("MyRecord", registry["test~MyRecord"].name)
                assert.is_same("my record", registry["test~MyRecord"].text)
                assert.is_same("global", registry["test~MyRecord"].type)
                assert.is_same("$test", registry["test~MyRecord"].parent)
                assert.is_same("test~MyRecord", registry["$test"].children[1])
                assert.is_same({ { name = "T", constraint = "math.Numeric", description = "my generic" } }, registry["test~MyRecord"].typeargs)
            end)
        end)
        it("fields", function()
            local registry = util.registry_for_text([[
                --- @module test

                local record MyRecord
                    --- my field
                    a: integer
                    --- my other field
                    b: string
                end
            ]])
            assert.is_not_nil(registry)
            assert.is_not_nil(registry["test~MyRecord"])
            assert.is_same("MyRecord", registry["test~MyRecord"].name)
            assert.is_same("local", registry["test~MyRecord"].type)
            assert.is_same("$test", registry["test~MyRecord"].parent)
            assert.is_same("test~MyRecord", registry["$test"].children[1])
            assert.is_not_nil(registry["test~MyRecord.my_field"])
            assert.is_same("a", registry["test~MyRecord.a"].name)
            assert.is_same("integer", registry["test~MyRecord.a"].typename)
            assert.is_same("my field", registry["test~MyRecord.a"].text)
            
            assert.is_same("b", registry["test~MyRecord.b"].name)
            assert.is_same("string", registry["test~MyRecord.b"].typename)
            assert.is_same("my other field", registry["test~MyRecord.b"].text)

            assert.is_same({"test~MyRecord.a", "test~MyRecord.b"}, registry["test~MyRecord"].children)
        end)
        -- TODO test errors!
        describe("functions", function()
            describe("in records", function()
                it("without params and returns", function()
                    local registry = util.registry_for_text([[
                        --- @module test

                        local record MyRecord
                            --- my function
                            my_function: function()
                        end
                    ]])
                    assert.is_not_nil(registry)
                    assert.is_not_nil(registry["test~MyRecord"])
                    assert.is_not_nil(registry["test~MyRecord.my_function"])
                    assert.is_same("my function", registry["test~MyRecord.my_function"].text)
                    assert.is_same({"test~MyRecord.my_function"}, registry["test~MyRecord"].children)
                    assert.is_same("test~MyRecord", registry["test~MyRecord.my_function"].parent)
                    assert.is_same("record", registry["test~MyRecord.my_function"].type)
                end)
                it("with params and returns", function()
                    local registry = util.registry_for_text([[
                        --- @module test

                        local record MyRecord
                            --- my function
                            --- @param x first number
                            --- @param y second number
                            --- @return sum of x and y
                            --- @return product of x and y
                            my_function: function(integer, integer): integer, integer
                        end
                    ]])
                    assert.is_not_nil(registry)
                    assert.is_not_nil(registry["test~MyRecord"])
                    assert.is_not_nil(registry["test~MyRecord.my_function"])
                    assert.is_same("my function", registry["test~MyRecord.my_function"].text)
                    assert.is_same({"test~MyRecord.my_function"}, registry["test~MyRecord"].children)
                    assert.is_same("test~MyRecord", registry["test~MyRecord.my_function"].parent)
                    assert.is_same("record", registry["test~MyRecord.my_function"].type)

                    assert.is_same({
                        { name = "x", type = "integer", description = "first number" },
                        { name = "y", type = "integer", description = "second number" }
                    }, registry["test~MyRecord.my_function"].params)

                    assert.is_same({
                        { type = "integer", description = "sum of x and y" },
                        { type = "integer", description = "product of x and y" }
                    }, registry["test~MyRecord.my_function"].returns)
                end)
                it("with generics", function()
                    local registry = util.registry_for_text([[
                        --- @module test

                        local record MyRecord
                            --- my function
                            --- @typearg T my generic
                            --- @param x my param
                            --- @return my return
                            my_function: function<T>(x: T): T
                        end
                    ]])
                    assert.is_not_nil(registry)
                    assert.is_not_nil(registry["test~MyRecord"])
                    assert.is_not_nil(registry["test~MyRecord.my_function"])
                    assert.is_same("my function", registry["test~MyRecord.my_function"].text)
                    assert.is_same({"test~MyRecord.my_function"}, registry["test~MyRecord"].children)
                    assert.is_same("test~MyRecord", registry["test~MyRecord.my_function"].parent)
                    assert.is_same("record", registry["test~MyRecord.my_function"].type)
                    assert.is_same({
                        { name = "x", type = "T", description = "my param" }
                    }, registry["test~MyRecord.my_function"].params)
                    assert.is_same({
                        { type = "T", description = "my return" }
                    }, registry["test~MyRecord.my_function"].returns)
                    assert.is_same({
                        { name = "T", description = "my generic" }
                    }, registry["test~MyRecord.my_function"].typeargs)
                end)
                it("with constrained generics", function()
                    local registry = util.registry_for_text([[
                        --- @module test

                        local record MyRecord
                            --- my function
                            --- @typearg T my generic
                            --- @param x my param
                            --- @return my return
                            my_function: function<T is math.Numeric>(x: T): T
                        end
                    ]])
                    assert.is_not_nil(registry)
                    assert.is_not_nil(registry["test~MyRecord"])
                    assert.is_not_nil(registry["test~MyRecord.my_function"])
                    assert.is_same("my function", registry["test~MyRecord.my_function"].text)
                    assert.is_same({"test~MyRecord.my_function"}, registry["test~MyRecord"].children)
                    assert.is_same("test~MyRecord", registry["test~MyRecord.my_function"].parent)
                    assert.is_same("record", registry["test~MyRecord.my_function"].type)
                    assert.is_same({
                        { name = "x", type = "T", description = "my param" }
                    }, registry["test~MyRecord.my_function"].params)
                    assert.is_same({
                        { type = "T", description = "my return" }
                    }, registry["test~MyRecord.my_function"].returns)
                    assert.is_same({
                        { name = "T", constraint = "math.Numeric", description = "my generic" }
                    }, registry["test~MyRecord.my_function"].typeargs) 
                end)

                it("overloaded", function()
                    local registry = util.registry_for_text([[
                        --- @module test

                        local record MyRecord
                            --- my function
                            --- @param x first number
                            --- @param y second number
                            --- @return number x or y 
                            my_function: function(integer, integer): integer

                            --- my overloaded function
                            --- @param x first string
                            --- @param y second string
                            --- @return string x or y
                            my_function: function(string, string): string

                            --- my overloaded function
                            --- @param x first boolean
                            --- @param y second boolean
                            --- @return boolean x or y
                            my_function: function(boolean, boolean): boolean
                        end
                    ]])
                    assert.is_not_nil(registry)
                    assert.is_not_nil(registry["test~MyRecord"])
                    assert.is_not_nil(registry["test~MyRecord.my_function"])
                    assert.is_same({
                        "test~MyRecord.my_function(integer,integer)",
                        "test~MyRecord.my_function(string,string)",
                        "test~MyRecord.my_function(boolean,boolean)"
                    }, registry["test~MyRecord.my_function"].children)
                    assert.is_same("my function", registry["test~MyRecord.my_function(integer,integer)"].text)
                    assert.is_same("my overloaded function", registry["test~MyRecord.my_function(string,string)"].text)
                    assert.is_same("my overloaded function", registry["test~MyRecord.my_function(boolean,boolean)"].text)
                    assert.is_same("test~MyRecord.my_function", registry["test~MyRecord.my_function(integer,integer)"].parent)
                    assert.is_same("test~MyRecord.my_function", registry["test~MyRecord.my_function(string,string)"].parent)
                    assert.is_same("test~MyRecord.my_function", registry["test~MyRecord.my_function(boolean,boolean)"].parent)
                    assert.is_same("record", registry["test~MyRecord.my_function(integer,integer)"].type)
                    assert.is_same("record", registry["test~MyRecord.my_function(string,string)"].type)
                    assert.is_same("record", registry["test~MyRecord.my_function(boolean,boolean)"].type)   
                    assert.is_same({
                        { name = "x", type = "integer", description = "first number" },
                        { name = "y", type = "integer", description = "second number" }
                    }, registry["test~MyRecord.my_function(integer,integer)"].params)
                    assert.is_same({
                        { type = "integer", description = "number x or y" }
                    }, registry["test~MyRecord.my_function(integer,integer)"].returns)
                    assert.is_same({
                        { name = "x", type = "string", description = "first string" },
                        { name = "y", type = "string", description = "second string" }
                    }, registry["test~MyRecord.my_function(string,string)"].params)
                    assert.is_same({
                        { type = "string", description = "string x or y" }
                    }, registry["test~MyRecord.my_function(string,string)"].returns)
                    assert.is_same({
                        { name = "x", type = "boolean", description = "first boolean" },
                        { name = "y", type = "boolean", description = "second boolean" }    
                    }, registry["test~MyRecord.my_function(boolean,boolean)"].params)
                    assert.is_same({
                        { type = "boolean", description = "boolean x or y" }
                    }, registry["test~MyRecord.my_function(boolean,boolean)"].returns)
                end)
            end)
        end)
    end)
end)

-- TODO: tests for metamethods, record functions declared outside, inner functions, nested type declartaions and all of those declarations conflicts!