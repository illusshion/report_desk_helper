--[[ Admin Report Desk — точка входа MoonLoader (/reps, bundle loader). ]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('3.98.39')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB v3, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS', 'mimgui')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

-- MoonLoader кэширует require между /reload — сброс spectate-модулей и bundle.
local function prepareDeskReload()
    for _, name in ipairs({
        'report_desk_spectate_stats',
        'report_desk_sp_ui',
        'report_desk_spectate_menu',
        'report_desk_spectate_session',
        'report_desk_spectate_ans',
        'report_desk_spectate_camera',
        'report_desk_sp_theme',
        'report_desk_sp_vehicle_hud',
        'report_desk_checker_parser',
        'report_desk_checker_catalog',
    }) do
        package.loaded[name] = nil
    end
    rawset(_G, '__desk_checkerSyncSession', nil)
    rawset(_G, '__desk_pendingCheckerCatalog', nil)
    local app = package.loaded['report_desk_app']
    if app and app.unload then
        pcall(app.unload)
    end
    package.loaded['report_desk_app'] = nil
end
prepareDeskReload()

local okLoad, loadResult = pcall(function()
    return require('report_desk_app').load()
end)
if not okLoad then
    print('[Report Desk] core error: ' .. tostring(loadResult))
end
local deskEnv = okLoad and loadResult or nil
local runDeskMain = deskEnv and deskEnv.main

-- Главный цикл MoonLoader: init, hooks, poll ingest, autosave.
function main()
    if not okLoad then
        print('[Report Desk] не запущен: ошибка загрузки core (см. moonloader.log)')
        while true do wait(1000) end
    end
    if runDeskMain then return runDeskMain() end
end

-- Cleanup при выгрузке скрипта.
function onScriptTerminate(scr)
    if scr ~= thisScript() then return end
    pcall(function()
        local app = package.loaded['report_desk_app']
        if app and app.unload then app.unload() end
    end)
    local bundleTerminate = deskEnv and rawget(deskEnv, 'onScriptTerminate')
    if type(bundleTerminate) == 'function' then
        bundleTerminate(scr)
    end
end
