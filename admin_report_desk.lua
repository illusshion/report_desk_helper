--[[ Admin Report Desk — entry point (modules in lib/report_desk_*.lua) ]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('3.98.39')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB v3, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS', 'mimgui')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

-- MoonLoader кэширует require между /reload — перезагружаем bundle и spectate-модули.
local function prepareDeskReload()
    for _, name in ipairs({
        'report_desk_spectate_stats',
        'report_desk_sp_ui',
        'report_desk_spectate_menu',
        'report_desk_spectate_session',
        'report_desk_spectate_ans',
        'report_desk_sp_theme',
    }) do
        package.loaded[name] = nil
    end
    local app = package.loaded['report_desk_app']
    if app and app.unload then
        pcall(app.unload)
    end
    package.loaded['report_desk_app'] = nil
end
prepareDeskReload()

local deskEnv = require('report_desk_app').load()
local runDeskMain = deskEnv and deskEnv.main

function main()
    if runDeskMain then return runDeskMain() end
end

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
