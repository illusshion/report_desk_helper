--[[ Merge config/intent_trigger_extensions.lua into intent list at load time. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local function clauseKey(clause)
    if type(clause) ~= 'table' then return '' end
    if clause.requires_id then return 'id' end
    if clause.token then return 't:' .. normalizeMatchText(clause.token) end
    local parts = {}
    if type(clause.all) == 'table' then
        for _, t in ipairs(clause.all) do parts[#parts + 1] = normalizeMatchText(t) end
        table.sort(parts)
        return 'a:' .. table.concat(parts, '+')
    end
    if type(clause.any) == 'table' then
        for _, t in ipairs(clause.any) do parts[#parts + 1] = normalizeMatchText(t) end
        table.sort(parts)
        return 'o:' .. table.concat(parts, '+')
    end
    return ''
end

local function mergeClauses(into, add)
    if type(into) ~= 'table' or type(add) ~= 'table' then return end
    local seen = {}
    for _, c in ipairs(into) do
        local k = clauseKey(c)
        if k ~= '' then seen[k] = true end
    end
    for _, c in ipairs(add) do
        local k = clauseKey(c)
        if k == '' or not seen[k] then
            into[#into + 1] = c
            if k ~= '' then seen[k] = true end
        end
    end
end

function applyIntentExtensionsToList(intents)
    local path = INTENT_EXTENSIONS_PATH
    if type(path) ~= 'string' or not doesFileExist(path) then return false end
    local chunk, err = loadfile(path)
    if not chunk then
        print('[Report Desk] intent extensions load: ' .. tostring(err))
        return false
    end
    local ok, ext = pcall(chunk)
    if not ok or type(ext) ~= 'table' then return false end

    local byId = {}
    for i, intent in ipairs(intents or {}) do
        if intent.id then byId[intent.id] = i end
    end

    for _, raw in ipairs(ext.new_intents or {}) do
        if type(raw) == 'table' and raw.id and not byId[raw.id] then
            intents[#intents + 1] = raw
            byId[raw.id] = #intents
        end
    end

    for _, patch in ipairs(ext.patches or {}) do
        local idx = patch.id and byId[patch.id]
        if idx then
            local intent = intents[idx]
            intent.triggers = intent.triggers or { any = {} }
            intent.triggers.any = intent.triggers.any or {}
            mergeClauses(intent.triggers.any, patch.add_any)
            if type(patch.add_exclusions) == 'table' and #patch.add_exclusions > 0 then
                intent.exclusions = intent.exclusions or {}
                mergeClauses(intent.exclusions, patch.add_exclusions)
            end
        end
    end

    return true
end
