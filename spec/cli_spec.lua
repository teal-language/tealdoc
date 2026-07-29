local CLI = require("tealdoc.cli")
local DefaultEnv = require("tealdoc.default_env")
local tealdoc = require("tealdoc")
local tl = require("tl")
local lfs = require("lfs")

local function temporary_project(config)
    local root = os.tmpname()
    os.remove(root)
    assert(lfs.mkdir(root))
    local file = assert(io.open(root .. "/tlconfig.lua", "w"))
    file:write(config)
    file:close()
    return root
end

describe("CLI", function()
    it("prints its version without loading project configuration", function()
        local previous_print = _G.print
        local previous_directory = assert(lfs.currentdir())
        local output = {}
        local root = temporary_project([[error("configuration was loaded")]])
        local env = DefaultEnv.init()
        _G.print = function(value)
            table.insert(output, tostring(value))
        end
        assert(lfs.chdir(root))

        CLI:init(env, true)
        local ok = CLI:run({"--version"})

        assert(lfs.chdir(previous_directory))
        _G.print = previous_print
        assert(os.remove(root .. "/tlconfig.lua"))
        assert(lfs.rmdir(root))
        assert.is_true(ok)
        assert.same({"tealdoc " .. tealdoc.version}, output)
    end)

    it("exits from the main entry point before creating an environment", function()
        local previous_print = _G.print
        local previous_arguments = _G.arg
        local previous_directory = assert(lfs.currentdir())
        local output = {}
        local root = temporary_project([[error("configuration was loaded")]])
        _G.print = function(value)
            table.insert(output, tostring(value))
        end
        _G.arg = {"--version"}
        local main = assert(loadfile(
            previous_directory .. "/build/tealdoc/main.lua"
        ))
        assert(lfs.chdir(root))

        local ok, message = pcall(main)

        assert(lfs.chdir(previous_directory))
        _G.arg = previous_arguments
        _G.print = previous_print
        assert(os.remove(root .. "/tlconfig.lua"))
        assert(lfs.rmdir(root))
        assert.is_true(ok, message)
        assert.same({"tealdoc " .. tealdoc.version}, output)
    end)

    it("applies global documentation precedence before a command", function()
        local previous_directory = assert(lfs.currentdir())
        local previous_loader = tl.loader
        local root = temporary_project([[
            return {
                tealdoc = {
                    doc_precedence = "definition",
                },
            }
        ]])
        local env = DefaultEnv.init()
        local observed
        tl.loader = function() end
        assert(lfs.chdir(root))

        CLI:init(env, true)
        CLI:add_command({
            name = "inspect",
            setup = function() end,
            handler = function()
                observed = env.doc_precedence
            end,
        })
        local ok = CLI:run({"inspect"})

        assert(lfs.chdir(previous_directory))
        tl.loader = previous_loader
        assert(os.remove(root .. "/tlconfig.lua"))
        assert(lfs.rmdir(root))
        assert.is_true(ok)
        assert.equal("definition", observed)
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
