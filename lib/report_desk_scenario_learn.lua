--[[ Модуль: обучение FAQ-сценариев на ходу (Q→A из реальных ответов админа). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

SCENARIO_LEARN_MAX_KW_PER_SCENARIO = 40
SCENARIO_LEARN_MAX_ENTRIES = 800
SCENARIO_LEARN_MANUAL_PROMOTE_MIN = 2

scenarioLearnData = scenarioLearnData or {
    keywords_by_scenario = {},
    stats = { session_records = 0, session_keywords = 0, total_records = 0 },
}
dirtyScenarioLearn = false
scenarioLearnSessionKeywords = scenarioLearnSessionKeywords or 0

local STOP_WORDS = {
    ['как'] = true, ['где'] = true, ['что'] = true, ['это'] = true, ['или'] = true,
    ['можно'] = true, ['надо'] = true, ['нужно'] = true, ['help'] = true,
    ['помогите'] = true, ['пожалуйста'] = true, ['здравствуйте'] = true,
    ['привет'] = true, ['очень'] = true, ['меня'] = true, ['мне'] = true,
    ['если'] = true, ['когда'] = true, ['почему'] = true, ['какой'] = true,
    ['какая'] = true, ['какие'] = true, ['есть'] = true, ['тут'] = true,
    ['для'] = true, ['про'] = true, ['ещё'] = true, ['еще'] = true,
    ['тоже'] = true, ['только'] = true, ['чтобы'] = true, ['чтоб'] = true,
    ['админ'] = true, ['админы'] = true, ['скажите'] = true, ['подскажите'] = true,
}

local SKIP_ANSWER_EXACT = {
    ['see'] = true, ['gg'] = true, ['спасибо'] = true, ['спс'] = true,
    ['ок'] = true, ['ok'] = true, ['+'] = true, ['ожидайте'] = true,
    ['ожидайте.'] = true, ['принял'] = true, ['принято'] = true,
    ['понял'] = true, ['хорошо'] = true, ['минуту'] = true,
}

-- Scenario Learn Enabled
function scenarioLearnEnabled()
    return settings.scenario_learn_enabled ~= false
end

-- Scenario Learn Mark Dirty
function scenarioLearnMarkDirty()
    dirtyScenarioLearn = true
end

-- Scenario Learn Normalize Answer
function scenarioLearnNormalizeAnswer(text)
    return normalizeMatchText(text or '')
end

-- Scenario Learn Is Skippable Question
function scenarioLearnIsSkippableQuestion(text)
    text = trim(text or '')
    if text == '' or #text < 8 then return true end
    if textLooksLikePlayerReport(text) and extractSuspectIdFromReport(text) then
        return true
    end
    local low = scenarioLearnNormalizeAnswer(text)
    if low == 'help' or low == 'спасибо' or low == 'спс' or low == 'gg' then return true end
    if low:find('помогите', 1, true) and #low < 24 then return true end
    if low:find('памагите', 1, true) and #low < 24 then return true end
    return false
end

-- Scenario Learn Is Skippable Answer
function scenarioLearnIsSkippableAnswer(text)
    text = trim(text or '')
    if text == '' or #text < 2 then return true end
    local low = scenarioLearnNormalizeAnswer(text)
    if SKIP_ANSWER_EXACT[low] then return true end
    if low:find('приятной игры', 1, true) then return true end
    if low:find('хорошей игры', 1, true) then return true end
    if low:find('ожидайте', 1, true) then return true end
    if low:find('не могу', 1, true) and #low < 40 then return true end
    if low:find('уточн', 1, true) and #low < 40 then return true end
    return false
end

-- Scenario Learn Extract Keywords
function scenarioLearnExtractKeywords(question)
    local msg = normalizeMatchText(question or '')
    if msg == '' then return nil end
    local words = {}
    for w in msg:gmatch('%S+') do
        w = w:gsub('^[^%w]+', ''):gsub('[^%w]+$', '')
        if #w >= 3 and not STOP_WORDS[w] then
            words[#words + 1] = w
        end
    end
    if #words < 1 then return nil end
    if #words >= 2 then
        local n = math.min(#words, 3)
        local parts = {}
        for i = 1, n do parts[i] = words[i] end
        return table.concat(parts, '+')
    end
    if #words[1] >= 5 then return words[1] end
    return nil
end

-- Scenario Learn Get Scenario Bucket
function scenarioLearnGetScenarioBucket(label)
    if not label or label == '' then return nil end
    local root = scenarioLearnData.keywords_by_scenario
    if type(root) ~= 'table' then
        root = {}
        scenarioLearnData.keywords_by_scenario = root
    end
    local bucket = root[label]
    if type(bucket) ~= 'table' then
        bucket = {}
        root[label] = bucket
    end
    return bucket
end

-- Scenario Learn Promote Keyword
function scenarioLearnPromoteKeyword(scLabel, question)
    if not scenarioLearnEnabled() then return false end
    local kw = scenarioLearnExtractKeywords(question)
    if not kw or kw == '' then return false end
    local key = keywordDedupeKey(kw)
    if key == '' then return false end
    local bucket = scenarioLearnGetScenarioBucket(scLabel)
    if not bucket then return false end
    local hit = bucket[key]
    if hit then
        hit.count = (tonumber(hit.count) or 0) + 1
        hit.last_at = os.time()
        return false
    end
    local n = 0
    for _ in pairs(bucket) do n = n + 1 end
    if n >= SCENARIO_LEARN_MAX_KW_PER_SCENARIO then
        scenarioLearnPruneScenarioBucket(bucket)
    end
    bucket[key] = {
        kw = kw,
        count = 1,
        learned = true,
        last_at = os.time(),
    }
    scenarioLearnSessionKeywords = scenarioLearnSessionKeywords + 1
    local st = scenarioLearnData.stats or {}
    st.session_keywords = (tonumber(st.session_keywords) or 0) + 1
    scenarioLearnData.stats = st
    bumpScenariosGen()
    invalidateUiCaches()
    return true
end

-- Scenario Learn Prune Scenario Bucket
function scenarioLearnPruneScenarioBucket(bucket)
    local list = {}
    for k, v in pairs(bucket) do
        list[#list + 1] = { key = k, count = tonumber(v.count) or 0, last_at = tonumber(v.last_at) or 0 }
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count < b.count end
        return a.last_at < b.last_at
    end)
    for i = 1, math.min(5, #list) do
        bucket[list[i].key] = nil
    end
end

-- Scenario Learn Find Scenario By Reply
function scenarioLearnFindScenarioByReply(answer)
    local want = scenarioLearnNormalizeAnswer(answer)
    if want == '' then return nil end
    for _, sc in ipairs(quickScenarios or {}) do
        if sc.enabled ~= false and sc.action ~= 'watch' then
            local got = scenarioLearnNormalizeAnswer(sc.reply or '')
            if got ~= '' and (got == want or got:find(want, 1, true) or want:find(got, 1, true)) then
                return sc.label or ''
            end
        end
    end
    return nil
end

-- Scenario Learn Track Manual Cluster
function scenarioLearnTrackManualCluster(question, answer)
    scenarioLearnData.manual_clusters = scenarioLearnData.manual_clusters or {}
    local aKey = scenarioLearnNormalizeAnswer(answer)
    if aKey == '' then return end
    local qKey = normalizeMatchText(question or '')
    local cluster = scenarioLearnData.manual_clusters[aKey]
    if type(cluster) ~= 'table' then
        cluster = { answer = trim(answer), count = 0, questions = {} }
        scenarioLearnData.manual_clusters[aKey] = cluster
    end
    cluster.count = (tonumber(cluster.count) or 0) + 1
    cluster.last_at = os.time()
    if qKey ~= '' and not cluster.questions[qKey] then
        cluster.questions[qKey] = trim(question)
    end
    if cluster.count >= SCENARIO_LEARN_MANUAL_PROMOTE_MIN then
        local scLabel = scenarioLearnFindScenarioByReply(answer)
        if scLabel and scLabel ~= '' then
            for _, q in pairs(cluster.questions) do
                scenarioLearnPromoteKeyword(scLabel, q)
            end
        end
    end
end

-- Scenario Learn Get Keywords For Scenario
function scenarioLearnGetKeywordsForScenario(label)
    if not scenarioLearnEnabled() then return nil end
    local bucket = scenarioLearnData.keywords_by_scenario and scenarioLearnData.keywords_by_scenario[label]
    if type(bucket) ~= 'table' then return nil end
    local out = {}
    for _, item in pairs(bucket) do
        if type(item) == 'table' and trim(item.kw or '') ~= '' then
            out[#out + 1] = item.kw
        end
    end
    if #out < 1 then return nil end
    return out
end

-- Scenario Learn On Reply
function scenarioLearnOnReply(question, answer, opts)
    if not scenarioLearnEnabled() then return end
    opts = opts or {}
    question = trim(question or '')
    answer = trim(answer or '')
    if scenarioLearnIsSkippableQuestion(question) then return end
    if scenarioLearnIsSkippableAnswer(answer) then return end

    local st = scenarioLearnData.stats or {}
    st.session_records = (tonumber(st.session_records) or 0) + 1
    st.total_records = (tonumber(st.total_records) or 0) + 1
    scenarioLearnData.stats = st
    scenarioLearnSessionKeywords = scenarioLearnSessionKeywords or 0

    local promoted = false
    if opts.scenarioLabel and opts.scenarioLabel ~= '' then
        promoted = scenarioLearnPromoteKeyword(opts.scenarioLabel, question) or promoted
    elseif opts.source == 'manual' then
        local scLabel = scenarioLearnFindScenarioByReply(answer)
        if scLabel and scLabel ~= '' then
            promoted = scenarioLearnPromoteKeyword(scLabel, question) or promoted
        else
            scenarioLearnTrackManualCluster(question, answer)
        end
    end

    scenarioLearnMarkDirty()
end

-- Scenario Learn Last Player Question
function scenarioLearnLastPlayerQuestion(t)
    if not t or type(t.messages) ~= 'table' then return '' end
    for i = #t.messages, 1, -1 do
        local m = t.messages[i]
        if m and messageKind(m) == 'player' then
            local body = messageBodyForScenarios(m)
            if body == '' then body = trim(m.text or '') end
            if body ~= '' then return body end
        end
    end
    return ''
end

-- Scenario Learn Count Keywords
function scenarioLearnCountKeywords()
    local n = 0
    local root = scenarioLearnData.keywords_by_scenario
    if type(root) ~= 'table' then return 0 end
    for _, bucket in pairs(root) do
        if type(bucket) == 'table' then
            for _ in pairs(bucket) do n = n + 1 end
        end
    end
    return n
end

-- Load Scenario Learn Data
function loadScenarioLearnData()
    local path = SCENARIO_LEARN_PATH
    if not doesFileExist(path) then return false end
    local chunk, err = loadfile(path)
    if not chunk then
        print('[Report Desk] scenario learn load: ' .. tostring(err))
        return false
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then return false end
    if type(data.keywords_by_scenario) == 'table' then
        scenarioLearnData.keywords_by_scenario = data.keywords_by_scenario
    end
    if type(data.stats) == 'table' then
        scenarioLearnData.stats = data.stats
        scenarioLearnData.stats.session_records = 0
        scenarioLearnData.stats.session_keywords = 0
    end
    if type(data.manual_clusters) == 'table' then
        scenarioLearnData.manual_clusters = data.manual_clusters
    end
    dirtyScenarioLearn = false
    return true
end

-- Save Scenario Learn Data
function saveScenarioLearnData()
    local dir = getWorkingDirectory() .. '\\config'
    if not doesDirectoryExist(dir) then createDirectory(dir) end
    local f, err = io.open(SCENARIO_LEARN_PATH, 'w')
    if not f then
        print('[Report Desk] scenario learn save: ' .. tostring(err))
        return false
    end
    f:write('-- Report Desk scenario learn data (UTF-8)\n')
    f:write('return {\n')
    f:write('  keywords_by_scenario = {\n')
    for label, bucket in pairs(scenarioLearnData.keywords_by_scenario or {}) do
        if type(bucket) == 'table' then
            f:write(string.format('    [%s] = {\n', luaQuoteUtf8(label)))
            for _, item in pairs(bucket) do
                if type(item) == 'table' and trim(item.kw or '') ~= '' then
                    f:write(string.format(
                        '      { kw = %s, count = %d, learned = true, last_at = %d },\n',
                        luaQuoteUtf8(item.kw), tonumber(item.count) or 1, tonumber(item.last_at) or 0
                    ))
                end
            end
            f:write('    },\n')
        end
    end
    f:write('  },\n')
    local st = scenarioLearnData.stats or {}
    f:write('  stats = {\n')
    f:write(string.format('    total_records = %d,\n', tonumber(st.total_records) or 0))
    f:write('  },\n')
    f:write('}\n')
    f:close()
    dirtyScenarioLearn = false
    return true
end

-- Init Scenario Learn
function initScenarioLearn()
    scenarioLearnSessionKeywords = 0
    pcall(loadScenarioLearnData)
end

pcall(initScenarioLearn)
