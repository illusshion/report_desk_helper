--[[
    Admin Report Desk — единая точка входа (AdminDesk.luac).
    Пользователь кладёт только этот файл в moonloader.
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('1 Beta')
script_description('/adesk \xF0\xE5\xEF\xEE\xF0\xF2\xFB, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

local function readDevEntryHead(path)
    if type(doesFileExist) ~= 'function' or not doesFileExist(path) then return nil end
    local f = io.open(path, 'r')
    if not f then return nil end
    local head = f:read(8192) or ''
    f:close()
    return head
end

local function devEntryHeadLooksDev(head)
    if not head or head == '' then return false end
    return head:find('report_desk_app', 1, true) ~= nil
        or head:find('__REPORT_DESK_DEV', 1, true) ~= nil
end

local function devEntryPresent()
    if rawget(_G, '__REPORT_DESK_DEV') == true then return true end
    local root = getWorkingDirectory()
    for _, name in ipairs({ 'admin_report_desk.lua', 'admin_report_desk.lua.off' }) do
        if devEntryHeadLooksDev(readDevEntryHead(root .. '\\' .. name)) then
            return true
        end
    end
    return false
end

do
    if not devEntryPresent() then
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
end

local MANIFEST_URL = 'https://raw.githubusercontent.com/illusshion/report_desk_helper/main/release/version.json'
local SEED_LIBS = {
    'report_desk_sha256.lua',
    'report_desk_zip.lua',
    'report_desk_fs.lua',
    'report_desk_deps.lua',
    'report_desk_autoupdate.lua',
}

local CORE_DIR = getWorkingDirectory() .. '\\report_desk'
local CORE_NAMES = { 'AdminDeskCore.luac', 'AdminDeskCore.lua', 'admin_report_desk_core.luac', 'admin_report_desk_core.lua' }

local function resolveCorePath()
    for _, name in ipairs(CORE_NAMES) do
        local path = CORE_DIR .. '\\' .. name
        if doesFileExist(path) then
            return path
        end
    end
    return CORE_DIR .. '\\AdminDeskCore.luac'
end

local function loadCore()
    local path = resolveCorePath()
    if not doesFileExist(path) then
        return nil, 'core not found: ' .. path
    end
    local fn, err = loadfile(path)
    if not fn then
        return nil, err or 'loadfile failed'
    end
    return fn
end

local function corePresent()
    for _, name in ipairs(CORE_NAMES) do
        if doesFileExist(CORE_DIR .. '\\' .. name) then
            return true
        end
    end
    return false
end

local function clearDeskModuleCache()
    package.loaded['lib.report_desk_autoupdate'] = nil
    package.loaded['lib.report_desk_deps'] = nil
    package.loaded['report_desk_autoupdate'] = nil
    package.loaded['report_desk_deps'] = nil
    package.loaded['report_desk_sha256'] = nil
    package.loaded['report_desk_zip'] = nil
    package.loaded['report_desk_fs'] = nil
    package.loaded.mimgui = nil
end

local function ensureDirFor(path)
    local dir = path:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

local function libPath(name)
    return getWorkingDirectory() .. '\\lib\\' .. name
end

local function updaterInstalled()
    return doesFileExist(libPath('report_desk_autoupdate.lua'))
end

local FIRST_RUN_INTRO = '\xD6\xF2\xEE \xE2\xE0\xF8 \xEF\xE5\xF0\xE2\xFB\xE9 \xE7\xE0\xEF\xF3\xF1\xEA. \xCF\xF0\xEE\xE2\xE5\xF0\xFE \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xFF \xE8 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xFE \xE2\xF1\xB8 \xED\xF3\xE6\xED\xEE\xE5. \xC2\xEE\xE7\xEC\xEE\xE6\xED\xE0 \xEF\xF0\xEE\xF1\xE0\xE4\xEA\xE0 FPS \xED\xE0 \xEF\xE0\xF0\xF3 \xF1\xE5\xEA\xF3\xED\xE4 \xB7 \xFD\xF2\xEE \xED\xEE\xF0\xEC\xE0\xEB\xFC\xED\xEE.'
local FIRST_RUN_FAIL = '\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xF3\xF1\xF2\xE0\xED\xEE\xE2\xE8\xF2\xFC. \xCF\xF0\xEE\xE2\xE5\xF0\xFC\xF2\xE5 \xE8\xED\xF2\xE5\xF0\xED\xE5\xF2 \xE8 \xEF\xEE\xEF\xF0\xEE\xE1\xF3\xE9\xF2\xE5 /deskrepair'
local FIRST_RUN_READY = '\xC3\xEE\xF2\xEE\xE2\xEE! \xCE\xF2\xEA\xF0\xEE\xE9\xF2\xE5 \xEE\xEA\xED\xEE \xEA\xEE\xEC\xE0\xED\xE4\xEE\xE9 /adesk'

local function bootstrapLog(text)
    print('[Report Desk] ' .. tostring(text or ''))
end

local function bootstrapSay(text)
    text = tostring(text or '')
    if text == '' then return end
    bootstrapLog(text)
    if isSampAvailable and isSampAvailable() and sampAddChatMessage then
        pcall(sampAddChatMessage, '{9E7BEF}[Report Desk] {FFFFFF}' .. text, 0xE8E8E8)
    end
end

local function downloadWait(url, dest, minBytes, timeoutSec)
    if not downloadUrlToFile then return false, 'no downloadUrlToFile' end
    minBytes = minBytes or 256
    ensureDirFor(dest)
    if doesFileExist(dest) then pcall(os.remove, dest) end
    downloadUrlToFile(url, dest)
    local deadline = os.clock() + (timeoutSec or 60)
    while os.clock() < deadline do
        if doesFileExist(dest) then
            local f = io.open(dest, 'rb')
            if f then
                local n = f:seek('end') or 0
                f:close()
                if n >= minBytes then return true end
            end
        end
        wait(100)
    end
    return false, 'timeout'
end

local function manifestField(raw, key)
    return raw:match('"' .. key .. '"%s*:%s*"([^"]+)"')
end

local function manifestAssetUrl(raw, asset)
    local esc = asset:gsub('([%.%-])', '%%%1')
    local url = raw:match('"' .. esc .. '"%s*:%s*{[^}]-"url"%s*:%s*"([^"]+)"')
    if url and url ~= '' then return url end
    local base = manifestField(raw, 'release_base')
    if base and base ~= '' then
        return base .. '/' .. asset
    end
    return nil
end

local function preloadLib(name)
    package.loaded[name] = nil
    local ok, err = pcall(require, name)
    if not ok then
        return false, tostring(err)
    end
    return true
end

local function requireAutoupdate()
    clearDeskModuleCache()
    for _, name in ipairs({ 'report_desk_sha256', 'report_desk_fs', 'report_desk_zip' }) do
        if doesFileExist(libPath(name .. '.lua')) then
            local ok, err = preloadLib(name)
            if not ok then
                return nil, 'preload ' .. name .. ': ' .. err
            end
        end
    end
    local ok, mod = pcall(require, 'lib.report_desk_autoupdate')
    if ok then return mod end
    ok, mod = pcall(require, 'report_desk_autoupdate')
    if ok then return mod end
    return nil, 'require autoupdate failed'
end

local function requireDeps()
    local ok, mod = pcall(require, 'lib.report_desk_deps')
    if ok then return mod end
    ok, mod = pcall(require, 'report_desk_deps')
    if ok then return mod end
    return nil
end

local function bootstrapSeedUpdater()
    if updaterInstalled() then
        return true
    end
    bootstrapLog('first run — seeding updater modules')
    local root = getWorkingDirectory()
    local tmpJson = root .. '\\report_desk\\_bootstrap_manifest.json'
    ensureDirFor(tmpJson)
    ensureDirFor(libPath('report_desk_autoupdate.lua'))
    local ok, err = downloadWait(MANIFEST_URL, tmpJson, 32, 45)
    if not ok then
        bootstrapLog('manifest download failed: ' .. tostring(err))
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end
    local f = io.open(tmpJson, 'r')
    if not f then
        bootstrapLog('manifest read failed')
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end
    local raw = f:read('*a') or ''
    f:close()
    for _, asset in ipairs(SEED_LIBS) do
        local dest = libPath(asset)
        if not doesFileExist(dest) then
            local url = manifestAssetUrl(raw, asset)
            if not url then
                bootstrapLog('missing url for ' .. asset)
                bootstrapSay(FIRST_RUN_FAIL)
                return false
            end
            ok, err = downloadWait(url, dest, 256, 180)
            if not ok then
                bootstrapLog('seed failed ' .. asset .. ': ' .. tostring(err))
                bootstrapSay(FIRST_RUN_FAIL)
                return false
            end
            bootstrapLog('seeded ' .. asset)
        end
    end
    wait(50)
    if not updaterInstalled() then
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end
    return true
end

local function stageLauncherPendingOnDisk()
    if not updaterInstalled() then
        return
    end
    local autoupdate = requireAutoupdate()
    if type(autoupdate) ~= 'table' or not autoupdate.applyLauncherPending then
        return
    end
    if autoupdate.applyLauncherPending() then
        print('[Report Desk] launcher committed on disk (picked up on next game start)')
    end
end

local function applyPendingBootstrap()
    if not updaterInstalled() then
        return
    end
    local autoupdate = requireAutoupdate()
    if type(autoupdate) ~= 'table' then return end
    if autoupdate.applyPendingFiles and autoupdate.applyPendingFiles({ includeLauncher = false }) then
        clearDeskModuleCache()
        print('[Report Desk] pending module files applied')
    end
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
        local willReload, status = autoupdate.repair()
        if willReload then
            clearDeskModuleCache()
            local pipelineOk, updated, firstInstall = runInstallPipeline()
            if pipelineOk then
                loadAndRunCore(updated, firstInstall)
            end
            return
        end
        if status == 'fail' and chatSay then
            chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xEF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8 (moonloader.log)')
        elseif status == 'uptodate' and chatSay then
            chatSay('\xC2\xE5\xF0\xF1\xE8\xFF \xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xE0')
        end
    end)
end

local function bootstrapReload(reason)
    bootstrapLog('reload: ' .. tostring(reason))
    wait(2000)
    if thisScript and thisScript().reload then
        thisScript():reload()
        return true
    end
    return false
end

local function loadAndRunCore(sessionUpdated, firstInstall)
    local autoupdate = requireAutoupdate()
    local fn, loadErr = loadCore()
    if not fn then
        bootstrapLog(tostring(loadErr))
        bootstrapSay(FIRST_RUN_FAIL)
        if autoupdate and autoupdate.repair then
            bootstrapReload('core load fail')
        end
        return false
    end

    if autoupdate and autoupdate.showWelcomeMessage then
        autoupdate.showWelcomeMessage(nil, {
            firstInstall = firstInstall,
            skipWelcome = sessionUpdated,
        })
    end

    local initOk, initErr = pcall(fn)
    if not initOk then
        bootstrapLog('core init: ' .. tostring(initErr))
        bootstrapSay(FIRST_RUN_FAIL)
        if autoupdate and autoupdate.repair then
            bootstrapReload('core init fail')
        end
        return false
    end

    if type(main) ~= 'function' then
        bootstrapLog('core main missing after init')
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end

    local mainOk, mainErr = pcall(main)
    if not mainOk then
        bootstrapLog('core main: ' .. tostring(mainErr))
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end
    return true
end

local function runInstallPipeline()
    local firstInstall = not corePresent()
    if firstInstall then
        bootstrapSay(FIRST_RUN_INTRO)
    end

    if not bootstrapSeedUpdater() then
        return false, false, firstInstall
    end

    local autoupdate, autoupdateErr = requireAutoupdate()
    if not autoupdate then
        bootstrapLog(tostring(autoupdateErr or 'autoupdate missing'))
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end

    local chatSay = autoupdate.chatSay
    registerUpdateCommands(autoupdate, chatSay)

    local userOpts = {
        quietChat = true,
        userFacing = true,
        showOverlay = true,
        firstInstall = firstInstall,
        minimalOverlay = true,
    }

    local manifest, manifestErr = autoupdate.fetchRemoteManifest()
    if not manifest then
        if corePresent() then
            bootstrapLog('offline, using local core')
            return true, false, firstInstall
        end
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end

    bootstrapLog('checking for updates...')
    local willReload, syncStatus = autoupdate.sync(manifest, {
        mode = 'full',
        includeCore = true,
        reload = false,
        quietChat = true,
        userFacing = true,
        showOverlay = true,
        firstInstall = firstInstall,
        minimalOverlay = true,
    })
    local sessionUpdated = syncStatus == 'updated' or syncStatus == 'pending'
    if syncStatus == 'fail' then
        return false, false, firstInstall
    end
    if willReload then
        print('[Report Desk] update applied, loading core in same session')
        if autoupdate.applyPendingFiles then
            autoupdate.applyPendingFiles({ includeLauncher = false })
            clearDeskModuleCache()
        end
    end

    clearDeskModuleCache()
    autoupdate = requireAutoupdate()
    if not autoupdate then
        bootstrapLog('autoupdate lost after sync')
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end
    chatSay = autoupdate.chatSay
    registerUpdateCommands(autoupdate, chatSay)

    local deps = requireDeps()
    if not deps then
        bootstrapLog('deps module missing')
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end
    local depsOk = select(1, deps.ensureAll({
        manifest = manifest,
        quietChat = true,
        userFacing = true,
        showOverlay = true,
        firstInstall = firstInstall,
        minimalOverlay = true,
    }))
    if not depsOk then
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end

    if not corePresent() then
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end

    if autoupdate.hideUpdateOverlay then
        pcall(autoupdate.hideUpdateOverlay)
    end

    if autoupdate.reconcileAssetsState then
        pcall(autoupdate.reconcileAssetsState, manifest)
    end

    if firstInstall and not sessionUpdated then
        bootstrapSay(FIRST_RUN_READY)
    end

    if autoupdate.deferAssets then
        autoupdate.deferAssets(manifest, userOpts)
    end

    return true, sessionUpdated, firstInstall
end

function main()
    if devEntryPresent() then
        return
    end
    stageLauncherPendingOnDisk()
    applyPendingBootstrap()
    while not isSampfuncsLoaded() or not isSampLoaded() do
        wait(100)
    end

    local ok, err = pcall(function()
        local pipelineOk, sessionUpdated, firstInstall = runInstallPipeline()
        if not pipelineOk then
            return
        end
        loadAndRunCore(sessionUpdated, firstInstall)
    end)

    if not ok then
        bootstrapLog('bootstrap error: ' .. tostring(err))
        bootstrapSay(FIRST_RUN_FAIL)
    end
end
