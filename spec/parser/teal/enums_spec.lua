local util = require("spec.util")

describe("teal support in tealdoc: enums", function()
    it("should parse a local enum", function()
        util.check_registry([[
            --- my enum
            local enum MyEnum
                "A"
                "B"
            end
        ]], {
            ["$test~MyEnum"] = {
                kind = "type",
                name = "MyEnum",
                text = "my enum",
                visibility = "local",
                typename = "MyEnum",
                parent = "$test",
                path = "$test~MyEnum",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                type_kind = "enum",
                children = {
                    "$test~MyEnum.\"A\"",
                    "$test~MyEnum.\"B\""
                },
            },
            ["$test~MyEnum.\"A\""] = {
                kind = "enumvalue",
                name = "\"A\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"A\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            },
            ["$test~MyEnum.\"B\""] = {
                kind = "enumvalue",
                name = "\"B\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"B\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)

    it("should parse a local enum with commented values", function()
        util.check_registry([[
            --- my enum
            local enum MyEnum
                --- A value
                "A"
                --- B value
                "B"
            end
        ]], {
            ["$test~MyEnum"] = {
                kind = "type",
                name = "MyEnum",
                text = "my enum",
                visibility = "local",
                typename = "MyEnum",
                parent = "$test",
                path = "$test~MyEnum",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                type_kind = "enum",
                children = {
                    "$test~MyEnum.\"A\"",
                    "$test~MyEnum.\"B\""
                },
            },
            ["$test~MyEnum.\"A\""] = {
                kind = "enumvalue",
                name = "\"A\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"A\"",
                text = "A value",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            },
            ["$test~MyEnum.\"B\""] = {
                kind = "enumvalue",
                name = "\"B\"",
                parent = "$test~MyEnum",
                text = "B value",
                path = "$test~MyEnum.\"B\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)

    it("should parse a global enum", function()
        util.check_registry([[
            --- my enum
            global enum MyEnum
                "A"
                "B"
            end
        ]], {
            ["$test~MyEnum"] = {
                kind = "type",
                name = "MyEnum",
                text = "my enum",
                visibility = "global",
                typename = "MyEnum",
                parent = "$test",
                path = "$test~MyEnum",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                type_kind = "enum",
                children = {
                    "$test~MyEnum.\"A\"",
                    "$test~MyEnum.\"B\""
                },
            },
            ["$test~MyEnum.\"A\""] = {
                kind = "enumvalue",
                name = "\"A\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"A\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            },
            ["$test~MyEnum.\"B\""] = {
                kind = "enumvalue",
                name = "\"B\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"B\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)

    it("should parse a global enum with commented values", function()
        util.check_registry([[
            --- my enum
            global enum MyEnum
                --- A value
                "A"
                --- B value
                "B"
            end
        ]], {
            ["$test~MyEnum"] = {
                kind = "type",
                name = "MyEnum",
                text = "my enum",
                visibility = "global",
                typename = "MyEnum",
                parent = "$test",
                path = "$test~MyEnum",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                type_kind = "enum",
                children = {
                    "$test~MyEnum.\"A\"",
                    "$test~MyEnum.\"B\""
                },
            },
            ["$test~MyEnum.\"A\""] = {
                kind = "enumvalue",
                name = "\"A\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"A\"",
                text = "A value",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            },
            ["$test~MyEnum.\"B\""] = {
                kind = "enumvalue",
                name = "\"B\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"B\"",
                text = "B value",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)

    it("enum values must be saved in lexicographic order", function()
        util.check_registry([[
            --- my enum
            local enum MyEnum
                "B"
                "A"
            end
        ]], {
            ["$test~MyEnum"] = {
                kind = "type",
                name = "MyEnum",
                text = "my enum",
                visibility = "local",
                typename = "MyEnum",
                parent = "$test",
                path = "$test~MyEnum",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
                type_kind = "enum",
                children = {
                    "$test~MyEnum.\"A\"",
                    "$test~MyEnum.\"B\""
                },
            },
            ["$test~MyEnum.\"A\""] = {
                kind = "enumvalue",
                name = "\"A\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"A\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            },
            ["$test~MyEnum.\"B\""] = {
                kind = "enumvalue",
                name = "\"B\"",
                parent = "$test~MyEnum",
                path = "$test~MyEnum.\"B\"",
                location = {
                    filename = "test.tl",
                    y = 2,
                    x = 1,
                },
            }
        })
    end)
end)