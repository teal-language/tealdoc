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

local function write_file(path, contents)
    local file = assert(io.open(path, "w"))
    file:write(contents)
    file:close()
end

local function remove_tree(path)
    local attributes = lfs.symlinkattributes(path)
    if not attributes then
        return
    end
    if attributes.mode == "directory" then
        for entry in lfs.dir(path) do
            if entry ~= "." and entry ~= ".." then
                remove_tree(path .. "/" .. entry)
            end
        end
        assert(lfs.rmdir(path))
    else
        assert(os.remove(path))
    end
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

    it("resolves public aliases through automatically indexed hidden modules", function()
        local previous_directory = assert(lfs.currentdir())
        local previous_utf8 = _G.utf8
        local previous_utf8_loader = package.preload["lua-utf8"]
        local root = temporary_project([[
            return {
                source_dir = "src",
                tealdoc = {
                    site = {
                        title = "Hidden aliases",
                        validate_links = false,
                        sources = {"src/api.tl"},
                        pages = {
                            {
                                path = "api",
                                title = "API",
                                api = "api",
                            },
                        },
                    },
                },
            }
        ]])
        assert(lfs.mkdir(root .. "/src"))
        assert(lfs.mkdir(root .. "/src/pkg"))
        assert(lfs.mkdir(root .. "/src/pkg/internal"))
        write_file(root .. "/src/api.tl", [[
            local type types = require("pkg.internal.types")
            local type private = require("pkg._types")
            local record api
                --- Runs an action.
                type Action = types.Action

                --- Configures an action.
                type Options = private.Options
            end
            return api
        ]])
        write_file(root .. "/src/pkg/internal/types.tl", [[
            local record types
                type Action = function(message: string)
            end
            return types
        ]])
        write_file(root .. "/src/pkg/_types.tl", [[
            local record types
                record Options
                    enabled: boolean
                end
            end
            return types
        ]])

        assert(lfs.chdir(root))
        _G.utf8 = require("compat53.module").utf8
        package.preload["lua-utf8"] = function()
            return require("compat53.module").utf8
        end
        CLI:init(DefaultEnv.init())
        local ok = CLI:run({
            "site",
            "-o",
            root .. "/site",
        })
        assert(lfs.chdir(previous_directory))
        _G.utf8 = previous_utf8
        package.preload["lua-utf8"] = previous_utf8_loader

        local html_file = assert(io.open(
            root .. "/site/api/index.html",
            "r"
        ))
        local html = assert(html_file:read("*a"))
        html_file:close()
        local action_start = assert(html:find(
            '<p><a id="api.Action"></a></p>',
            1,
            true
        ))
        local action = html:sub(action_start, action_start + 1600)
        local options_start = assert(html:find(
            '<p><a id="api.Options"></a></p>',
            1,
            true
        ))
        local options = html:sub(options_start, options_start + 2400)
        assert.is_true(ok)
        assert.is_truthy(action:find(
            "keyword-function",
            1,
            true
        ), action)
        assert.is_falsy(action:find(
            "pkg.internal.types.Action",
            1,
            true
        ), action)
        assert.is_truthy(options:find(
            'id="api.Options.enabled"',
            1,
            true
        ), options)
        assert.is_falsy(options:find(
            "pkg._types.Options",
            1,
            true
        ), options)
        remove_tree(root)
    end)
end)
