local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local log = {}

















log.threshold = os.getenv("DEBUG") and "debug" or "info"
log.use_color = os.getenv("NO_COLOR") == nil
log.output = io.stdout

local level_to_int = {
   ["debug"] = 0,
   ["info"] = 1,
   ["warning"] = 2,
   ["error"] = 3,
}

local ansi_reset = "\x1b[0m"

local level_to_ansi_color = {
   ["debug"] = "\x1b[36m",
   ["info"] = "\x1b[32m",
   ["warning"] = "\x1b[33m",
   ["error"] = "\x1b[31m",
}


function log:log(level, message, ...)
   if level_to_int[level] < level_to_int[self.threshold] then
      return
   end
   local formatted = message:format(...)
   local color = level_to_ansi_color[level]
   local decorated
   if self.use_color then
      decorated = string.format("%s[%s] %s%s\n", color, level, formatted, ansi_reset)
   else
      decorated = string.format("[%s] %s\n", level, formatted)
   end
   self.output:write(decorated)
end

function log:debug(message, ...)
   self:log("debug", message, ...)
end

function log:info(message, ...)
   self:log("info", message, ...)
end

function log:warning(message, ...)
   self:log("warning", message, ...)
end

function log:error(message, ...)
   self:log("error", message, ...)
end

return log
