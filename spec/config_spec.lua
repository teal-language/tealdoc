local Config = require("tealdoc.config")

describe("Tealdoc configuration in tlconfig.lua", function()
    it("loads Markdown type links from Lua", function()
        local filename = os.tmpname()
        local file = assert(io.open(filename, "w"))
        file:write([[
            return {
                tealdoc = {
                    markdown = {
                        type_links = {
                            ["example.Widget"] = "/modules/widget#example.Widget",
                        },
                    },
                },
            }
        ]])
        file:close()

        local config = Config.load(filename)
        os.remove(filename)

        assert.are.equal(
            "/modules/widget#example.Widget",
            config.values.tealdoc.markdown.type_links["example.Widget"]
        )
    end)

    it("accepts a computed Markdown type resolver", function()
        local filename = os.tmpname()
        local file = assert(io.open(filename, "w"))
        file:write([[
            return {
                tealdoc = {
                    markdown = {
                        type_links = function(path)
                            return "/types/" .. path
                        end,
                    },
                },
            }
        ]])
        file:close()

        local config = Config.load(filename)
        os.remove(filename)

        assert.are.equal(
            "/types/example.Widget",
            config.values.tealdoc.markdown.type_links("example.Widget")
        )
    end)
end)
