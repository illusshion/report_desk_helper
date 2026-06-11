--[[ Intent registry, compile index, resolveMessageIntents (Top-1 + optional alt). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

intentRegistry = nil
deskIntents = {}
deskIntentsById = {}
deskIntentIndex = {}
intentsGen = 0

function bumpIntentsGen()
    intentsGen = intentsGen + 1
    if type(deskCache) == 'table' then
        deskCache.intentResolve = {}
    end
    resetIntentContextConfig()
end

local function normalizeIntentText(s)
    if type(ensureWireCp1251) == 'function' then
        return ensureWireCp1251(s)
    end
    s = trim(s or '')
    if s == '' then return '' end
    if type(normalizeStoredText) == 'function' then
        return normalizeStoredText(s, type(isUtf8Text) == 'function' and isUtf8Text(s))
    end
    return s
end

function normalizeIntentRecord(raw)
    if type(raw) ~= 'table' then return nil end
    local id = trim(raw.id or '')
    if id == '' then return nil end
    local action = raw.action
    if type(action) ~= 'table' then
        local actionType = raw.action == 'watch' and 'watch' or 'reply'
        local reply = normalizeIntentText(raw.reply or '')
        action = { type = actionType, text = reply, notify = reply }
    else
        action = {
            type = action.type == 'watch' and 'watch' or 'reply',
            text = normalizeIntentText(action.text or action.notify or raw.reply or ''),
            notify = normalizeIntentText(action.notify or action.text or raw.reply or ''),
        }
    end
    return {
        id = id,
        context = raw.context or INTENT_CONTEXT_FAQ,
        category = raw.category or 'general',
        label = normalizeIntentText(raw.label or id),
        enabled = raw.enabled ~= false,
        stem = raw.stem == true,
        action = action,
        triggers = raw.triggers or { any = {} },
        exclusions = raw.exclusions,
        requires = raw.requires,
    }
end

function compileIntentIndex(intents)
    local index = {}
    for i, intent in ipairs(intents or {}) do
        local ctx = intent.context or INTENT_CONTEXT_FAQ
        if not index[ctx] then index[ctx] = { all = {}, byToken = {} } end
        index[ctx].all[#index[ctx].all + 1] = i
        for _, tok in ipairs(intentFirstTokens(intent)) do
            local bucket = index[ctx].byToken[tok]
            if not bucket then
                bucket = {}
                index[ctx].byToken[tok] = bucket
            end
            bucket[#bucket + 1] = i
        end
    end
    return index
end

function setDeskIntents(intents, registryMeta)
    deskIntents = {}
    deskIntentsById = {}
    for i, raw in ipairs(intents or {}) do
        local intent = normalizeIntentRecord(raw)
        if intent then
            deskIntents[i] = intent
            deskIntentsById[intent.id] = intent
        end
    end
    intentRegistry = registryMeta or { version = INTENTS_VERSION or 1 }
    if type(intentRegistry.intents) ~= 'table' then
        intentRegistry.intents = deskIntents
    end
    deskIntentIndex = compileIntentIndex(deskIntents)
    bumpIntentsGen()
end

function loadIntentsFromFile(path)
    path = path or INTENTS_CONFIG_PATH
    if not doesFileExist(path) then return false end
    local chunk, err = loadfile(path)
    if not chunk then
        print('[Report Desk] intents load: ' .. tostring(err))
        return false
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then return false end
    if type(data.intents) ~= 'table' or #data.intents < 1 then return false end
    migrateGuardRulesToIntentExclusions(data.intents)
    if type(applyIntentExtensionsToList) == 'function' then
        applyIntentExtensionsToList(data.intents)
    end
    setDeskIntents(data.intents, data)
    if data.version then
        settings.intents_version = tonumber(data.version) or settings.intents_version
    end
    return true
end

function reloadDeskIntentsFromSources(preferLegacyScenarios)
    if not preferLegacyScenarios
            and type(loadIntentsFromFile) == 'function'
            and loadIntentsFromFile(INTENTS_CONFIG_PATH) then
        return true
    end
    if type(quickScenarios) == 'table' and #quickScenarios > 0 then
        local adapted = adaptLegacyScenariosToIntents(quickScenarios)
        setDeskIntents(adapted, { version = 0, source = 'legacy_adapter' })
        return #deskIntents > 0
    end
    setDeskIntents({}, { version = 0 })
    return false
end

function ensureDeskIntentsLoaded()
    if #deskIntents > 0 then return true end
    return reloadDeskIntentsFromSources()
end

function intentCandidateIndices(bags, context)
    ensureDeskIntentsLoaded()
    local bucket = deskIntentIndex[context]
    if not bucket then return {} end
    if not bags or bags.key == '' then return bucket.all end
    local seen = {}
    local out = {}
    for tok in bags.key:gmatch('%S+') do
        local list = bucket.byToken[tok]
        if list then
            for _, idx in ipairs(list) do
                if not seen[idx] then
                    seen[idx] = true
                    out[#out + 1] = idx
                end
            end
        end
    end
    if #out < 1 then return bucket.all end
    return out
end

function intentToQuickScenario(intent)
    if not intent then return nil end
    local action = intent.action or {}
    local actionType = action.type == 'watch' and 'watch' or 'reply'
    return {
        label = intent.label or intent.id,
        enabled = intent.enabled ~= false,
        match = 'contains',
        keywords = {},
        negative_keywords = {},
        reply = normalizeIntentText(action.text or action.notify or ''),
        action = actionType,
        priority = 0,
        skip_if_report_id = intent.context == INTENT_CONTEXT_FAQ,
        intentId = intent.id,
    }
end

function resolveMessageIntents(text)
    text = trim(text or '')
    if text == '' then return {}, INTENT_CONTEXT_UNKNOWN end
    ensureDeskIntentsLoaded()
    local bags = intentNormalizeBags(text)
    if bags.key == '' then return {}, INTENT_CONTEXT_UNKNOWN end

    local sig = tostring(intentsGen) .. '|' .. tostring(#deskIntents)
    if type(deskCache) == 'table' and deskCache.intentResolve then
        local hit = deskCache.intentResolve[bags.key]
        if hit and hit.sig == sig then
            return hit.results, hit.context
        end
    end

    local context = classifyContext(text, bags)
    local minConf = tonumber(INTENT_MIN_CONFIDENCE) or 12
    local closeRatio = tonumber(INTENT_CLOSE_RATIO) or 0.92
    local maxBtns = tonumber(INTENT_MAX_BUTTONS) or 2

    local results = {}
    if context ~= INTENT_CONTEXT_THANKS and context ~= INTENT_CONTEXT_UNKNOWN then
        local candidates = {}
        local indices = intentCandidateIndices(bags, context)
        for _, idx in ipairs(indices) do
            local intent = deskIntents[idx]
            local ok, score = intentMatches(bags, intent, context)
            if ok and score >= minConf then
                candidates[#candidates + 1] = {
                    intent = intent,
                    score = score,
                    id = intent.id,
                }
            end
        end

        table.sort(candidates, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return (a.id or '') < (b.id or '')
        end)

        if #candidates > 0 then
            results[1] = candidates[1]
            if #candidates > 1 and maxBtns > 1 then
                local second = candidates[2]
                if second.score / candidates[1].score >= closeRatio then
                    results[2] = second
                end
            end
        end
    end

    if messageEligibleForWatchButton(text, context) then
        local hasWatch = false
        for _, r in ipairs(results) do
            if r.intent and r.intent.action and r.intent.action.type == 'watch' then
                hasWatch = true
                break
            end
        end
        if not hasWatch then
            local watchIntent = deskIntentsById['report.watch']
            if not watchIntent then
                watchIntent = normalizeIntentRecord({
                    id = 'report.watch',
                    context = INTENT_CONTEXT_REPORT,
                    category = 'reports',
                    label = '\xD1\xEB\xE5\xE4\xE8\xF2\xFC',
                    action = { type = 'watch', text = '', notify = settings and settings.watch_notify or 'see' },
                    triggers = { any = { { requires_id = true } } },
                })
            end
            if watchIntent then
                table.insert(results, 1, { intent = watchIntent, score = 30, id = watchIntent.id })
                if #results > maxBtns then
                    table.remove(results)
                end
            end
        end
    end

    if type(deskCache) == 'table' then
        deskCache.intentResolve = deskCache.intentResolve or {}
        deskCache.intentResolve[bags.key] = { sig = sig, results = results, context = context }
    end
    return results, context
end

function resolveMessageIntentIds(text)
    local results, ctx = resolveMessageIntents(text)
    local ids = {}
    for _, r in ipairs(results) do
        ids[#ids + 1] = r.id
    end
    return ids, ctx
end

function formatIntentResolveSummary(text)
    local results, ctx = resolveMessageIntents(text)
    if #results < 1 then
        return string.format('context=%s | no match', tostring(ctx))
    end
    local parts = { string.format('context=%s', tostring(ctx)) }
    for i, r in ipairs(results) do
        parts[#parts + 1] = string.format('%s=%s (%.0f)', i == 1 and 'top1' or 'alt', tostring(r.id), r.score or 0)
    end
    return table.concat(parts, ' | ')
end
