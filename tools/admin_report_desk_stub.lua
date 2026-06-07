--[[
    Admin Report Desk — launcher для пользователей (распространение).
    Скопируйте в moonloader как admin_report_desk.lua
    Ядро: report_desk\admin_report_desk_core.luac (качается с GitHub автоматически).
    Исходники и сборка: tools\build_release.ps1, docs\DISTRIBUTION.md
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('1.0.7')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
-- mimgui ставится через report_desk_deps (не в script_dependencies — иначе ML не запустит main)
script_dependencies('SAMP', 'SAMPFUNCS')
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
    -- autoupdate кладёт .lua; старый .luac из zip не должен перекрывать свежее ядро
    local path = nil
    if doesFileExist(CORE_PATH_LUA) then
        path = CORE_PATH_LUA
    elseif doesFileExist(CORE_PATH) then
        path = CORE_PATH
    end
    if not path then
        return nil, 'core not found: ' .. CORE_PATH
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
    local chatSay = autoupdate and autoupdate.chatSay or nil

    local deps = nil
    pcall(function()
        deps = require('report_desk_deps')
    end)
    if deps then
        local depsOk, installed = deps.ensureAll({ say = chatSay })
        if not depsOk then
            return
        end
        if installed and thisScript and thisScript().reload then
            thisScript():reload()
            return
        end
    elseif not (pcall(require, 'mimgui')) then
        if chatSay then
            chatSay('missing mimgui (report_desk_deps.lua)')
        end
        return
    end

    local updateStatus = 'unknown'
    if autoupdate then
        local willReload = false
        pcall(function()
            willReload, updateStatus = autoupdate.check(CORE_PATH)
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
                if autoupdate.chatSay then
                    autoupdate.chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE8: ' .. tostring(err))
                end
                return
            end
            if thisScript and thisScript().reload then
                thisScript():reload()
                return
            end
        else
            if autoupdate and autoupdate.chatSay then
                autoupdate.chatSay('missing report_desk_autoupdate.lua')
            end
            return
        end
    end

    local fn, err = loadCore()
    if not fn then
        if autoupdate and autoupdate.chatSay then
            autoupdate.chatSay(tostring(err))
        end
        return
    end

    local ver = (thisScript and thisScript().version) and tostring(thisScript().version) or '?'
    if autoupdate and autoupdate.chatSay then
        local extra = ''
        if updateStatus == 'uptodate' then
            extra = ', \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xFF \xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xFB'
        elseif updateStatus == 'offline' then
            extra = ', \xEF\xF0\xEE\xE2\xE5\xF0\xEA\xE0 \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE9 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xE0'
        end
        autoupdate.chatSay('\xC7\xE0\xE3\xF0\xF3\xE6\xE5\xED v' .. ver .. extra .. ' (F7)')
    end

    local ok, runErr = pcall(function()
        fn()
        main()
    end)
    if not ok then
        print('[Report Desk] core error: ' .. tostring(runErr))
        if autoupdate and autoupdate.chatSay then
            autoupdate.chatSay('core error (see moonloader.log)')
        end
    end
end
