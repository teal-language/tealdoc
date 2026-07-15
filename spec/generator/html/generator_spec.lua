local HTMLBuilder = require("tealdoc.generator.html.builder")
local HTMLGenerator = require("tealdoc.generator.html.generator")

describe("HTML generator", function()
    it("renders a module description", function()
        local description = "The Tag module renders HTML elements."
        local generator = HTMLGenerator.init("unused")
        local builder = HTMLBuilder.init()
        local ctx = {builder = builder}
        local item = {
            kind = "module",
            name = "Tag",
            text = description,
        }
        local phase = {name = "module_header"}

        local run_default_phase = generator:on_item_phase(
            item,
            phase,
            ctx,
            {}
        )

        assert.is_false(run_default_phase)
        assert.is_truthy(builder:build():find(description, 1, true))
    end)
end)
