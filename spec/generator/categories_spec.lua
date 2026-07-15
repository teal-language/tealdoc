local tealdoc = require("tealdoc")
local DefaultEnv = require("tealdoc.default_env")
local Generator = require("tealdoc.generator")

describe("generator categories", function()
    it("handles an empty module record", function()
        local env = DefaultEnv.init()
        tealdoc.process_text([[
            local record something
            end

            return something
        ]], "something.d.tl", env)

        local order, categories = Generator.categories_for_module_record(
            env.registry["something"],
            env
        )

        assert.same({"$uncategorized"}, order)
        assert.same({}, categories["$uncategorized"])
    end)
end)
