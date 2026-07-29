local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local os = _tl_compat and _tl_compat.os or os; local CLI = require("tealdoc.cli")
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
