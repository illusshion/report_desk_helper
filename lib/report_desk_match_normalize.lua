--[[ Intent matching: token normalization, stem policy, text bags. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local EDGE_PUNCT = '[%s%.%!%?,:;%-]+'

if type(normalizeMatchText) ~= 'function' then
    function normalizeMatchText(s)
        s = trim(stripTags(s or ''))
        -- Intent config / UI strings are UTF-8; SAMP chat and stored threads are CP1251.
        if type(isUtf8Text) == 'function' and isUtf8Text(s)
                and type(utf8ToCp1251) == 'function' then
            s = utf8ToCp1251(s)
        end
        s = s:lower():gsub('%s+', ' ')
        s = s:gsub('\xB8', '\xE5')
        s = s:gsub('^' .. EDGE_PUNCT, ''):gsub(EDGE_PUNCT .. '$', '')
        return s
    end
end

local STEM_BLOCKLIST = {}
local STEM_BLOCKLIST_LOADED = false

function loadIntentStemBlocklist()
    if STEM_BLOCKLIST_LOADED then return end
    STEM_BLOCKLIST_LOADED = true
    STEM_BLOCKLIST = {}
    local path = INTENT_STEM_BLOCKLIST_PATH
    if type(path) ~= 'string' or not doesFileExist(path) then return end
    local chunk = loadfile(path)
    if not chunk then return end
    local ok, data = pcall(chunk)
    if ok and type(data) == 'table' then
        for _, root in ipairs(data) do
            local n = normalizeMatchText(root)
            if n ~= '' then STEM_BLOCKLIST[n] = true end
        end
    end
end

function intentStemBlocked(token)
    loadIntentStemBlocklist()
    token = normalizeMatchText(token)
    if token == '' then return false end
    for blocked, _ in pairs(STEM_BLOCKLIST) do
        if #blocked >= 4 and (token:sub(1, #blocked) == blocked or blocked:sub(1, #token) == token) then
            return true
        end
    end
    return false
end

function intentMatchTextPadded(s)
    s = normalizeMatchText(s)
    if s == '' then return '' end
    return ' ' .. s:gsub('%s+', ' ') .. ' '
end

function intentTokenMinLength(token)
    token = normalizeMatchText(token)
    if token == '' then return MIN_CONTAINS_TRIGGER_LEN or 3 end
    if token:match('^[%a%d]+$') and #token >= 2 then return 2 end
    return MIN_CONTAINS_TRIGGER_LEN or 3
end

function intentTextContainsToken(msg, msgAlt, token, msgTypo)
    token = normalizeMatchText(token)
    if token == '' or #token < intentTokenMinLength(token) then return false end
    local needle = ' ' .. token .. ' '
    for _, bag in ipairs({ msg, msgAlt, msgTypo or normalizeMatchTextTypo(msg) }) do
        local mp = intentMatchTextPadded(bag)
        if mp:find(needle, 1, true) then return true end
    end
    return false
end

function intentWordsShareStem(word, token, minStem, allowStem)
    if not allowStem or intentStemBlocked(token) or intentStemBlocked(word) then return false end
    minStem = minStem or 6
    word = normalizeMatchText(word)
    token = normalizeMatchText(token)
    if word == '' or token == '' then return false end
    if word == token then return true end
    local maxStem = math.min(#word, #token)
    if maxStem < minStem then return false end
    for n = maxStem, minStem, -1 do
        if word:sub(1, n) == token:sub(1, n) then return true end
    end
    return false
end

--[[
    Intent token match: whole word; prefix for len>=5; stem only if allowStem and not blocklisted.
]]
function intentTextMatchesToken(msg, msgAlt, token, msgTypo, allowStem)
    token = normalizeMatchText(token)
    if token == '' or #token < intentTokenMinLength(token) then return false end
    msgTypo = msgTypo or normalizeMatchTextTypo(msg)
    if intentTextContainsToken(msg, msgAlt, token, msgTypo) then return true end
    if #token < 5 then return false end
    local seen = {}
    local bags = {}
    for _, bag in ipairs({ msg, msgAlt, msgTypo }) do
        local n = normalizeMatchText(bag)
        if n ~= '' and not seen[n] then
            seen[n] = true
            bags[#bags + 1] = n
        end
    end
    for _, bag in ipairs(bags) do
        for w in bag:gmatch('%S+') do
            if #w >= #token and w:sub(1, #token) == token then
                return true
            end
            if allowStem and #token >= 6 then
                local minStem = (#token >= 8) and 6 or 5
                if intentWordsShareStem(w, token, minStem, true) then
                    return true
                end
            end
        end
    end
    return false
end

function intentNormalizeBags(body)
    local msg, msgAlt, msgTypo = matchMessageVariants(body)
    return {
        raw = body,
        msg = msg,
        msgAlt = msgAlt,
        msgTypo = msgTypo,
        key = msg ~= '' and msg or msgAlt,
    }
end

function intentMessageHasToken(bags, token, allowStem)
    if not bags then return false end
    return intentTextMatchesToken(bags.msg, bags.msgAlt, token, bags.msgTypo, allowStem)
end

function intentMessageHasAllTokens(bags, tokens, allowStem)
    if not bags or type(tokens) ~= 'table' then return false end
    for _, t in ipairs(tokens) do
        if not intentMessageHasToken(bags, t, allowStem) then
            return false
        end
    end
    return #tokens > 0
end

function intentMessageHasAnyToken(bags, tokens, allowStem)
    if not bags or type(tokens) ~= 'table' then return false end
    for _, t in ipairs(tokens) do
        if intentMessageHasToken(bags, t, allowStem) then
            return true
        end
    end
    return false
end

function intentMessageHasNoneTokens(bags, tokens, allowStem)
    if not bags or type(tokens) ~= 'table' then return true end
    for _, t in ipairs(tokens) do
        if intentMessageHasToken(bags, t, allowStem) then
            return false
        end
    end
    return true
end

-- Unified auto-rule aliases (ingest_runtime, builtins time/GG).
function matchTextPadded(s)
    return intentMatchTextPadded(s)
end

function tokenMinLength(token)
    return intentTokenMinLength(token)
end

function textContainsToken(msg, msgAlt, token, msgTypo)
    return intentTextContainsToken(msg, msgAlt, token, msgTypo)
end

function wordsShareStem(word, token, minStem)
    return intentWordsShareStem(word, token, minStem, true)
end

function textMatchesContainsToken(msg, msgAlt, token, msgTypo)
    return intentTextMatchesToken(msg, msgAlt, token, msgTypo, true)
end
