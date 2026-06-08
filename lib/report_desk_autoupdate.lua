--[[
    GitHub auto-update для Admin Report Desk (тонкий launcher → core.luac).
    Перед публикацией укажите URL в release/repo.config.json и пересоберите release/version.json.
]]
pcall(function()
    if not getWorkingDirectory or not doesFileExist then return end
    local root = getWorkingDirectory()
    for _, name in ipairs({ 'report_desk_deps.lua', 'report_desk_autoupdate.lua' }) do
        local path = root .. '\\' .. name
        local off = path .. '.off'
        if doesFileExist(path) then
            pcall(os.remove, off)
            pcall(os.rename, path, off)
        end
    end
end)

local M = {}

M.VERSION_JSON_URL = 'https://raw.githubusercontent.com/illusshion/report_desk_helper/main/release/version.json'
M.CHAT_PREFIX = '{9E7BEF}[Report Desk] {FFFFFF}'
M.CHAT_COLOR = 0xE8E8E8
M.RUNTIME_LIBS_ZIP = 'report_desk_runtime_libs.zip'
M.ICONV_DLL = 'lib\\iconv.dll'
M.LATEST_RELEASE_BASE = 'https://github.com/illusshion/report_desk_helper/releases/latest/download'

-- Log
local function log(msg)
    print('[Report Desk] update: ' .. tostring(msg))
end

-- Публичный API модуля.
function M.chatSay(text)
    text = tostring(text or '')
    if text == '' then return end
    print('[Report Desk] ' .. text)
    if not isSampAvailable or not isSampAvailable() or not sampAddChatMessage then return end
    pcall(sampAddChatMessage, M.CHAT_PREFIX .. text, M.CHAT_COLOR)
end

-- Notify
local function notify(msg, opts)
    opts = opts or {}
    log(msg)
    if opts.quietChat then return end
    M.chatSay(msg)
end

-- Публичный API модуля.
function M.root()
    return getWorkingDirectory()
end

-- Публичный API модуля.
function M.path(rel)
    return M.root() .. '\\' .. tostring(rel or ''):gsub('/', '\\')
end

-- Ps Literal
local function psLiteral(s)
    s = tostring(s or ''):gsub("'", "''")
    return "'" .. s .. "'"
end

-- Публичный API модуля.
function M.parseVersion(v)
    v = tostring(v or ''):gsub('^v', '')
    local major, minor, patch, pre = v:match('^(%d+)%.(%d+)%.(%d+)(%-(.+))?$')
    if not major then
        return 0
    end
    local base = tonumber(major) * 1000000 + tonumber(minor) * 1000 + tonumber(patch)
    if not pre or pre == '' then
        return base
    end
    pre = pre:gsub('^%-', '')
    local beta = pre:match('^beta%.(%d+)$')
    if beta then
        local n = tonumber(beta) or 0
        if n < 0 then n = 0 end
        if n > 9999 then n = 9999 end
        return base - 10000 + n
    end
    return base - 5000
end

-- Публичный API модуля.
function M.readLocalVersion()
    if thisScript and thisScript().version then
        return tostring(thisScript().version)
    end
    return '0.0.0'
end

-- Публичный API модуля.
function M.downloadSync(url, dest, timeoutSec, minBytes)
    if not downloadUrlToFile then
        return false, 'downloadUrlToFile unavailable'
    end
    minBytes = tonumber(minBytes) or 64
    if doesFileExist(dest) then
        os.remove(dest)
    end
    downloadUrlToFile(url, dest)
    local deadline = os.clock() + (timeoutSec or 45)
    while os.clock() < deadline do
        if doesFileExist(dest) then
            local f = io.open(dest, 'rb')
            if f then
                local n = f:seek('end') or 0
                f:close()
                if n >= minBytes then
                    return true
                end
            end
        end
        wait(100)
    end
    if doesFileExist(dest) then
        pcall(os.remove, dest)
    end
    return false, 'timeout'
end

-- Публичный API модуля.
function M.readJsonFile(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local raw = f:read('*a')
    f:close()
    if not raw or raw == '' then return nil end
    if decodeJson then
        local ok, data = pcall(decodeJson, raw)
        if ok and type(data) == 'table' then return data end
    end
    local version = raw:match('"version"%s*:%s*"([^"]+)"')
    local core_url = raw:match('"core_url"%s*:%s*"([^"]+)"')
    local zip_url = raw:match('"zip_url"%s*:%s*"([^"]+)"')
    local runtime_libs_url = raw:match('"runtime_libs_url"%s*:%s*"([^"]+)"')
    local iconv_url = raw:match('"iconv_url"%s*:%s*"([^"]+)"')
    if version and core_url then
        return {
            version = version,
            core_url = core_url,
            zip_url = zip_url,
            runtime_libs_url = runtime_libs_url,
            iconv_url = iconv_url,
        }
    end
    return nil
end

-- Публичный API модуля.
function M.fetchRemoteManifest(tmpJson)
    if M.VERSION_JSON_URL:find('YOUR_GITHUB_USER', 1, true) then
        return nil, 'update URL not configured'
    end
    tmpJson = tmpJson or (M.root() .. '\\report_desk\\_update_manifest.json')
    local ok, err = M.downloadSync(M.VERSION_JSON_URL, tmpJson, 25)
    if not ok then
        return nil, err
    end
    return M.readJsonFile(tmpJson), nil
end

-- Публичный API модуля.
function M.releaseBaseUrl(manifest)
    manifest = manifest or {}
    local zip = tostring(manifest.zip_url or '')
    local base = zip:match('^(.*)/[^/]+$')
    if base and base ~= '' then
        return base
    end
    local ver = tostring(manifest.version or '')
    if ver ~= '' then
        return 'https://github.com/illusshion/report_desk_helper/releases/download/v' .. ver
    end
    return M.LATEST_RELEASE_BASE
end

-- Публичный API модуля.
function M.assetUrl(manifest, filename)
    filename = tostring(filename or '')
    if filename == '' then return nil end
    local base = M.releaseBaseUrl(manifest)
    if not base then return nil end
    return base .. '/' .. filename
end

-- Публичный API модуля.
function M.coreDir()
    return M.root() .. '\\report_desk'
end

-- Публичный API модуля.
function M.installedCoreVersionPath()
    return M.coreDir() .. '\\_core_version.txt'
end

-- Публичный API модуля.
function M.readInstalledCoreVersion()
    local f = io.open(M.installedCoreVersionPath(), 'r')
    if not f then return '' end
    local v = (f:read('*l') or ''):gsub('^%s+', ''):gsub('%s+$', '')
    f:close()
    return v
end

-- Публичный API модуля.
function M.writeInstalledCoreVersion(version)
    version = tostring(version or '')
    if version == '' then return end
    M.ensureCoreDir(M.installedCoreVersionPath())
    local f = io.open(M.installedCoreVersionPath(), 'w')
    if not f then return end
    f:write(version)
    f:close()
end

-- Публичный API модуля.
function M.coreIsCurrent(remoteVer, corePath)
    remoteVer = tostring(remoteVer or '')
    corePath = tostring(corePath or '')
    if remoteVer == '' or corePath == '' then return false end
    if M.readInstalledCoreVersion() ~= remoteVer then return false end
    return doesFileExist(corePath)
end

-- Публичный API модуля.
function M.corePathFromUrl(url, fallback)
    url = tostring(url or '')
    local name = url:match('/([^/%?]+)$')
    if name and name:find('%.luac?$', 1) then
        return M.coreDir() .. '\\' .. name
    end
    return fallback or (M.coreDir() .. '\\admin_report_desk_core.luac')
end

-- Публичный API модуля.
function M.ensureCoreDir(corePath)
    local dir = corePath:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

-- Публичный API модуля.
function M.installCore(tmpPath, corePath)
    M.ensureCoreDir(corePath)
    if doesFileExist(corePath) then
        os.remove(corePath)
    end
    local ok = os.rename(tmpPath, corePath)
    if not ok and doesFileExist(tmpPath) then
        local f = io.open(tmpPath, 'rb')
        if not f then return false end
        local data = f:read('*a')
        f:close()
        local out = io.open(corePath, 'wb')
        if not out then return false end
        out:write(data)
        out:close()
        os.remove(tmpPath)
        return true
    end
    return ok == true or doesFileExist(corePath)
end

-- Публичный API модуля.
function M.downloadCore(url, corePath)
    M.ensureCoreDir(corePath)
    local tmp = corePath .. '.download'
    local ok, err = M.downloadSync(url, tmp, 180, 65536)
    if not ok then
        return false, err
    end
    if not M.installCore(tmp, corePath) then
        return false, 'install failed'
    end
    return true
end

-- Публичный API модуля.
function M.writeLegacyRootStub(relName)
    relName = tostring(relName or '')
    if relName == '' then return false end
    local path = M.path(relName)
    local f = io.open(path, 'w')
    if not f then return false end
    f:write('do return end\n')
    f:close()
    log('legacy root stub: ' .. relName)
    return true
end

-- Публичный API модуля.
function M.installAuxFile(url, relName)
    relName = tostring(relName or '')
    if relName == '' then return false end
    local dest = M.path(relName)
    local tmp = dest .. '.bootstrap'
    local ok, err = M.downloadSync(url, tmp, 45, 32)
    if not ok then
        log('aux download failed: ' .. relName .. ' (' .. tostring(err) .. ')')
        return false
    end
    if doesFileExist(dest) then
        os.remove(dest)
    end
    local renamed = os.rename(tmp, dest)
    if not renamed then
        local f = io.open(tmp, 'rb')
        if not f then return false end
        local data = f:read('*a')
        f:close()
        local out = io.open(dest, 'wb')
        if not out then return false end
        out:write(data)
        out:close()
        pcall(os.remove, tmp)
    end
    return doesFileExist(dest)
end

-- Публичный API модуля.
function M.needsRuntimeLibs()
    local req = {
        'lib\\samp\\events.lua',
        'lib\\encoding.lua',
        'lib\\iconv.dll',
        'lib\\vkeys.lua',
        'lib\\vector3d.lua',
    }
    for _, rel in ipairs(req) do
        if not doesFileExist(M.path(rel)) then
            return true
        end
    end
    return false
end

-- Публичный API модуля.
function M.installRuntimeLibsZip(zipPath)
    local root = M.root()
    local tmp = root .. '\\report_desk\\_deps_runtime_tmp'
    local libDir = root .. '\\lib'
    local ps = table.concat({
        'powershell -NoProfile -ExecutionPolicy Bypass -Command "& {',
        '$tmp=' .. psLiteral(tmp) .. ';',
        '$zip=' .. psLiteral(zipPath) .. ';',
        '$lib=' .. psLiteral(libDir) .. ';',
        'Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue;',
        'Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force;',
        [[if (-not (Test-Path (Join-Path $tmp 'lib'))) { exit 2 };]],
        'New-Item -ItemType Directory -Path $lib -Force | Out-Null;',
        [[Get-ChildItem -LiteralPath (Join-Path $tmp 'lib') | ForEach-Object {]],
        '  $dest = Join-Path $lib $_.Name;',
        '  if ($_.PSIsContainer) { Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force }',
        '  else { Copy-Item -LiteralPath $_.FullName -Destination $dest -Force }',
        '};',
        'Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue',
        '}"',
    }, ' ')
    local ok = os.execute(ps)
    if ok == 0 or ok == true then
        return not M.needsRuntimeLibs()
    end
    return false
end

-- Публичный API модуля.
function M.ensureIconvDll(manifest, opts)
    opts = opts or {}
    if doesFileExist(M.path(M.ICONV_DLL)) then
        return true, false
    end
    local url = manifest and tostring(manifest.iconv_url or '') or ''
    if url == '' then
        url = M.assetUrl(manifest, 'iconv.dll') or (M.LATEST_RELEASE_BASE .. '/iconv.dll')
    end
    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 iconv...', opts)
    M.ensureCoreDir(M.path(M.ICONV_DLL))
    if not doesDirectoryExist(M.path('lib')) then
        createDirectory(M.path('lib'))
    end
    local dest = M.path(M.ICONV_DLL)
    local ok, err = M.downloadSync(url, dest, 45, 4096)
    if not ok then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 iconv: ' .. tostring(err), opts)
        return false, false
    end
    return true, true
end

-- Публичный API модуля.
function M.ensureRuntimeLibs(manifest, opts)
    opts = opts or {}
    if not M.needsRuntimeLibs() then
        return true, false
    end
    local url = manifest and tostring(manifest.runtime_libs_url or '') or ''
    if url == '' then
        url = M.assetUrl(manifest, M.RUNTIME_LIBS_ZIP) or (M.LATEST_RELEASE_BASE .. '/' .. M.RUNTIME_LIBS_ZIP)
    end
    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 lib...', opts)
    local zipPath = M.path('report_desk\\' .. M.RUNTIME_LIBS_ZIP)
    M.ensureCoreDir(zipPath)
    local ok, err = M.downloadSync(url, zipPath, 90, 1024)
    if not ok then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 lib: ' .. tostring(err), opts)
        return false, false
    end
    if not M.installRuntimeLibsZip(zipPath) then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xF0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE8 lib', opts)
        return false, false
    end
    notify('lib OK', opts)
    return true, true
end

-- Публичный API модуля.
function M.refreshAuxiliaryScripts(manifest, opts)
    manifest = manifest or {}
    opts = opts or {}
    local remoteVer = tostring(manifest.version or '')
    local localVer = M.readLocalVersion()
    if remoteVer == '' then return false end
    if M.parseVersion(remoteVer) <= M.parseVersion(localVer) then
        return false
    end
    local base = M.releaseBaseUrl(manifest)
    if not base then return false end
    local changed = false
    local files = {
        { 'report_desk_deps.lua', 'lib\\report_desk_deps.lua' },
        { 'report_desk_autoupdate.lua', 'lib\\report_desk_autoupdate.lua' },
    }
    if M.parseVersion(remoteVer) > M.parseVersion(localVer) then
        local launcherPending = M.path('admin_report_desk.lua.pending')
        if M.installAuxFile(base .. '/admin_report_desk.lua', 'admin_report_desk.lua.pending') then
            changed = true
            log('launcher pending: ' .. launcherPending)
        end
    end
    for _, spec in ipairs(files) do
        local url = base .. '/' .. spec[1]
        if M.installAuxFile(url, spec[2]) then
            changed = true
            log('aux updated: ' .. spec[2])
        end
    end
    if changed then
        package.loaded['report_desk_deps'] = nil
        package.loaded['report_desk_autoupdate'] = nil
    end
    return changed
end

--[[ returns: needsReload, status ]]
function M.ensureBootstrap(manifest, opts)
    opts = opts or {}
    if not manifest then
        return false, 'offline'
    end
    local changed = false
    if not doesFileExist(M.path('lib\\report_desk_deps.lua')) then
        M.writeLegacyRootStub('report_desk_deps.lua')
    end
    local auxChanged = M.refreshAuxiliaryScripts(manifest, opts)
    if auxChanged then
        changed = true
    end
    local libsOk, libsInstalled = M.ensureRuntimeLibs(manifest, opts)
    if libsInstalled then
        changed = true
    elseif not libsOk then
        log('runtime libs install skipped (bundled core fallback)')
    end
    local iconvOk, iconvInstalled = M.ensureIconvDll(manifest, opts)
    if iconvInstalled then
        changed = true
    elseif not iconvOk then
        log('iconv install pending (core bootstrap will retry)')
    end
    if auxChanged and thisScript and thisScript().reload then
        notify('bootstrap ' .. tostring(manifest.version) .. '...', opts)
        thisScript():reload()
        return true, 'reload'
    end
    if changed then
        package.loaded['lib.report_desk_deps'] = nil
        package.loaded['report_desk_autoupdate'] = nil
        package.loaded['report_desk_deps'] = nil
    end
    return false, changed and 'updated' or 'ok'
end

--[[ returns: needsReload, status ('uptodate'|'offline'|'fail'|'reload') ]]
function M.check(corePath)
    corePath = corePath or (M.root() .. '\\report_desk\\admin_report_desk_core.luac')
    local localVer = M.readLocalVersion()
    local manifest, err = M.fetchRemoteManifest()
    if manifest then
        local bootstrapReload = M.ensureBootstrap(manifest, { quietChat = true })
        if bootstrapReload then
            return true, 'reload'
        end
    else
        log('manifest skip: ' .. tostring(err))
        if not doesFileExist(corePath) then
            notify('\xDF\xE4\xF0\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE, \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xEE')
        end
        return false, 'offline'
    end
    local remoteVer = tostring(manifest.version or '')
    local coreUrl = tostring(manifest.core_url or '')
    if coreUrl == '' then
        log('manifest has no core_url')
        return false, 'fail'
    end
    corePath = M.corePathFromUrl(coreUrl, corePath)
    if M.coreIsCurrent(remoteVer, corePath) then
        log('core up to date (' .. remoteVer .. ')')
        return false, 'uptodate'
    end
    local localNum = M.parseVersion(localVer)
    local remoteNum = M.parseVersion(remoteVer)
    if remoteNum < localNum or (remoteNum == localNum and remoteVer == localVer) then
        if doesFileExist(corePath) then
            M.writeInstalledCoreVersion(remoteVer)
            log('up to date (' .. localVer .. ')')
            return false, 'uptodate'
        end
    end
    notify('\xD1\xEA\xE0\xF7\xE8\xE2\xE0\xED\xE8\xE5 ' .. remoteVer .. '...')
    local ok, derr = M.downloadCore(coreUrl, corePath)
    if not ok and manifest.core_url_fallback and tostring(manifest.core_url_fallback) ~= '' then
        local fb = tostring(manifest.core_url_fallback)
        log('core primary failed, fallback: ' .. fb)
        corePath = M.corePathFromUrl(fb, corePath)
        ok, derr = M.downloadCore(fb, corePath)
    end
    if not ok then
        local dir = M.coreDir()
        local hadCore = doesFileExist(corePath)
        if not hadCore then
            hadCore = doesFileExist(dir .. '\\admin_report_desk_core.lua')
                or doesFileExist(dir .. '\\admin_report_desk_core.luac')
        end
        if hadCore then
            local prev = M.readInstalledCoreVersion()
            notify('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5 \xE7\xE0\xE3\xF0\xF3\xE7\xE8\xEB\xEE\xF1\xFC (' .. tostring(derr) .. '), \xFF\xE4\xF0\xEE ' .. (prev ~= '' and prev or '\xEF\xF0\xE5\xE6\xED\xE5\xE5'))
        else
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE8: ' .. tostring(derr))
        end
        return false, 'fail'
    end
    M.writeInstalledCoreVersion(remoteVer)
    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE ' .. remoteVer)
    if thisScript and thisScript().reload then
        thisScript():reload()
        return true, 'reload'
    end
    return false, 'fail'
end

-- Публичный API модуля.
function M.forceDownload(corePath)
    corePath = corePath or (M.root() .. '\\report_desk\\admin_report_desk_core.luac')
    local manifest = select(1, M.fetchRemoteManifest())
    if not manifest or not manifest.core_url then
        return false, 'no manifest'
    end
    if manifest then
        M.ensureBootstrap(manifest, { quietChat = true })
    end
    corePath = M.corePathFromUrl(manifest.core_url, corePath)
    local ok, err = M.downloadCore(manifest.core_url, corePath)
    if not ok and manifest.core_url_fallback and tostring(manifest.core_url_fallback) ~= '' then
        corePath = M.corePathFromUrl(tostring(manifest.core_url_fallback), corePath)
        ok, err = M.downloadCore(manifest.core_url_fallback, corePath)
    end
    return ok, err
end

return M
