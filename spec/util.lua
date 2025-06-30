local tl = require("tl")
tl.loader()
local tealdoc = require("tealdoc")
local DefaultEnv = require("default_env")

local util = {}

function util.registry_for_text(text)
    local env = DefaultEnv.init()
    tealdoc.process_text(text, "test.tl", env)
    return env.registry
end

return util