--[[ Модуль: checker HUD.
     Каталог (кто админ + уровень): /adms при входе и кнопка «Синхронизировать».
     HUD «кто в сети»: каталог × скан игроков в табе (checkerRebuildOnline).
     /admins в чат — только обновление уровня уже известных админов (повышение). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

rawset(_G, 'checkerState', nil)
rawset(_G, 'checkerOnline', nil)
rawset(_G, 'checkerCatalog', nil)

local OnlineIndex

local CHECKER_LVL_SPECIAL_BASE = 100
local CHECKER_LVL_CHIEF_BASE = 200
local CHECKER_LVL_CHIEF_GA = 201
local CHECKER_LVL_CHIEF_ZGA = 202

local CHECKER_CHIEF_TAG = {
    [CHECKER_LVL_CHIEF_GA] = '\xC3\xC0',
    [CHECKER_LVL_CHIEF_ZGA] = '\xC7\xC3\xC0',
}

local CHECKER_CHIEF_COLOR = {
    [CHECKER_LVL_CHIEF_GA] = imgui.ImVec4(0.18, 0.52, 0.28, 1.0),
    [CHECKER_LVL_CHIEF_ZGA] = imgui.ImVec4(0.35, 0.85, 0.40, 1.0),
}

local CHECKER_CHIEF_COLOR_HEX = {
    [CHECKER_LVL_CHIEF_GA] = '2E8548',
    [CHECKER_LVL_CHIEF_ZGA] = '59D966',
}

local CHECKER_CHIEF_DEFAULTS = {
    { nick = 'Arthas_Bartolomeo', level = CHECKER_LVL_CHIEF_GA },
    { nick = 'Amattore_Adderio', level = CHECKER_LVL_CHIEF_ZGA },
}

local CHECKER_TOP_ADMIN_DEFAULTS = {
    'Andrey_Ringo',
    'Smart_Jackson',
}

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
local ORG_GROVE = 6
local ORG_BALLAS = 7
local ORG_VAGOS = 8
local ORG_AZTECAS = 9
local ORG_RIFA = 10
local ORG_YAKUZA = 11
local ORG_LCN = 12
local ORG_RMAF = 13
local ORG_BAND = ORG_GROVE
local ORG_BAND_MAX = ORG_RIFA
local ORG_MAFIA = ORG_YAKUZA
local ORG_MAFIA_MAX = ORG_RMAF

local SAMP_COLOR_AUTO_PROMOTE = -65281

-- Clist фракций (sampGetPlayerColor), собрано in-game + ballas purple.
local CHECKER_ORG_CLIST_COLOR = {
    [ORG_GOV] = 0xFFCCFF00,     -- pravitelstvo
    [ORG_MVD] = 0xFF0000FF,     -- mvd
    [ORG_MO] = 0xFF996633,      -- mo
    [ORG_MZ] = 0xFFFF6666,      -- mz
    [ORG_SMI] = 0xFFFF6600,     -- smi
    [ORG_GROVE] = 0xFF009900,   -- grove
    [ORG_BALLAS] = 0xFF800080,  -- ballas (purple, not sampled)
    [ORG_VAGOS] = 0xFFFFCD00,   -- vagos
    [ORG_AZTECAS] = 0xFF00CCFF, -- aztecas
    [ORG_RIFA] = 0xFF6666FF,    -- rifa
    [ORG_YAKUZA] = 0xFFBB0000,  -- yakuza
    [ORG_LCN] = 0xFF993366,     -- lcn
    [ORG_RMAF] = 0xFF007575,    -- russkaya mafia
    [0] = 0xFFAAAAAA,
}

local CHECKER_ORG_LABEL = {
    [ORG_GOV] = 'gov',
    [ORG_MVD] = 'mvd',
    [ORG_MO] = 'mo',
    [ORG_MZ] = 'mz',
    [ORG_SMI] = 'smi',
    [ORG_GROVE] = 'grove',
    [ORG_BALLAS] = 'ballas',
    [ORG_VAGOS] = 'vagos',
    [ORG_AZTECAS] = 'aztecas',
    [ORG_RIFA] = 'rifa',
    [ORG_YAKUZA] = 'yakuza',
    [ORG_LCN] = 'lcn',
    [ORG_RMAF] = 'rmaf',
}

local CHECKER_SPECIAL_COLOR = {
    [1] = imgui.ImVec4(0.98, 0.58, 0.38, 1.0),
    [2] = imgui.ImVec4(0.94, 0.72, 0.22, 1.0),
    [3] = imgui.ImVec4(0.32, 0.82, 0.68, 1.0),
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

-- Группы лидеров в настройках чекера: порядок, подзаголовок, clist-цвет секции.
local CHECKER_LEADER_FACTION_META = {
    gov = {
        sort = 1,
        title = '\xCF\xF0\xE0\xE2\xE8\xF2\xE5\xEB\xFC\xF1\xF2\xE2\xEE',
        clistOrg = ORG_GOV,
    },
    mo = {
        sort = 2,
        title = '\xCC\xCE',
        clistOrg = ORG_MO,
    },
    mz = {
        sort = 3,
        title = '\xCC\xC7',
        clistOrg = ORG_MZ,
    },
    illegal = {
        sort = 4,
        title = '\xCD\xE5\xEB\xE5\xE3\xE0\xEB\xFB',
        neutralHeader = true,
    },
    band = {
        sort = 4,
        title = '\xC1\xE0\xED\xE4\xFB',
        subtitle = true,
        headerColor = imgui.ImVec4(0.48, 0.72, 0.50, 1.0),
    },
    mafia = {
        sort = 4,
        title = '\xCC\xE0\xF4\xE8\xE8',
        subtitle = true,
        headerColor = imgui.ImVec4(0.78, 0.48, 0.48, 1.0),
    },
    mvd = {
        sort = 5,
        title = '\xCC\xC2\xC4',
        clistOrg = ORG_MVD,
    },
    smi = {
        sort = 6,
        title = '\xD1\xCC\xC8',
        clistOrg = ORG_SMI,
    },
    other = {
        sort = 99,
        title = '\xCF\xF0\xEE\xF7\xE5\xE5',
        clistOrg = 0,
    },
}

local checkerSpTheme = require 'report_desk_sp_theme'
local CheckerParser = require 'report_desk_checker_parser'
local CheckerCatalogStore = require 'report_desk_checker_catalog'
local CHECKER_HUD_W = checkerSpTheme.HUD_LIST_W or 218
local CHECKER_ADMINS_FLOW_T = 30.0
local CHECKER_ADMS_DIALOG_CHAT_GUARD_SEC = 10.0
local CHECKER_SPAWN_ADMS_MAX_RETRIES = 2
local CHECKER_ADMS_RESYNC_INTERVAL = 240.0
local CHECKER_ADMS_PARSE_DUMP_LEN = 500
local CHECKER_LEADERS_FLOW_T = 30.0
local CHECKER_LEADERS_SNAPSHOT_MAX_AGE = 180.0
local CHECKER_AFK_POLL_INTERVAL = 15.0
local CHECKER_REBUILD_INTERVAL = 15.0
local CHECKER_SPAWN_REBUILD_DELAY = 1.5
local CHECKER_SPAWN_SYNC_DELAY = 2.5
local CHECKER_SPAWN_SYNC_LEADERS_WAIT_MS = 1200
local CHECKER_SPAWN_SYNC_RETRY_SEC = 1.0
local CHECKER_SPAWN_DIALOG_WAIT_SEC = 6.0
local CHECKER_SYNC_CHAT_MIN_INTERVAL = 4.0
local CHECKER_HUD_HEAL_INTERVAL = 30.0
local CHECKER_HUD_HEAL_MAX_TRIES = 4
local CHECKER_HUD_HEAL_RESET_SEC = 300.0
local CHECKER_JOIN_NOTIFY_DELAY = 10.0
local L_ADMINS_ONLINE = '\xC0\xE4\xEC\xE8\xED\xFB \xEE\xED\xEB\xE0\xE9\xED'
local L_ADMIN_WORD = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0'
local L_LEADERS = '\xCB\xE8\xE4\xE5\xF0'

-- Fresh tables every load (env __index=_G would otherwise resurrect stale globals on reload).
checkerCatalog = { admins = {}, leaders = {}, friends = {}, org_clist = {} }
checkerOnline = { admins = {}, leaders = {}, friends = {} }
checkerOnlineRev = 0
checkerState = {}
do
    local s = checkerState
    s.hudPlaced = s.hudPlaced == true
    s.hudPosValidated = s.hudPosValidated == true
    s.hudDrag = type(s.hudDrag) == 'table' and s.hudDrag or { active = false, startX = 0, startY = 0, offX = 0, offY = 0 }
    if s.hudDrag.active == nil then s.hudDrag.active = false end
    if s.hudDrag.startX == nil then s.hudDrag.startX = 0 end
    if s.hudDrag.startY == nil then s.hudDrag.startY = 0 end
    if s.hudDrag.offX == nil then s.hudDrag.offX = 0 end
    if s.hudDrag.offY == nil then s.hudDrag.offY = 0 end
    s.hudHovered = s.hudHovered == true
    s.hudRect = type(s.hudRect) == 'table' and s.hudRect or nil
    s.lastRebuild = tonumber(s.lastRebuild) or 0
    s.lastAfkPoll = tonumber(s.lastAfkPoll) or 0
    s.uiSynced = s.uiSynced == true
    s.leadersFlowUntil = tonumber(s.leadersFlowUntil) or 0
    s.admsFlowUntil = tonumber(s.admsFlowUntil) or tonumber(s.admsAwaitUntil) or tonumber(s.adminsFlowUntil) or 0
    if s.admsFlow == nil and s.admsSyncOutbound == true then
        s.admsFlow = 'outbound'
    end
    if s.admsFlow ~= 'outbound' and s.admsFlow ~= 'parsing' and s.admsFlow ~= 'done' then
        s.admsFlow = nil
    end
    s.admsDialogSyncedAt = tonumber(s.admsDialogSyncedAt) or 0
    s.admsChatMuteUntil = tonumber(s.admsChatMuteUntil) or 0
    s.syncServerKey = type(s.syncServerKey) == 'string' and s.syncServerKey or ''
    s.leadersSyncOutbound = s.leadersSyncOutbound == true
    s.spawnCatalogSyncAt = tonumber(s.spawnCatalogSyncAt)
    s.spawnCatalogSyncDone = s.spawnCatalogSyncDone == true
    s.spawnCatalogSyncRunning = s.spawnCatalogSyncRunning == true
    s.spawnAdmsHandled = s.spawnAdmsHandled == true
    s.spawnLeadersHandled = s.spawnLeadersHandled == true
    s.nickIndexNeedsFullScan = s.nickIndexNeedsFullScan == true
    s.healResetAt = tonumber(s.healResetAt) or 0
    s.wasSuspended = s.wasSuspended == true
    s.pendingAdminMode = s.pendingAdminMode or 'replace'
    s.spawnedAt = s.spawnedAt
    s.firstRebuildAt = s.firstRebuildAt
    s.pendingRebuild = s.pendingRebuild == true
    s.leaderShowUi = type(s.leaderShowUi) == 'table' and s.leaderShowUi or {}
    s.leaderGroupShowUi = type(s.leaderGroupShowUi) == 'table' and s.leaderGroupShowUi or {}
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
    s.admsOnlineSnapshot = type(s.admsOnlineSnapshot) == 'table' and s.admsOnlineSnapshot or nil
    s.leadersOnlineSnapshot = type(s.leadersOnlineSnapshot) == 'table' and s.leadersOnlineSnapshot or nil
    s.syncSession = type(s.syncSession) == 'table' and s.syncSession or {}
    if s.syncSession.admsUntil == nil then s.syncSession.admsUntil = 0 end
    if s.syncSession.leadersUntil == nil then s.syncSession.leadersUntil = 0 end
    if s.syncSession.spawnAdmsRetries == nil then s.syncSession.spawnAdmsRetries = 0 end
    if s.syncSession.lastAdmsResync == nil then s.syncSession.lastAdmsResync = os.clock() end
end

CheckerParser.configure({
    trim = trim,
    stripTags = stripTags,
    lAdminsOnline = L_ADMINS_ONLINE,
    lAdminWord = L_ADMIN_WORD,
})

local Parser = CheckerParser

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

-- Safe Call
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

-- Bump Online Rev
local function bumpOnlineRev()
    checkerOnlineRev = (tonumber(checkerOnlineRev) or 0) + 1
end

-- Bump Catalog Rev
local function bumpCatalogRev()
    checkerState.catalogRev = (tonumber(checkerState.catalogRev) or 0) + 1
end

-- Ensure Checker Catalog
local function ensureCheckerCatalog()
    if type(checkerCatalog) ~= 'table' then checkerCatalog = {} end
    if type(checkerCatalog.admins) ~= 'table' then checkerCatalog.admins = {} end
    if type(checkerCatalog.leaders) ~= 'table' then checkerCatalog.leaders = {} end
    if type(checkerCatalog.friends) ~= 'table' then checkerCatalog.friends = {} end
    if type(checkerCatalog.org_clist) ~= 'table' then checkerCatalog.org_clist = {} end
end

-- === Catalog: admins/leaders/friends, индекс по nick ===
local Catalog = {}

-- Пересборка индекса каталога после import/sync.
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

-- Получить запись admin из каталога по nick.
function Catalog.getAdmin(nick)
    ensureCheckerCatalog()
    local key = nickKey(nick)
    if key == '' then return nil end
    local idx = checkerState.catalogIndex
    if type(idx.admins) ~= 'table' then Catalog.rebuildIndex() end
    return idx.admins[key]
end

-- Получить запись leader из каталога.
function Catalog.getLeader(nick)
    ensureCheckerCatalog()
    local key = nickKey(nick)
    if key == '' then return nil end
    local idx = checkerState.catalogIndex
    if type(idx.leaders) ~= 'table' then Catalog.rebuildIndex() end
    return idx.leaders[key]
end

-- Получить запись friend из каталога.
function Catalog.getFriend(nick)
    ensureCheckerCatalog()
    local key = nickKey(nick)
    if key == '' then return nil end
    local idx = checkerState.catalogIndex
    if type(idx.friends) ~= 'table' then Catalog.rebuildIndex() end
    return idx.friends[key]
end

-- Rebuild Checker Catalog Index
local function rebuildCheckerCatalogIndex()
    Catalog.rebuildIndex()
end

-- Ensure Checker Settings
local function ensureCheckerSettings()
    if settings.checker_hud == nil then settings.checker_hud = true end
    if settings.checker_show_admins == nil then settings.checker_show_admins = true end
    if settings.checker_show_leaders == nil then settings.checker_show_leaders = true end
    if settings.checker_show_friends == nil then settings.checker_show_friends = true end
    if settings.checker_notify_join == nil then settings.checker_notify_join = true end
    if settings.checker_notify_quit == nil then settings.checker_notify_quit = true end
    if settings.checker_notify_sound == nil then settings.checker_notify_sound = true end
    if settings.checker_notify_leader_join == nil then settings.checker_notify_leader_join = false end
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

-- Checker (admin HUD/catalog).
function checkerLeaderHiddenKey(nick)
    return nickKey(nick)
end

-- Checker (admin HUD/catalog).
function checkerIsLeaderNickHidden(nick)
    local key = checkerLeaderHiddenKey(nick)
    if key == '' then return false end
    ensureCheckerSettings()
    return settings.checker_leader_hidden[key] == true
end

-- Checker (admin HUD/catalog).
function checkerSetLeaderNickHidden(nick, hidden)
    local key = checkerLeaderHiddenKey(nick)
    if key == '' then return end
    ensureCheckerSettings()
    if hidden then
        settings.checker_leader_hidden[key] = true
    else
        settings.checker_leader_hidden[key] = nil
    end
end

-- Sync Checker Ui From Settings
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

-- Checker (admin HUD/catalog).
function checkerSampColorToImVec4(color)
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

-- Checker (admin HUD/catalog).
function checkerLog(msg)
    if settings and settings.debug == true then
        print('[Report Desk] checker: ' .. tostring(msg))
    end
end

-- Checker (admin HUD/catalog).
function checkerCopyOnlineEntry(e)
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

-- Checker (admin HUD/catalog).
function checkerDedupeOnlineById(list)
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

-- Checker (admin HUD/catalog).
function checkerCopyOnlineList(list)
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

-- Checker (admin HUD/catalog).
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

-- Checker (admin HUD/catalog).
function checkerHudLists()
    local h = rawget(_G, '__desk_checkerHud')
    if type(h) ~= 'table' then
        h = type(deskCache) == 'table' and deskCache.checkerHud
    end
    if type(h) == 'table' and type(h.admins) == 'table' then
        return h.admins, h.leaders or {}, h.friends or {}
    end
    return checkerOnline.admins, checkerOnline.leaders, checkerOnline.friends
end

-- Checker (admin HUD/catalog).
function checkerMarkPlayersSeenFromOnline()
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

-- Checker (admin HUD/catalog).
function checkerResetJoinNotifyWarmup()
    checkerState.joinNotifyReady = false
    checkerState.joinNotifyEnableAt = os.clock() + CHECKER_JOIN_NOTIFY_DELAY
    checkerState.seenPlayerIds = {}
end

-- Checker (admin HUD/catalog).
function checkerTryEnableJoinNotify()
    if checkerState.joinNotifyReady then return end
    if os.clock() < (checkerState.joinNotifyEnableAt or 0) then return end
    checkerMarkPlayersSeenFromOnline()
    checkerState.joinNotifyReady = true
end

-- Checker (admin HUD/catalog).
function checkerShouldNotifyJoin(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    if not checkerState.joinNotifyReady then return false end
    if type(checkerState.seenPlayerIds) ~= 'table' then checkerState.seenPlayerIds = {} end
    if checkerState.seenPlayerIds[playerId] == true then return false end
    if OnlineIndex and OnlineIndex.hasId and OnlineIndex.hasId(playerId) then return false end
    return true
end

-- Checker (admin HUD/catalog).
function checkerMarkPlayerSeen(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end
    if type(checkerState.seenPlayerIds) ~= 'table' then checkerState.seenPlayerIds = {} end
    checkerState.seenPlayerIds[playerId] = true
end

-- Checker (admin HUD/catalog).
function checkerNotifyJoinEnabled(role)
    role = role or ''
    if role == 'leader' then
        return settings.checker_notify_leader_join == true
    end
    if role == 'friend' then
        return settings.checker_notify_friend_join ~= false
    end
    return settings.checker_notify_join ~= false
end

-- Checker (admin HUD/catalog).
function checkerNotifyQuitEnabled(role)
    role = role or ''
    if role == 'leader' then
        if settings.checker_notify_leader_quit == false then return false end
        return settings.checker_notify_quit ~= false
    end
    return settings.checker_notify_quit ~= false
end

-- Checker (admin HUD/catalog).
function checkerSampConnected()
    if type(sampGetGamestate) ~= 'function' then return true end
    local ok, gs = SafeCall('sampGetGamestate', sampGetGamestate)
    return ok and gs == 3
end

checkerIsSpawned = function()
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return false end
    if type(sampIsLocalPlayerSpawned) == 'function' then
        local ok, spawned = SafeCall('sampIsLocalPlayerSpawned', sampIsLocalPlayerSpawned)
        return ok and spawned == true
    end
    return checkerSampConnected()
end

-- Checker (admin HUD/catalog).
function checkerSampReady()
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

-- Checker (admin HUD/catalog).
function checkerMaxPlayerId()
    local maxId = tonumber(MAX_PLAYER_ID) or 1000
    if type(sampGetMaxPlayerId) == 'function' then
        local ok, m = SafeCall('sampGetMaxPlayerId', sampGetMaxPlayerId, false)
        if ok and m and m >= 0 then return m end
        ok, m = SafeCall('sampGetMaxPlayerId', sampGetMaxPlayerId)
        if ok and m and m >= 0 then return m end
    end
    return maxId
end

-- Checker (admin HUD/catalog).
function checkerBuildNickIndex(forceRefresh)
    if type(refreshPlayerNickCache) == 'function' then
        SafeCall('refreshPlayerNickCache', refreshPlayerNickCache, forceRefresh == true)
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

-- Checker (admin HUD/catalog): убрать offline id из nick-index без full scan.
function checkerPruneNickIndex()
    local idx = checkerState.onlineNickIndex
    if type(idx) ~= 'table' then return end
    if type(idx.byNick) == 'table' then
        for key, id in pairs(idx.byNick) do
            if not checkerPlayerConnectedSafe(id) then idx.byNick[key] = nil end
        end
    end
    if type(idx.byExact) == 'table' then
        for nick, id in pairs(idx.byExact) do
            if not checkerPlayerConnectedSafe(id) then idx.byExact[nick] = nil end
        end
    end
end

-- Checker (admin HUD/catalog): full scan 0..maxId только при force / после spawn.
function checkerEnsureNickIndex(forceFull)
    if forceFull == true or checkerState.nickIndexNeedsFullScan == true then
        checkerBuildNickIndex(true)
        checkerState.nickIndexNeedsFullScan = false
        return
    end
    local idx = checkerState.onlineNickIndex
    if type(idx) ~= 'table' or type(idx.byNick) ~= 'table' then
        checkerBuildNickIndex(true)
        checkerState.nickIndexNeedsFullScan = false
        return
    end
    checkerPruneNickIndex()
end

-- Checker (admin HUD/catalog): точечное обновление nick-index при join.
function checkerIndexOnePlayer(playerId, nickHint)
    playerId = tonumber(playerId)
    if not playerId or not checkerSampReady() or not checkerPlayerConnectedSafe(playerId) then
        return false
    end
    local idx = checkerState.onlineNickIndex
    if type(idx) ~= 'table' then
        idx = { byNick = {}, byExact = {} }
        checkerState.onlineNickIndex = idx
    end
    if type(idx.byNick) ~= 'table' then idx.byNick = {} end
    if type(idx.byExact) ~= 'table' then idx.byExact = {} end
    local nick = checkerNormalizeNick(nickHint) or checkerSafeNick(playerId, '')
    if nick == '' then return false end
    idx.byExact[nick] = playerId
    local key = nickKey(nick)
    if key ~= '' then idx.byNick[key] = playerId end
    if type(playerNickToId) == 'table' and key ~= '' then
        playerNickToId[key] = playerId
    end
    return true
end

-- Checker (admin HUD/catalog).
function checkerCountNickIndex(byNick)
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
    local snap = checkerState.admsOnlineSnapshot
    if type(snap) == 'table' and type(snap.byNick) == 'table' then
        local snapId = snap.byNick[nickKey(nick)]
        if snapId and checkerPlayerConnectedSafe(snapId) then return snapId end
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

-- Checker (admin HUD/catalog).
function checkerIsPauseMenuOpen()
    return isPauseMenuActive and isPauseMenuActive()
end

-- Checker (admin HUD/catalog).
function checkerIsSuspended()
    if checkerIsPauseMenuOpen() then return true end
    if isGamePaused and isGamePaused() then return true end
    return false
end

-- Find Catalog Admin
local function findCatalogAdmin(nick)
    return Catalog.getAdmin(nick)
end

-- Find Catalog Leader
local function findCatalogLeader(nick)
    return Catalog.getLeader(nick)
end

-- Find Catalog Friend
local function findCatalogFriend(nick)
    return Catalog.getFriend(nick)
end

-- Checker (admin HUD/catalog).
function checkerNormalizeNick(nick)
    nick = trim(stripTags(nick or ''))
    if nick == '' then return nil end
    local parsed = nick:match('^([%w][%w_]*)%[%d+%]')
    if parsed then return parsed end
    parsed = nick:match('^([%w][%w_]*)')
    return parsed or nick
end

-- Checker (admin HUD/catalog).
function checkerLeaderIsHidden(entry)
    if type(entry) ~= 'table' then return false end
    if checkerIsLeaderNickHidden(entry.nick) then return true end
    return entry.hidden == true
end

-- Checker (admin HUD/catalog).
function checkerLeaderShowRef(nick)
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

-- Checker (admin HUD/catalog).
function checkerSetLeaderHidden(nick, hidden)
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

-- Checker (admin HUD/catalog).
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

-- Checker (admin HUD/catalog).
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

-- Нормализация org/role для сопоставления (CP1251 из /leaders + UTF-8 из каталога).
local function cp1251Lower(s)
    if not s or s == '' then return '' end
    return (s:gsub('[\192-\223]', function(c)
        return string.char(c:byte() + 32)
    end):gsub('\168', '\184'))
end

local function checkerLeaderTextToMatch(s)
    s = trim(s or '')
    if s == '' then return '' end
    if type(isUtf8Text) == 'function' and isUtf8Text(s)
            and type(utf8ToCp1251) == 'function' then
        s = utf8ToCp1251(s)
    end
    s = cp1251Lower(s)
    return s:lower()
end

local function checkerLeaderOrgHaystack(entry)
    local org = checkerLeaderTextToMatch(entry and entry.org_name)
    local role = checkerLeaderTextToMatch(entry and entry.role)
    if org == '' and role == '' then return '' end
    if org == '' then return role end
    if role == '' then return org end
    return org .. ' ' .. role
end

local function checkerLeaderHayFind(hay, pattern)
    return hay ~= '' and hay:find(pattern, 1, true) ~= nil
end

-- Org id по org_name/role (не доверяем битому org из каталога).
function checkerResolveLeaderOrgId(entry)
    if not entry then return 0 end
    local hay = checkerLeaderOrgHaystack(entry)
    if hay == '' then
        local prev = math.floor(tonumber(entry.org) or 0)
        if prev >= ORG_GOV and prev <= ORG_MAFIA_MAX then return prev end
        return 0
    end

    -- Мафии (конкретные названия).
    if checkerLeaderHayFind(hay, 'yakuza') then
        return ORG_YAKUZA
    end
    if checkerLeaderHayFind(hay, 'cosa') or checkerLeaderHayFind(hay, 'nostra')
            or checkerLeaderHayFind(hay, 'la cosa') or checkerLeaderHayFind(hay, 'lcn') then
        return ORG_LCN
    end
    if checkerLeaderHayFind(hay, '\xF0\xF3\xF1\xF1\xEA')
            or checkerLeaderHayFind(hay, '\xF0\xF3\xF1\xF1\xE0\xFF \xEC\xE0\xF4') then
        return ORG_RMAF
    end

    -- Банды.
    if checkerLeaderHayFind(hay, 'grove') or checkerLeaderHayFind(hay, 'street') then
        return ORG_GROVE
    end
    if checkerLeaderHayFind(hay, 'ballas') then
        return ORG_BALLAS
    end
    if checkerLeaderHayFind(hay, 'vagos') or checkerLeaderHayFind(hay, 'los santos vagos') then
        return ORG_VAGOS
    end
    if checkerLeaderHayFind(hay, 'aztecas') or checkerLeaderHayFind(hay, 'varios los') then
        return ORG_AZTECAS
    end
    if checkerLeaderHayFind(hay, 'rifa') or checkerLeaderHayFind(hay, 'the rifa') then
        return ORG_RIFA
    end

    -- МВД (до правительства: «министерство внутренних» не gov).
    if checkerLeaderHayFind(hay, '\xEC\xE2\xE4')
            or checkerLeaderHayFind(hay, '\xEF\xEE\xEB\xE8\xF6')
            or checkerLeaderHayFind(hay, 'police')
            or checkerLeaderHayFind(hay, '\xF4\xE1\xF0')
            or checkerLeaderHayFind(hay, '\xF4\xE5\xE4\xE5\xF0\xE0\xEB\xFC\xED')
            or checkerLeaderHayFind(hay, '\xE1\xFE\xF0\xEE \xF0\xE0\xF1\xF1\xEB\xE5\xE4')
            or checkerLeaderHayFind(hay, '\xF3\xEF\xF0\xE0\xE2\xEB\xE5\xED\xE8\xE5 \xEF\xEE\xEB\xE8\xF6')
            or checkerLeaderHayFind(hay, '\xEC\xE8\xED\xE8\xF1\xF2\xE5\xF0\xF1\xF2\xE2\xEE \xE2\xED\xF3\xF2\xF0\xE5\xED\xED\xE8\xF5')
            or checkerLeaderHayFind(hay, '\xE2\xED\xF3\xF2\xF0\xE5\xED\xED\xE8\xF5 \xE4\xE5\xEB') then
        return ORG_MVD
    end

    -- МО.
    if checkerLeaderHayFind(hay, '\xEC\xE8\xED\xE8\xF1\xF2\xE5\xF0\xF1\xF2\xE2\xEE \xEE\xE1\xEE\xF0\xEE\xED')
            or checkerLeaderHayFind(hay, '\xEE\xE1\xEE\xF0\xEE\xED')
            or checkerLeaderHayFind(hay, '\xF1\xF3\xF5\xEE\xEF\xF3\xF2')
            or checkerLeaderHayFind(hay, '\xE2\xE2\xF1')
            or checkerLeaderHayFind(hay, '\xE2\xEE\xE7\xE4\xF3\xF8')
            or checkerLeaderHayFind(hay, '\xF4\xEB\xEE\xF2')
            or checkerLeaderHayFind(hay, '\xEC\xEE\xF0\xF1\xEA')
            or checkerLeaderHayFind(hay, '\xE2\xEE\xE5\xED')
            or checkerLeaderHayFind(hay, 'army')
            or checkerLeaderHayFind(hay, 'ranger')
            or checkerLeaderHayFind(hay, '\xF0\xE5\xE9\xED\xE4\xE6')
            or checkerLeaderHayFind(hay, '\xE0\xF0\xEC\xE8') then
        return ORG_MO
    end

    -- МЗ (+ больницы LS/SF/LV с разными названиями).
    if checkerLeaderHayFind(hay, '\xE7\xE4\xF0\xE0\xE2\xEE\xEE\xF5\xF0\xE0\xED')
            or checkerLeaderHayFind(hay, '\xEC\xE3\xEC\xF6')
            or checkerLeaderHayFind(hay, '\xEA\xEB\xE8\xED\xE8\xF7')
            or checkerLeaderHayFind(hay, '\xEA\xEF\xF5')
            or checkerLeaderHayFind(hay, '\xE1\xEE\xEB\xFC\xED\xE8\xF6')
            or checkerLeaderHayFind(hay, 'hospital')
            or checkerLeaderHayFind(hay, '\xEC\xE8\xED\xE8\xF1\xF2\xF0 \xE7\xE4\xF0\xE0\xE2')
            or checkerLeaderHayFind(hay, '\xEC\xE8\xED\xE8\xF1\xF2\xF0 \xE7\xE4\xF0\xE0\xE2\xEE\xEE\xF5\xF0\xE0\xED') then
        return ORG_MZ
    end

    -- СМИ.
    if checkerLeaderHayFind(hay, '\xF0\xE0\xE4\xE8\xEE')
            or checkerLeaderHayFind(hay, '\xF2\xE5\xEB\xE5\xE2\xE8\xE7')
            or checkerLeaderHayFind(hay, '\xF1\xEC\xE8')
            or checkerLeaderHayFind(hay, '\xF1\xE2\xFF\xE7\xE8')
            or checkerLeaderHayFind(hay, '\xEA\xEE\xEC\xEC\xF3\xED\xE8\xEA\xE0\xF6')
            or checkerLeaderHayFind(hay, '\xF2\xE5\xEB\xE5\xF6\xE5\xED\xF2\xF0')
            or checkerLeaderHayFind(hay, '\xEC\xE8\xED.\xF1\xE2\xFF\xE7\xE8')
            or checkerLeaderHayFind(hay, '\xEC\xE8\xED \xF1\xE2\xFF\xE7\xE8') then
        return ORG_SMI
    end

    -- Правительство.
    if checkerLeaderHayFind(hay, '\xEF\xF0\xE5\xE7\xE8\xE4\xE5\xED\xF2')
            or checkerLeaderHayFind(hay, '\xE3\xF3\xE1\xE5\xF0\xED\xE0\xF2\xEE\xF0')
            or checkerLeaderHayFind(hay, '\xEF\xF0\xE0\xE2\xE8\xF2\xE5\xEB\xFC\xF1\xF2\xE2')
            or checkerLeaderHayFind(hay, '\xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF6\xE8\xFF \xEF\xF0\xE5\xE7\xE8\xE4\xE5\xED\xF2')
            or checkerLeaderHayFind(hay, '\xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF6\xE8\xFF \xE3\xF3\xE1\xE5\xF0\xED\xE0\xF2\xEE\xF0') then
        return ORG_GOV
    end

    local prev = math.floor(tonumber(entry.org) or 0)
    if prev >= ORG_GOV and prev <= ORG_MAFIA_MAX then return prev end
    return 0
end

function checkerInferLeaderOrgId(entry)
    return checkerResolveLeaderOrgId(entry)
end

-- Checker (admin HUD/catalog).
function checkerLeaderDisplayRole(entry)
    local role = trim(entry.role or '')
    if role ~= '' then
        if checkerLeaderStatusOnline(role) ~= nil then
            role = ''
        else
            role = role:gsub('^%[%d+%]%s*', '')
            role = role:gsub('^LV%s*[%•%-%·]%s*', ''):gsub('^LS%s*|%s*', ''):gsub('^SF%s*|%s*', '')
            role = role:gsub('^LV%s*[%-–—]%s*', '')
        end
    end
    if role ~= '' then return role end
    local org = trim(entry.org_name or '')
    if org ~= '' and checkerLeaderStatusOnline(org) == nil then
        return org
    end
    return ''
end

-- Checker (admin HUD/catalog).
function checkerLeaderSettingsStats(entries)
    local total, visible, online = 0, 0, 0
    for _, e in ipairs(entries or {}) do
        total = total + 1
        if not checkerLeaderIsHidden(e) then visible = visible + 1 end
        if checkerPlayerConnectedSafe(e.id) then online = online + 1 end
    end
    return total, visible, online
end

local function checkerLeaderFilterMatch(entry, flt)
    flt = checkerLeaderTextToMatch(flt)
    if flt == '' then return true end
    local nick = checkerLeaderTextToMatch(entry and entry.nick)
    local org = checkerLeaderTextToMatch(entry and entry.org_name)
    local role = checkerLeaderTextToMatch(entry and entry.role)
    local hay = nick .. ' ' .. org .. ' ' .. role
    return hay:find(flt, 1, true) ~= nil
end

-- Checker (admin HUD/catalog).
function checkerLeaderSubline(entry)
    local org = trim(entry.org_name or '')
    local role = checkerLeaderDisplayRole(entry)
    if org ~= '' and role ~= '' and org ~= role then return org .. '  \xB7  ' .. role end
    if org ~= '' then return org end
    if role ~= '' then return role end
    return ''
end

-- Ключ фракции лидера для группировки в настройках.
function checkerLeaderFactionKey(entry)
    local org = checkerResolveLeaderOrgId(entry)
    if org == ORG_GOV then return 'gov' end
    if org == ORG_MVD then return 'mvd' end
    if org == ORG_MO then return 'mo' end
    if org == ORG_MZ then return 'mz' end
    if org == ORG_SMI then return 'smi' end
    if org >= ORG_BAND and org <= ORG_BAND_MAX then return 'band' end
    if org >= ORG_MAFIA and org <= ORG_MAFIA_MAX then return 'mafia' end
    return 'other'
end

-- Checker (admin HUD/catalog).
function checkerLeaderFactionMeta(factionKey)
    return CHECKER_LEADER_FACTION_META[factionKey] or CHECKER_LEADER_FACTION_META.other
end

-- Clist-цвет организации (offline / заголовки секций).
function checkerLeaderOrgClistColor(orgId)
    orgId = math.floor(tonumber(orgId) or 0)
    return CHECKER_ORG_CLIST_COLOR[orgId] or CHECKER_ORG_CLIST_COLOR[0]
end

local function checkerDimNickColor(c, visible)
    if not c or c.x == nil then
        c = col_muted2
    end
    if not c or c.x == nil then
        return imgui.ImVec4(0.55, 0.55, 0.60, 1.0)
    end
    if visible == false then
        return imgui.ImVec4(c.x * 0.55, c.y * 0.55, c.z * 0.55, 0.72)
    end
    return c
end

-- Checker (admin HUD/catalog).
function checkerLeaderFactionClistImColor(factionKey, visible)
    local meta = checkerLeaderFactionMeta(factionKey)
    if meta and meta.neutralHeader then
        return checkerDimNickColor(col_muted2, visible)
    end
    local samp = checkerLeaderOrgClistColor(meta and meta.clistOrg or 0)
    local c = checkerSampColorToImVec4(samp) or col_muted2
    return checkerDimNickColor(c, visible)
end

-- Checker (admin HUD/catalog).
function checkerLeaderNickColor(entry, visible)
    local id = entry and (entry.id or checkerLookupOnlineId(entry.nick))
    if id and checkerPlayerConnectedSafe(id) then
        local live = checkerSafePlayerColor(id)
        if live then return checkerDimNickColor(live, visible) end
    end
    local org = checkerResolveLeaderOrgId(entry)
    local c = checkerSampColorToImVec4(checkerLeaderOrgClistColor(org)) or col_accent
    return checkerDimNickColor(c, visible)
end

-- Checker (admin HUD/catalog).
function checkerLeaderFactionColor(entry, visible)
    return checkerLeaderNickColor(entry, visible)
end

local CHECKER_LEADER_SECTION_ORDER = { 'gov', 'mo', 'mz', 'illegal', 'mvd', 'smi', 'other' }

-- Checker (admin HUD/catalog).
function checkerBuildLeaderFactionGroups(list)
    local groups, seen = {}, {}
    for _, e in ipairs(list or {}) do
        local fk = checkerLeaderFactionKey(e)
        if not groups[fk] then groups[fk] = {} end
        groups[fk][#groups[fk] + 1] = e
        seen[fk] = true
    end
    for fk, entries in pairs(groups) do
        table.sort(entries, function(a, b) return (a.nick or '') < (b.nick or '') end)
    end
    local order = {}
    for _, key in ipairs(CHECKER_LEADER_SECTION_ORDER) do
        if key == 'illegal' then
            if (seen.band and groups.band and #groups.band > 0)
                    or (seen.mafia and groups.mafia and #groups.mafia > 0) then
                order[#order + 1] = 'illegal'
            end
        elseif seen[key] and groups[key] and #groups[key] > 0 then
            order[#order + 1] = key
        end
    end
    return order, groups
end

-- Catalog Has Any
local function catalogHasAny()
    ensureCheckerCatalog()
    return #checkerCatalog.admins + #checkerCatalog.leaders + #checkerCatalog.friends > 0
end

-- Checker (admin HUD/catalog).
function checkerTopAdminList()
    local list, seen = {}, {}
    for _, nick in ipairs(CHECKER_TOP_ADMIN_DEFAULTS) do
        nick = trim(nick or '')
        local key = nickKey(nick)
        if nick ~= '' and key ~= '' and not seen[key] then
            seen[key] = true
            list[#list + 1] = nick
        end
    end
    ensureCheckerSettings()
    local cfg = settings.checker_top_admins
    if type(cfg) == 'table' then
        for _, raw in ipairs(cfg) do
            local nick = type(raw) == 'table' and trim(raw.nick or '') or trim(tostring(raw or ''))
            local key = nickKey(nick)
            if nick ~= '' and key ~= '' and not seen[key] then
                seen[key] = true
                list[#list + 1] = nick
            end
        end
    end
    return list
end

-- Checker (admin HUD/catalog).
function checkerIsTopAdmin(nick)
    local key = nickKey(nick)
    if key == '' then return false end
    for _, n in ipairs(checkerTopAdminList()) do
        if nickKey(n) == key then return true end
    end
    return false
end

-- Checker (admin HUD/catalog).
function checkerAdminEntrySortKey(e)
    if e and checkerIsTopAdmin(e.nick) then return 3000 end
    return checkerAdminSortKey(e and e.level)
end

-- Checker (admin HUD/catalog).
function checkerIsChiefLevel(level)
    level = math.floor(tonumber(level) or 0)
    return level == CHECKER_LVL_CHIEF_GA or level == CHECKER_LVL_CHIEF_ZGA
end

-- Checker (admin HUD/catalog): допустимые уровни каталога (1–7, S1–S9, ГА/ЗГА).
function checkerIsValidAdminLevel(level)
    level = math.floor(tonumber(level) or 0)
    if level >= ADMIN_LEVEL_1 and level <= ADMIN_LEVEL_7 then return true end
    if checkerIsSpecialLevel(level) then return true end
    if checkerIsChiefLevel(level) then return true end
    return false
end

-- Checker (admin HUD/catalog): ранг в роли лидера ([10] Padrone) не должен попадать в admins.
function checkerLeaderRoleConflictsAdminLevel(nick, level)
    local leader = Catalog.getLeader(nick)
    if not leader then return false end
    level = math.floor(tonumber(level) or 0)
    local role = trim(leader.role or '')
    local rank = role:match('%[(%d+)%]')
    if not rank then return false end
    return math.floor(tonumber(rank) or 0) == level
end

-- Checker (admin HUD/catalog): не понижать S/chief до обычного lvl из чата/promote.
function checkerShouldApplyAdminLevelUpdate(oldLevel, newLevel)
    oldLevel = math.floor(tonumber(oldLevel) or 0)
    newLevel = math.floor(tonumber(newLevel) or 0)
    if not checkerIsValidAdminLevel(newLevel) then return false end
    if checkerIsChiefLevel(oldLevel) and not checkerIsChiefLevel(newLevel) then return false end
    if checkerIsSpecialLevel(oldLevel)
            and not checkerIsSpecialLevel(newLevel)
            and not checkerIsChiefLevel(newLevel) then
        return false
    end
    return true
end

-- Checker (admin HUD/catalog).
function checkerChiefList()
    local list, seen = {}, {}
    for _, e in ipairs(CHECKER_CHIEF_DEFAULTS) do
        local key = nickKey(e.nick)
        if key ~= '' and not seen[key] then
            seen[key] = true
            list[#list + 1] = { nick = e.nick, level = e.level }
        end
    end
    ensureCheckerSettings()
    local cfg = settings.checker_chief_admins
    if type(cfg) == 'table' then
        for _, raw in ipairs(cfg) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                local key = nickKey(raw.nick)
                if key ~= '' then
                    local lv = math.floor(tonumber(raw.level) or CHECKER_LVL_CHIEF_GA)
                    if lv ~= CHECKER_LVL_CHIEF_GA and lv ~= CHECKER_LVL_CHIEF_ZGA then
                        lv = CHECKER_LVL_CHIEF_GA
                    end
                    if not seen[key] then
                        seen[key] = true
                        list[#list + 1] = { nick = trim(raw.nick), level = lv }
                    else
                        for _, e in ipairs(list) do
                            if nickKey(e.nick) == key then
                                e.level = lv
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return list
end

-- Checker (admin HUD/catalog).
function checkerResolveChief(nick)
    local key = nickKey(nick)
    if key == '' then return nil end
    for _, e in ipairs(checkerChiefList()) do
        if nickKey(e.nick) == key then return e end
    end
    return nil
end

-- Checker (admin HUD/catalog).
function checkerEffectiveAdminLevel(nick, level)
    local chief = checkerResolveChief(nick)
    if chief then return chief.level end
    return math.floor(tonumber(level) or 0)
end

-- Checker (admin HUD/catalog).
function checkerAdminSortKey(level)
    level = math.floor(tonumber(level) or 0)
    if level == CHECKER_LVL_CHIEF_GA then return 1000 end
    if level == CHECKER_LVL_CHIEF_ZGA then return 999 end
    if checkerIsChiefLevel(level) then return 998 end
    if level >= CHECKER_LVL_SPECIAL_BASE and level < CHECKER_LVL_CHIEF_BASE then
        return 500 + checkerSpecialLevelNum(level)
    end
    return level
end

-- Checker (admin HUD/catalog).
function checkerIsSpecialLevel(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsChiefLevel(level) then return false end
    return level >= CHECKER_LVL_SPECIAL_BASE and level < CHECKER_LVL_CHIEF_BASE
end

-- Checker (admin HUD/catalog).
function checkerSpecialLevelNum(level)
    level = math.floor(tonumber(level) or 0)
    if level < CHECKER_LVL_SPECIAL_BASE then return 0 end
    return level - CHECKER_LVL_SPECIAL_BASE
end

-- Checker (admin HUD/catalog).
function checkerAdminColorHex(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsChiefLevel(level) then
        return CHECKER_CHIEF_COLOR_HEX[level] or 'E8E8E8'
    end
    if checkerIsSpecialLevel(level) then
        local sn = checkerSpecialLevelNum(level)
        if sn == 1 then return 'FA945F' end
        if sn == 2 then return 'F0B838' end
        if sn == 3 then return '52D1AD' end
        return 'E8E8E8'
    end
    local map = {
        [7] = 'FF1414', [6] = '36BA0F', [5] = '30F87A', [4] = '426EED',
        [3] = 'A63BD9', [2] = '00BFFF', [1] = '00BFFF',
    }
    return map[level] or 'E8E8E8'
end

-- Checker (admin HUD/catalog).
function checkerAdminColor(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsChiefLevel(level) then
        return CHECKER_CHIEF_COLOR[level] or imgui.ImVec4(0.35, 0.85, 0.40, 1.0)
    end
    if checkerIsSpecialLevel(level) then
        return CHECKER_SPECIAL_COLOR[checkerSpecialLevelNum(level)]
            or imgui.ImVec4(0.92, 0.88, 0.78, 1.0)
    end
    return CHECKER_ADMIN_COLOR[level] or col_label or imgui.ImVec4(0.92, 0.88, 0.96, 1.0)
end

-- Checker (admin HUD/catalog).
function checkerFormatNickColored(nick, level)
    nick = nick or ''
    return string.format('{%s}%s{E8E8E8}', checkerAdminColorHex(level), nick)
end

-- Checker (admin HUD/catalog).
function checkerParseAdminLevel(lvlStr)
    return Parser.parseAdminLevel(lvlStr)
end

-- Checker (admin HUD/catalog).
function checkerFormatAdminLevelDisplay(level, nick)
    if nick and checkerIsTopAdmin(nick) then return '' end
    level = math.floor(tonumber(level) or 0)
    if checkerIsChiefLevel(level) then
        return CHECKER_CHIEF_TAG[level] or ''
    end
    if checkerIsSpecialLevel(level) then
        return 'S' .. tostring(checkerSpecialLevelNum(level))
    end
    if level > 0 then
        return string.format('lvl %i', level)
    end
    return ''
end

-- Checker (admin HUD/catalog).
function checkerSplitAdminLists(list)
    local executive, regular, special = {}, {}, {}
    for _, e in ipairs(list or {}) do
        if type(e) ~= 'table' then goto continue end
        if checkerIsSpecialLevel(e.level) then
            special[#special + 1] = e
        elseif checkerIsChiefLevel(e.level) or checkerIsTopAdmin(e.nick) then
            executive[#executive + 1] = e
        else
            regular[#regular + 1] = e
        end
        ::continue::
    end
    table.sort(executive, function(a, b)
        if type(a) ~= 'table' then return false end
        if type(b) ~= 'table' then return true end
        local aChief = checkerIsChiefLevel(a.level)
        local bChief = checkerIsChiefLevel(b.level)
        if aChief and not bChief then return true end
        if bChief and not aChief then return false end
        if aChief and bChief then
            local ka = checkerAdminSortKey(a.level)
            local kb = checkerAdminSortKey(b.level)
            if ka ~= kb then return ka > kb end
        end
        return (a.nick or '') < (b.nick or '')
    end)
    table.sort(regular, function(a, b)
        if type(a) ~= 'table' then return false end
        if type(b) ~= 'table' then return true end
        local ka = checkerAdminSortKey(a.level)
        local kb = checkerAdminSortKey(b.level)
        if ka ~= kb then return ka > kb end
        return (a.nick or '') < (b.nick or '')
    end)
    table.sort(special, function(a, b)
        if type(a) ~= 'table' then return false end
        if type(b) ~= 'table' then return true end
        local ka = checkerSpecialLevelNum(a.level)
        local kb = checkerSpecialLevelNum(b.level)
        if ka ~= kb then return ka > kb end
        return (a.nick or '') < (b.nick or '')
    end)
    return executive, regular, special
end

-- Нормализация и парсинг admin-строк — lib/report_desk_checker_parser.lua (Parser).

-- Checker (admin HUD/catalog).
function checkerParserOpts()
    return {
        resolveChief = checkerResolveChief,
        effectiveLevel = checkerEffectiveAdminLevel,
        isValidLevel = checkerIsValidAdminLevel,
        splitCols = checkerLeadersSplitCols,
        isAdminsHeaderRow = checkerIsAdminsHeaderRow,
    }
end

-- Checker (admin HUD/catalog).
function checkerParseAdminsDialog(text, style)
    return Parser.parseAdminsDialog(text, style, checkerParserOpts())
end

-- Checker (admin HUD/catalog).
function checkerLogAdmsParseFailure(title, style, text)
    local snippet = stripTags(text or ''):gsub('\r', ''):gsub('\n', ' ')
    if #snippet > CHECKER_ADMS_PARSE_DUMP_LEN then
        snippet = snippet:sub(1, CHECKER_ADMS_PARSE_DUMP_LEN) .. '...'
    end
    print(string.format(
        '[Report Desk] checker: adms dialog 0 parsed (style=%s title=%s) sample=%s',
        tostring(style),
        tostring(stripTags(title or '')),
        snippet
    ))
end

-- Checker (admin HUD/catalog).
function checkerLeadersSplitCols(line)
    local cols = {}
    for col in (line .. '\t'):gmatch('([^\t]*)\t') do
        cols[#cols + 1] = trim(stripTags(col))
    end
    return cols
end

-- true/false/nil — распознать «Онлайн»/«Оффлайн» в колонке статуса (CP1251 + latin).
function checkerLeaderStatusOnline(status)
    local s = checkerLeaderTextToMatch(status or '')
    if s == '' then return nil end
    if s:find('online', 1, true) or s:find('\xEE\xED\xEB\xE0\xE9\xED', 1, true) then
        return true
    end
    if s:find('offline', 1, true) or s:find('\xEE\xF4\xF4\xE0\xE9\xED', 1, true)
            or s:find('\xEE\xF4\xE8\xE0\xE9\xED', 1, true) then
        return false
    end
    return nil
end

local function checkerLeaderNormalizeCols(cols)
    local name = trim(cols[1] or '')
    local org = trim(cols[2] or '')
    local role = trim(cols[3] or '')
    local status = trim(cols[4] or '')
    if status == '' and role ~= '' and checkerLeaderStatusOnline(role) ~= nil then
        status = role
        role = ''
    end
    if status == '' and cols[5] and trim(cols[5]) ~= '' then
        status = trim(cols[5])
    end
    if role ~= '' and checkerLeaderStatusOnline(role) ~= nil then
        if status == '' then status = role end
        role = ''
    end
    return name, org, role, status
end

-- Checker (admin HUD/catalog).
function checkerIsLeadersHeaderRow(cols)
    local c1 = cols[1] or ''
    return c1:find('\xC8\xEC\xFF', 1, true) ~= nil
        or c1:find('\xCE\xF0\xE3\xE0\xED', 1, true) ~= nil
end

-- Checker (admin HUD/catalog).
function checkerParseLeadersDialog(text, style)
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
            local name, org, role, status = checkerLeaderNormalizeCols(cols)
            if name ~= '' then
                rows[#rows + 1] = {
                    name = name,
                    org = org,
                    role = role,
                    status = status,
                }
            end
        end
    end
    return headers, rows
end

-- Checker (admin HUD/catalog).
function checkerDialogLooksLikeLeaders(text, style)
    if not checkerIsTableDialogStyle(style) then return false end
    local _, rows = checkerParseLeadersDialog(text, style)
    return #rows > 0
end

-- Checker (admin HUD/catalog).
function checkerIsLeadersDialog(title)
    local tit = stripTags(title or '')
    if tit:find(L_LEADERS, 1, true) then return true end
    if tit:find('\xEB\xE8\xE4\xE5\xF0', 1, true) then return true end
    if tit:lower():find('leaders', 1, true) then return true end
    return false
end

-- Checker (admin HUD/catalog).
function checkerIsAdminsDialog(title)
    local tit = stripTags(title or '')
    if tit:find(L_ADMINS_ONLINE, 1, true) then return true end
    if tit:find(L_ADMIN_WORD, 1, true) and not tit:find('\xEE\xED\xEB\xE0\xE9\xED', 1, true) then
        return true
    end
    if tit:find('\xC0\xE4\xEC\xE8\xED', 1, true) and not tit:find('\xEE\xED\xEB\xE0\xE9\xED', 1, true) then
        return true
    end
    if tit:lower():find('adms', 1, true) then return true end
    return false
end

-- Checker (admin HUD/catalog).
function checkerDialogLooksLikeAdmins(text, style)
    style = tonumber(style) or -1
    if checkerIsTableDialogStyle(style) then
        return #checkerParseAdminsDialog(text, style) > 0
    end
    local plain = stripTags(text or '')
    if plain == '' then return false end
    for line in plain:gmatch('[^\r\n]+') do
        if Parser.parseAdminEntry(line, checkerParserOpts()) then return true end
    end
    return false
end

-- Checker (admin HUD/catalog).
function checkerIsAdminsHeaderRow(cols)
    local c1 = trim(cols[1] or '')
    return c1:find(L_ADMIN_WORD, 1, true) ~= nil
        or c1:find('\xC8\xEC\xFF', 1, true) ~= nil
        or c1:find('\xCD\xE8\xEA', 1, true) ~= nil
        or c1:find('\xD3\xF0\xEE\xE2', 1, true) ~= nil
        or c1:find('\xD1\xF2\xE0\xF2', 1, true) ~= nil
end

-- Checker (admin HUD/catalog).
function checkerSortCatalogAdmins(list)
    table.sort(list, function(a, b)
        if type(a) ~= 'table' then return false end
        if type(b) ~= 'table' then return true end
        local ka = checkerAdminSortKey(a.level)
        local kb = checkerAdminSortKey(b.level)
        if ka ~= kb then return ka > kb end
        return (a.nick or '') < (b.nick or '')
    end)
end

-- Checker (admin HUD/catalog).
function checkerEnsureChiefCatalog()
    ensureCheckerCatalog()
    local changed = false
    for _, chief in ipairs(checkerChiefList()) do
        local ex = Catalog.getAdmin(chief.nick)
        if not ex then
            checkerCatalog.admins[#checkerCatalog.admins + 1] = {
                nick = chief.nick,
                level = chief.level,
            }
            changed = true
        elseif math.floor(tonumber(ex.level) or 0) ~= chief.level then
            ex.level = chief.level
            changed = true
        end
    end
    if changed then
        checkerSortCatalogAdmins(checkerCatalog.admins)
        checkerMarkCatalogDirty()
    end
    return changed
end

-- Checker (admin HUD/catalog).
function checkerMergeChiefCatalog(list)
    for _, chief in ipairs(checkerChiefList()) do
        local found = false
        for _, e in ipairs(list) do
            if nickKey(e.nick) == nickKey(chief.nick) then
                e.level = chief.level
                found = true
                break
            end
        end
        if not found then
            list[#list + 1] = { nick = chief.nick, level = chief.level }
        end
    end
    return list
end

-- Checker (admin HUD/catalog).
function checkerMergeAdminsIntoCatalog(list)
    ensureCheckerCatalog()
    local changed = false
    for _, e in ipairs(list or {}) do
        local nick = trim(e.nick or '')
        if nick ~= '' then
            local lv = checkerEffectiveAdminLevel(nick, e.level)
            if not checkerIsValidAdminLevel(lv) then goto continue end
            if checkerLeaderRoleConflictsAdminLevel(nick, lv) then goto continue end
            local ex = Catalog.getAdmin(nick)
            if ex then
                local old = math.floor(tonumber(ex.level) or 0)
                if old ~= lv then
                    if checkerShouldApplyAdminLevelUpdate(old, lv) then
                        ex.level = lv
                        changed = true
                    end
                end
            else
                checkerCatalog.admins[#checkerCatalog.admins + 1] = {
                    nick = nick,
                    level = lv,
                }
                changed = true
            end
        end
        ::continue::
    end
    checkerMergeChiefCatalog(checkerCatalog.admins)
    checkerSortCatalogAdmins(checkerCatalog.admins)
    return changed
end

-- Checker (admin HUD/catalog).
function checkerApplyAdmsOnlineSnapshot(parsedList)
    local byNick, byId = {}, {}
    for _, e in ipairs(parsedList or {}) do
        local nick = trim(e.nick or '')
        local id = tonumber(e.id)
        if nick ~= '' and id and checkerPlayerConnectedSafe(id) then
            byNick[nickKey(nick)] = id
            byId[id] = {
                nick = nick,
                level = checkerEffectiveAdminLevel(nick, e.level),
            }
            checkerIndexOnePlayer(id, nick)
            local lv = byId[id].level
            if not Catalog.getAdmin(nick)
                    and checkerIsValidAdminLevel(lv)
                    and not checkerLeaderRoleConflictsAdminLevel(nick, lv) then
                checkerCatalog.admins[#checkerCatalog.admins + 1] = {
                    nick = nick,
                    level = lv,
                }
                checkerMarkCatalogDirty()
            end
        end
    end
    checkerMergeChiefCatalog(checkerCatalog.admins)
    checkerSortCatalogAdmins(checkerCatalog.admins)
    checkerState.admsOnlineSnapshot = {
        byNick = byNick,
        byId = byId,
        at = os.clock(),
    }
end

-- Checker (admin HUD/catalog).
function checkerApplyAdminsDialogSync(list)
    if not list or #list == 0 then return false end
    ensureCheckerCatalog()
    local before = #checkerCatalog.admins
    local changed = checkerMergeAdminsIntoCatalog(list)
    if not changed and #list > 0 then
        changed = true
    end
    checkerState.syncInFlight = false
    local now = os.clock()
    checkerState.admsDialogSyncedAt = now
    checkerState.admsChatMuteUntil = now + CHECKER_ADMS_DIALOG_CHAT_GUARD_SEC
    if changed then checkerMarkCatalogDirty() end
    checkerSanitizeAdminCatalog()
    checkerApplyAdmsOnlineSnapshot(list)
    SafeCall('rebuildOnlineAfterAdms', checkerRebuildOnline, true)
    print(string.format('[Report Desk] checker: dialog sync %d admins (merge, catalog %d -> %d)',
        #list, before, #checkerCatalog.admins))
    return true
end

-- Checker (admin HUD/catalog).
function checkerApplyLeadersOnlineSnapshot(rows)
    ensureCheckerCatalog()
    checkerEnsureNickIndex(true)
    local list = {}
    for _, r in ipairs(rows or {}) do
        local nick = trim(stripTags(r.name or ''))
        if nick == '' then goto continue end
        if checkerLeaderStatusOnline(r.status) ~= true then goto continue end
        local cat = Catalog.getLeader(nick)
        if cat and checkerLeaderIsHidden(cat) then goto continue end
        local id = checkerLookupOnlineId(nick)
        if not id then goto continue end
        local orgName = trim(stripTags(r.org or ''))
        local role = trim(stripTags(r.role or ''))
        if orgName == '' and cat then orgName = trim(cat.org_name or '') end
        if role == '' and cat then role = trim(cat.role or '') end
        if checkerLeaderStatusOnline(role) ~= nil then role = '' end
        local entry = {
            id = id,
            nick = checkerSafeNick(id, nick),
            org = checkerResolveLeaderOrgId({ org_name = orgName, role = role, org = cat and cat.org }),
            org_name = orgName,
            role = role,
        }
        list[#list + 1] = entry
        ::continue::
    end
    table.sort(list, function(a, b) return (a.nick or '') < (b.nick or '') end)
    checkerState.leadersOnlineSnapshot = {
        list = list,
        at = os.clock(),
    }
end

local function checkerLeadersFromSnapshot()
    local snap = checkerState.leadersOnlineSnapshot
    if type(snap) ~= 'table' or type(snap.list) ~= 'table' then return nil end
    local at = tonumber(snap.at) or 0
    if at <= 0 or os.clock() - at > CHECKER_LEADERS_SNAPSHOT_MAX_AGE then return nil end
    local out = {}
    for _, e in ipairs(snap.list) do
        if e and e.nick then
            local id = tonumber(e.id) or checkerLookupOnlineId(e.nick)
            if id and checkerPlayerConnectedSafe(id) then
                local cat = Catalog.getLeader(e.nick)
                if cat and checkerLeaderIsHidden(cat) then goto continue end
                local prev = OnlineIndex.getById('leader', id)
                out[#out + 1] = {
                    id = id,
                    nick = checkerSafeNick(id, e.nick),
                    org = tonumber(e.org) or 0,
                    org_name = e.org_name or '',
                    role = e.role or '',
                    afk = prev and prev.afk or checkerPlayerAfk(id),
                }
            end
        end
        ::continue::
    end
    return out
end

-- Checker (admin HUD/catalog).
function checkerApplyLeadersSync(rows)
    if not rows or #rows == 0 then
        checkerLog('leaders parse returned empty — catalog NOT replaced')
        return false
    end
    ensureCheckerCatalog()
    local prevCount = #checkerCatalog.leaders
    if prevCount > 0 and #rows < math.max(3, math.floor(prevCount * 0.3)) then
        checkerLog(string.format('leaders list suspiciously short (%d vs %d), skipping',
            #rows, prevCount))
        return false
    end
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
                org = 0,
                org_name = orgName ~= '' and orgName or trim(prev and prev.org_name or ''),
                role = role ~= '' and role or trim(prev and prev.role or ''),
            }
            entry.org = checkerResolveLeaderOrgId(entry)
            if checkerIsLeaderNickHidden(nick) or (prev and prev.hidden == true) then
                entry.hidden = true
            end
            list[#list + 1] = entry
        end
    end
    table.sort(list, function(a, b) return (a.nick or '') < (b.nick or '') end)
    checkerCatalog.leaders = list
    checkerState.leaderShowUi = {}
    checkerState.leaderGroupShowUi = {}
    checkerMarkCatalogDirty()
    checkerApplyLeadersOnlineSnapshot(rows)
    checkerScheduleRebuild()
    SafeCall('rebuildOnlineAfterLeaders', checkerRebuildOnline, true)
    local onlineN = type(checkerState.leadersOnlineSnapshot) == 'table'
        and type(checkerState.leadersOnlineSnapshot.list) == 'table'
        and #checkerState.leadersOnlineSnapshot.list or 0
    print(string.format('[Report Desk] checker: dialog sync %d leaders (%d online)',
        #list, onlineN))
    return true
end

-- Checker (admin HUD/catalog).
function checkerResolveCloseButton(button1, button2)
    local b1 = trim(stripTags(button1 or ''))
    local b2 = trim(stripTags(button2 or ''))
    local closeWord = '\xC7\xE0\xEA\xF0\xFB\xF2\xFC'
    if b2:find(closeWord, 1, true) or b2:lower():find('close', 1, true) then return 0 end
    if b1:find(closeWord, 1, true) or b1:lower():find('close', 1, true) then return 1 end
    if b2 ~= '' then return 0 end
    if b1 ~= '' then return 1 end
    return 0
end

-- Checker (admin HUD/catalog).
function checkerIsTableDialogStyle(style)
    style = tonumber(style) or -1
    return style == 2 or style == 4 or style == 5
end

local SYNC_SESSION_KEY = '__desk_checkerSyncSession'
local CHECKER_SYNC_RESTORE_MAX_SEC = 90.0

local function checkerGetServerKey()
    if type(sampGetCurrentServerAddress) == 'function' then
        return sampGetCurrentServerAddress() or ''
    end
    if type(sampGetServerSettingsPtr) == 'function' then
        local ptr = sampGetServerSettingsPtr()
        if ptr and ptr ~= 0 then return tostring(ptr) end
    end
    return ''
end

local function checkerAdmsFlowIsOutbound()
    return checkerState.admsFlow == 'outbound'
end

local function checkerAdmsFlowIsActive(now)
    now = now or os.clock()
    return checkerState.admsFlow ~= nil and now < (checkerState.admsFlowUntil or 0)
end

local function checkerSyncServerKeyMismatch()
    local key = checkerState.syncServerKey
    if not key or key == '' then return false end
    return checkerGetServerKey() ~= key
end

local function ensureSyncSession()
    if type(checkerState.syncSession) ~= 'table' then
        checkerState.syncSession = {}
    end
    local s = checkerState.syncSession
    if s.admsUntil == nil then s.admsUntil = 0 end
    if s.leadersUntil == nil then s.leadersUntil = 0 end
    if s.spawnAdmsRetries == nil then s.spawnAdmsRetries = 0 end
    if s.lastAdmsResync == nil then s.lastAdmsResync = os.clock() end
    return s
end

local function checkerMarkSyncAdmsSession(untilAt)
    local s = ensureSyncSession()
    s.admsUntil = untilAt
    checkerPersistSyncSession()
end

function checkerBeginAdmsFlow(untilAt)
    checkerState.admsFlow = 'outbound'
    checkerState.admsFlowUntil = untilAt
    checkerState.syncServerKey = checkerGetServerKey()
    checkerMarkSyncAdmsSession(untilAt)
end

function checkerClearAdmsFlow()
    checkerState.admsFlow = nil
    checkerState.admsFlowUntil = 0
    checkerState.syncServerKey = ''
    checkerClearSyncAdms()
end

-- После /reload os.clock() сбрасывается — не восстанавливать «вечный» sync из _G.
function checkerSanitizeSyncSession()
    local s = ensureSyncSession()
    local now = os.clock()
    local function clampUntil(field)
        local v = tonumber(s[field]) or 0
        if v > now and (v - now) > CHECKER_SYNC_RESTORE_MAX_SEC then
            s[field] = 0
        end
    end
    clampUntil('admsUntil')
    clampUntil('leadersUntil')
    if (tonumber(s.admsUntil) or 0) <= now then
        if (checkerState.admsFlowUntil or 0) <= now
                or (checkerState.admsFlowUntil or 0) - now > CHECKER_SYNC_RESTORE_MAX_SEC then
            checkerState.admsFlow = nil
            checkerState.admsFlowUntil = 0
        end
    end
    if (tonumber(s.leadersUntil) or 0) <= now then
        if (checkerState.leadersFlowUntil or 0) <= now
                or (checkerState.leadersFlowUntil or 0) - now > CHECKER_SYNC_RESTORE_MAX_SEC then
            checkerState.leadersFlowUntil = 0
        end
    end
end

-- Checker (admin HUD/catalog).
function checkerPersistSyncSession()
    local s = ensureSyncSession()
    rawset(_G, SYNC_SESSION_KEY, {
        admsUntil = s.admsUntil,
        leadersUntil = s.leadersUntil,
        spawnAdmsRetries = s.spawnAdmsRetries,
    })
end

-- Checker (admin HUD/catalog).
function checkerRestoreSyncSession()
    local g = rawget(_G, SYNC_SESSION_KEY)
    if type(g) ~= 'table' then return end
    local s = ensureSyncSession()
    local now = os.clock()

    local function restoreUntil(field, applyFn)
        local untilAt = tonumber(g[field])
        if not untilAt or untilAt <= now then return end
        if untilAt - now > CHECKER_SYNC_RESTORE_MAX_SEC then return end
        s[field] = untilAt
        if type(applyFn) == 'function' then applyFn(untilAt) end
    end

    restoreUntil('admsUntil', function(untilAt)
        checkerState.admsFlow = 'outbound'
        checkerState.admsFlowUntil = untilAt
    end)
    restoreUntil('leadersUntil', function(untilAt)
        checkerState.leadersFlowUntil = untilAt
    end)
    s.spawnAdmsRetries = tonumber(g.spawnAdmsRetries) or s.spawnAdmsRetries
    checkerSanitizeSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerSyncAdmsActive(now)
    now = now or os.clock()
    local s = ensureSyncSession()
    return now < (s.admsUntil or 0) or checkerAdmsFlowIsActive(now)
end

-- Checker (admin HUD/catalog).
function checkerSyncLeadersActive(now)
    now = now or os.clock()
    local s = ensureSyncSession()
    return now < (s.leadersUntil or 0) or (checkerState.leadersFlowUntil or 0) > now
end

-- Checker (admin HUD/catalog).
function checkerMarkSyncAdms(untilAt)
    checkerMarkSyncAdmsSession(untilAt)
end

-- Checker (admin HUD/catalog).
function checkerMarkSyncLeaders(untilAt)
    local s = ensureSyncSession()
    s.leadersUntil = untilAt
    checkerState.leadersFlowUntil = untilAt
    checkerPersistSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerClearSyncAdms()
    local s = ensureSyncSession()
    s.admsUntil = 0
    checkerPersistSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerClearSyncLeaders()
    local s = ensureSyncSession()
    s.leadersUntil = 0
    checkerState.leadersFlowUntil = 0
    checkerState.leadersSyncOutbound = false
    if not checkerAdmsFlowIsOutbound() then
        checkerState.syncServerKey = ''
    end
    checkerPersistSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerClearPendingSyncDialogs()
    checkerClearAdmsFlow()
    checkerClearSyncLeaders()
end

-- Checker (admin HUD/catalog).
function checkerScheduleSpawnAdmsRetry()
    local s = ensureSyncSession()
    if #checkerCatalog.admins > 0 then
        if checkerState.spawnLeadersHandled then
            checkerState.spawnCatalogSyncDone = true
        else
            checkerState.spawnLeadersDueAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        end
        return
    end
    if s.spawnAdmsRetries >= CHECKER_SPAWN_ADMS_MAX_RETRIES then
        if #checkerCatalog.admins == 0 then
            print('[Report Desk] checker: /adms sync failed — catalog empty, use «Синхронизировать» in checker tab')
        else
            print('[Report Desk] checker: /adms sync failed after retries — using persisted catalog')
        end
        return
    end
    s.spawnAdmsRetries = s.spawnAdmsRetries + 1
    checkerState.spawnCatalogSyncDone = false
    checkerState.spawnAdmsHandled = false
    checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC * s.spawnAdmsRetries
    checkerPersistSyncSession()
    checkerLog(string.format('spawn /adms retry %d/%d', s.spawnAdmsRetries, CHECKER_SPAWN_ADMS_MAX_RETRIES))
end

-- Закрыть уже открытый диалог на клиенте (reload). Без sampSendDialogResponse — иначе краш.
function checkerCloseVisibleDialog(button1, button2)
    if type(sampIsDialogActive) ~= 'function' or not sampIsDialogActive() then
        return false
    end
    local btn = checkerResolveCloseButton(button1, button2)
    if type(sampCloseCurrentDialogWithButton) == 'function' then
        pcall(sampCloseCurrentDialogWithButton, btn)
    end
    if type(sampIsDialogActive) == 'function' and not sampIsDialogActive() then
        checkerClearPendingSyncDialogs()
    end
    return true
end

-- Checker (admin HUD/catalog).
function checkerDeferCloseVisibleDialog(button1, button2)
    checkerCloseVisibleDialog(button1, button2)
    if lua_thread and lua_thread.create then
        lua_thread.create(function()
            wait(120)
            checkerCloseVisibleDialog(button1, button2)
            wait(350)
            checkerCloseVisibleDialog(button1, button2)
        end)
    end
end

-- Checker (admin HUD/catalog).
function checkerClearSyncFlowFlags()
    checkerState.leadersFlowUntil = 0
end

-- После reload onShowDialog не приходит для уже открытого окна — только UI-close активного диалога.
function checkerDismissStaleSyncDialog()
    if type(sampIsDialogActive) ~= 'function' or not sampIsDialogActive() then
        checkerClearPendingSyncDialogs()
        return
    end
    if not checkerAdmsFlowIsOutbound() and not checkerState.leadersSyncOutbound then
        return
    end
    checkerDeferCloseVisibleDialog(nil, nil)
end

-- Закрытие sync-диалога перед unload/reload (checkerState при reload сбрасывается).
function checkerDismissOpenSyncDialogOnUnload()
    checkerDismissStaleSyncDialog()
end

-- Игнорировать echo /admins в чат (диалог — единственный источник при автосинхе).
function checkerIsAdmsChatMuted(now)
    now = now or os.clock()
    if checkerAdmsFlowIsActive(now) then return true end
    if now < (checkerState.admsChatMuteUntil or 0) then return true end
    return false
end

-- /admins в чат: только актуализировать уровень админа, который уже есть в каталоге.
function checkerRefreshAdminLevelFromChat(plain)
    if checkerState.admsDialogSyncedAt
        and checkerState.admsDialogSyncedAt > 0
        and (os.clock() - checkerState.admsDialogSyncedAt) < CHECKER_ADMS_DIALOG_CHAT_GUARD_SEC then
        return false
    end
    if Parser.isAdminsListNoise(plain) then return false end
    local nick, level = Parser.parseAdminLine(plain)
    if nick and not level then
        local chief = checkerResolveChief(nick)
        level = chief and chief.level or nil
    end
    if not nick or not level then return false end
    ensureCheckerCatalog()
    local ex = Catalog.getAdmin(nick)
    if not ex then return false end
    level = checkerEffectiveAdminLevel(nick, level)
    if not checkerIsValidAdminLevel(level) then return false end
    local old = math.floor(tonumber(ex.level) or 0)
    if old == level then return false end
    if not checkerShouldApplyAdminLevelUpdate(old, level) then return false end
    ex.level = level
    checkerSortCatalogAdmins(checkerCatalog.admins)
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    return true
end

-- Checker (admin HUD/catalog).
function checkerOnShowDialog(dialogId, style, title, button1, button2, text)
    local titleMatch = checkerIsAdminsDialog(title)
    local isAdminsDlg = titleMatch
        or (checkerAdmsFlowIsOutbound() and checkerDialogLooksLikeAdmins(text, style))
    local leadersTitleMatch = checkerIsLeadersDialog(title)
    local isLeadersDlg = leadersTitleMatch
        or (checkerState.leadersSyncOutbound and checkerDialogLooksLikeLeaders(text, style))

    if isAdminsDlg and checkerAdmsFlowIsOutbound() then
        if checkerSyncServerKeyMismatch() then return false end
        local list = checkerParseAdminsDialog(text, style)
        if #list > 0 then
            SafeCall('checkerApplyAdminsDialogSync', checkerApplyAdminsDialogSync, list)
            if checkerState.spawnCatalogSyncRunning then
                checkerState.spawnAdmsHandled = true
                ensureSyncSession().spawnAdmsRetries = 0
                checkerPersistSyncSession()
            end
        else
            checkerLogAdmsParseFailure(title, style, text)
            if checkerState.spawnCatalogSyncRunning then
                checkerState.spawnAdmsHandled = false
                checkerScheduleSpawnAdmsRetry()
            end
        end
        checkerClearAdmsFlow()
        if checkerState.spawnCatalogSyncRunning then
            checkerDeferCloseVisibleDialog(button1, button2)
        else
            checkerCloseVisibleDialog(button1, button2)
        end
        return true
    end

    if isLeadersDlg then
        local applied = false
        if checkerIsTableDialogStyle(style) then
            local _, rows = checkerParseLeadersDialog(text, style)
            if #rows > 0 then
                applied = SafeCall('checkerApplyLeadersSync', checkerApplyLeadersSync, rows) == true
            elseif checkerState.leadersSyncOutbound then
                checkerLog('sync /leaders dialog parse failed (0 rows)')
            end
        end
        if checkerState.leadersSyncOutbound then
            if checkerSyncServerKeyMismatch() then return false end
            if checkerState.spawnCatalogSyncRunning and applied then
                checkerState.spawnLeadersHandled = true
            end
            checkerClearSyncLeaders()
            if checkerState.spawnCatalogSyncRunning then
                checkerDeferCloseVisibleDialog(button1, button2)
            else
                checkerCloseVisibleDialog(button1, button2)
            end
            return true
        end
        return false
    end

    return false
end

-- Checker (admin HUD/catalog).
function checkerIsSyncBlocked()
    if checkerIsSuspended() then return true end
    if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then return true end
    if type(showWindow) == 'table' and showWindow[0] then return true end
    return false
end

-- Spawn catalog sync: не ждём произвольный диалог игрока — только pause и окно /reps.
function checkerIsSpawnCatalogSyncBlocked()
    if checkerIsSuspended() then return true end
    if type(showWindow) == 'table' and showWindow[0] then return true end
    return false
end

-- Checker (admin HUD/catalog).
function checkerWaitSpawnDialogFlow(isAdmins, maxSec)
    maxSec = tonumber(maxSec) or CHECKER_SPAWN_DIALOG_WAIT_SEC
    local t0 = os.clock()
    while os.clock() - t0 < maxSec do
        if isAdmins then
            if checkerState.spawnAdmsHandled then return true end
        elseif checkerState.spawnLeadersHandled then
            return true
        end
        local now = os.clock()
        if isAdmins then
            if not checkerAdmsFlowIsActive(now) then
                return true
            end
        elseif (checkerState.leadersFlowUntil or 0) <= now then
            return true
        end
        wait(100)
    end
    return false
end

-- Checker (admin HUD/catalog).
function checkerTrySendSyncChat(cmd, forSpawn)
    if type(sendChat) ~= 'function' then return false end
    local now = os.clock()
    local last = tonumber(checkerState.lastSyncChatAt) or 0
    if now - last < CHECKER_SYNC_CHAT_MIN_INTERVAL then
        if forSpawn then
            local waitSec = CHECKER_SYNC_CHAT_MIN_INTERVAL - (now - last) + 0.25
            checkerState.spawnCatalogSyncAt = now + waitSec
        end
        checkerLog('sync chat rate-limited: ' .. tostring(cmd))
        return false
    end
    checkerState.lastSyncChatAt = now
    return SafeCall('sendChat', sendChat, cmd) == true
end

-- Checker (admin HUD/catalog).
function checkerRequestAdmsSync(forSpawn)
    if not checkerSampReady() then return false end
    if forSpawn then
        if checkerIsSpawnCatalogSyncBlocked() then return false end
    elseif checkerIsSyncBlocked() then
        return false
    end
    local now = os.clock()
    local flowT = forSpawn and CHECKER_SPAWN_DIALOG_WAIT_SEC or CHECKER_ADMINS_FLOW_T
    checkerState.pendingAdminMode = 'replace'
    checkerBeginAdmsFlow(now + flowT)
    local ok = checkerTrySendSyncChat('/adms', forSpawn)
    if not ok then checkerClearAdmsFlow() end
    return ok
end

-- Checker (admin HUD/catalog).
function checkerRequestLeadersSync(forSpawn)
    if not checkerSampReady() then return false end
    if forSpawn then
        if checkerIsSpawnCatalogSyncBlocked() then return false end
    elseif checkerIsSyncBlocked() then
        return false
    end
    local flowT = forSpawn and CHECKER_SPAWN_DIALOG_WAIT_SEC or CHECKER_LEADERS_FLOW_T
    local now = os.clock()
    checkerState.leadersSyncOutbound = true
    if checkerState.syncServerKey == '' then
        checkerState.syncServerKey = checkerGetServerKey()
    end
    checkerMarkSyncLeaders(now + flowT)
    local ok = checkerTrySendSyncChat('/leaders', forSpawn)
    if ok then
        checkerLog(forSpawn and 'spawn sync: sent /leaders' or 'sync chat: /leaders')
    else
        checkerState.leadersSyncOutbound = false
    end
    return ok
end

-- Checker (admin HUD/catalog).
function checkerDeferSyncAfterResume()
    checkerScheduleRebuild()
end

-- Checker (admin HUD/catalog).
function checkerStartSpawnCatalogSyncThread()
    if checkerState.spawnCatalogSyncRunning then return end
    if not lua_thread or not lua_thread.create then
        checkerState.spawnCatalogSyncRunning = true
        if checkerRequestAdmsSync(true) then
            checkerState.spawnLeadersDueAt = os.clock() + CHECKER_SPAWN_SYNC_LEADERS_WAIT_MS / 1000
        else
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        end
        checkerState.spawnCatalogSyncRunning = false
        return
    end
    checkerState.spawnCatalogSyncRunning = true
    checkerState.spawnAdmsHandled = false
    checkerState.spawnLeadersHandled = false
    lua_thread.create(function()
        local function waitUntilReady(maxSec)
            maxSec = tonumber(maxSec) or 8.0
            local t0 = os.clock()
            while os.clock() - t0 < maxSec do
                if checkerSampReady() and not checkerIsSpawnCatalogSyncBlocked() then
                    return true
                end
                wait(200)
            end
            return checkerSampReady() and not checkerIsSpawnCatalogSyncBlocked()
        end

        if not waitUntilReady(8.0) then
            checkerState.spawnCatalogSyncRunning = false
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            return
        end

        if checkerRequestAdmsSync(true) then
            checkerWaitSpawnDialogFlow(true, CHECKER_SPAWN_DIALOG_WAIT_SEC)
            wait(CHECKER_SPAWN_SYNC_LEADERS_WAIT_MS)
        end

        if checkerSampReady() and not checkerIsSpawnCatalogSyncBlocked() then
            if checkerRequestLeadersSync(true) then
                checkerWaitSpawnDialogFlow(false, CHECKER_SPAWN_DIALOG_WAIT_SEC)
            end
        end

        local admsHandled = checkerState.spawnAdmsHandled
        local leadersHandled = checkerState.spawnLeadersHandled
        checkerState.spawnCatalogSyncRunning = false
        checkerClearAdmsFlow()
        checkerClearSyncFlowFlags()
        checkerState.spawnAdmsHandled = false
        checkerState.spawnLeadersHandled = false
        local admsOk = admsHandled or #checkerCatalog.admins > 0
        local leadersOk = leadersHandled
        if admsOk and leadersOk then
            checkerState.spawnCatalogSyncDone = true
            ensureSyncSession().spawnAdmsRetries = 0
            checkerPersistSyncSession()
            checkerLog('spawn catalog sync: /adms + /leaders ok')
        elseif not admsOk then
            checkerScheduleSpawnAdmsRetry()
            checkerLog('spawn catalog sync: /adms pending retry')
        else
            checkerState.spawnLeadersDueAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            checkerLog('spawn catalog sync: /leaders pending retry')
        end
    end)
end

-- Checker (admin HUD/catalog).
function checkerScheduleSpawnCatalogSync(delaySec)
    if settings.checker_auto_sync == false then return end
    if checkerState.spawnCatalogSyncDone then return end
    delaySec = tonumber(delaySec) or CHECKER_SPAWN_SYNC_DELAY
    checkerState.spawnCatalogSyncAt = os.clock() + delaySec
end

-- Возобновить spawn catalog sync после закрытия /reps.
function checkerOnDeskWindowClosed()
    if settings.checker_auto_sync == false then return end
    if checkerState.spawnCatalogSyncDone then return end
    if checkerState.spawnCatalogSyncRunning then return end
    if checkerState.spawnAdmsHandled and checkerState.spawnLeadersHandled then return end
    local s = ensureSyncSession()
    if s.spawnAdmsRetries >= CHECKER_SPAWN_ADMS_MAX_RETRIES then
        s.spawnAdmsRetries = 0
        checkerPersistSyncSession()
    end
    checkerScheduleSpawnCatalogSync(1.5)
end

-- Checker (admin HUD/catalog).
function checkerTrySpawnCatalogSync()
    if settings.checker_auto_sync == false then return end
    if checkerState.spawnCatalogSyncDone then return end
    if checkerState.spawnCatalogSyncRunning then return end
    local leadersDue = tonumber(checkerState.spawnLeadersDueAt)
    if leadersDue and os.clock() >= leadersDue then
        checkerState.spawnLeadersDueAt = nil
        if checkerState.spawnLeadersHandled then
            checkerState.spawnCatalogSyncDone = true
            return
        end
        if not checkerSampReady() or checkerIsSpawnCatalogSyncBlocked() then
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            return
        end
        if checkerRequestLeadersSync(true) then
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_DIALOG_WAIT_SEC
        else
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        end
        return
    end
    local at = checkerState.spawnCatalogSyncAt
    if not at or os.clock() < at then return end
    if not checkerSampReady() or checkerIsSpawnCatalogSyncBlocked() then
        checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        return
    end
    checkerState.spawnCatalogSyncAt = nil
    checkerStartSpawnCatalogSyncThread()
end

-- Checker (admin HUD/catalog).
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

-- Checker (admin HUD/catalog).
function checkerAdminLevelLabel(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsChiefLevel(level) then
        return CHECKER_CHIEF_TAG[level] or ''
    end
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

-- Checker (admin HUD/catalog).
function checkerPlayJoinAlert()
    if settings.checker_notify_sound == false then return end
    if type(playDeskAlertSound) == 'function' then
        SafeCall('playDeskAlertSound', playDeskAlertSound)
    end
end

-- Checker (admin HUD/catalog).
function checkerOnSendCommand(command)
    local cmd = trim(command or ''):match('^/?(%S+)')
    if not cmd then return end
    local lc = cmd:lower()
    if lc == 'leaders' then
        if checkerState.leadersSyncOutbound then return end
        checkerClearSyncLeaders()
    elseif lc == 'adms' or lc == 'admins' then
        if checkerAdmsFlowIsOutbound() then return end
        checkerClearAdmsFlow()
    end
end

-- Dev RPC probe: активно ли окно ожидания /adms (lib/report_desk_hooks.lua).
function checkerIsAdmsSyncWindow()
    return checkerSyncAdmsActive(os.clock())
end

-- Checker (admin HUD/catalog).
function checkerMarkCatalogDirty()
    Catalog.rebuildIndex()
    bumpCatalogRev()
    CheckerCatalogStore.markDirty()
end

-- Checker (admin HUD/catalog).
function checkerBuildCatalogSnapshot()
    ensureCheckerCatalog()
    ensureCheckerSettings()
    local hiddenKeys = {}
    for key in pairs(settings.checker_leader_hidden or {}) do
        if key ~= '' then hiddenKeys[#hiddenKeys + 1] = key end
    end
    table.sort(hiddenKeys)
    return {
        admins = checkerCatalog.admins,
        leaders = checkerCatalog.leaders,
        friends = checkerCatalog.friends,
        hidden_nicks = hiddenKeys,
    }
end

-- Checker (admin HUD/catalog).
function checkerApplyCatalogSnapshot(c)
    if type(c) ~= 'table' then return false end
    ensureCheckerCatalog()
    local changed = false
    if type(c.admins) == 'table' and #c.admins > 0 then
        local list = {}
        for _, raw in ipairs(c.admins) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                list[#list + 1] = {
                    nick = trim(raw.nick),
                    level = checkerEffectiveAdminLevel(trim(raw.nick), raw.level),
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
                local e = list[#list]
                e.org = checkerResolveLeaderOrgId(e)
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
        checkerState.leaderShowUi = {}
        checkerState.leaderGroupShowUi = {}
        Catalog.rebuildIndex()
        bumpCatalogRev()
    end
    if checkerEnsureChiefCatalog() then
        changed = true
    end
    checkerSanitizeAdminCatalog()
    return changed
end

-- Checker (admin HUD/catalog).
function checkerSaveCatalogStorage()
    return CheckerCatalogStore.save(checkerBuildCatalogSnapshot())
end

-- Checker (admin HUD/catalog).
function flushCheckerCatalogNow()
    if CheckerCatalogStore.isDirty() then
        checkerSaveCatalogStorage()
    end
end

-- Checker (admin HUD/catalog).
function checkerLoadCatalogStorage()
    local data = CheckerCatalogStore.load()
    if not data then return false end
    checkerApplyCatalogSnapshot(data)
    return true
end

-- Checker (admin HUD/catalog): одноразовый перенос из admin_report_desk_user.lua.
function checkerMigrateLegacyCatalog(legacyChecker)
    if CheckerCatalogStore.exists() then return false end
    if type(legacyChecker) ~= 'table' then return false end
    if not checkerApplyCatalogSnapshot(legacyChecker) then return false end
    if checkerSaveCatalogStorage() then
        print('[Report Desk] checker catalog: migrated to config/report_desk_checker_catalog.lua')
        return true
    end
    return false
end

-- Sort Admins Online
local function sortAdminsOnline(list)
    local executive, regular, special = checkerSplitAdminLists(list)
    local n = 0
    for _, e in ipairs(executive) do
        n = n + 1
        list[n] = e
    end
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

OnlineIndex = {}

local ONLINE_ROLE = {
    admin = { list = 'admins', byId = 'adminsById', byNick = 'adminsByNick' },
    leader = { list = 'leaders', byId = 'leadersById', byNick = 'leadersByNick' },
    friend = { list = 'friends', byId = 'friendsById', byNick = 'friendsByNick' },
}

-- Online Index.clear
function OnlineIndex.clear()
    local idx = checkerState.onlineIndex
    idx.adminsById = {}
    idx.leadersById = {}
    idx.friendsById = {}
    idx.adminsByNick = {}
    idx.leadersByNick = {}
    idx.friendsByNick = {}
end

-- Online Index.sync From Lists
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

-- Online Index.add
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

-- Online Index.remove By Id
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

-- Online Index.get By Id
function OnlineIndex.getById(role, playerId)
    playerId = tonumber(playerId)
    if not playerId then return nil end
    local cfg = ONLINE_ROLE[role]
    if not cfg then return nil end
    local byId = checkerState.onlineIndex[cfg.byId]
    if type(byId) ~= 'table' then return nil end
    return byId[playerId]
end

-- Online Index.get By Nick
function OnlineIndex.getByNick(role, nick)
    local key = nickKey(nick)
    if key == '' then return nil end
    local cfg = ONLINE_ROLE[role]
    if not cfg then return nil end
    local byNick = checkerState.onlineIndex[cfg.byNick]
    if type(byNick) ~= 'table' then return nil end
    return byNick[key]
end

-- Online Index.has Id
function OnlineIndex.hasId(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    local idx = checkerState.onlineIndex
    return (type(idx.adminsById) == 'table' and idx.adminsById[playerId] ~= nil)
        or (type(idx.leadersById) == 'table' and idx.leadersById[playerId] ~= nil)
        or (type(idx.friendsById) == 'table' and idx.friendsById[playerId] ~= nil)
end

-- Online Index.get Tracked Role
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

-- Online Lists Equal
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

-- Сопоставляет каталог admin/leader/friend с онлайном SAMP.
function checkerRebuildOnline(force)
    ensureCheckerCatalog()
    checkerState.lastRebuild = os.clock()
    if not checkerSampReady() then return false end
    checkerEnsureNickIndex(force == true)
    local byNick = checkerState.onlineNickIndex and checkerState.onlineNickIndex.byNick
    local admins, leaders, friends = {}, {}, {}
    for _, e in ipairs(checkerCatalog.admins) do
        if e and e.nick and checkerIsValidAdminLevel(e.level)
                and not checkerLeaderRoleConflictsAdminLevel(e.nick, e.level) then
            local id = checkerLookupOnlineId(e.nick)
            if id then
                local prev = OnlineIndex.getById('admin', id)
                local nick = checkerSafeNick(id, e.nick)
                local level = checkerEffectiveAdminLevel(e.nick, e.level)
                local snap = checkerState.admsOnlineSnapshot
                if type(snap) == 'table' and type(snap.byId) == 'table' and snap.byId[id] then
                    level = snap.byId[id].level or level
                end
                admins[#admins + 1] = {
                    id = id,
                    nick = nick,
                    level = level,
                    afk = prev and prev.afk or checkerPlayerAfk(id),
                }
            end
        end
    end
    local snapLeaders = checkerLeadersFromSnapshot()
    if snapLeaders then
        leaders = snapLeaders
    else
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
    end
    for _, e in ipairs(checkerCatalog.friends) do
        if e and e.nick and not Catalog.getAdmin(e.nick) then
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

-- Rescan Checker Online
function rescanCheckerOnline(force)
    return checkerRebuildOnline(force)
end

-- Checker (admin HUD/catalog).
function checkerRemoveOnlineById(playerId)
    return OnlineIndex.removeById(playerId)
end

-- Checker (admin HUD/catalog).
function checkerAddOnlineFromJoin(playerId, nick)
    playerId = tonumber(playerId)
    nick = nick or ''
    if not playerId or nick == '' or not checkerSampReady() then return false end
    checkerIndexOnePlayer(playerId, nick)
    local displayNick = checkerNormalizeNick(nick) or nick
    local changed = false
    local admin = Catalog.getAdmin(nick)
    if admin and not OnlineIndex.getById('admin', playerId) then
        if OnlineIndex.add('admin', {
            id = playerId,
            nick = displayNick,
            level = checkerEffectiveAdminLevel(nick, admin.level),
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

-- Checker (admin HUD/catalog).
function checkerTrackedRole(playerId)
    return OnlineIndex.getTrackedRole(playerId)
end

-- Checker (admin HUD/catalog).
function checkerSayAdminJoin(id, nick, level)
    level = math.floor(tonumber(level) or 0)
    local cnick = checkerFormatNickColored(nick, level)
    local msg
    if checkerIsTopAdmin(nick) then
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0, %s[%i].', cnick, id)
    elseif checkerIsChiefLevel(level) then
        msg = string.format('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE8\xEB\xF1\xFF %s, %s[%i].',
            checkerFormatAdminLevelDisplay(level), cnick, id)
    elseif checkerIsSpecialLevel(level) then
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

-- Checker (admin HUD/catalog).
function checkerSayLeaderJoin(id, nick, org)
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

-- Checker (admin HUD/catalog).
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
                    checkerSayLeaderJoin(playerId, nick, checkerInferLeaderOrgId(leader))
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

-- Checker (admin HUD/catalog).
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

-- Checker (admin HUD/catalog).
function checkerOnServerMessage(color, text)
    if not checkerIsSpawned() then return end
    if not text or text == '' then return end
    local plain = stripChatTimestamp(stripTags(text))
    if plain ~= '' and not checkerIsAdmsChatMuted() then
        checkerRefreshAdminLevelFromChat(plain)
    end

    if settings.checker_auto_promote == false then return end
    if tonumber(color) ~= SAMP_COLOR_AUTO_PROMOTE then return end
    plain = Parser.normalizeAdminListLine(stripTags(text))
    local nick, level, pid = Parser.parseAdminLine(plain)
    if not nick or not level then return end
    level = checkerEffectiveAdminLevel(nick, level)
    if not checkerIsValidAdminLevel(level) then return end
    if checkerLeaderRoleConflictsAdminLevel(nick, level) then return end
    if type(isValidPlayerNick) == 'function' and not isValidPlayerNick(nick) then return end
    if not nick:find('_', 1, true) then return end
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
        local newLevel = level
        if old ~= newLevel and checkerShouldApplyAdminLevelUpdate(old, newLevel) then
            existing.level = newLevel
            checkerMarkCatalogDirty()
        end
        return
    end
    checkerCatalog.admins[#checkerCatalog.admins + 1] = {
        nick = nick,
        level = level,
    }
    checkerSortCatalogAdmins(checkerCatalog.admins)
    checkerMarkCatalogDirty()
    local id = checkerLookupOnlineId(nick)
    if id then checkerAddOnlineFromJoin(id, nick) end
end

-- Checker (admin HUD/catalog).
function checkerScheduleRebuild()
    checkerState.pendingRebuild = true
end

-- Checker (admin HUD/catalog).
function checkerScheduleRescan()
    checkerScheduleRebuild()
end

-- Checker (admin HUD/catalog).
function checkerRunPendingRebuild()
    if not checkerState.pendingRebuild or not checkerSampReady() then return end
    checkerState.pendingRebuild = false
    SafeCall('rebuildOnlinePending', checkerRebuildOnline, true)
end

-- Checker (admin HUD/catalog).
function checkerPollTrackedAfk()
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

-- Checker (admin HUD/catalog).
function checkerOnPlayerStreamIn(playerId)
    playerId = tonumber(playerId)
    if not playerId or not checkerIsSpawned() then return end
    local nick = checkerSafeNick(playerId, '')
    if nick ~= '' and checkerAddOnlineFromJoin(playerId, nick) then return end
    checkerScheduleRebuild()
end

-- Checker (admin HUD/catalog).
function checkerNoteSpawned()
    if not checkerIsSpawned() then return end
    if checkerState.spawnedAt then return end
    checkerState.spawnedAt = os.clock()
    checkerState.firstRebuildAt = checkerState.spawnedAt + CHECKER_SPAWN_REBUILD_DELAY
    checkerState.lastRebuild = 0
    checkerState.nickIndexNeedsFullScan = true
    checkerResetJoinNotifyWarmup()
    checkerScheduleSpawnCatalogSync()
end

local Sync = {}

-- === Sync: periodic rebuild ===
function Sync.update()
    SafeCall('pendingRebuild', checkerRunPendingRebuild)
    if os.clock() - (checkerState.lastRebuild or 0) >= CHECKER_REBUILD_INTERVAL then
        checkerState.lastRebuild = os.clock()
        SafeCall('periodicRebuild', checkerRebuildOnline, false)
    end
    if settings.checker_auto_sync == true and checkerIsSpawned() and not checkerIsSuspended()
            and not checkerState.spawnCatalogSyncRunning then
        local s = ensureSyncSession()
        local now = os.clock()
        if now - (s.lastAdmsResync or 0) >= CHECKER_ADMS_RESYNC_INTERVAL then
            if not checkerIsSyncBlocked() and not checkerSyncAdmsActive(now) then
                if checkerRequestAdmsSync(false) then
                    s.lastAdmsResync = now
                end
            end
        end
        if #checkerCatalog.leaders == 0 and not checkerSyncLeadersActive(now)
                and not checkerIsSyncBlocked() and not checkerState.spawnCatalogSyncRunning then
            checkerRequestLeadersSync(false)
        end
    end
end

local Tracker = {}

-- Первый rebuild после spawn delay.
function Tracker.update()
    if checkerState.firstRebuildAt and os.clock() >= checkerState.firstRebuildAt then
        checkerState.firstRebuildAt = nil
        checkerScheduleRebuild()
    end
end

local Afk = {}

-- Poll AFK статуса tracked игроков.
function Afk.update()
    SafeCall('pollAfk', checkerPollTrackedAfk)
end

local Hud = {}

-- Suspend drag HUD при alt-tab.
function Hud.update()
    if checkerIsSuspended() and checkerState.hudDrag then
        checkerState.hudDrag.active = false
    end
end

-- Периодика checker: rebuild online, AFK, spawn catalog sync.
function checkerTick()
    if not checkerSampReady() then
        if checkerState.hudDrag then checkerState.hudDrag.active = false end
        checkerState.syncInFlight = false
        checkerClearAdmsFlow()
        checkerState.leadersFlowUntil = 0
        checkerState.spawnCatalogSyncRunning = false
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
        SafeCall('spawnCatalogSync', checkerTrySpawnCatalogSync)
    end
end

-- Пересчитать org id у лидеров из org_name (каталог мог хранить неверный org).
local function checkerNormalizeLeaderCatalogOrg()
    local changed = false
    for _, e in ipairs(checkerCatalog.leaders or {}) do
        if e then
            local inferred = checkerResolveLeaderOrgId(e)
            if inferred > 0 and (tonumber(e.org) or 0) ~= inferred then
                e.org = inferred
                changed = true
            end
        end
    end
    if changed then checkerMarkCatalogDirty() end
end

-- Убрать битые записи лидеров (org id без org_name — типичный мусор после сбоя синка).
-- Убрать из admins невалидные уровни и ложные записи (ранг лидера ≠ admin lvl).
function checkerSanitizeAdminCatalog()
    local out, changed = {}, false
    for _, e in ipairs(checkerCatalog.admins or {}) do
        local nick = trim(e and e.nick or '')
        local level = math.floor(tonumber(e and e.level) or 0)
        if nick == '' then
            changed = true
        elseif not checkerIsValidAdminLevel(level) then
            changed = true
        elseif checkerLeaderRoleConflictsAdminLevel(nick, level) then
            changed = true
        else
            out[#out + 1] = e
        end
    end
    if changed then
        checkerCatalog.admins = out
        checkerSortCatalogAdmins(checkerCatalog.admins)
        checkerMarkCatalogDirty()
    end
end

local function checkerSanitizeLeaderCatalog()
    local out, changed = {}, false
    for _, e in ipairs(checkerCatalog.leaders or {}) do
        local nick = trim(e and e.nick or '')
        local orgName = trim(e and e.org_name or '')
        local orgId = math.floor(tonumber(e and e.org) or 0)
        if nick == '' then
            changed = true
        elseif orgName == '' and orgId > 0 and orgId <= ORG_MAFIA_MAX then
            changed = true
        else
            out[#out + 1] = e
        end
    end
    if changed then
        checkerCatalog.leaders = out
        checkerState.leaderShowUi = {}
        checkerState.leaderGroupShowUi = {}
        checkerMarkCatalogDirty()
    end
end

-- Инициализация checker HUD и catalog при старте.
-- === Init / HUD overlay ===
function checkerInit()
    SafeCall('checkerInit', function()
        ensureCheckerSettings()
        ensureCheckerCatalog()
        checkerEnsureChiefCatalog()
        if not checkerLoadCatalogStorage() then
            local pending = rawget(_G, '__desk_pendingCheckerCatalog')
            if type(pending) == 'table' then
                checkerMigrateLegacyCatalog(pending)
                rawset(_G, '__desk_pendingCheckerCatalog', nil)
            end
        else
            rawset(_G, '__desk_pendingCheckerCatalog', nil)
        end
        Catalog.rebuildIndex()
        checkerSanitizeAdminCatalog()
        checkerSanitizeLeaderCatalog()
        checkerNormalizeLeaderCatalogOrg()
        if not checkerSampReady() then
            checkerState.spawnedAt = nil
        end
        checkerState.firstRebuildAt = nil
        checkerState.lastAfkPoll = 0
        checkerState.lastRebuild = 0
        checkerState.lastOnlineCatalogRev = -1
        checkerState.lastOnlineRev = -1
        checkerState.syncInFlight = false
        checkerState.admsFlow = nil
        checkerState.admsFlowUntil = 0
        checkerState.admsDialogSyncedAt = 0
        checkerState.syncServerKey = ''
        checkerState.leadersFlowUntil = 0
        checkerState.leadersSyncOutbound = false
        checkerState.leadersOnlineSnapshot = nil
        checkerState.spawnCatalogSyncRunning = false
        checkerState.wasSuspended = false
        checkerState.hudHealAttempts = 0
        checkerState.spawnLeadersDueAt = nil
        checkerState.lastSyncChatAt = 0
        rawset(_G, SYNC_SESSION_KEY, nil)
        checkerState.spawnCatalogSyncDone = false
        checkerState.spawnAdmsHandled = false
        checkerState.spawnLeadersHandled = false
        checkerState.spawnCatalogSyncAt = nil
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
        checkerClearSyncFlowFlags()
        checkerSanitizeSyncSession()
        checkerDismissStaleSyncDialog()
        if checkerSampReady() then
            checkerScheduleRebuild()
            if settings.checker_auto_sync ~= false then
                checkerScheduleSpawnCatalogSync()
            end
        end
        print(string.format('[Report Desk] checker catalog: %d admins, %d leaders, %d friends',
            #checkerCatalog.admins, #checkerCatalog.leaders, #checkerCatalog.friends))
    end)
end

-- Checker (admin HUD/catalog).
function checkerHudVisible()
    ensureCheckerSettings()
    if settings.checker_hud == false then return false end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
    if type(isSampAvailable) == 'function' and not isSampAvailable() then return false end
    if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then
        if checkerState.hudDrag then checkerState.hudDrag.active = false end
        return false
    end
    return true
end

-- Checker (admin HUD/catalog).
function checkerIsHudVisible()
    return checkerHudVisible()
end

-- Uninstall Checker Hud Frame
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

-- Install Checker Hud Frame
function installCheckerHudFrame()
    if toU32 and checkerSpTheme.setColorConverter then
        pcall(checkerSpTheme.setColorConverter, toU32)
    end
    uninstallCheckerHudFrame()
    if type(imgui) ~= 'table' or type(imgui.OnFrame) ~= 'function' then
        checkerState.hudFrameInstalled = true
        return
    end
    local frame = imgui.OnFrame(
        function()
            return checkerHudVisible()
        end,
        function(self)
            local ok, err = pcall(drawCheckerHudOverlay)
            if not ok then
                print('[Report Desk] checker HUD draw: ' .. tostring(err))
            end
            self.HideCursor = deskMimguiHideCursor(
                type(checkerHudWantsInput) == 'function' and checkerHudWantsInput())
            self.LockPlayer = false
        end
    )
    if frame then
        frame.HideCursor = true
        frame.LockPlayer = false
        if type(deskCache) == 'table' then deskCache.checkerHudFrame = frame end
        rawset(_G, '__desk_checkerHudFrame', frame)
    end
    checkerState.hudFrameInstalled = true
end

-- Checker (admin HUD/catalog).
function checkerSafePlayerColor(id)
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

-- Checker (admin HUD/catalog).
function checkerScreenSize()
    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    return sw, sh
end

-- Checker (admin HUD/catalog).
function checkerClampHudPos(hx, hy, winW, winH)
    local sw, sh = checkerScreenSize()
    winW = math.max(CHECKER_HUD_W, tonumber(winW) or CHECKER_HUD_W)
    winH = math.max(48, tonumber(winH) or 120)
    hx = math.max(8, math.min(hx, sw - winW - 8))
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

-- Checker (admin HUD/catalog).
function checkerHudSavedHeight(fallback)
    local h = tonumber(settings.checker_hud_h)
    if h and h >= 48 then return h end
    return math.max(48, tonumber(fallback) or 120)
end

-- Checker (admin HUD/catalog).
function checkerGuardHudOffScreen(hx, hy, winW, winH)
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

-- Checker (admin HUD/catalog).
function checkerPersistHudPos(hx, hy, winW, winH, flushNow)
    hx, hy = checkerClampHudPos(hx, hy, winW, winH)
    local nx = math.floor(hx + 0.5)
    local ny = math.floor(hy + 0.5)
    local nh = math.floor(math.max(48, tonumber(winH) or 120) + 0.5)
    local ox = math.floor(tonumber(settings.checker_hud_x) or 8)
    local oy = math.floor(tonumber(settings.checker_hud_y) or 8)
    local oh = math.floor(tonumber(settings.checker_hud_h) or 160)
    checkerState.hudPlaced = true
    if nx == ox and ny == oy and nh == oh then
        return
    end
    settings.checker_hud_x = nx
    settings.checker_hud_y = ny
    settings.checker_hud_h = nh
    markDirtySettings()
    if flushNow and type(flushDirtyConfigNow) == 'function' then
        SafeCall('flushDirtyConfigNow', flushDirtyConfigNow)
    end
end

-- Checker (admin HUD/catalog).
function checkerIsHudDragActive()
    return checkerState.hudDrag and checkerState.hudDrag.active == true
end

-- Checker (admin HUD/catalog).
function checkerHudWantsInput()
    if checkerState.hudDrag and checkerState.hudDrag.active then return true end
    if checkerState.hudHovered then return true end
    local r = checkerState.hudRect
    if r then
        local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
            or type(deskPointerInRect) == 'function' and deskPointerInRect
        if pin and pin(r) then return true end
        if imgui and type(imgui.GetIO) == 'function' then
            local ok, io = pcall(imgui.GetIO)
            if ok and io and io.MousePos then
                local mp = io.MousePos
                if mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1 then
                    return true
                end
            end
        end
    end
    local hx = tonumber(settings.checker_hud_x) or 8
    local hy = tonumber(settings.checker_hud_y) or 8
    local estW = tonumber(checkerState.hudLastW) or (CHECKER_HUD_W + 80)
    local estH = tonumber(checkerState.hudLastH) or checkerHudSavedHeight(160)
    local est = { x0 = hx, y0 = hy, x1 = hx + estW, y1 = hy + estH }
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin and pin(est) then return true end
    if imgui and type(imgui.GetIO) == 'function' then
        local ok, io = pcall(imgui.GetIO)
        if ok and io and io.MousePos then
            local mp = io.MousePos
            return mp.x >= est.x0 and mp.x < est.x1 and mp.y >= est.y0 and mp.y < est.y1
        end
    end
    return false
end

-- HUD-строка: одна линия, без переноса (уровень/тег не уезжает на строку ниже).
local function drawCheckerHudRow(label, col)
    imgui.PushTextWrapPos(0)
    imgui.TextColored(col, uiText(label))
    imgui.PopTextWrapPos()
end

-- Checker (admin HUD/catalog).
function checkerOnlineTags(e)
    if e and e.afk then return ' AFK' end
    return ''
end

-- Отрисовка checker UI.
function drawCheckerAdminRow(e, index, idSuffix, indent)
    indent = tonumber(indent) or 0
    local lv = math.floor(tonumber(e.level) or 0)
    local col = checkerAdminColor(lv)
    local prefix = indent > 0 and '  ' or ''
    local label = string.format('%s%i. %s [%i]', prefix, index, e.nick or '', e.id or -1)
    local lvlText = checkerFormatAdminLevelDisplay(lv, e.nick)
    if lvlText ~= '' then
        label = label .. '  ' .. lvlText
    end
    label = label .. checkerOnlineTags(e)
    drawCheckerHudRow(label, col)
end

-- Отрисовка checker UI.
function drawCheckerAdminsBlock()
    local list = select(1, checkerHudLists())
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    local executive, regular, special = checkerSplitAdminLists(list)
    local shown = 0
    if #executive > 0 then
        for _, e in ipairs(executive) do
            shown = shown + 1
            drawCheckerAdminRow(e, shown, 'adm_e_', 0)
        end
    end
    if #regular > 0 then
        if #executive > 0 then
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        shown = 0
        for _, e in ipairs(regular) do
            shown = shown + 1
            drawCheckerAdminRow(e, shown, 'adm_', 0)
        end
    end
    if #special > 0 then
        if #executive > 0 or #regular > 0 then
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        checkerSpTheme.drawSectionLabel(
            '\x50\x52 \xE8 \xF2\xE5\xF5\xED\xE0\xF0\xE8:',
            col_muted2, uiText)
        local sIndex = 0
        for _, e in ipairs(special) do
            sIndex = sIndex + 1
            drawCheckerAdminRow(e, sIndex, 'adm_s_', 0)
        end
    end
end

-- Отрисовка checker UI.
function drawCheckerColorListBlock(list, emptyText, idPrefix)
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
        drawCheckerHudRow(label, col)
    end
end

-- Отрисовка checker UI.
function drawCheckerLeadersBlock()
    local list = select(2, checkerHudLists())
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText('\xCB\xE8\xE4\xE5\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    local shown = 0
    for _, e in ipairs(list) do
        shown = shown + 1
        local col = checkerSafePlayerColor(e.id) or col_accent
        local label = string.format('%i. %s [%i]%s', shown, e.nick, e.id, checkerOnlineTags(e))
        drawCheckerHudRow(label, col)
    end
end

-- Отрисовка checker UI.
function drawCheckerFriendsBlock()
    ensureCheckerCatalog()
    local list = select(3, checkerHudLists())
    local filtered = {}
    for _, e in ipairs(list) do
        if e and e.nick and not Catalog.getAdmin(e.nick) then
            filtered[#filtered + 1] = e
        end
    end
    drawCheckerColorListBlock(filtered, '\xC4\xF0\xF3\xE7\xE5\xE9 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2', 'fr')
end

-- Отрисовка checker UI.
function drawCheckerFriendsSettings()
    ensureCheckerCatalog()
    if not checkerUi.friendNick then return end
    imgui.TextColored(col_muted2, uiText('\xCD\xE8\xEA \xE4\xF0\xF3\xE3\xE0 (\xED\xE5 \xE8\xE7 \xEA\xE0\xF2\xE0\xEB\xEE\xE3\xE0 \xE0\xE4\xEC\xE8\xED\xEE\xE2):'))
    imgui.Dummy(imgui.ImVec2(0, 4))
    if imgui.InputTextWithHint then
        imgui.InputTextWithHint('##chk_fr_nick', uiText('Nick_Name'), checkerUi.friendNick, sizeof(checkerUi.friendNick))
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
    local visible = {}
    for _, e in ipairs(checkerCatalog.friends) do
        if e and e.nick and not Catalog.getAdmin(e.nick) then
            visible[#visible + 1] = e
        end
    end
    if #visible == 0 then
        imgui.TextColored(col_muted2, uiText('\xD1\xEF\xE8\xF1\xEE\xEA \xE4\xF0\xF3\xE7\xE5\xE9 \xEF\xF3\xF1\xF2'))
        return
    end
    for i, e in ipairs(visible) do
        local nick = e.nick or ''
        local uid = nickKey(nick)
        local id = checkerLookupOnlineId(nick)
        local online = id and checkerPlayerConnectedSafe(id)
        local nickCol = online and checkerSafePlayerColor(id) or col_muted2
        imgui.PushID('chk_fr_' .. uid)
        if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
        imgui.TextColored(nickCol, uiText(nick))
        if online then
            imgui.SameLine(0, 6)
            imgui.TextColored(col_muted2, uiText('[' .. tostring(id) .. ']'))
        end
        imgui.SameLine(0, 12)
        local removed = false
        if imgui.SmallButton then
            removed = imgui.SmallButton(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##chk_fr_rm_' .. uid)
        elseif imgui.Button then
            removed = imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##chk_fr_rm_' .. uid)
        end
        if removed then
            checkerRemoveFriend(nick)
        end
        imgui.PopID()
    end
end

-- Отрисовка checker UI.
local function drawCheckerLeaderSubsectionHeader(factionKey, count)
    local meta = checkerLeaderFactionMeta(factionKey)
    local col = meta.headerColor or col_muted2
    if checkerSpTheme and checkerSpTheme.drawSectionLabel then
        checkerSpTheme.drawSectionLabel(meta.title, col, uiText)
    else
        imgui.TextColored(col, uiText(meta.title))
    end
    imgui.SameLine(0, 6)
    imgui.TextColored(col_muted2, uiText('(' .. tostring(count or 0) .. ')'))
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Отрисовка checker UI.
local function drawCheckerLeaderFactionHeader(factionKey, count, firstSection)
    local meta = checkerLeaderFactionMeta(factionKey)
    local headerCol = checkerLeaderFactionClistImColor(factionKey, true)
    if not firstSection then
        imgui.Dummy(imgui.ImVec2(0, 8))
    end
    if checkerSpTheme and checkerSpTheme.drawSectionLabel then
        checkerSpTheme.drawSectionLabel(meta.title, headerCol, uiText)
    else
        imgui.TextColored(headerCol, uiText(meta.title))
    end
    imgui.SameLine(0, 6)
    imgui.TextColored(col_muted2, uiText('(' .. tostring(count or 0) .. ')'))
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Отрисовка checker UI.
function drawCheckerLeaderSettingsRow(entry)
    local nick = entry.nick or ''
    local ref = checkerLeaderShowRef(nick)
    if not ref then return end
    local uid = nickKey(nick)
    local visible = ref[0] and true or false
    local nickCol = checkerLeaderFactionColor(entry, visible)
    local sub = checkerLeaderSubline(entry)
    local id = entry.id or checkerLookupOnlineId(nick)
    if id and checkerPlayerConnectedSafe(id) then
        sub = (sub ~= '' and (sub .. '  \xB7  ') or '') .. '\xE2 \xF1\xE5\xF2\xE8'
    end

    imgui.PushID('chk_ld_' .. uid)
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    local changed = false
    if imgui.Checkbox('##vis', ref) then
        changed = true
    end
    imgui.SameLine(0, 8)
    imgui.TextColored(nickCol, uiText(nick))
    if sub ~= '' then
        imgui.SameLine(0, 6)
        imgui.TextColored(col_muted2, uiText(sub))
    end
    imgui.PopID()
    if changed then
        checkerSetLeaderHidden(nick, not ref[0])
    end
end

-- Отрисовка checker UI.
function drawCheckerLeadersSettings()
    ensureCheckerCatalog()
    local leaders = checkerCatalog.leaders
    if #leaders == 0 then
        imgui.TextColored(col_muted2, uiText('\xCA\xE0\xF2\xE0\xEB\xEE\xE3 \xEB\xE8\xE4\xE5\xF0\xEE\xE2 \xEF\xF3\xF1\xF2 \x2014 \xED\xE0\xE6\xEC\xE8\xF2\xE5 \xAB\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE8\xF0\xEE\xE2\xE0\xF2\xFC\xBB \xE2 \xF7\xE5\xEA\xE5\xF0\xE5'))
        return
    end

    local order, groups = checkerBuildLeaderFactionGroups(leaders)
    if #order == 0 then
        return
    end
    for gi, fk in ipairs(order) do
        if fk == 'illegal' then
            local bands = groups.band or {}
            local mafias = groups.mafia or {}
            if gi > 1 then
                imgui.Dummy(imgui.ImVec2(0, 8))
            end
            if #bands > 0 then
                drawCheckerLeaderSubsectionHeader('band', #bands)
                for _, e in ipairs(bands) do
                    drawCheckerLeaderSettingsRow(e)
                end
            end
            if #bands > 0 and #mafias > 0 then
                imgui.Dummy(imgui.ImVec2(0, 4))
            end
            if #mafias > 0 then
                drawCheckerLeaderSubsectionHeader('mafia', #mafias)
                for _, e in ipairs(mafias) do
                    drawCheckerLeaderSettingsRow(e)
                end
            end
        else
            local entries = groups[fk]
            drawCheckerLeaderFactionHeader(fk, #entries, gi == 1)
            for _, e in ipairs(entries) do
                drawCheckerLeaderSettingsRow(e)
            end
        end
    end
end

-- Отрисовка checker UI.
-- === Checker HUD ImGui overlay ===
function drawCheckerHudOverlay()
    if not checkerHudVisible() then return end
    ensureCheckerSettings()
    local hudAdmins = select(1, checkerHudLists())
    if #hudAdmins > 0 then
        checkerState.hudHealAttempts = 0
        checkerState.healResetAt = 0
    elseif #checkerCatalog.admins > 0 and checkerSampReady() then
        local now = os.clock()
        local healResetAt = tonumber(checkerState.healResetAt) or 0
        if healResetAt > 0 and now >= healResetAt then
            checkerState.hudHealAttempts = 0
            checkerState.healResetAt = 0
        end
        local tries = tonumber(checkerState.hudHealAttempts) or 0
        local lastHeal = tonumber(checkerState.lastHudHealAt) or 0
        if tries < CHECKER_HUD_HEAL_MAX_TRIES
                and (lastHeal <= 0 or now - lastHeal >= CHECKER_HUD_HEAL_INTERVAL) then
            checkerState.lastHudHealAt = now
            checkerState.hudHealAttempts = tries + 1
            SafeCall('hudHealRebuild', checkerRebuildOnline, true)
            if checkerState.hudHealAttempts >= CHECKER_HUD_HEAL_MAX_TRIES then
                checkerState.healResetAt = now + CHECKER_HUD_HEAL_RESET_SEC
            end
        end
    end

    local hudH = checkerHudSavedHeight(120)
    local rawHx = tonumber(settings.checker_hud_x) or 8
    local rawHy = tonumber(settings.checker_hud_y) or 8
    local hx, hy = checkerClampHudPos(rawHx, rawHy, CHECKER_HUD_W, hudH)
    if not checkerState.hudDrag then
        checkerState.hudDrag = { active = false, offX = 0, offY = 0 }
    end
    local drag = checkerState.hudDrag
    if drag.active then
        hx = drag.offX
        hy = drag.offY
    elseif not checkerState.hudPlaced
            and (math.floor(hx + 0.5) ~= math.floor(rawHx + 0.5)
            or math.floor(hy + 0.5) ~= math.floor(rawHy + 0.5)) then
        checkerPersistHudPos(hx, hy, CHECKER_HUD_W, hudH, true)
    end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoNav + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoSavedSettings then
        flags = flags + imgui.WindowFlags.NoSavedSettings
    end

    imgui.SetNextWindowSizeConstraints(
        imgui.ImVec2(CHECKER_HUD_W, 0), imgui.ImVec2(CHECKER_HUD_W + 80, 900))
    if imgui.SetNextWindowBgAlpha then
        imgui.SetNextWindowBgAlpha(checkerSpTheme.HUD_OVERLAY_ALPHA or 0.80)
    end
    imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)

    checkerSpTheme.pushHudChrome()
    if imgui.Begin('###desk_checker_hud', nil, flags) then
        checkerState.hudHovered = false
        checkerSpTheme.drawPanelFrame()
        local hudAdmins, hudLeaders, hudFriends = checkerHudLists()
        checkerSpTheme.drawPanelTitle(
            '\xD7\xE5\xEA\xE5\xF0',
            string.format('(%i/%i/%i)', #hudAdmins, #hudLeaders, #hudFriends),
            col_accent, col_muted2, uiText)

        if settings.checker_show_admins ~= false then
            checkerSpTheme.drawSectionLabel(
                '\xC0\xE4\xEC\xE8\xED\xFB:',
                col_muted2, uiText)
            drawCheckerAdminsBlock()
            imgui.Spacing()
        end
        if settings.checker_show_leaders ~= false then
            checkerSpTheme.drawSectionLabel(
                '\xCB\xE8\xE4\xE5\xF0\xFB:',
                col_muted2, uiText)
            drawCheckerLeadersBlock()
            imgui.Spacing()
        end
        if settings.checker_show_friends ~= false then
            checkerSpTheme.drawSectionLabel(
                '\xC4\xF0\xF3\xE7\xFC\xFF:',
                col_muted2, uiText)
            drawCheckerFriendsBlock()
            imgui.Spacing()
        end

        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        checkerState.hudLastW = ww
        checkerState.hudLastH = wh
        checkerState.hudRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }

        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        imgui.InvisibleButton('##checker_hud_drag', imgui.ImVec2(-1, -1))
        if imgui.IsItemHovered() or imgui.IsItemActive() or drag.active then
            checkerState.hudHovered = true
        end
        if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
            local delta = imgui.GetMouseDragDelta(0)
            if not drag.active then
                drag.active = true
                drag.startX = wp.x
                drag.startY = wp.y
                imgui.ResetMouseDragDelta(0)
                delta = imgui.GetMouseDragDelta(0)
            end
            drag.offX = drag.startX + delta.x
            drag.offY = drag.startY + delta.y
            drag.offX, drag.offY = checkerClampHudPos(drag.offX, drag.offY, ww, wh)
        elseif drag.active and not imgui.IsMouseDown(0) then
            drag.active = false
            checkerPersistHudPos(wp.x, wp.y, ww, wh, true)
        end

        imgui.End()
    end
    checkerSpTheme.popHudChrome()
end

-- Отрисовка checker UI.
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
    drawSettingsCardHeader('\xCA\xE0\xF2\xE0\xEB\xEE\xE3')
    imgui.TextColored(col_muted2, uiText('\xCE\xED\xEB\xE0\xE9\xED \xE2 HUD \xE1\xE5\xF0\xB8\xF2\xF1\xFF \xE8\xE7 \xF2\xE0\xE1\xE0 (\xF1\xEA\xE0\xED \xE8\xE3\xF0\xEE\xEA\xEE\xE2). \xCA\xE0\xF2\xE0\xEB\xEE\xE3 \xE7\xE0\xE3\xF0\xF3\xE6\xE0\xE5\xF2\xF1\xFF \xF7\xE5\xF0\xE5\xE7 /adms \xE8 /leaders \xEF\xF0\xE8 \xE2\xF5\xEE\xE4\xE5. /admins \xE2 \xF0\xF3\xF7\xED\xF3\xFE \x201 \xF0\xE0\xE7 \x201 \xF3\xF0\xEE\xE2\xED\xFF \xE0\xE4\xEC\xE8\xED\xE0 \xE5\xF1\xEB\xE8 \xEF\xEE\xE2\xFB\xF1\xE8\xEB\xE8.'))
    imgui.TextColored(col_muted2, uiText('\xC8\xE7\xEC\xE5\xED\xE5\xED\xE8\xE5 \xF3\xF0\xEE\xE2\xED\xFF \xF7\xE5\xF0\xE5\xE7 promote-\xF1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5 \xF1\xE5\xF0\xE2\xE5\xF0\xE0.'))
    if imgui.Button(uiText('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE8\xF0\xEE\xE2\xE0\xF2\xFC \xEA\xE0\xF2\xE0\xEB\xEE\xE3 (/adms + /leaders)') .. '##chk_sync_now') then
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
    if deskFormCheckboxRow('\xCE\xF2\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5 (\xE0\xE4\xEC\xE8\xED\xFB \xE8 \xEB\xE8\xE4\xE5\xF0\xFB)', checkerUi.notifyQuit, function(v)
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
