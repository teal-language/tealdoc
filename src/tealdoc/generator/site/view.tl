local tealdoc = require("tealdoc")
local Generator = require("tealdoc.generator")
local SiteTypes = require("tealdoc.generator.site.types")

local record SiteView
    prepare: function(
        page: SiteTypes.Page,
        env: tealdoc.Env,
        pages?: {SiteTypes.Page}
    ): SiteTypes.ApiView
    modules: function(page: SiteTypes.Page): {string}
end

local function sources(page: SiteTypes.Page): {SiteTypes.ApiSource}
    if type(page.api) == "string" then
        return {{module = page.api as string}}
    end
    local output: {SiteTypes.ApiSource} = {}
    for _, entry in ipairs(page.api as {string | SiteTypes.ApiSource} or {}) do
        if type(entry) == "string" then
            table.insert(output, {module = entry as string})
        else
            table.insert(output, entry as SiteTypes.ApiSource)
        end
    end
    return output
end

function SiteView.modules(page: SiteTypes.Page): {string}
    local output: {string} = {}
    for _, source in ipairs(sources(page)) do
        table.insert(output, source.module)
    end
    return output
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
            and left.is_const == right.is_const
            and summary_line(left) == summary_line(right)
    end
    if left is tealdoc.TypeItem and right is tealdoc.TypeItem then
        local alias: tealdoc.TypeItem
        local definition: tealdoc.TypeItem
        if left.type_kind == "type" and right.type_kind ~= "type" then
            alias, definition = left, right
        elseif right.type_kind == "type" and left.type_kind ~= "type" then
            alias, definition = right, left
        end
        if alias and definition then
            return alias.name == definition.name
                and alias.typename:match("([%w_]+)$") == definition.name
        end
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
    env: tealdoc.Env,
    pages?: {SiteTypes.Page}
): SiteTypes.ApiView
    local api_sources = sources(page)
    if #api_sources == 0 then
        return nil
    end
    local modules = SiteView.modules(page)
    local public = page.public or api_sources[1].public or modules[1]
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
    local module_texts: {string} = {}

    local function has_documented_target(path: string): boolean
        for _, candidate_page in ipairs(pages or {page}) do
            for _, source in ipairs(sources(candidate_page)) do
                if path == source.module
                    or path:sub(1, #source.module + 1) ==
                        source.module .. "."
                then
                    if #(source.include or {}) == 0 then
                        return true
                    end
                    local remainder = path:sub(#source.module + 2)
                    local first = remainder:match("^([^.]+)")
                        or remainder
                    for _, name in ipairs(source.include) do
                        if name == first then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function mount(
        source_path: string,
        source_prefix: string,
        public_prefix: string,
        parent: string,
        exported_root?: boolean,
        force?: boolean
    ): string
        local item = assert(
            env.registry[source_path],
            "public API item not found: " .. source_path
        )
        if not force and not Generator.filter(item, env) then
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
                and (
                    not (previous_item is tealdoc.TypeItem)
                    or (
                        previous_item.type_kind == "type"
                        and item.type_kind ~= "type"
                    )
                )
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
                    public_path,
                    false,
                    force
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
                public_path,
                false,
                force
            )
            if child_public then
                table.insert(clone.children, child_public)
            end
        end
        return public_path
    end

    for _, source in ipairs(api_sources) do
        local module_name = source.module
        local source_public = source.public or public
        local module_item = assert(
            env.registry["$" .. module_name],
            "configured API module not found: " .. module_name
        )
        if #(source.include or {}) == 0
            and module_item.text
            and module_item.text ~= ""
        then
            table.insert(module_texts, module_item.text)
        end
        local module_record = env.registry[module_name]
        local basename = module_name:match("([^.]+)$") or module_name
        local public_basename = source_public:match("([^.]+)$")
            or source_public
        local mounts_as_child = module_record
            and module_name ~= source_public
            and basename ~= public_basename
            and basename:match("^[A-Z]") ~= nil
        local included: {string: boolean} = {}
        for _, name in ipairs(source.include or {}) do
            included[name] = true
        end
        local function selected(child_path: string): boolean
            if #(source.include or {}) == 0 then
                return true
            end
            local child = assert(env.registry[child_path])
            return included[child.name] == true
        end
        if mounts_as_child then
            if selected(module_name) then
                local mounted = mount(
                    module_name,
                    module_name,
                    source_public .. "." .. basename,
                    public,
                    true
                )
                if mounted then
                    table.insert(root_children, mounted)
                end
            end
        else
            if #(source.include or {}) == 0 then
                source_to_public[module_name] = source_public
            end
            local exported = module_record and module_record.children
                or module_item.children
                or {}
            for _, child_path in ipairs(exported) do
                if (not module_record or child_path ~= module_name)
                    and selected(child_path)
                then
                    local child = assert(env.registry[child_path])
                    local mounted = mount(
                        child_path,
                        child_path,
                        source_public .. "." .. child.name,
                        public
                    )
                    if mounted then
                        table.insert(root_children, mounted)
                    end
                end
            end
        end
    end

    -- A private named type in a public signature is part of that public API
    -- whether or not the source module returned the type itself. Publish the
    -- structural closure under the page root so a signature never ends at an
    -- unexplained, unlinked name.
    local pending: {string} = {}
    for _, path in ipairs(root_children) do
        table.insert(pending, path)
    end
    local scanned: {string: boolean} = {}
    local function include_reference(reference: tealdoc.TypeReference)
        if source_to_public[reference.path] then
            return
        end
        local target = env.registry[reference.path]
        local candidate_path = target
            and target is tealdoc.TypeItem
            and public .. "." .. target.name
            or nil
        local candidate = candidate_path
            and mounted_from[candidate_path]
            and projected.registry[candidate_path]
            or nil
        if target
            and candidate
            and same_public_item(candidate, target, env)
            and not (
                candidate is tealdoc.TypeItem
                and candidate.type_kind == "type"
                and target is tealdoc.TypeItem
                and target.type_kind ~= "type"
            )
        then
            source_to_public[reference.path] = candidate_path
            return
        end
        local aliased_public: string
        for source_path, public_path in pairs(source_to_public) do
            local source = env.registry[source_path]
            if source
                and source is tealdoc.TypeItem
                and canonical_alias(source, env) == reference.path
            then
                if aliased_public and aliased_public ~= public_path then
                    return
                end
                aliased_public = public_path
            end
        end
        if aliased_public then
            source_to_public[reference.path] = aliased_public
            return
        end
        if not target
            or not target is tealdoc.TypeItem
            or Generator.filter(target, env)
            or target.type_kind == "type"
        then
            return
        end
        local mounted = mount(
            reference.path,
            reference.path,
            public .. "." .. target.name,
            public,
            true,
            true
        )
        if mounted then
            table.insert(root_children, mounted)
            table.insert(pending, mounted)
        end
    end
    local function include_typeargs(typeargs: {tealdoc.Typearg})
        for _, typearg in ipairs(typeargs or {}) do
            for _, reference in ipairs(typearg.type_references or {}) do
                include_reference(reference)
            end
        end
    end
    local function expand_private_alias(
        path: string,
        item: tealdoc.TypeItem
    ): tealdoc.TypeItem
        if item.type_kind ~= "type" or not item.alias_target then
            return item
        end
        local target_path = canonical_alias(item, env)
        local target = target_path and env.registry[target_path]
        if not target
            or not target is tealdoc.TypeItem
            or target.type_kind == "type"
            or has_documented_target(target_path)
        then
            return item
        end

        -- A resolved dependency is not necessarily a documented module.
        -- Project its structural declaration under the public alias so a
        -- namespace-shaped source path cannot manufacture a link to an
        -- anchor no page renders.
        local definition = copy_item(target) as tealdoc.TypeItem
        definition.path = path
        definition.parent = item.parent
        definition.name = item.name
        definition.visibility = item.visibility
        definition.text = item.text or definition.text
        definition.typeargs = item.typeargs or definition.typeargs
        definition.children = {}
        projected.registry[path] = definition
        source_to_public[target_path] = path
        mounted_from[path] = target_path
        for _, child_path in ipairs(target.children or {}) do
            local child_public = mount(
                child_path,
                target_path,
                path,
                path,
                false,
                true
            )
            if child_public then
                table.insert(definition.children, child_public)
            end
        end
        return definition
    end
    local function scan(path: string)
        if scanned[path] then
            return
        end
        scanned[path] = true
        local item = projected.registry[path]
        if not item then
            return
        end
        if item is tealdoc.VariableItem then
            for _, reference in ipairs(item.type_references or {}) do
                include_reference(reference)
            end
        elseif item is tealdoc.FunctionItem then
            include_typeargs(item.typeargs)
            for _, param in ipairs(item.params or {}) do
                for _, reference in ipairs(param.type_references or {}) do
                    include_reference(reference)
                end
            end
            for _, result in ipairs(item.returns or {}) do
                for _, reference in ipairs(result.type_references or {}) do
                    include_reference(reference)
                end
            end
        elseif item is tealdoc.TypeItem then
            local type_item = expand_private_alias(path, item)
            item = type_item
            include_typeargs(type_item.typeargs)
            for _, reference in ipairs(
                type_item.inherit_references or {}
            ) do
                include_reference(reference)
            end
        end
        for _, child in ipairs(item.children or {}) do
            scan(child)
        end
    end
    local next_pending = 1
    while next_pending <= #pending do
        scan(pending[next_pending])
        next_pending = next_pending + 1
    end

    local module_root: tealdoc.Item = {
        kind = "module",
        path = "$" .. public,
        name = public,
        children = {public},
        text = #module_texts > 0
            and table.concat(module_texts, "\n\n")
            or nil,
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
