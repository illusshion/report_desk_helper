--[[ Context classifier: FAQ / REPORT / THANKS / UNKNOWN (before intent matching). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

INTENT_CONTEXT_FAQ = 'faq'
INTENT_CONTEXT_REPORT = 'report'
INTENT_CONTEXT_THANKS = 'thanks'
INTENT_CONTEXT_UNKNOWN = 'unknown'

local DEFAULT_REPORT_MARKERS = {
    'dm', 'дм', 'id', '\xF3\xE1\xE8\xEB', '\xF3\xE1\xE8\xEB\xE0', '\xF7\xE8\xF2', '\xF7\xE8\xF2\xE5\xF0',
    'hack', 'cheat', 'kill', 'killed', '\xED\xE0\xF0\xF3\xF8', 'report', '\xF0\xE5\xEF\xEE\xF0\xF2',
}

local DEFAULT_FAQ_HINTS = {
    'где', 'как', 'сколько', 'можно', 'можно ли', 'почему', 'что', 'когда', 'куда', 'какой', 'какая',
    'help', 'хелп', 'подскаж', 'объясн', 'найти', 'купить', 'продать', 'устроиться', 'работ',
}

local contextConfig = nil

function getIntentContextConfig()
    if contextConfig then return contextConfig end
    contextConfig = {
        report_markers = DEFAULT_REPORT_MARKERS,
        faq_hints = DEFAULT_FAQ_HINTS,
        thanks_exact = {},
    }
    if type(BUILTIN_AUTO_RULE_GG) == 'table' and type(BUILTIN_AUTO_RULE_GG.keywords) == 'table' then
        for _, k in ipairs(BUILTIN_AUTO_RULE_GG.keywords) do
            contextConfig.thanks_exact[#contextConfig.thanks_exact + 1] = k
        end
    end
    if type(intentRegistry) == 'table' and type(intentRegistry.contexts) == 'table' then
        local c = intentRegistry.contexts
        if type(c.report_markers) == 'table' then contextConfig.report_markers = c.report_markers end
        if type(c.faq_hints) == 'table' then contextConfig.faq_hints = c.faq_hints end
        if type(c.thanks_exact) == 'table' and #c.thanks_exact > 0 then
            local merged = {}
            local seen = {}
            for _, kw in ipairs(contextConfig.thanks_exact or {}) do
                local k = normalizeMatchText(kw)
                if k ~= '' and not seen[k] then
                    seen[k] = true
                    merged[#merged + 1] = kw
                end
            end
            for _, kw in ipairs(c.thanks_exact) do
                local k = normalizeMatchText(kw)
                if k ~= '' and not seen[k] then
                    seen[k] = true
                    merged[#merged + 1] = kw
                end
            end
            contextConfig.thanks_exact = merged
        end
    end
    return contextConfig
end

function resetIntentContextConfig()
    contextConfig = nil
end

function getReportIdMarkers()
    return getIntentContextConfig().report_markers or DEFAULT_REPORT_MARKERS
end

function messageLooksLikeThanks(bags)
    if not bags then return false end
    local cfg = getIntentContextConfig()
    local low = bags.msg
    if low == '' then low = bags.msgAlt end
    if low == '' then return false end
    if #low > 48 then return false end
    for _, kw in ipairs(cfg.thanks_exact or {}) do
        local k = normalizeMatchText(kw)
        if k ~= '' then
            if low == k or low == normalizeMatchTextTypo(kw) then return true end
            if #k >= 3 and #low <= 48 and low:find('^' .. k, 1, true) then return true end
        end
    end
    if #low <= 48 then
        if low == '+' or low == 'ок' or low:find('^ок ', 1, true) or low:find('^понял', 1, true) then
            return true
        end
        if low:find('^спс', 1, true) then return true end
    end
    return false
end

function messageLooksLikeReportContext(bags, rawText)
    if not bags then return false end
    local low = bags.msg
    if low == '' then low = bags.msgAlt end
    if low == '' then return false end
    if type(deskIngest) == 'table' and deskIngest.looksLikeAdminActionText
        and deskIngest.looksLikeAdminActionText(rawText or bags.raw or '') then
        return false
    end
    local cfg = getIntentContextConfig()
    local hasMarker = false
    for _, m in ipairs(cfg.report_markers or DEFAULT_REPORT_MARKERS) do
        local mNorm = normalizeMatchText(m)
        if mNorm ~= '' and low:find(mNorm, 1, true) then
            hasMarker = true
            break
        end
    end
    if not hasMarker then return false end
    if extractReportSuspectId(rawText or bags.raw or '') then
        return true
    end
    return false
end

function messageHasFaqHints(bags)
    if not bags then return false end
    local low = bags.msg
    if low == '' then low = bags.msgAlt end
    if low == '' then return false end
    local cfg = getIntentContextConfig()
    for _, h in ipairs(cfg.faq_hints or DEFAULT_FAQ_HINTS) do
        local hint = normalizeMatchText(h)
        if hint ~= '' and intentMessageHasToken(bags, hint, false) then
            return true
        end
    end
    if low:find('%?') then return true end
    return false
end

function classifyContext(body, bags)
    bags = bags or intentNormalizeBags(body)
    if messageLooksLikeThanks(bags) then
        return INTENT_CONTEXT_THANKS
    end
    if messageLooksLikeReportContext(bags, body) then
        return INTENT_CONTEXT_REPORT
    end
    local low = bags.msg
    if low == '' then low = bags.msgAlt end
    if low == '' then return INTENT_CONTEXT_UNKNOWN end
    local genericOnly = {
        'help', 'хелп', 'hel', 'помогите', 'помоги', 'помог',
        '\xEF\xEE\xEC\xEE\xE3\xE8\xF2\xE5', '\xEF\xEE\xEC\xEE\xE3\xE8',
        'zastryal', 'застрял', '\xE7\xE0\xF1\xF2\xF0\xFF\xEB',
        'админ', '\xE0\xE4\xEC\xE8\xED',
    }
    for _, token in ipairs(genericOnly) do
        local key = normalizeMatchText(token)
        if key ~= '' and low == key then
            return INTENT_CONTEXT_UNKNOWN
        end
    end
    if messageHasFaqHints(bags) then
        return INTENT_CONTEXT_FAQ
    end
    if extractReportSuspectId(body or bags.raw) then
        return INTENT_CONTEXT_REPORT
    end
    return INTENT_CONTEXT_UNKNOWN
end
