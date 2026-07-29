local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tealdoc = require("tealdoc")
local SiteTypes = require("tealdoc.generator.site.types")

local SiteExamples = {}










local function read_file(path)
   local file = assert(io.open(path, "rb"), "Could not open " .. path)
   local contents = assert(file:read("*a"), "Could not read " .. path)
   file:close()
   return contents
end

local function extract_region(
   code,
   source,
   region)

   if not region or region == "" then
      return code
   end

   code = code:gsub("\r\n", "\n"):gsub("\r", "\n")
   local output = {}
   local stack = {}
   local found = 0
   local target_depth = 0
   for line in (code .. "\n"):gmatch("(.-)\n") do
      local opening = line:match("^%s*%-%-%s*#region%s+(%S.-)%s*$")
      local closing = line:match("^%s*%-%-%s*#endregion%s*(.-)%s*$")
      if opening then
         table.insert(stack, opening)
         if opening == region then
            assert(
            target_depth == 0,
            "nested example region '" .. region .. "' in " .. source)

            found = found + 1
            target_depth = #stack
         end
      elseif closing ~= nil and #stack > 0 then
         local opened = stack[#stack]
         assert(
         closing == "" or closing == opened,
         "example region '" ..
         opened ..
         "' in " ..
         source ..
         " closes as '" ..
         closing ..
         "'")

         if target_depth == #stack then
            target_depth = 0
         end
         table.remove(stack)
      elseif target_depth > 0 then
         table.insert(output, line)
      end
   end
   assert(
   found == 1 and target_depth == 0,
   found == 0 and
   "example region '" .. region .. "' was not found in " .. source or
   "example region '" ..
   region ..
   "' must occur once and have an end marker in " ..
   source)

   return table.concat(output, "\n"):gsub("\n*$", "") .. "\n"
end

local function validate_example(
   example,
   code,
   language,
   env)

   if example.check == false then
      return
   end
   local errors = {}
   if language == "teal" then
      local parser = env.parser_registry[".tl"]
      assert(parser and parser.validate, "Teal parser cannot validate examples")
      errors = parser:validate(code, example.source)
   elseif language == "lua" then
      local chunk, load_error = load(code, "@" .. example.source)
      if not chunk then
         table.insert(errors, tostring(load_error))
      end
   end
   assert(
   #errors == 0,
   "invalid example '" ..
   example.source ..
   (example.region and "#" .. example.region or "") ..
   "':\n" ..
   table.concat(errors, "\n"))

end

function SiteExamples.prepare(
   settings,
   env)

   local pages = {}
   local attached = {}
   local paths = {}
   for _, page in ipairs(settings.pages or {}) do
      table.insert(pages, page)
      paths[page.path or ""] = true
   end

   for _, example in ipairs(settings.examples or {}) do
      local has_path = example.path and example.path ~= ""
      local has_attachment = example.attach_to and example.attach_to ~= ""
      assert(
      has_path ~= has_attachment,
      "example requires exactly one of path or attach_to")

      if has_path then
         assert(
         example.title and example.title ~= "",
         "example title is required")

      end
      assert(
      example.source and example.source ~= "",
      "example source is required")

      if has_path then
         assert(
         not paths[example.path],
         "example path conflicts with a page: " .. example.path)

      end
      local code = read_file(example.source)
      code = extract_region(code, example.source, example.region)
      local language = example.language
      if not language then
         language = example.source:match("%.tl$") and "teal" or
         example.source:match("%.lua$") and "lua" or
         "text"
      end
      validate_example(example, code, language, env)
      if has_attachment then
         attached[example.attach_to] = attached[example.attach_to] or {}
         table.insert(attached[example.attach_to], {
            attach_to = example.attach_to,
            title = example.title or "Example",
            source = example.source,
            language = language,
            code = code,
         })
      else
         table.insert(pages, {
            path = example.path,
            title = example.title,
            description = example.description,
            example_source = example.source,
            example_language = language,
            example_code = code,
         })
         paths[example.path] = true
      end
   end
   return pages, attached
end

return SiteExamples
