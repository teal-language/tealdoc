local CLI = require("cli")
local DefaultEnv = require("default_env")

local env = DefaultEnv.init()

CLI:init(env)
CLI:run()

