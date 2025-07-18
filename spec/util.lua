local tealdoc = require("tealdoc")
local DefaultEnv = require("tealdoc.default_env")
local log = require("tealdoc.log")
local assert = require("luassert")

local util = {}

--- asserts that two array contain the same elements, regardless of order
function util.assert_is_same_array(a, b)
    local a_set = {}
    local b_set = {}
    for _, v in ipairs(a) do
        a_set[v] = true
    end
    for _, v in ipairs(b) do
        b_set[v] = true
    end
    for k in pairs(a_set) do
        assert.is_true(b_set[k], "Element " .. k .. " is in the first array but not in the second")
    end
    for k in pairs(b_set) do
        assert.is_true(a_set[k], "Element " .. k .. " is in the second array but not in the first")
    end
end

--- removes leading whitespace from every line of a multiline string
function util.dedent(s)
   local min, lines = math.huge, {}

   for line in s:gmatch("([^\n]*)\n?") do
      local indent = line:match("^(%s*)%S")
      if indent then min = math.min(min, #indent) end
      table.insert(lines, line)
   end

   if min == math.huge then
      return s
   end

   for i, line in ipairs(lines) do
      lines[i] = line:sub(min + 1)
   end

   return table.concat(lines, "\n")
end

function util.registry_for_text(text)
    local env = DefaultEnv.init()
    log.output = io.open("test.log", "w")
    tealdoc.process_text(text, "test.tl", env)
    return env.registry
end

function util.check_registry(text, expected) 
    text = util.dedent(text)
    text = text.."\nlocal record test\nend\nreturn test"
    local registry = util.registry_for_text(text)
    local expected_children = {}
    for k, v in pairs(expected) do
        if v.parent == "$test" then
            table.insert(expected_children, k)
        end
    end
    table.insert(expected_children, "test") -- module record
    
    util.assert_is_same_array(
        registry["$test"].children,
        expected_children
    )

    expected["$test"] = {
        kind = "module",
        name = "test",
        location = {
            filename = "test.tl",
            y = 1,
            x = 1,
        },
        path = "$test",
        -- a bit of a hack to avoid having to manually specify children
        -- technically this does not test if the children are in the right order
        -- however the order is not important for the test 
        children = registry["$test"].children,
    }

    expected["test"] = {
        kind = "type",
        name = "test",
        location = {
            filename = "test.tl",
            y = select(2, string.gsub(text, "\n", "")) - 1,
            x = 1,
        },
        path = "test",
        parent = "$test",
        type_kind = "record",
        typename = "test",
        visibility = "local"
    }
    assert.is_same(expected, registry)
end

return util