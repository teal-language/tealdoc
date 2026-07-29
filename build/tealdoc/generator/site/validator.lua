local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local SiteValidator = {}



local function read_file(path)
   local file = assert(io.open(path, "rb"), "Could not open " .. path)
   local contents = assert(file:read("*a"), "Could not read " .. path)
   file:close()
   return contents
end

local function normalized_relative_path(
   directory,
   path)

   local parts = {}
   local combined = path:sub(1, 1) == "/" and path:sub(2) or
   directory .. path
   for part in combined:gmatch("[^/]+") do
      if part == ".." then
         if #parts == 0 then
            return nil
         end
         table.remove(parts)
      elseif part ~= "." and part ~= "" then
         table.insert(parts, part)
      end
   end
   return table.concat(parts, "/")
end

function SiteValidator.validate(
   output,
   base,
   files)

   local root = base or "/"
   if root:sub(1, 1) ~= "/" then
      root = "/" .. root
   end
   if root:sub(-1) ~= "/" then
      root = root .. "/"
   end

   local anchors = {}
   local function anchors_for(path)
      if anchors[path] then
         return anchors[path]
      end
      local found = {}
      local file = io.open(output .. "/" .. path, "r")
      if file then
         local html = file:read("*a")
         file:close()
         for id in html:gmatch('%sid="([^"]+)"') do
            found[id] = true
         end
         for id in html:gmatch("%sid='([^']+)'") do
            found[id] = true
         end
      end
      anchors[path] = found
      return found
   end

   local errors = {}
   for _, source_path in ipairs(files) do
      if source_path:match("%.html$") then
         local source = source_path:sub(#output + 2)
         local html = read_file(source_path)
         local source_directory = source:match("^(.*[/])") or ""
         local function check(href)
            href = href:gsub("&amp;", "&")
            if href == "" or
               href:sub(1, 2) == "//" or
               href:match("^[%a][%w+%.%-]*:") then

               return
            end

            local without_query = href:gsub("%?[^#]*", "")
            local path, fragment = without_query:match("^([^#]*)#?(.*)$")
            local absolute = path:sub(1, 1) == "/"
            if absolute then
               if root ~= "/" and path:sub(1, #root) ~= root then
                  table.insert(
                  errors,
                  source .. ": link escapes configured base: " .. href)

                  return
               end
               path = root == "/" and path:sub(2) or
               path:sub(#root + 1)
            end
            local normalized
            if path == "" then
               normalized = absolute and "index.html" or source
            else
               normalized = normalized_relative_path(
               absolute and "" or source_directory,
               path)

            end
            if not normalized then
               table.insert(errors, source .. ": unsafe link: " .. href)
               return
            end
            if path ~= "" and path:sub(-1) == "/" then
               normalized = normalized == "" and
               "index.html" or
               normalized .. "/index.html"
            elseif not normalized:match("%.[^/]+$") then
               normalized = normalized .. "/index.html"
            end

            local target = io.open(output .. "/" .. normalized, "r")
            if not target then
               table.insert(errors, source .. ": missing link target " .. href)
               return
            end
            target:close()
            if fragment ~= "" and
               normalized:match("%.html$") and
               not anchors_for(normalized)[fragment] then

               table.insert(errors, source .. ": missing anchor " .. href)
            end
         end
         for href in html:gmatch('href="([^"]*)"') do
            check(href)
         end
         for href in html:gmatch("href='([^']*)'") do
            check(href)
         end
      end
   end
   table.sort(errors)
   assert(
   #errors == 0,
   "site link validation failed:\n" .. table.concat(errors, "\n"))

end

return SiteValidator
