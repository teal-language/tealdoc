local HTMLBuilder = require("tealdoc.generator.html.builder")
local HTMLGenerator = require("tealdoc.generator.html.generator")
local DefaultEnv = require("tealdoc.default_env")
local detailed_signature_phase = require("tealdoc.generator.html.detailed_signature_phase")
local tealdoc = require("tealdoc")

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

    it("renders overloaded metamethods in detailed signatures", function()
        local env = DefaultEnv.init()
        tealdoc.process_text([[
            global record V
                metamethod __mul: function(number, number): number
                metamethod __mul: function(number, table): number
            end
        ]], "test.tl", env)

        local builder = HTMLBuilder.init()
        local ctx = {
            builder = builder,
            module_name = "test",
            path_mode = "relative",
            env = env,
            filter = function()
                return true
            end,
        }

        assert.has_no.errors(function()
            detailed_signature_phase.run(ctx, env.registry["$test~V"])
        end)

        local html = builder:build()
        assert.is_truthy(html:find("number, number", 1, true))
        assert.is_truthy(html:find("number, {&lt;any type&gt; : &lt;any type&gt;}", 1, true))
    end)

    it("links type aliases to declarations in other modules", function()
        local env = DefaultEnv.init()
        env.modules = {"tecs.init", "tecs.types"}
        env.registry["tecs.types.components.TagComponentOptions"] = {
            kind = "type",
            type_kind = "interface",
            name = "TagComponentOptions",
            path = "tecs.types.components.TagComponentOptions",
            visibility = "record",
        }
        local item = {
            kind = "type",
            type_kind = "type",
            name = "TagComponentOptions",
            path = "tecs.init.TagComponentOptions",
            visibility = "record",
            typename = "types.components.TagComponentOptions",
            alias_target = "tecs.types.components.TagComponentOptions",
        }
        local builder = HTMLBuilder.init()
        local ctx = {
            builder = builder,
            module_name = "tecs.init",
            path_mode = "relative",
            env = env,
            url_for_path = function(path)
                return HTMLGenerator.url_for_path(path, "tecs.init", env)
            end,
        }

        detailed_signature_phase.run(ctx, item)

        assert.is_truthy(builder:build():find(
            'href="types.html#tecs.types.components.TagComponentOptions"',
            1,
            true
        ))
    end)
end)
