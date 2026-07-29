local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local SiteTypes = require("tealdoc.generator.site.types")

local SiteConfig = {}












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

SiteConfig.join_path = join_path

local function resolve_file_path(
   directory,
   path,
   name)

   assert(
   type(path) == "string" and path ~= "",
   name .. " must be a non-empty string")

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

local function validate_optional_table(values, key)
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

SiteConfig.normalize_route = normalize_route

local function validate_link(link, name)
   validate_keys(link, link_keys, name)
   local values = link
   assert(
   type(values["text"]) == "string" and values["text"] ~= "",
   name .. ".text is required")

   assert(type(values["path"]) == "string", name .. ".path is required")
end

function SiteConfig.configure(
   raw,
   config_directory)

   validate_keys(raw, site_keys, "tealdoc.site")
   local values = raw
   assert(
   type(values["title"]) == "string" and values["title"] ~= "",
   "tealdoc.site.title is required")

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
      assert(type(head_entry["tag"]) == "string", name .. ".tag is required")
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
      for feature_index, feature in ipairs(page["features"] or {}) do
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
      example["language"] == nil or type(example["language"]) == "string",
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

return SiteConfig
