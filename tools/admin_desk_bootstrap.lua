--[[
    Admin Report Desk — единая точка входа (AdminDesk.luac).
    Пользователь кладёт только этот файл в moonloader.
]]
script_name('Admin Report Desk')
script_author('ARP Helper')
script_version('1.0.18')
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
end

local function ensureDirFor(path)
    local dir = path:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

local function downloadWait(url, dest, minBytes, timeoutSec)
    if not downloadUrlToFile then return false end
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
    return false
end

local function libPath(name)
    return getWorkingDirectory() .. '\\lib\\' .. name
end

local function updaterInstalled()
    return doesFileExist(libPath('report_desk_autoupdate.lua'))
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

local function bootstrapSeedUpdater()
    if updaterInstalled() then
        return false
    end
    print('[Report Desk] first run — downloading updater modules...')
    local root = getWorkingDirectory()
    local tmpJson = root .. '\\report_desk\\_bootstrap_manifest.json'
    ensureDirFor(tmpJson)
    ensureDirFor(libPath('report_desk_autoupdate.lua'))
    if not downloadWait(MANIFEST_URL, tmpJson, 32, 30) then
        print('[Report Desk] bootstrap: manifest download failed')
        return false
    end
    local f = io.open(tmpJson, 'r')
    if not f then return false end
    local raw = f:read('*a') or ''
    f:close()
    local seeded = false
    for _, asset in ipairs(SEED_LIBS) do
        local dest = libPath(asset)
        if not doesFileExist(dest) then
            local url = manifestAssetUrl(raw, asset)
            if url and downloadWait(url, dest, 256, 120) then
                print('[Report Desk] downloaded ' .. asset)
                seeded = true
            else
                print('[Report Desk] bootstrap: failed ' .. asset)
            end
        end
    end
    if not updaterInstalled() then
        print('[Report Desk] bootstrap: autoupdate module missing after seed')
        return false
    end
    return seeded
end

local function applyPendingBootstrap()
    if not updaterInstalled() then
        return false
    end
    local autoupdate = requireAutoupdate()
    if autoupdate and autoupdate.applyPendingFiles then
        if autoupdate.applyPendingFiles() and thisScript and thisScript().reload then
            thisScript():reload()
            return true
        end
    end
    local scriptPath = (thisScript and thisScript().path) or (getWorkingDirectory() .. '\\AdminDesk.luac')
    local pending = scriptPath .. '.pending'
    if doesFileExist(pending) then
        pcall(os.remove, scriptPath)
        if os.rename(pending, scriptPath) then
            print('[Report Desk] bootstrap updated from pending')
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
        local willReload, status = autoupdate.repair()
        if willReload then return end
        if status == 'fail' and chatSay then
            chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xEF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8 (moonloader.log)')
        elseif status == 'uptodate' and chatSay then
            chatSay('\xC2\xE5\xF0\xF1\xE8\xFF \xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xE0')
        end
    end)
end

function main()
    if devEntryPresent() then
        return
    end
    if applyPendingBootstrap() then
        return
    end
    while not isSampfuncsLoaded() or not isSampLoaded() do
        wait(100)
    end

    if bootstrapSeedUpdater() and thisScript and thisScript().reload then
        thisScript():reload()
        return
    end

    local autoupdate = requireAutoupdate()
    local chatSay = autoupdate and autoupdate.chatSay or nil
    registerUpdateCommands(autoupdate, chatSay)

    if not autoupdate then
        print('[Report Desk] missing lib/report_desk_autoupdate.lua (check moonloader.log)')
        return
    end

    local manifest = select(1, autoupdate.fetchRemoteManifest())
    if not manifest then
        if not corePresent() then
            if chatSay then
                chatSay('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xEE (offline)')
            end
            return
        end
    else
        local willReload = select(1, autoupdate.sync(manifest, {
            quietChat = true,
            mode = 'full',
            includeCore = true,
        }))
        if willReload then
            return
        end
        clearDeskModuleCache()
        autoupdate = requireAutoupdate()
        chatSay = autoupdate and autoupdate.chatSay or chatSay
        registerUpdateCommands(autoupdate, chatSay)

        if autoupdate.needsAssets and autoupdate.needsAssets(manifest) then
            local ok = select(1, autoupdate.ensureAssets(manifest, { quietChat = true }))
            if not ok then
                if chatSay then chatSay('\xCE\xF8\xE8\xE1\xEA\xE0 \xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE8 assets') end
                return
            end
        end
    end

    local deps = requireDeps()
    if deps then
        local depsOk, installed = deps.ensureAll({ say = chatSay, manifest = manifest })
        if not depsOk then
            print('[Report Desk] bootstrap: deps check failed (see chat / moonloader.log)')
            return
        end
        if installed and thisScript and thisScript().reload then
            thisScript():reload()
            return
        end
    end

    if not corePresent() then
        if chatSay then
            chatSay('\xDF\xE4\xF0\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE (/deskrepair)')
        end
        return
    end

    local fn, err = loadCore()
    if not fn then
        if autoupdate.chatSay then
            autoupdate.chatSay(tostring(err))
        end
        if autoupdate.repair then
            print('[Report Desk] core load failed — attempting repair')
            local healed = select(1, autoupdate.repair())
            if healed then return end
        end
        return
    end

    local ver = (thisScript and thisScript().version) and tostring(thisScript().version) or '?'
    if autoupdate.chatSay then
        local coreVer = autoupdate.readInstalledCoreVersion and autoupdate.readInstalledCoreVersion() or ''
        local label = coreVer ~= '' and ('\xFF\xE4\xF0\xEE v' .. coreVer) or ('bootstrap v' .. ver)
        autoupdate.chatSay('\xC7\xE0\xE3\xF0\xF3\xE6\xE5\xED ' .. label .. ' (F7, /deskupdate)')
    end

    local ok, runErr = pcall(function()
        fn()
        main()
    end)
    if not ok then
        print('[Report Desk] core error: ' .. tostring(runErr))
        if autoupdate.chatSay then
            autoupdate.chatSay('core error (see moonloader.log), /deskrepair')
        end
        if autoupdate.repair then
            local healed = select(1, autoupdate.repair())
            if healed then return end
        end
    end
end
