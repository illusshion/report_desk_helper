--[[
    Admin Report Desk — единая точка входа (AdminDesk.luac).
    Пользователь кладёт только этот файл в moonloader.
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('1.0.27')
script_description('/reps \xF0\xE5\xEF\xEE\xF0\xF2\xFB, \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB, \xE1\xE8\xED\xE4')
script_dependencies('SAMP', 'SAMPFUNCS')
script_moonloader(26)

require 'lib.moonloader'
require 'lib.sampfuncs'

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
    local legacy = root .. '\\admin_report_desk.lua'
    local legacyOff = legacy .. '.off'
    if doesFileExist(root .. '\\AdminDesk.luac') and doesFileExist(legacy) then
        pcall(os.remove, legacyOff)
        pcall(os.rename, legacy, legacyOff)
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

local function devEntryPresent()
    if rawget(_G, '__REPORT_DESK_DEV') == true then return true end
    local path = getWorkingDirectory() .. '\\admin_report_desk.lua'
    if not doesFileExist(path) then return false end
    local f = io.open(path, 'r')
    if not f then return false end
    local head = f:read(8192) or ''
    f:close()
    return head:find('report_desk_app', 1, true) ~= nil
        or head:find('__REPORT_DESK_DEV', 1, true) ~= nil
end

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

local function bootstrapSay(text)
    text = tostring(text or '')
    if text == '' then return end
    print('[Report Desk] ' .. text)
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
    bootstrapSay('\xCF\xE5\xF0\xE2\xFB\xE9 \xE7\xE0\xEF\xF3\xF1\xEA, \xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE0 \xEC\xEE\xE4\xF3\xEB\xE5\xE9...')
    print('[Report Desk] first run — seeding updater modules')
    local root = getWorkingDirectory()
    local tmpJson = root .. '\\report_desk\\_bootstrap_manifest.json'
    ensureDirFor(tmpJson)
    ensureDirFor(libPath('report_desk_autoupdate.lua'))
    local ok, err = downloadWait(MANIFEST_URL, tmpJson, 32, 45)
    if not ok then
        bootstrapSay('\xCE\xF8\xE8\xE1\xEA\xE0 manifest: ' .. tostring(err))
        return false
    end
    local f = io.open(tmpJson, 'r')
    if not f then
        bootstrapSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xF7\xF2\xE5\xED\xE8\xFF manifest')
        return false
    end
    local raw = f:read('*a') or ''
    f:close()
    for _, asset in ipairs(SEED_LIBS) do
        local dest = libPath(asset)
        if not doesFileExist(dest) then
            local url = manifestAssetUrl(raw, asset)
            if not url then
                bootstrapSay('\xED\xE5\xF2 URL: ' .. asset)
                return false
            end
            ok, err = downloadWait(url, dest, 256, 180)
            if not ok then
                bootstrapSay('\xEE\xF8\xE8\xE1\xEA\xE0 ' .. asset .. ': ' .. tostring(err))
                return false
            end
            print('[Report Desk] seeded ' .. asset)
        end
    end
    wait(50)
    if not updaterInstalled() then
        bootstrapSay('\xEC\xEE\xE4\xF3\xEB\xE8 \xED\xE5 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xFB')
        return false
    end
    bootstrapSay('\xEC\xEE\xE4\xF3\xEB\xE8 OK, \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0...')
    return true
end

local function applyPendingBootstrap()
    if not updaterInstalled() then
        return false
    end
    local autoupdate = requireAutoupdate()
    if type(autoupdate) ~= 'table' then return false end
    if autoupdate.applyPendingFiles and autoupdate.applyPendingFiles() then
        print('[Report Desk] pending files applied — reload')
        if thisScript and thisScript().reload then
            thisScript():reload()
            return true
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
        local willReload, status = autoupdate.repair()
        if willReload then return end
        if status == 'fail' and chatSay then
            chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xEF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8 (moonloader.log)')
        elseif status == 'uptodate' and chatSay then
            chatSay('\xC2\xE5\xF0\xF1\xE8\xFF \xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xE0')
        end
    end)
end

local function bootstrapReload(reason)
    print('[Report Desk] reload: ' .. tostring(reason))
    if thisScript and thisScript().reload then
        thisScript():reload()
        return true
    end
    return false
end

local function runInstallPipeline()
    if not bootstrapSeedUpdater() then
        return false
    end

    local autoupdate, autoupdateErr = requireAutoupdate()
    if not autoupdate then
        bootstrapSay(tostring(autoupdateErr or 'autoupdate missing'))
        return false
    end

    local chatSay = autoupdate.chatSay
    registerUpdateCommands(autoupdate, chatSay)

    local manifest, manifestErr = autoupdate.fetchRemoteManifest()
    if not manifest then
        if corePresent() then
            print('[Report Desk] offline, using local core')
            return true
        end
        bootstrapSay('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xEE: ' .. tostring(manifestErr))
        return false
    end

    bootstrapSay('\xC7\xE0\xE3\xF0\xF3\xE7\xEA\xE0 \xEA\xEE\xEC\xEF\xEE\xED\xE5\xED\xF2\xEE\xE2...')
    local willReload, syncStatus = autoupdate.sync(manifest, {
        quietChat = false,
        mode = 'full',
        includeCore = true,
        reload = false,
        showOverlay = true,
    })
    if syncStatus == 'fail' then
        bootstrapSay('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC (/deskrepair)')
        return false
    end
    if willReload then
        if autoupdate.applyPendingFiles then
            autoupdate.applyPendingFiles()
            clearDeskModuleCache()
        end
        bootstrapReload('sync pending')
        return false
    end

    clearDeskModuleCache()
    autoupdate = requireAutoupdate()
    if not autoupdate then
        bootstrapSay('autoupdate lost after sync')
        return false
    end
    chatSay = autoupdate.chatSay
    registerUpdateCommands(autoupdate, chatSay)

    if autoupdate.needsAssets and autoupdate.needsAssets(manifest) then
        bootstrapSay('\xCF\xF0\xE5\xE2\xFC\xFE \xF1\xEA\xE0\xF7\xE0\xE5\xF2\xF1\xFF \xEF\xEE\xF1\xEB\xE5 \xF1\xEF\xE0\xE2\xED\xE0 (~50 \xCC\xE1)')
        if autoupdate.deferAssets then
            autoupdate.deferAssets(manifest, { quietChat = false, showOverlay = true })
        end
    end

    local deps = requireDeps()
    if not deps then
        bootstrapSay('deps module missing')
        return false
    end
    local depsOk = select(1, deps.ensureAll({ say = chatSay, manifest = manifest }))
    if not depsOk then
        bootstrapSay('\xE7\xE0\xE2\xE8\xF1\xE8\xEC\xEE\xF1\xF2\xE8 \xED\xE5 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xFB')
        return false
    end

    if not corePresent() then
        bootstrapSay('\xFF\xE4\xF0\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE (/deskrepair)')
        return false
    end

    return true
end

function main()
    if devEntryPresent() then
        return
    end
    do
        local root = getWorkingDirectory()
        local legacy = root .. '\\admin_report_desk.lua'
        local off = legacy .. '.off'
        if doesFileExist(root .. '\\AdminDesk.luac') and doesFileExist(legacy) then
            pcall(os.remove, off)
            pcall(os.rename, legacy, off)
        end
    end
    if applyPendingBootstrap() then
        return
    end
    while not isSampfuncsLoaded() or not isSampLoaded() do
        wait(100)
    end

    local ok, err = pcall(function()
        if not runInstallPipeline() then
            return
        end

        local autoupdate = requireAutoupdate()
        local fn, loadErr = loadCore()
        if not fn then
            bootstrapSay(tostring(loadErr))
            if autoupdate and autoupdate.repair then
                bootstrapReload('core load fail')
            end
            return
        end

        local ver = (thisScript and thisScript().version) and tostring(thisScript().version) or '?'
        if autoupdate and autoupdate.chatSay then
            local coreVer = autoupdate.readInstalledCoreVersion and autoupdate.readInstalledCoreVersion() or ''
            local label = coreVer ~= '' and ('\xFF\xE4\xF0\xEE v' .. coreVer) or ('bootstrap v' .. ver)
            autoupdate.chatSay('\xC7\xE0\xE3\xF0\xF3\xE6\xE5\xED ' .. label .. ' (F7, /deskupdate)')
        end

        fn()
        main()
    end)

    if not ok then
        bootstrapSay('bootstrap error: ' .. tostring(err))
        print('[Report Desk] bootstrap error: ' .. tostring(err))
    end
end
