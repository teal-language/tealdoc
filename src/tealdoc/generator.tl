local tealdoc = require("tealdoc")

local record Generator
    interface Builder
        type Content = string | function(b: Builder)

        h1: function(self, content: Content): Builder
        h2: function(self, content: Content): Builder
        h3: function(self, content: Content): Builder
        h4: function(self, content: Content): Builder
        h5: function(self, content: Content): Builder
        h6: function(self, content: Content): Builder
        line: function(self, ...: Content): Builder
        rawline: function(self, ...: Content): Builder
        text: function(self, ...: Content): Builder
        rawtext: function(self, ...: Content): Builder
        paragraph: function(self, ...: Content): Builder
        link: function(self, to: string, ...: Content): Builder

        code_block: function(self, content: Content): Builder
        ordered_list: function(self, content: function(item: function(content: function))): Builder
        unordered_list: function(self, content: function(item: function(content: function))): Builder

        b: function(self, content: Content): Builder
        i: function(self, content: Content): Builder
        code: function(self, content: Content): Builder
        md: function(self, content: string): Builder

        build: function(self): string
    end

    interface Base
        builder: Builder
        run: function(self, filename: string, env: tealdoc.Env)
    end

    enum PathMode
        "full" -- full path to the item
        "relative" -- relative path to the item from the module
        "none" -- no path, just the item name
    end

    interface Phase
        interface Context
            builder: Builder
            module_name: string
            path_mode: PathMode
            env: tealdoc.Env
            filter: function(item: tealdoc.Item, env: tealdoc.Env): boolean
        end

        name: string
        run: function(ctx: Context, item: tealdoc.Item)
    end
end

return Generator