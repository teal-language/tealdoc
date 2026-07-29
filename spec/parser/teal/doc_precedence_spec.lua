local DefaultEnv = require("tealdoc.default_env")
local log = require("tealdoc.log")
local tealdoc = require("tealdoc")

local cases = {
    {
        name = "ordinary functions",
        path = "$test~make",
        source = [[
--- Declaration documentation.
local make: function(): string

--- Definition documentation.
function make(): string
    return "value"
end

local record example
end

return example
]],
    },
    {
        name = "record functions",
        path = "test.run",
        source = [[
local record example
    --- Declaration documentation.
    run: function(): string
end

--- Definition documentation.
function example.run(): string
    return "value"
end

return example
]],
    },
}

local function process(case, precedence)
    local env = DefaultEnv.init()
    if precedence then
        env.doc_precedence = precedence
    end
    tealdoc.process_text(case.source, "test.tl", env)
    return env
end

local function capture_warning(callback)
    local previous_output = log.output
    local previous_color = log.use_color
    local path = os.tmpname()
    local output = assert(io.open(path, "w"))
    log.output = output
    log.use_color = false
    local ok, result = pcall(callback)
    output:close()
    log.output = previous_output
    log.use_color = previous_color

    local file = assert(io.open(path, "r"))
    local message = assert(file:read("*a"))
    file:close()
    assert(os.remove(path))
    assert.is_true(ok, result)
    return result, message
end

describe("Teal function documentation precedence", function()
    for _, case in ipairs(cases) do
        it("retains declaration comments by default for " .. case.name, function()
            local env, warning = capture_warning(function()
                return process(case)
            end)
            assert.equal("declaration", env.doc_precedence)
            assert.equal(
                "Declaration documentation.",
                env.registry[case.path].text
            )
            assert.is_truthy(warning:find(case.path, 1, true), warning)
            assert.is_truthy(warning:find(
                "declaration comment is retained",
                1,
                true
            ), warning)
        end)

        it("can retain definition comments for " .. case.name, function()
            local env, warning = capture_warning(function()
                return process(case, "definition")
            end)
            assert.equal(
                "Definition documentation.",
                env.registry[case.path].text
            )
            assert.is_truthy(warning:find(case.path, 1, true), warning)
            assert.is_truthy(warning:find(
                "definition comment is retained",
                1,
                true
            ), warning)
        end)

        it("can reject duplicate comments for " .. case.name, function()
            local ok, message = pcall(function()
                process(case, "error")
            end)
            assert.is_false(ok)
            message = tostring(message)
            assert.is_truthy(message:find(case.path, 1, true), message)
            assert.is_truthy(message:find(
                "neither comment is retained",
                1,
                true
            ), message)
        end)
    end
end)
