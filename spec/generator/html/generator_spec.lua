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
        assert.is_truthy(html:find("number, {any : any}", 1, true))
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

    it("tabulates parameters and returns", function()
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

            return api
        ]], "api.tl", env)

        local builder = HTMLBuilder.init()
        local ctx = {
            builder = builder,
            module_name = "api",
            path_mode = "relative",
            env = env,
            url_for_path = function(path)
                return HTMLGenerator.url_for_path(path, "api", env)
            end,
        }
        local item = env.registry["api.open"]

        for _, phase in ipairs(HTMLGenerator.item_phases["function"]) do
            if phase.name == "function_params"
                or phase.name == "function_returns"
            then
                phase.run(ctx, item)
            end
        end

        local html = builder:build()

        assert.is_truthy(html:find(
            "<thead><tr><th>Name</th><th>Type</th><th>Description</th></tr>"
                .. "</thead>",
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            "<tr><td><code>name</code></td><td><code>string</code></td>"
                .. "<td>What to open.</td></tr>",
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            "<tr><td><code>mode</code></td><td><code>integer</code></td>"
                .. "<td>How to open it.</td></tr>",
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            "<thead><tr><th>Type</th><th>Description</th></tr></thead>",
            1,
            true
        ), html)
        assert.is_truthy(html:find(
            "<tr><td><code>api.Handle</code></td>"
                .. "<td>The handle.</td></tr>",
            1,
            true
        ), html)
        -- Nothing survives from the lists the tables replaced.
        assert.is_nil(html:find("<ul>", 1, true))
        assert.is_nil(html:find("<ol>", 1, true))
    end)

    it("leaves a cell empty when a row has nothing to put in it", function()
        local env = DefaultEnv.init()
        env.no_warnings_on_missing = true
        tealdoc.process_text([[
            local record api
                --- Reset everything.
                reset: function(count: integer)
            end

            return api
        ]], "api.tl", env)

        local builder = HTMLBuilder.init()
        local ctx = {
            builder = builder,
            module_name = "api",
            path_mode = "relative",
            env = env,
            url_for_path = function(path)
                return HTMLGenerator.url_for_path(path, "api", env)
            end,
        }
        local item = env.registry["api.reset"]

        for _, phase in ipairs(HTMLGenerator.item_phases["function"]) do
            if phase.name == "function_params" then
                phase.run(ctx, item)
            end
        end

        assert.is_truthy(builder:build():find(
            "<tr><td></td><td><code>integer</code></td><td></td></tr>",
            1,
            true
        ))
    end)
end)
