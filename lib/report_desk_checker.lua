--[[ Report Desk — admin/leader/friend checker (HUD + catalog) ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

rawset(_G, 'checkerState', nil)
rawset(_G, 'checkerOnline', nil)
rawset(_G, 'checkerCatalog', nil)

local CHECKER_LVL_SPECIAL_BASE = 100

local ADMIN_LEVEL_1 = 1
local ADMIN_LEVEL_2 = 2
local ADMIN_LEVEL_3 = 3
local ADMIN_LEVEL_4 = 4
local ADMIN_LEVEL_5 = 5
local ADMIN_LEVEL_6 = 6
local ADMIN_LEVEL_7 = 7

local ORG_GOV = 1
local ORG_MVD = 2
local ORG_MO = 3
local ORG_MZ = 4
local ORG_SMI = 5
local ORG_BAND = 6
local ORG_BAND_MAX = 10
local ORG_MAFIA = 11
local ORG_MAFIA_MAX = 13

local SAMP_COLOR_AUTO_PROMOTE = -65281

local CHECKER_SPECIAL_COLOR = {
    [1] = imgui.ImVec4(0.95, 0.78, 0.22, 1.0),
    [2] = imgui.ImVec4(0.82, 0.52, 0.95, 1.0),
    [3] = imgui.ImVec4(0.35, 0.82, 0.95, 1.0),
}

local CHECKER_ADMIN_COLOR = {
    [7] = imgui.ImVec4(1.0, 0.08, 0.08, 1.0),
    [6] = imgui.ImVec4(0.21, 0.73, 0.06, 1.0),
    [5] = imgui.ImVec4(0.19, 0.97, 0.48, 1.0),
    [4] = imgui.ImVec4(0.26, 0.43, 0.93, 1.0),
    [3] = imgui.ImVec4(0.65, 0.23, 0.85, 1.0),
    [2] = imgui.ImVec4(0.0, 0.75, 1.0, 1.0),
    [1] = imgui.ImVec4(0.0, 0.75, 1.0, 1.0),
}

local CHECKER_ORG_JOIN = {
    [1] = '\xEF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xEE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xE8 \'\xEF\xF0\xE0\xE2\xE8\xF2\xE5\xEB\xFC\xF1\xF2\xE2\xEE\', %s[%i].',
    [2] = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xEE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xE8 \'\xCC\xC2\xC4\', %s[%i].',
    [3] = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xEE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xE8 \'\xCC\xCE\', %s[%i].',
    [4] = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xEE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xE8 \'\xCC\xC7\', %s[%i].',
    [5] = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xEE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xE8 \'\xD1\xCC\xC8\', %s[%i].',
}

local CHECKER_HUD_W = 300
local CHECKER_ADMINS_CAPTURE_T = 5.0
local CHECKER_LEADERS_FLOW_T = 30.0
local CHECKER_ADMINS_FLOW_T = 30.0
local CHECKER_AFK_POLL_INTERVAL = 15.0
local CHECKER_REBUILD_INTERVAL = 15.0
local CHECKER_RESCAN_INTERVAL = 5.0
local CHECKER_SPAWN_REBUILD_DELAY = 1.5
local CHECKER_AUTO_ADMS_INTERVAL = 240.0
local CHECKER_AUTO_LEADERS_INTERVAL = 900.0
local CHECKER_AUTO_SYNC_INITIAL = 12.0
local CHECKER_AUTO_LEADERS_DELAY = 8.0
local CHECKER_JOIN_NOTIFY_DELAY = 10.0
local L_ADMINS_ONLINE = '\xC0\xE4\xEC\xE8\xED\xFB \xEE\xED\xEB\xE0\xE9\xED'
local L_ADMIN_WORD = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0'
local L_LEADERS = '\xCB\xE8\xE4\xE5\xF0'

-- Fresh tables every load (env __index=_G would otherwise resurrect stale globals on reload).
checkerCatalog = { admins = {}, leaders = {}, friends = {} }
checkerOnline = { admins = {}, leaders = {}, friends = {} }
checkerOnlineRev = 0
checkerState = {}
do
    local s = checkerState
    s.hudPlaced = s.hudPlaced == true
    s.hudDrag = type(s.hudDrag) == 'table' and s.hudDrag or { active = false, offX = 0, offY = 0 }
    if s.hudDrag.active == nil then s.hudDrag.active = false end
    if s.hudDrag.offX == nil then s.hudDrag.offX = 0 end
    if s.hudDrag.offY == nil then s.hudDrag.offY = 0 end
    s.hudHovered = s.hudHovered == true
    s.hudRect = type(s.hudRect) == 'table' and s.hudRect or nil
    s.lastRebuild = tonumber(s.lastRebuild) or 0
    s.lastAfkPoll = tonumber(s.lastAfkPoll) or 0
    s.uiSynced = s.uiSynced == true
    s.adminsCapture = type(s.adminsCapture) == 'table' and s.adminsCapture or nil
    s.adminsFlowUntil = tonumber(s.adminsFlowUntil) or 0
    s.leadersFlowUntil = tonumber(s.leadersFlowUntil) or 0
    s.autoAdmsAt = s.autoAdmsAt
    s.autoLeadersAt = s.autoLeadersAt
    s.wasSuspended = s.wasSuspended == true
    s.lastRescan = tonumber(s.lastRescan) or 0
    s.pendingAdminMode = s.pendingAdminMode or 'merge'
    s.spawnedAt = s.spawnedAt
    s.firstRebuildAt = s.firstRebuildAt
    s.pendingRebuild = s.pendingRebuild == true
    s.leaderShowUi = type(s.leaderShowUi) == 'table' and s.leaderShowUi or {}
    s.catalogRev = tonumber(s.catalogRev) or 0
    s.syncInFlight = s.syncInFlight == true
    s.lastOnlineCatalogRev = tonumber(s.lastOnlineCatalogRev) or -1
    s.lastOnlineRev = tonumber(s.lastOnlineRev) or -1
    s.catalogIndex = type(s.catalogIndex) == 'table' and s.catalogIndex or {}
    if type(s.catalogIndex.admins) ~= 'table' then s.catalogIndex.admins = {} end
    if type(s.catalogIndex.leaders) ~= 'table' then s.catalogIndex.leaders = {} end
    if type(s.catalogIndex.friends) ~= 'table' then s.catalogIndex.friends = {} end
    s.onlineNickIndex = type(s.onlineNickIndex) == 'table' and s.onlineNickIndex or { byNick = {}, byExact = {} }
    if type(s.onlineNickIndex.byNick) ~= 'table' then s.onlineNickIndex.byNick = {} end
    if type(s.onlineNickIndex.byExact) ~= 'table' then s.onlineNickIndex.byExact = {} end
    s.onlineIndex = type(s.onlineIndex) == 'table' and s.onlineIndex or {}
    if type(s.onlineIndex.adminsById) ~= 'table' then s.onlineIndex.adminsById = {} end
    if type(s.onlineIndex.leadersById) ~= 'table' then s.onlineIndex.leadersById = {} end
    if type(s.onlineIndex.friendsById) ~= 'table' then s.onlineIndex.friendsById = {} end
    if type(s.onlineIndex.adminsByNick) ~= 'table' then s.onlineIndex.adminsByNick = {} end
    if type(s.onlineIndex.leadersByNick) ~= 'table' then s.onlineIndex.leadersByNick = {} end
    if type(s.onlineIndex.friendsByNick) ~= 'table' then s.onlineIndex.friendsByNick = {} end
    s.joinNotifyReady = s.joinNotifyReady == true
    s.joinNotifyEnableAt = tonumber(s.joinNotifyEnableAt) or 0
    s.seenPlayerIds = type(s.seenPlayerIds) == 'table' and s.seenPlayerIds or {}
    s.hudFrameInstalled = s.hudFrameInstalled == true
end

local checkerUi = {
    hud = new.bool(true),
    showAdmins = new.bool(true),
    showLeaders = new.bool(true),
    showFriends = new.bool(true),
    notifyJoin = new.bool(true),
    notifyQuit = new.bool(true),
    notifySound = new.bool(true),
    notifyLeaderJoin = new.bool(false),
    friendNick = new.char[64](),
    leaderFilter = new.char[48](),
}

local function SafeCall(label, fn, ...)
    if type(fn) ~= 'function' then
        print('[Report Desk] checker error [' .. tostring(label) .. ']: not a function')
        return false
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        print('[Report Desk] checker error [' .. tostring(label) .. ']: ' .. tostring(err))
    end
    return ok, err
end

local function bumpOnlineRev()
    checkerOnlineRev = (tonumber(checkerOnlineRev) or 0) + 1
end

local function bumpCatalogRev()
    checkerState.catalogRev = (tonumber(checkerState.catalogRev) or 0) + 1
end

local function ensureCheckerCatalog()
    if type(checkerCatalog) ~= 'table' then checkerCatalog = {} end
    if type(checkerCatalog.admins) ~= 'table' then checkerCatalog.admins = {} end
    if type(checkerCatalog.leaders) ~= 'table' then checkerCatalog.leaders = {} end
    if type(checkerCatalog.friends) ~= 'table' then checkerCatalog.friends = {} end
end

local Catalog = {}

function Catalog.rebuildIndex()
    ensureCheckerCatalog()
    local idx = checkerState.catalogIndex
    idx.admins = {}
    idx.leaders = {}
    idx.friends = {}
    idx.adminsByNick = idx.admins
    idx.leadersByNick = idx.leaders
    idx.friendsByNick = idx.friends
    for _, e in ipairs(checkerCatalog.admins) do
        local key = nickKey(e and e.nick)
        if key ~= '' then idx.admins[key] = e end
    end
    for _, e in ipairs(checkerCatalog.leaders) do
        local key = nickKey(e and e.nick)
        if key ~= '' then idx.leaders[key] = e end
    end
    for _, e in ipairs(checkerCatalog.friends) do
        local key = nickKey(e and e.nick)
        if key ~= '' then idx.friends[key] = e end
    end
end

function Catalog.getAdmin(nick)
    ensureCheckerCatalog()
    local key = nickKey(nick)
    if key == '' then return nil end
    local idx = checkerState.catalogIndex
    if type(idx.admins) ~= 'table' then Catalog.rebuildIndex() end
    return idx.admins[key]
end

function Catalog.getLeader(nick)
    ensureCheckerCatalog()
    local key = nickKey(nick)
    if key == '' then return nil end
    local idx = checkerState.catalogIndex
    if type(idx.leaders) ~= 'table' then Catalog.rebuildIndex() end
    return idx.leaders[key]
end

function Catalog.getFriend(nick)
    ensureCheckerCatalog()
    local key = nickKey(nick)
    if key == '' then return nil end
    local idx = checkerState.catalogIndex
    if type(idx.friends) ~= 'table' then Catalog.rebuildIndex() end
    return idx.friends[key]
end

local function rebuildCheckerCatalogIndex()
    Catalog.rebuildIndex()
end

local function ensureCheckerSettings()
    if settings.checker_hud == nil then settings.checker_hud = true end
    if settings.checker_show_admins == nil then settings.checker_show_admins = true end
    if settings.checker_show_leaders == nil then settings.checker_show_leaders = false end
    if settings.checker_show_friends == nil then settings.checker_show_friends = true end
    if settings.checker_notify_join == nil then settings.checker_notify_join = true end
    if settings.checker_notify_quit == nil then settings.checker_notify_quit = true end
    if settings.checker_notify_sound == nil then settings.checker_notify_sound = true end
    if settings.checker_notify_leader_join == nil then settings.checker_notify_leader_join = false end
    if settings.checker_notify_leader_quit == nil then settings.checker_notify_leader_quit = false end
    if settings.checker_notify_friend_join == nil then settings.checker_notify_friend_join = settings.checker_notify_join end
    if settings.checker_auto_promote == nil then
        settings.checker_auto_promote = settings.checker_auto_admin ~= false
    end
    if settings.checker_auto_sync == nil then settings.checker_auto_sync = true end
    if tonumber(settings.checker_hud_x) == nil then settings.checker_hud_x = 8 end
    if tonumber(settings.checker_hud_y) == nil then settings.checker_hud_y = 8 end
    if tonumber(settings.checker_hud_h) == nil then settings.checker_hud_h = 160 end
    settings.checker_hud_persist = true
    if type(settings.checker_leader_hidden) ~= 'table' then settings.checker_leader_hidden = {} end
end

local function checkerLeaderHiddenKey(nick)
    return nickKey(nick)
end

local function checkerIsLeaderNickHidden(nick)
    local key = checkerLeaderHiddenKey(nick)
    if key == '' then return false end
    ensureCheckerSettings()
    return settings.checker_leader_hidden[key] == true
end

local function checkerSetLeaderNickHidden(nick, hidden)
    local key = checkerLeaderHiddenKey(nick)
    if key == '' then return end
    ensureCheckerSettings()
    if hidden then
        settings.checker_leader_hidden[key] = true
    else
        settings.checker_leader_hidden[key] = nil
    end
end

local function syncCheckerUiFromSettings()
    ensureCheckerSettings()
    if checkerUi.hud then checkerUi.hud[0] = settings.checker_hud ~= false end
    if checkerUi.showAdmins then checkerUi.showAdmins[0] = settings.checker_show_admins ~= false end
    if checkerUi.showLeaders then checkerUi.showLeaders[0] = settings.checker_show_leaders ~= false end
    if checkerUi.showFriends then checkerUi.showFriends[0] = settings.checker_show_friends ~= false end
    if checkerUi.notifyJoin then checkerUi.notifyJoin[0] = settings.checker_notify_join ~= false end
    if checkerUi.notifyQuit then checkerUi.notifyQuit[0] = settings.checker_notify_quit ~= false end
    if checkerUi.notifySound then checkerUi.notifySound[0] = settings.checker_notify_sound ~= false end
    if checkerUi.notifyLeaderJoin then checkerUi.notifyLeaderJoin[0] = settings.checker_notify_leader_join == true end
    settings.checker_hud_persist = true
    checkerState.uiSynced = true
end

local function checkerSampColorToImVec4(color)
    color = tonumber(color) or 0
    if color < 0 then color = bit.band(color, 0xFFFFFFFF) end
    if color == 0 then return nil end
    local bb = bit.band(color, 0xFF)
    local gg = bit.band(bit.rshift(color, 8), 0xFF)
    local rr = bit.band(bit.rshift(color, 16), 0xFF)
    local aa = bit.band(bit.rshift(color, 24), 0xFF)
    if aa == 0 then aa = 255 end
    if rr == 34 and gg == 34 and bb == 34 then
        rr, gg, bb = 110, 110, 110
    elseif rr == 0 and gg == 0 and bb == 255 then
        rr, gg, bb = 30, 144, 255
    end
    return imgui.ImVec4(rr / 255, gg / 255, bb / 255, aa / 255)
end

local checkerIsSpawned
local checkerPlayerConnectedSafe
local checkerSafeNick
local checkerLookupOnlineId
local checkerPlayerAfk

local function checkerLog(msg)
    if settings and settings.debug == true then
        print('[Report Desk] checker: ' .. tostring(msg))
    end
end

local function checkerCopyOnlineEntry(e)
    if type(e) ~= 'table' then return nil end
    return {
        id = e.id,
        nick = e.nick,
        level = e.level,
        org = e.org,
        org_name = e.org_name,
        role = e.role,
        afk = e.afk,
    }
end

local function checkerDedupeOnlineById(list)
    local out, seen = {}, {}
    for _, e in ipairs(list or {}) do
        local id = tonumber(e and e.id)
        if id and not seen[id] then
            seen[id] = true
            out[#out + 1] = e
        end
    end
    return out
end

local function checkerCopyOnlineList(list)
    local out, seen = {}, {}
    for _, e in ipairs(list or {}) do
        local c = checkerCopyOnlineEntry(e)
        local id = c and tonumber(c.id)
        if c and id and not seen[id] then
            seen[id] = true
            out[#out + 1] = c
        end
    end
    return out
end

function checkerPublishHudState()
    local snap = {
        admins = checkerCopyOnlineList(checkerOnline.admins),
        leaders = checkerCopyOnlineList(checkerOnline.leaders),
        friends = checkerCopyOnlineList(checkerOnline.friends),
        rev = checkerOnlineRev,
    }
    if type(deskCache) == 'table' then deskCache.checkerHud = snap end
    rawset(_G, '__desk_checkerHud', snap)
end

local function checkerHudLists()
    local h = rawget(_G, '__desk_checkerHud')
    if type(h) ~= 'table' then
        h = type(deskCache) == 'table' and deskCache.checkerHud
    end
    if type(h) == 'table' and type(h.admins) == 'table' then
        return h.admins, h.leaders or {}, h.friends or {}
    end
    return checkerOnline.admins, checkerOnline.leaders, checkerOnline.friends
end

local function checkerMarkPlayersSeenFromOnline()
    if type(checkerState.seenPlayerIds) ~= 'table' then
        checkerState.seenPlayerIds = {}
    end
    for _, list in ipairs({ checkerOnline.admins, checkerOnline.leaders, checkerOnline.friends }) do
        if type(list) == 'table' then
            for _, e in ipairs(list) do
                if e and e.id then checkerState.seenPlayerIds[e.id] = true end
            end
        end
    end
end

local function checkerResetJoinNotifyWarmup()
    checkerState.joinNotifyReady = false
    checkerState.joinNotifyEnableAt = os.clock() + CHECKER_JOIN_NOTIFY_DELAY
    checkerState.seenPlayerIds = {}
end

local function checkerTryEnableJoinNotify()
    if checkerState.joinNotifyReady then return end
    if os.clock() < (checkerState.joinNotifyEnableAt or 0) then return end
    checkerMarkPlayersSeenFromOnline()
    checkerState.joinNotifyReady = true
end

local function checkerShouldNotifyJoin(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    if not checkerState.joinNotifyReady then return false end
    if type(checkerState.seenPlayerIds) ~= 'table' then checkerState.seenPlayerIds = {} end
    if checkerState.seenPlayerIds[playerId] == true then return false end
    if OnlineIndex.hasId(playerId) then return false end
    return true
end

local function checkerMarkPlayerSeen(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end
    if type(checkerState.seenPlayerIds) ~= 'table' then checkerState.seenPlayerIds = {} end
    checkerState.seenPlayerIds[playerId] = true
end

local function checkerNotifyJoinEnabled(role)
    role = role or ''
    if role == 'leader' then
        return settings.checker_notify_leader_join == true
    end
    if role == 'friend' then
        return settings.checker_notify_friend_join ~= false
    end
    return settings.checker_notify_join ~= false
end

local function checkerNotifyQuitEnabled(role)
    role = role or ''
    if role == 'leader' then
        return settings.checker_notify_leader_quit == true
    end
    return settings.checker_notify_quit ~= false
end

local function checkerSampConnected()
    if type(sampGetGamestate) ~= 'function' then return true end
    local ok, gs = SafeCall('sampGetGamestate', sampGetGamestate)
    return ok and gs == 3
end

checkerIsSpawned = function()
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return false end
    if type(sampIsLocalPlayerSpawned) ~= 'function' then return checkerSampConnected() end
    local ok, spawned = SafeCall('sampIsLocalPlayerSpawned', sampIsLocalPlayerSpawned)
    if ok and spawned == true then return true end
    return checkerSampConnected()
end

local function checkerSampReady()
    return checkerIsSpawned()
end

checkerPlayerConnectedSafe = function(id)
    id = tonumber(id)
    if not id or id < 0 then return false end
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return false end
    if type(sampIsPlayerConnected) ~= 'function' then return false end
    local ok, connected = SafeCall('sampIsPlayerConnected', sampIsPlayerConnected, id)
    return ok and connected == true
end

checkerSafeNick = function(playerId, fallback)
    fallback = fallback or ''
    playerId = tonumber(playerId)
    if not playerId or not checkerSampReady() then return fallback end
    if type(sampGetPlayerNickname) ~= 'function' then return fallback end
    local ok, nk = SafeCall('sampGetPlayerNickname', sampGetPlayerNickname, playerId)
    if ok and nk and nk ~= '' then return nk end
    return fallback
end

local function checkerMaxPlayerId()
    local maxId = tonumber(MAX_PLAYER_ID) or 1000
    if type(sampGetMaxPlayerId) == 'function' then
        local ok, m = SafeCall('sampGetMaxPlayerId', sampGetMaxPlayerId, false)
        if ok and m and m >= 0 then return m end
        ok, m = SafeCall('sampGetMaxPlayerId', sampGetMaxPlayerId)
        if ok and m and m >= 0 then return m end
    end
    return maxId
end

local function checkerBuildNickIndex()
    if type(refreshPlayerNickCache) == 'function' then
        SafeCall('refreshPlayerNickCache', refreshPlayerNickCache, true)
    end
    local byNick, byExact = {}, {}
    if type(playerNickToId) == 'table' then
        for key, id in pairs(playerNickToId) do
            if checkerPlayerConnectedSafe(id) then
                byNick[key] = id
            end
        end
    end
    if checkerSampReady() then
        local maxId = checkerMaxPlayerId()
        for id = 0, maxId do
            if checkerPlayerConnectedSafe(id) then
                local nick = checkerSafeNick(id, '')
                if nick ~= '' then
                    byExact[nick] = id
                    local key = nickKey(nick)
                    if key ~= '' then byNick[key] = id end
                end
            end
        end
    end
    checkerState.onlineNickIndex = { byNick = byNick, byExact = byExact }
    return byNick, byExact
end

local function checkerCountNickIndex(byNick)
    local n = 0
    if type(byNick) == 'table' then
        for _ in pairs(byNick) do n = n + 1 end
    end
    return n
end

checkerLookupOnlineId = function(nick)
    if not nick or nick == '' then return nil end
    if type(findPlayerIdByNick) == 'function' then
        local id = findPlayerIdByNick(nick)
        if id and checkerPlayerConnectedSafe(id) then return id end
    end
    local idx = checkerState.onlineNickIndex
    if type(idx) == 'table' and type(idx.byNick) == 'table' then
        local id = idx.byNick[nickKey(nick)]
        if id and checkerPlayerConnectedSafe(id) then return id end
        if type(idx.byExact) == 'table' then
            id = idx.byExact[nick]
            if id and checkerPlayerConnectedSafe(id) then return id end
        end
    end
    return nil
end

checkerPlayerAfk = function(id)
    id = tonumber(id)
    if not id or not checkerPlayerConnectedSafe(id) then return false end
    if type(sampIsPlayerPaused) ~= 'function' then return false end
    local ok, paused = SafeCall('sampIsPlayerPaused', sampIsPlayerPaused, id)
    return ok and paused == true
end

local function checkerIsPauseMenuOpen()
    return isPauseMenuActive and isPauseMenuActive()
end

local function checkerIsSuspended()
    if checkerIsPauseMenuOpen() then return true end
    if isGamePaused and isGamePaused() then return true end
    return false
end

local function findCatalogAdmin(nick)
    return Catalog.getAdmin(nick)
end

local function findCatalogLeader(nick)
    return Catalog.getLeader(nick)
end

local function findCatalogFriend(nick)
    return Catalog.getFriend(nick)
end

local function checkerNormalizeNick(nick)
    nick = trim(stripTags(nick or ''))
    if nick == '' then return nil end
    local parsed = nick:match('^([%w][%w_]*)%[%d+%]')
    if parsed then return parsed end
    parsed = nick:match('^([%w][%w_]*)')
    return parsed or nick
end

local function checkerLeaderIsHidden(entry)
    if type(entry) ~= 'table' then return false end
    if checkerIsLeaderNickHidden(entry.nick) then return true end
    return entry.hidden == true
end

local function checkerLeaderShowRef(nick)
    local key = checkerLeaderHiddenKey(nick)
    if key == '' or not new then return nil end
    local ref = checkerState.leaderShowUi[key]
    if not ref then
        local e = findCatalogLeader(nick)
        ref = new.bool(not checkerLeaderIsHidden(e))
        checkerState.leaderShowUi[key] = ref
    end
    return ref
end

local function checkerSetLeaderHidden(nick, hidden)
    local e = findCatalogLeader(nick)
    if not e then return false end
    checkerSetLeaderNickHidden(nick, hidden)
    if hidden then
        e.hidden = true
    else
        e.hidden = nil
    end
    local ref = checkerState.leaderShowUi[checkerLeaderHiddenKey(nick)]
    if ref then ref[0] = not hidden end
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    if type(flushDirtyConfigNow) == 'function' then
        SafeCall('flushDirtyConfigNow', flushDirtyConfigNow)
    end
    return true
end

function checkerAddFriend(nick)
    nick = checkerNormalizeNick(nick)
    if not nick or findCatalogFriend(nick) then return false end
    ensureCheckerCatalog()
    checkerCatalog.friends[#checkerCatalog.friends + 1] = { nick = nick }
    table.sort(checkerCatalog.friends, function(a, b) return (a.nick or '') < (b.nick or '') end)
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    return true
end

function checkerRemoveFriend(nick)
    nick = checkerNormalizeNick(nick)
    if not nick then return false end
    ensureCheckerCatalog()
    local key = nickKey(nick)
    local removed = false
    for i = #checkerCatalog.friends, 1, -1 do
        if nickKey(checkerCatalog.friends[i].nick) == key then
            table.remove(checkerCatalog.friends, i)
            removed = true
        end
    end
    if not removed then return false end
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    return true
end

local function checkerLeaderDisplayRole(entry)
    local role = trim(entry.role or '')
    if role ~= '' then
        role = role:gsub('^%[%d+%]%s*', '')
        role = role:gsub('^LV%s*•%s*', ''):gsub('^LS%s*|%s*', ''):gsub('^SF%s*|%s*', '')
        return role
    end
    return trim(entry.org_name or '')
end

local function checkerLeaderGroupKey(entry)
    local org = trim(entry.org_name or ''):lower()
    if org:find('президент', 1, true) or org:find('администрация президента', 1, true) then
        return 1, 'Правительство'
    end
    if org:find('министер', 1, true) or org:find('федеральн', 1, true) or org:find('фбр', 1, true)
            or org:find('оборон', 1, true) or org:find('здравоохран', 1, true)
            or org:find('внутренн', 1, true) or org:find('связи', 1, true)
            or org:find('коммуникац', 1, true) then
        return 1, 'Правительство'
    end
    if (org:find('los', 1, true) or org:find('лос', 1, true) or org:find('сантос', 1, true))
            and not org:find('ventur', 1, true) and not org:find('вентур', 1, true) then
        return 2, 'Los Santos'
    end
    if org:find('ventur', 1, true) or org:find('вентур', 1, true) or org:find(' las', 1, true) then
        return 3, 'Las Venturas'
    end
    if org:find('fierro', 1, true) or org:find('фиерро', 1, true) or org:find('san%-f', 1, true)
            or org:find('сан%-ф', 1, true) then
        return 4, 'San Fierro'
    end
    if org:find('воен', 1, true) or org:find('флот', 1, true) or org:find('ввс', 1, true)
            or org:find('сухопут', 1, true) or org:find('полици', 1, true) then
        return 5, 'Силовые структуры'
    end
    if org:find('клиник', 1, true) or org:find('nova mac', 1, true) or org:find('мгмц', 1, true)
            or org:find('кпх', 1, true) then
        return 6, 'Медицина'
    end
    if org:find('радио', 1, true) or org:find('телевиз', 1, true) or org:find('сми', 1, true) then
        return 7, 'СМИ'
    end
    if org:find('mafia', 1, true) or org:find('мафия', 1, true) or org:find('grove', 1, true)
            or org:find('ballas', 1, true) or org:find('aztecas', 1, true) or org:find('rifa', 1, true)
            or org:find('yakuza', 1, true) or org:find('cosa', 1, true) or org:find('nostra', 1, true) then
        return 8, 'Криминал'
    end
    local orgName = trim(entry.org_name or '')
    if orgName == '' then orgName = 'Прочее' end
    return 90, orgName
end

local function checkerBuildLeaderGroups(list, onlyOnline)
    local groups, order = {}, {}
    for _, e in ipairs(list or {}) do
        if not onlyOnline or checkerPlayerConnectedSafe(e.id) then
            local sortKey, title = checkerLeaderGroupKey(e)
            local gk = tostring(sortKey) .. '|' .. title
            if not groups[gk] then
                groups[gk] = { title = title, sortKey = sortKey, entries = {} }
                order[#order + 1] = gk
            end
            groups[gk].entries[#groups[gk].entries + 1] = e
        end
    end
    table.sort(order, function(a, b)
        local ga, gb = groups[a], groups[b]
        if ga.sortKey ~= gb.sortKey then return ga.sortKey < gb.sortKey end
        return ga.title < gb.title
    end)
    for _, gk in ipairs(order) do
        table.sort(groups[gk].entries, function(a, b) return (a.nick or '') < (b.nick or '') end)
    end
    return order, groups
end

local function checkerLeaderSubline(entry)
    local org = trim(entry.org_name or '')
    local role = trim(entry.role or '')
    if org ~= '' and role ~= '' then return org .. '  ·  ' .. role end
    if org ~= '' then return org end
    if role ~= '' then return role end
    return ''
end

local function catalogHasAny()
    ensureCheckerCatalog()
    return #checkerCatalog.admins + #checkerCatalog.leaders + #checkerCatalog.friends > 0
end

local function checkerAdminSortKey(level)
    level = math.floor(tonumber(level) or 0)
    if level >= CHECKER_LVL_SPECIAL_BASE then
        return level - CHECKER_LVL_SPECIAL_BASE
    end
    return level + 100
end

local function checkerIsSpecialLevel(level)
    level = math.floor(tonumber(level) or 0)
    return level >= CHECKER_LVL_SPECIAL_BASE
end

local function checkerSpecialLevelNum(level)
    level = math.floor(tonumber(level) or 0)
    if level < CHECKER_LVL_SPECIAL_BASE then return 0 end
    return level - CHECKER_LVL_SPECIAL_BASE
end

local function checkerAdminColorHex(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsSpecialLevel(level) then
        local sn = checkerSpecialLevelNum(level)
        if sn == 1 then return 'F2C738' end
        if sn == 2 then return 'D085F2' end
        if sn == 3 then return '59D1F2' end
        return 'E8E8E8'
    end
    local map = {
        [7] = 'FF1414', [6] = '36BA0F', [5] = '30F87A', [4] = '426EED',
        [3] = 'A63BD9', [2] = '00BFFF', [1] = '00BFFF',
    }
    return map[level] or 'E8E8E8'
end

local function checkerAdminColor(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsSpecialLevel(level) then
        return CHECKER_SPECIAL_COLOR[checkerSpecialLevelNum(level)] or col_accent
    end
    return CHECKER_ADMIN_COLOR[level] or col_muted
end

local function checkerFormatNickColored(nick, level)
    nick = nick or ''
    return string.format('{%s}%s{E8E8E8}', checkerAdminColorHex(level), nick)
end

local Parser = {}

function Parser.parseAdminLevel(lvlStr)
    lvlStr = trim(lvlStr or '')
    if lvlStr == '' then return nil end
    local sn = lvlStr:match('^[Ss](%d+)$')
    if sn then
        sn = math.floor(tonumber(sn) or 0)
        if sn >= 1 and sn <= 9 then
            return CHECKER_LVL_SPECIAL_BASE + sn
        end
        return nil
    end
    if lvlStr:upper() == 'S' then
        return CHECKER_LVL_SPECIAL_BASE + 1
    end
    local n = lvlStr:match('^(%d+)$')
    if n then return math.floor(tonumber(n)) end
    return nil
end

local function checkerParseAdminLevel(lvlStr)
    return Parser.parseAdminLevel(lvlStr)
end

local function checkerFormatAdminLevelDisplay(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsSpecialLevel(level) then
        return 'S' .. tostring(checkerSpecialLevelNum(level))
    end
    if level > 0 then
        return string.format('lvl %i', level)
    end
    return ''
end

local function checkerSplitAdminLists(list)
    local regular, special = {}, {}
    for _, e in ipairs(list or {}) do
        if checkerIsSpecialLevel(e.level) then
            special[#special + 1] = e
        else
            regular[#regular + 1] = e
        end
    end
    table.sort(regular, function(a, b)
        local ka = math.floor(tonumber(a.level) or 0)
        local kb = math.floor(tonumber(b.level) or 0)
        if ka ~= kb then return ka > kb end
        return (a.nick or '') < (b.nick or '')
    end)
    table.sort(special, function(a, b)
        local ka = checkerSpecialLevelNum(a.level)
        local kb = checkerSpecialLevelNum(b.level)
        if ka ~= kb then return ka > kb end
        return (a.nick or '') < (b.nick or '')
    end)
    return regular, special
end

function Parser.parseAdminLine(plain)
    plain = trim(stripTags(plain or ''))
    if plain == '' then return nil end
    local nick, pid, lvlStr = plain:match('^([%w][%w_]*)%[(%d+)%]%s*%(([Ss]?%d+)%s*lvl%)')
    if not nick then
        nick, pid, lvlStr = plain:match('^([%w][%w_]*)%[(%d+)%]%s*%(([Ss]?%d*)%s*lvl%)')
    end
    if not nick then
        nick, lvlStr = plain:match('^([%w][%w_]*)%s*%(([Ss]?%d+)%s*lvl%)')
    end
    if not nick then
        nick, lvlStr = plain:match('^([%w][%w_]*)%s*%(([Ss]?%d*)%s*lvl%)')
    end
    if not nick then return nil end
    local level = Parser.parseAdminLevel(lvlStr)
    if not level then return nil end
    return nick, level, tonumber(pid)
end

function Parser.parseAdminHeader(plain)
    plain = trim(stripTags(plain or ''))
    if plain == '' then return nil end
    if plain:find(L_ADMINS_ONLINE, 1, true) then return 'merge' end
    if plain:find(L_ADMIN_WORD, 1, true) and not plain:find('\xEE\xED\xEB\xE0\xE9\xED', 1, true) then
        return 'replace'
    end
    return nil
end

function Parser.parseJoinNotification(plain)
    plain = trim(stripTags(plain or ''))
    if plain == '' then return nil end
    local nick, pid = plain:match('^([%w][%w_]*)%[(%d+)%]')
    if nick and pid then return nick, tonumber(pid) end
    return nil
end

function Parser.parseQuitNotification(plain)
    return Parser.parseJoinNotification(plain)
end

function Parser.parseLeaderLine(plain)
    plain = trim(stripTags(plain or ''))
    if plain == '' then return nil end
    local nick, org = plain:match('^([%w][%w_]*)%s+(%d+)')
    if nick and org then return nick, math.floor(tonumber(org) or 0) end
    return nil
end

local function checkerLeadersSplitCols(line)
    local cols = {}
    for col in (line .. '\t'):gmatch('([^\t]*)\t') do
        cols[#cols + 1] = trim(col)
    end
    return cols
end

local function checkerIsLeadersHeaderRow(cols)
    local c1 = cols[1] or ''
    return c1:find('\xC8\xEC\xFF', 1, true) ~= nil
        or c1:find('\xCE\xF0\xE3\xE0\xED', 1, true) ~= nil
end

local function checkerParseLeadersDialog(text, style)
    local headers, rows = {}, {}
    local plain = stripTags(text or ''):gsub('\r', '')
    local lines = {}
    for line in plain:gmatch('[^\n]+') do
        line = trim(line)
        if line ~= '' then lines[#lines + 1] = line end
    end
    if #lines == 0 then return headers, rows end
    local startRow = 1
    local firstCols = checkerLeadersSplitCols(lines[1])
    if style == 5 or checkerIsLeadersHeaderRow(firstCols) then
        headers = firstCols
        startRow = 2
    end
    for i = startRow, #lines do
        local cols = checkerLeadersSplitCols(lines[i])
        if #cols >= 2 and not checkerIsLeadersHeaderRow(cols) then
            rows[#rows + 1] = {
                name = cols[1] or '',
                org = cols[2] or '',
                role = cols[3] or '',
                status = cols[4] or '',
            }
        end
    end
    return headers, rows
end

local function checkerIsLeadersDialog(title)
    local tit = stripTags(title or '')
    if tit:find(L_LEADERS, 1, true) then return true end
    if tit:find('\xEB\xE8\xE4\xE5\xF0', 1, true) then return true end
    return false
end

local function checkerIsAdminsDialog(title)
    local tit = stripTags(title or '')
    if tit:find(L_ADMINS_ONLINE, 1, true) then return true end
    if tit:find(L_ADMIN_WORD, 1, true) and not tit:find('\xEE\xED\xEB\xE0\xE9\xED', 1, true) then
        return true
    end
    if tit:find('\xC0\xE4\xEC\xE8\xED', 1, true) and not tit:find('\xEE\xED\xEB\xE0\xE9\xED', 1, true) then
        return true
    end
    return false
end

local function checkerIsAdminsHeaderRow(cols)
    local c1 = trim(cols[1] or '')
    return c1:find(L_ADMIN_WORD, 1, true) ~= nil
        or c1:find('\xC8\xEC\xFF', 1, true) ~= nil
        or c1:find('\xD3\xF0\xEE\xE2', 1, true) ~= nil
        or c1:find('\xD1\xF2\xE0\xF2', 1, true) ~= nil
end

local function checkerParseAdminsDialogLine(line)
    line = trim(stripTags(line or ''))
    if line == '' then return nil end
    local nick, lvlStr = line:match('^([%w][%w_]*)%[%d+%]%s*%(([Ss]?%d*)%s*lvl%)')
    if not nick then
        nick, lvlStr = line:match('^([%w][%w_]*)%s*%(([Ss]?%d*)%s*lvl%)')
    end
    if nick then
        local level = checkerParseAdminLevel(lvlStr)
        if level then return nick, level end
    end
    local cols = checkerLeadersSplitCols(line)
    if #cols >= 1 then
        nick = cols[1]:match('^([%w][%w_]*)')
        if nick then
            for i = 2, #cols do
                local cell = trim(cols[i] or '')
                local level = checkerParseAdminLevel(cell)
                    or checkerParseAdminLevel(cell:match('([Ss]?%d+)%s*lvl'))
                    or checkerParseAdminLevel(cell:match('([Ss]?%d+)'))
                if level then return nick, level end
            end
        end
    end
    return nil
end

local function checkerParseAdminsDialog(text, style)
    local list, seen = {}, {}
    local plain = stripTags(text or ''):gsub('\r', '')
    local lines = {}
    for line in plain:gmatch('[^\n]+') do
        line = trim(line)
        if line ~= '' then lines[#lines + 1] = line end
    end
    if #lines == 0 then return list end
    local startRow = 1
    local firstCols = checkerLeadersSplitCols(lines[1])
    if style == 5 or checkerIsAdminsHeaderRow(firstCols) then
        startRow = 2
    end
    for i = startRow, #lines do
        local cols = checkerLeadersSplitCols(lines[i])
        if not checkerIsAdminsHeaderRow(cols) then
            local nick, level = checkerParseAdminsDialogLine(lines[i])
            if nick and level then
                local key = nickKey(nick)
                if not seen[key] then
                    seen[key] = true
                    list[#list + 1] = { nick = nick, level = level }
                end
            end
        end
    end
    return list
end

local function checkerApplyAdminsDialogSync(list)
    if not list or #list == 0 then return false end
    ensureCheckerCatalog()
    checkerSortCatalogAdmins(list)
    checkerCatalog.admins = list
    checkerState.adminsCapture = nil
    checkerState.syncInFlight = false
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    print(string.format('[Report Desk] checker: dialog sync %d admins', #list))
    return true
end

local function checkerApplyLeadersSync(rows)
    if not rows or #rows == 0 then return false end
    ensureCheckerCatalog()
    local prevByNick = {}
    for _, e in ipairs(checkerCatalog.leaders) do
        local pk = checkerLeaderHiddenKey(e.nick)
        if pk ~= '' then prevByNick[pk] = e end
    end
    local list = {}
    for _, r in ipairs(rows) do
        local nick = trim(r.name or '')
        if nick ~= '' then
            local pk = checkerLeaderHiddenKey(nick)
            local prev = pk ~= '' and prevByNick[pk] or nil
            local orgName = trim(r.org or '')
            local role = trim(r.role or '')
            local entry = {
                nick = nick,
                org = prev and tonumber(prev.org) or 0,
                org_name = orgName ~= '' and orgName or trim(prev and prev.org_name or ''),
                role = role ~= '' and role or trim(prev and prev.role or ''),
            }
            if checkerIsLeaderNickHidden(nick) or (prev and prev.hidden == true) then
                entry.hidden = true
            end
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b) return (a.nick or '') < (b.nick or '') end)
    checkerCatalog.leaders = list
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    print(string.format('[Report Desk] checker: dialog sync %d leaders', #list))
    return true
end

local function checkerResolveCloseButton(button1, button2)
    local b1 = trim(stripTags(button1 or ''))
    local b2 = trim(stripTags(button2 or ''))
    local closeWord = '\xC7\xE0\xEA\xF0\xFB\xF2\xFC'
    if b2:find(closeWord, 1, true) or b2:lower():find('close', 1, true) then return 0 end
    if b1:find(closeWord, 1, true) or b1:lower():find('close', 1, true) then return 1 end
    if b2 ~= '' then return 0 end
    if b1 ~= '' then return 1 end
    return 0
end

local function checkerBlockDialog(dialogId, button1, button2)
    local btn = checkerResolveCloseButton(button1, button2)
    if type(sampSendDialogResponse) == 'function' and dialogId then
        pcall(sampSendDialogResponse, dialogId, btn, 0, '')
    end
    return true
end

function checkerOnShowDialog(dialogId, style, title, button1, button2, text)
    if style ~= 4 and style ~= 5 then return false end
    local now = os.clock()
    local adminsFlow = (checkerState.adminsFlowUntil or 0) > now
    local leadersFlow = (checkerState.leadersFlowUntil or 0) > now

    if adminsFlow and checkerIsAdminsDialog(title) then
        local list = checkerParseAdminsDialog(text, style)
        if #list > 0 then
            checkerApplyAdminsDialogSync(list)
        end
        checkerState.adminsFlowUntil = 0
        return checkerBlockDialog(dialogId, button1, button2)
    end

    if leadersFlow and checkerIsLeadersDialog(title) then
        local _, rows = checkerParseLeadersDialog(text, style)
        if #rows > 0 then
            checkerApplyLeadersSync(rows)
        end
        checkerState.leadersFlowUntil = 0
        return checkerBlockDialog(dialogId, button1, button2)
    end

    return false
end

local function checkerAdminsHeaderMode(plain)
    return Parser.parseAdminHeader(plain)
end

local function checkerStartAdminsCapture(mode)
    if checkerState.adminsCapture and os.clock() < (checkerState.adminsCapture.untilAt or 0) then
        checkerState.adminsCapture.mode = mode or checkerState.adminsCapture.mode or 'merge'
        checkerState.adminsCapture.untilAt = os.clock() + CHECKER_ADMINS_CAPTURE_T
        checkerState.syncInFlight = true
        return
    end
    checkerState.adminsCapture = {
        mode = mode or checkerState.pendingAdminMode or 'merge',
        untilAt = os.clock() + CHECKER_ADMINS_CAPTURE_T,
        list = {},
        seen = {},
        byNick = {},
    }
    checkerState.syncInFlight = true
end

local function checkerSortCatalogAdmins(list)
    table.sort(list, function(a, b)
        local ka = checkerAdminSortKey(a.level)
        local kb = checkerAdminSortKey(b.level)
        if ka ~= kb then return ka > kb end
        return (a.nick or '') < (b.nick or '')
    end)
end

local function checkerCatalogEntryFromCapture(e)
    return { nick = e.nick, level = e.level }
end

local function checkerApplyAdminsCapture(cap)
    if not cap or #cap.list == 0 then return end
    ensureCheckerCatalog()
    if cap.mode == 'replace' then
        local list = {}
        for _, e in ipairs(cap.list) do
            list[#list + 1] = checkerCatalogEntryFromCapture(e)
        end
        checkerSortCatalogAdmins(list)
        checkerCatalog.admins = list
    else
        for _, e in ipairs(cap.list) do
            local ex = Catalog.getAdmin(e.nick)
            if ex then
                ex.level = e.level
            else
                checkerCatalog.admins[#checkerCatalog.admins + 1] = checkerCatalogEntryFromCapture(e)
            end
        end
        checkerSortCatalogAdmins(checkerCatalog.admins)
    end
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    print(string.format('[Report Desk] checker: captured %d admins (%s)',
        #cap.list, cap.mode or '?'))
end

local function checkerFlushAdminsCapture(force)
    local cap = checkerState.adminsCapture
    if not cap then
        checkerState.syncInFlight = false
        return
    end
    if not force and os.clock() < (cap.untilAt or 0) then return end
    checkerState.adminsCapture = nil
    checkerState.syncInFlight = false
    checkerApplyAdminsCapture(cap)
end

local function checkerCaptureAdminLine(plain)
    local cap = checkerState.adminsCapture
    if not cap then return false end
    local nick, level, pid = Parser.parseAdminLine(plain)
    if not nick then
        if #cap.list > 0 then checkerFlushAdminsCapture(true) end
        return false
    end
    local key = nickKey(nick)
    if not cap.seen[key] then
        cap.seen[key] = true
        local entry = { nick = nick, level = level, id = pid }
        cap.list[#cap.list + 1] = entry
        if type(cap.byNick) == 'table' then cap.byNick[key] = entry end
    else
        local entry = type(cap.byNick) == 'table' and cap.byNick[key] or nil
        if entry then
            entry.level = level
            if pid and not entry.id then entry.id = pid end
        end
    end
    cap.untilAt = os.clock() + CHECKER_ADMINS_CAPTURE_T
    return true
end

local function checkerIsSyncBlocked()
    if checkerIsSuspended() then return true end
    if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then return true end
    if type(showWindow) == 'table' and showWindow[0] then return true end
    return false
end

local function checkerRequestAdminsChatSync()
    if not checkerSampReady() then return false end
    if checkerIsSyncBlocked() then return false end
    if checkerState.syncInFlight and checkerState.adminsCapture then return false end
    checkerState.pendingAdminMode = 'merge'
    checkerStartAdminsCapture('merge')
    if type(sendChat) ~= 'function' then return false end
    local ok = SafeCall('sendChat', sendChat, '/admins')
    if ok then
        checkerLog('sent /admins')
    else
        checkerState.adminsCapture = nil
        checkerState.syncInFlight = false
    end
    return ok == true
end

local function checkerRequestAdmsSync()
    if not checkerSampReady() then return false end
    if checkerIsSyncBlocked() then return false end
    local now = os.clock()
    checkerState.pendingAdminMode = 'replace'
    checkerState.adminsFlowUntil = now + CHECKER_ADMINS_FLOW_T
    checkerStartAdminsCapture('replace')
    if type(sendChat) ~= 'function' then return false end
    return SafeCall('sendChat', sendChat, '/adms') == true
end

local function checkerRequestLeadersSync()
    if not checkerSampReady() then return false end
    if checkerIsSyncBlocked() then return false end
    checkerState.leadersFlowUntil = os.clock() + CHECKER_LEADERS_FLOW_T
    if type(sendChat) ~= 'function' then return false end
    return SafeCall('sendChat', sendChat, '/leaders') == true
end

local function checkerDeferSyncAfterResume()
    local now = os.clock()
    local admsDefer = now + 6.0
    local leadersDefer = now + 10.0
    if not checkerState.autoAdmsAt or checkerState.autoAdmsAt < admsDefer then
        checkerState.autoAdmsAt = admsDefer
    end
    if not checkerState.autoLeadersAt or checkerState.autoLeadersAt < leadersDefer then
        checkerState.autoLeadersAt = leadersDefer
    end
    checkerScheduleRebuild()
end

local function checkerRunAutoSyncStep()
    if settings.checker_auto_sync == false then return end
    if not checkerSampReady() then return end
    if checkerIsSyncBlocked() then return end
    local now = os.clock()
    if not checkerState.autoAdmsAt then
        checkerState.autoAdmsAt = now + CHECKER_AUTO_SYNC_INITIAL
    end
    if not checkerState.autoLeadersAt then
        checkerState.autoLeadersAt = now + CHECKER_AUTO_SYNC_INITIAL + CHECKER_AUTO_LEADERS_DELAY
    end
    if now >= checkerState.autoAdmsAt then
        checkerState.autoAdmsAt = now + CHECKER_AUTO_ADMS_INTERVAL
        checkerRequestAdminsChatSync()
    end
    if now >= checkerState.autoLeadersAt then
        checkerState.autoLeadersAt = now + CHECKER_AUTO_LEADERS_INTERVAL
        checkerRequestLeadersSync()
    end
end

function checkerManualSync()
    if not checkerIsSpawned() then
        if type(say) == 'function' then
            say('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE0\xF6\xE8\xFF \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xE0: \xE4\xEE\xE6\xE4\xE8\xF2\xE5\xF1\xFC \xF1\xEF\xE0\xE2\xED\xE0')
        end
        return
    end
    if checkerIsSyncBlocked() then
        if type(say) == 'function' then
            say('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE0\xF6\xE8\xFF \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xE0: \xE7\xE0\xEA\xF0\xEE\xE9\xF2\xE5 \xE4\xE8\xE0\xEB\xEE\xE3 \xE8\xEB\xE8 /reps')
        end
        return
    end
    checkerRequestAdmsSync()
    if type(lua_thread) == 'table' and type(lua_thread.create) == 'function' then
        lua_thread.create(function()
            wait(2500)
            if not checkerIsSyncBlocked() then
                checkerRequestLeadersSync()
            end
        end)
    else
        checkerRequestLeadersSync()
    end
    if type(say) == 'function' then
        say('\xC7\xE0\xEF\xF0\xEE\xF8\xE5\xED /adms \xE8 /leaders.')
    end
end

local function checkerAdminLevelLabel(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsSpecialLevel(level) then
        return 'S' .. tostring(checkerSpecialLevelNum(level))
    end
    local titles = settings.checker_level_titles
    if type(titles) == 'table' then
        local custom = titles[level] or titles[tostring(level)]
        if custom and trim(tostring(custom)) ~= '' then
            return trim(tostring(custom))
        end
    end
    if level > 0 then
        return string.format('\xD3\xF0\xEE\xE2\xE5\xED\xFC %i', level)
    end
    return '\xC1\xE5\xE7 \xF3\xF0\xEE\xE2\xED\xFF'
end

local function checkerPlayJoinAlert()
    if settings.checker_notify_sound == false then return end
    if type(playDeskAlertSound) == 'function' then
        SafeCall('playDeskAlertSound', playDeskAlertSound)
    end
end

function checkerOnSendCommand(command)
    -- Перехват /adms /leaders только когда чекер сам запросил sync (checkerRequest*Sync).
    -- Ручной ввод игроком не трогаем — серверное окно должно открываться.
end

function checkerMarkCatalogDirty()
    Catalog.rebuildIndex()
    bumpCatalogRev()
    if type(markDirtySettings) == 'function' then
        SafeCall('markDirtySettings', markDirtySettings)
    end
end

function checkerSaveCatalogToUser(f)
    ensureCheckerCatalog()
    f:write('  checker = {\n')
    f:write('    admins = {\n')
    for _, e in ipairs(checkerCatalog.admins) do
        f:write('      { nick = ' .. luaQuoteUtf8(e.nick or '') .. ', level = ' .. math.floor(tonumber(e.level) or 0) .. ' },\n')
    end
    f:write('    },\n')
    f:write('    leaders = {\n')
    for _, e in ipairs(checkerCatalog.leaders) do
        f:write('      { nick = ' .. luaQuoteUtf8(e.nick or '') .. ', org = ' .. math.floor(tonumber(e.org) or 0))
        if trim(e.org_name or '') ~= '' then
            f:write(', org_name = ' .. luaQuoteUtf8(e.org_name))
        end
        if trim(e.role or '') ~= '' then
            f:write(', role = ' .. luaQuoteUtf8(e.role))
        end
        if checkerLeaderIsHidden(e) then
            f:write(', hidden = true')
        end
        f:write(' },\n')
    end
    f:write('    },\n')
    ensureCheckerSettings()
    local hiddenKeys = {}
    for key in pairs(settings.checker_leader_hidden) do
        if key ~= '' then hiddenKeys[#hiddenKeys + 1] = key end
    end
    table.sort(hiddenKeys)
    f:write('    hidden_nicks = {\n')
    for _, key in ipairs(hiddenKeys) do
        f:write('      ' .. luaQuoteUtf8(key) .. ',\n')
    end
    f:write('    },\n')
    f:write('    friends = {\n')
    for _, e in ipairs(checkerCatalog.friends) do
        f:write('      { nick = ' .. luaQuoteUtf8(e.nick or '') .. ' },\n')
    end
    f:write('    },\n')
    f:write('  },\n')
end

function checkerLoadCatalogFromUser(data)
    if type(data) ~= 'table' or type(data.checker) ~= 'table' then return false end
    ensureCheckerCatalog()
    local c = data.checker
    local changed = false
    if type(c.admins) == 'table' and #c.admins > 0 then
        local list = {}
        for _, raw in ipairs(c.admins) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                list[#list + 1] = {
                    nick = trim(raw.nick),
                    level = math.floor(tonumber(raw.level) or 0),
                }
            end
        end
        if #list > 0 then
            checkerCatalog.admins = list
            changed = true
        end
    end
    if type(c.hidden_nicks) == 'table' then
        for _, nick in ipairs(c.hidden_nicks) do
            if type(nick) == 'string' and trim(nick) ~= '' then
                checkerSetLeaderNickHidden(nick, true)
                changed = true
            end
        end
        for key, val in pairs(c.hidden_nicks) do
            if val == true and type(key) == 'string' and trim(key) ~= '' then
                checkerSetLeaderNickHidden(key, true)
                changed = true
            end
        end
    end
    if type(c.leaders) == 'table' and #c.leaders > 0 then
        local list = {}
        for _, raw in ipairs(c.leaders) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                local nick = trim(raw.nick)
                if raw.hidden == true then checkerSetLeaderNickHidden(nick, true) end
                list[#list + 1] = {
                    nick = nick,
                    org = math.floor(tonumber(raw.org) or 0),
                    org_name = trim(raw.org_name or ''),
                    role = trim(raw.role or ''),
                    hidden = checkerIsLeaderNickHidden(nick) and true or nil,
                }
            end
        end
        if #list > 0 then
            checkerCatalog.leaders = list
            changed = true
        end
    end
    if type(c.friends) == 'table' and #c.friends > 0 then
        local list = {}
        for _, raw in ipairs(c.friends) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                list[#list + 1] = { nick = trim(raw.nick) }
            end
        end
        if #list > 0 then
            checkerCatalog.friends = list
            changed = true
        end
    end
    if changed then
        Catalog.rebuildIndex()
        bumpCatalogRev()
    end
    return changed
end

local function readCheckerTxtLines(path, parser)
    if not doesFileExist(path) then return 0 end
    local f = io.open(path, 'r')
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
        line = trim(line)
        if line ~= '' and parser(line) then
            n = n + 1
        end
    end
    f:close()
    return n
end

function checkerImportFromAdminTools()
    ensureCheckerCatalog()
    local base = getWorkingDirectory() .. '\\AdminTools\\checker\\'
    local added = 0
    added = added + readCheckerTxtLines(base .. 'admins.txt', function(line)
        local nick, lvlStr = line:match('^(%S+)%s+(%S+)')
        if not nick then nick = line:match('^(%S+)') end
        if not nick then return false end
        if findCatalogAdmin(nick) then return false end
        local level = lvlStr and checkerParseAdminLevel(lvlStr) or 0
        checkerCatalog.admins[#checkerCatalog.admins + 1] = {
            nick = nick,
            level = level,
        }
        return true
    end)
    added = added + readCheckerTxtLines(base .. 'leaders.txt', function(line)
        local nick, org = line:match('^(%S+)%s+(%d+)')
        if not nick then return false end
        if findCatalogLeader(nick) then return false end
        checkerCatalog.leaders[#checkerCatalog.leaders + 1] = {
            nick = nick,
            org = math.floor(tonumber(org) or 0),
        }
        return true
    end)
    added = added + readCheckerTxtLines(base .. 'friends.txt', function(line)
        local nick = line:match('^(%S+)')
        if not nick or findCatalogFriend(nick) then return false end
        checkerCatalog.friends[#checkerCatalog.friends + 1] = { nick = nick }
        return true
    end)
    if added > 0 then
        checkerMarkCatalogDirty()
        checkerScheduleRebuild()
    end
    return added
end

local function sortAdminsOnline(list)
    local regular, special = checkerSplitAdminLists(list)
    local n = 0
    for _, e in ipairs(regular) do
        n = n + 1
        list[n] = e
    end
    for _, e in ipairs(special) do
        n = n + 1
        list[n] = e
    end
    for i = n + 1, #list do
        list[i] = nil
    end
end

local OnlineIndex = {}

local ONLINE_ROLE = {
    admin = { list = 'admins', byId = 'adminsById', byNick = 'adminsByNick' },
    leader = { list = 'leaders', byId = 'leadersById', byNick = 'leadersByNick' },
    friend = { list = 'friends', byId = 'friendsById', byNick = 'friendsByNick' },
}

function OnlineIndex.clear()
    local idx = checkerState.onlineIndex
    idx.adminsById = {}
    idx.leadersById = {}
    idx.friendsById = {}
    idx.adminsByNick = {}
    idx.leadersByNick = {}
    idx.friendsByNick = {}
end

function OnlineIndex.syncFromLists()
    OnlineIndex.clear()
    for role, cfg in pairs(ONLINE_ROLE) do
        local list = checkerOnline[cfg.list]
        if type(list) == 'table' then
            for _, e in ipairs(list) do
                OnlineIndex.add(role, e, true)
            end
        end
    end
end

function OnlineIndex.add(role, entry, skipSort)
    local cfg = ONLINE_ROLE[role]
    if not cfg or type(entry) ~= 'table' then return false end
    local id = tonumber(entry.id)
    if not id then return false end
    local idx = checkerState.onlineIndex
    local byId = idx[cfg.byId]
    local byNick = idx[cfg.byNick]
    local list = checkerOnline[cfg.list]
    if type(byId) ~= 'table' or type(byNick) ~= 'table' or type(list) ~= 'table' then return false end
    if not byId[id] then
        list[#list + 1] = entry
        if role == 'admin' and not skipSort then sortAdminsOnline(list)
        elseif role ~= 'admin' and not skipSort then
            table.sort(list, function(a, b) return (a.nick or '') < (b.nick or '') end)
        end
    else
        for i, e in ipairs(list) do
            if e.id == id then list[i] = entry break end
        end
    end
    byId[id] = entry
    local key = nickKey(entry.nick)
    if key ~= '' then byNick[key] = entry end
    return true
end

function OnlineIndex.removeById(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    local idx = checkerState.onlineIndex
    local changed = false
    for _, cfg in pairs(ONLINE_ROLE) do
        local byId = idx[cfg.byId]
        local byNick = idx[cfg.byNick]
        local list = checkerOnline[cfg.list]
        local entry = type(byId) == 'table' and byId[playerId] or nil
        if entry then
            byId[playerId] = nil
            local key = nickKey(entry.nick)
            if key ~= '' and type(byNick) == 'table' then byNick[key] = nil end
            if type(list) == 'table' then
                for i = #list, 1, -1 do
                    if list[i].id == playerId then
                        table.remove(list, i)
                        changed = true
                    end
                end
            end
        end
    end
    if changed then bumpOnlineRev() end
    return changed
end

function OnlineIndex.getById(role, playerId)
    playerId = tonumber(playerId)
    if not playerId then return nil end
    local cfg = ONLINE_ROLE[role]
    if not cfg then return nil end
    local byId = checkerState.onlineIndex[cfg.byId]
    if type(byId) ~= 'table' then return nil end
    return byId[playerId]
end

function OnlineIndex.getByNick(role, nick)
    local key = nickKey(nick)
    if key == '' then return nil end
    local cfg = ONLINE_ROLE[role]
    if not cfg then return nil end
    local byNick = checkerState.onlineIndex[cfg.byNick]
    if type(byNick) ~= 'table' then return nil end
    return byNick[key]
end

function OnlineIndex.hasId(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    local idx = checkerState.onlineIndex
    return (type(idx.adminsById) == 'table' and idx.adminsById[playerId] ~= nil)
        or (type(idx.leadersById) == 'table' and idx.leadersById[playerId] ~= nil)
        or (type(idx.friendsById) == 'table' and idx.friendsById[playerId] ~= nil)
end

function OnlineIndex.getTrackedRole(playerId)
    playerId = tonumber(playerId)
    if not playerId then return nil end
    local admin = OnlineIndex.getById('admin', playerId)
    if admin then return 'admin', admin end
    local leader = OnlineIndex.getById('leader', playerId)
    if leader then return 'leader', leader end
    local friend = OnlineIndex.getById('friend', playerId)
    if friend then return 'friend', friend end
    return nil
end

local function onlineListsEqual(newAdmins, newLeaders, newFriends)
    local function sameList(newList, oldList)
        if #newList ~= #oldList then return false end
        for i, e in ipairs(newList) do
            local o = oldList[i]
            if not o then return false end
            if e.id ~= o.id or e.nick ~= o.nick or (e.afk and true or false) ~= (o.afk and true or false) then
                return false
            end
            if e.level and o.level and e.level ~= o.level then return false end
        end
        return true
    end
    return sameList(newAdmins, checkerOnline.admins)
        and sameList(newLeaders, checkerOnline.leaders)
        and sameList(newFriends, checkerOnline.friends)
end

function checkerRebuildOnline(force)
    ensureCheckerCatalog()
    checkerState.lastRebuild = os.clock()
    if not checkerSampReady() then return false end
    local byNick = checkerBuildNickIndex()
    if type(refreshPlayerNickCache) == 'function' then
        SafeCall('refreshPlayerNickCache', refreshPlayerNickCache, true)
    end
    local admins, leaders, friends = {}, {}, {}
    for _, e in ipairs(checkerCatalog.admins) do
        if e and e.nick then
            local id = checkerLookupOnlineId(e.nick)
            if id then
                local prev = OnlineIndex.getById('admin', id)
                local nick = checkerSafeNick(id, e.nick)
                admins[#admins + 1] = {
                    id = id,
                    nick = nick,
                    level = tonumber(e.level) or 0,
                    afk = prev and prev.afk or checkerPlayerAfk(id),
                }
            end
        end
    end
    for _, e in ipairs(checkerCatalog.leaders) do
        if e and e.nick and not checkerLeaderIsHidden(e) then
            local id = checkerLookupOnlineId(e.nick)
            if id then
                local prev = OnlineIndex.getById('leader', id)
                local nick = checkerSafeNick(id, e.nick)
                leaders[#leaders + 1] = {
                    id = id,
                    nick = nick,
                    org = tonumber(e.org) or 0,
                    org_name = e.org_name or '',
                    role = e.role or '',
                    afk = prev and prev.afk or checkerPlayerAfk(id),
                }
            end
        end
    end
    for _, e in ipairs(checkerCatalog.friends) do
        if e and e.nick then
            local id = checkerLookupOnlineId(e.nick)
            if id then
                local prev = OnlineIndex.getById('friend', id)
                local nick = checkerSafeNick(id, e.nick)
                friends[#friends + 1] = {
                    id = id,
                    nick = nick,
                    afk = prev and prev.afk or checkerPlayerAfk(id),
                }
            end
        end
    end
    admins = checkerDedupeOnlineById(admins)
    leaders = checkerDedupeOnlineById(leaders)
    friends = checkerDedupeOnlineById(friends)
    sortAdminsOnline(admins)
    table.sort(leaders, function(a, b) return (a.nick or '') < (b.nick or '') end)
    table.sort(friends, function(a, b) return (a.nick or '') < (b.nick or '') end)
    local changed = force == true or not onlineListsEqual(admins, leaders, friends)
    if changed or force == true then
        checkerOnline.admins = admins
        checkerOnline.leaders = leaders
        checkerOnline.friends = friends
        OnlineIndex.syncFromLists()
        bumpOnlineRev()
    end
    -- During warmup: players from scan are already on server (join may not fire after reload).
    if not checkerState.joinNotifyReady then
        checkerMarkPlayersSeenFromOnline()
    end
    checkerPublishHudState()
    checkerTryEnableJoinNotify()
    checkerState.lastOnlineCatalogRev = tonumber(checkerState.catalogRev) or 0
    checkerState.lastOnlineRev = checkerOnlineRev
    local scanned = checkerCountNickIndex(byNick)
    checkerLog(string.format('online %d/%d/%d (scanned %d)', #admins, #leaders, #friends, scanned))
    if #admins == 0 and #checkerCatalog.admins > 0 and (checkerState.lastZeroWarn or 0) + 30 < os.clock() then
        checkerState.lastZeroWarn = os.clock()
        if scanned > 0 then
            print(string.format('[Report Desk] checker: 0 admins online, catalog=%d, players scanned=%d (nick mismatch?)',
                #checkerCatalog.admins, scanned))
        else
            print(string.format('[Report Desk] checker: 0 players scanned (maxId=%d, spawned=%s)',
                checkerMaxPlayerId(), tostring(checkerIsSpawned())))
        end
    elseif #admins > 0 and not checkerState.reportedOnline then
        checkerState.reportedOnline = true
        print(string.format('[Report Desk] checker: online %d admins, %d leaders, %d friends',
            #admins, #leaders, #friends))
    end
    return changed
end

function rescanCheckerOnline(force)
    return checkerRebuildOnline(force)
end

local function checkerRemoveOnlineById(playerId)
    return OnlineIndex.removeById(playerId)
end

local function checkerAddOnlineFromJoin(playerId, nick)
    playerId = tonumber(playerId)
    nick = nick or ''
    if not playerId or nick == '' or not checkerSampReady() then return false end
    checkerBuildNickIndex()
    local displayNick = checkerNormalizeNick(nick) or nick
    local changed = false
    local admin = Catalog.getAdmin(nick)
    if admin and not OnlineIndex.getById('admin', playerId) then
        if OnlineIndex.add('admin', {
            id = playerId,
            nick = displayNick,
            level = tonumber(admin.level) or 0,
            afk = false,
        }) then
            changed = true
        end
    end
    local leader = Catalog.getLeader(nick)
    if leader and not checkerLeaderIsHidden(leader) and not OnlineIndex.getById('leader', playerId) then
        if OnlineIndex.add('leader', {
            id = playerId,
            nick = displayNick,
            org = tonumber(leader.org) or 0,
            org_name = leader.org_name or '',
            role = leader.role or '',
            afk = false,
        }) then
            changed = true
        end
    end
    if Catalog.getFriend(nick) and not OnlineIndex.getById('friend', playerId) then
        if OnlineIndex.add('friend', {
            id = playerId,
            nick = displayNick,
            afk = false,
        }) then
            changed = true
        end
    end
    if changed then
        bumpOnlineRev()
        checkerPublishHudState()
    end
    return changed
end

local function checkerTrackedRole(playerId)
    return OnlineIndex.getTrackedRole(playerId)
end

local function checkerSayAdminJoin(id, nick, level)
    level = math.floor(tonumber(level) or 0)
    local cnick = checkerFormatNickColored(nick, level)
    local msg
    if checkerIsSpecialLevel(level) then
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xF1\xEF\xE5\xF6. \xE0\xE4\xEC\xE8\xED %s, %s[%i].',
            checkerFormatAdminLevelDisplay(level), cnick, id)
    elseif level == ADMIN_LEVEL_7 or level == ADMIN_LEVEL_6 then
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xE3\xEB\xE0\xE2\xED\xFB\xE9 \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0, %s[%i].', cnick, id)
    elseif level == ADMIN_LEVEL_5 then
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xE7\xE0\xEC. \xE3\xEB\xE0\xE2\xED\xEE\xE3\xEE \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xE0, %s[%i].', cnick, id)
    elseif level >= ADMIN_LEVEL_1 and level <= ADMIN_LEVEL_4 then
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 %i \xF3\xF0\xEE\xE2\xED\xFF, %s[%i].', level, cnick, id)
    else
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 %s[%i].', cnick, id)
    end
    say(msg)
end

local function checkerSayLeaderJoin(id, nick, org)
    org = math.floor(tonumber(org) or 0)
    local fmt = CHECKER_ORG_JOIN[org]
    if org >= ORG_BAND and org <= ORG_BAND_MAX then
        fmt = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xE1\xE0\xED\xE4\xFB, %s[%i].'
    elseif org >= ORG_MAFIA and org <= ORG_MAFIA_MAX then
        fmt = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0 \xEC\xE0\xF4\xE8\xE8, %s[%i].'
    elseif not fmt then
        fmt = '\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xEB\xE8\xE4\xE5\xF0, %s[%i].'
    end
    say(string.format(fmt, nick, id))
end

function checkerOnPlayerJoin(playerId, nick)
    if not checkerSampReady() then return end
    SafeCall('onPlayerJoin', function()
        playerId = tonumber(playerId)
        nick = nick or ''
        if not playerId or nick == '' then return end
        local shouldNotify = checkerShouldNotifyJoin(playerId)
        checkerMarkPlayerSeen(playerId)
        if shouldNotify then
            local notified = false
            local admin = Catalog.getAdmin(nick)
            if admin and checkerNotifyJoinEnabled('admin') then
                checkerSayAdminJoin(playerId, nick, admin.level)
                notified = true
            else
                local leader = Catalog.getLeader(nick)
                if leader and checkerNotifyJoinEnabled('leader') then
                    checkerSayLeaderJoin(playerId, nick, leader.org)
                    notified = true
                elseif Catalog.getFriend(nick) and checkerNotifyJoinEnabled('friend') then
                    if type(say) == 'function' then
                        say(string.format('%s[%i] \xEF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF.', nick, playerId))
                    end
                    notified = true
                end
            end
            if notified then checkerPlayJoinAlert() end
        end
        checkerAddOnlineFromJoin(playerId, nick)
        checkerPublishHudState()
    end)
end

function checkerOnPlayerQuit(playerId)
    playerId = tonumber(playerId)
    if not playerId or not checkerSampReady() then return end
    local role, entry = checkerTrackedRole(playerId)
    if not role or not entry then
        checkerRemoveOnlineById(playerId)
        if type(checkerState.seenPlayerIds) == 'table' then
            checkerState.seenPlayerIds[playerId] = nil
        end
        return
    end
    checkerRemoveOnlineById(playerId)
    if not checkerNotifyQuitEnabled(role) then
        if type(checkerState.seenPlayerIds) == 'table' then
            checkerState.seenPlayerIds[playerId] = nil
        end
        return
    end
    if type(say) ~= 'function' then return end
    if role == 'admin' then
        say(string.format('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 %s[%i] \xEE\xF2\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF.',
            checkerFormatNickColored(entry.nick, entry.level), playerId))
    elseif role == 'leader' then
        say(string.format('\xCB\xE8\xE4\xE5\xF0 %s[%i] \xEE\xF2\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF.', entry.nick, playerId))
    else
        say(string.format('%s[%i] \xEE\xF2\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF.', entry.nick, playerId))
    end
    if type(checkerState.seenPlayerIds) == 'table' then
        checkerState.seenPlayerIds[playerId] = nil
    end
end

function checkerOnServerMessage(color, text)
    if not checkerIsSpawned() then return end
    if not text or text == '' then return end
    local plain = stripChatTimestamp(stripTags(text))
    if plain ~= '' then
        local hdrMode = checkerAdminsHeaderMode(plain)
        if hdrMode then
            if not checkerState.adminsCapture then
                checkerStartAdminsCapture(hdrMode)
            end
            checkerState.adminsCapture.untilAt = os.clock() + CHECKER_ADMINS_CAPTURE_T
        elseif checkerState.adminsCapture then
            if not checkerCaptureAdminLine(plain) and #(checkerState.adminsCapture.list or {}) > 0 then
                checkerFlushAdminsCapture(true)
            end
        end
    end

    if settings.checker_auto_promote == false then return end
    if tonumber(color) ~= SAMP_COLOR_AUTO_PROMOTE then return end
    plain = stripTags(text)
    local nick = plain:match('[_%w]+')
    local lvlStr = plain:match('%(([Ss]?%d*)%s*lvl%)') or plain:match('([Ss]%d+)%s*lvl') or plain:match('(%d+)%s*lvl')
    local lvl = checkerParseAdminLevel(lvlStr)
    if not nick or not lvl then return end
    local myNick = ''
    SafeCall('autoPromoteMyNick', function()
        if not checkerIsSpawned() then return end
        if type(sampGetPlayerIdByCharHandle) ~= 'function' or type(sampGetPlayerNickname) ~= 'function' then return end
        local ok, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
        if ok and myId then
            myNick = sampGetPlayerNickname(myId) or ''
        end
    end)
    if nickKey(myNick) == nickKey(nick) then return end
    ensureCheckerCatalog()
    local existing = Catalog.getAdmin(nick)
    if existing then
        local old = math.floor(tonumber(existing.level) or 0)
        if old ~= lvl then
            existing.level = lvl
            checkerMarkCatalogDirty()
        end
        return
    end
    checkerCatalog.admins[#checkerCatalog.admins + 1] = { nick = nick, level = lvl }
    checkerSortCatalogAdmins(checkerCatalog.admins)
    checkerMarkCatalogDirty()
    local id = checkerLookupOnlineId(nick)
    if id then checkerAddOnlineFromJoin(id, nick) end
end

function checkerScheduleRebuild()
    checkerState.pendingRebuild = true
end

function checkerScheduleRescan()
    checkerScheduleRebuild()
end

local function checkerRunPendingRebuild()
    if not checkerState.pendingRebuild or not checkerSampReady() then return end
    checkerState.pendingRebuild = false
    SafeCall('rebuildOnlinePending', checkerRebuildOnline, true)
end

local function checkerPollTrackedAfk()
    if not checkerSampReady() then return end
    if checkerIsSuspended() then return end
    local now = os.clock()
    if now - (checkerState.lastAfkPoll or 0) < CHECKER_AFK_POLL_INTERVAL then return end
    checkerState.lastAfkPoll = now
    local changed = false
    for _, list in ipairs({ checkerOnline.admins, checkerOnline.leaders, checkerOnline.friends }) do
        if type(list) == 'table' then
            for _, e in ipairs(list) do
                if e and e.id then
                    local afk = checkerPlayerAfk(e.id)
                    if (e.afk and true or false) ~= (afk and true or false) then
                        e.afk = afk
                        changed = true
                    end
                end
            end
        end
    end
    if changed then bumpOnlineRev() end
end

function checkerOnPlayerStreamIn(playerId)
    playerId = tonumber(playerId)
    if not playerId or not checkerIsSpawned() then return end
    local nick = checkerSafeNick(playerId, '')
    if nick ~= '' and checkerAddOnlineFromJoin(playerId, nick) then return end
    checkerScheduleRebuild()
end

local function checkerNoteSpawned()
    if not checkerIsSpawned() then return end
    if checkerState.spawnedAt then return end
    checkerState.spawnedAt = os.clock()
    checkerState.firstRebuildAt = checkerState.spawnedAt + CHECKER_SPAWN_REBUILD_DELAY
    checkerState.lastRebuild = 0
    checkerResetJoinNotifyWarmup()
end

local Sync = {}

function Sync.update()
    if checkerState.adminsCapture then
        SafeCall('flushCapture', checkerFlushAdminsCapture, false)
    end
    SafeCall('pendingRebuild', checkerRunPendingRebuild)
    if os.clock() - (checkerState.lastRescan or 0) >= CHECKER_RESCAN_INTERVAL then
        checkerState.lastRescan = os.clock()
        SafeCall('periodicRescan', checkerRebuildOnline, false)
    end
    if os.clock() - (checkerState.lastRebuild or 0) >= CHECKER_REBUILD_INTERVAL then
        checkerState.lastRebuild = os.clock()
        SafeCall('periodicRebuild', checkerRebuildOnline, false)
    end
end

local Tracker = {}

function Tracker.update()
    if checkerState.firstRebuildAt and os.clock() >= checkerState.firstRebuildAt then
        checkerState.firstRebuildAt = nil
        checkerScheduleRebuild()
    end
end

local Afk = {}

function Afk.update()
    SafeCall('pollAfk', checkerPollTrackedAfk)
end

local Hud = {}

function Hud.update()
    if checkerIsSuspended() and checkerState.hudDrag then
        checkerState.hudDrag.active = false
    end
end

function checkerTick()
    if not checkerSampReady() then
        checkerState.spawnedAt = nil
        checkerState.firstRebuildAt = nil
        checkerState.wasSuspended = false
        if checkerState.hudDrag then checkerState.hudDrag.active = false end
        checkerState.adminsCapture = nil
        checkerState.syncInFlight = false
        checkerState.adminsFlowUntil = 0
        checkerState.leadersFlowUntil = 0
        return
    end
    local suspended = checkerIsSuspended()
    if suspended then
        checkerState.wasSuspended = true
        if checkerState.hudDrag then checkerState.hudDrag.active = false end
    else
        if checkerState.wasSuspended then
            checkerState.wasSuspended = false
            checkerDeferSyncAfterResume()
        end
        checkerNoteSpawned()
        checkerTryEnableJoinNotify()
    end
    SafeCall('Hud.update', Hud.update)
    SafeCall('Tracker.update', Tracker.update)
    SafeCall('Sync.update', Sync.update)
    SafeCall('Afk.update', Afk.update)
    if not suspended then
        SafeCall('autoSync', checkerRunAutoSyncStep)
    end
end

function checkerInit()
    SafeCall('checkerInit', function()
        ensureCheckerSettings()
        ensureCheckerCatalog()
        Catalog.rebuildIndex()
        if not catalogHasAny() then
            SafeCall('importAdminTools', checkerImportFromAdminTools)
            Catalog.rebuildIndex()
        end
        checkerState.spawnedAt = nil
        checkerState.firstRebuildAt = nil
        checkerState.lastAfkPoll = 0
        checkerState.lastRebuild = 0
        checkerState.lastOnlineCatalogRev = -1
        checkerState.lastOnlineRev = -1
        checkerState.syncInFlight = false
        checkerState.adminsCapture = nil
        checkerState.adminsFlowUntil = 0
        checkerState.leadersFlowUntil = 0
        checkerState.wasSuspended = false
        checkerState.lastRescan = 0
        local now = os.clock()
        checkerState.autoAdmsAt = now + CHECKER_AUTO_SYNC_INITIAL
        checkerState.autoLeadersAt = now + CHECKER_AUTO_SYNC_INITIAL + CHECKER_AUTO_LEADERS_DELAY
        checkerState.reportedOnline = false
        checkerState.onlineNickIndex = { byNick = {}, byExact = {} }
        checkerOnline.admins = {}
        checkerOnline.leaders = {}
        checkerOnline.friends = {}
        OnlineIndex.clear()
        checkerOnlineRev = 0
        checkerResetJoinNotifyWarmup()
        checkerState.hudFrameInstalled = false
        checkerState.lastHudHealAt = nil
        rawset(_G, '__desk_checkerHud', nil)
        installCheckerHudFrame()
        checkerPublishHudState()
        if checkerSampReady() then
            checkerScheduleRebuild()
        end
        print(string.format('[Report Desk] checker catalog: %d admins, %d leaders, %d friends',
            #checkerCatalog.admins, #checkerCatalog.leaders, #checkerCatalog.friends))
    end)
end

local function checkerHudVisible()
    ensureCheckerSettings()
    if settings.checker_hud == false then return false end
    if type(showWindow) == 'table' and showWindow[0] then return false end
    if type(isSampAvailable) == 'function' and not isSampAvailable() then return false end
    return true
end

function uninstallCheckerHudFrame()
    local prev = rawget(_G, '__desk_checkerHudFrame')
    if (not prev or type(prev.Unsubscribe) ~= 'function')
            and type(deskCache) == 'table' and deskCache.checkerHudFrame then
        prev = deskCache.checkerHudFrame
    end
    if prev and type(prev.Unsubscribe) == 'function' then
        pcall(function() prev:Unsubscribe() end)
    end
    if type(deskCache) == 'table' then deskCache.checkerHudFrame = nil end
    rawset(_G, '__desk_checkerHudFrame', nil)
    if type(checkerState) == 'table' then checkerState.hudFrameInstalled = false end
end

function installCheckerHudFrame()
    if type(imgui) ~= 'table' or type(imgui.OnFrame) ~= 'function' then return end
    uninstallCheckerHudFrame()
    local frame = imgui.OnFrame(
        function()
            ensureCheckerSettings()
            return settings.checker_hud ~= false and not (type(showWindow) == 'table' and showWindow[0])
        end,
        function(self)
            local ok, err = pcall(drawCheckerHudOverlay)
            if not ok then
                print('[Report Desk] checker HUD draw: ' .. tostring(err))
            end
            self.HideCursor = true
            self.LockPlayer = false
        end
    )
    if frame then
        frame.HideCursor = true
        frame.LockPlayer = false
        if type(deskCache) == 'table' then deskCache.checkerHudFrame = frame end
        rawset(_G, '__desk_checkerHudFrame', frame)
        checkerState.hudFrameInstalled = true
    end
end

local function checkerSafePlayerColor(id)
    id = tonumber(id)
    if not id then return nil end
    if type(sampIsPlayerConnected) ~= 'function' or type(sampGetPlayerColor) ~= 'function' then return nil end
    local ok, color = SafeCall('sampGetPlayerColor', function()
        if not sampIsPlayerConnected(id) then return nil end
        return sampGetPlayerColor(id)
    end)
    if not ok or not color then return nil end
    return checkerSampColorToImVec4(color)
end

local function checkerScreenSize()
    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    return sw, sh
end

local function checkerClampHudPos(hx, hy, winW, winH)
    local sw, sh = checkerScreenSize()
    winW = math.max(CHECKER_HUD_W, tonumber(winW) or CHECKER_HUD_W)
    winH = math.max(48, tonumber(winH) or 120)
    hx = math.max(8, math.min(hx, sw - winW - 8))
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

local function checkerHudSavedHeight(fallback)
    local h = tonumber(settings.checker_hud_h)
    if h and h >= 48 then return h end
    return math.max(48, tonumber(fallback) or 120)
end

local function checkerGuardHudOffScreen(hx, hy, winW, winH)
    local sw, sh = checkerScreenSize()
    winW = math.max(CHECKER_HUD_W, tonumber(winW) or CHECKER_HUD_W)
    winH = checkerHudSavedHeight(winH)
    if hx >= 8 and hy >= 8 and hx + winW <= sw - 8 and hy + winH <= sh - 8 then
        return hx, hy, false
    end
    local nx, ny = checkerClampHudPos(hx, hy, winW, winH)
    settings.checker_hud_x = math.floor(nx + 0.5)
    settings.checker_hud_y = math.floor(ny + 0.5)
    markDirtySettings()
    return nx, ny, true
end

local function checkerPersistHudPos(hx, hy, winW, winH)
    hx, hy = checkerClampHudPos(hx, hy, winW, winH)
    settings.checker_hud_x = math.floor(hx + 0.5)
    settings.checker_hud_y = math.floor(hy + 0.5)
    settings.checker_hud_h = math.floor(math.max(48, tonumber(winH) or 120) + 0.5)
    markDirtySettings()
end

local function checkerHudWantsInput()
    if checkerState.hudDrag and checkerState.hudDrag.active then return true end
    if checkerState.hudHovered then return true end
    local r = checkerState.hudRect
    if r then
        local mp = imgui.GetIO().MousePos
        return mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1
    end
    local hx = tonumber(settings.checker_hud_x) or 8
    local hy = tonumber(settings.checker_hud_y) or 8
    local hudH = checkerHudSavedHeight(160)
    local mp = imgui.GetIO().MousePos
    return mp.x >= hx and mp.x < hx + CHECKER_HUD_W + 80
        and mp.y >= hy and mp.y < hy + hudH + 20
end

local function checkerOnlineTags(e)
    if e and e.afk then return ' AFK' end
    return ''
end

local function drawCheckerAdminRow(e, index, idSuffix, indent)
    indent = tonumber(indent) or 0
    local lv = math.floor(tonumber(e.level) or 0)
    local col = checkerAdminColor(lv)
    local prefix = indent > 0 and string.rep(' ', math.floor(indent)) or ''
    local label = string.format('%s%i. %s [%i]', prefix, index, e.nick or '', e.id or -1)
    local lvlText = checkerFormatAdminLevelDisplay(lv)
    if lvlText ~= '' then
        label = label .. '  ' .. lvlText
    end
    label = label .. checkerOnlineTags(e)
    imgui.PushStyleColor(imgui.Col.Text, col)
    if imgui.Selectable(uiText(label) .. '##' .. idSuffix .. tostring(e.id or index), false) then
        if type(sendChat) == 'function' then SafeCall('sendChat', sendChat, '/sp ' .. e.id) end
    end
    imgui.PopStyleColor()
end

local function drawCheckerAdminsBlock()
    local list = select(1, checkerHudLists())
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    local regular, special = checkerSplitAdminLists(list)
    local shown = 0
    for _, e in ipairs(regular) do
        shown = shown + 1
        drawCheckerAdminRow(e, shown, 'adm_', 0)
    end
    if #special > 0 then
        if #regular > 0 then
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        imgui.TextColored(col_muted2, uiText('S'))
        local sIndex = 0
        for _, e in ipairs(special) do
            sIndex = sIndex + 1
            drawCheckerAdminRow(e, sIndex, 'adm_s_', 2)
        end
    end
end

local function drawCheckerColorListBlock(list, emptyText, idPrefix)
    idPrefix = idPrefix or 'pl'
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText(emptyText))
        return
    end
    local shown = 0
    for _, e in ipairs(list) do
        shown = shown + 1
        local col = checkerSafePlayerColor(e.id) or col_accent
        local label = string.format('%i. %s [%i]%s', shown, e.nick, e.id, checkerOnlineTags(e))
        imgui.PushStyleColor(imgui.Col.Text, col)
        if imgui.Selectable(uiText(label) .. '##' .. idPrefix .. tostring(e.id or shown), false) then
            pcall(sendChat, '/sp ' .. e.id)
        end
        imgui.PopStyleColor()
    end
end

local function drawCheckerLeadersBlock()
    local list = select(2, checkerHudLists())
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText('\xCB\xE8\xE4\xE5\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    local order, groups = checkerBuildLeaderGroups(list, false)
    if #order == 0 then
        imgui.TextColored(col_muted2, uiText('\xCB\xE8\xE4\xE5\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    if imgui.PushStyleVarVec2 then
        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(4, 1))
    end
    local shown = 0
    for _, gk in ipairs(order) do
        for _, e in ipairs(groups[gk].entries) do
            shown = shown + 1
            local col = checkerSafePlayerColor(e.id) or col_accent
            local role = checkerLeaderDisplayRole(e)
            local label = string.format('%i. %s [%i]%s', shown, e.nick, e.id, checkerOnlineTags(e))
            if role ~= '' then
                label = label .. '  \xB7  ' .. role
            end
            imgui.PushStyleColor(imgui.Col.Text, col)
            if imgui.Selectable(uiText(label) .. '##ld_' .. tostring(e.id or e.nick), false) then
                if type(sendChat) == 'function' then SafeCall('sendChat', sendChat, '/sp ' .. e.id) end
            end
            imgui.PopStyleColor()
        end
    end
    if imgui.PopStyleVar then imgui.PopStyleVar(1) end
end

local function drawCheckerFriendsBlock()
    local list = select(3, checkerHudLists())
    drawCheckerColorListBlock(list, '\xC4\xF0\xF3\xE7\xE5\xE9 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2', 'fr')
end

local function drawCheckerFriendsSettings()
    ensureCheckerCatalog()
    if not checkerUi.friendNick then return end
    if imgui.InputTextWithHint then
        imgui.InputTextWithHint('##chk_fr_nick', uiText('\xCD\xE8\xEA \xE4\xF0\xF3\xE3\xE0'), checkerUi.friendNick, sizeof(checkerUi.friendNick))
    else
        imgui.InputText('##chk_fr_nick', checkerUi.friendNick, sizeof(checkerUi.friendNick))
    end
    imgui.SameLine()
    if imgui.Button(uiText('\xC4\xEE\xE1\xE0\xE2\xE8\xF2\xFC') .. '##chk_fr_add') then
        local nick = readInputBuf(checkerUi.friendNick)
        if checkerAddFriend(nick) then
            checkerUi.friendNick[0] = 0
        end
    end
    imgui.Spacing()
    if #checkerCatalog.friends == 0 then
        imgui.TextColored(col_muted2, uiText('\xD1\xEF\xE8\xF1\xEE\xEA \xE4\xF0\xF3\xE7\xE5\xE9 \xEF\xF3\xF1\xF2'))
    else
        for i, e in ipairs(checkerCatalog.friends) do
            local nick = e.nick or ''
            imgui.TextColored(col_accent, uiText(nick))
            imgui.SameLine()
            local removed = false
            if imgui.SmallButton then
                removed = imgui.SmallButton(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##chk_fr_rm_' .. i)
            elseif imgui.Button then
                removed = imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##chk_fr_rm_' .. i)
            end
            if removed then
                checkerRemoveFriend(nick)
            end
        end
    end
end

local function drawCheckerLeaderToggleRow(entry)
    local nick = entry.nick or ''
    local role = checkerLeaderDisplayRole(entry)
    local ref = checkerLeaderShowRef(nick)
    if not ref then return end
    local uid = nickKey(nick)
    imgui.PushID('chk_ld_' .. uid)
    local changed = false
    if imgui.Checkbox('##vis', ref) then
        changed = true
    end
    imgui.SameLine()
    imgui.TextColored(ref[0] and col_label or col_muted2, uiText(nick))
    if role ~= '' then
        imgui.SameLine()
        imgui.TextColored(col_muted2, uiText('  \xB7  ' .. role))
    end
    imgui.PopID()
    if changed then
        checkerSetLeaderHidden(nick, not ref[0])
    end
end

local function drawCheckerLeadersSettings()
    ensureCheckerCatalog()
    local leaders = checkerCatalog.leaders
    if #leaders == 0 then
        imgui.TextColored(col_muted2, uiText('\xCA\xE0\xF2\xE0\xEB\xEE\xE3 \xEB\xE8\xE4\xE5\xF0\xEE\xE2 \xEF\xF3\xF1\xF2 \x2014 \xE8\xEC\xEF\xEE\xF0\xF2 \xE8\xE7 AdminTools\\checker\\leaders.txt \xE8\xEB\xE8 user config'))
        return
    end
    imgui.TextColored(col_muted2, uiText('\xCE\xF2\xEA\xEB\xFE\xF7\xE8\xF2\xE5 \xEB\xE8\xE4\xE5\xF0\xE0, \xF7\xF2\xEE\xE1\xFB \xF3\xE1\xF0\xE0\xF2\xFC \xE5\xE3\xEE \xE8\xE7 HUD (\xF3\xE2\xE5\xE4\xEE\xEC\xEB\xE5\xED\xE8\xFF \xEE\xF1\xF2\xE0\xED\xF3\xF2\xF1\xFF).'))
    if checkerUi.leaderFilter then
        if imgui.InputTextWithHint then
            imgui.InputTextWithHint('##chk_ld_flt', uiText('\xD4\xE8\xEB\xFC\xF2\xF0 \xEF\xEE \xED\xE8\xEA\xF3 \xE8\xEB\xE8 \xEE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xE8'), checkerUi.leaderFilter, sizeof(checkerUi.leaderFilter))
        else
            imgui.InputText('##chk_ld_flt', checkerUi.leaderFilter, sizeof(checkerUi.leaderFilter))
        end
    end
    local flt = checkerUi.leaderFilter and trim(readInputBuf(checkerUi.leaderFilter)):lower() or ''
    local filtered = {}
    for _, e in ipairs(leaders) do
        local nick = e.nick or ''
        local org = trim(e.org_name or '')
        local role = checkerLeaderDisplayRole(e)
        local hay = (nick .. ' ' .. org .. ' ' .. role):lower()
        if flt == '' or hay:find(flt, 1, true) then
            filtered[#filtered + 1] = e
        end
    end
    local order, groups = checkerBuildLeaderGroups(filtered, false)
    if #order == 0 then
        imgui.TextColored(col_muted2, uiText('\xCD\xE8\xF7\xE5\xE3\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE'))
    else
        for gi, gk in ipairs(order) do
            local g = groups[gk]
            imgui.TextColored(col_accent, uiText(g.title))
            imgui.SameLine()
            imgui.TextColored(col_muted2, uiText('(' .. #g.entries .. ')'))
            imgui.Dummy(imgui.ImVec2(0, 2))
            for _, e in ipairs(g.entries) do
                drawCheckerLeaderToggleRow(e)
            end
            if gi < #order then
                imgui.Dummy(imgui.ImVec2(0, 6))
                local dl = imgui.GetWindowDrawList()
                if dl then
                    local p = imgui.GetCursorScreenPos()
                    local w = imgui.GetContentRegionAvail().x
                    if w > 20 then
                        dl:AddLine(
                            imgui.ImVec2(p.x, p.y),
                            imgui.ImVec2(p.x + w, p.y),
                            toU32(imgui.ImVec4(col_accent_dim.x, col_accent_dim.y, col_accent_dim.z, 0.25)),
                            1.0)
                    end
                end
                imgui.Dummy(imgui.ImVec2(0, 6))
            end
        end
    end
end

function drawCheckerHudOverlay()
    if not checkerHudVisible() then return end
    ensureCheckerSettings()
    if checkerState.lastHudHealAt == nil or os.clock() - checkerState.lastHudHealAt > 2.0 then
        local hudAdmins = select(1, checkerHudLists())
        if #hudAdmins == 0 and #checkerCatalog.admins > 0 and checkerSampReady() then
            checkerState.lastHudHealAt = os.clock()
            SafeCall('hudHealRebuild', checkerRebuildOnline, true)
        end
    end
    checkerState.hudHovered = false
    local hx = tonumber(settings.checker_hud_x) or 8
    local hy = tonumber(settings.checker_hud_y) or 8
    if not checkerState.hudPlaced and not (checkerState.hudDrag and checkerState.hudDrag.active) then
        hx, hy = checkerGuardHudOffScreen(hx, hy, CHECKER_HUD_W, checkerHudSavedHeight(120))
    end
    local wantInput = checkerHudWantsInput()
    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoNav + imgui.WindowFlags.NoScrollbar
    if not wantInput and imgui.WindowFlags.NoInputs then
        flags = flags + imgui.WindowFlags.NoInputs
    end
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(CHECKER_HUD_W, 0), imgui.ImVec2(CHECKER_HUD_W + 80, 900))
    imgui.SetNextWindowBgAlpha(0.86)
    if not checkerState.hudPlaced then
        imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)
        checkerState.hudPlaced = true
    elseif checkerState.hudDrag and checkerState.hudDrag.active then
        imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)
    end
    if imgui.Begin('###desk_checker_hud', nil, flags) then
        imgui.TextColored(col_accent, uiText('\xD7\xE5\xEA\xE5\xF0'))
        imgui.SameLine()
        local hudAdmins, hudLeaders, hudFriends = checkerHudLists()
        imgui.TextColored(col_muted2, uiText(string.format('(%i/%i/%i)',
            #hudAdmins, #hudLeaders, #hudFriends)))
        imgui.Separator()
        if settings.checker_show_admins ~= false then
            imgui.TextColored(col_label, uiText('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xFB \xE2 \xF1\xE5\xF2\xE8:'))
            drawCheckerAdminsBlock()
            imgui.Spacing()
        end
        if settings.checker_show_leaders ~= false then
            imgui.TextColored(col_label, uiText('\xCB\xE8\xE4\xE5\xF0\xFB \xE2 \xF1\xE5\xF2\xE8:'))
            drawCheckerLeadersBlock()
            imgui.Spacing()
        end
        if settings.checker_show_friends ~= false then
            imgui.TextColored(col_label, uiText('\xC4\xF0\xF3\xE7\xFC\xFF \xE2 \xF1\xE5\xF2\xE8:'))
            drawCheckerFriendsBlock()
            imgui.Spacing()
        end
        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        local mp = imgui.GetIO().MousePos
        checkerState.hudHovered = mp.x >= wp.x and mp.x < wp.x + ww and mp.y >= wp.y and mp.y < wp.y + wh
        checkerState.hudRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }
        local headerH = 28
        local onHeader = mp.y >= wp.y and mp.y < wp.y + headerH
        if onHeader and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
            if not checkerState.hudDrag then
                checkerState.hudDrag = { active = false, offX = 0, offY = 0 }
            end
            local delta = imgui.GetMouseDragDelta(0)
            if not checkerState.hudDrag.active then
                checkerState.hudDrag.active = true
                checkerState.hudDrag.offX = wp.x
                checkerState.hudDrag.offY = wp.y
                imgui.ResetMouseDragDelta(0)
            end
            local nx = checkerState.hudDrag.offX + delta.x
            local ny = checkerState.hudDrag.offY + delta.y
            nx, ny = checkerClampHudPos(nx, ny, ww, wh)
            settings.checker_hud_x = nx
            settings.checker_hud_y = ny
            if type(markDirtySettings) == 'function' then markDirtySettings() end
            if imgui.SetWindowPos then
                imgui.SetWindowPos(imgui.ImVec2(nx, ny))
            end
        elseif checkerState.hudDrag and checkerState.hudDrag.active and not imgui.IsMouseDown(0) then
            checkerState.hudDrag.active = false
            checkerPersistHudPos(wp.x, wp.y, ww, wh)
            if type(flushDirtyConfigNow) == 'function' then SafeCall('flushDirtyConfigNow', flushDirtyConfigNow) end
        elseif onHeader and imgui.IsMouseReleased(0) and not imgui.IsAnyItemActive() then
            checkerPersistHudPos(wp.x, wp.y, ww, wh)
            if type(flushDirtyConfigNow) == 'function' then SafeCall('flushDirtyConfigNow', flushDirtyConfigNow) end
        end
        imgui.End()
    end
end

function drawCheckerTab()
    if not checkerState.uiSynced then syncCheckerUiFromSettings() end
    pushPanelStyle(col_chat_bg)
    local childFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        childFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##checker_panel', imgui.ImVec2(-1, -1), false, childFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 6))

    deskFormPanelBegin('##chk_hud')
    drawSettingsCardHeader('\xCE\xE2\xE5\xF0\xEB\xE5\xE9 \xED\xE0 \xFD\xEA\xF0\xE0\xED\xE5')
    if deskFormCheckboxRow('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xF2\xFC HUD', checkerUi.hud, function(v)
        settings.checker_hud = v
        if not v then checkerState.hudPlaced = false end
        markDirtySettings()
    end) then end
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_show')
    drawSettingsCardHeader('\xD1\xE5\xEA\xF6\xE8\xE8')
    if deskFormCheckboxRow('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xFB', checkerUi.showAdmins, function(v)
        settings.checker_show_admins = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xCB\xE8\xE4\xE5\xF0\xFB', checkerUi.showLeaders, function(v)
        settings.checker_show_leaders = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xC4\xF0\xF3\xE7\xFC\xFF', checkerUi.showFriends, function(v)
        settings.checker_show_friends = v
        markDirtySettings()
    end) then end
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_friends')
    drawSettingsCardHeader('\xC4\xF0\xF3\xE7\xFC\xFF')
    drawCheckerFriendsSettings()
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_leaders_vis')
    drawSettingsCardHeader('\xCB\xE8\xE4\xE5\xF0\xFB \xE2 HUD')
    drawCheckerLeadersSettings()
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_sync')
    drawSettingsCardHeader('\xCA\xE0\xF2\xE0\xEB\xEE\xE3 \xE0\xE4\xEC\xE8\xED\xEE\xE2')
    imgui.TextColored(col_muted2, uiText('\xCE\xED\xEB\xE0\xE9\xED \xE2 HUD \xEE\xE1\xED\xEE\xE2\xEB\xFF\xE5\xF2\xF1\xFF \xE0\xE2\xF2\xEE\xEC\xE0\xF2\xE8\xF7\xE5\xF1\xEA\xE8 \xE8\xE7 \xF1\xEF\xE8\xF1\xEA\xE0. \xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE0\xF6\xE8\xFF \xED\xF3\xE6\xED\xE0 \xF2\xEE\xEB\xFC\xEA\xEE \xF7\xF2\xEE\xE1\xFB \xE4\xEE\xE1\xE0\xE2\xE8\xF2\xFC \xED\xEE\xE2\xFB\xF5 \xE0\xE4\xEC\xE8\xED\xEE\xE2 \xF1 \xF1\xE5\xF0\xE2\xE5\xF0\xE0.'))
    imgui.TextColored(col_muted2, uiText('\xD0\xF3\xF7\xED\xEE\xE9 /admins \xF2\xEE\xE6\xE5 \xEE\xE1\xED\xEE\xE2\xE8\xF2 \xEA\xE0\xF2\xE0\xEB\xEE\xE3 (\xEF\xE0\xF1\xF1\xE8\xE2\xED\xFB\xE9 \xE7\xE0\xF5\xE2\xE0\xF2).'))
    if imgui.Button(uiText('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE8\xF0\xEE\xE2\xE0\xF2\xFC \xEA\xE0\xF2\xE0\xEB\xEE\xE3 (/adms)') .. '##chk_sync_now') then
        SafeCall('checkerManualSync', checkerManualSync)
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_notify')
    drawSettingsCardHeader('\xD3\xE2\xE5\xE4\xEE\xEC\xEB\xE5\xED\xE8\xFF')
    if deskFormCheckboxRow('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5 (\xE0\xE4\xEC\xE8\xED\xFB)', checkerUi.notifyJoin, function(v)
        settings.checker_notify_join = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5 (\xEB\xE8\xE4\xE5\xF0\xFB)', checkerUi.notifyLeaderJoin, function(v)
        settings.checker_notify_leader_join = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xCE\xF2\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5', checkerUi.notifyQuit, function(v)
        settings.checker_notify_quit = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xC7\xE2\xF3\xEA \xEF\xF0\xE8 \xEF\xEE\xE4\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE8', checkerUi.notifySound, function(v)
        settings.checker_notify_sound = v
        markDirtySettings()
    end) then end
    deskFormPanelEnd()

    imgui.PopStyleVar()
    imgui.EndChild()
    popPanelStyle()
end
