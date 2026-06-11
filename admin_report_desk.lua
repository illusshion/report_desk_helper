--[[ Admin Report Desk — точка входа MoonLoader (/adesk, bundle loader). ]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('3.98.41')
script_description('/adesk \xF0\xE5\xEF\xEE\xF0\xF2\xFB v3, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS', 'mimgui')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

rawset(_G, '__REPORT_DESK_DEV', true)

local deskEnv = nil
local bundleLoadError = nil

-- MoonLoader кэширует require между /reload — сброс spectate-модулей и bundle.
local function prepareDeskReload()
    for _, name in ipairs({
        'report_desk_spectate_stats',
        'report_desk_sp_ui',
        'report_desk_spectate_menu',
        'report_desk_spectate_session',
        'report_desk_spectate_camera',
        'report_desk_sp_theme',
        'report_desk_sp_vehicle_hud',
        'report_desk_sp_keys_hud',
        'report_desk_checker_parser',
        'report_desk_checker_catalog',
    }) do
        package.loaded[name] = nil
    end
    rawset(_G, '__desk_checkerSyncSession', nil)
    rawset(_G, '__desk_pendingCheckerCatalog', nil)
    pcall(function()
        local wm = package.loaded['report_desk_wm_dispatch']
        if wm and wm.uninstall then wm.uninstall() end
    end)
    package.loaded['report_desk_wm_dispatch'] = nil
    local app = package.loaded['report_desk_app']
    if app and app.unload then
        pcall(app.unload)
    end
    package.loaded['report_desk_app'] = nil
    deskEnv = nil
    bundleLoadError = nil
end

local function logBundleError(errText)
    errText = tostring(errText or '')
    print('[Report Desk] core error: ' .. errText)
    pcall(function()
        local path = getWorkingDirectory() .. '\\report_desk_load_error.txt'
        local f = io.open(path, 'w')
        if f then
            f:write(os.date('%Y-%m-%d %H:%M:%S') .. '\n' .. errText .. '\n')
            f:close()
        end
    end)
    if isSampAvailable and isSampAvailable() and sampAddChatMessage then
        pcall(sampAddChatMessage, '{FF6666}[Report Desk] {FFFFFF}ошибка загрузки (см. report_desk_load_error.txt)', 0xE8E8E8)
    end
end

local function ensureDeskBundle()
    if deskEnv then return deskEnv end
    if bundleLoadError then return nil end
    prepareDeskReload()
    local okLoad, loadResult = pcall(function()
        return require('report_desk_app').load()
    end)
    if okLoad then
        deskEnv = loadResult
        pcall(os.remove, getWorkingDirectory() .. '\\report_desk_load_error.txt')
        return deskEnv
    end
    bundleLoadError = tostring(loadResult)
    logBundleError(bundleLoadError)
    return nil
end

-- Главный цикл MoonLoader: init, hooks, poll ingest, autosave.
function main()
    local env = ensureDeskBundle()
    if not env or type(env.main) ~= 'function' then
        print('[Report Desk] не запущен: ошибка загрузки core')
        while true do wait(1000) end
    end
    return env.main()
end

-- Cleanup при выгрузке скрипта.
function onScriptTerminate(scr)
    if scr ~= thisScript() then return end
    local bundleTerminate = deskEnv and rawget(deskEnv, 'onScriptTerminate')
    if type(bundleTerminate) == 'function' then
        bundleTerminate(scr)
    end
    pcall(function()
        local app = package.loaded['report_desk_app']
        if app and app.unload then app.unload() end
    end)
end
