local lfs = require("lfs")
local TealParser = require("tealdoc.parser.teal")
local tl = require("tl")

describe("Teal project configuration", function()
    local original_directory
    local temporary_directory

    local function write_file(path, contents)
        local file = assert(io.open(path, "w"))
        assert(file:write(contents))
        assert(file:close())
    end

    before_each(function()
        original_directory = assert(lfs.currentdir())
        temporary_directory = os.tmpname()
        os.remove(temporary_directory)
        assert(lfs.mkdir(temporary_directory))
        assert(lfs.mkdir(temporary_directory .. "/definitions"))
        assert(lfs.mkdir(temporary_directory .. "/source"))
        assert(lfs.mkdir(temporary_directory .. "/work"))

        write_file(temporary_directory .. "/tlconfig.lua", [[
return {
    source_dir = "source",
    include_dir = {"definitions"},
    global_env_def = "fixture_globals",
    feat_arity = "off",
    gen_compat = "off",
    gen_target = "5.1",
}
]])
        write_file(temporary_directory .. "/definitions/fixture_globals.d.tl", [[
global record FixtureGlobal
    value: string
end
]])
        write_file(temporary_directory .. "/definitions/fixture_dependency.d.tl", [[
local record FixtureDependency
    value: string
end

return FixtureDependency
]])

        assert(lfs.chdir(temporary_directory .. "/work"))
    end)

    after_each(function()
        assert(lfs.chdir(original_directory))
        os.remove(temporary_directory .. "/definitions/fixture_globals.d.tl")
        os.remove(temporary_directory .. "/definitions/fixture_dependency.d.tl")
        os.remove(temporary_directory .. "/tlconfig.lua")
        assert(lfs.rmdir(temporary_directory .. "/definitions"))
        assert(lfs.rmdir(temporary_directory .. "/source"))
        assert(lfs.rmdir(temporary_directory .. "/work"))
        assert(lfs.rmdir(temporary_directory))
    end)

    it("applies compiler settings and resolves configured definitions", function()
        local original_package_path = package.path
        local original_tl_path = tl.path
        local parser = TealParser.init()
        local defaults = parser.tl_env.defaults or parser.tl_env.opts

        assert.equal("../source", parser.source_dir)
        assert.equal("off", defaults.feat_arity)
        assert.equal("off", defaults.gen_compat)
        assert.equal("5.1", defaults.gen_target)
        assert.is_not_nil(parser.tl_env.globals.FixtureGlobal)
        assert.equal(original_package_path, package.path)
        assert.equal(original_tl_path, tl.path)

        local env = {modules = {}, registry = {}}
        parser:process([[
local dependency = require("fixture_dependency")

local record Example
    global: FixtureGlobal
    dependency: dependency
end

return Example
]], "../source/example.tl", env)

        assert.is_not_nil(parser.tl_env.modules.fixture_dependency)
        assert.is_not_nil(env.registry["$example"])
        assert.equal(original_package_path, package.path)
        assert.equal(original_tl_path, tl.path)
    end)
end)
