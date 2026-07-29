local CLI = require("tealdoc.cli")
local DefaultEnv = require("tealdoc.default_env")
local tealdoc = require("tealdoc")

for _, argument in ipairs(arg or {}) do
    if argument == "-V" or argument == "--version" then
        print("tealdoc " .. tealdoc.version)
        return
    end
end
local env = DefaultEnv.init()

CLI:init(env)
if not CLI:run() then
    os.exit(1)
end
