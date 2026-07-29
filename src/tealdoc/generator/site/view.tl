local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local SiteTypes = require("tealdoc.generator.site.types")

local record SiteView
    prepare: function(page: SiteTypes.Page, env: tealdoc.Env): SiteTypes.ApiView
    modules: function(page: SiteTypes.Page): {string}
end

function SiteView.modules(page: SiteTypes.Page): {string}
    if type(page.api) == "string" then
        return {page.api as string}
    end
    return page.api as {string} or {}
end

local function copy_item(item: tealdoc.Item): tealdoc.Item
    local values: {string: any} = {}
    for key, value in pairs(item as {string: any}) do
        values[key] = value
    end
    return values as tealdoc.Item
end

local function canonical_alias(
    item: tealdoc.Item,
    env: tealdoc.Env
): string
    local seen: {string: boolean} = {}
    while item and item is tealdoc.TypeItem
        and item.type_kind == "type"
        and item.alias_target
        and not seen[item.path]
    do
        seen[item.path] = true
        local target = env.registry[item.alias_target]
        if not target then
            return item.alias_target
        end
        item = target
    end
    return item and item.path or nil
end

local function normalized_type(
    typename: string,
    references: {tealdoc.TypeReference},
    env: tealdoc.Env
): string
    local replacements: {tealdoc.TypeReference} = {}
    for _, reference in ipairs(references or {}) do
        table.insert(replacements, reference)
    end
    table.sort(replacements, function(
        left: tealdoc.TypeReference,
        right: tealdoc.TypeReference
    ): boolean
        return #left.name > #right.name
    end)
    for _, reference in ipairs(replacements) do
        local item = env.registry[reference.path]
        local canonical = item and canonical_alias(item, env)
            or reference.path
        typename = typename:gsub(
            reference.name:gsub("([^%w])", "%%%1"),
            canonical
        )
    end
    return typename
end

local function same_function(
    left: tealdoc.FunctionItem,
    right: tealdoc.FunctionItem,
    env: tealdoc.Env
): boolean
    if left.function_kind ~= right.function_kind
        or #(left.typeargs or {}) ~= #(right.typeargs or {})
        or #(left.params or {}) ~= #(right.params or {})
        or #(left.returns or {}) ~= #(right.returns or {})
    then
        return false
    end
    for index, typearg in ipairs(left.typeargs or {}) do
        local other = right.typeargs[index]
        if typearg.name ~= other.name
            or typearg.constraint ~= other.constraint
        then
            return false
        end
    end
    for index, param in ipairs(left.params or {}) do
        local other = right.params[index]
        if param.name ~= other.name
            or normalized_type(
                param.type,
                param.type_references,
                env
            ) ~= normalized_type(
                other.type,
                other.type_references,
                env
            )
        then
            return false
        end
    end
    for index, result in ipairs(left.returns or {}) do
        local other = right.returns[index]
        if normalized_type(
            result.type,
            result.type_references,
            env
        ) ~= normalized_type(
            other.type,
            other.type_references,
            env
        )
        then
            return false
        end
    end
    return true
end

local function function_references(
    item: tealdoc.FunctionItem,
    prefix: string
): boolean
    local function contains(references: {tealdoc.TypeReference}): boolean
        for _, reference in ipairs(references or {}) do
            if reference.path == prefix
                or reference.path:sub(1, #prefix + 1) == prefix .. "."
                or reference.path:sub(1, #prefix + 2) == "$" ..
                    prefix ..
                    "~"
            then
                return true
            end
        end
        return false
    end
    for _, param in ipairs(item.params or {}) do
        if contains(param.type_references) then
            return true
        end
    end
    for _, result in ipairs(item.returns or {}) do
        if contains(result.type_references) then
            return true
        end
    end
    return false
end

local function summary_line(item: tealdoc.Item): string
    return item.text and item.text:match("^%s*([^\r\n]+)") or nil
end

local function same_public_item(
    left: tealdoc.Item,
    right: tealdoc.Item,
    env: tealdoc.Env
): boolean
    if left == right then
        return true
    end
    if left.kind ~= right.kind then
        local variable: tealdoc.VariableItem
        local declared_type: tealdoc.TypeItem
        if left is tealdoc.VariableItem and right is tealdoc.TypeItem then
            variable, declared_type = left, right
        elseif left is tealdoc.TypeItem and right is tealdoc.VariableItem then
            variable, declared_type = right, left
        end
        if variable and declared_type then
            return variable.name == declared_type.name
                and variable.typename:match("([%w_]+)$") == declared_type.name
        end
        return false
    end
    if left is tealdoc.FunctionItem
        and right is tealdoc.FunctionItem
    then
        return same_function(left, right, env)
            and (
                summary_line(left) == summary_line(right)
                or function_references(left, right.parent)
                or function_references(right, left.parent)
            )
    end
    if left is tealdoc.VariableItem
        and right is tealdoc.VariableItem
    then
        return left.typename == right.typename
            and summary_line(left) == summary_line(right)
    end
    local left_target = canonical_alias(left, env)
    local right_target = canonical_alias(right, env)
    if left_target and right_target and left_target == right_target then
        return true
    end
    return left.location and right.location
        and left.location.filename == right.location.filename
        and left.location.y == right.location.y
        and left.location.x == right.location.x
end

function SiteView.prepare(
    page: SiteTypes.Page,
    env: tealdoc.Env
): SiteTypes.ApiView
    local modules = SiteView.modules(page)
    if #modules == 0 then
        return nil
    end
    local public = page.public or modules[1]
    local projected = tealdoc.Env.init()
    for path, item in pairs(env.registry) do
        projected.registry[path] = item
    end
    projected.include_all = env.include_all
    projected.no_warnings_on_missing = true
    projected.modules = {public}

    local source_to_public: {string: string} = {}
    local public_paths: {string: boolean} = {}
    local source_paths: {string} = {}
    local mounted_from: {string: string} = {}
    local root_children: {string} = {}

    local function mount(
        source_path: string,
        source_prefix: string,
        public_prefix: string,
        parent: string,
        exported_root?: boolean
    ): string
        local item = assert(
            env.registry[source_path],
            "public API item not found: " .. source_path
        )
        if not Generator.filter(item, env) then
            return nil
        end
        local suffix = source_path:sub(#source_prefix + 1)
        local public_path = public_prefix .. suffix
        local previous = mounted_from[public_path]
        if previous then
            local previous_item = assert(env.registry[previous])
            assert(
                previous == source_path
                    or same_public_item(previous_item, item, env),
                "duplicate public API path " ..
                    public_path ..
                    " from " ..
                    previous ..
                    " and " ..
                    source_path
            )
            source_to_public[source_path] = public_path
            table.insert(source_paths, source_path)
            local existing = assert(projected.registry[public_path])
            local replace = item is tealdoc.TypeItem
                and not (previous_item is tealdoc.TypeItem)
            if replace then
                local clone = copy_item(item)
                clone.path = public_path
                clone.parent = parent
                clone.children = {}
                clone.text = existing.text or clone.text
                if exported_root
                    and clone is tealdoc.DeclarationItem
                then
                    clone.visibility = "global"
                end
                projected.registry[public_path] = clone
                mounted_from[public_path] = source_path
                existing = clone
            end
            for _, child_path in ipairs(item.children or {}) do
                local child_public = mount(
                    child_path,
                    source_prefix,
                    public_prefix,
                    public_path
                )
                if child_public then
                    table.insert(existing.children, child_public)
                end
            end
            return nil
        end
        mounted_from[public_path] = source_path
        source_to_public[source_path] = public_path
        public_paths[public_path] = true
        table.insert(source_paths, source_path)

        local clone = copy_item(item)
        clone.path = public_path
        clone.parent = parent
        clone.children = {}
        if exported_root and clone is tealdoc.DeclarationItem then
            clone.visibility = "global"
        end
        projected.registry[public_path] = clone
        for _, child_path in ipairs(item.children or {}) do
            local child_public = mount(
                child_path,
                source_prefix,
                public_prefix,
                public_path
            )
            if child_public then
                table.insert(clone.children, child_public)
            end
        end
        return public_path
    end

    for _, module_name in ipairs(modules) do
        local module_item = assert(
            env.registry["$" .. module_name],
            "configured API module not found: " .. module_name
        )
        local module_record = env.registry[module_name]
        local basename = module_name:match("([^.]+)$") or module_name
        local public_basename = public:match("([^.]+)$") or public
        local mounts_as_child = module_record
            and module_name ~= public
            and basename ~= public_basename
            and basename:match("^[A-Z]") ~= nil
        if mounts_as_child then
            local mounted = mount(
                module_name,
                module_name,
                public .. "." .. basename,
                public,
                true
            )
            if mounted then
                table.insert(root_children, mounted)
            end
        else
            source_to_public[module_name] = public
            local exported = module_record and module_record.children
                or module_item.children
                or {}
            for _, child_path in ipairs(exported) do
                if not module_record or child_path ~= module_name then
                    local child = assert(env.registry[child_path])
                    local mounted = mount(
                        child_path,
                        child_path,
                        public .. "." .. child.name,
                        public
                    )
                    if mounted then
                        table.insert(root_children, mounted)
                    end
                end
            end
        end
    end

    local module_root: tealdoc.Item = {
        kind = "module",
        path = "$" .. public,
        name = public,
        children = {public},
    }
    local public_root: tealdoc.Item = {
        kind = "module",
        path = public,
        name = public:match("([^.]+)$") or public,
        parent = "$" .. public,
        children = root_children,
    }
    projected.registry["$" .. public] = module_root
    projected.registry[public] = public_root
    public_paths[public] = true

    return {
        public = public,
        modules = modules,
        env = projected,
        source_to_public = source_to_public,
        public_paths = public_paths,
        source_paths = source_paths,
    }
end

return SiteView
