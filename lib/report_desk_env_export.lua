--[[ Модуль: публикация locals в env для hooks/late chunks (checker). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

-- Экспорт core locals в env — hooks/checker chunks видят imgui, settings, deskCache и т.д.
do
    local e = getfenv(1)
    if type(e) ~= 'table' then return end
    e.imgui = imgui
    e.sampev = sampev
    e.vkeys = vkeys
    e.new = new
    e.sizeof = sizeof
    e.u8 = u8
    e.ffi = ffi
    e.memory = memory
    e.cheat_user32 = cheat_user32
    e.deskVeh = deskVeh
    e.deskGrid = deskGrid
    e.deskTex = deskTex
    e.deskTexPipeline = deskTexPipeline
    e.deskTexLoad = deskTexLoad
    e.deskSpectateStats = deskSpectateStats
    e.deskIngest = deskIngest
    e.settings = settings
    e.deskCache = deskCache
    e.deskInputState = deskInputState
    e.showWindow = showWindow
    e.threads = threads
    e.threadOrder = threadOrder
    e.threadCount = threadCount
    e.MAX_PLAYER_ID = MAX_PLAYER_ID
    e.findPlayerIdByNick = findPlayerIdByNick
    e.refreshPlayerNickCache = refreshPlayerNickCache
    e.nickKey = nickKey
    if type(outbound) ~= 'table' then
        error('[Report Desk] outbound not initialized before env export')
    end
    if type(chatSeen) ~= 'table' then
        error('[Report Desk] chatSeen not initialized before env export')
    end
    e.chatSeen = chatSeen
    e.outbound = outbound
    _G.chatSeen = chatSeen
    _G.outbound = outbound
    e.trim = trim
    e.stripTags = stripTags
    e.stripChatTimestamp = stripChatTimestamp
    e.chatLineSeenKey = chatLineSeenKey
    e.markChatLineSeen = markChatLineSeen
    e.markDirtyThreads = markDirtyThreads
    e.clearPendingOutbound = clearPendingOutbound
    e.tryIngestAdminReplyLine = tryIngestAdminReplyLine
    e.processChatLineIngest = processChatLineIngest
    e.profanityIsLineSeen = profanityIsLineSeen
    e.checkProfanityFromChatLine = checkProfanityFromChatLine
    e.checkProfanityOutgoing = checkProfanityOutgoing
    e.installProfanityHooks = installProfanityHooks
    e.tryInterceptSplitAnsCommand = tryInterceptSplitAnsCommand
    e.handleOutgoingAnsCommand = handleOutgoingAnsCommand
    e.deskLeaveSpectateMode = deskLeaveSpectateMode
    e.deskApplyInputPolicy = deskApplyInputPolicy
    if deskSpectatingNow then _G.deskSpectatingNow = deskSpectatingNow end
    if deskSetPlayerSpectating then _G.deskSetPlayerSpectating = deskSetPlayerSpectating end
    if deskReinstallSpMenuHooks then _G.deskReinstallSpMenuHooks = deskReinstallSpMenuHooks end
    if deskEnsureAllHooks then _G.deskEnsureAllHooks = deskEnsureAllHooks end
    if deskHoldSampChatInput then _G.deskHoldSampChatInput = deskHoldSampChatInput end
    if deskReleaseSampChatInput then _G.deskReleaseSampChatInput = deskReleaseSampChatInput end
    if deskCloseSampChatIfOpen then _G.deskCloseSampChatIfOpen = deskCloseSampChatIfOpen end
    if deskRestoreSampChatIfNeeded then _G.deskRestoreSampChatIfNeeded = deskRestoreSampChatIfNeeded end
    if deskShouldBlockGameInput then _G.deskShouldBlockGameInput = deskShouldBlockGameInput end
    if deskSpectateCameraBlocked then _G.deskSpectateCameraBlocked = deskSpectateCameraBlocked end
    if deskRestoreSpectateCamera then _G.deskRestoreSpectateCamera = deskRestoreSpectateCamera end
    if deskMimguiHideCursor then _G.deskMimguiHideCursor = deskMimguiHideCursor end
    if deskSpectateCameraOwnsInput then _G.deskSpectateCameraOwnsInput = deskSpectateCameraOwnsInput end
    if deskEnableUiCursorForSamp then _G.deskEnableUiCursorForSamp = deskEnableUiCursorForSamp end
    if deskCache then _G.deskCache = deskCache end
end
