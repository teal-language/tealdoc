local DefaultEnv = require("tealdoc.default_env")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local tealdoc = require("tealdoc")

describe("Markdown generator", function()
    it("links type aliases to declarations", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record types
                interface Options
                end
            end

            return types
        ]], "types.tl", env)
        tealdoc.process_text([[
            local types = require("types")

            local record api
                type Options = types.Options
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        assert.is_truthy(markdown:find('<a id="types.Options"></a>', 1, true))
        assert.is_truthy(markdown:find(
            '<a href="#types.Options">types.Options</a>',
            1,
            true
        ))
    end)
end)
