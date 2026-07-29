local CLI = require("tealdoc.cli")
local DefaultEnv = require("tealdoc.default_env")
local tealdoc = require("tealdoc")
local tl = require("tl")

describe("CLI", function()
    it("prints its version without requiring a command", function()
        local previous_print = _G.print
        local output = {}
        _G.print = function(value)
            table.insert(output, tostring(value))
        end

        CLI:init(DefaultEnv.init(), true)
        local ok = CLI:run({"--version"})

        _G.print = previous_print
        assert.is_true(ok)
        assert.same({"tealdoc " .. tealdoc.version}, output)
    end)

    it("reports command errors without a traceback", function()
        local previous_stderr = io.stderr
        local previous_loader = tl.loader
        local error_path = os.tmpname()
        local error_file = assert(io.open(error_path, "w"))
        io.stderr = error_file
        tl.loader = function() end

        CLI:init(DefaultEnv.init(), true)
        CLI:add_command({
            name = "fail",
            setup = function() end,
            handler = function()
                error("broken configuration")
            end,
        })
        local ok = CLI:run({"fail"})

        error_file:close()
        io.stderr = previous_stderr
        tl.loader = previous_loader
        local file = assert(io.open(error_path, "r"))
        local message = file:read("*a")
        file:close()
        os.remove(error_path)

        assert.is_false(ok)
        assert.is_truthy(message:find(
            "tealdoc: broken configuration",
            1,
            true
        ), message)
        assert.is_falsy(message:find("stack traceback", 1, true), message)
    end)
end)
