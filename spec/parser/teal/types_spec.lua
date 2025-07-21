local util = require("spec.util")

describe("teal support in tealdoc: types", function()
    -- TODO: fix types x locations
    it("should parse a local type alias", function()
        util.check_registry([[
            --- my type
            local type MyType = integer
        ]], {
            ["test~MyType"] = {
                kind = "type",
                name = "MyType",
                typename = "integer",
                text = "my type",
                visibility = "local",
                parent = "$test",
                path = "test~MyType",
                type_kind = "type",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 21,
                }
            }
        })
    end)

    it("should parse a global type alias", function()
        util.check_registry([[
            --- my type
            global type MyType = integer
        ]], {
            ["test~MyType"] = {
                kind = "type",
                name = "MyType",
                typename = "integer",
                text = "my type",
                visibility = "global",
                parent = "$test",
                path = "test~MyType",
                type_kind = "type",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 22,
                }
            }
        })
    end)

    it("should propely handle type requires", function()
        -- we currently ignore that
        util.check_registry([[
            --- my type
            local type tl_types = require("tl")
        ]], {})
    end)

    it("should parse a record type", function()
        util.check_registry([[
            --- my record
            local type MyRecord = record
            end
        ]], {
            ["test~MyRecord"] = {
                kind = "type",
                name = "MyRecord",
                typename = "MyRecord",
                text = "my record",
                visibility = "local",
                parent = "$test",
                path = "test~MyRecord",
                type_kind = "record",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 23,
                }
            }
        })
    end)
    it("should parse a interface type", function()
        util.check_registry([[
            --- my interface
            local type MyInterface = interface
            end
        ]], {
            ["test~MyInterface"] = {
                kind = "type",
                name = "MyInterface",
                typename = "MyInterface",
                text = "my interface",
                visibility = "local",
                parent = "$test",
                path = "test~MyInterface",
                type_kind = "interface",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 26,
                }
            }
        })
    end)
    it("should parse a enum type", function()
        util.check_registry([[
            --- my enum
            local type MyEnum = enum
            end
        ]], {
            ["test~MyEnum"] = {
                kind = "type",
                name = "MyEnum",
                typename = "MyEnum",
                text = "my enum",
                visibility = "local",
                parent = "$test",
                path = "test~MyEnum",
                type_kind = "enum",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 21,
                }
            }
        })
    end)
    it("should parse a record type with generic parameters", function()
        util.check_registry([[
            --- my record
            local type MyRecord = record<T>
            end
        ]], {
            ["test~MyRecord"] = {
                kind = "type",
                name = "MyRecord",
                typename = "MyRecord<T>",
                text = "my record",
                visibility = "local",
                parent = "$test",
                path = "test~MyRecord",
                type_kind = "record",
                typeargs = { {name = "T"} },
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 23,
                }
            }
        })
    end)
    it("should parse a record type with constrainted generic parameters", function()
        util.check_registry([[
            --- my record
            local type MyRecord = record<T is math.Numeric>
            end
        ]], {
            ["test~MyRecord"] = {
                kind = "type",
                name = "MyRecord",
                typename = "MyRecord<T is math.Numeric>",
                text = "my record",
                visibility = "local",
                parent = "$test",
                path = "test~MyRecord",
                type_kind = "record",
                typeargs = { {name = "T", constraint = "math.Numeric" } },
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 23,
                }
            }
        })
    end)
    it("should parse a interface type with generic parameters", function()
        util.check_registry([[
            --- my interface
            local type MyInterface = interface<T>
            end
        ]], {
            ["test~MyInterface"] = {
                kind = "type",
                name = "MyInterface",
                typename = "MyInterface<T>",
                text = "my interface",
                visibility = "local",
                parent = "$test",
                path = "test~MyInterface",
                type_kind = "interface",
                typeargs = { {name = "T"} },
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 26,
                }
            }
        })
    end)
    it("should parse a interface type with constrainted generic parameters", function()
        util.check_registry([[
            --- my interface
            local type MyInterface = interface<T is math.Numeric>
            end
        ]], {
            ["test~MyInterface"] = {
                kind = "type",
                name = "MyInterface",
                typename = "MyInterface<T is math.Numeric>",
                text = "my interface",
                visibility = "local",
                parent = "$test",
                path = "test~MyInterface",
                type_kind = "interface",
                typeargs = { {name = "T", constraint = "math.Numeric" } },
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 26,
                }
            }
        })
    end)
end)