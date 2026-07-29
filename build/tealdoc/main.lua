local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local CLI = require("tealdoc.cli")
local DefaultEnv = require("tealdoc.default_env")

local env = DefaultEnv.init()

CLI:init(env)
if not CLI:run() then
   os.exit(1)
end
