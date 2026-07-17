local util = require("spec.util")

describe("teal parser integration", function()
    it("handles uncommented nested type declarations", function()
        assert.has_no.errors(function()
            util.registry_for_text([[
                local record example
                    type Value = string
                end

                return example
            ]])
        end)
    end)

    it("handles assignments through generic record receivers", function()
        assert.has_no.errors(function()
            util.registry_for_text([[
                local record example
                    callback: function()
                end

                local function configure<T is example>(value: T)
                    value.callback = function()
                    end
                end

                return example
            ]])
        end)
    end)

    it("matches local forward declarations with function definitions", function()
        local registry = util.registry_for_text([[
            local make: function(): string

            function make(): string
                return "value"
            end

            local record example
                value: string
            end

            return example
        ]])

        assert.equal("function", registry["$test~make"].kind)
        assert.equal("local", registry["$test~make"].visibility)
    end)

    it("matches aliased function fields with their definitions", function()
        local registry = util.registry_for_text([[
            local type Callback = function(value: string): string

            local record example
                transform: Callback
            end

            function example.transform(value: string): string
                return value
            end

            return example
        ]])

        assert.equal("function", registry["test.transform"].kind)
        assert.equal("record", registry["test.transform"].visibility)
    end)

    it("matches function aliases assigned through record values", function()
        local registry = util.registry_for_text([[
            global type Fun = function(): integer

            global record T
                fun: Fun
            end

            local t: T

            t.fun = function(): integer
                return 1
            end
        ]])

        assert.equal("function", registry["$test~T.fun"].kind)
        assert.equal("record", registry["$test~T.fun"].visibility)
    end)

    it("does not attach separated documentation blocks", function()
        local registry = util.registry_for_text([[
            --- Stale function documentation.
            --- @param value A value
            -- This comment belongs to the implementation below.
            local value = 1

            local record example
                marker: boolean
            end

            return example
        ]])

        assert.is_nil(registry["$test~value"].text)
    end)

    it("documents method parameters without requiring self", function()
        local registry = util.registry_for_text([[
            local record example
            end

            --- @param value The value to use
            function example:method(value: string)
            end
        ]])

        local params = registry["$test~example.method"].params
        assert.is_nil(params[1].description)
        assert.equal("The value to use", params[2].description)
    end)

    it("normalizes relative and Windows module paths", function()
        local text = [[
            local record example
            end

            return example
        ]]

        local relative = util.registry_for_text(text, "./nested/example.tl")
        local windows = util.registry_for_text(text, "nested\\example.tl")

        assert.equal("nested.example", relative["$nested.example"].name)
        assert.equal("nested.example", windows["$nested.example"].name)
    end)

end)
