local util = require("spec.util")

describe("teal support in tealdoc: type arguments", function()
    it("should describe each type argument by the name its tag gives", function()
        -- The tags are written in the opposite order to the declaration. A
        -- handler binding by position would put each description on the
        -- wrong parameter, or drop one and keep the other.
        local registry = util.registry_for_text(util.dedent([[
            --- my function
            --- @typearg V what comes out
            --- @typearg K what goes in
            local function lookup<K, V>(key: K): V
            end
        ]]))
        assert.are.same(
            {
                { name = "K", description = "what goes in" },
                { name = "V", description = "what comes out" },
            },
            registry["$test~lookup"].typeargs
        )
    end)

    it("should describe a type argument the compiler leaves unnamed", function()
        local registry = util.registry_for_text(util.dedent([[
            --- my function
            --- @typearg T the only one
            local function only<T>(value: T): T
            end
        ]]))
        assert.are.same(
            { { name = "T", description = "the only one" } },
            registry["$test~only"].typeargs
        )
    end)
end)
