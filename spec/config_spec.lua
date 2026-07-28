local Config = require("tealdoc.config")
local lfs = require("lfs")

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

    it("reports the directory of a discovered parent configuration", function()
        local root = os.tmpname()
        os.remove(root)
        assert(lfs.mkdir(root))
        assert(lfs.mkdir(root .. "/nested"))
        local file = assert(io.open(root .. "/tlconfig.lua", "w"))
        file:write([[
            return {
                tealdoc = {
                    site = {
                        title = "Discovered",
                        pages = {
                            { path = "", title = "Home" },
                        },
                    },
                },
            }
        ]])
        file:close()

        local previous = assert(lfs.currentdir())
        assert(lfs.chdir(root .. "/nested"))
        local ok, loaded = pcall(Config.load)
        assert(lfs.chdir(previous))
        assert.is_true(ok, loaded)
        assert.are.equal("../tlconfig.lua", loaded.filename)
        assert.are.equal("..", loaded.directory)

        assert(os.remove(root .. "/tlconfig.lua"))
        assert(lfs.rmdir(root .. "/nested"))
        assert(lfs.rmdir(root))
    end)
end)
