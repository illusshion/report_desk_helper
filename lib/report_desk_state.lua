--[[ Модуль: settings, deskCache, threads state, builtin auto-rules. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

--[[
    Встроенные автоответы: keywords только в коде (exact match — целое сообщение).
    В UI настраиваются вкл/выкл и текст ответа.
]]
BUILTIN_AUTO_RULE_TIME = {
    name = 'time',
    match = 'exact',
    keywords = {
        'time', 'vr', 'eshyu', 'eshu',
        '\xE5\xF8\xFCu', '\xE5\xF8\xFC\xF3',
        '\xE2\xF0\xE5\xEC\xFF', '\xE2\xF0\xE5\xEC',
        '\xF2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF', '\xEA\xEE\xF2\xEE\xF0\xFB\xE9 \xF7\xE0\xF1',
        '\xF1\xEA\xEE\xEB\xFC\xEA\xEE \xE2\xF0\xE5\xEC\xE5\xED\xE8', '\xF2\xE5\xEA\xF3\xF9\xE5\xE5 \xE2\xF0\xE5\xEC\xFF',
        '/c 60', '/\xF1 60', '.c 60', '.\xF1 60', 'c 60', '\xF1 60',
    },
    action = 'ans_text',
    cooldown = 60,
    mode = 'instant',
    priority = 0,
    skip_if_report_id = false,
}

BUILTIN_AUTO_RULE_GG = {
    name = 'GG',
    match = 'exact',
    keywords = {
        '\xF1\xEF\xE0\xF1\xE8\xE1\xEE', '\xF1\xEF\xE0\xF1\xE8\xE1', '\xF1\xEF\xF1', '\xF1\xEF\xE0\xF1\xE8\xE1\xEE\xF7\xEA\xE8', '\xF1\xEF\xE0\xF1\xE8\xE1\xEA\xE8',
        '\xF1\xE5\xED\xEA\xF1', '\xF1\xE5\xED\xEA', 'sps', 'gg',
        '\xE1\xEB\xE0\xE3\xEE\xE4\xE0\xF0\xFE', '\xE1\xEB\xE0\xE3\xE4\xE0\xF0\xFE', '\xE1\xEB\xE0\xE3\xE4\xE0\xF0\xE8\xEC', '\xE1\xEB\xE0\xE3\xE4\xE0\xF0\xE8\xEC\xF1\xFF',
        '\xEC\xE5\xF0\xF1\xE8', 'merci',
        'thanks', 'thank you', 'thank u', 'thx', 'ty', 'tyvm', 'thnx', 'thanx',
        'cgfcb', 'cgfcbj', 'cgfcb,j', 'cgfcb j',
        'kfujlfh', 'kfujlfh.',
    },
    action = 'ans_text',
    cooldown = 60,
    mode = 'instant',
    priority = 0,
    skip_if_report_id = false,
}

settings = {
    hotkey = vkeys.VK_F7,
    sound = false,
    auto_only_unread = false,
    watch_notify = 'see',
    watch_auto_notify = true,
    gg_reply = DEFAULT_GG_REPLY,
    time_reply = DEFAULT_TIME_REPLY,
    tech_reply = DEFAULT_TECH_REPLY,
    composer_quick_buttons = nil,
    auto_rules_enabled = true,
    auto_time_enabled = true,
    auto_gg_enabled = true,
    ingest_srv_any_color = false,
    profanity_filter_enabled = true,
    profanity_filter_sound = true,
    profanity_filter_chat = false,
    remote_chat_samp_mirror = true,
    admin_level = 3,
    skin_radius = 20,
    skin_apply_delay_ms = 2500,
    veh_spawn_count = 1,
    veh_grid_rows = 1,
    veh_grid_cols = 5,
    veh_color1 = 0,
    veh_color2 = 0,
    cheats = nil,
    spectate_hud = true,
    spectate_auto_st = true,
    spectate_auto_refresh = true,
    spectate_hud_persist = true,
    spectate_sp_menu_sound = false,
    spectate_hud_x = -233,
    spectate_hud_y = 369,
    spectate_sp_ui = true,
    spectate_sp_ui_x = -28,
    spectate_sp_ui_y = 0,
    spectate_sp_ui_custom = false,
    spectate_hud_layout_v2 = true,
    spectate_sp_ui_layout_v2 = true,
    spectate_vehicle_hud = true,
    spectate_vehicle_hud_x = -12,
    spectate_vehicle_hud_y = -8,
    spectate_keys_hud = true,
    spectate_keys_hud_x = 1234,
    spectate_keys_hud_y = 925,
    spectate_keys_hud_custom = true,
    spectate_vehicle_hud_custom = false,
    spectate_vehicle_hud_layout_v2 = true,
    spectate_vehicle_hud_layout_v3 = true,
    spectate_vehicle_hud_layout_v4 = true,
    spectate_vehicle_hud_layout_v5 = true,
    spectate_vehicle_hud_layout_v6 = true,
    checker_hud = true,
    checker_hud_persist = true,
    checker_hud_x = 32,
    checker_hud_y = 468,
    checker_hud_h = 244,
    checker_show_admins = true,
    checker_show_leaders = true,
    checker_show_friends = true,
    checker_notify_join = true,
    checker_notify_quit = true,
    checker_notify_sound = true,
    checker_auto_sync = true,
    checker_auto_promote = true,
    checker_auto_admin = true,
}

-- Default Cheats Settings
local function defaultCheatsSettings()
    return {
        gm_on_start = false,
        wh_on_start = false,
        ab_speed = 1.0,
        show_hud = true,
        gm_key1 = vkeys.VK_INSERT,
        gm_key2 = 0,
        gm_ctrl = false,
        gm_shift = false,
        gm_alt = false,
        wh_key1 = vkeys.VK_F3,
        wh_key2 = 0,
        wh_ctrl = false,
        wh_shift = false,
        wh_alt = false,
        ab_key1 = vkeys.VK_OEM_COMMA,
        ab_key2 = 0,
        ab_ctrl = false,
        ab_shift = false,
        ab_alt = false,
        marker_wheel = true,
        marker_key1 = vkeys.VK_MBUTTON,
        marker_key2 = 0,
        marker_ctrl = false,
        marker_shift = false,
        marker_alt = false,
        tp_key1 = vkeys.VK_LBUTTON,
        tp_key2 = 0,
        tp_ctrl = false,
        tp_shift = false,
        tp_alt = false,
        veh_key1 = vkeys.VK_RBUTTON,
        veh_key2 = 0,
        veh_ctrl = false,
        veh_shift = false,
        veh_alt = false,
        hud_x = 12,
        hud_y = 80,
    }
end

-- Дефолты и миграция settings.cheats.
function ensureCheatsSettings()
    if type(settings) ~= 'table' then return end
    if type(settings.cheats) ~= 'table' then
        settings.cheats = defaultCheatsSettings()
    end
    local ch = settings.cheats
    local d = defaultCheatsSettings()
    for k, v in pairs(d) do
        if ch[k] == nil then ch[k] = v end
    end
    if ch.wh_ctrl == nil and tonumber(ch.wh_key1) == vkeys.VK_MENU and tonumber(ch.wh_key2) == vkeys.VK_F3 then
        ch.wh_alt = true
        ch.wh_key1 = vkeys.VK_F3
        ch.wh_key2 = 0
    end
    for _, p in ipairs({ 'gm', 'wh', 'ab', 'marker', 'tp', 'veh' }) do
        ch[p .. '_ctrl'] = ch[p .. '_ctrl'] == true
        ch[p .. '_shift'] = ch[p .. '_shift'] == true
        ch[p .. '_alt'] = ch[p .. '_alt'] == true
    end
    ch.ab_speed = math.max(0.05, math.min(3.0, tonumber(ch.ab_speed) or 0.5))
    ch.hud_x = tonumber(ch.hud_x) or 12
    ch.hud_y = tonumber(ch.hud_y) or 80
    ch.gm_on_start = ch.gm_on_start == true or tonumber(ch.gm_on_start) == 1
    ch.wh_on_start = ch.wh_on_start == true or tonumber(ch.wh_on_start) == 1
    ch.show_hud = not (ch.show_hud == false or tonumber(ch.show_hud) == 0)
    ch.marker_wheel = not (ch.marker_wheel == false or tonumber(ch.marker_wheel) == 0)
end
local profanity_words = {}
local DEFAULT_QUICK_SCENARIOS = {
    {
        label = '\xD1\xEE\xE1\xE5\xF1\xE5\xE4\xEE\xE2\xE0\xED\xE8\xE5',
        enabled = true,
        match = 'contains',
        keywords = {
            '\xF1\xEE\xE1\xE5\xF1', '\xF1\xEE\xE1\xE5\xF1\xEE\xE2\xE0\xED', '\xED\xE0\xE1\xEE\xF0',
            '\xEA\xE0\xEA+\xF3\xE7\xED\xE0\xF2\xFC+\xF1\xEE\xE1\xE5\xF1',
        },
        reply = '\xCD\xE0\xE1\xEE\xF0 \xF4\xF0\xE0\xEA\xF6\xE8\xE9: \xF1\xEC. /help \xE8\xEB\xE8 F1. \xCF\xEE\xEC\xEE\xF9\xFC: /gps.',
        action = 'reply',
        priority = 50,
        skip_if_report_id = true,
    },
    {
        label = '\xD1\xEB\xE5\xE4\xE8\xF2\xFC',
        enabled = true,
        match = 'contains',
        keywords = {},
        reply = 'see',
        action = 'watch',
        priority = 60,
        skip_if_report_id = false,
    },
}
local quickScenarios = {}
local threads = {}
local threadOrder = {}
local threadCount = 0

local showWindow = new.bool(false)
local activeTab = new.int(0)
local filterMode = new.int(0)
local searchBuf = new.char[96]()
local replyBuf = new.char[512]()
local cmdBuf = new.char[64]()
local selectedKey = nil
local focusReplyNext = false
local focusReplyReason = nil  -- 'open' | 'select' | 'send'
local pendingAuto = {}
local ruleCooldowns = {}
local deskInputState = {
    replyFocused = false,
    replyInputActive = false,
    keyboardStickyUntil = 0,
    windowOpenSince = 0,
    wasOpen = false,
    playerLocked = false,
    playerSpectating = false,
    spectateWantCursorMode = nil,
    spectateUiModeActive = false,
    panelOpenPrev = false,
    deskUiOpenPrev = false,
    sampChatHeldOff = false,
    chatScrollUntil = 0,
    chatFollowBottom = true,
    chatLastScrollY = nil,
    snapPending = false,
    snapKey = nil,
    hasUnseenMessages = false,
}
local outbound = { pending = nil, fromDesk = nil, selfAns = nil, echo = {} }
local replyUi = { key = nil, at = 0 }
local catWarmup = {
    inited = false, startedAt = 0, timingLogged = false,
    cardW = 480, cardH = 82, bottomPad = 78, hudAnim = 0,
}
local cheatState = {
    godmode = false,
    gmHealthPrimed = false,
    gmHpCmdAt = 0,
    wallhack = false,
    hudDrag = { active = false, startX = 0, startY = 0, offX = 0, offY = 0 },
    hudHovered = false,
    hudPlaced = false,
    hudRect = nil,
    airbreak = false,
    abSpeedLive = nil,
    abKeyHold = { q = { held = false, nextAt = 0 }, e = { held = false, nextAt = 0 } },
    abSpeedFlash = nil,
    ntBackup = nil,
    marker = {
        active = false,
        userMarker = nil,
        aimCar = nil,
        hoverCar = nil,
        dist = 0,
        pos = nil,
        vehLabel = '',
        vehSampId = nil,
    },
    uiMarkerWheel = new.bool(true),
}
local uiCheatGm = new.bool(false)
local uiCheatWh = new.bool(false)
local uiCheatAb = new.bool(false)
local uiCheatGmStart = new.bool(false)
local uiCheatWhStart = new.bool(false)
local uiCheatHud = new.bool(true)
local uiCheatAbSpeed = new.float(1.0)
local cheatsUiSynced = false
local cheatsStartupDone = false
local skinCatalog = nil
local skinCatalogById = {}
local skinUiTabActive = false
local skinTabEntered = false
local skinSelectedId = 1
local skinNearbyCache = { t = 0, n = 0, r = -1 }
local skinLoadFailLogged = false
local skinTargetBuf = new.char[96]()
local skinFilterBuf = new.char[32]()
local skinFiltered = {}
local skinsTabSynced = false
local uiSkinRadius = new.int(20)
local uiAdminLevel = new.int(3)
local skinRadiusJob = { active = false, cancel = false }
local skinApplyCooldownUntil = 0
local SKIN_RADIUS_MIN, SKIN_RADIUS_MAX = 3, 80
local SKIN_RADIUS_MAX_TARGETS = 12  -- макс. игроков skin radius
local SKIN_LIST_MAX_TARGETS = 16
local SKIN_APPLY_COOLDOWN_SEC = 2.0  -- cooldown выдачи скинов, сек
local MOUSE_BIND_VKS = {
    [0x01] = true, [0x02] = true, [0x04] = true, [0x05] = true, [0x06] = true,
}
local rulesEditorDirty = false
local dirtySettings = false
local dirtyThreads = false

local RECENT = {
    ingest = {}, ingestOrd = {},
    auto = {}, autoOrd = {},
    out = {}, outOrd = {},
    prof = {}, profOrd = {},
}
local lastMapPrune = 0
local lastSettingsSave = 0
local lastThreadsSave = 0
local scenariosGen = 0
local cachedSortedScenarioIdx = nil
local cachedSortedScenariosGen = -1
local deskCache = {
    monthRu = {
        January = '\xFF\xED\xE2\xE0\xF0\xFF', February = '\xF4\xE5\xE2\xF0\xE0\xEB\xFF',
        March = '\xEC\xE0\xF0\xF2\xE0', April = '\xE0\xEF\xF0\xE5\xEB\xFF', May = '\xEC\xE0\xFF',
        June = '\xE8\xFE\xED\xFF', July = '\xE8\xFE\xEB\xFF', August = '\xE0\xE2\xE3\xF3\xF1\xF2\xE0',
        September = '\xF1\xE5\xED\xF2\xFF\xE1\xF0\xFF', October = '\xEE\xEA\xF2\xFF\xE1\xF0\xFF',
        November = '\xED\xEE\xFF\xE1\xF0\xFF', December = '\xE4\xE5\xEA\xE0\xE1\xF0\xFF',
    },
    weekdayRu = {
        ['0'] = '\xC2\xEE\xF1\xEA\xF0\xE5\xF1\xE5\xED\xFC\xE5', ['1'] = '\xCF\xEE\xED\xE5\xE4\xE5\xEB\xFC\xED\xE8\xEA',
        ['2'] = '\xC2\xF2\xEE\xF0\xED\xE8\xEA', ['3'] = '\xD1\xF0\xE5\xE4\xE0', ['4'] = '\xD7\xE5\xF2\xE2\xE5\xF0\xE3',
        ['5'] = '\xCF\xFF\xF2\xED\xE8\xF6\xE0', ['6'] = '\xD1\xF3\xE1\xE1\xEE\xF2\xE0',
    },
    hotkeyPrev = {},
    hotkeyLastToggle = 0,
    hotkeyCapture = false,
    hotkeyCaptureAt = 0,
    cheatBindPrev = {},
    cheatCapture = nil,
    cheatCaptureAt = 0,
    cheatCaptureSlot = 'main',
    bindCapVk = nil,
    bindCapIgnoreMouseUntil = 0,
    bindCapPollPrev = nil,
    ui = { kwBulkOpen = {}, panelStart = {}, panelStack = {} },
    filterKeys = nil,
    filterSig = '',
    threadRev = 0,
    threadStructRev = 0,
    threadMsgRev = 0,
    ellipsize = {},
    ellipsizeOrder = {},
    composerQuickItems = nil,
    composerQuickGen = -1,
    nickKeys = {},
    profNorm = {},
    profSet = {},
    remoteChatDedup = {},
    remoteChatDedupOrd = {},
    remoteChatQueue = {},
    sampPlayerColors = {},
    profLineSeen = {},
    profHooksInstalled = false,
    quickBtn = {},
    quickBtnGen = -1,
    catalogTexFlushPending = false,
    skinPrewarmActive = false,
    skinPrewarmTarget = 0,
    skinFilterSig = '',
    skinGridLayoutCache = nil,
    skinGridLayoutSig = '',
    skinGridPage = 1,
    skinPageSig = '',
    serverMsgHandler = nil,
    gamePassVks = { [0x2C] = true, [0x7B] = true },
    specDialogHandler = nil,
    specToggleHandler = nil,
    sendChatHandler = nil,
    sendCommandHandler = nil,
    playerQuitHandler = nil,
    playerJoinHandler = nil,
    playerStreamInHandler = nil,
    playerColorHandler = nil,
    profBubbleHandler = nil,
    profChatHandler = nil,
    hookPrevServerMsg = nil,
    hookPrevShowDialog = nil,
    hookPrevSpecToggle = nil,
    hookPrevSendChat = nil,
    hookPrevSendCommand = nil,
    hookPrevPlayerQuit = nil,
    hookPrevPlayerJoin = nil,
    hookPrevPlayerStreamIn = nil,
    hookPrevPlayerColor = nil,
    hookPrevProfBubble = nil,
    hookPrevProfChat = nil,
    mainPanelFrame = nil,
    deskWindowFrame = nil,
    catalogFlushFrame = nil,
    deskUiFrames = nil,
    spMenuRpcHandler = nil,
    checkerRpcProbeHandler = nil,
    d3dLostHandler = nil,
    d3dResetHandler = nil,
    wm = {
        KEYDOWN = 0x0100,
        KEYUP = 0x0101,
        SYSKEYDOWN = 0x0104,
        SYSKEYUP = 0x0105,
        CHAR = 0x0102,
        LBUTTONDOWN = 0x0201,
        LBUTTONUP = 0x0202,
        RBUTTONDOWN = 0x0204,
        RBUTTONUP = 0x0205,
        MBUTTONDOWN = 0x0207,
        MBUTTONUP = 0x0208,
        MOUSEMOVE = 0x0200,
        MOUSEWHEEL = 0x020A,
        MOUSEHWHEEL = 0x020E,
        XBUTTONDOWN = 0x020B,
        KILLFOCUS = 0x0008,
        CHAT_KEYS = {
            [0x54] = true, [0x49] = true, [0x59] = true, [0x42] = true,
            [0x4F] = true, [0x50] = true, [0x4E] = true, [0xC0] = true, [0x75] = true,
            [0x7A] = true,
        },
        CHAT_CHAR = {
            [0x74] = true, [0x69] = true, [0x79] = true, [0x62] = true,
            [0x6F] = true, [0x70] = true, [0x6E] = true,
        },
        GAME_KEYS = {
            [0x20] = true, [0x09] = true, [0x0D] = true,
            [0x25] = true, [0x26] = true, [0x27] = true, [0x28] = true,
            [0x57] = true, [0x41] = true, [0x53] = true, [0x44] = true,
            [0x51] = true, [0x45] = true, [0x52] = true, [0x46] = true,
            [0x47] = true, [0x48] = true, [0x4A] = true, [0x4B] = true,
            [0x4C] = true, [0x4D] = true, [0x55] = true, [0x56] = true,
            [0x58] = true, [0x5A] = true, [0x31] = true, [0x32] = true,
            [0x33] = true, [0x34] = true, [0x35] = true, [0x36] = true,
            [0x37] = true, [0x38] = true, [0x39] = true,
            [0x70] = true, [0x71] = true, [0x72] = true, [0x73] = true,
            [0x74] = true, [0x75] = true, [0x76] = true,
        },
    },
}

local uiSound = new.bool(false)
local uiAutoOnlyUnread = new.bool(false)
local deskReplyBuf = {
    watch = new.char[256](),
    time = new.char[512](),
    gg = new.char[512](),
    tech = new.char[512](),
}
selectedScenarioIdx = 1
scenariosUiSynced = false
composerQuickSelected = 1
composerQuickUiSynced = false
composerQuickEditorDirty = false
local editCqLabel = new.char[48]()
local editCqText = new.char[512]()
scenariosEditorDirty = false
local editScLabel = new.char[48]()
local editScReply = new.char[512]()
editScMatch = new.int(1)
editScPriority = new.int(0)
editScEnabled = new.bool(true)
editScWatch = new.bool(false)
editScSkipReportId = new.bool(true)
local scKwNew = new.char[96]()
scKwEdit = {}
local scKwBulk = new.char[2048]()
local scTestBuf = new.char[256]()
local scTestResult = new.char[128]()
local uiAutoRulesEnabled = new.bool(true)
local uiAutoTimeEnabled = new.bool(true)
local uiAutoGgEnabled = new.bool(true)
local uiWatchAutoNotify = new.bool(true)
local uiSpecHud = new.bool(true)
local uiSpecAutoSt = new.bool(true)
local uiSpecAutoRefresh = new.bool(true)
local uiSpecHudPersist = new.bool(true)
local uiSpecSpMenuSound = new.bool(false)
local uiSpecVehicleHud = new.bool(true)
local uiSpecKeysHud = new.bool(true)
local uiSpecWheelZoom = new.bool(true)
local uiProfanityFilter = new.bool(true)
local uiRemoteChatSamp = new.bool(true)
local uiProfanitySound = new.bool(true)
editRuleMatch = new.int(1)
editRulePriority = new.int(0)
editRuleSkipReportId = new.bool(true)
local ruleKwBulk = new.char[2048]()
local ruleTestBuf = new.char[256]()
local ruleTestResult = new.char[128]()
rulesTestOpen = new.bool(false)

local AUTO_RETRY_MS = 280  -- retry auto-reply, мс
local AUTO_RETRY_MAX = 4
local AUTO_REPLY_DELAY_MS = 250
local myPlayerNick = ''
local myNickTick = 0
local PLAYER_NICK_CACHE_INTERVAL = 2.0  -- интервал кэша nick→id, сек
local CHAT_UI_RENDER_MAX = 100
local playerNickToId = {}
local playerNickCacheAt = 0
local chatSeen = { lines = {}, order = {}, deferred = {}, consumed = {}, consumedOrder = {} }
local chatLogReady = false
local styleApplied = false
local sessionLive = false
local deskConfigReady = false
local totalUnread = 0

local editRuleName = new.char[64]()
local editRulePayload = new.char[512]()
editRuleCooldown = new.int(120)
editRuleEnabled = new.bool(true)
local ruleKwNew = new.char[96]()
ruleKwEdit = {}
selectedRuleIdx = 1
rulesUiSynced = false
settingsUiSynced = false
deskWantsKeyboard = false
