--[[
    Admin Report Desk — launcher для пользователей (распространение).
    Скопируйте в moonloader как admin_report_desk.lua
    Ядро: report_desk\admin_report_desk_core.luac (качается с GitHub автоматически).
    Исходники и сборка: tools\build_release.ps1, docs\DISTRIBUTION.md
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('3.49.12')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS', 'mimgui')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

-- Полный исходник admin_report_desk.lua в moonloader — не грузить ядро повторно (двойные хуки /sp).
local function fullDeskSourcePresent()
    local path = getWorkingDirectory() .. '\\admin_report_desk.lua'
    if not doesFileExist(path) then return false end
    local f = io.open(path, 'r')
    if not f then return false end
    local head = f:read(12000) or ''
    f:close()
    if head:find('loadCore', 1, true) or head:find('admin_report_desk_core', 1, true) then
        return false
    end
    if head:find('report_desk_app', 1, true) then
        return true
    end
    return head:find('function drawMainWindow', 1, true) ~= nil
        or head:find('function deskApplyInputPolicy', 1, true) ~= nil
end

local CORE_DIR = getWorkingDirectory() .. '\\report_desk'
local CORE_PATH = CORE_DIR .. '\\admin_report_desk_core.luac'
local CORE_PATH_LUA = CORE_DIR .. '\\admin_report_desk_core.lua'

local function loadCore()
    local path = doesFileExist(CORE_PATH) and CORE_PATH or CORE_PATH_LUA
    if not doesFileExist(path) then
        return nil, 'core not found: ' .. path
    end
    local fn, err = loadfile(path)
    if not fn then
        return nil, err or 'loadfile failed'
    end
    return fn
end

function main()
    if fullDeskSourcePresent() then
        return
    end
    if not isSampfuncsLoaded() or not isSampLoaded() then
        return
    end
    while not isSampAvailable() do
        wait(100)
    end

    local autoupdate = nil
    pcall(function()
        autoupdate = require('report_desk_autoupdate')
    end)

    if autoupdate then
        local willReload = false
        pcall(function()
            willReload = autoupdate.check(CORE_PATH) == true
        end)
        if willReload then
            return
        end
    end

    if not doesFileExist(CORE_PATH) and not doesFileExist(CORE_PATH_LUA) then
        if autoupdate then
            print('[Report Desk] first run — downloading core…')
            local ok, err = autoupdate.forceDownload(CORE_PATH)
            if not ok then
                sampAddChatMessage('{FF6060}[Report Desk] update failed: ' .. tostring(err), -1)
                return
            end
            if thisScript and thisScript().reload then
                thisScript():reload()
                return
            end
        else
            sampAddChatMessage('{FF6060}[Report Desk] missing report_desk_autoupdate.lua', -1)
            return
        end
    end

    local fn, err = loadCore()
    if not fn then
        sampAddChatMessage('{FF6060}[Report Desk] ' .. tostring(err), -1)
        return
    end

    local ok, runErr = pcall(function()
        fn()
        main()
    end)
    if not ok then
        print('[Report Desk] core error: ' .. tostring(runErr))
        sampAddChatMessage('{FF6060}[Report Desk] core error (see moonloader.log)', -1)
    end
end
