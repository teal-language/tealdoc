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

    it("reads a file-leading long comment as module documentation", function()
        local registry = util.registry_for_text([[
--[=[
Opens windows and reports display changes.

```teal
local window = api.open()
```
]=]

local dependency = require("dependency")
local record test
    dependency: dependency
end
return test
]])

        assert.are.equal(
            [[Opens windows and reports display changes.

```teal
local window = api.open()
```]],
            registry["$test"].text
        )
    end)
end)
