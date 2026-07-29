local CLI = require("tealdoc.cli")
local DefaultEnv = require("tealdoc.default_env")

local env = DefaultEnv.init()

CLI:init(env)
if not CLI:run() then
    os.exit(1)
end
