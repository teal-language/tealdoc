local CLI = require("tealdoc.cli")
local DefaultEnv = require("tealdoc.default_env")

local env = DefaultEnv.init()

CLI:init(env)
CLI:run()

