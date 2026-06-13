--[[ Intent trigger / exclusion matching and scoring. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

function intentClauseMatches(bags, clause, allowStem)
    if type(clause) ~= 'table' then return false end
    if clause.requires_id then
        return extractReportSuspectId(bags.raw or '') ~= nil
    end
    if clause.token and trim(clause.token) ~= '' then
        return intentMessageHasToken(bags, clause.token, allowStem)
    end
    if type(clause.all) == 'table' and #clause.all > 0 then
        if not intentMessageHasAllTokens(bags, clause.all, allowStem) then return false end
    end
    if type(clause.any) == 'table' and #clause.any > 0 then
        if not intentMessageHasAnyToken(bags, clause.any, allowStem) then return false end
    end
    if type(clause.none) == 'table' and #clause.none > 0 then
        if not intentMessageHasNoneTokens(bags, clause.none, allowStem) then return false end
    end
    if clause.all or clause.any or clause.token or clause.requires_id then
        return true
    end
    if type(clause.none) == 'table' and #clause.none > 0 then
        return true
    end
    return false
end

function intentExclusionMatches(bags, exclusions, allowStem)
    if type(exclusions) ~= 'table' then return false end
    for _, clause in ipairs(exclusions) do
        if intentClauseMatches(bags, clause, allowStem) then
            return true
        end
    end
    return false
end

function intentCountClauseTokens(clause)
    if type(clause) ~= 'table' then return 0 end
    if clause.requires_id then return 2 end
    if clause.token and trim(clause.token) ~= '' then return 1 end
    local n = 0
    if type(clause.all) == 'table' then n = n + #clause.all end
    if type(clause.any) == 'table' then n = n + #clause.any end
    return n
end

function intentScoreTriggerClause(bags, clause, allowStem)
    if not intentClauseMatches(bags, clause, allowStem) then return 0 end
    local score = 0
    if clause.requires_id then return 24 end
    if clause.token and trim(clause.token) ~= '' then
        score = 10 + math.min(#normalizeMatchText(clause.token), 12)
    end
    if type(clause.all) == 'table' then
        for _, t in ipairs(clause.all) do
            score = score + 10 + math.min(#normalizeMatchText(t), 8)
        end
        if #clause.all >= 2 then score = score + 5 end
    end
    if type(clause.any) == 'table' and #clause.any > 0 then
        score = score + 6
    end
    return score
end

function intentBestTriggerScore(bags, intent)
    if not intent or type(intent.triggers) ~= 'table' then return 0 end
    local allowStem = intent.stem == true
    local groups = intent.triggers.any
    if type(groups) ~= 'table' then return 0 end
    local best = 0
    for _, clause in ipairs(groups) do
        best = math.max(best, intentScoreTriggerClause(bags, clause, allowStem))
    end
    if type(intent.requires) == 'table' then
        for _, req in ipairs(intent.requires) do
            if not intentClauseMatches(bags, req, allowStem) then
                return 0
            end
            best = best + 8
        end
    end
    return best
end

function intentMatches(bags, intent, context)
    if not intent or intent.enabled == false then return false, 0 end
    if context and intent.context and intent.context ~= context then return false, 0 end
    local allowStem = intent.stem == true
    if intentExclusionMatches(bags, intent.exclusions, allowStem) then
        return false, 0
    end
    local score = intentBestTriggerScore(bags, intent)
    if score <= 0 then return false, 0 end
    return true, score
end

function intentFirstTokens(intent)
    local out = {}
    local seen = {}
    local function addToken(t)
        t = normalizeMatchText(t)
        if t ~= '' and #t >= 3 and not seen[t] then
            seen[t] = true
            out[#out + 1] = t
        end
    end
    if type(intent.triggers) ~= 'table' or type(intent.triggers.any) ~= 'table' then
        return out
    end
    for _, clause in ipairs(intent.triggers.any) do
        if clause.requires_id then
            addToken('id')
        end
        if clause.token then addToken(clause.token) end
        if type(clause.all) == 'table' then
            for _, t in ipairs(clause.all) do addToken(t) end
        end
        if type(clause.any) == 'table' then
            for _, t in ipairs(clause.any) do addToken(t) end
        end
    end
    return out
end
