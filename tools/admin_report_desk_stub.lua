--[[
    Admin Report Desk — launcher для пользователей (распространение).
    Скопируйте в moonloader как admin_report_desk.lua
    Ядро: report_desk\admin_report_desk_core.lua (качается с GitHub автоматически).
    Исходники и сборка: tools\build_release.ps1, docs\DISTRIBUTION.md
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('1.0.14')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
-- mimgui ставится через report_desk_deps (не в script_dependencies — иначе ML не запустит main)
script_dependencies('SAMP', 'SAMPFUNCS')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

-- Старые zip клали deps/autoupdate в корень moonloader — ML грузит их как отдельные скрипты.
-- Отключаем ДО загрузки остальных .lua (admin_report_desk грузится первым по алфавиту).
do
    local root = getWorkingDirectory()
    for _, name in ipairs({ 'report_desk_deps.lua', 'report_desk_autoupdate.lua' }) do
        local path = root .. '\\' .. name
        local off = path .. '.off'
        if doesFileExist(path) then
            pcall(os.remove, off)
            pcall(os.rename, path, off)
        end
    end
end

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

local function clearDeskModuleCache()
    package.loaded['lib.report_desk_autoupdate'] = nil
    package.loaded['lib.report_desk_deps'] = nil
    package.loaded['report_desk_autoupdate'] = nil
    package.loaded['report_desk_deps'] = nil
end

local function requireAutoupdate()
    clearDeskModuleCache()
    local ok, mod = pcall(require, 'lib.report_desk_autoupdate')
    if ok then return mod end
    ok, mod = pcall(require, 'report_desk_autoupdate')
    if ok then return mod end
    return nil
end

local function requireDeps()
    clearDeskModuleCache()
    local ok, mod = pcall(require, 'lib.report_desk_deps')
    if ok then return mod end
    ok, mod = pcall(require, 'report_desk_deps')
    if ok then return mod end
    return nil
end

local function applyPendingLauncher()
    local autoupdate = requireAutoupdate()
    if autoupdate and autoupdate.applyPendingFiles then
        if autoupdate.applyPendingFiles() and thisScript and thisScript().reload then
            thisScript():reload()
            return true
        end
    end
    local root = getWorkingDirectory()
    local pending = root .. '\\admin_report_desk.lua.pending'
    local launcher = root .. '\\admin_report_desk.lua'
    if doesFileExist(pending) then
        pcall(os.remove, launcher)
        if os.rename(pending, launcher) then
            print('[Report Desk] launcher updated from pending')
            if thisScript and thisScript().reload then
                thisScript():reload()
                return true
            end
        end
    end
    return false
end

local function registerUpdateCommands(autoupdate, chatSay)
    if not sampRegisterChatCommand or not autoupdate then return end
    sampRegisterChatCommand('deskupdate', function()
        if autoupdate.printDiagnostics then
            autoupdate.printDiagnostics()
        elseif chatSay then
            chatSay('autoupdate unavailable')
        end
    end)
    sampRegisterChatCommand('deskrepair', function()
        if not autoupdate.repair then
            if chatSay then chatSay('repair unavailable') end
            return
        end
        if chatSay then
            chatSay('\xCF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 \xE2\xE5\xF0\xF1\xE8\xE8...')
        end
        local runRepair = function()
            local willReload, status = autoupdate.repair()
            if willReload then return end
            if status == 'fail' and chatSay then
                chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xEF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8 (moonloader.log)')
            elseif status == 'uptodate' and chatSay then
                chatSay('\xC2\xE5\xF0\xF1\xE8\xFF \xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xE0')
            end
        end
        if lua_thread and lua_thread.create then
            lua_thread.create(runRepair)
        else
            runRepair()
        end
    end)
end

function main()
    if fullDeskSourcePresent() then
        return
    end
    if applyPendingLauncher() then
        return
    end
    while not isSampfuncsLoaded() or not isSampLoaded() do
        wait(100)
    end

    local autoupdate = requireAutoupdate()
    local chatSay = autoupdate and autoupdate.chatSay or nil
    registerUpdateCommands(autoupdate, chatSay)

    local manifest = nil
    if autoupdate and autoupdate.fetchRemoteManifest then
        manifest = select(1, autoupdate.fetchRemoteManifest())
        if manifest and autoupdate.ensureBootstrap then
            local bootstrapReload = select(1, autoupdate.ensureBootstrap(manifest, { quietChat = true }))
            if bootstrapReload then
                return
            end
            clearDeskModuleCache()
            autoupdate = requireAutoupdate()
            chatSay = autoupdate and autoupdate.chatSay or chatSay
            registerUpdateCommands(autoupdate, chatSay)
        end
    end

    local deps = requireDeps()
    if deps then
        local depsOk, installed = deps.ensureAll({ say = chatSay, manifest = manifest })
        if not depsOk then
            print('[Report Desk] launcher: deps check failed (see chat / moonloader.log)')
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

    if autoupdate and manifest and autoupdate.ensureIconvDll then
        pcall(function()
            autoupdate.ensureIconvDll(manifest, { quietChat = true })
        end)
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
            if chatSay then
                chatSay('missing report_desk_autoupdate.lua')
            end
            return
        end
    end

    local fn, err = loadCore()
    if not fn then
        if autoupdate and autoupdate.chatSay then
            autoupdate.chatSay(tostring(err))
        end
        if autoupdate and autoupdate.repair then
            print('[Report Desk] core load failed — attempting repair')
            local healed = select(1, autoupdate.repair())
            if healed then return end
        end
        return
    end

    local ver = (thisScript and thisScript().version) and tostring(thisScript().version) or '?'
    if autoupdate and autoupdate.chatSay then
        local coreVer = autoupdate.readInstalledCoreVersion and autoupdate.readInstalledCoreVersion() or ''
        local extra = ''
        if updateStatus == 'uptodate' then
            extra = ', \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xFF \xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xFB'
        elseif updateStatus == 'offline' then
            extra = ', \xEF\xF0\xEE\xE2\xE5\xF0\xEA\xE0 \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE9 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xE0'
        elseif updateStatus == 'fail' then
            extra = ', \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5 \xE7\xE0\xE3\xF0\xF3\xE7\xE8\xEB\xEE\xF1\xFC'
        end
        local label = coreVer ~= '' and ('\xFF\xE4\xF0\xEE v' .. coreVer) or ('launcher v' .. ver)
        autoupdate.chatSay('\xC7\xE0\xE3\xF0\xF3\xE6\xE5\xED ' .. label .. extra .. ' (F7, /deskupdate)')
    end

    local ok, runErr = pcall(function()
        fn()
        main()
    end)
    if not ok then
        print('[Report Desk] core error: ' .. tostring(runErr))
        if autoupdate and autoupdate.chatSay then
            autoupdate.chatSay('core error (see moonloader.log), /deskrepair')
        end
        if autoupdate and autoupdate.repair then
            local healed = select(1, autoupdate.repair())
            if healed then return end
        end
    end
end
