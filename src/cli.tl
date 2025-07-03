local argparse = require("argparse")
local DumpTool = require("tool.dump")
local MarkdownGenerator = require("tool.markdown")
local tealdoc = require("tealdoc")

local record CLI
    record Command -- TODO: description, alias?
        type Handler = function(args: argparse.Args) 
        type Setup = function(command: argparse.Command)
        name: string
        setup: Setup
        handler: Handler
    end

    init: function(CLI, env: tealdoc.Env, skip_default_commands?: boolean)
    run: function(CLI)    
    add_default_commands: function(CLI)
    add_command: function(CLI, command: Command)
    
    _parser: argparse.Parser
    _commands: {string: Command.Handler}
    _env: tealdoc.Env
end

function CLI:add_default_commands() 
    local dump_command: CLI.Command = {
        name = "dump",
        setup = function(command: argparse.Command)
            command:argument("files", "input files"):args("+")
        end,
        handler = function(args: argparse.Args)
            local files = args.files as {string} -- TODO: bulletproof
            for _, file in ipairs(files) do
                tealdoc.process_file(file, self._env)
            end
            DumpTool.run(self._env.registry)
        end
    }

    local md_command: CLI.Command = {
        name = "md",
        setup = function(command: argparse.Command)
            command:argument("files", "input files"):args("+")
        end,
        handler = function(args: argparse.Args)
            local files = args.files as {string} -- TODO: bulletproof
            for _, file in ipairs(files) do
                tealdoc.process_file(file, self._env)
            end
            MarkdownGenerator:run("doc.md", self._env)
        end
    }
    self:add_command(dump_command)
    self:add_command(md_command)
end

function CLI:init(env: tealdoc.Env, skip_default_commands?: boolean)
    self._parser = argparse("tealdoc", nil, nil)
    self._parser:command_target("command")
    self._commands = {}
    self._env = env
    if not skip_default_commands then
        self:add_default_commands()
    end
end

function CLI:add_command(command: CLI.Command)
    assert(command.name and command.setup and command.handler)
    local c = self._parser:command(command.name, nil, nil)
    command.setup(c)
    self._commands[command.name] = command.handler 
end

function CLI:run() 
    local args = self._parser:parse(nil)
    local command_name = args["command"]
    assert(command_name and command_name is string)
    local handler = self._commands[command_name as string]
    assert(handler)
    handler(args)
end

return CLI