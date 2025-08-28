local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local HTMLBuilder = require("tealdoc.generator.html.builder")
local default_css = require("tealdoc.generator.html.default_css")
local lfs = require("lfs")

local function strip_module_prefix(path: string, module_name: string): string
    if path:sub(1, 1) == "$" then
        path = path:sub(2)
    end
    return path:sub(#module_name + 2) -- +2 for the dot after module name
end


local record HTMLGenerator
    init: function(ouput: string): Generator.Base
    item_phases: {string: {Generator.Phase}}
end

HTMLGenerator.item_phases = {}

local record ModuleNode
    name: string -- top level module name, last element of the path
    path: string -- full path to the module, e.g. "tealdoc.tool.html"
    -- children are submodules
    children: {ModuleNode}
end

local function make_file(path: string, title: string, content: function(b: HTMLBuilder))
    local b = HTMLBuilder.init()

    b:rawline("<!DOCTYPE html>")
    b:rawline("<html lang=\"en\">")
    b:rawline("<head>")
    b:rawline("<meta charset=\"UTF-8\">")
    b:rawline("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
    b:rawline("<title>"..title.."</title>")
    b:rawline("<style>")
    b:rawline(default_css)
    b:rawline("</style>")
    b:rawline("</head>")
    b:rawline("<body>")
    content(b)
    b:rawline("<footer>")
    b:rawline("<small>generated using <a href=\"https://github.com/teal-language/tealdoc\" target=\"_blank\">tealdoc</a> " .. tealdoc.version .. "</small>")
    b:rawline("</footer>")
    b:rawline("</body>")
    b:rawline("</html>")
    
    local file = io.open(path..".html", "w")
    assert(file)

    file:write(b:build())
    file:close()
end

local function generate_breadcrumbs(b: HTMLBuilder, visited: {string}, env: tealdoc.Env)
    b:rawline("<nav>")
    b:unordered_list(function(item: function(content: function))
        local path: string
        for i, v in ipairs(visited) do
            if i == #visited then -- last item is not a link
                item(function()
                    b:text(v)
                end)
            elseif i == 1 then -- first item is always index
                local prefix = string.rep("../", #visited - 2)
                item(function()
                    b:rawtext("<a href=\"" .. prefix .. v .. ".html\">")
                    b:text(v)
                    b:rawtext("</a> / ")
                end)
            else
                if not path then
                    path = v
                else
                    path = path .. "." .. v
                end
                local prefix = string.rep("../", #visited - i)
                item(function()
                    if path and env.registry["$"..path] then
                        b:rawtext("<a href=\"" .. prefix .. v .. ".html\">")
                        b:text(v)
                        b:rawtext("</a>")
                    else
                        b:text(v)
                    end
                    b:rawtext(" / ")
                end)
            end
        end
    end)
    b:rawline("</nav>")
end

HTMLGenerator.init = function(output: string): Generator.Base
    local base = Generator.Base.init()
    
    base.item_phases = HTMLGenerator.item_phases
    
    local root: ModuleNode = {
        name = "",
        path = "",
        children = {}
    }

    local node_map: {string: ModuleNode} = {}

    local module_name_to_builder: {string: HTMLBuilder} = {}

    base.on_context_for_item = function(_, ctx: Generator.Phase.Context, _: tealdoc.Item, module_name: string, _: tealdoc.Env)
        ctx.builder = module_name_to_builder[module_name]
        ctx.path_mode = "relative"
    end

    base.on_category_start = function(_, _: tealdoc.Item, category: string, ctx: Generator.Phase.Context, _: tealdoc.Env)
        if category ~= "$module_record" then
            local category_name: string
            if category == "$uncategorized" then
                category_name = ""
            elseif category:sub(1, 1) == "$" then
                category_name = category:sub(2) -- remove the leading $
            else
                category_name = category
            end


            ctx.builder:rawline("<h2 class=\"category\" id=\"category-" .. category_name .. "\">")
            if category_name ~= "" then
                ctx.builder:rawtext("<span class=\"muted\">")
                ctx.builder:text("Category: ")
                ctx.builder:rawtext("</span>")
                ctx.builder:text(category_name)
                ctx.builder:rawtext("<a class=\"title-link\" href=\"#category-" .. category_name .. "\">")
                ctx.builder:text("🔗")
                ctx.builder:rawtext("</a>")
            end
            ctx.builder:rawline("</h2>")
        end
    end

    base.on_start = function(_, env: tealdoc.Env)
        for _, item in ipairs(env.modules) do
            local parts = {}
            for part in item:gmatch("[^.]+") do
                table.insert(parts, part)
            end

            local current_path = ""
            local current_parent = root

            for i, part in ipairs(parts) do
                if i > 1 then
                    current_path = current_path .. "."
                end
                current_path = current_path .. part

                if not node_map[current_path] then
                    local new_node: ModuleNode = {
                        name = part,
                        path = current_path,
                        children = {}
                    }
                    node_map[current_path] = new_node
                    table.insert(current_parent.children, new_node)
                end

                current_parent = node_map[current_path]
            end
            
            local builder = HTMLBuilder.init()
            module_name_to_builder[item] = builder
        end
    end
    base.on_item_phase = function(_, item: tealdoc.Item, phase: Generator.Phase, ctx: Generator.Phase.Context, _: tealdoc.Env): boolean
        if phase.name == "header" then
            ctx.builder:rawtext("<h3 id=\"" .. item.path .. "\">")
            ctx.builder:text(strip_module_prefix(item.path, ctx.module_name))
            ctx.builder:rawtext("<a class=\"title-link\" href=\"#".. item.path .. "\">")
            ctx.builder:text("🔗")
            ctx.builder:rawtext("</a>")
            ctx.builder:rawtext("</h3>")
            return false
        elseif phase.name == "module_header" then
            ctx.builder:rawtext("<h1 id=\"" .. item.name .. "\">")
            ctx.builder:rawtext("<span class=\"muted\">")
            ctx.builder:text("Module ")
            ctx.builder:rawtext("</span>")
            ctx.builder:text(item.name)
            ctx.builder:rawtext("<a class=\"title-link\" href=\"#".. item.name .. "\">")
            ctx.builder:text("🔗")
            ctx.builder:rawtext("</a>")
            ctx.builder:rawtext("</h1>")
            return false
        end
        return true
    end

    base.on_end = function(_, env: tealdoc.Env)
        make_file(output .. "/index", "Index - Documentation", function(b: HTMLBuilder)
            b:rawline("<main>")
            b:h1("Documentation Index")
            local visited = {"index"}

            local function traverse(cur_filename: string, node: ModuleNode)
                local module_item = env.registry["$"..node.path]

                if node.name ~= "" then
                    table.insert(visited, node.name)
                end

                if not module_item then
                    b:text(node.name)
                else
                    local path = cur_filename .."/".. node.name

                    make_file(path, node.name .. " - " .. node.path.." - Documentation", function(moduleBuilder: HTMLBuilder)
                        moduleBuilder:rawline("<main>")
                        generate_breadcrumbs(moduleBuilder, visited, env)
                        moduleBuilder:rawtext(module_name_to_builder[node.path]:build())
                        moduleBuilder:rawline("</main>")
                    end)

                    local link = path:sub(#output + 2)
                    b:rawtext("<a href=\"" ..link.. ".html\">")
                    b:text(node.name)
                    b:rawtext("</a>")
                end

                if #node.children > 0 then
                    b:rawline("<ul class=\"tree-list\">")
                    for _, child in ipairs(node.children) do
                        b:rawline("<li>")
                        local path: string = cur_filename
                        if node.name ~= "" then
                            path = path .. "/".. node.name
                        end
                        lfs.mkdir(path)
                        traverse(path, child)
                        b:rawline("</li>")
                    end
                    b:rawline("</ul>")
                end

                if node.name ~= "" then
                    table.remove(visited)
                end
            end

            traverse(output, root)
            b:rawline("</main>")
        end)
    end

    return base
end

return HTMLGenerator