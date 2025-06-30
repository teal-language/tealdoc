local record log
    enum Level 
        "debug"
        "info"
        "warning"
        "error"
    end
    threshold: Level
    use_color: boolean
    output: FILE

    log: function(log, level: Level, message: string, ...: any)
    debug: function(log, message: string, ...: any)
    info: function(log, message: string, ...: any)
    warning: function(log, message: string, ...: any)
    error: function(log, message: string, ...: any)
end

log.threshold = os.getenv("DEBUG") and "debug" or "info"
log.use_color = os.getenv("NO_COLOR") == nil
log.output = io.stdout 

local level_to_int: {log.Level: number} = {
    ["debug"] = 0,
    ["info"] = 1,
    ["warning"] = 2,
    ["error"] = 3
}

local ansi_reset = "\x1b[0m"

local level_to_ansi_color: {log.Level: string} = {
    ["debug"] = "\x1b[36m",
    ["info"] = "\x1b[32m",
    ["warning"] = "\x1b[33m",
    ["error"] = "\x1b[31m"
}


function log:log(level: log.Level, message: string, ...: any)
    if level_to_int[level] < level_to_int[self.threshold] then
        return
    end
    local formatted = message:format(...)
    local color = level_to_ansi_color[level]
    local decorated: string 
    if self.use_color then
        decorated = string.format("%s[%s] %s%s\n", color, level, formatted, ansi_reset)
    else
        decorated = string.format("[%s] %s\n", level, formatted)
    end
    self.output:write(decorated)
end

function log:debug(message: string, ...: any)
    self:log("debug", message, ...)
end

function log:info(message: string, ...: any)
    self:log("info", message, ...)
end

function log:warning(message: string, ...: any)
    self:log("warning", message, ...)
end

function log:error(message: string, ...: any)
    self:log("error", message, ...)
end

return log