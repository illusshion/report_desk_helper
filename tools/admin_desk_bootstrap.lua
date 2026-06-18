--[[
    Admin Report Desk — единая точка входа (AdminDesk.luac).
    Пользователь кладёт только этот файл в moonloader.
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('1 Beta.1.9.1')
script_description('/adesk \xF0\xE5\xEF\xEE\xF0\xF2\xFB, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS')
script_moonloader(26)

require 'lib.moonloader'

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
    'report_desk_update_overlay.lua',
    'report_desk_autoupdate.lua',
}

local CORE_NAMES = { 'AdminDeskCore.luac', 'AdminDeskCore.lua', 'admin_report_desk_core.luac', 'admin_report_desk_core.lua' }

local function coreDir()
    return getWorkingDirectory() .. '\\report_desk'
end

local function resolveCorePath()
    local dir = coreDir()
    for _, name in ipairs(CORE_NAMES) do
        local path = dir .. '\\' .. name
        if doesFileExist(path) then
            return path
        end
    end
    return dir .. '\\AdminDeskCore.luac'
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
    local dir = coreDir()
    for _, name in ipairs(CORE_NAMES) do
        if doesFileExist(dir .. '\\' .. name) then
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
local DEFERRED_UPDATE_MSG = '\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xF0\xE5\xF1\xF3\xF0\xF1\xEE\xE2 \xF1\xEA\xE0\xF7\xE0\xE5\xF2\xF1\xFF \xE2 \xF4\xEE\xED\xE5. \xCF\xEE\xF1\xEB\xE5 \xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE8 \xF1\xEA\xF0\xE8\xEF\xF2 \xEF\xE5\xF0\xE5\xE7\xE0\xE3\xF0\xF3\xE7\xE8\xF2\xF1\xFF \xF1\xE0\xEC.'

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

local MINIMAL_SEED_LIBS = {
    'report_desk_sha256.lua',
    'report_desk_zip.lua',
    'report_desk_fs.lua',
}

local SEED_PROGRESS = '\xC7\xE0\xE3\xF0\xF3\xE7\xEA\xE0: '

local function seedOneLib(raw, asset, minBytes, showProgress)
    local dest = libPath(asset)
    if doesFileExist(dest) then
        local df = io.open(dest, 'rb')
        if df then
            local n = df:seek('end') or 0
            df:close()
            if n >= minBytes then
                return true
            end
        end
        pcall(os.remove, dest)
    end
    local url = manifestAssetUrl(raw, asset)
    if not url then
        bootstrapLog('missing url for ' .. asset)
        return false, 'no url'
    end
    if showProgress then
        bootstrapSay(SEED_PROGRESS .. asset)
    end
    bootstrapLog('downloading ' .. asset)
    local ok, err = downloadWait(url, dest, minBytes, 120)
    if not ok then
        return false, err or 'timeout'
    end
    bootstrapLog('seeded ' .. asset)
    return true
end

local function bootstrapExtractMainZip(zipUrl)
    for _, name in ipairs(MINIMAL_SEED_LIBS) do
        local ok, err = preloadLib(name:gsub('%.lua$', ''))
        if not ok then
            bootstrapLog('preload ' .. name .. ': ' .. tostring(err))
            return false
        end
    end
    local deskZip = package.loaded['report_desk_zip']
    if type(deskZip) ~= 'table' or not deskZip.extract then
        bootstrapLog('zip module unavailable')
        return false
    end
    local root = getWorkingDirectory()
    local zipPath = root .. '\\report_desk\\_bootstrap_main.zip'
    ensureDirFor(zipPath)
    bootstrapSay('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 \xEF\xE0\xEA\xE5\xF2\xE0 Report Desk...')
    bootstrapLog('downloading main zip')
    if not downloadWait(zipUrl, zipPath, 1048576, 420) then
        bootstrapLog('main zip download failed')
        pcall(os.remove, zipPath)
        return false
    end
    local ok, err = deskZip.extract(zipPath, root, { yieldEvery = 48 })
    pcall(os.remove, zipPath)
    if not ok then
        bootstrapLog('main zip extract: ' .. tostring(err))
        return false
    end
    return corePresent()
end

local function bootstrapSeedUpdater(firstInstall)
    local root = getWorkingDirectory()
    local tmpJson = root .. '\\report_desk\\_bootstrap_manifest.json'
    ensureDirFor(tmpJson)
    ensureDirFor(libPath('report_desk_autoupdate.lua'))

    if updaterInstalled() and corePresent() and not firstInstall then
        return true
    end

    bootstrapLog('seeding updater (firstInstall=' .. tostring(firstInstall) .. ')')
    local ok, err = downloadWait(MANIFEST_URL, tmpJson, 32, 60)
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

    for _, asset in ipairs(MINIMAL_SEED_LIBS) do
        local seedOk = seedOneLib(raw, asset, 256, firstInstall)
        if not seedOk then
            bootstrapSay(FIRST_RUN_FAIL)
            return false
        end
    end

    if firstInstall and not corePresent() then
        local zipUrl = manifestField(raw, 'zip_url')
        if zipUrl and zipUrl ~= '' then
            if bootstrapExtractMainZip(zipUrl) then
                bootstrapLog('main zip install complete')
                clearDeskModuleCache()
                return true
            end
            bootstrapLog('main zip install failed, falling back to module seed')
        end
    end

    for _, asset in ipairs(SEED_LIBS) do
        if not doesFileExist(libPath(asset)) then
            local seedOk = seedOneLib(raw, asset, 256, firstInstall)
            if not seedOk then
                bootstrapSay(FIRST_RUN_FAIL)
                return false
            end
        end
    end
    wait(50)
    if not updaterInstalled() then
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end
    return true
end

local function isLuaBytecodeFile(path)
    if not doesFileExist(path) then return false end
    local f = io.open(path, 'rb')
    if not f then return false end
    local h1, h2, h3 = f:read(1), f:read(1), f:read(1)
    local size = f:seek('end') or 0
    f:close()
    if size < 128 then return false end
    if not h1 or not h2 or not h3 then return false end
    return h1:byte() == 0x1b and h2:byte() == 0x4c and h3:byte() == 0x4a
end

local function purgeBrokenLauncherPending()
    local root = getWorkingDirectory()
    local pending = root .. '\\AdminDesk.luac.pending'
    if doesFileExist(pending) and not isLuaBytecodeFile(pending) then
        pcall(os.remove, pending)
        print('[Report Desk] removed broken AdminDesk.luac.pending')
    end
end

local function applyLauncherPendingOnStartup()
    if not updaterInstalled() then
        return false
    end
    local ok, applied = pcall(function()
        local autoupdate = requireAutoupdate()
        if type(autoupdate) ~= 'table' or not autoupdate.applyLauncherPending then
            return false
        end
        return autoupdate.applyLauncherPending() == true
    end)
    if not ok then
        print('[Report Desk] launcher pending skipped: ' .. tostring(applied))
        return false
    end
    if applied then
        bootstrapLog('launcher updated — reloading')
        wait(300)
        if thisScript and thisScript().reload then
            thisScript():reload()
        end
    end
    return applied == true
end

local function applyPendingBootstrap()
    if not updaterInstalled() then
        return
    end
    local autoupdate = requireAutoupdate()
    if type(autoupdate) ~= 'table' then return end
    if autoupdate.applyPendingFiles and autoupdate.applyPendingFiles({ includeLauncher = false }) then
        clearDeskModuleCache()
        bootstrapLog('pending module files applied')
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
        if not lua_thread or not lua_thread.create then
            if chatSay then chatSay('repair: lua_thread unavailable') end
            return
        end
        lua_thread.create(function()
            wait(0)
            local okRepair, willReload, status = pcall(function()
                return autoupdate.repair({ quietChat = false, userFacing = true })
            end)
            if not okRepair then
                bootstrapLog('repair: ' .. tostring(willReload))
                if chatSay then
                    chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xEF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8 (moonloader.log)')
                end
                return
            end
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
    end)
end

local function coreLoadLooksBroken(errText)
    errText = tostring(errText or '')
    return errText:find("module 'report_desk_", 1, true) ~= nil
        or errText:find('not found', 1, true) ~= nil
end

local function loadAndRunCore(sessionUpdated, firstInstall)
    local autoupdate = requireAutoupdate()
    local fn, loadErr = loadCore()
    if not fn then
        bootstrapLog(tostring(loadErr))
        bootstrapSay(FIRST_RUN_FAIL)
        return false
    end

    if autoupdate and autoupdate.showWelcomeMessage then
        autoupdate.showWelcomeMessage(nil, {
            firstInstall = firstInstall,
            skipWelcome = sessionUpdated,
        })
    end

    local initOk, initErr = pcall(fn)
    if not initOk and autoupdate and autoupdate.repair and coreLoadLooksBroken(initErr) then
        bootstrapLog('core init: ' .. tostring(initErr))
        bootstrapLog('repairing broken core...')
        local repaired = select(1, autoupdate.repair({
            brokenCore = true,
            quietChat = true,
            userFacing = true,
            showOverlay = true,
            minimalOverlay = true,
        }))
        if repaired then
            clearDeskModuleCache()
            autoupdate = requireAutoupdate()
            fn, loadErr = loadCore()
            if fn then
                initOk, initErr = pcall(fn)
            end
        end
    end
    if not initOk then
        bootstrapLog('core init: ' .. tostring(initErr))
        bootstrapSay(FIRST_RUN_FAIL)
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

    if not bootstrapSeedUpdater(firstInstall) then
        return false, false, firstInstall
    end

    local autoupdate, autoupdateErr = requireAutoupdate()
    if not autoupdate then
        bootstrapLog(tostring(autoupdateErr or 'autoupdate missing'))
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end

    local userOpts = {
        quietChat = true,
        userFacing = true,
        showOverlay = true,
        firstInstall = firstInstall,
        minimalOverlay = true,
    }

    local manifest = autoupdate.fetchRemoteManifest()
    if not manifest then
        if corePresent() then
            bootstrapLog('offline, using local core')
            return true, false, firstInstall
        end
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end

    registerUpdateCommands(autoupdate, autoupdate.chatSay)
    bootstrapLog('checking for updates...')

    local willReload, syncStatus
    if autoupdate.startupSync then
        willReload, syncStatus = autoupdate.startupSync(manifest, userOpts)
    else
        willReload, syncStatus = autoupdate.sync(manifest, {
            mode = 'full',
            includeCore = true,
            reload = true,
        })
    end

    if syncStatus == 'fail' then
        bootstrapSay(FIRST_RUN_FAIL)
        return false, false, firstInstall
    end
    if syncStatus == 'deferred' then
        bootstrapSay(DEFERRED_UPDATE_MSG)
    end
    if willReload or syncStatus == 'reload' then
        return true, true, firstInstall
    end

    clearDeskModuleCache()
    autoupdate = requireAutoupdate()
    registerUpdateCommands(autoupdate, autoupdate.chatSay)

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

    if autoupdate.verifyInstall then
        local ready, missing = autoupdate.verifyInstall(manifest)
        if not ready then
            bootstrapLog('install incomplete: ' .. table.concat(missing, ', '))
            if autoupdate.repair then
                bootstrapLog('repair after incomplete install')
                local repaired = select(1, autoupdate.repair({
                    quietChat = true,
                    userFacing = true,
                    showOverlay = true,
                    minimalOverlay = true,
                }))
                if not repaired then
                    bootstrapSay(FIRST_RUN_FAIL)
                    return false, false, firstInstall
                end
                clearDeskModuleCache()
                autoupdate = requireAutoupdate()
            end
        end
    end

    if firstInstall and syncStatus == 'uptodate' then
        bootstrapSay(FIRST_RUN_READY)
    end

    return true, syncStatus == 'updated', firstInstall
end

function main()
    if devEntryPresent() then
        return
    end
    purgeBrokenLauncherPending()
    if applyLauncherPendingOnStartup() then
        return
    end
    while not isSampfuncsLoaded() or not isSampLoaded() do
        wait(100)
    end
    local okSf, errSf = pcall(require, 'lib.sampfuncs')
    if not okSf then
        print('[Report Desk] SAMPFUNCS required: ' .. tostring(errSf))
        return
    end
    pcall(applyPendingBootstrap)

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
