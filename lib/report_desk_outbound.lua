--[[ Модуль: исходящие команды в SAMP (sendChat, sendMenuOutbound). ]]

function sendChat(line)
    line = trim(line)
    if line == '' then return false end
    local cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line
    local ansHookBump = false
    if cmdBody:match('^ans%s') then
        local ansId, ansBody = cmdBody:match('^ans%s+(%d+)%s+(.*)$')
        if ansId and ansBody and ansBody ~= '' then
            ansBody = ensureWireCp1251(ansBody)
            local prefix = line:sub(1, 1) == '/' and '/ans ' or 'ans '
            line = prefix .. ansId .. ' ' .. ansBody
            cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line
        end
        if type(helpStatsRecordAns) == 'function' then
            pcall(helpStatsRecordAns)
        end
        if type(deskCache) == 'table' then
            deskCache.skipAnsStatsHook = (tonumber(deskCache.skipAnsStatsHook) or 0) + 1
            ansHookBump = true
        end
    end
    local spId = cmdBody:match('^sp%s+(%d+)%s*$')
    if spId and type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSpCommand then
        local skip = deskCache and tonumber(deskCache.skipSpHookLocal) and deskCache.skipSpHookLocal > 0
        if not skip then
            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spId), '')
        end
    end
    if line:sub(1, 1) ~= '/' then line = '/' .. line end
    local function releaseAnsHookSkip()
        if not ansHookBump or type(deskCache) ~= 'table' then return end
        local n = (tonumber(deskCache.skipAnsStatsHook) or 0) - 1
        deskCache.skipAnsStatsHook = n > 0 and n or nil
    end
    if type(sampSendChat) ~= 'function' then
        releaseAnsHookSkip()
        return false
    end
    local ok = pcall(sampSendChat, line)
    releaseAnsHookSkip()
    return ok
end

local specSessionMod

-- РњРµРЅСЋ /sp: sampSendChat РёРґС‘С‚ С‡РµСЂРµР· onSendCommand вЂ” skipSpHookLocal РЅРµ РґСѓР±Р»РёСЂСѓРµС‚ Р»РѕРєР°Р»СЊРЅС‹Р№ /sp.

local function sampTextInputBusy()
    return (type(sampIsChatInputActive) == 'function' and sampIsChatInputActive())
        or (type(sampIsDialogActive) == 'function' and sampIsDialogActive())
end

function sendMenuOutbound(line, opts)
    line = trim(line)
    if line == '' then return false end
    opts = type(opts) == 'table' and opts or {}
    local quietSp = opts.quietSp == true
    local skipPendingMark = opts.skipPendingMark == true or quietSp
    local cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line
    local cache = rawget(_G, 'deskCache')
    if quietSp and type(cache) == 'table' then
        cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
    end
    local isStCmd = cmdBody:match('^st%s+%d+') ~= nil
    if isStCmd and type(cache) == 'table' then
        cache.skipStStatsHook = (tonumber(cache.skipStStatsHook) or 0) + 1
    end
    local function skipPendingSp()
        if skipPendingMark then return true end
        return type(cache) == 'table' and tonumber(cache.skipSpHookLocal) and cache.skipSpHookLocal > 0
    end
    if sampTextInputBusy() then
        if not specSessionMod then
            local okReq, mod = pcall(require, 'report_desk_spectate_session')
            specSessionMod = okReq and mod or false
        end
        local spIdBusy = cmdBody:match('^sp%s+(%d+)%s*$')
        if spIdBusy and not skipPendingSp()
                and type(deskSpectateStats) == 'table'
                and deskSpectateStats.markPendingSpCommand then
            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spIdBusy), '')
        end
        if specSessionMod and specSessionMod.queueOutbound then
            pcall(specSessionMod.queueOutbound, cmdBody)
        end
        if type(cache) == 'table' then
            local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
            cache.skipSpHookLocal = n > 0 and n or nil
            if isStCmd then
                local sn = (tonumber(cache.skipStStatsHook) or 0) - 1
                cache.skipStStatsHook = sn > 0 and sn or nil
            end
        end
        return true
    end
    local spId = cmdBody:match('^sp%s+(%d+)%s*$')
    if spId and not skipPendingSp() and type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSpCommand then
        pcall(deskSpectateStats.markPendingSpCommand, tonumber(spId), '')
    end
    if type(cache) == 'table' and not quietSp then
        cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
    end
    local ok = false
    if type(sendChat) == 'function' then
        local callOk, sent = pcall(sendChat, line)
        ok = callOk and sent ~= false
    end
    if type(cache) == 'table' then
        local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
        cache.skipSpHookLocal = n > 0 and n or nil
        if isStCmd then
            local sn = (tonumber(cache.skipStStatsHook) or 0) - 1
            cache.skipStStatsHook = sn > 0 and sn or nil
        end
    end
    return ok
end
