--[[ Report Desk — publish core locals into shared env for late chunks ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

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
    e.MAX_PLAYER_ID = MAX_PLAYER_ID
    e.findPlayerIdByNick = findPlayerIdByNick
    e.refreshPlayerNickCache = refreshPlayerNickCache
    e.nickKey = nickKey
end
