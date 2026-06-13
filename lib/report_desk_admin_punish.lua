--[[ Модуль: автовыдача наказаний по запросу в admin chat (/a). ]]
-- REWRITTEN: line dedup prune, parse-fail rollback, hooksActive guard.
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local PUNISH_TIMEOUT_SEC = 15
local OVERLAY_W = 420
local OVERLAY_BOTTOM_MARGIN = 62
local AP_HINT_GAP = 20

local AP_SEEN_GLOBAL = rawget(_G, '__DESK_AP_SEEN')
if type(AP_SEEN_GLOBAL) ~= 'table' then
    AP_SEEN_GLOBAL = { req = {}, line = {} }
    rawset(_G, '__DESK_AP_SEEN', AP_SEEN_GLOBAL)
end

local apState = {
    pending = nil,
    executing = false,
    bindField = nil,
    bindCapture = false,
    handled = {},
    handledOrd = {},
    handledPerm = {},
    reqSeen = AP_SEEN_GLOBAL.req,
    pendingOfflineSince = nil,
    punishLogDedup = { key = '', at = 0 },
    punishLogQueue = {},
    bootstrapped = false,
}
local AP_LINE_REJECT_SEC = 50
local AP_REQ_SEEN_SEC = PUNISH_TIMEOUT_SEC + 30
local AP_POLL_RECENT = 40
local AP_POLL_LINES_FALLBACK = 24
local AP_POLL_INTERVAL_FALLBACK = 0.45
local AP_OFFLINE_CANCEL_SEC = 0.35
local AP_HANDLED_MAX = 512
local AP_LINE_SEEN_MAX = 2048
local AP_HOOK_REINSTALL_SEC = 30.0
local apPollLastAt = 0
local apHookReinstallAt = 0

local function apMono()
    if type(getGameTimer) == 'function' then
        local ok, ms = pcall(getGameTimer)
        if ok and ms then return (tonumber(ms) or 0) / 1000.0 end
    end
    return os.clock()
end

local spThemeMod

local function apTheme()
    if spThemeMod == false then return nil end
    if not spThemeMod then
        local ok, mod = pcall(require, 'report_desk_sp_theme')
        spThemeMod = ok and mod or false
    end
    return spThemeMod or nil
end

-- Ensure Admin Punish Settings
function ensureAdminPunishSettings()
    if type(settings) ~= 'table' then return end
    if settings.admin_punish_enabled == nil then settings.admin_punish_enabled = false end
    if settings.admin_punish_sign_cmd == nil then settings.admin_punish_sign_cmd = true end
    local ck = tonumber(settings.admin_punish_confirm_key)
    if not ck or ck <= 0 then settings.admin_punish_confirm_key = vkeys.VK_DELETE end
    local xk = tonumber(settings.admin_punish_cancel_key)
    if not xk or xk <= 0 then settings.admin_punish_cancel_key = vkeys.VK_END end
    if type(deskBindKeysOverlap) == 'function'
            and deskBindKeysOverlap(settings.admin_punish_confirm_key, settings.admin_punish_cancel_key) then
        if deskBindKeysOverlap(settings.admin_punish_confirm_key, vkeys.VK_END) then
            settings.admin_punish_cancel_key = vkeys.VK_ESCAPE
        else
            settings.admin_punish_cancel_key = vkeys.VK_END
        end
    end
end

local function apPlayerConnected(id)
    id = clampSuspectPlayerId and clampSuspectPlayerId(id) or tonumber(id)
    if not id then return false end
    if not isSampAvailable or not isSampAvailable() then return false end
    if type(sampIsPlayerConnected) ~= 'function' then return false end
    return sampIsPlayerConnected(id)
end

local function apPlainText(text)
    if type(normalizeChatLine) == 'function' then
        return normalizeChatLine(text)
    end
    if type(stripChatTimestamp) == 'function' and type(stripTags) == 'function' then
        return trim(stripChatTimestamp(stripTags(text or '')))
    end
    if type(stripTags) == 'function' then
        return trim(stripTags(text or ''))
    end
    return trim(text or '')
end

-- AdminTools: string.find(text, "]: /") — только строки с командой, не весь /a чат.
local function apHasPunishCommand(plain)
    plain = trim(plain or '')
    if plain == '' then return false end
    if plain:find(']: /', 1, true) then return true end
    if plain:match('%]:%s*/') then return true end
    if plain:find('^%[A%]%s', 1) and plain:match('/[%a_]') then return true end
    if plain:find('^[%w][%w_]+%[%d+%]%:%s*/', 1) then return true end
    return false
end

local function apIsAdminChatLine(color, plain)
    if apHasPunishCommand(plain) then return true end
    plain = trim(plain or '')
    if plain:find('^%[A%]%s', 1) and plain:match('/[%a_]') then return true end
    if plain:find('^[%w][%w_]+%[%d+%]%:%s*/', 1) then return true end
    return false
end

-- Строка похожа на запрос наказания в /a (для poll, не зависит от chatSeen).
function lineLooksLikeAdminPunishRequest(plain, color)
    return apIsAdminChatLine(color, plain)
end

-- Lua: a,b,c = s:match(p1) or s:match(p2) оставляет только первый capture при or — нельзя.
-- NO-API: other admins' /a requests appear only in chat.
local function apParseAdminRequest(plain)
    plain = trim(plain or '')
    if plain == '' then return nil end
    -- Как AdminTools: [A] Name[id]: /cmd (пробел после [A] необязателен)
    local admName, admId, admCommand = plain:match('^%[A%]%s*(.-)%[(%d+)%]%:%s*(.*)')
    if not admId then
        admName, admId, admCommand = plain:match('^([%w][%w_]*)%[(%d+)%]%:%s*(/.*)$')
    end
    if not admId or not admCommand then return nil end
    admCommand = trim(admCommand)
    if admCommand == '' or admCommand:sub(1, 1) ~= '/' then return nil end
    return trim(admName), tonumber(admId), admCommand
end

local function apIsDirectCommand(cmd)
    return cmd:match('^/unban%s')
        or cmd:match('^/unwarn%s')
        or cmd:match('^/unmute%s')
        or cmd:match('^/unjail%s')
        or cmd:match('^/tr%s')
end

local function apEnabled()
    return type(settings) == 'table' and settings.admin_punish_enabled == true
end

local function apMinLevel()
    return getLocalAdminLevel and getLocalAdminLevel() or 3
end

local function apIsCatalogAdmin(nick)
    if not nick or nick == '' then return false end
    if type(checkerIsCatalogAdmin) == 'function' then
        return checkerIsCatalogAdmin(nick) == true
    end
    if type(Catalog) == 'table' and type(Catalog.getAdmin) == 'function' then
        return Catalog.getAdmin(nick) ~= nil
    end
    return false
end

local function apBlocksTargetAdmin(cmd)
    if not cmd or cmd == '' then return false end
    local skip = {
        '/skin', '/hp', '/unmute', '/unwarn', '/unban', '/msg', '/areg', '/unjail',
    }
    for _, s in ipairs(skip) do
        if cmd:find(s, 1, true) then return false end
    end
    return true
end

local function apAdminSurname(admName)
    admName = trim(tostring(admName or ''))
    if admName == '' then return '?' end
    local surname = admName:match('_(%w+)$')
    if surname and surname ~= '' then return surname end
    return admName
end

local function apSignSuffix(admName)
    if settings.admin_punish_sign_cmd == false then return '' end
    local surname = apAdminSurname(admName)
    if surname == '?' then return '' end
    return ' / by ' .. surname
end

local function apMuteHasReason(cmd)
    return cmd:match('^/mute%s+%d+%s+%d+%s+(.+)$') ~= nil
end

-- Как AdminTools: /mute без причины — без подписи; с причиной — с подписью; /un* — без.
local function apNeedsSignSuffix(cmd)
    if apIsDirectCommand(cmd) then return false end
    if cmd:match('^/mute') then
        return apMuteHasReason(cmd)
    end
    return true
end

local function apOutboundCmd(cmd, admName)
    if apNeedsSignSuffix(cmd) then
        return cmd .. apSignSuffix(admName)
    end
    return cmd
end

-- Ключ без метки времени: hook и poll дают разный chatLineSeenKey, plain одинаковый.
local function apStableLineKey(text)
    return apPlainText(text)
end

local function apNormalizeCommand(cmd)
    cmd = trim(tostring(cmd or ''))
    if cmd == '' then return '' end
    return (cmd:gsub('%s+', ' '))
end

local function apRequestKey(admId, admCommand)
    admId = tonumber(admId) or 0
    admCommand = apNormalizeCommand(admCommand)
    if admCommand == '' then return '' end
    return tostring(admId) .. '|' .. admCommand
end

local function apIsOwnAutovydachaLog(plain)
    plain = trim(plain or '')
    if plain == '' then return false end
    if plain:find('[\xC0\xE2\xF2\xEE\xE2\xFB\xE4\xE0\xF7\xE0]', 1, true) then return true end
    if plain:find('[ReportDesk]', 1, true) and plain:find('/[%a_]', 1) == nil then return true end
    return false
end

local function apIsAdminRequestLine(plain)
    plain = trim(plain or '')
    if plain == '' then return false end
    if plain:find('^%[A%]%s', 1) and plain:match('/[%a_]') then return true end
    if plain:find('^[%w][%w_]+%[%d+%]%:%s*/', 1) then return true end
    return false
end

local function apPruneHandled()
    local guard = 0
    while #apState.handledOrd > AP_HANDLED_MAX and guard < AP_HANDLED_MAX do
        guard = guard + 1
        local old = table.remove(apState.handledOrd, 1)
        if not old then break end
        if apState.handledPerm[old] then
            apState.handledOrd[#apState.handledOrd + 1] = old
        else
            apState.handled[old] = nil
        end
    end
end

local function apLineHandledEntry(lineKey)
    if not lineKey or lineKey == '' then return nil end
    local e = apState.handled[lineKey]
    if not e then return nil end
    if e.perm or e.kind == 'ok' then return e end
    if apMono() - (e.at or 0) >= AP_LINE_REJECT_SEC then
        apState.handled[lineKey] = nil
        return nil
    end
    return e
end

local function apPruneLineSeen()
    local ord = AP_SEEN_GLOBAL.lineOrd
    if type(ord) ~= 'table' then return end
    local line = AP_SEEN_GLOBAL.line
    while #ord > AP_LINE_SEEN_MAX do
        local old = table.remove(ord, 1)
        if old then line[old] = nil end
    end
end

local function apClaimLineKey(lineKey)
    if not lineKey or lineKey == '' then return false end
    if AP_SEEN_GLOBAL.line[lineKey] then return false end
    AP_SEEN_GLOBAL.line[lineKey] = true
    local ord = AP_SEEN_GLOBAL.lineOrd
    if type(ord) ~= 'table' then
        ord = {}
        AP_SEEN_GLOBAL.lineOrd = ord
    end
    ord[#ord + 1] = lineKey
    apPruneLineSeen()
    return true
end

local function apReleaseLineKey(lineKey)
    if not lineKey or lineKey == '' then return end
    AP_SEEN_GLOBAL.line[lineKey] = nil
end

local function apMarkLineConsumed(lineKey)
    if not lineKey or lineKey == '' then return end
    apState.handledPerm[lineKey] = true
    AP_SEEN_GLOBAL.line[lineKey] = true
end

local function apLineGloballyConsumed(lineKey)
    if not lineKey or lineKey == '' then return false end
    if apState.handledPerm[lineKey] then return true end
    return AP_SEEN_GLOBAL.line[lineKey] == true
end

local function apRequestSeenRecently(dedupKey)
    dedupKey = trim(tostring(dedupKey or ''))
    if dedupKey == '' then return false end
    local at = tonumber(apState.reqSeen[dedupKey]) or 0
    if at <= 0 then return false end
    if apMono() - at > AP_REQ_SEEN_SEC then
        apState.reqSeen[dedupKey] = nil
        return false
    end
    return true
end

local function apMarkRequestSeen(dedupKey)
    dedupKey = trim(tostring(dedupKey or ''))
    if dedupKey == '' then return end
    apState.reqSeen[dedupKey] = apMono()
end

local function apPruneRequestSeen()
    local now = apMono()
    for key, at in pairs(apState.reqSeen) do
        if now - (tonumber(at) or 0) > AP_REQ_SEEN_SEC then
            apState.reqSeen[key] = nil
        end
    end
end

-- После /reload буфер чата содержит старые /a — помечаем без уведомлений.
local function apBootstrapChatBuffer()
    if apState.bootstrapped or not apEnabled() then return end
    apState.bootstrapped = true
    if not sampGetChatString then return end
    for i = 0, AP_POLL_RECENT - 1 do
        local line = sampGetChatString(i) or ''
        if line ~= '' then
            local plain = apPlainText(line)
            if apHasPunishCommand(plain) then
                local lineKey = apStableLineKey(line)
                if lineKey ~= '' then
                    apMarkLineConsumed(lineKey)
                end
                local admName, admId, admCommand = apParseAdminRequest(plain)
                if admId and admCommand then
                    apMarkRequestSeen(apRequestKey(admId, admCommand))
                end
            end
        end
    end
    apPruneRequestSeen()
    apPruneLineSeen()
end

local function apSealPending(p)
    if not p then return end
    if p.stableLineKey and p.stableLineKey ~= '' then
        apMarkLineConsumed(p.stableLineKey)
    end
    if p.dedupKey and p.dedupKey ~= '' then
        apMarkRequestSeen(p.dedupKey)
    elseif p.admId and p.command then
        apMarkRequestSeen(apRequestKey(p.admId, p.command))
    end
end

local AP_PUNISH_HEADS = {
    jail = true, unjail = true, mute = true, unmute = true, kick = true, warn = true,
    ban = true, skick = true, tr = true, unwarn = true, unban = true,
    offmute = true, offjail = true, offban = true, offwarn = true,
}

local AP_PUNISH_HEAD_TO_KIND = {
    jail = 'jail', unjail = 'jail', offjail = 'jail',
    mute = 'mute', unmute = 'mute', offmute = 'mute',
    kick = 'kick', skick = 'kick',
    ban = 'ban', unban = 'ban', offban = 'ban',
    warn = 'warn', unwarn = 'warn', offwarn = 'warn',
    tr = 'tr',
}

local AP_PUNISH_SKIP_FIRST = {
    ans = true, sp = true, spec = true, st = true, c = true, cc = true,
    history = true, hist = true, iget = true, ilog = true, iskill = true,
    admins = true, adms = true, leaders = true, pm = true, me = true, ['do'] = true,
    r = true, report = true, time = true, watch = true,
}

local function apCommandHead(cmd)
    cmd = trim(tostring(cmd or ''))
    if cmd == '' then return '' end
    if cmd:sub(1, 1) ~= '/' then cmd = '/' .. cmd end
    local head = cmd:match('^/(%S+)')
    return head and head:lower() or ''
end

local function apCommandLooksSupported(cmd)
    return AP_PUNISH_HEADS[apCommandHead(cmd)] == true
end

local function apPunishKindFromCommand(cmd)
    return AP_PUNISH_HEAD_TO_KIND[apCommandHead(cmd)] or 'other'
end

-- Быстрый фильтр в chat/command hooks: не парсим /ans, /sp и прочий шум.
function adminPunishOutgoingLooksRelevant(message)
    message = trim(tostring(message or ''))
    if message == '' then return false end
    local lc = message:lower()
    if lc:sub(1, 4) == '/ans' or lc:match('^ans%s') then return false end
    local first = message:match('^/?(%S+)')
    if not first then return false end
    first = first:lower()
    if AP_PUNISH_SKIP_FIRST[first] then return false end
    if first == 'a' then
        local punishPart = message:match('^/?a%s+(/.*)$')
        if not punishPart then return false end
        return apCommandLooksSupported(trim(punishPart))
    end
    local cmd = message:sub(1, 1) == '/' and message or '/' .. message
    return apCommandLooksSupported(cmd)
end

local function apNotifyPending(p)
    if not p then return end
    local target = trim(p.playerName or p.snapshotNick or '?')
    local tid = tonumber(p.playerId)
    local targetShow = (tid and tid >= 0) and string.format('%s[%d]', target, tid) or target
    say(string.format(
        '{9E7BEF}[\xC0\xE2\xF2\xEE\xE2\xFB\xE4\xE0\xF7\xE0]{FFFFFF} %s[%d] \xB7 %s \xB7 %s',
        p.admName or '?', p.admId or 0, p.action or '-', targetShow))
end

local function apClearPending(reason)
    if apState.executing then
        if not reason then return end
        apState.executing = false
    end
    local p = apState.pending
    if p then
        apSealPending(p)
    end
    if p and reason then
        say(reason)
    end
    apState.pending = nil
    apState.pendingOfflineSince = nil
end

local function apSyncBindKeyPrev()
    ensureAdminPunishSettings()
    local prev = deskCache.adminPunishBindPrev
    local keys = {
        tonumber(settings.admin_punish_confirm_key) or 0,
        tonumber(settings.admin_punish_cancel_key) or 0,
    }
    for _, vk in ipairs(keys) do
        deskBindSyncKeyPrev(vk, prev)
    end
end

local function apSetPending(p, opts)
    if not p then return end
    opts = type(opts) == 'table' and opts or {}
    local dedupKey = p.dedupKey or apRequestKey(p.admId, p.command)
    p.dedupKey = dedupKey

    local cur = apState.pending
    if cur and cur.dedupKey == dedupKey then
        cur.tick = apMono()
        if p.stableLineKey and p.stableLineKey ~= '' then
            apMarkLineConsumed(p.stableLineKey)
        end
        return
    end

    p.snapshotNick = trim(p.playerName or '')
    if p.snapshotNick == '' and tonumber(p.playerId) and tonumber(p.playerId) >= 0 then
        p.snapshotNick = trim(sampGetPlayerNickname(p.playerId) or '')
    end
    if type(nickKey) == 'function' then
        p.snapshotNickKey = nickKey(p.snapshotNick)
    else
        p.snapshotNickKey = p.snapshotNick:lower()
    end
    apState.pending = p
    apState.pendingOfflineSince = nil
    apSyncBindKeyPrev()
    if not opts.silent then
        apNotifyPending(p)
        if settings.sound and playSoundFrontEnd then
            pcall(playSoundFrontEnd, 4)
        end
    end
end

-- Статус цели для online-ID: ok / offline / nick_changed. Offline-nick команды — na.
local function apLiveTargetStatus(p)
    if not p then return nil end
    local pid = clampSuspectPlayerId and clampSuspectPlayerId(p.playerId) or tonumber(p.playerId)
    if not pid or pid < 0 then
        return {
            mode = 'offline_nick',
            status = 'na',
            nickOk = true,
            connected = nil,
            playerId = -1,
            snapshotNick = p.snapshotNick or p.playerName,
            liveNick = p.snapshotNick or p.playerName,
        }
    end
    local snapNick = p.snapshotNick or p.playerName or ''
    if not apPlayerConnected(pid) then
        return {
            mode = 'online_id',
            status = 'offline',
            nickOk = false,
            connected = false,
            playerId = pid,
            snapshotNick = snapNick,
            liveNick = '',
        }
    end
    local liveNick = trim(sampGetPlayerNickname(pid) or '')
    local snapKey = p.snapshotNickKey
    if not snapKey or snapKey == '' then
        snapKey = type(nickKey) == 'function' and nickKey(snapNick) or snapNick:lower()
    end
    local liveKey = type(nickKey) == 'function' and nickKey(liveNick) or liveNick:lower()
    local nickOk = snapKey ~= '' and liveKey ~= '' and snapKey == liveKey
    return {
        mode = 'online_id',
        status = nickOk and 'ok' or 'nick_changed',
        nickOk = nickOk,
        connected = true,
        playerId = pid,
        snapshotNick = snapNick,
        liveNick = liveNick,
    }
end

local function apRefreshPendingNick(p)
    if not p then return end
    local pid = tonumber(p.playerId)
    if not pid or pid < 0 or not apPlayerConnected(pid) then return end
    local live = trim(sampGetPlayerNickname(pid) or '')
    if live == '' then return end
    local snap = trim(p.snapshotNick or p.playerName or '')
    if snap == '' or snap:match('^ID %d+$') then
        p.playerName = live
        p.snapshotNick = live
        if type(nickKey) == 'function' then
            p.snapshotNickKey = nickKey(live)
        else
            p.snapshotNickKey = live:lower()
        end
    end
end

local function apCanExecutePending(p)
    apRefreshPendingNick(p)
    local st = apLiveTargetStatus(p)
    if not st then return false, nil, nil end
    if st.mode == 'offline_nick' or st.status == 'na' then
        return true, st, nil
    end
    if st.status == 'offline' then
        return false, st, string.format(
            '\xC8\xE3\xF0\xEE\xEA %s[%d] \xE2\xFB\xF8\xE5\xEB \xF1 \xF1\xE5\xF0\xE2\xE5\xF0\xE0. \xC7\xE0\xEF\xF0\xEE\xF1 \xEE\xF2\xEC\xE5\xED\xB8\xED.',
            st.snapshotNick or '?', st.playerId or 0)
    end
    if st.status == 'nick_changed' then
        return false, st, string.format(
            '\xCD\xE0 ID %d \xE1\xFB\xEB %s, \xF1\xE5\xE9\xF7\xE0\xF1 %s. \xCD\xE0\xEA\xE0\xE7\xE0\xED\xE8\xE5 \xED\xE5 \xE2\xFB\xE4\xE0\xED\xEE.',
            st.playerId or 0, st.snapshotNick or '?', st.liveNick ~= '' and st.liveNick or '?')
    end
    return true, st, nil
end

local function apBuildOutboundPreview(p)
    if not p or not p.command then return '' end
    return apOutboundCmd(p.command, p.admName)
end

local function apResolveOnlineNick(id)
    id = tonumber(id)
    if not id then return nil, nil end
    local nick = 'ID ' .. tostring(id)
    if apPlayerConnected(id) and type(sampGetPlayerNickname) == 'function' then
        local live = trim(sampGetPlayerNickname(id) or '')
        if live ~= '' then nick = live end
    end
    return id, nick
end

local function apMakeOnlineCmd(cmd, action, id, term, reason)
    local pid, nick = apResolveOnlineNick(id)
    if not pid then return nil end
    return {
        command = cmd,
        action = action,
        playerId = pid,
        playerName = nick,
        term = term or '-',
        reason = reason or '-',
    }
end

-- Разбор команды наказания без проверки уровня (для /a и журнала).
function apParsePunishCommand(admCommand)
    local cmd = trim(tostring(admCommand or ''))
    if cmd == '' or cmd:sub(1, 1) ~= '/' then return nil end

    local id, term, reason = cmd:match('^/jail%s+(%d+)%s+(%d+)%s+(.+)$')
    if id and term and reason then
        return apMakeOnlineCmd(cmd, '\xCF\xEE\xF1\xE0\xE4\xE8\xF2\xFC \xE2 \xF2\xFE\xF0\xFC\xEC\xF3', id, term, reason)
    end

    id = cmd:match('^/unjail%s+(%d+)$')
    if id then
        return apMakeOnlineCmd(cmd, '\xC2\xFB\xEF\xF3\xF1\xF2\xE8\xF2\xFC \xE8\xE7 \xF2\xFE\xF0\xFC\xEC\xFB', id)
    end

    id = cmd:match('^/unmute%s+(%d+)$')
    if id then
        return apMakeOnlineCmd(cmd, '\xD1\xED\xFF\xF2\xFC \xE7\xE0\xF2\xFB\xF7\xEA\xF3', id)
    end

    id, reason = cmd:match('^/kick%s+(%d+)%s+(.+)$')
    if id and reason then
        return apMakeOnlineCmd(cmd, '\xCA\xE8\xEA\xED\xF3\xF2\xFC', id, '-', reason)
    end

    id, term = cmd:match('^/mute%s+(%d+)%s+(%d+)')
    if id and term then
        reason = cmd:match('^/mute%s+%d+%s+%d+%s+(.+)$') or '-'
        return apMakeOnlineCmd(cmd, '\xC7\xE0\xEC\xF3\xF2\xE8\xF2\xFC', id, term, reason)
    end

    id, reason = cmd:match('^/warn%s+(%d+)%s+(.+)$')
    if id and reason then
        return apMakeOnlineCmd(cmd, '\xC7\xE0\xE2\xE0\xF0\xED\xE8\xF2\xFC', id, '-', reason)
    end

    id, term, reason = cmd:match('^/ban%s+(%d+)%s+(%d+)%s+(.+)$')
    if id and term and reason then
        return apMakeOnlineCmd(cmd, '\xC7\xE0\xE1\xE0\xED\xE8\xF2\xFC', id, term, reason)
    end

    local nick, offTerm, offReason = cmd:match('^/offmute%s+(%S+)%s+(%d+)%s+(.+)$')
    if nick and offTerm and offReason then
        return {
            command = cmd,
            action = '\xCE\xF4\xF4\xEB\xE0\xE9\xED \xE7\xE0\xF2\xFB\xF7\xEA\xE0',
            playerId = -1,
            playerName = nick,
            term = offTerm,
            reason = offReason,
        }
    end

    nick, offTerm, offReason = cmd:match('^/offjail%s+(%S+)%s+(%d+)%s+(.+)$')
    if nick and offTerm and offReason then
        return {
            command = cmd,
            action = '\xCE\xF4\xF4\xEB\xE0\xE9\xED \xF2\xFE\xF0\xFC\xEC\xE0',
            playerId = -1,
            playerName = nick,
            term = offTerm,
            reason = offReason,
        }
    end

    id = cmd:match('^/skick%s+(%d+)$')
    if id then
        return apMakeOnlineCmd(cmd, '\xD1\xEA\xE8\xEA', id)
    end

    id = cmd:match('^/tr%s+(%d+)')
    if id then
        local pid, resolvedNick = apResolveOnlineNick(id)
        if not pid then return nil end
        return {
            command = string.format('/tr %d', pid),
            action = '\xC4\xEE\xF1\xF2\xE0\xF2\xFC \xE8\xE7 \xE2\xEE\xE4\xFB',
            playerId = pid,
            playerName = resolvedNick,
            term = '-',
            reason = '-',
        }
    end

    id = cmd:match('^/unwarn%s+(%d+)$')
    if id then
        return apMakeOnlineCmd(cmd, '\xD1\xED\xFF\xF2\xFC \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xE5', id)
    end

    nick, offTerm, offReason = cmd:match('^/offban%s+(%S+)%s+(%d+)%s+(.+)$')
    if nick and offTerm and offReason then
        return {
            command = cmd,
            action = '\xCE\xF4\xF4\xEB\xE0\xE9\xED \xE1\xE0\xED',
            playerId = -1,
            playerName = nick,
            term = offTerm,
            reason = offReason,
        }
    end

    nick, offReason = cmd:match('^/offwarn%s+(%S+)%s+(.+)$')
    if nick and offReason then
        return {
            command = cmd,
            action = '\xCE\xF4\xF4\xEB\xE0\xE9\xED \xE2\xE0\xF0\xED',
            playerId = -1,
            playerName = nick,
            term = '-',
            reason = offReason,
        }
    end

    nick = cmd:match('^/unban%s+(%S+)$')
    if nick then
        return {
            command = cmd,
            action = '\xD0\xE0\xE7\xE1\xE0\xED\xE8\xF2\xFC',
            playerId = -1,
            playerName = nick,
            term = '-',
            reason = '-',
        }
    end

    nick = cmd:match('^/unwarn%s+(%S+)$')
    if nick then
        return {
            command = cmd,
            action = '\xD1\xED\xFF\xF2\xFC \xE2\xE0\xF0\xED',
            playerId = -1,
            playerName = nick,
            term = '-',
            reason = '-',
        }
    end

    nick = cmd:match('^/unmute%s+(%S+)$')
    if nick then
        return {
            command = cmd,
            action = '\xD1\xED\xFF\xF2\xFC \xEE\xF4\xF4\xEB\xE0\xE9\xED \xEC\xF3\xF2',
            playerId = -1,
            playerName = nick,
            term = '-',
            reason = '-',
        }
    end

    nick = cmd:match('^/unjail%s+(%S+)$')
    if nick then
        return {
            command = cmd,
            action = '\xCE\xF4\xF4\xEB\xE0\xE9\xED \xE2\xFB\xEF\xF3\xF1\xEA',
            playerId = -1,
            playerName = nick,
            term = '-',
            reason = '-',
        }
    end

    if apCommandLooksSupported(cmd) then
        return nil
    end
    return nil
end

local function apPunishCommandAllowedAtLevel(cmd, lvl)
    lvl = tonumber(lvl) or 0
    if cmd:match('^/jail') or cmd:match('^/unjail%s+%d')
            or cmd:match('^/unmute%s+%d') or cmd:match('^/kick')
            or cmd:match('^/mute') or cmd:match('^/unjail%s+%S')
            or cmd:match('^/unmute%s+%S') then
        return lvl >= 2
    end
    if cmd:match('^/warn') or cmd:match('^/ban') or cmd:match('^/offmute')
            or cmd:match('^/offjail') or cmd:match('^/skick') or cmd:match('^/tr') then
        return lvl >= 3
    end
    if cmd:match('^/unwarn%s+%d') or cmd:match('^/offban') or cmd:match('^/offwarn')
            or cmd:match('^/unban') or cmd:match('^/unwarn%s+%S') then
        return lvl >= 4
    end
    return false
end

local function apTryParse(admCommand)
    local cmd = trim(tostring(admCommand or ''))
    if cmd == '' or cmd:sub(1, 1) ~= '/' then return nil end
    local parsed = apParsePunishCommand(cmd)
    if not parsed then return nil end
    if not apPunishCommandAllowedAtLevel(cmd, apMinLevel()) then return nil end
    return parsed
end

-- NO-API: punishment log echo is server chat only.
local function apAnotherAdminExecuted(text)
    local p = apState.pending
    if not p then return false end
    local plain = apPlainText(text)
    if plain == '' then return false end
    if apIsOwnAutovydachaLog(plain) then return false end
    if apIsAdminRequestLine(plain) then return false end
    local target = trim(p.playerName or p.snapshotNick or '')
    if target == '' then return false end
    local pid = tonumber(p.playerId)
    local mayRelate = plain:find(target, 1, true)
        or plain:find('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 ', 1, true)
    if not mayRelate and pid and pid >= 0 and p.command and p.command:match('^/tr') then
        mayRelate = plain:find('/tr%s+' .. tostring(pid), 1) ~= nil
    end
    if not mayRelate then return false end
    local needles = {
        ' \xEF\xEE\xF1\xE0\xE4\xE8\xEB \xE2 \xF2\xFE\xF0\xFC\xEC\xF3 ' .. target,
        ' \xE2\xFB\xF2\xE0\xF9\xE8\xEB \xE8\xE7 \xF2\xFE\xF0\xFC\xEC\xFB ' .. target,
        ' \xF0\xE0\xE7\xE1\xE0\xED\xE8\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target,
        ' \xEA\xE8\xEA\xED\xF3\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target,
        ' \xEF\xEE\xF1\xF2\xE0\xE2\xE8\xEB \xE7\xE0\xF2\xFB\xF7\xEA\xF3 \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target,
        ' \xEF\xEE\xF1\xF2\xE0\xE2\xE8\xEB \xE7\xE0\xF2\xFB\xF7\xEA\xF3 \xEE\xF4\xF4\xEB\xE0\xE9\xED \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target,
        ' \xE2\xFB\xE4\xE0\xEB \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xE5 \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target,
        ' \xE2\xFB\xE4\xE0\xEB \xEE\xF4\xF4\xEB\xE0\xE9\xED \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xE5 \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target,
        ' \xE7\xE0\xE1\xE0\xED\xE8\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target,
        ' \xE7\xE0\xE1\xE0\xED\xE8\xEB \xEE\xF4\xF4\xEB\xE0\xE9\xED \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target,
        ' \xF1\xED\xFF\xEB \xE7\xE0\xF2\xFB\xF7\xEA\xF3 \xF1 \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target,
        ' \xF1\xED\xFF\xEB \xE7\xE0\xF2\xFB\xF7\xEA\xF3 \xEE\xF4\xF4\xEB\xE0\xE9\xED \xF1 \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target,
        ' \xF1\xED\xFF\xEB 1 \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xE5 \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target,
        '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 ',
    }
    for _, n in ipairs(needles) do
        if n == '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 ' then
            if plain:find('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 ', 1, true)
                    and (plain:find(' \xEA\xE8\xEA\xED\xF3\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target, 1, true)
                        or plain:find(' \xEF\xEE\xF1\xE0\xE4\xE8\xEB \xE2 \xF2\xFE\xF0\xFC\xEC\xF3 ' .. target, 1, true)
                        or plain:find(' \xE7\xE0\xE1\xE0\xED\xE8\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ' .. target, 1, true)
                        or plain:find(' \xEF\xEE\xF1\xF2\xE0\xE2\xE8\xEB \xE7\xE0\xF2\xFB\xF7\xEA\xF3 \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target, 1, true)
                        or plain:find(' \xE2\xFB\xE4\xE0\xEB \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xE5 \xE8\xE3\xF0\xEE\xEA\xF3 ' .. target, 1, true)) then
                return true
            end
        elseif plain:find(n, 1, true) then
            return true
        end
    end
    if pid and pid >= 0 and p.command and p.command:match('^/tr') then
        if plain:find('/tr%s+' .. tostring(pid) .. '(%s|$)') then
            return true
        end
    end
    if pid and pid >= 0 then
        local idTag = '[' .. tostring(pid) .. ']'
        if plain:find(idTag, 1, true)
                and (plain:find('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 ', 1, true)
                    or plain:find(' \xEF\xEE\xF1\xF2\xE0\xE2\xE8\xEB \xE7\xE0\xF2\xFB\xF7\xEA\xF3 ', 1, true)
                    or plain:find(' \xEA\xE8\xEA\xED\xF3\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ', 1, true)
                    or plain:find(' \xEF\xEE\xF1\xE0\xE4\xE8\xEB \xE2 \xF2\xFE\xF0\xFC\xEC\xF3 ', 1, true)
                    or plain:find(' \xE7\xE0\xE1\xE0\xED\xE8\xEB \xE8\xE3\xF0\xEE\xEA\xE0 ', 1, true)
                    or plain:find(' \xE2\xFB\xE4\xE0\xEB \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xE5 ', 1, true)) then
            return true
        end
    end
    return false
end

-- REWRITTEN: claim after cheap filters; rollback line key on parse fail; prune bounded line map.
function adminPunishIngestChatLine(color, text)
    if not apEnabled() then return end
    if not text or text == '' then return end
    apBootstrapChatBuffer()

    local plain = apPlainText(text)
    if apIsOwnAutovydachaLog(plain) then return end

    if apState.pending and apAnotherAdminExecuted(text) then
        apClearPending('\xCA\xEE\xEC\xE0\xED\xE4\xF3 \xF3\xE6\xE5 \xE2\xFB\xEF\xEE\xEB\xED\xE8\xEB \xE4\xF0\xF3\xE3\xEE\xE9 \xE0\xE4\xEC\xE8\xED.')
        return
    end

    if not apIsAdminChatLine(color, plain) then return end
    if not apHasPunishCommand(plain) then return end

    local stableLineKey = apStableLineKey(text)
    if stableLineKey == '' then return end
    if AP_SEEN_GLOBAL.line[stableLineKey] then return end

    local admName, admId, admCommand = apParseAdminRequest(plain)
    if not admName or not admId or not admCommand then return end
    if not apClaimLineKey(stableLineKey) then return end

    local dedupKey = apRequestKey(admId, admCommand)
    if apRequestSeenRecently(dedupKey) then
        apMarkLineConsumed(stableLineKey)
        return
    end

    if type(isMyAdminReply) == 'function' and isMyAdminReply(admName, admId) then
        apMarkLineConsumed(stableLineKey)
        apMarkRequestSeen(dedupKey)
        return
    end

    if apState.pending then
        local old = apState.pending
        if old.dedupKey == dedupKey or apRequestKey(old.admId, old.command) == dedupKey then
            old.tick = apMono()
            apMarkLineConsumed(stableLineKey)
            return
        end
        apClearPending()
    end

    local parsed = apTryParse(admCommand)
    if not parsed then
        apMarkLineConsumed(stableLineKey)
        apMarkRequestSeen(dedupKey)
        return
    end

    if apBlocksTargetAdmin(admCommand) and apIsCatalogAdmin(parsed.playerName) then
        say('{EE0000}\xC2\xED\xE8\xEC\xE0\xED\xE8\xE5! \xD6\xE5\xEB\xFC \xE2 \xEA\xE0\xF2\xE0\xEB\xEE\xE3\xE5 \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xEE\xE2.')
        apMarkLineConsumed(stableLineKey)
        apMarkRequestSeen(dedupKey)
        return
    end

    apMarkLineConsumed(stableLineKey)

    parsed.admName = admName
    parsed.admId = admId
    parsed.command = admCommand
    parsed.tick = apMono()
    parsed.stableLineKey = stableLineKey
    parsed.dedupKey = dedupKey
    apSetPending(parsed)
end

-- Admin Punish On Server Message
function adminPunishOnServerMessage(color, text)
    adminPunishIngestChatLine(color, text)
end

-- CHAT RPC (/a иногда не дублируется в onServerMessage, только в onChatMessage + sampGetChatString).
-- NO-API: /a may arrive via onChatMessage without onServerMessage.
function adminPunishOnChatMessage(playerId, text)
    if not apEnabled() then return end
    if not text or text == '' then return end
    local plain = apPlainText(text)
    if apHasPunishCommand(plain) then
        adminPunishIngestChatLine(0, text)
        return
    end
    playerId = tonumber(playerId)
    if not playerId or playerId < 0 then return end
    local cmd = trim(text)
    if cmd:sub(1, 1) ~= '/' or not apCommandLooksSupported(cmd) then return end
    local nick = trim(sampGetPlayerNickname and sampGetPlayerNickname(playerId) or '')
    if nick == '' then return end
    if not apIsCatalogAdmin(nick) then return end
    adminPunishIngestChatLine(0, string.format('[A] %s[%d]: %s', nick, playerId, cmd))
end

function adminPunishHooksActive()
    return type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive()
end

-- Запасной poll только если хуки не стоят (иначе дубли и лаг от скана буфера).
-- NO-API: fallback poll via sampGetChatString when hooks inactive.
function pollAdminPunishChat()
    if not apEnabled() then return end
    if adminPunishHooksActive() then return end
    apBootstrapChatBuffer()
    if not sampGetChatString then return end
    local now = os.clock()
    if now - apPollLastAt < AP_POLL_INTERVAL_FALLBACK then return end
    apPollLastAt = now
    local maxLines = AP_POLL_LINES_FALLBACK
    if maxLines > AP_POLL_RECENT then maxLines = AP_POLL_RECENT end
    for i = 0, maxLines - 1 do
        local line = sampGetChatString(i) or ''
        if line ~= '' then
            local plain = apPlainText(line)
            if apHasPunishCommand(plain) then
                pcall(adminPunishIngestChatLine, 0, line)
            end
        end
    end
end

-- Health-check hooks автовыдачи (onServerMessage + onChatMessage).
function adminPunishEnsureServerHook()
    if not apEnabled() then return end
    apBootstrapChatBuffer()
    if type(installDeskServerMessageHook) == 'function' then
        if type(deskIsServerMsgHookActive) ~= 'function' or not deskIsServerMsgHookActive() then
            pcall(installDeskServerMessageHook)
        end
    end
    if type(installProfanityHooks) == 'function' then
        local needReinstall = not deskCache.profHooksInstalled
            or (deskCache.profChatHandler and sampev and sampev.onChatMessage ~= deskCache.profChatHandler)
        if needReinstall and os.clock() - apHookReinstallAt >= AP_HOOK_REINSTALL_SEC then
            apHookReinstallAt = os.clock()
            deskCache.profHooksInstalled = false
            pcall(installProfanityHooks)
        end
    end
end

local function apInputsBlocked()
    if deskCache.hotkeyCapture or deskCache.cheatCapture or deskCache.adminPunishBindCapture then
        return true
    end
    if apState.pending then return false end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if type(deskSampDialogActive) == 'function' and deskSampDialogActive() then return true end
    return false
end

local function apPollPendingBindKeys()
    if not apState.pending then return end
    ensureAdminPunishSettings()
    local prev = deskCache.adminPunishBindPrev
    local ck = tonumber(settings.admin_punish_confirm_key) or vkeys.VK_DELETE
    local xk = tonumber(settings.admin_punish_cancel_key) or vkeys.VK_END
    if apInputsBlocked() then
        deskBindJustPressed(ck, prev)
        deskBindJustPressed(xk, prev)
        return
    end
    if deskBindJustPressed(ck, prev) then
        adminPunishConfirm()
    elseif deskBindJustPressed(xk, prev) then
        adminPunishCancel()
    end
end

-- Наказание всегда через sendChat: очередь /sp (0.55 с) задерживает kick и проигрывает гонку админов.
local function apSendPunishChat(line)
    line = trim(tostring(line or ''))
    if line == '' then return false end
    if line:sub(1, 1) ~= '/' then line = '/' .. line end
    return sendChat(line) == true
end

local function apFinishExecuteSuccess(p)
    apSealPending(p)
    apState.pending = nil
    apState.pendingOfflineSince = nil
    apState.executing = false
end

local function apFinishExecuteFail()
    apState.executing = false
    say('{EE0000}\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC \xEA\xEE\xEC\xE0\xED\xE4\xF3.')
end

local function apBuildPunishLogEntry(p, outbound)
    if not p then return nil end
    local cmd = p.command or ''
    return {
        ts = os.time(),
        kind = apPunishKindFromCommand(cmd),
        action = p.action or '-',
        player = trim(p.snapshotNick or p.playerName or '?'),
        pid = tonumber(p.playerId) or -1,
        term = p.term or '-',
        reason = p.reason or '-',
        cmd = outbound or cmd,
        reqAdmin = p.admName or '',
        reqAdminId = tonumber(p.admId),
        src = 'auto',
    }
end

-- Журнал наказаний: только главный поток (etState.punish + imgui-таблица).
local function apExtractPunishOutgoing(message)
    message = trim(tostring(message or ''))
    if message == '' then return nil end
    local inner = message:match('^/?a%s+(/.*)$')
    if inner then
        inner = trim(inner)
        if inner ~= '' and inner:sub(1, 1) == '/' then
            return inner, 'a_request', message
        end
        return nil
    end
    local cmd = message
    if cmd:sub(1, 1) ~= '/' then cmd = '/' .. cmd end
    return cmd, 'manual', cmd
end

local function apRecordPunishLogNow(entry)
    if type(helpStatsRecordPunish) ~= 'function' then
        print('[Report Desk] punish log: helpStatsRecordPunish unavailable')
        return
    end
    entry = type(entry) == 'table' and entry or nil
    if not entry then return end
    local pCmd = select(1, apExtractPunishOutgoing(entry.cmd or ''))
    if not pCmd then
        pCmd = entry.cmd or ''
        if pCmd:sub(1, 1) ~= '/' then pCmd = '/' .. pCmd end
    end
    if not entry.kind or entry.kind == '' then
        entry.kind = apPunishKindFromCommand(pCmd)
    end
    local cmdKey = apNormalizeCommand(pCmd)
    local dedupKey = tostring(entry.pid or -1) .. '|' .. cmdKey
    local now = os.time()
    if apState.punishLogDedup.key == dedupKey and (now - (apState.punishLogDedup.at or 0)) <= 2 then
        return
    end
    apState.punishLogDedup.key = dedupKey
    apState.punishLogDedup.at = now
    pcall(helpStatsRecordPunish, entry)
end

local function apEnqueuePunishLog(entry)
    if not entry then return end
    local q = apState.punishLogQueue
    if type(q) ~= 'table' then
        q = {}
        apState.punishLogQueue = q
    end
    q[#q + 1] = entry
end

function adminPunishFlushDeferredLogs()
    local q = apState.punishLogQueue
    if type(q) ~= 'table' or #q == 0 then return end
    apState.punishLogQueue = {}
    for i = 1, #q do
        pcall(apRecordPunishLogNow, q[i])
    end
end

local function apRecordPunishLog(entry)
    apEnqueuePunishLog(entry)
    adminPunishFlushDeferredLogs()
end

local function apReleasePunishStatsHook()
    if type(deskCache) ~= 'table' then return end
    local n = (tonumber(deskCache.skipPunishStatsHook) or 0) - 1
    deskCache.skipPunishStatsHook = n > 0 and n or nil
end

local function apSendPunishOutbound(outbound)
    if type(deskCache) == 'table' then
        deskCache.skipPunishStatsHook = (tonumber(deskCache.skipPunishStatsHook) or 0) + 1
    end
    local ok, sent = pcall(function()
        return apSendPunishChat(outbound) == true
    end)
    apReleasePunishStatsHook()
    if not ok then return false end
    return sent
end

local function apExecutePending()
    if apState.executing then return end
    local p = apState.pending
    if not p then return end
    local ok, _, errMsg = apCanExecutePending(p)
    if not ok then
        if errMsg then say(errMsg) end
        return
    end
    local outbound = apOutboundCmd(p.command, p.admName)
    apState.executing = true

    local sentOk, sent = pcall(apSendPunishOutbound, outbound)
    if not sentOk or not sent then
        apFinishExecuteFail()
        return
    end

    apRecordPunishLog(apBuildPunishLogEntry(p, outbound))
    apFinishExecuteSuccess(p)
end

-- Admin Punish Confirm
function adminPunishConfirm()
    if apState.executing then return end
    apExecutePending()
end

-- Журнал «Справка»: прямые команды и запросы /a /ban … (когда нет прав на прямую выдачу).
function adminPunishNoteOutgoingMessage(message)
    if type(deskCache) == 'table' and tonumber(deskCache.skipPunishStatsHook) and deskCache.skipPunishStatsHook > 0 then
        return
    end
    if not adminPunishOutgoingLooksRelevant(message) then return end
    local punishCmd, src, fullLine = apExtractPunishOutgoing(message)
    if not punishCmd then return end
    local parsed = apParsePunishCommand(punishCmd)
    if not parsed then return end
    apRecordPunishLog({
        ts = os.time(),
        kind = apPunishKindFromCommand(punishCmd),
        action = parsed.action or '-',
        player = trim(parsed.playerName or parsed.snapshotNick or '?'),
        pid = tonumber(parsed.playerId) or -1,
        term = parsed.term or '-',
        reason = parsed.reason or '-',
        cmd = fullLine or punishCmd,
        src = src,
    })
end

-- Admin Punish On Player Quit
function adminPunishOnPlayerQuit(playerId)
    if not apEnabled() then return end
    local p = apState.pending
    if not p then return end
    local pid = clampSuspectPlayerId and clampSuspectPlayerId(p.playerId) or tonumber(p.playerId)
    if not pid or pid < 0 then return end
    if pid ~= tonumber(playerId) then return end
    apClearPending(string.format(
        '\xC8\xE3\xF0\xEE\xEA %s[%d] \xE2\xFB\xF8\xE5\xEB. \xC7\xE0\xEF\xF0\xEE\xF1 \xEE\xF2\xEC\xE5\xED\xB8\xED.',
        p.snapshotNick or p.playerName or '?', pid))
end

-- Admin Punish Cancel
function adminPunishCancel()
    apClearPending('\xC7\xE0\xEF\xF0\xEE\xF1 \xEE\xF2\xEC\xE5\xED\xB8\xED.')
end

-- WM: подтверждение/отмена pending (клавиши, которые доходят через onWindowMessage).
function tryHandleAdminPunishBindMessage(msg, wparam, lparam)
    if not apEnabled() or not apState.pending then return false end
    if deskCache.adminPunishBindCapture or deskCache.hotkeyCapture or deskCache.cheatCapture then
        return false
    end
    if apInputsBlocked() then return false end
    if type(deskBindMessageIsDown) ~= 'function' then return false end

    ensureAdminPunishSettings()
    local prev = deskCache.adminPunishBindPrev
    local ck = tonumber(settings.admin_punish_confirm_key) or 0
    local xk = tonumber(settings.admin_punish_cancel_key) or 0

    if ck > 0 and deskBindMessageIsDown(msg, wparam, lparam, ck) then
        prev[ck] = true
        adminPunishConfirm()
        if consumeWindowMessage then consumeWindowMessage(true, true, true) end
        return true
    end
    if xk > 0 and deskBindMessageIsDown(msg, wparam, lparam, xk) then
        prev[xk] = true
        adminPunishCancel()
        if consumeWindowMessage then consumeWindowMessage(true, true, true) end
        return true
    end
    return false
end

-- Admin Punish Has Pending
function adminPunishHasPending()
    return apState.pending ~= nil
end

-- Admin Punish Tick
function adminPunishTick()
    local p = apState.pending
    if not p then return end
    if apState.executing then return end

    apRefreshPendingNick(p)

    if apMono() - (p.tick or 0) > PUNISH_TIMEOUT_SEC then
        apClearPending('\xC2\xF0\xE5\xEC\xFF \xEE\xE6\xE8\xE4\xE0\xED\xE8\xFF \xE8\xF1\xF2\xE5\xEA\xEB\xEE.')
        return
    end

    local st = apLiveTargetStatus(p)
    if st and st.mode == 'online_id' and st.status == 'offline' then
        local offAt = tonumber(apState.pendingOfflineSince) or 0
        if offAt <= 0 then
            apState.pendingOfflineSince = apMono()
            return
        end
        if apMono() - offAt < AP_OFFLINE_CANCEL_SEC then
            return
        end
        apClearPending(string.format(
            '\xC8\xE3\xF0\xEE\xEA %s[%d] \xE2\xFB\xF8\xE5\xEB \xF1 \xF1\xE5\xF0\xE2\xE5\xF0\xE0. \xC7\xE0\xEF\xF0\xEE\xF1 \xEE\xF2\xEC\xE5\xED\xB8\xED.',
            st.snapshotNick or '?', st.playerId or 0))
        return
    end
    apState.pendingOfflineSince = nil
    apPollPendingBindKeys()
end

local function apBindPreviewCapturing()
    local vk = tonumber(deskCache.bindCapVk) or 0
    if vk > 0 then return vkToLabel(vk) end
    return '...'
end

-- Admin Punish Bind Capture Save
function adminPunishBindCaptureSave(vk)
    vk = deskCanonicalBindVk(tonumber(vk) or 0)
    if vk <= 0 then return false end
    if cheatBindIsModifier and cheatBindIsModifier(vk) then return false end
    ensureAdminPunishSettings()
    local field = apState.bindField or deskCache.adminPunishBindField or 'confirm'
    local peerKey = field == 'cancel' and settings.admin_punish_confirm_key or settings.admin_punish_cancel_key
    if deskBindKeysOverlap(vk, peerKey) then
        say('\xCF\xEE\xE4\xF2\xE2\xE5\xF0\xE6\xE4\xE5\xED\xE8\xE5 \xE8 \xEE\xF2\xEC\xE5\xED\xE0 \xED\xE5 \xEC\xEE\xE3\xF3\xF2 \xE1\xFB\xF2\xFC \xEE\xE4\xED\xEE\xE9 \xEA\xEB\xE0\xE2\xE8\xF8\xE5\xE9.')
        return false
    end
    if field == 'cancel' then
        settings.admin_punish_cancel_key = vk
    else
        settings.admin_punish_confirm_key = vk
    end
    markDirtySettings()
    if type(finishDeskBindCapture) == 'function' then
        finishDeskBindCapture()
    else
        finishAdminPunishBindCapture()
    end
    return true
end

-- WM/poll захват клавиш (как hotkey/cheats в настройках).
function applyAdminPunishBindCapture(msg, wparam, lparam)
    if not deskCache.adminPunishBindCapture then return false end
    if os.clock() - (tonumber(deskCache.adminPunishBindCaptureAt) or 0) < PF.HOTKEY_CAPTURE_GRACE then
        return true
    end
    wparam = tonumber(wparam) or 0
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        if wparam == vkeys.VK_ESCAPE then
            finishDeskBindCapture()
        elseif wparam == vkeys.VK_DELETE or wparam == vkeys.VK_BACK then
            ensureAdminPunishSettings()
            local field = apState.bindField or deskCache.adminPunishBindField or 'confirm'
            if field == 'cancel' then
                settings.admin_punish_cancel_key = vkeys.VK_END
            else
                settings.admin_punish_confirm_key = vkeys.VK_DELETE
            end
            markDirtySettings()
            finishDeskBindCapture()
        else
            local capKey = deskBindCaptureKeyFromKeyboard and deskBindCaptureKeyFromKeyboard(wparam) or nil
            if capKey then
                deskCache.bindCapVk = capKey
                if deskBindMouseCommitsOnDown and deskBindMouseCommitsOnDown(capKey) then
                    adminPunishBindCaptureSave(capKey)
                end
            end
        end
        return true
    end
    if msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
        local capKey = deskBindCaptureKeyFromKeyboard and deskBindCaptureKeyFromKeyboard(wparam) or nil
        if deskBindCapTrySaveOnUp then
            deskBindCapTrySaveOnUp(capKey, adminPunishBindCaptureSave, capKey)
        end
        return true
    end
    local mvk = parseMouseButtonVk and parseMouseButtonVk(msg, wparam, lparam) or nil
    if mvk then
        if deskBindMouseUiClickVk and deskBindMouseUiClickVk(mvk)
                and os.clock() < (tonumber(deskCache.bindCapIgnoreMouseUntil) or 0) then
            return true
        end
        deskCache.bindCapVk = mvk
        if deskBindMouseCommitsOnDown and deskBindMouseCommitsOnDown(mvk) then
            adminPunishBindCaptureSave(mvk)
        end
        return true
    end
    local relMv = parseMouseButtonReleaseVk and parseMouseButtonReleaseVk(msg, wparam, lparam) or nil
    if relMv then
        if deskBindMouseUiClickVk and deskBindMouseUiClickVk(relMv)
                and os.clock() < (tonumber(deskCache.bindCapIgnoreMouseUntil) or 0) then
            return true
        end
        if deskBindCapTrySaveOnUp then
            deskBindCapTrySaveOnUp(relMv, adminPunishBindCaptureSave, relMv)
        end
        return true
    end
    return true
end

-- Begin Admin Punish Bind Capture
function beginAdminPunishBindCapture(field)
    if type(cancelDeskBindCapture) == 'function' then cancelDeskBindCapture() end
    field = field == 'cancel' and 'cancel' or 'confirm'
    apState.bindField = field
    apState.bindCapture = true
    deskCache.adminPunishBindField = field
    deskCache.adminPunishBindCapture = true
    deskCache.adminPunishBindCaptureAt = os.clock()
    deskCache.bindCapVk = nil
    deskCache.bindCapPollPrev = nil
    deskCache.bindCapIgnoreMouseUntil = os.clock() + 0.35
    if type(deskBindCaptureResetPollState) == 'function' then
        deskBindCaptureResetPollState()
    end
end

-- Finish Admin Punish Bind Capture
function finishAdminPunishBindCapture()
    apState.bindCapture = false
    apState.bindField = nil
    deskCache.adminPunishBindCapture = false
    deskCache.adminPunishBindCaptureAt = nil
    deskCache.adminPunishBindField = nil
end

-- Sync Admin Punish Ui From Settings
function syncAdminPunishUiFromSettings()
    ensureAdminPunishSettings()
    uiAdminPunishEnabled[0] = settings.admin_punish_enabled == true
    uiAdminPunishSignCmd[0] = settings.admin_punish_sign_cmd ~= false
end

local function apTruncate(s, maxBytes)
    s = trim(tostring(s or ''))
    maxBytes = tonumber(maxBytes) or 48
    if #s <= maxBytes then return s end
    return s:sub(1, math.max(1, maxBytes - 2)) .. '..'
end

local function apOverlayLiveValue(st, reqNick)
    if st.mode == 'offline_nick' or st.status == 'na' then
        return '\xEF\xEE \xED\xE8\xEA\xF3', col_muted2
    end
    if st.status == 'offline' then
        return '\xED\xE5 \xED\xE0 \xF1\xE5\xF0\xE2\xE5\xF0\xE5', col_punish_label
    end
    if st.status == 'nick_changed' then
        local liveShow = st.liveNick
        if not liveShow or liveShow == '' then
            liveShow = string.format('?[%d]', st.playerId or 0)
        elseif st.playerId and st.playerId >= 0 then
            liveShow = string.format('%s[%d]', liveShow, st.playerId)
        end
        return liveShow, col_punish_label
    end
    local liveLine = st.liveNick or reqNick
    if st.playerId and st.playerId >= 0 then
        liveLine = string.format('%s[%d]', liveLine, st.playerId)
    end
    return liveLine .. ' \xB7 \xEE\xEA', col_player_nick
end

local function apHudColorU32(col)
    if type(toU32) == 'function' then return toU32(col) end
    if imgui.ColorConvertFloat4ToU32 then return imgui.ColorConvertFloat4ToU32(col) end
    return 0xFFFFFFFF
end

local function apHudActionColor(_p)
    return col_punish_label
end

local function apHudTargetLabel(reqNick, reqPid)
    reqNick = trim(tostring(reqNick or '?'))
    local pid = tonumber(reqPid)
    if pid and pid >= 0 then
        return string.format('%s [%d]', reqNick, pid)
    end
    return reqNick
end

local function apHudCmdLine(p)
    if not p or not p.command then return '' end
    local cmd = trim(tostring(p.command or ''))
    if cmd == '' then return '' end
    return apOutboundCmd(cmd, p.admName)
end

local function apHudDrawTimerStrip(frac, left)
    local timer = string.format('%.0f \xF1', left)
    timer = uiText(timer)
    local subW = imgui.CalcTextSize(timer).x
    local avail = imgui.GetContentRegionAvail().x
    if avail > subW + 2 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + avail - subW)
    end
    imgui.TextColored(col_muted2, timer)
    imgui.Dummy(imgui.ImVec2(0, 1))

    local dl = imgui.GetWindowDrawList()
    if not dl then
        imgui.Dummy(imgui.ImVec2(0, 4))
        return
    end
    local wp = imgui.GetWindowPos()
    local ws = imgui.GetWindowSize()
    local pad = 10
    local y = imgui.GetCursorScreenPos().y
    local x0 = wp.x + pad
    local x1 = wp.x + ws.x - pad
    local track = imgui.ImVec4(0.10, 0.08, 0.14, 0.55)
    dl:AddRectFilled(imgui.ImVec2(x0, y), imgui.ImVec2(x1, y + 2), apHudColorU32(track), 1)
    if frac > 0 then
        dl:AddRectFilled(
            imgui.ImVec2(x0, y), imgui.ImVec2(x0 + (x1 - x0) * frac, y + 2),
            apHudColorU32(col_accent_dim), 1)
    end
    imgui.Dummy(imgui.ImVec2(0, 6))
end

local function apVkHudShort(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return '?' end
    if vkeys then
        if vk == vkeys.VK_DELETE then return 'Del' end
        if vk == vkeys.VK_END then return 'End' end
        if vk == vkeys.VK_INSERT then return 'Ins' end
        if vk == vkeys.VK_HOME then return 'Hm' end
        if vk == vkeys.VK_PRIOR then return 'PgU' end
        if vk == vkeys.VK_NEXT then return 'PgD' end
        if vk == vkeys.VK_RETURN then return 'Ent' end
        if vk == vkeys.VK_BACK then return 'Bk' end
        if vk == vkeys.VK_SPACE then return 'Spc' end
        if vk == vkeys.VK_TAB then return 'Tab' end
        if vk == vkeys.VK_ESCAPE then return 'Esc' end
        if vk == vkeys.VK_LBUTTON then return 'LMB' end
        if vk == vkeys.VK_RBUTTON then return 'RMB' end
        if vk == vkeys.VK_MBUTTON then return 'MMB' end
        if vk == vkeys.VK_XBUTTON1 then return 'M4' end
        if vk == vkeys.VK_XBUTTON2 then return 'M5' end
        for d = 0, 9 do
            if vk == vkeys['VK_NUMPAD' .. d] then return 'N' .. d end
        end
        if vk >= vkeys.VK_F1 and vk <= vkeys.VK_F12 then
            return 'F' .. (vk - vkeys.VK_F1 + 1)
        end
    end
    local full = vkToLabel(vk)
    local digit = full:match('^NUMPAD(%d)$') or full:match('^[Nn]umpad%s*(%d)$')
    if digit then return 'N' .. digit end
    if #full <= 5 then return full end
    return full:sub(1, 5)
end

local function apHudMeasureHintLine(label, keyVk, primary)
    local lbl = uiText(tostring(label or ''))
    local key = uiText(apVkHudShort(keyVk))
    if primary then
        return imgui.CalcTextSize(lbl).x + 4 + imgui.CalcTextSize(key).x
    end
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(0.90) end
    local w = imgui.CalcTextSize(lbl).x + 4
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(0.76) end
    w = w + imgui.CalcTextSize(key).x
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(1.0) end
    return w
end

local function apHudDrawHintLine(label, keyVk, primary, enabled)
    local lbl = uiText(tostring(label or ''))
    local key = uiText(apVkHudShort(keyVk))
    enabled = enabled ~= false

    if primary then
        imgui.TextColored(enabled and col_accent or col_muted, lbl)
        imgui.SameLine(0, 4)
        if imgui.SetWindowFontScale then imgui.SetWindowFontScale(0.78) end
        local keyCol = enabled
            and imgui.ImVec4(col_accent.x, col_accent.y, col_accent.z, 0.38)
            or imgui.ImVec4(0.42, 0.40, 0.48, 0.30)
        imgui.TextColored(keyCol, key)
    else
        if imgui.SetWindowFontScale then imgui.SetWindowFontScale(0.90) end
        imgui.TextColored(imgui.ImVec4(col_muted.x, col_muted.y, col_muted.z, 0.46), lbl)
        imgui.SameLine(0, 4)
        if imgui.SetWindowFontScale then imgui.SetWindowFontScale(0.76) end
        imgui.TextColored(imgui.ImVec4(0.40, 0.38, 0.46, 0.22), key)
    end
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(1.0) end
end

local function apHudDrawBody(p, reqNick, reqPid, canExec)
    local targetCol = canExec and col_player_nick or col_punish_label
    imgui.TextColored(apHudActionColor(p), uiText(p.action or '-'))
    imgui.SameLine(0, 6)
    imgui.TextColored(targetCol, uiText(apHudTargetLabel(reqNick, reqPid)))
    imgui.SameLine(0, 6)
    imgui.TextColored(col_muted2, uiText('\xEF\xEE \xEF\xF0\xEE\xF1\xFC\xE1\xE5'))
    imgui.SameLine(0, 4)
    imgui.TextColored(col_admin_label, uiText(trim(p.admName or '?')))

    imgui.Dummy(imgui.ImVec2(0, 4))
    local cmdLine = apHudCmdLine(p)
    if cmdLine ~= '' then
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + imgui.GetContentRegionAvail().x)
        imgui.TextColored(col_muted2, uiText(apTruncate(cmdLine, 84)))
        imgui.PopTextWrapPos()
    end
end

local function apHudDrawStatus(st, reqNick, canExec, blockMsg)
    if canExec then return end
    if blockMsg and blockMsg ~= '' then
        imgui.TextColored(col_punish_label, uiText(apTruncate(blockMsg, 64)))
        return
    end
    local liveText, liveCol = apOverlayLiveValue(st, reqNick)
    if st.status == 'nick_changed' or st.status == 'offline' then
        imgui.TextColored(liveCol or col_punish_label, uiText(liveText))
    end
end

local function apHudDrawHints(canExec)
    ensureAdminPunishSettings()
    local ck = tonumber(settings.admin_punish_confirm_key) or 0
    local xk = tonumber(settings.admin_punish_cancel_key) or 0
    local lblOk = '\xCF\xF0\xE8\xED\xFF\xF2\xFC'
    local lblNo = '\xEE\xF2\xEC\xE5\xED\xE0'

    imgui.Dummy(imgui.ImVec2(0, 2))
    local w1 = apHudMeasureHintLine(lblOk, ck, true)
    local w2 = apHudMeasureHintLine(lblNo, xk, false)
    local avail = imgui.GetContentRegionAvail().x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max(0, (avail - (w1 + AP_HINT_GAP + w2)) * 0.5))

    apHudDrawHintLine(lblOk, ck, true, canExec and not apState.executing)
    imgui.SameLine(0, AP_HINT_GAP)
    apHudDrawHintLine(lblNo, xk, false, true)
    imgui.Dummy(imgui.ImVec2(0, 1))
end

local function apHudDrawActions(canExec)
    local busy = apState.executing == true
    local btnW = math.max(96, (OVERLAY_W - 28 - 8) * 0.5)
    local lblOk = uiText('\xCF\xF0\xE8\xED\xFF\xF2\xFC')
    local lblNo = uiText('\xCE\xF2\xEC\xE5\xED\xE0')
    imgui.Dummy(imgui.ImVec2(0, 2))
    if canExec and not busy then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.14, 0.26, 0.96))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.22, 0.42, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
        if imgui.Button(lblOk .. '##ap_ok', imgui.ImVec2(btnW, 26)) then
            adminPunishConfirm()
        end
        imgui.PopStyleColor(3)
        imgui.SameLine(0, 8)
    elseif busy then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.14, 0.12, 0.18, 0.72))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14, 0.12, 0.18, 0.72))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.14, 0.12, 0.18, 0.72))
        imgui.PushStyleColor(imgui.Col.Text, col_muted2)
        imgui.Button(lblOk .. '##ap_ok_busy', imgui.ImVec2(btnW, 26))
        imgui.PopStyleColor(4)
        imgui.SameLine(0, 8)
    end
    if imgui.Button(lblNo .. '##ap_no', imgui.ImVec2(btnW, 26)) and not busy then
        adminPunishCancel()
    end
    imgui.Dummy(imgui.ImVec2(0, 1))
end

-- Draw Admin Punish Tab
function drawAdminPunishTab()
    if not adminPunishUiSynced then
        syncAdminPunishUiFromSettings()
        adminPunishUiSynced = true
    end

    pushPanelStyle(col_chat_bg)
    local panelFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        panelFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##admin_punish_panel', imgui.ImVec2(-1, -1), false, panelFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))

    if adminPunishHasPending() then
        drawSettingsSubsection('\xC0\xEA\xF2\xE8\xE2\xED\xFB\xE9 \xE7\xE0\xEF\xF0\xEE\xF1')
        drawSettingsHint('\xCE\xE6\xE8\xE4\xE0\xE5\xF2\xF1\xFF \xEF\xEE\xE4\xF2\xE2\xE5\xF0\xE6\xE4\xE5\xED\xE8\xE5 \xB7 \xEF\xEB\xE0\xF8\xEA\xE0 \xE2\xED\xE8\xE7\xF3 \xEF\xEE \xF6\xE5\xED\xF2\xF0\xF3 \xFD\xEA\xF0\xE0\xED\xE0')
        imgui.Dummy(imgui.ImVec2(0, 4))
    end

    deskFormPanelBegin('##ap_main')
    drawSettingsCardHeader('\xCD\xE0\xEA\xE0\xE7\xE0\xED\xE8\xFF \xE8\xE7 /a',
        '\xD1\xEA\xF0\xE8\xEF\xF2 \xF7\xE8\xF2\xE0\xE5\xF2 \xF7\xE0\xF2 \xE0\xE4\xEC\xE8\xED\xE0 \xE8 \xEF\xF0\xE5\xE4\xEB\xE0\xE3\xE0\xE5\xF2 \xE2\xFB\xEF\xEE\xEB\xED\xE8\xF2\xFC \xED\xE0\xEA\xE0\xE7\xE0\xED\xE8\xFF \xEF\xEE \xEF\xF0\xEE\xF1\xFC\xE1\xE5.')
    if deskFormCheckboxRow('\xC2\xEA\xEB\xFE\xF7\xE8\xF2\xFC \xE0\xE2\xF2\xEE\xE2\xFB\xE4\xE0\xF7\xF3', uiAdminPunishEnabled, function(v)
        settings.admin_punish_enabled = v
        if not v then
            apClearPending()
        else
            apState.bootstrapped = false
            apBootstrapChatBuffer()
        end
        markDirtySettings()
    end, 'ap_en') then end
    if deskFormCheckboxRow('\xC4\xEE\xEF\xE8\xF1\xFB\xE2\xE0\xF2\xFC\x20\x2F\x20\x62\x79', uiAdminPunishSignCmd, function(v)
        settings.admin_punish_sign_cmd = v
        markDirtySettings()
    end, 'ap_sign') then end
    drawSettingsHint('\xAB\xEF\xF0\xE8\xF7\xE8\xED\xE0\x20\x2F\x20\x62\x79\x20\x41\x64\x6D\x69\x6E\xBB')
    deskFormPanelEnd()

    deskFormPanelBegin('##ap_keys')
    drawSettingsCardHeader('\xCA\xEB\xE0\xE2\xE8\xF8\xE8')
    local capConfirm = deskCache.adminPunishBindCapture and deskCache.adminPunishBindField == 'confirm'
    local capCancel = deskCache.adminPunishBindCapture and deskCache.adminPunishBindField == 'cancel'
    drawDeskBindRow({
        label = '\xCF\xEE\xE4\xF2\xE2\xE5\xF0\xE4\xE8\xF2\xFC',
        inline = false,
        previewText = capConfirm and apBindPreviewCapturing() or vkToLabel(settings.admin_punish_confirm_key),
        capturing = capConfirm,
        keyCapId = '##ap_confirm',
        onCapture = function() beginAdminPunishBindCapture('confirm') end,
        onClear = function()
            settings.admin_punish_confirm_key = vkeys.VK_DELETE
            ensureAdminPunishSettings()
            markDirtySettings()
        end,
    })
    drawDeskBindRow({
        label = '\xCF\xF0\xEE\xEF\xF3\xF1\xF2\xE8\xF2\xFC',
        inline = false,
        previewText = capCancel and apBindPreviewCapturing() or vkToLabel(settings.admin_punish_cancel_key),
        capturing = capCancel,
        keyCapId = '##ap_cancel',
        onCapture = function() beginAdminPunishBindCapture('cancel') end,
        onClear = function()
            settings.admin_punish_cancel_key = vkeys.VK_END
            ensureAdminPunishSettings()
            markDirtySettings()
        end,
    })
    deskFormPanelEnd()

    imgui.PopStyleVar(2)
    imgui.Dummy(imgui.ImVec2(0, 12))
    imgui.EndChild()
    popPanelStyle()
end

function drawAdminPunishSettings()
    drawAdminPunishTab()
end

-- Draw Admin Punish Overlay (компактная карточка внизу по центру)
function drawAdminPunishOverlay()
    local p = apState.pending
    if not p or not apEnabled() then return end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return end
    ensureAdminPunishSettings()

    local canExec, st, blockMsg = apCanExecutePending(p)
    st = st or {}
    local reqNick = st.snapshotNick or p.snapshotNick or p.playerName or '?'
    local reqPid = st.playerId
    if reqPid == nil then reqPid = p.playerId end

    local sw, sh = getScreenResolution()
    sw, sh = tonumber(sw) or 800, tonumber(sh) or 600
    local elapsed = apMono() - (p.tick or 0)
    local left = math.max(0, PUNISH_TIMEOUT_SEC - elapsed)
    local frac = math.max(0, math.min(1, left / PUNISH_TIMEOUT_SEC))

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoNav + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoFocusOnAppearing then
        flags = flags + imgui.WindowFlags.NoFocusOnAppearing
    end
    if imgui.WindowFlags.NoSavedSettings then
        flags = flags + imgui.WindowFlags.NoSavedSettings
    end

    imgui.SetNextWindowSizeConstraints(
        imgui.ImVec2(OVERLAY_W, 0), imgui.ImVec2(OVERLAY_W + 56, 280))
    imgui.SetNextWindowPos(
        imgui.ImVec2(sw * 0.5, sh - OVERLAY_BOTTOM_MARGIN), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))

    local theme = apTheme()
    if theme then theme.pushHudChrome(0.92) end
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 10))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(4, 2))
    if imgui.Begin('###desk_admin_punish', nil, flags) then
        if theme and theme.drawPanelFrame then theme.drawPanelFrame() end

        apHudDrawTimerStrip(frac, left)
        apHudDrawBody(p, reqNick, reqPid, canExec)
        apHudDrawStatus(st, reqNick, canExec, blockMsg)
        apHudDrawActions(canExec)
        apHudDrawHints(canExec)
        imgui.End()
    end
    imgui.PopStyleVar(2)
    if theme then theme.popHudChrome() end
end
