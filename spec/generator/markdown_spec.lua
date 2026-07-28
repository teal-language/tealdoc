local DefaultEnv = require("tealdoc.default_env")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local tealdoc = require("tealdoc")

describe("Markdown generator", function()
    it("renders signatures as fenced Teal code", function()
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
            local type PrivateOptions = types.Options

            local record api
                type Options = types.Options
                type PublicOptions = types.Options

                --- Returns a value unchanged.
                --- @param value The value to return.
                --- @return The same value.
                identity: function<T>(value: T): T

                --- Performs one update.
                update: function()

                --- Copies options.
                copy: function(options: types.Options): types.Options

                --- Copies a public alias.
                copyPublic: function(options: PublicOptions): PublicOptions

                --- Copies through a private alias.
                copyPrivate: function(options: PrivateOptions): PrivateOptions
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
            "```teal\ntype api.Options = types.Options\n```",
            1,
            true
        ))
        assert.is_truthy(markdown:find(
            "```teal\nfunction api.identity<T>(value: T): T\n```",
            1,
            true
        ))
        local identity_heading = assert(markdown:find("## api.identity", 1, true))
        local identity_text = assert(markdown:find("Returns a value unchanged.", identity_heading, true))
        local identity_synopsis = assert(markdown:find("### Synopsis", identity_text, true))
        local identity_arguments = assert(markdown:find("### Arguments", identity_synopsis, true))
        local identity_returns = assert(markdown:find("### Returns", identity_arguments, true))
        assert.is_true(identity_heading < identity_text)
        assert.is_true(identity_text < identity_synopsis)
        assert.is_true(identity_synopsis < identity_arguments)
        assert.is_true(identity_arguments < identity_returns)
        assert.is_truthy(markdown:find(
            "### Arguments\n\nNone.\n\n### Returns\n\nNone.",
            assert(markdown:find("## api.update", 1, true)),
            true
        ), markdown)
        assert.is_falsy(markdown:find("<pre><code>", 1, true))
        assert.is_falsy(markdown:find('<a href="#types.Options">', 1, true))
        assert.is_falsy(markdown:find("[`types.Options`](", 1, true))
        assert.is_falsy(markdown:find("&lt;T&gt;", 1, true))

        local linked_output = os.tmpname()
        MarkdownGenerator.init(linked_output, function(path)
            if path == "types.Options" then
                return "/modules/types#types.Options"
            end
            return nil
        end):run(env)
        local linked_file = assert(io.open(linked_output, "r"))
        local linked_markdown = linked_file:read("*a")
        linked_file:close()
        os.remove(linked_output)

        assert.is_truthy(linked_markdown:find(
            "([`types.Options`](/modules/types#types.Options))",
            assert(linked_markdown:find("## api.copy", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "([`PublicOptions`](#api.PublicOptions))",
            assert(linked_markdown:find("## api.copyPublic", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "([`PrivateOptions`](/modules/types#types.Options))",
            assert(linked_markdown:find("## api.copyPrivate", 1, true)),
            true
        ), linked_markdown)
    end)
end)
