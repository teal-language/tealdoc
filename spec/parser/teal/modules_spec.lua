local util = require("spec.util")

describe("teal support in tealdoc: modules", function()
    it("should detect a module", function()
        util.check_registry([[
            --- This is a test module.
        ]], {
            ["$test"] = {
                kind = "module",
                name = "test",
                text = "This is a test module.",
                path = "$test",
                location = {
                    filename = "test.tl",
                    y = 1,
                    x = 1,
                }
            }
        })
    end)
end)