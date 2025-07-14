local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pcall = _tl_compat and _tl_compat.pcall or pcall; local type = type; local argparse = require("argparse")
local DumpTool = require("tealdoc.tool.dump")
local MarkdownGenerator = require("tealdoc.tool.markdown")
local tealdoc = require("tealdoc")
local log = require("tealdoc.log")
local tl = require("tl")

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
         command:option("-o --output", "output file"):
         default("doc.md")
      end,
      handler = function(args)
         if args["all"] then
            self._env.include_all = true
         end
         local files = args.files
         for _, file in ipairs(files) do
            tealdoc.process_file(file, self._env)
         end
         MarkdownGenerator:run(args["output"], self._env)
      end,
   }
   self:add_command(dump_command)
   self:add_command(md_command)
end

function CLI:init(env, skip_default_commands)
   self._parser = argparse("tealdoc", nil, nil)
   self._parser:option("--plugin", "plugin to load", nil, nil, nil, "*")
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

function CLI:run()
   local args = self._parser:parse(nil)
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

return CLI
