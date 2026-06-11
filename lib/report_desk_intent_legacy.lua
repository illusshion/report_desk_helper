--[[ Legacy quick_scenarios → intent adapter; guard rules as data exclusions. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local LEGACY_GUARD_EXCLUSIONS = {
    ['/c 090'] = {
        { all = { 'квест', 'механик' } },
        { all = { 'заклад' } },
        { all = { 'участк' }, none = { '090' } },
            { all = { 'механик' }, none = { 'вызвать', '090', 'эвакуатор', '010', 'полом' } },
    },
    ['азс'] = {
        { all = { 'заправ', 'игрок' }, none = { 'бензин', 'топлив', 'канистр' } },
        { all = { 'контракт' }, none = { 'бензин', 'азс' } },
    },
    ['канистр'] = {
        { all = { 'заправ', 'игрок' }, none = { 'бензин', 'топлив', 'канистр' } },
        { all = { 'контракт' }, none = { 'бензин', 'азс' } },
    },
    ['creditshelp'] = {
        { all = { 'кредит' }, none = { 'advance', 'credits', 'donate', 'адванс', 'credit' } },
    },
    ['/bp'] = {
        { all = { 'квест' }, none = { 'бп', 'battle', 'батл' } },
    },
    ['/mn 8'] = {
        { all = { 'квест' }, none = { 'бп', 'battle', 'батл' } },
    },
}

function legacyIntentIdFromLabel(label)
    label = normalizeMatchText(label)
    if label == '' then return 'legacy.unknown' end
    label = label:gsub('[^%w%.%-]+', '_'):gsub('_+', '_'):gsub('^_', ''):gsub('_$', '')
    return 'legacy.' .. label
end

function legacyKeywordToTrigger(kw)
    kw = trim(kw or '')
    if kw == '' then return nil end
    if kw:find('+', 1, true) or kw:find(' ', 1, true) then
        local parts = {}
        local seen = {}
        for w in (kw:gsub('+', ' ') .. ' '):gmatch('(%S+)') do
            w = normalizeMatchText(w)
            if w ~= '' and not seen[w] then
                seen[w] = true
                parts[#parts + 1] = w
            end
        end
        if #parts < 1 then return nil end
        if #parts == 1 then return { token = parts[1] } end
        return { all = parts }
    end
    return { token = kw }
end

function legacyKeywordsToTriggers(keywords)
    local any = {}
    for _, kw in ipairs(keywords or {}) do
        local tr = legacyKeywordToTrigger(kw)
        if tr then any[#any + 1] = tr end
    end
    return any
end

function legacyKeywordsToExclusions(neg)
    local out = {}
    for _, kw in ipairs(neg or {}) do
        local tr = legacyKeywordToTrigger(kw)
        if tr then out[#out + 1] = tr end
    end
    return out
end

function legacyGuardExclusionsForReply(reply)
    reply = normalizeMatchText(reply or '')
    if reply == '' then return {} end
    local out = {}
    for key, rules in pairs(LEGACY_GUARD_EXCLUSIONS) do
        local nk = normalizeMatchText(key)
        if reply:find(nk, 1, true) or reply:find(key, 1, true) then
            for _, r in ipairs(rules) do
                out[#out + 1] = r
            end
        end
    end
    return out
end

function legacyCategoryFromLabel(label, reply)
    label = normalizeMatchText(label or '')
    reply = trim(reply or '')
    if label:find('gps') or label:find('тир') or label:find('отель') or label:find('лиценз') then
        return 'navigation'
    end
    if label:find('прод') or label:find('куп') or label:find('price') or label:find('баланс') or label:find('кредит') then
        return 'economy'
    end
    if label:find('телефон') or label:find('такси') or label:find('позвон') or label:find('sms') or label:find('/c') then
        return 'communication'
    end
    if label:find('работ') or label:find('устро') or label:find('автобус') or label:find('таксист') or label:find('дальноб') then
        return 'jobs'
    end
    if reply:find('/sp') or label:find('след') then return 'reports' end
    return 'gameplay'
end

function adaptQuickScenarioToIntent(sc, idx)
    if type(sc) ~= 'table' then return nil end
    local actionType = sc.action == 'watch' and 'watch' or 'reply'
    local context = actionType == 'watch' and INTENT_CONTEXT_REPORT or INTENT_CONTEXT_FAQ
    local reply = trim(sc.reply or '')
    local triggersAny = legacyKeywordsToTriggers(sc.keywords or {})
    if actionType == 'watch' and #triggersAny < 1 then
        triggersAny = { { requires_id = true } }
    end
    if #triggersAny < 1 then return nil end
    local exclusions = legacyKeywordsToExclusions(sc.negative_keywords)
    local guardEx = legacyGuardExclusionsForReply(reply)
    for _, g in ipairs(guardEx) do
        exclusions[#exclusions + 1] = g
    end
    local label = trim(sc.label or '')
    return {
        id = legacyIntentIdFromLabel(label ~= '' and label or ('scenario_' .. tostring(idx or 0))),
        context = context,
        category = legacyCategoryFromLabel(label, reply),
        label = label ~= '' and label or '?',
        enabled = sc.enabled ~= false,
        stem = false,
        action = {
            type = actionType,
            text = reply,
            notify = actionType == 'watch' and reply or nil,
        },
        triggers = { any = triggersAny },
        exclusions = #exclusions > 0 and exclusions or nil,
        _legacy = true,
    }
end

function adaptLegacyScenariosToIntents(scenarios)
    local intents = {}
    for i, sc in ipairs(scenarios or {}) do
        local intent = adaptQuickScenarioToIntent(sc, i)
        if intent then intents[#intents + 1] = intent end
    end
    return intents
end

function migrateGuardRulesToIntentExclusions(intents)
    if type(intents) ~= 'table' then return end
    for _, intent in ipairs(intents) do
        if type(intent.action) == 'table' and intent.action.text then
            local guardEx = legacyGuardExclusionsForReply(intent.action.text)
            if #guardEx > 0 then
                intent.exclusions = intent.exclusions or {}
                for _, g in ipairs(guardEx) do
                    intent.exclusions[#intent.exclusions + 1] = g
                end
            end
        end
    end
end
