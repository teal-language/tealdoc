local argparse = require("argparse")
local Config = require("tealdoc.config")
local DumpTool = require("tealdoc.dump")
local MarkdownGenerator = require("tealdoc.generator.markdown")
local HTMLGenerator = require("tealdoc.generator.html.generator")
local SiteGenerator = require("tealdoc.generator.site")
local tealdoc = require("tealdoc")
local log = require("tealdoc.log")
local tl = require("tl")

local record TypeRoute
    path: string
    url: string
end

local function prefix_url_resolver(config: any): MarkdownGenerator.URLResolver
    local routes: {TypeRoute} = {}
    for path, url in pairs(config as {any: any}) do
        assert(
            type(path) == "string" and type(url) == "string",
            "Type-link route keys and values must be strings"
        )
        table.insert(routes, {path = path as string, url = url as string})
    end
    table.sort(routes, function(a: TypeRoute, b: TypeRoute): boolean
        return #a.path > #b.path
    end)

    return function(path: string): string
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

local function type_url_resolver(config: any): MarkdownGenerator.URLResolver
    if type(config) == "function" then
        return config as MarkdownGenerator.URLResolver
    end
    assert(
        type(config) == "table",
        "Type-link configuration must return a route table or resolver function"
    )
    return prefix_url_resolver(config)
end

local record CLI
    record Command -- TODO: description, alias?
        type Handler = function(args: argparse.Args)
        type Setup = function(command: argparse.Command)
        name: string
        setup: Setup
        handler: Handler
    end

    init: function(CLI, env: tealdoc.Env, skip_default_commands?: boolean)
    run: function(CLI, argv?: {string}): boolean
    add_default_commands: function(CLI)
    add_command: function(CLI, command: Command)

    _run: function(CLI, argv?: {string})
    _parser: argparse.Parser
    _commands: {string: Command.Handler}
    _env: tealdoc.Env
    _config: Config.Loaded
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
            command:flag("-a --all", "include all items in the documentation")
            command:flag("--no-warn-missing", "do not warn about missing items")
            command:option("-o --output", "output file")
                :default("doc.md")
        end,
        handler = function(args: argparse.Args)
            if args["all"] then
                self._env.include_all = true
            end
            if args["no_warn_missing"] then
                self._env.no_warnings_on_missing = true
            end
            local files = args.files as {string} -- TODO: bulletproof
            for _, file in ipairs(files) do
                tealdoc.process_file(file, self._env)
            end
            
            local resolver: MarkdownGenerator.URLResolver
            local settings = self._config.values as {string: any}
            local tealdoc_config = settings["tealdoc"] as {string: any}
            local markdown_config = tealdoc_config
                and tealdoc_config["markdown"] as {string: any}
            local type_links = markdown_config
                and markdown_config["type_links"]
            if type_links then
                resolver = type_url_resolver(type_links)
            end
            local generator = MarkdownGenerator.init(args["output"] as string, resolver)
            generator:run(self._env)
        end
    }
    local html_command: CLI.Command = {
        name = "html",
        setup = function(command: argparse.Command)
            command:argument("files", "input files"):args("+")
            command:flag("-a --all", "include all items in the documentation")
            command:flag("--no-warn-missing", "do not warn about missing items")
            command:option("-o --output", "output folder")
                :default("doc")
        end,
        handler = function(args: argparse.Args)
            if args["all"] then
                self._env.include_all = true
            end
            if args["no_warn_missing"] then
                self._env.no_warnings_on_missing = true
            end
            local files = args.files as {string} -- TODO: bulletproof
            for _, file in ipairs(files) do
                tealdoc.process_file(file, self._env)
            end
            local generator = HTMLGenerator.init(args["output"] as string)
            generator:run(self._env)
            --HTMLGenerator:run(args["output"] as string, self._env)
        end
    }
    local site_command: CLI.Command = {
        name = "site",
        setup = function(command: argparse.Command)
            command:argument("files", "Teal input files"):args("*")
            command:flag("--no-warn-missing", "do not warn about missing items")
            command:option("-o --output", "output directory")
                :default("site")
        end,
        handler = function(args: argparse.Args)
            if args["no_warn_missing"] then
                self._env.no_warnings_on_missing = true
            end
            local loaded = self._config
            local values = loaded.values as {string: any}
            local tealdoc_config = values["tealdoc"] as {string: any}
            local site_config = tealdoc_config
                and tealdoc_config["site"] as SiteGenerator.Settings
            assert(site_config, "tlconfig.lua does not contain tealdoc.site")

            local files = SiteGenerator.source_files(
                site_config,
                loaded.directory,
                values
            )
            local seen: {string: boolean} = {}
            for _, file in ipairs(files) do
                seen[file] = true
                tealdoc.process_file(file, self._env)
            end
            for _, file in ipairs(args.files as {string} or {}) do
                if not seen[file] then
                    seen[file] = true
                    tealdoc.process_file(file, self._env)
                end
            end
            for _, file in ipairs(SiteGenerator.hidden_source_files(
                values,
                loaded.directory
            )) do
                if not seen[file] then
                    seen[file] = true
                    tealdoc.process_file(file, self._env)
                end
            end

            SiteGenerator.build(
                args["output"] as string,
                self._env,
                site_config,
                loaded.directory
            )
        end,
    }
    self:add_command(dump_command)
    self:add_command(md_command)
    self:add_command(html_command)
    self:add_command(site_command)
end

function CLI:init(env: tealdoc.Env, skip_default_commands?: boolean)
    self._parser = argparse("tealdoc", nil, nil)
    self._parser:option("--plugin", "plugin to load", nil, nil, nil, "*")
    self._parser:flag("-V --version", "show version and exit")
        :target("version")
    self._parser:require_command(false)
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

function CLI:_run(argv?: {string})
    local args = self._parser:parse(argv)
    if args["version"] then
        print("tealdoc " .. tealdoc.version)
        return
    end
    self._config = Config.load()
    local settings = self._config.values as {string: any}
    local tealdoc_config = settings["tealdoc"] as {string: any}
    local doc_precedence = tealdoc_config
        and tealdoc_config["doc_precedence"]
    if doc_precedence ~= nil then
        assert(
            doc_precedence == "declaration"
                or doc_precedence == "definition"
                or doc_precedence == "error",
            "tealdoc.doc_precedence must be 'declaration', " ..
                "'definition', or 'error'"
        )
        self._env.doc_precedence =
            doc_precedence as tealdoc.Env.DocPrecedence
    end
    local command_name = args["command"]

    tl.loader()
    local plugins = args["plugin"] as {string}
    if plugins then
        for _, plugin in ipairs(plugins) do
            local ok, result = pcall(require, plugin)
            if not ok then
                log:error("Failed to load plugin '" .. plugin .. "': " .. tostring(result))
            end
            print(result)
            if result is tealdoc.Plugin then
                result.run(self._env)
            else
                log:error("Plugin '" .. plugin .. "' does not implement tealdoc.Plugin interface")
            end
        end
    end

    assert(command_name and command_name is string)
    local handler = self._commands[command_name as string]
    assert(handler)
    handler(args)
end

local function error_message(value: any): string
    local message = tostring(value)
    message = message:gsub("^.-:%d+:%s*", "", 1)
    return message
end

function CLI:run(argv?: {string}): boolean
    local ok, result = pcall(function(): boolean
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
