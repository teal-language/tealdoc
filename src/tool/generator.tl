local tealdoc = require("tealdoc")

local record Generator
    interface Builder
        h1: function(self, text: string): Builder
        h2: function(self, text: string): Builder
        h3: function(self, text: string): Builder
        h4: function(self, text: string): Builder
        h5: function(self, text: string): Builder
        h6: function(self, text: string): Builder
        line: function(self, ...: string): Builder
        text: function(self, ...: string): Builder

        code_block: function(self, content: function()): Builder
        ordered_list: function(self, content: function(item: function(content: function))): Builder
        unordered_list: function(self, content: function(item: function(content: function))): Builder

        -- Modifiers
        b: function(self, text: string): string
        i: function(self, text: string): string
        code: function(self, text: string): string

        build: function(self): string
    end

    interface Base
        builder: Builder    
        run: function(self, filename: string, env: tealdoc.Env)
    end

    interface Phase
        name: string
        run: function(generator: Base, item: tealdoc.Item)
    end

    item_phases: {string: {Phase}}
    generate_for_item: function(generator: Base, item: tealdoc.Item, env: tealdoc.Env)
end

Generator.item_phases = {}

Generator.generate_for_item = function(generator: Generator.Base, item: tealdoc.Item, env: tealdoc.Env)
    local phases = Generator.item_phases[item.kind]
    if phases then
        for _, phase in ipairs(phases) do
            phase.run(generator, item)
        end
    end

    if item.children then
        for _, child_name in ipairs(item.children) do
            local child_item = env.registry[child_name]
            assert(child_item)
            Generator.generate_for_item(generator, child_item, env)
        end
    end
end

return Generator