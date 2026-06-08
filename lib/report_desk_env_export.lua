--[[ Модуль: публикация locals в env для late chunk (checker). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

-- Экспорт core locals в env — checker chunk видит imgui, settings, deskCache и т.д.
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
