local DefaultEnv = require("tealdoc.default_env")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local tealdoc = require("tealdoc")

describe("Markdown generator", function()
    it("resolves a routed public type absent from the local registry", function()
        local env = DefaultEnv.init()
        local markdown = MarkdownGenerator.resolve_markdown_type_links(
            env,
            "Returns a [`Future`](tealdoc:tecs.Future).",
            function(path)
                return path == "tecs.Future"
                    and "/modules/Future/"
                    or nil
            end
        )

        assert.are.equal(
            "Returns a [`Future`](/modules/Future/).",
            markdown
        )
    end)

    it("renders a routed reference to the current item without a link", function()
        local env = DefaultEnv.init()
        local markdown = MarkdownGenerator.resolve_markdown_type_links(
            env,
            "Returns a [`Future`](tealdoc:tecs.Future)`<T>`.",
            function(path)
                return path == "tecs.Future"
                    and "/modules/Future/"
                    or nil
            end,
            nil,
            "/modules/Future/"
        )

        assert.are.equal("Returns a `Future<T>`.", markdown)
    end)

    it("hides single-underscore members unless explicitly public", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                --- Internal storage.
                _hidden: string

                --- Deliberately exposed storage.
                --- @public
                _shown: string

                --- A real metamethod-shaped public member.
                __call: function()

                --- Conventional public version constant.
                _VERSION: string
            end

            return api
        ]], "visibility.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        assert.is_falsy(markdown:find("visibility._hidden", 1, true))
        assert.is_truthy(markdown:find("visibility._shown", 1, true))
        assert.is_truthy(markdown:find("visibility.__call", 1, true))
        assert.is_truthy(markdown:find("visibility._VERSION", 1, true))
    end)

    it("renders signatures as fenced Teal code", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record types
                interface Options
                    value: string
                end
            end

            return types
        ]], "types.tl", env)
        tealdoc.process_text([[
            local record Window
            end

            return Window
        ]], "window.tl", env)
        tealdoc.process_text([[
            local types = require("types")
            local type Window = require("window")
            local type PrivateOptions = types.Options
            local record Payload
                value: string
            end

            local record api
                interface Readable
                end

                interface Writable
                end

                interface ReadWrite is Readable, Writable
                end

                type Options = types.Options
                type PublicOptions = types.Options
                Payload: Payload

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

                --- Copies a payload.
                copyPayload: function(payload: Payload): Payload

                --- Shows a message in a [`Window`](tealdoc:window).
                messageBox: function(window: Window)

                --- Wraps a generic window.
                generic: function<T>(window: Window<T>): Window<T>
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
        assert.is_falsy(markdown:find("tealdoc-kind-badge", 1, true))
        local identity_text = assert(markdown:find("Returns a value unchanged.", identity_heading, true))
        local identity_signature = assert(markdown:find(
            "```teal\nfunction api.identity<T>(value: T): T\n```",
            identity_text,
            true
        ))
        local identity_arguments = assert(markdown:find("### Arguments", identity_signature, true))
        local identity_returns = assert(markdown:find("### Returns", identity_arguments, true))
        assert.is_true(identity_heading < identity_text)
        assert.is_true(identity_text < identity_signature)
        assert.is_true(identity_signature < identity_arguments)
        assert.is_true(identity_arguments < identity_returns)
        assert.is_truthy(markdown:find("### types.Options.value", 1, true))
        assert.is_falsy(markdown:find("Synopsis", 1, true))
        assert.is_truthy(markdown:find(
            "### Arguments\n\nNone.\n\n### Returns\n\nNone.",
            assert(markdown:find("## api.update", 1, true)),
            true
        ), markdown)
        assert.is_falsy(markdown:find("<pre><code>", 1, true))
        assert.is_falsy(markdown:find('<a href="#types.Options">', 1, true))
        assert.is_falsy(markdown:find("[`types.Options`](", 1, true))
        assert.is_falsy(markdown:find("&lt;T&gt;", 1, true))
        assert.is_truthy(markdown:find(
            "Shows a message in a [`Window`](#window).",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find("tealdoc:", 1, true))

        local linked_output = os.tmpname()
        MarkdownGenerator.init(linked_output, function(path)
            if path == "types.Options" then
                return "/modules/types#types.Options"
            end
            if path == "window" then
                return "/modules/window#window"
            end
            return nil
        end):run(env)
        local linked_file = assert(io.open(linked_output, "r"))
        local linked_markdown = linked_file:read("*a")
        linked_file:close()
        os.remove(linked_output)

        assert.is_truthy(linked_markdown:find(
            "| [`types.Options`](/modules/types#types.Options) |",
            assert(linked_markdown:find("## api.copy", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "| [`PublicOptions`](#api.PublicOptions) |",
            assert(linked_markdown:find("## api.copyPublic", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "| [`PrivateOptions`](/modules/types#types.Options) |",
            assert(linked_markdown:find("## api.copyPrivate", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "```teal\nrecord api.Payload\n    value: string\nend\n```",
            1,
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "```teal\ninterface api.ReadWrite is Readable, Writable\n" ..
                "end\n```",
            1,
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "### Interfaces\n\n" ..
                "| Interface |\n" ..
                "| --- |\n" ..
                "| [`Readable`](#api.Readable) |\n" ..
                "| [`Writable`](#api.Writable) |",
            1,
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find("## api.Payload.value", 1, true))
        assert.is_falsy(linked_markdown:find("api.Payload: Payload", 1, true))
        assert.is_truthy(linked_markdown:find(
            "| [`Payload`](#api.Payload) |",
            assert(linked_markdown:find("## api.copyPayload", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "| [`Window`](/modules/window#window) |",
            assert(linked_markdown:find("## api.messageBox", 1, true)),
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "Shows a message in a [`Window`](/modules/window#window).",
            1,
            true
        ), linked_markdown)
        assert.is_truthy(linked_markdown:find(
            "| [`Window`](/modules/window#window)`<T>` |",
            assert(linked_markdown:find("## api.generic", 1, true)),
            true
        ), linked_markdown)
        assert.is_falsy(linked_markdown:find("``T``", 1, true))
    end)

    it("separates nested types only when another member follows", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                record Followed
                    record Nested
                        value: string
                    end
                    next: string
                end

                record Trailing
                    first: string
                    record Nested
                        value: string
                    end
                end
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        assert.is_truthy(markdown:find(
            "record api.Followed\n" ..
                "    record Nested\n" ..
                "        value: string\n" ..
                "    end\n\n" ..
                "    next: string\n" ..
                "end",
            1,
            true
        ), markdown)
        assert.is_truthy(markdown:find(
            "record api.Trailing\n" ..
                "    first: string\n" ..
                "    record Nested\n" ..
                "        value: string\n" ..
                "    end\n" ..
                "end",
            1,
            true
        ), markdown)
        assert.is_falsy(markdown:find(
            "    record Nested\n" ..
                "        value: string\n" ..
                "    end\n\n" ..
                "end",
            1,
            true
        ), markdown)
    end)

    it("tabulates parameters, returns and type parameters", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                record Handle
                end
            end

            --- Open a handle.
            --- @param name What to open.
            --- @param mode How to open it.
            --- @return The handle.
            function api.open(name: string, mode: integer): api.Handle
                return nil
            end

            --- Returns a value unchanged.
            --- @param value The value to return.
            --- @return The same value.
            function api.identity<T>(value: T): T
                return value
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        assert.is_truthy(markdown:find([[
| Name | Type | Description |
| --- | --- | --- |
| `name` | `string` | What to open. |
| `mode` | `integer` | How to open it. |
]], 1, true), markdown)

        assert.is_truthy(markdown:find([[
| Type | Description |
| --- | --- |
| `api.Handle` | The handle. |
]], 1, true), markdown)

        assert.is_truthy(markdown:find([[
| Name | Constraint | Description |
| --- | --- | --- |
| `T` |  |  |
]], 1, true), markdown)
    end)

    it("keeps a union type inside its own cell", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                find: function(string): string | nil
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        -- A literal pipe would end the cell in the middle of the type.
        assert.is_truthy(markdown:find(
            "| <code>string &#124; nil</code> |",
            1,
            true
        ), markdown)
    end)

    it("keeps angle brackets readable in a cell that carries a union", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                record Handle<T>
                end

                find: function(string): Handle<string> | nil
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        -- The code element is HTML, so its contents are escaped the way a code
        -- span would have had them escaped on the reader's behalf.
        assert.is_truthy(markdown:find(
            "| <code>Handle&lt;string&gt; &#124; nil</code> |",
            1,
            true
        ), markdown)
    end)

    it("folds a description written over several lines onto its row", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                --- Open a handle.
                --- @param name What to open. The name is looked up in the
                ---     registry first.
                open: function(name: string)
            end

            return api
        ]], "api.tl", env)

        local output = os.tmpname()
        MarkdownGenerator.init(output):run(env)
        local file = assert(io.open(output, "r"))
        local markdown = file:read("*a")
        file:close()
        os.remove(output)

        assert.is_truthy(markdown:find(
            "| What to open. The name is looked up in the registry first. |",
            1,
            true
        ), markdown)
    end)
end)
