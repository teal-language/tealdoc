local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local argparse = require("argparse")
local Config = require("tealdoc.config")
local DumpTool = require("tealdoc.dump")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local HTMLGenerator = require("tealdoc.generator.html.generator")
local SiteGenerator = require("tealdoc.generator.site")
local tealdoc = require("tealdoc")
local log = require("tealdoc.log")
local tl = require("tl")






local function prefix_url_resolver(config)
   local routes = {}
   for path, url in pairs(config) do
      assert(
      type(path) == "string" and type(url) == "string",
      "Type-link route keys and values must be strings")

      table.insert(routes, { path = path, url = url })
   end
   table.sort(routes, function(a, b)
      return #a.path > #b.path
   end)

   return function(path)
      for _, route in ipairs(routes) do
         if path == route.path then
            return route.url:match("^[^#]*")
         end
         if path:sub(1, #route.path + 1) == route.path .. "." then
            return route.url .. path:sub(#route.path + 1)
         end
      end
      return nil
   end
end

local function type_url_resolver(config)
   if type(config) == "function" then
      return config
   end
   assert(
   type(config) == "table",
   "Type-link configuration must return a route table or resolver function")

   return prefix_url_resolver(config)
end

local CLI = { Command = {} }




















function CLI:add_default_commands()
   local dump_command = {
      name = "dump",
      setup = function(command)
         command:argument("files", "input files"):args("+")
      end,
      handler = function(args)
         local files = args.files
         for _, file in ipairs(files) do
            tealdoc.process_file(file, self._env)
         end
         DumpTool.run(self._env.registry)
      end,
   }

   local md_command = {
      name = "md",
      setup = function(command)
         command:argument("files", "input files"):args("+")
         command:flag("-a --all", "include all items in the documentation")
         command:flag("--no-warn-missing", "do not warn about missing items")
         command:option("-o --output", "output file"):
         default("doc.md")
      end,
      handler = function(args)
         if args["all"] then
            self._env.include_all = true
         end
         if args["no_warn_missing"] then
            self._env.no_warnings_on_missing = true
         end
         local files = args.files
         for _, file in ipairs(files) do
            tealdoc.process_file(file, self._env)
         end

         local resolver
         local settings = self._config.values
         local tealdoc_config = settings["tealdoc"]
         local markdown_config = tealdoc_config and
         tealdoc_config["markdown"]
         local type_links = markdown_config and
         markdown_config["type_links"]
         if type_links then
            resolver = type_url_resolver(type_links)
         end
         local generator = MarkdownGenerator.init(args["output"], resolver)
         generator:run(self._env)
      end,
   }
   local html_command = {
      name = "html",
      setup = function(command)
         command:argument("files", "input files"):args("+")
         command:flag("-a --all", "include all items in the documentation")
         command:flag("--no-warn-missing", "do not warn about missing items")
         command:option("-o --output", "output folder"):
         default("doc")
      end,
      handler = function(args)
         if args["all"] then
            self._env.include_all = true
         end
         if args["no_warn_missing"] then
            self._env.no_warnings_on_missing = true
         end
         local files = args.files
         for _, file in ipairs(files) do
            tealdoc.process_file(file, self._env)
         end
         local generator = HTMLGenerator.init(args["output"])
         generator:run(self._env)

      end,
   }
   local site_command = {
      name = "site",
      setup = function(command)
         command:argument("files", "Teal input files"):args("*")
         command:flag("--no-warn-missing", "do not warn about missing items")
         command:option("-o --output", "output directory"):
         default("site")
      end,
      handler = function(args)
         if args["no_warn_missing"] then
            self._env.no_warnings_on_missing = true
         end
         local loaded = self._config
         local values = loaded.values
         local tealdoc_config = values["tealdoc"]
         local site_config = tealdoc_config and
         tealdoc_config["site"]
         assert(site_config, "tlconfig.lua does not contain tealdoc.site")

         local files = SiteGenerator.source_files(
         site_config,
         loaded.directory)

         local seen = {}
         for _, file in ipairs(files) do
            seen[file] = true
            tealdoc.process_file(file, self._env)
         end
         for _, file in ipairs(args.files or {}) do
            if not seen[file] then
               seen[file] = true
               tealdoc.process_file(file, self._env)
            end
         end

         SiteGenerator.build(
         args["output"],
         self._env,
         site_config,
         loaded.directory)

      end,
   }
   self:add_command(dump_command)
   self:add_command(md_command)
   self:add_command(html_command)
   self:add_command(site_command)
end

function CLI:init(env, skip_default_commands)
   self._parser = argparse("tealdoc", nil, nil)
   self._parser:option("--plugin", "plugin to load", nil, nil, nil, "*")
   self._parser:flag("-V --version", "show version and exit"):
   target("version")
   self._parser:require_command(false)
   self._parser:command_target("command")
   self._commands = {}
   self._env = env
   if not skip_default_commands then
      self:add_default_commands()
   end
end

function CLI:add_command(command)
   assert(command.name and command.setup and command.handler)
   local c = self._parser:command(command.name, nil, nil)
   command.setup(c)
   self._commands[command.name] = command.handler
end

function CLI:_run(argv)
   local args = self._parser:parse(argv)
   if args["version"] then
      print("tealdoc " .. tealdoc.version)
      return
   end
   self._config = Config.load()
   local settings = self._config.values
   local tealdoc_config = settings["tealdoc"]
   local doc_precedence = tealdoc_config and
   tealdoc_config["doc_precedence"]
   if doc_precedence ~= nil then
      assert(
      doc_precedence == "declaration" or
      doc_precedence == "definition" or
      doc_precedence == "error",
      "tealdoc.doc_precedence must be 'declaration', " ..
      "'definition', or 'error'")

      self._env.doc_precedence =
      doc_precedence
   end
   local command_name = args["command"]

   tl.loader()
   local plugins = args["plugin"]
   if plugins then
      for _, plugin in ipairs(plugins) do
         local ok, result = pcall(require, plugin)
         if not ok then
            log:error("Failed to load plugin '" .. plugin .. "': " .. tostring(result))
         end
         print(result)
         if type(result) == "table" then
            result.run(self._env)
         else
            log:error("Plugin '" .. plugin .. "' does not implement tealdoc.Plugin interface")
         end
      end
   end

   assert(command_name and type(command_name) == "string")
   local handler = self._commands[command_name]
   assert(handler)
   handler(args)
end

local function error_message(value)
   local message = tostring(value)
   message = message:gsub("^.-:%d+:%s*", "", 1)
   return message
end

function CLI:run(argv)
   local ok, result = pcall(function()
      self:_run(argv)
      return true
   end)
   if not ok then
      io.stderr:write("tealdoc: " .. error_message(result) .. "\n")
      return false
   end
   return true
end

return CLI
