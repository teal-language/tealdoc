local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local default_css = require("tealdoc.generator.site.default_css")
local default_js = require("tealdoc.generator.site.default_js")
local pico_css = require("tealdoc.generator.site.pico_css")
local Highlighter = require("tealdoc.generator.site.highlighter")
local PageTemplate = require("tealdoc.generator.site.page_template")
local lfs = require("lfs")

local SiteGenerator = { Link = {}, Feature = {}, HeadEntry = {}, Page = {}, Example = {}, Settings = {}, Context = {} }

































































































































local function read_file(path)
   local file = assert(io.open(path, "rb"), "Could not open " .. path)
   local contents = assert(file:read("*a"), "Could not read " .. path)
   file:close()
   return contents
end

local function append_custom_css(css, custom)
   local imports = {}
   while true do
      local first, last, statement = custom:find(
      "^%s*(@import%s+[^;]+;)")

      if not first then
         break
      end
      table.insert(imports, statement)
      custom = custom:sub(last + 1)
   end
   local prefix = ""
   if #imports > 0 then
      prefix = table.concat(imports, "\n") .. "\n\n"
   end
   return prefix .. css .. "\n" .. custom:gsub("^%s+", "")
end

local function write_file(path, contents)
   local file = assert(io.open(path, "wb"), "Could not write " .. path)
   file:write(contents)
   file:close()
end

local function mkdir_p(path)
   local separator = package.config:sub(1, 1)
   local current = path:match("^[/\\]") and separator or ""
   for part in path:gmatch("[^/\\]+") do
      if current == "" or current == separator then
         current = current .. part
      else
         current = current .. separator .. part
      end
      lfs.mkdir(current)
   end
end

local function join_path(directory, path)
   if path:match("^[/\\]") or
      path:match("^%a:[/\\]") or
      directory == "" or
      directory == "." then

      return path
   end
   local separator = package.config:sub(1, 1)
   return directory:gsub("[/\\]+$", "") .. separator .. path
end

local function resolve_file_path(directory, path, name)
   assert(type(path) == "string" and path ~= "", name .. " must be a non-empty string")
   return join_path(directory, path)
end

local function validate_keys(
   values,
   allowed,
   name)

   assert(type(values) == "table", name .. " must be a table")
   for key in pairs(values) do
      assert(
      type(key) == "string" and allowed[key],
      "unknown " .. name .. " setting: " .. tostring(key))

   end
end

local function validate_optional_string(values, key)
   assert(
   values[key] == nil or type(values[key]) == "string",
   "tealdoc.site." .. key .. " must be a string")

end

local function validate_optional_table(
   values,
   key)

   assert(
   values[key] == nil or type(values[key]) == "table",
   "tealdoc.site." .. key .. " must be a table")

end

local function validate_optional_boolean(values, key)
   assert(
   values[key] == nil or type(values[key]) == "boolean",
   "tealdoc.site." .. key .. " must be a boolean")

end

local site_keys = {
   title = true,
   name = true,
   description = true,
   language = true,
   base = true,
   site_url = true,
   logo = true,
   github = true,
   show_markdown_link = true,
   favicon = true,
   public = true,
   cname = true,
   head = true,
   author = true,
   social_image = true,
   twitter_site = true,
   sitemap = true,
   robots = true,
   not_found = true,
   custom_css = true,
   templates = true,
   copyright = true,
   license = true,
   footer_links = true,
   redirects = true,
   examples = true,
   validate_links = true,
   pages = true,
   nav = true,
   sources = true,
   before_build = true,
   after_build = true,
}

local page_keys = {
   path = true,
   title = true,
   description = true,
   source = true,
   api = true,
   public = true,
   layout = true,
   hero_title = true,
   hero_text = true,
   hero_image = true,
   hero_image_alt = true,
   hero_actions = true,
   features = true,
   example_source = true,
   example_language = true,
   canonical = true,
   image = true,
   noindex = true,
}

local example_keys = {
   path = true,
   attach_to = true,
   region = true,
   title = true,
   description = true,
   source = true,
   language = true,
   check = true,
}

local link_keys = {
   text = true,
   path = true,
   theme = true,
}

local feature_keys = {
   title = true,
   details = true,
   icon = true,
   image = true,
}

local head_entry_keys = {
   tag = true,
   attributes = true,
}

local function normalize_base(base)
   if base == nil or base == "" then
      return "/"
   end
   assert(type(base) == "string", "tealdoc.site.base must be a string")
   local normalized = (base):gsub("\\", "/")
   assert(
   normalized:sub(1, 1) == "/",
   "tealdoc.site.base must begin with '/'")

   normalized = normalized:gsub("/+", "/")
   if normalized:sub(-1) ~= "/" then
      normalized = normalized .. "/"
   end
   for segment in normalized:gmatch("[^/]+") do
      assert(
      segment ~= "." and segment ~= "..",
      "tealdoc.site.base contains an unsafe path segment")

   end
   return normalized
end

local function normalize_route(
   route,
   name,
   allow_empty)

   assert(type(route) == "string", name .. " must be a string")
   local normalized = (route):gsub("\\", "/")
   assert(
   not normalized:find("[?#]"),
   name .. " must not contain a query or fragment")

   assert(
   not normalized:find("[%z\1-\31\127]"),
   name .. " must not contain control characters")

   normalized = normalized:gsub("^/+", ""):gsub("/+$", ""):gsub("/+", "/")
   assert(allow_empty or normalized ~= "", name .. " must not be empty")
   for segment in normalized:gmatch("[^/]+") do
      assert(
      segment ~= "." and segment ~= "..",
      name .. " contains an unsafe path segment: " .. (route))

   end
   return normalized
end

local function validate_link(link, name)
   validate_keys(link, link_keys, name)
   local values = link
   assert(
   type(values["text"]) == "string" and values["text"] ~= "",
   name .. ".text is required")

   assert(
   type(values["path"]) == "string",
   name .. ".path is required")

end

local function configured_settings(
   raw,
   config_directory)

   validate_keys(raw, site_keys, "tealdoc.site")
   local values = raw
   assert(
   type(values["title"]) == "string" and values["title"] ~= "",
   "tealdoc.site.title is required")

   validate_optional_boolean(values, "show_markdown_link")
   for _, key in ipairs({
         "name",
         "description",
         "language",
         "site_url",
         "logo",
         "github",
         "favicon",
         "public",
         "cname",
         "author",
         "social_image",
         "twitter_site",
         "custom_css",
         "templates",
         "copyright",
         "license",
      }) do
      validate_optional_string(values, key)
   end
   for _, key in ipairs({
         "redirects",
         "examples",
         "pages",
         "nav",
         "sources",
         "head",
         "footer_links",
         "not_found",
      }) do
      validate_optional_table(values, key)
   end
   for _, key in ipairs({
         "sitemap",
         "robots",
         "validate_links",
      }) do
      validate_optional_boolean(values, key)
   end
   assert(
   values["before_build"] == nil or
   type(values["before_build"]) == "function",
   "tealdoc.site.before_build must be a function")

   assert(
   values["after_build"] == nil or
   type(values["after_build"]) == "function",
   "tealdoc.site.after_build must be a function")


   local directory = config_directory or "."
   local settings = {
      title = values["title"],
      name = (values["name"] == nil and
      values["title"] or
      values["name"]),
      description = (values["description"] or ""),
      language = (values["language"] or "en"),
      base = normalize_base(values["base"]),
      site_url = values["site_url"],
      logo = values["logo"],
      github = values["github"],
      show_markdown_link = (values["show_markdown_link"] or false),
      favicon = values["favicon"],
      public = values["public"] and
      resolve_file_path(
      directory,
      values["public"],
      "tealdoc.site.public") or

      nil,
      cname = values["cname"],
      head = {},
      author = values["author"],
      social_image = values["social_image"],
      twitter_site = values["twitter_site"],
      sitemap = values["sitemap"] == nil and
      values["site_url"] ~= nil or
      values["sitemap"],
      robots = values["robots"] ~= false,
      not_found = nil,
      custom_css = values["custom_css"] and
      resolve_file_path(
      directory,
      values["custom_css"],
      "tealdoc.site.custom_css") or

      nil,
      templates = values["templates"] and
      resolve_file_path(
      directory,
      values["templates"],
      "tealdoc.site.templates") or

      nil,
      copyright = values["copyright"],
      license = values["license"],
      footer_links = {},
      redirects = {},
      examples = {},
      validate_links = values["validate_links"] ~= false,
      pages = {},
      nav = {},
      sources = {},
      before_build = values["before_build"],
      after_build = values["after_build"],
   }

   assert(type(settings.name) == "string", "tealdoc.site.name must be a string")
   assert(
   type(settings.description) == "string",
   "tealdoc.site.description must be a string")

   if settings.site_url and settings.site_url ~= "" then
      assert(
      settings.site_url:match("^https?://[^/%?#]+/?$"),
      "tealdoc.site.site_url must be an HTTP origin without a path")

      settings.site_url = settings.site_url:gsub("/+$", "")
   end
   for index, entry in ipairs(values["head"] or {}) do
      local name = "tealdoc.site.head[" .. tostring(index) .. "]"
      validate_keys(entry, head_entry_keys, name)
      local head_entry = entry
      assert(
      type(head_entry["tag"]) == "string",
      name .. ".tag is required")

      assert(
      type(head_entry["attributes"]) == "table",
      name .. ".attributes is required")

      table.insert(settings.head, entry)
   end
   for _, source in ipairs(values["sources"] or {}) do
      table.insert(
      settings.sources,
      resolve_file_path(directory, source, "tealdoc.site.sources entry"))

   end
   for index, link in ipairs(values["nav"] or {}) do
      validate_link(link, "tealdoc.site.nav[" .. tostring(index) .. "]")
      table.insert(settings.nav, link)
   end
   for index, link in ipairs(values["footer_links"] or {}) do
      validate_link(
      link,
      "tealdoc.site.footer_links[" .. tostring(index) .. "]")

      table.insert(settings.footer_links, link)
   end
   for index, page_value in ipairs(values["pages"] or {}) do
      local name = "tealdoc.site.pages[" .. tostring(index) .. "]"
      validate_keys(page_value, page_keys, name)
      local page = page_value
      assert(
      type(page["title"]) == "string" and page["title"] ~= "",
      name .. ".title is required")

      for _, key in ipairs({
            "description",
            "source",
            "api",
            "public",
            "layout",
            "hero_title",
            "hero_text",
            "hero_image",
            "hero_image_alt",
            "example_source",
            "example_language",
            "canonical",
            "image",
         }) do
         assert(
         page[key] == nil or type(page[key]) == "string",
         name .. "." .. key .. " must be a string")

      end
      assert(
      page["hero_actions"] == nil or
      type(page["hero_actions"]) == "table",
      name .. ".hero_actions must be a table")

      assert(
      page["features"] == nil or type(page["features"]) == "table",
      name .. ".features must be a table")

      assert(
      page["noindex"] == nil or type(page["noindex"]) == "boolean",
      name .. ".noindex must be a boolean")

      local normalized_values = {}
      for key, value in pairs(page) do
         normalized_values[key] = value
      end
      local normalized = normalized_values
      normalized.path = normalize_route(
      page["path"] or "",
      name .. ".path",
      true)

      if page["source"] then
         normalized.source = resolve_file_path(
         directory,
         page["source"],
         name .. ".source")

      end
      for action_index, action in ipairs(
         page["hero_actions"] or {}) do

         validate_link(
         action,
         name .. ".hero_actions[" .. tostring(action_index) .. "]")

      end
      for feature_index, feature in ipairs(
         page["features"] or {}) do

         local feature_name = name ..
         ".features[" ..
         tostring(feature_index) ..
         "]"
         validate_keys(feature, feature_keys, feature_name)
         local feature_values = feature
         assert(
         type(feature_values["title"]) == "string" and
         feature_values["title"] ~= "",
         feature_name .. ".title is required")

      end
      table.insert(settings.pages, normalized)
   end
   for index, example_value in ipairs(values["examples"] or {}) do
      local name = "tealdoc.site.examples[" .. tostring(index) .. "]"
      validate_keys(example_value, example_keys, name)
      local example = example_value
      local has_path = type(example["path"]) == "string" and
      example["path"] ~= ""
      local has_attachment = type(example["attach_to"]) == "string" and
      example["attach_to"] ~= ""
      assert(
      has_path ~= has_attachment,
      name .. " requires exactly one of path or attach_to")

      assert(
      has_attachment or
      type(example["title"]) == "string" and
      example["title"] ~= "",
      name .. ".title is required for a page example")

      assert(
      type(example["source"]) == "string" and example["source"] ~= "",
      name .. ".source is required")

      assert(
      example["description"] == nil or
      type(example["description"]) == "string",
      name .. ".description must be a string")

      assert(
      example["language"] == nil or
      type(example["language"]) == "string",
      name .. ".language must be a string")

      assert(
      example["region"] == nil or type(example["region"]) == "string",
      name .. ".region must be a string")

      assert(
      example["check"] == nil or type(example["check"]) == "boolean",
      name .. ".check must be a boolean")

      local normalized_values = {}
      for key, value in pairs(example) do
         normalized_values[key] = value
      end
      local normalized = normalized_values
      if has_path then
         normalized.path = normalize_route(
         example["path"],
         name .. ".path",
         false)

      end
      normalized.source = resolve_file_path(
      directory,
      example["source"],
      name .. ".source")

      table.insert(settings.examples, normalized)
   end
   if values["not_found"] ~= nil then
      local name = "tealdoc.site.not_found"
      validate_keys(values["not_found"], page_keys, name)
      local configured = values["not_found"]
      local normalized_values = {}
      for key, value in pairs(configured) do
         normalized_values[key] = value
      end
      local normalized = normalized_values
      if configured["source"] then
         normalized.source = resolve_file_path(
         directory,
         configured["source"],
         name .. ".source")

      end
      settings.not_found = normalized
   end
   assert(
   #settings.pages > 0 or #settings.examples > 0,
   "tealdoc.site.pages or tealdoc.site.examples is required")

   if values["redirects"] ~= nil then
      assert(
      type(values["redirects"]) == "table",
      "tealdoc.site.redirects must be a table")

      for source, target in pairs(values["redirects"]) do
         assert(
         type(source) == "string" and type(target) == "string",
         "tealdoc.site.redirects keys and values must be strings")

         settings.redirects[source] = target
      end
   end
   return settings
end

local function copy_public_directory(
   source,
   destination,
   files)

   local attributes = assert(
   lfs.symlinkattributes(source),
   "Could not read public path " .. source)

   assert(
   attributes.mode == "directory",
   "tealdoc.site.public must name a directory")


   local entries = {}
   for entry in lfs.dir(source) do
      if entry ~= "." and entry ~= ".." then
         table.insert(entries, entry)
      end
   end
   table.sort(entries)

   for _, entry in ipairs(entries) do
      local source_path = source .. "/" .. entry
      local destination_path = destination .. "/" .. entry
      local entry_attributes = assert(
      lfs.symlinkattributes(source_path),
      "Could not read public path " .. source_path)

      assert(
      entry_attributes.mode ~= "link",
      "public assets may not contain symbolic links: " .. source_path)

      if entry_attributes.mode == "directory" then
         mkdir_p(destination_path)
         copy_public_directory(source_path, destination_path, files)
      elseif entry_attributes.mode == "file" then
         write_file(destination_path, read_file(source_path))
         table.insert(files, destination_path)
      else
         error("unsupported public asset: " .. source_path)
      end
   end
end

local function escape_html(text)
   return ((text or ""):gsub("([&<>'\"])", {
      ["&"] = "&amp;",
      ["<"] = "&lt;",
      [">"] = "&gt;",
      ["'"] = "&#39;",
      ['"'] = "&quot;",
   }))
end

local function strip_tags(text)
   local stripped = text:gsub(
   '%s*<span class="tealdoc%-kind%-badge[^"]*">.-</span>',
   "")

   stripped = stripped:gsub("<[^>]+>", "")
   stripped = stripped:gsub("&quot;", '"'):
   gsub("&#39;", "'"):
   gsub("&lt;", "<"):
   gsub("&gt;", ">"):
   gsub("&amp;", "&")
   return stripped
end

local function plain_text(html)
   return (strip_tags(html):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function slug(text)
   local value = strip_tags(text):lower()
   value = value:gsub("[^%w%s%-_%.]", "")
   value = value:gsub("[%s_%.]+", "-")
   value = value:gsub("^%-+", ""):gsub("%-+$", "")
   return value
end

local function page_url(base, path)
   local root = base or "/"
   if root:sub(-1) ~= "/" then
      root = root .. "/"
   end
   if path == "" then
      return root
   end
   return root .. path:gsub("^/+", "") .. "/"
end

local function root_file_url(base, path)
   if path:match("^https?://") or
      path:match("^data:") or
      path:sub(1, 1) == "/" then

      return path
   end
   local root = page_url(base, "")
   return root .. path:gsub("^/+", "")
end

local function absolute_url(site_url, path)
   if not path or path == "" then
      return nil
   end
   if path:match("^https?://") then
      return path
   end
   if not site_url or site_url == "" then
      return path
   end
   local origin = site_url:gsub("/+$", "")
   return origin .. "/" .. path:gsub("^/+", "")
end

local function canonical_url(
   settings,
   page)

   if page.canonical and page.canonical ~= "" then
      return absolute_url(settings.site_url, page.canonical)
   end
   if settings.site_url and settings.site_url ~= "" then
      return absolute_url(
      settings.site_url,
      page_url(settings.base, page.path))

   end
   return nil
end

local function link_url(base, path)
   if path:match("^https?://") or
      path:match("^mailto:") or
      path:sub(1, 1) == "#" then

      return path
   end
   return page_url(base, path)
end

local function markdown_url(base, path)
   local root = page_url(base, "")
   if not path or path == "" then
      return root .. "index.md"
   end
   return root .. path:gsub("^/+", ""):gsub("/+$", "") .. ".md"
end

local function source_markdown(page)
   if page.example_source then
      local code = page.example_code or read_file(page.example_source)
      local language = page.example_language
      if not language then
         language = page.example_source:match("%.tl$") and "teal" or
         page.example_source:match("%.lua$") and "lua" or
         "text"
      end
      local fence = "```"
      while code:find(fence, 1, true) do
         fence = fence .. "`"
      end
      local output = "# " .. page.title .. "\n\n"
      if page.description then
         output = output .. page.description .. "\n\n"
      end
      return output ..
      fence ..
      language ..
      "\n" ..
      code:gsub("\n*$", "") ..
      "\n" ..
      fence ..
      "\n"
   end
   if not page.source then
      return ""
   end

   local text = read_file(page.source)
   if text:sub(1, 4) == "---\n" then
      local ending = text:find("\n---\n", 5, true)
      if ending then
         text = text:sub(ending + 5)
      end
   end

   local generated = text:find("\n<!-- @generated", 1, true)
   if generated then
      text = text:sub(1, generated - 1)
   end
   return text
end

local function extract_example_region(
   code,
   source,
   region)

   if not region or region == "" then
      return code
   end

   local output = {}
   local found = 0
   local active = false
   for line in (code .. "\n"):gmatch("(.-)\n") do
      local opening = line:match("^%s*%-%-%s*#region%s+(.+)%s*$")
      local closing = line:match("^%s*%-%-%s*#endregion%s*(.-)%s*$")
      if opening then
         if opening == region then
            assert(
            not active,
            "nested example region '" .. region .. "' in " .. source)

            found = found + 1
            active = true
         end
      elseif closing ~= nil and active then
         assert(
         closing == "" or closing == region,
         "example region '" ..
         region ..
         "' in " ..
         source ..
         " closes as '" ..
         closing ..
         "'")

         active = false
      elseif active then
         table.insert(output, line)
      end
   end
   assert(
   found == 1 and not active,
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

local function pages_with_examples(
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
         assert(example.title and example.title ~= "", "example title is required")
      end
      assert(example.source and example.source ~= "", "example source is required")
      if has_path then
         assert(
         not paths[example.path],
         "example path conflicts with a page: " .. example.path)

      end
      local code = read_file(example.source)
      code = extract_example_region(code, example.source, example.region)
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

local function validated_redirects(
   pages,
   redirects)

   local routes = {}
   for _, page in ipairs(pages) do
      local original = page.path or ""
      local normalized = normalize_route(original, "page route", true)
      assert(
      routes[normalized] == nil,
      "duplicate normalized page or example route: " .. original)

      routes[normalized] = "page"
      page.path = normalized
   end

   local normalized_redirects = {}
   for source, target in pairs(redirects or {}) do
      local normalized = normalize_route(source, "redirect source", false)
      assert(
      routes[normalized] == nil,
      "duplicate normalized page, example, or redirect route: " .. source)

      routes[normalized] = "redirect"
      if not target:match("^https?://") then
         local target_route = target
         if target_route:sub(1, 1) == "/" then
            target_route = target_route:sub(2)
         end
         normalize_route(target_route, "redirect target", true)
      end
      normalized_redirects[normalized] = target
   end
   return normalized_redirects
end

local function validate_output_routes(
   pages,
   redirects,
   has_not_found)

   local outputs = {}
   local function claim(path, owner)
      assert(
      outputs[path] == nil,
      owner ..
      " conflicts with " ..
      tostring(outputs[path]) ..
      " at output path " ..
      path)

      outputs[path] = owner
   end
   for _, page in ipairs(pages) do
      local route = page.path or ""
      local owner = route == "" and "home page" or "page " .. route
      claim(route == "" and "index.html" or route .. "/index.html", owner)
      claim(route == "" and "index.md" or route .. ".md", owner)
      claim(route == "" and "llms.txt" or route .. "/llms.txt", owner)
   end
   for route in pairs(redirects or {}) do
      local path = route:match("%.html$") and
      route or
      route .. "/index.html"
      claim(path, "redirect " .. route)
   end
   if has_not_found then
      claim("404.html", "custom 404 page")
      claim("404.md", "custom 404 page")
      claim("404/llms.txt", "custom 404 page")
   end
end

local function discover_source(path, files)
   local attributes = lfs.symlinkattributes(path)
   assert(attributes, "configured Teal source does not exist: " .. path)
   assert(
   attributes.mode ~= "link",
   "configured Teal sources may not be symbolic links: " .. path)

   if attributes.mode == "file" then
      assert(
      path:match("%.tl$"),
      "configured Teal source is not a .tl file: " .. path)

      table.insert(files, path)
      return
   end
   assert(
   attributes.mode == "directory",
   "configured Teal source is not a file or directory: " .. path)

   local entries = {}
   for entry in lfs.dir(path) do
      if entry ~= "." and entry ~= ".." then
         table.insert(entries, entry)
      end
   end
   table.sort(entries)
   for _, entry in ipairs(entries) do
      local child = join_path(path, entry)
      local child_attributes = lfs.symlinkattributes(child)
      assert(
      not child_attributes or child_attributes.mode ~= "link",
      "configured Teal sources may not be symbolic links: " .. child)

      if child_attributes and child_attributes.mode == "directory" then
         discover_source(child, files)
      elseif child_attributes and
         child_attributes.mode == "file" and
         child:match("%.tl$") then

         table.insert(files, child)
      end
   end
end

function SiteGenerator.source_files(
   raw,
   config_directory)

   local settings = configured_settings(raw, config_directory)
   local files = {}
   local seen = {}
   for _, source in ipairs(settings.sources) do
      local discovered = {}
      discover_source(source, discovered)
      for _, file in ipairs(discovered) do
         if not seen[file] then
            seen[file] = true
            table.insert(files, file)
         end
      end
   end
   return files
end

local function routes_for_pages(
   pages,
   base)

   local mapped = {}
   local prefixes = {}
   for _, page in ipairs(pages) do
      if page.api then
         mapped[page.api] = page
         table.insert(prefixes, page.api)
      end
   end
   table.sort(prefixes, function(a, b)
      return #a > #b
   end)

   return function(path)
      for _, prefix in ipairs(prefixes) do
         if path == prefix or path:sub(1, #prefix + 1) == prefix .. "." then
            local page = mapped[prefix]
            local url = page_url(base, page.path)
            if path ~= prefix then
               local public = page.public or prefix
               url = url .. "#" .. public .. path:sub(#prefix + 1)
            end
            return url
         end
      end
      return nil
   end
end

local function add_type_link(
   links,
   ambiguous,
   name,
   url)

   if not name or name == "" or not url then
      return
   end
   local function add(candidate)
      if ambiguous[candidate] then
         return
      end
      if links[candidate] and links[candidate] ~= url then
         links[candidate] = nil
         ambiguous[candidate] = true
      else
         links[candidate] = url
      end
   end
   add(name)
   local basename = name:match("([%w_]+)$")
   if basename and basename ~= name then
      add(basename)
   end
end

local function type_links_for_page(
   page,
   env,
   resolver)

   local links = {}
   local ambiguous = {}
   if not page.api then
      return links
   end

   local function belongs_to_page(path)
      return path == page.api or
      path:sub(1, #page.api + 1) == page.api .. "."
   end

   local function add_reference(reference)
      local url = MarkdownGenerator.resolve_type_url(
      env,
      reference.path,
      resolver)

      add_type_link(links, ambiguous, reference.name, url)
   end

   for path, item in pairs(env.registry) do
      if belongs_to_page(path) then
         if item.kind == "type" and
            path ~= page.api and
            Generator.filter(item, env) then

            add_type_link(links, ambiguous, item.name, resolver(path))
         elseif item.kind == "function" then
            for _, param in ipairs(item.params or {}) do
               for _, reference in ipairs(param.type_references or {}) do
                  add_reference(reference)
               end
            end
            for _, result in ipairs(item.returns or {}) do
               for _, reference in ipairs(result.type_references or {}) do
                  add_reference(reference)
               end
            end
         end
      end
   end
   return links
end

local function api_markdown(
   page,
   env,
   resolver,
   attached_examples,
   attached_examples_used)

   if not page.api then
      return ""
   end

   local page_env = tealdoc.Env.init()
   page_env.registry = env.registry
   page_env.modules = { page.api }
   page_env.include_all = env.include_all
   page_env.no_warnings_on_missing = true

   local output = os.tmpname()
   MarkdownGenerator.init(output, resolver):run(page_env)
   local markdown = read_file(output)
   os.remove(output)

   for item_path, examples in pairs(attached_examples or {}) do
      local anchor = '<a id="' .. item_path .. '"></a>'
      local first, ending = markdown:find(anchor, 1, true)
      if first then
         attached_examples_used[item_path] = true
         local following = markdown:find("\n<a id=\"", ending + 1, true)
         local insertion = following or (#markdown + 1)
         local blocks = {}
         for _, example in ipairs(examples) do
            local fence = "```"
            while example.code:find(fence, 1, true) do
               fence = fence .. "`"
            end
            table.insert(
            blocks,
            "\n### " ..
            example.title ..
            "\n\n" ..
            fence ..
            example.language ..
            "\n" ..
            example.code:gsub("\n*$", "") ..
            "\n" ..
            fence ..
            "\n")

         end
         markdown = markdown:sub(1, insertion - 1) ..
         table.concat(blocks) ..
         markdown:sub(insertion)
      end
   end

   local module_anchor = '<a id="' .. page.api .. '"></a>'
   local _, ending = markdown:find(module_anchor, 1, true)
   if ending then
      markdown = markdown:sub(ending + 1)
   end
   if page.public and page.public ~= page.api then
      markdown = markdown:gsub(
      page.api:gsub("([^%w])", "%%%1"),
      page.public)

   end

   markdown = "\n" .. markdown
   markdown = markdown:gsub("\n(##+) ", function(level)
      return "\n#" .. level .. " "
   end)
   return markdown:sub(2)
end

local function api_item_text(
   item,
   env)

   if item.text and item.text ~= "" then
      return item.text
   end
   for _, child_path in ipairs(item.children or {}) do
      local child = env.registry[child_path]
      if child and child.text and child.text ~= "" then
         return child.text
      end
   end
   return ""
end

local function api_item_summary(
   item,
   env)

   local text = api_item_text(item, env)
   if text == "" then
      return "—"
   end
   text = text:gsub("```[%s%S]-```", " ")
   text = text:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
   text = text:gsub("`([^`]*)`", "%1")
   text = text:gsub("<[^>]+>", " ")
   text = text:gsub("[%*~]", "")
   text = text:gsub("^%s*#+%s*", "")
   text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

   for index = 1, #text do
      local character = text:sub(index, index)
      local following = text:sub(index + 1, index + 1)
      if (character == "." or character == "!" or character == "?") and
         (following == "" or following:match("%s")) then

         text = text:sub(1, index)
         break
      end
   end

   local maximum = 120
   if #text > maximum then
      local shortened = text:sub(1, maximum - 3)
      shortened = shortened:match("^(.*)%s+%S*$") or shortened
      text = shortened:gsub("%s+$", "") .. "..."
   end
   return (text:gsub("\\", "\\\\"):gsub("|", "\\|"))
end

local function api_summary_markdown(
   page,
   env,
   resolver)

   if not page.api then
      return ""
   end
   local module = env.registry[page.api]
   if not module or not module.children then
      return ""
   end

   local items = {}
   for _, path in ipairs(module.children) do
      local item = env.registry[path]
      if item and Generator.filter(item, env) then
         table.insert(items, item)
      end
   end
   table.sort(items, function(a, b)
      local left = a.name:lower()
      local right = b.name:lower()
      if left == right then
         return a.path < b.path
      end
      return left < right
   end)
   if #items == 0 then
      return ""
   end

   local output = {
      "| API | Kind | Description |\n",
      "| --- | --- | --- |\n",
   }
   for _, item in ipairs(items) do
      local url = resolver(item.path) or "#" .. item.path
      local kind = Generator.item_kind(item, env)
      table.insert(
      output,
      "| [`" ..
      item.name ..
      "`](" ..
      url ..
      ') | <span class="tealdoc-kind-badge tealdoc-kind-' ..
      kind ..
      '">' ..
      kind ..
      "</span> | " ..
      api_item_summary(item, env) ..
      " |\n")

   end
   return table.concat(output)
end

local admonition_kinds = {
   ["danger"] = "Danger",
   ["info"] = "Info",
   ["note"] = "Note",
   ["tip"] = "Tip",
   ["warning"] = "Warning",
}

local function site_div(
   content,
   attributes)

   local classes = attributes and attributes.class or ""
   local kind
   local title
   kind, title = classes:match("^([%w_-]+)%s*(.-)%s*$")
   if kind == "details" then
      if title == "" then
         title = "Details"
      end
      return {
         '<details class="tealdoc-details"><summary>' ..
         escape_html(title) ..
         '</summary><div class="tealdoc-details-content">',
         content,
         "</div></details>",
      }
   elseif kind == "code-group" then
      return {
         '<div class="tealdoc-code-group" role="group">',
         content,
         "</div>",
      }
   elseif kind == "tealdoc-code-label" then
      return {
         '<figure class="tealdoc-labeled-code"><figcaption>' ..
         escape_html(title) ..
         "</figcaption>",
         content,
         "</figure>",
      }
   end
   if kind and admonition_kinds[kind] then
      if title == "" then
         title = admonition_kinds[kind]
      end
      if kind == "info" then
         kind = "note"
      end
      return {
         '<aside class="tealdoc-admonition tealdoc-admonition-' ..
         escape_html(kind) ..
         '" role="note"><p class="tealdoc-admonition-title">' ..
         escape_html(title) ..
         "</p>",
         content,
         "</aside>",
      }
   end

   local class_attribute = classes ~= "" and
   ' class="' .. escape_html(classes) .. '"' or
   ""
   local id_attribute = attributes and
   attributes.id and
   ' id="' .. escape_html(attributes.id) .. '"' or
   ""
   return { "<div" .. id_attribute .. class_attribute .. ">", content, "</div>" }
end

local github_admonition_kinds = {
   ["CAUTION"] = "danger",
   ["IMPORTANT"] = "important",
   ["NOTE"] = "note",
   ["TIP"] = "tip",
   ["WARNING"] = "warning",
}

local function rope_to_string(rope)
   local output = {}
   local walk
   walk = function(value)
      local value_type = type(value)
      if value_type == "table" then
         for _, child in ipairs(value) do
            walk(child)
         end
      elseif value_type == "function" then
         local callback = value
         local ok
         local result
         ok, result = pcall(callback)
         if ok then
            walk(result)
         end
      elseif value ~= nil then
         table.insert(output, tostring(value))
      end
   end
   walk(rope)
   return table.concat(output)
end

local function site_blockquote(content)
   local rendered = rope_to_string(content)
   local marker
   local body
   marker, body = rendered:match("^%s*%[!([A-Z]+)%]%s*(.*)$")
   if not marker then
      local paragraph
      local following
      marker, paragraph, following = rendered:match(
      "^%s*<p>%s*%[!([A-Z]+)%]%s*(.-)</p>(.*)$")

      if marker then
         body = paragraph .. following
      end
   end
   local kind = marker and github_admonition_kinds[marker]
   if not kind then
      return { "<blockquote>", content, "</blockquote>" }
   end
   local title = marker:sub(1, 1) .. marker:sub(2):lower()
   return {
      '<aside class="tealdoc-admonition tealdoc-admonition-' ..
      kind ..
      '" role="note"><p class="tealdoc-admonition-title">' ..
      title ..
      "</p>",
      body,
      "</aside>",
   }
end

local function mark_inline_code_spacing(rendered)
   local output = {}
   local position = 1
   while true do
      local opening_start, opening_end = rendered:find(
      "<code>",
      position,
      true)

      if not opening_start then
         table.insert(output, rendered:sub(position))
         break
      end
      local closing_start, closing_end = rendered:find(
      "</code>",
      opening_end + 1,
      true)

      if not closing_start then
         table.insert(output, rendered:sub(position))
         break
      end

      table.insert(output, rendered:sub(position, opening_start - 1))
      local classes = {}
      if strip_tags(rendered:sub(1, opening_start - 1)):match("%S") then
         table.insert(classes, "tealdoc-inline-code-before")
      end
      if strip_tags(rendered:sub(closing_end + 1)):match("%S") then
         table.insert(classes, "tealdoc-inline-code-after")
      end
      if #classes > 0 then
         table.insert(
         output,
         '<code class="' .. table.concat(classes, " ") .. '">')

      else
         table.insert(output, "<code>")
      end
      table.insert(
      output,
      rendered:sub(opening_end + 1, closing_end))

      position = closing_end + 1
   end
   return table.concat(output)
end

local function site_paragraph(content)
   return {
      "<p>",
      mark_inline_code_spacing(rope_to_string(content)),
      "</p>",
   }
end

local function markdown_html(
   markdown,
   type_links)

   local prepared = {}
   local fence
   local labeled_fence = false
   for line in (markdown .. "\n"):gmatch("(.-)\n") do
      if fence then
         table.insert(prepared, line)
         if line:match("^%s*" .. fence .. "%s*$") then
            fence = nil
            if labeled_fence then
               table.insert(prepared, "::::")
               labeled_fence = false
            end
         end
      else
         local indentation, opening, language, label = line:match(
         "^(%s*)(`+)([%w_+%-]+)%s+%[([^%]]+)%]%s*$")

         if opening and #opening >= 3 then
            table.insert(
            prepared,
            indentation ..
            ":::: tealdoc-code-label " ..
            label)

            table.insert(prepared, indentation .. opening .. language)
            fence = opening
            labeled_fence = true
         else
            local plain_fence = line:match("^%s*(```+)")
            if plain_fence then
               fence = plain_fence
            end
            table.insert(prepared, line)
         end
      end
   end
   markdown = table.concat(prepared, "\n")

   local builder = HTMLBuilder.init({
      fenced_divs = true,
      blockquote = site_blockquote,
      div = site_div,
      paragraph = site_paragraph,
   })
   builder:md(markdown)
   local html = builder:build()
   local function highlight_code(
      language,
      links)

      html = html:gsub(
      '<pre><code class="language%-' .. language .. '">(.-)</code></pre>',
      function(code)
         code = code:gsub("&lt;", "<"):
         gsub("&gt;", ">"):
         gsub("&quot;", '"'):
         gsub("&#39;", "'"):
         gsub("&amp;", "&")
         return '<pre class="language-' ..
         language ..
         '"><code class="language-' ..
         language ..
         '">' ..
         Highlighter.highlight(code, links) ..
         "</code></pre>"
      end)

   end
   highlight_code("teal", type_links)
   highlight_code("lua")
   return html
end

local function headings(html)
   local outline = {}
   local found = {}
   local used = {}
   local parent = ""
   local outline_prefix = ""
   local with_ids = html:gsub(
   "<h([1-4])>(.-)</h%1>",
   function(level_text, content)
      local level = tonumber(level_text)
      local id = slug(content)
      if level == 4 and
         (id == "arguments" or id == "returns") and
         parent ~= "" then

         id = parent .. "-" .. id
      end
      if id == "" then
         id = "section"
      end
      used[id] = (used[id] or 0) + 1
      if used[id] > 1 then
         id = id .. "-" .. tostring(used[id])
      end
      if level == 2 or level == 3 then
         parent = id
         local title = strip_tags(content)
         local outline_title = title
         if level == 2 then
            outline_prefix = ""
         elseif outline_prefix ~= "" and
            title:sub(1, #outline_prefix + 1) ==
            outline_prefix .. "." then

            outline_title = "↳ " ..
            title:sub(#outline_prefix + 2)
         else
            outline_prefix = title:match("^(.*)%.") or ""
         end
         table.insert(found, {
            id = id,
            title = title,
            level = level,
         })
         table.insert(
         outline,
         '<li class="level-' ..
         level_text ..
         '"><a href="#' ..
         escape_html(id) ..
         '\" title=\"' ..
         escape_html(title) ..
         '\" aria-label=\"' ..
         escape_html(title) ..
         '">' ..
         escape_html(outline_title) ..
         "</a></li>")

      end

      local label = "Permalink to " .. strip_tags(content)
      return "<h" ..
      level_text ..
      ' id="' ..
      escape_html(id) ..
      '" tabindex="-1">' ..
      content ..
      '<a class="tealdoc-header-anchor" href="#' ..
      escape_html(id) ..
      '" aria-label="' ..
      escape_html(label) ..
      '"><span aria-hidden="true">#</span></a></h' ..
      level_text ..
      ">"
   end)

   return with_ids, table.concat(outline, "\n"), found
end

local function navigation(
   links,
   current,
   base)

   local output = {}
   for _, link in ipairs(links or {}) do
      local selected = link.path == current and ' aria-current="page"' or ""
      table.insert(
      output,
      '<a href="' ..
      escape_html(page_url(base, link.path)) ..
      '"' ..
      selected ..
      ">" ..
      escape_html(link.text) ..
      "</a>")

   end
   return table.concat(output, "\n")
end

local function sidebar_page(
   page,
   current,
   base)

   local selected = page.path == current and ' aria-current="page"' or ""
   return '<li><a href="' ..
   escape_html(page_url(base, page.path)) ..
   '"' ..
   selected ..
   ">" ..
   escape_html(page.title) ..
   "</a></li>"
end

local function group_title(path)
   local title = path:gsub("[_-]+", " ")
   return title:sub(1, 1):upper() .. title:sub(2)
end

local function sidebar(
   pages,
   current,
   base)

   local output = {}
   local groups = {}
   local group_order = {}
   for _, page in ipairs(pages) do
      if page.path and page.path ~= "" then
         local group = page.path:match("^([^/]+)/")
         if group then
            if not groups[group] then
               groups[group] = {}
               table.insert(group_order, group)
            end
            table.insert(groups[group], page)
         else
            table.insert(output, sidebar_page(page, current, base))
         end
      end
   end
   for _, group in ipairs(group_order) do
      local children = {}
      for _, page in ipairs(groups[group]) do
         table.insert(children, sidebar_page(page, current, base))
      end
      table.insert(
      output,
      '<li class="tealdoc-sidebar-section"><details open><summary>' ..
      escape_html(group_title(group)) ..
      "</summary><ul>" ..
      table.concat(children, "\n") ..
      "</ul></details></li>")

   end
   return table.concat(output, "\n")
end

local function breadcrumbs(
   page,
   pages,
   base)

   if not page.path or page.path == "" then
      return ""
   end

   local pages_by_path = {}
   for _, candidate in ipairs(pages) do
      pages_by_path[candidate.path or ""] = candidate
   end

   local items = {
      '<li><a href="' ..
      escape_html(page_url(base, "")) ..
      '">Home</a></li>',
   }
   local segments = {}
   for segment in page.path:gmatch("[^/]+") do
      table.insert(segments, segment)
   end
   local path = ""
   for index, segment in ipairs(segments) do
      path = path == "" and segment or path .. "/" .. segment
      if index == #segments then
         table.insert(
         items,
         '<li><span aria-current="page">' ..
         escape_html(page.title) ..
         "</span></li>")

      else
         local ancestor = pages_by_path[path]
         if ancestor then
            table.insert(
            items,
            '<li><a href="' ..
            escape_html(page_url(base, ancestor.path)) ..
            '">' ..
            escape_html(ancestor.title) ..
            "</a></li>")

         else
            table.insert(
            items,
            "<li><span>" ..
            escape_html(group_title(segment)) ..
            "</span></li>")

         end
      end
   end
   return '<nav class="tealdoc-breadcrumbs" aria-label="Breadcrumb"><ol>' ..
   table.concat(items) ..
   "</ol></nav>"
end

local function search_dialog(search_index_url)
   return [[
<dialog class="tealdoc-search-dialog" aria-label="Search documentation" data-tealdoc-search-index="]] ..
   escape_html(search_index_url) ..
   [[">
<section class="tealdoc-search-panel">
<header><label><span aria-hidden="true">⌕</span><input type="search" placeholder="Search documentation" autocomplete="off" aria-label="Search documentation"></label><button type="button" data-tealdoc-search-close aria-label="Close search">Esc</button></header>
<nav class="tealdoc-search-results" aria-live="polite"></nav>
</section>
</dialog>
]]
end

local function page_navigation(
   page,
   pages,
   base)

   local previous
   local following
   for index, candidate in ipairs(pages) do
      if candidate == page then
         previous = pages[index - 1]
         following = pages[index + 1]
         break
      end
   end
   if not previous and not following then
      return ""
   end

   local output = {
      '<nav class="tealdoc-page-nav" aria-label="Adjacent pages">',
   }
   if previous then
      table.insert(
      output,
      '<a class="previous" href="' ..
      escape_html(page_url(base, previous.path)) ..
      '"><span>Previous page</span><strong>← ' ..
      escape_html(previous.title) ..
      "</strong></a>")

   else
      table.insert(output, "<span></span>")
   end
   if following then
      table.insert(
      output,
      '<a class="next" href="' ..
      escape_html(page_url(base, following.path)) ..
      '"><span>Next page</span><strong>' ..
      escape_html(following.title) ..
      " →</strong></a>")

   end
   table.insert(output, "</nav>")
   return table.concat(output)
end

local safe_head_attributes = {
   ["link"] = {
      ["as"] = true,
      ["crossorigin"] = true,
      ["href"] = true,
      ["hreflang"] = true,
      ["media"] = true,
      ["referrerpolicy"] = true,
      ["rel"] = true,
      ["sizes"] = true,
      ["title"] = true,
      ["type"] = true,
   },
   ["meta"] = {
      ["content"] = true,
      ["name"] = true,
      ["property"] = true,
   },
}

local function custom_head_entry(entry)
   assert(
   entry.tag == "link" or entry.tag == "meta",
   "tealdoc.site.head entries must use the link or meta tag")

   assert(
   type(entry.attributes) == "table",
   "tealdoc.site.head entry attributes must be a table")

   local allowed = safe_head_attributes[entry.tag]
   local names = {}
   for name, value in pairs(entry.attributes) do
      assert(
      allowed[name] == true,
      "unsafe " .. entry.tag .. " head attribute: " .. tostring(name))

      assert(
      type(value) == "string",
      "head attribute values must be strings")

      assert(
      not value:find("[%z\1-\31]"),
      "head attribute values may not contain control characters")

      if name == "href" then
         assert(
         not value:lower():match("^%s*javascript:"),
         "javascript URLs are not allowed in head entries")

      end
      table.insert(names, name)
   end
   table.sort(names)
   if entry.tag == "link" then
      assert(
      entry.attributes.rel and entry.attributes.href,
      "link head entries require rel and href")

   else
      assert(
      entry.attributes.content and
      (
      entry.attributes.name or
      entry.attributes.property),

      "meta head entries require content and name or property")

   end

   local output = { "<", entry.tag }
   for _, name in ipairs(names) do
      table.insert(
      output,
      " " ..
      name ..
      '="' ..
      escape_html(entry.attributes[name]) ..
      '"')

   end
   table.insert(output, ">")
   return table.concat(output)
end

local function page_head(
   settings,
   page)

   local output = {}
   local description = page.description or settings.description or ""
   local canonical = canonical_url(settings, page)
   local markdown = markdown_url(settings.base, page.path)
   local image = page.image or settings.social_image

   if settings.favicon and settings.favicon ~= "" then
      table.insert(
      output,
      '<link rel="icon" href="' ..
      escape_html(root_file_url(settings.base, settings.favicon)) ..
      '">')

   end
   if canonical then
      table.insert(
      output,
      '<link rel="canonical" href="' ..
      escape_html(canonical) ..
      '">')

   end
   table.insert(
   output,
   '<link rel="alternate" type="text/markdown" href="' ..
   escape_html(absolute_url(settings.site_url, markdown)) ..
   '" title="' ..
   escape_html(page.title .. " as Markdown") ..
   '">')

   if settings.author and settings.author ~= "" then
      table.insert(
      output,
      '<meta name="author" content="' ..
      escape_html(settings.author) ..
      '">')

   end
   if page.noindex then
      table.insert(output, '<meta name="robots" content="noindex, nofollow">')
   end
   table.insert(
   output,
   '<meta property="og:site_name" content="' ..
   escape_html(settings.title) ..
   '">')

   table.insert(
   output,
   '<meta property="og:title" content="' ..
   escape_html(page.title) ..
   '">')

   table.insert(
   output,
   '<meta property="og:description" content="' ..
   escape_html(description) ..
   '">')

   table.insert(
   output,
   '<meta property="og:locale" content="' ..
   escape_html(((settings.language or "en"):gsub("%-", "_"))) ..
   '">')

   table.insert(
   output,
   '<meta property="og:type" content="' ..
   (page.layout == "home" and "website" or "article") ..
   '">')

   if canonical then
      table.insert(
      output,
      '<meta property="og:url" content="' ..
      escape_html(canonical) ..
      '">')

   end
   if image and image ~= "" then
      local image_url = absolute_url(
      settings.site_url,
      root_file_url(settings.base, image))

      table.insert(
      output,
      '<meta property="og:image" content="' ..
      escape_html(image_url) ..
      '">')

   end
   table.insert(
   output,
   '<meta name="twitter:card" content="' ..
   (image and image ~= "" and "summary_large_image" or "summary") ..
   '">')

   table.insert(
   output,
   '<meta name="twitter:title" content="' ..
   escape_html(page.title) ..
   '">')

   table.insert(
   output,
   '<meta name="twitter:description" content="' ..
   escape_html(description) ..
   '">')

   if image and image ~= "" then
      local image_url = absolute_url(
      settings.site_url,
      root_file_url(settings.base, image))

      table.insert(
      output,
      '<meta name="twitter:image" content="' ..
      escape_html(image_url) ..
      '">')

   end
   if settings.twitter_site and settings.twitter_site ~= "" then
      table.insert(
      output,
      '<meta name="twitter:site" content="' ..
      escape_html(settings.twitter_site) ..
      '">')

   end
   for _, entry in ipairs(settings.head or {}) do
      table.insert(output, custom_head_entry(entry))
   end
   return table.concat(output, "\n")
end

local function footer_items(
   settings,
   page)

   local parts = {}
   if settings.copyright then
      table.insert(
      parts,
      '<span class="tealdoc-footer-copyright">' ..
      escape_html(settings.copyright) ..
      "</span>")

   end
   if settings.license then
      table.insert(
      parts,
      '<span class="tealdoc-footer-license">' ..
      escape_html(settings.license) ..
      "</span>")

   end
   for _, link in ipairs(settings.footer_links or {}) do
      table.insert(
      parts,
      '<a class="tealdoc-footer-link" href="' ..
      escape_html(link_url(settings.base, link.path)) ..
      '">' ..
      escape_html(link.text) ..
      "</a>")

   end
   table.insert(
   parts,
   '<a class="tealdoc-footer-llms" href="' ..
   escape_html(page_url(settings.base, page.path) .. "llms.txt") ..
   '">llms.txt</a>')

   table.insert(
   parts,
   '<span class="tealdoc-footer-credit">Generated by <a href="https://github.com/teal-language/tealdoc">Tealdoc</a></span>')

   return table.concat(parts, '<span aria-hidden="true">·</span>')
end

local function icon(name)
   if name == "github" then
      return [[<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 .7a11.5 11.5 0 0 0-3.64 22.4c.58.1.79-.25.79-.56v-2.23c-3.24.7-3.92-1.38-3.92-1.38-.53-1.35-1.29-1.71-1.29-1.71-1.06-.72.08-.71.08-.71 1.17.08 1.79 1.2 1.79 1.2 1.04 1.79 2.73 1.27 3.4.97.1-.76.41-1.27.74-1.56-2.58-.29-5.3-1.29-5.3-5.7 0-1.26.45-2.29 1.2-3.1-.12-.3-.52-1.48.11-3.07 0 0 .98-.31 3.16 1.18a10.9 10.9 0 0 1 5.76 0c2.18-1.49 3.15-1.18 3.15-1.18.64 1.59.24 2.77.12 3.07.74.81 1.19 1.84 1.19 3.1 0 4.42-2.72 5.4-5.31 5.69.42.36.79 1.07.79 2.16v3.2c0 .31.21.67.8.56A11.5 11.5 0 0 0 12 .7Z"/></svg>]]
   elseif name == "markdown" then
      return [[<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M2.5 5.25h19A2.5 2.5 0 0 1 24 7.75v8.5a2.5 2.5 0 0 1-2.5 2.5h-19A2.5 2.5 0 0 1 0 16.25v-8.5a2.5 2.5 0 0 1 2.5-2.5Zm.5 3v7.5h2v-4l2 2 2-2v4h2v-7.5H9l-2 2-2-2H3Zm11 3.75h2.5v3.75h2V12H21l-3.5-3.5L14 12Z"/></svg>]]
   elseif name == "sun" then
      return [[<svg class="tealdoc-theme-icon-sun" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 4a1 1 0 0 1-1-1V1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1Zm0 19a1 1 0 0 1-1-1v-2a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1ZM4.22 5.64a1 1 0 0 1-.71-.29L2.1 3.93a1 1 0 0 1 1.41-1.41l1.42 1.41a1 1 0 0 1-.71 1.71Zm16.97 16.97a1 1 0 0 1-.71-.29l-1.41-1.42a1 1 0 0 1 1.41-1.41l1.42 1.41a1 1 0 0 1-.71 1.71ZM1 13a1 1 0 1 1 0-2h2a1 1 0 1 1 0 2H1Zm20 0a1 1 0 1 1 0-2h2a1 1 0 1 1 0 2h-2ZM2.81 22.61a1 1 0 0 1-.71-1.71l1.41-1.41a1 1 0 0 1 1.42 1.41l-1.42 1.42a1 1 0 0 1-.7.29ZM19.78 5.64a1 1 0 0 1-.71-1.71l1.41-1.41a1 1 0 0 1 1.42 1.41l-1.42 1.42a1 1 0 0 1-.7.29ZM12 18a6 6 0 1 1 0-12 6 6 0 0 1 0 12Zm0-10a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z"/></svg>]]
   elseif name == "moon" then
      return [[<svg class="tealdoc-theme-icon-moon" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M21.64 15.36A9 9 0 0 1 8.64 2.36 10 10 0 1 0 21.64 15.36ZM12 22A8 8 0 0 1 7.45 7.42a11 11 0 0 0 9.13 9.13A7.94 7.94 0 0 1 12 22Z"/></svg>]]
   end
   return ""
end

local function brand(settings)
   local contents = {}
   if settings.logo then
      table.insert(
      contents,
      '<img class="tealdoc-logo" src="' ..
      escape_html(settings.logo) ..
      '" alt="">')

   end
   local name = settings.name
   if name == nil then
      name = settings.title
   end
   if name ~= "" then
      table.insert(
      contents,
      '<span class="tealdoc-brand-name">' ..
      escape_html(name) ..
      "</span>")

   end
   return '<a class="tealdoc-brand" href="' ..
   escape_html(page_url(settings.base, "")) ..
   '">' ..
   table.concat(contents) ..
   "</a>"
end

local function header_actions(
   settings,
   page)

   local output = {}
   if settings.show_markdown_link then
      table.insert(
      output,
      '<a class="tealdoc-icon-link" href="' ..
      escape_html(markdown_url(settings.base, page.path)) ..
      '" aria-label="View this page as Markdown" title="View Markdown">' ..
      icon("markdown") ..
      "</a>")

   end
   table.insert(
   output,
   '<label class="tealdoc-icon-link tealdoc-theme-toggle" for="tealdoc-theme-input" aria-label="Toggle light and dark theme" title="Toggle theme">' ..
   icon("sun") ..
   icon("moon") ..
   "</label>")

   if settings.github then
      table.insert(
      output,
      '<a class="tealdoc-icon-link" href="' ..
      escape_html(settings.github) ..
      '" aria-label="View this project on GitHub" title="GitHub">' ..
      icon("github") ..
      "</a>")

   end
   return table.concat(output, "\n")
end

local function home_hero(
   page,
   base,
   type_links)

   local hero_main_class = "tealdoc-hero-main"
   if page.hero_image and page.hero_image ~= "" then
      hero_main_class = hero_main_class .. " has-image"
   end
   local output = {
      '<section class="tealdoc-home-hero"><div class="' ..
      hero_main_class ..
      '"><div class="tealdoc-hero-copy"><h1>',
      escape_html(page.hero_title or page.title),
      "</h1>",
   }
   if page.hero_text then
      table.insert(
      output,
      '<p class="tealdoc-hero-text">' ..
      escape_html(page.hero_text) ..
      "</p>")

   end
   if page.hero_actions and #page.hero_actions > 0 then
      table.insert(output, '<div class="tealdoc-hero-actions">')
      for _, action in ipairs(page.hero_actions) do
         local theme = action.theme == "brand" and "brand" or "alt"
         table.insert(
         output,
         '<a class="tealdoc-hero-action ' ..
         theme ..
         '" href="' ..
         escape_html(link_url(base, action.path)) ..
         '">' ..
         escape_html(action.text) ..
         "</a>")

      end
      table.insert(output, "</div>")
   end
   table.insert(output, "</div>")
   if page.hero_image and page.hero_image ~= "" then
      table.insert(
      output,
      '<div class="tealdoc-hero-image"><div class="tealdoc-hero-starburst" aria-hidden="true"></div><img src="' ..
      escape_html(page.hero_image) ..
      '" alt="' ..
      escape_html(page.hero_image_alt or "") ..
      '"></div>')

   end
   table.insert(output, "</div>")
   if page.features and #page.features > 0 then
      table.insert(output, '<div class="tealdoc-features">')
      for _, feature in ipairs(page.features) do
         table.insert(output, '<section class="tealdoc-feature">')
         if feature.image and feature.image ~= "" then
            table.insert(
            output,
            '<img class="tealdoc-feature-image" src="' ..
            escape_html(feature.image) ..
            '" alt="">')

         elseif feature.icon then
            table.insert(
            output,
            '<span class="tealdoc-feature-icon" aria-hidden="true">' ..
            escape_html(feature.icon) ..
            "</span>")

         end
         table.insert(
         output,
         "<h2>" ..
         escape_html(feature.title) ..
         '</h2><div class="tealdoc-feature-details">' ..
         markdown_html(feature.details or "", type_links) ..
         "</div></section>")

      end
      table.insert(output, "</div>")
   end
   table.insert(output, "</section>")
   return table.concat(output)
end

local function render_page(
   page,
   context,
   resolver)

   local markdown = source_markdown(page)
   local api = api_markdown(
   page,
   context.env,
   resolver,
   context.attached_examples,
   context.attached_examples_used)

   if api ~= "" then
      local summary = api_summary_markdown(
      page,
      context.env,
      resolver)

      local introduction = ""
      local public_name = page.public or page.api
      if not markdown:match("%S") then
         introduction = "\n\nPublic APIs in `" .. public_name .. "`."
      end
      markdown = markdown ..
      "\n\n## " ..
      public_name ..
      " Reference" ..
      introduction ..
      "\n\n" ..
      summary ..
      "\n" ..
      api
   end

   local type_links = type_links_for_page(page, context.env, resolver)
   local content = markdown_html(markdown, type_links)
   local outline
   local page_headings
   content, outline, page_headings = headings(content)

   local settings = context.settings
   local hero_region = ""
   if page.layout == "home" then
      hero_region = home_hero(page, settings.base, type_links)
   end
   local entries = {
      {
         title = page.title,
         url = page_url(settings.base, page.path),
         text = (page.description or "") ..
         " " ..
         plain_text(hero_region .. content),
      },
   }
   for _, heading in ipairs(page_headings) do
      table.insert(entries, {
         title = page.title .. " › " .. heading.title,
         url = page_url(settings.base, page.path) .. "#" .. heading.id,
         text = heading.title .. " " .. page.title,
      })
   end

   local assets = page_url(settings.base, "assets")
   local title = page.title .. " | " .. settings.title
   local sidebar_html = sidebar(context.pages, page.path, settings.base)
   local shell_class = "tealdoc-shell"
   local content_class = "tealdoc-content"
   local sidebar_region = '<aside class="tealdoc-sidebar" aria-label="Page navigation"><ul>' ..
   sidebar_html ..
   "</ul></aside>"
   local breadcrumb_region = breadcrumbs(
   page,
   context.pages,
   settings.base)

   local mobile_outline = '<details class="tealdoc-mobile-outline"><summary>On this page</summary><ol>' ..
   outline ..
   "</ol></details>"
   local outline_region = '<aside class="tealdoc-outline" aria-label="On this page"><div class="tealdoc-outline-title">On this page</div><ol>' ..
   outline ..
   "</ol></aside>"
   local page_navigation_region = page_navigation(
   page,
   context.pages,
   settings.base)

   local content_template = "content.html"
   local footer_class = ""
   if page.layout == "home" then
      shell_class = shell_class .. " tealdoc-home-shell"
      content_class = content_class .. " tealdoc-home-content"
      sidebar_region = ""
      breadcrumb_region = ""
      mobile_outline = ""
      outline_region = ""
      page_navigation_region = ""
      footer_class = " tealdoc-home-footer"
      content_template = "home.html"
   end
   local top_navigation = navigation(
   settings.nav,
   page.path,
   settings.base)

   local html = PageTemplate.render({
      language = escape_html(settings.language or "en"),
      title = escape_html(title),
      description = escape_html(page.description or settings.description),
      head = page_head(settings, page),
      stylesheet_url = escape_html(assets .. "tealdoc.css"),
      pico_stylesheet_url = escape_html(
      assets .. "pico.classless.min.css"),

      search_index_url = escape_html(assets .. "search-index.js"),
      script_url = escape_html(assets .. "tealdoc.js"),
      brand = brand(settings),
      top_navigation = top_navigation,
      header_actions = header_actions(settings, page),
      sidebar_links = sidebar_html,
      shell_class = shell_class,
      sidebar = sidebar_region,
      content_class = content_class,
      breadcrumbs = breadcrumb_region,
      mobile_outline = mobile_outline,
      content = content,
      page_navigation = page_navigation_region,
      outline = outline_region,
      search_dialog = search_dialog(assets .. "search-index.js"),
      footer_class = footer_class,
      footer_items = footer_items(settings, page),
      home_hero = hero_region,
      content_template = content_template,
   }, settings.templates)
   return html, entries, markdown
end

local function escape_js(text)
   return (text:gsub("\\", "\\\\"):
   gsub('"', '\\"'):
   gsub("\r", "\\r"):
   gsub("\n", "\\n"):
   gsub("</", "<\\/"))
end

local function search_index_js(entries)
   local output = { "window.TEALDOC_SEARCH_INDEX = [\n" }
   for _, entry in ipairs(entries) do
      table.insert(
      output,
      '  {title:"' ..
      escape_js(entry.title) ..
      '",url:"' ..
      escape_js(entry.url) ..
      '",text:"' ..
      escape_js(entry.text) ..
      '"},\n')

   end
   table.insert(output, "];\n")
   return table.concat(output)
end

local function redirect_url(base, target)
   if target:match("^https?://") or target:sub(1, 1) == "/" then
      return target
   end
   return page_url(base, target)
end

local function redirect_html(target)
   local escaped = escape_html(target)
   return "<!DOCTYPE html>\n" ..
   '<html lang="en">\n<head>\n<meta charset="utf-8">\n' ..
   '<meta name="viewport" content="width=device-width, initial-scale=1">\n' ..
   '<meta http-equiv="refresh" content="0; url=' ..
   escaped ..
   '">\n<link rel="canonical" href="' ..
   escaped ..
   '">\n<title>Moved</title>\n</head>\n<body>\n' ..
   '<p>This page moved to <a href="' ..
   escaped ..
   '">' ..
   escaped ..
   "</a>.</p>\n</body>\n</html>\n"
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

local function validate_site_links(
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
               table.insert(
               errors,
               source .. ": missing link target " .. href)

               return
            end
            target:close()
            if fragment ~= "" and
               normalized:match("%.html$") and
               not anchors_for(normalized)[fragment] then

               table.insert(
               errors,
               source .. ": missing anchor " .. href)

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

local function sitemap_xml(
   settings,
   pages)

   local output = {
      '<?xml version="1.0" encoding="UTF-8"?>\n',
      '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n',
   }
   for _, page in ipairs(pages) do
      if not page.noindex then
         local url = canonical_url(settings, page)
         if url then
            table.insert(
            output,
            "    <url><loc>" ..
            escape_html(url) ..
            "</loc></url>\n")

         end
      end
   end
   table.insert(output, "</urlset>\n")
   return table.concat(output)
end

local function robots_txt(settings)
   local base = page_url(settings.base, "")
   local output = "User-agent: *\nAllow: " .. base .. "\n"
   if settings.site_url and
      settings.site_url ~= "" and
      settings.sitemap ~= false then

      output = output ..
      "Sitemap: " ..
      absolute_url(
      settings.site_url,
      root_file_url(settings.base, "sitemap.xml")) ..

      "\n"
   end
   return output
end

local function not_found_page(
   configured)

   return {
      path = "404",
      title = configured.title or "Page not found",
      description = configured.description or "The requested page was not found.",
      source = configured.source,
      layout = configured.layout,
      hero_title = configured.hero_title,
      hero_text = configured.hero_text,
      hero_image = configured.hero_image,
      hero_image_alt = configured.hero_image_alt,
      hero_actions = configured.hero_actions,
      features = configured.features,
      image = configured.image,
      noindex = true,
   }
end

local function valid_cname(name)
   if #name == 0 or #name > 253 or name:find("%.%.", 1, true) then
      return false
   end
   local length = 0
   for label in name:gmatch("[^%.]+") do
      length = length + #label + (length > 0 and 1 or 0)
      if #label == 0 or
         #label > 63 or
         not label:match("^[A-Za-z0-9][A-Za-z0-9%-]*[A-Za-z0-9]$") and
         not label:match("^[A-Za-z0-9]$") then

         return false
      end
   end
   return length == #name
end

function SiteGenerator.build(
   output,
   env,
   raw_settings,
   config_directory)

   local settings = configured_settings(raw_settings, config_directory)
   local pages
   local attached_examples
   pages, attached_examples = pages_with_examples(settings, env)
   settings.redirects = validated_redirects(pages, settings.redirects)

   local context = {
      output = output,
      env = env,
      settings = settings,
      pages = pages,
      attached_examples = attached_examples,
      attached_examples_used = {},
      files = {},
   }
   if settings.before_build then
      settings.before_build(context)
   end
   settings.redirects = validated_redirects(context.pages, settings.redirects)
   validate_output_routes(
   context.pages,
   settings.redirects,
   settings.not_found ~= nil)

   mkdir_p(output)
   mkdir_p(output .. "/assets")

   if settings.public then
      copy_public_directory(settings.public, output, context.files)
   end

   local css = default_css
   if settings.custom_css then
      css = append_custom_css(css, read_file(settings.custom_css))
   end
   local css_path = output .. "/assets/tealdoc.css"
   write_file(css_path, css)
   table.insert(context.files, css_path)

   local pico_path = output .. "/assets/pico.classless.min.css"
   write_file(pico_path, pico_css)
   table.insert(context.files, pico_path)

   local js_path = output .. "/assets/tealdoc.js"
   write_file(js_path, default_js)
   table.insert(context.files, js_path)

   local resolver = routes_for_pages(context.pages, settings.base)
   local search_entries = {}
   for _, page in ipairs(context.pages) do
      local directory = output
      if page.path and page.path ~= "" then
         directory = output .. "/" .. page.path:gsub("^/+", ""):gsub("/+$", "")
         mkdir_p(directory)
      end
      local path = directory .. "/index.html"
      local html
      local page_entries
      local markdown
      html, page_entries, markdown = render_page(page, context, resolver)
      write_file(path, html)
      table.insert(context.files, path)
      local markdown_path = output .. "/index.md"
      if page.path and page.path ~= "" then
         markdown_path = output ..
         "/" ..
         page.path:gsub("^/+", ""):gsub("/+$", "") ..
         ".md"
      end
      write_file(markdown_path, markdown)
      table.insert(context.files, markdown_path)
      local llms_path = directory .. "/llms.txt"
      write_file(llms_path, markdown)
      table.insert(context.files, llms_path)
      for _, entry in ipairs(page_entries) do
         table.insert(search_entries, entry)
      end
   end

   for item_path in pairs(context.attached_examples) do
      assert(
      context.attached_examples_used[item_path],
      "example attach_to is not a public API item: " .. item_path)

   end

   for old_path, target in pairs(settings.redirects or {}) do
      local path
      if old_path:match("%.html$") then
         local parent = old_path:match("^(.*)/[^/]+$")
         if parent then
            mkdir_p(output .. "/" .. parent)
         end
         path = output .. "/" .. old_path
      else
         local directory = output .. "/" .. old_path
         mkdir_p(directory)
         path = directory .. "/index.html"
      end
      write_file(path, redirect_html(redirect_url(settings.base, target)))
      table.insert(context.files, path)
   end

   if settings.not_found then
      local missing = not_found_page(settings.not_found)
      local missing_directory = output .. "/404"
      mkdir_p(missing_directory)
      local html
      local _
      local markdown
      html, _, markdown = render_page(
      missing,
      context,
      resolver)

      local html_path = output .. "/404.html"
      write_file(html_path, html)
      table.insert(context.files, html_path)
      local markdown_path = output .. "/404.md"
      write_file(markdown_path, markdown)
      table.insert(context.files, markdown_path)
      local llms_path = missing_directory .. "/llms.txt"
      write_file(llms_path, markdown)
      table.insert(context.files, llms_path)
   end

   if settings.cname then
      assert(
      valid_cname(settings.cname),
      "tealdoc.site.cname must be a bare DNS name")

      local cname_path = output .. "/CNAME"
      write_file(cname_path, settings.cname .. "\n")
      table.insert(context.files, cname_path)
   end

   if settings.site_url and
      settings.site_url ~= "" and
      settings.sitemap ~= false then

      assert(
      settings.site_url:match("^https?://[^/%?#]+/?$"),
      "tealdoc.site.site_url must be an HTTP origin without a path")

      local sitemap_path = output .. "/sitemap.xml"
      write_file(sitemap_path, sitemap_xml(settings, context.pages))
      table.insert(context.files, sitemap_path)
   end

   if settings.robots ~= false then
      local robots_path = output .. "/robots.txt"
      write_file(robots_path, robots_txt(settings))
      table.insert(context.files, robots_path)
   end

   local search_path = output .. "/assets/search-index.js"
   write_file(search_path, search_index_js(search_entries))
   table.insert(context.files, search_path)

   if settings.after_build then
      settings.after_build(context)
   end
   if settings.validate_links ~= false then
      validate_site_links(output, settings.base, context.files)
   end
end

return SiteGenerator
