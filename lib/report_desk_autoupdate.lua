--[[
    GitHub auto-update для Admin Report Desk (manifest v2, SHA256, атомарная установка).
    Перед публикацией: tools\publish_release.ps1 -Version X.Y.Z
]]
pcall(function()
    if not getWorkingDirectory or not doesFileExist then return end
    local root = getWorkingDirectory()
    for _, spec in ipairs({
        { 'report_desk_deps.lua', 'report_desk_deps.lua.off' },
        { 'report_desk_autoupdate.lua', 'report_desk_autoupdate.lua.off' },
    }) do
        local path = root .. '\\' .. spec[1]
        local off = root .. '\\' .. spec[2]
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
M.MANIFEST_VERSION = 2
M.STATE_FILE = 'report_desk\\_install_state.json'
M.STAGING_DIR = 'report_desk\\_update_staging'
M.LEGACY_CORE_VERSION = 'report_desk\\_core_version.txt'
M.RUNTIME_LIBS_ZIP = 'report_desk_runtime_libs.zip'
M.ICONV_DLL = 'lib\\iconv.dll'
M.LATEST_RELEASE_BASE = 'https://github.com/illusshion/report_desk_helper/releases/latest/download'
M.DOWNLOAD_RETRIES = 3

local function log(msg)
    print('[Report Desk] update: ' .. tostring(msg))
end

local function notify(msg, opts)
    opts = opts or {}
    log(msg)
    if opts.quietChat or opts.say == false then return end
    M.chatSay(msg)
end

-- Публичный API модуля.
function M.chatSay(text)
    text = tostring(text or '')
    if text == '' then return end
    print('[Report Desk] ' .. text)
    if not isSampAvailable or not isSampAvailable() or not sampAddChatMessage then return end
    pcall(sampAddChatMessage, M.CHAT_PREFIX .. text, M.CHAT_COLOR)
end

-- Публичный API модуля.
function M.root()
    return getWorkingDirectory()
end

-- Публичный API модуля.
function M.path(rel)
    return M.root() .. '\\' .. tostring(rel or ''):gsub('/', '\\')
end

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
    local state = M.readState()
    if state and state.version and state.version ~= '' then
        return tostring(state.version)
    end
    if thisScript and thisScript().version then
        return tostring(thisScript().version)
    end
    return '0.0.0'
end

-- Публичный API модуля.
function M.readInstalledCoreVersion()
    return M.readLocalVersion()
end

local function ensureDirFor(filePath)
    local dir = filePath:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

-- Публичный API модуля.
function M.ensureCoreDir(filePath)
    ensureDirFor(filePath)
end

-- Публичный API модуля.
function M.downloadSync(url, dest, timeoutSec, minBytes)
    if not downloadUrlToFile then
        return false, 'downloadUrlToFile unavailable'
    end
    minBytes = tonumber(minBytes) or 32
    ensureDirFor(dest)
    if doesFileExist(dest) then
        pcall(os.remove, dest)
    end
    downloadUrlToFile(url, dest)
    local deadline = os.clock() + (timeoutSec or 60)
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

local function downloadWithRetry(url, dest, timeoutSec, minBytes)
    local lastErr = 'unknown'
    for attempt = 1, M.DOWNLOAD_RETRIES do
        local ok, err = M.downloadSync(url, dest, timeoutSec, minBytes)
        if ok then
            return true
        end
        lastErr = err or 'download failed'
        log('retry ' .. attempt .. '/' .. M.DOWNLOAD_RETRIES .. ': ' .. tostring(url) .. ' (' .. tostring(lastErr) .. ')')
        wait(250 * attempt)
    end
    return false, lastErr
end

-- Публичный API модуля.
function M.sha256File(path)
    path = tostring(path or '')
    if path == '' or not doesFileExist(path) then
        return nil
    end
    local ps = table.concat({
        'powershell -NoProfile -ExecutionPolicy Bypass -Command',
        '"& { (Get-FileHash -LiteralPath ' .. psLiteral(path) .. ' -Algorithm SHA256).Hash.ToLower() }"',
    }, ' ')
    local pipe = io.popen(ps)
    if not pipe then
        return nil
    end
    local out = pipe:read('*a') or ''
    pipe:close()
    return out:match('([a-f0-9]+)')
end

local function fileBytes(path)
    if not doesFileExist(path) then
        return nil
    end
    local f = io.open(path, 'rb')
    if not f then
        return nil
    end
    local n = f:seek('end') or 0
    f:close()
    return n
end

local function readTextFile(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local raw = f:read('*a')
    f:close()
    return raw
end

local function writeTextFile(path, text)
    ensureDirFor(path)
    local f = io.open(path, 'w')
    if not f then return false end
    f:write(text)
    f:close()
    return true
end

-- Публичный API модуля.
function M.readJsonFile(path)
    local raw = readTextFile(path)
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

local function writeJsonFile(path, tbl)
    if encodeJson then
        local ok, raw = pcall(encodeJson, tbl)
        if ok and raw then
            return writeTextFile(path, raw)
        end
    end
    local version = tostring(tbl.version or ''):gsub('"', '\\"')
    local parts = { '{"version":"' .. version .. '"'}
    if type(tbl.files) == 'table' then
        local fileParts = {}
        for dest, spec in pairs(tbl.files) do
            if type(spec) == 'table' then
                local key = tostring(dest):gsub('"', '\\"')
                local sha = tostring(spec.sha256 or ''):gsub('"', '\\"')
                fileParts[#fileParts + 1] = '"' .. key .. '":{"sha256":"' .. sha .. '","bytes":'
                    .. tostring(tonumber(spec.bytes) or 0) .. '}'
            end
        end
        if #fileParts > 0 then
            parts[#parts + 1] = ',"files":{' .. table.concat(fileParts, ',') .. '}'
        end
    end
    parts[#parts + 1] = ',"updated_at":"' .. os.date('%Y-%m-%dT%H:%M:%S') .. '"}'
    return writeTextFile(path, table.concat(parts) .. '\n')
end

-- Публичный API модуля.
function M.readState()
    local path = M.path(M.STATE_FILE)
    local data = M.readJsonFile(path)
    if type(data) == 'table' then
        return data
    end
    return nil
end

local function writeState(state)
    state = state or {}
    state.updated_at = os.date('%Y-%m-%dT%H:%M:%S')
    return writeJsonFile(M.path(M.STATE_FILE), state)
end

local function migrateLegacyState()
    local state = M.readState()
    if state and state.version and state.version ~= '' then
        return state
    end
    local version = ''
    local legacyPath = M.path(M.LEGACY_CORE_VERSION)
    local f = io.open(legacyPath, 'r')
    if f then
        version = (f:read('*l') or ''):gsub('^%s+', ''):gsub('%s+$', '')
        f:close()
    end
    if version == '' and thisScript and thisScript().version then
        version = tostring(thisScript().version)
    end
    if version == '' then
        return state
    end
    local migrated = {
        version = version,
        migrated_from = '_core_version.txt',
        files = {},
    }
    writeState(migrated)
    log('migrated legacy state -> ' .. version)
    return migrated
end

-- Публичный API модуля.
function M.fetchRemoteManifest(tmpJson)
    if M.VERSION_JSON_URL:find('YOUR_GITHUB_USER', 1, true) then
        return nil, 'update URL not configured'
    end
    tmpJson = tmpJson or M.path('report_desk\\_update_manifest.json')
    local ok, err = downloadWithRetry(M.VERSION_JSON_URL, tmpJson, 30, 32)
    if not ok then
        return nil, err
    end
    return M.readJsonFile(tmpJson), nil
end

-- Публичный API модуля.
function M.releaseBaseUrl(manifest)
    manifest = manifest or {}
    if manifest.release_base and tostring(manifest.release_base) ~= '' then
        return tostring(manifest.release_base):gsub('/$', '')
    end
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

local function manifestUsesV2(manifest)
    return type(manifest) == 'table'
        and tonumber(manifest.manifest_version) == M.MANIFEST_VERSION
        and type(manifest.files) == 'table'
end

local function normalizeManifestFiles(manifest)
    if manifestUsesV2(manifest) then
        local out = {}
        for asset, spec in pairs(manifest.files) do
            if type(spec) == 'table' and spec.dest then
                out[#out + 1] = {
                    asset = tostring(asset),
                    dest = tostring(spec.dest):gsub('/', '\\'),
                    sha256 = tostring(spec.sha256 or ''):lower(),
                    bytes = tonumber(spec.bytes) or 0,
                    url = tostring(spec.url or ''),
                    pending = spec.pending == true,
                }
            end
        end
        table.sort(out, function(a, b) return a.dest < b.dest end)
        return out
    end

    local base = M.releaseBaseUrl(manifest)
    local coreUrl = tostring(manifest.core_url or '')
    local coreName = coreUrl:match('/([^/%?]+)$') or 'admin_report_desk_core.lua'
    local out = {
        {
            asset = 'report_desk_autoupdate.lua',
            dest = 'lib\\report_desk_autoupdate.lua',
            sha256 = '',
            bytes = 0,
            url = base .. '/report_desk_autoupdate.lua',
            pending = true,
        },
        {
            asset = 'report_desk_deps.lua',
            dest = 'lib\\report_desk_deps.lua',
            sha256 = '',
            bytes = 0,
            url = base .. '/report_desk_deps.lua',
            pending = false,
        },
        {
            asset = coreName,
            dest = 'report_desk\\' .. coreName,
            sha256 = '',
            bytes = 0,
            url = coreUrl,
            pending = false,
        },
        {
            asset = 'admin_report_desk.lua',
            dest = 'admin_report_desk.lua',
            sha256 = '',
            bytes = 0,
            url = base .. '/admin_report_desk.lua',
            pending = true,
        },
    }
    return out
end

local function verifyFile(path, spec)
    if not doesFileExist(path) then
        return false, 'missing'
    end
    local bytes = fileBytes(path)
    if not bytes then
        return false, 'unreadable'
    end
    if spec.bytes and spec.bytes > 0 and bytes ~= spec.bytes then
        return false, 'size mismatch'
    end
    if spec.sha256 and spec.sha256 ~= '' then
        local hash = M.sha256File(path)
        if not hash then
            return false, 'hash unavailable'
        end
        if hash:lower() ~= spec.sha256:lower() then
            return false, 'hash mismatch'
        end
    end
    return true
end

local function localFileMatches(spec)
    local path = M.path(spec.dest)
    if not doesFileExist(path) then
        return false, 'missing'
    end
    local bytes = fileBytes(path) or 0
    if spec.bytes and spec.bytes > 0 then
        if bytes ~= spec.bytes then
            return false, 'size'
        end
        return true
    end
    if spec.sha256 and spec.sha256 ~= '' then
        local hash = M.sha256File(path)
        if not hash or hash:lower() ~= spec.sha256:lower() then
            return false, 'hash'
        end
    end
    return true
end

local function needsRuntimeLibs()
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
function M.needsRuntimeLibs()
    return needsRuntimeLibs()
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
        return not needsRuntimeLibs()
    end
    return false
end

local function runtimeSpec(manifest)
    if type(manifest.runtime_libs) == 'table' then
        local spec = manifest.runtime_libs
        local url = tostring(spec.url or '')
        if url == '' then
            url = M.releaseBaseUrl(manifest) .. '/' .. tostring(spec.asset or M.RUNTIME_LIBS_ZIP)
        end
        return {
            asset = tostring(spec.asset or M.RUNTIME_LIBS_ZIP),
            url = url,
            sha256 = tostring(spec.sha256 or ''):lower(),
            bytes = tonumber(spec.bytes) or 0,
        }
    end
    local url = tostring(manifest.runtime_libs_url or '')
    if url == '' then
        url = M.releaseBaseUrl(manifest) .. '/' .. M.RUNTIME_LIBS_ZIP
    end
    return {
        asset = M.RUNTIME_LIBS_ZIP,
        url = url,
        sha256 = '',
        bytes = 0,
    }
end

local function iconvSpec(manifest)
    if type(manifest.files) == 'table' and manifest.files['iconv.dll'] then
        local spec = manifest.files['iconv.dll']
        return {
            dest = tostring(spec.dest or 'lib/iconv.dll'):gsub('/', '\\'),
            url = tostring(spec.url or ''),
            sha256 = tostring(spec.sha256 or ''):lower(),
            bytes = tonumber(spec.bytes) or 0,
        }
    end
    local url = tostring(manifest.iconv_url or '')
    if url == '' then
        url = M.releaseBaseUrl(manifest) .. '/iconv.dll'
    end
    return {
        dest = 'lib\\iconv.dll',
        url = url,
        sha256 = '',
        bytes = 0,
    }
end

local function clearStaging()
    local dir = M.path(M.STAGING_DIR)
    if doesDirectoryExist(dir) then
        pcall(function()
            os.execute('powershell -NoProfile -Command "Remove-Item -LiteralPath ' .. psLiteral(dir) .. ' -Recurse -Force -ErrorAction SilentlyContinue"')
        end)
    end
    if not doesDirectoryExist(M.path('report_desk')) then
        createDirectory(M.path('report_desk'))
    end
    createDirectory(dir)
end

local function copyFileAtomic(src, dest)
    ensureDirFor(dest)
    if doesFileExist(dest) then
        pcall(os.remove, dest)
    end
    if os.rename(src, dest) then
        return doesFileExist(dest)
    end
    local f = io.open(src, 'rb')
    if not f then return false end
    local data = f:read('*a')
    f:close()
    local out = io.open(dest, 'wb')
    if not out then return false end
    out:write(data)
    out:close()
    pcall(os.remove, src)
    return doesFileExist(dest)
end

local function installToDest(src, spec)
    local dest = M.path(spec.dest)
    local finalDest = dest
    if spec.pending then
        finalDest = dest .. '.pending'
    end
    if not copyFileAtomic(src, finalDest) then
        return false, 'install failed: ' .. spec.dest
    end
    if spec.dest:find('admin_report_desk_core%.lua$', 1) then
        local staleLuac = M.path('report_desk\\admin_report_desk_core.luac')
        if doesFileExist(staleLuac) then
            pcall(os.remove, staleLuac)
            log('removed stale core.luac')
        end
    end
    return true
end

local function buildUpdatePlan(manifest, opts)
    opts = opts or {}
    local state = migrateLegacyState() or {}
    local remoteVer = tostring(manifest.version or '')
    local files = normalizeManifestFiles(manifest)
    local plan = {}
    local force = opts.force == true or opts.mode == 'repair'

    for _, spec in ipairs(files) do
        if spec.url == '' then
            spec.url = M.releaseBaseUrl(manifest) .. '/' .. spec.asset
        end
        local need = force
        if not need then
            if remoteVer ~= tostring(state.version or '') then
                need = true
            else
                local ok = localFileMatches(spec)
                if not ok then
                    need = true
                end
            end
        end
        if need then
            plan[#plan + 1] = spec
        end
    end

    local rt = runtimeSpec(manifest)
    local needRuntime = force or needsRuntimeLibs()
    if needRuntime then
        plan.runtime = rt
    end

    local iv = iconvSpec(manifest)
    if force or not doesFileExist(M.path(iv.dest)) then
        plan.iconv = iv
    end

    return plan, state, files
end

local function downloadPlan(plan, manifest, opts)
    opts = opts or {}
    clearStaging()
    local staging = M.path(M.STAGING_DIR)
    local downloaded = {}

    for _, spec in ipairs(plan) do
        local tmp = staging .. '\\' .. spec.asset:gsub('[\\/]', '_')
        notify('\xD1\xEA\xE0\xF7\xE8\xE2\xE0\xED\xE8\xE5 ' .. spec.asset .. '...', opts)
        local minBytes = math.min(32, spec.bytes > 0 and spec.bytes or 32)
        local ok, err = downloadWithRetry(spec.url, tmp, 180, minBytes)
        if not ok then
            return nil, 'download ' .. spec.asset .. ': ' .. tostring(err)
        end
        local verOk, verErr = verifyFile(tmp, spec)
        if not verOk then
            pcall(os.remove, tmp)
            return nil, 'verify ' .. spec.asset .. ': ' .. tostring(verErr)
        end
        downloaded[#downloaded + 1] = { spec = spec, tmp = tmp }
    end

    if plan.runtime then
        local spec = plan.runtime
        local tmp = staging .. '\\' .. spec.asset
        notify('\xD1\xEA\xE0\xF7\xE8\xE2\xE0\xED\xE8\xE5 ' .. spec.asset .. '...', opts)
        local ok, err = downloadWithRetry(spec.url, tmp, 120, 512)
        if not ok then
            return nil, 'download runtime: ' .. tostring(err)
        end
        if spec.sha256 ~= '' then
            local verOk, verErr = verifyFile(tmp, spec)
            if not verOk then
                pcall(os.remove, tmp)
                return nil, 'verify runtime: ' .. tostring(verErr)
            end
        end
        downloaded.runtime = tmp
    end

    if plan.iconv then
        local spec = plan.iconv
        local tmp = staging .. '\\iconv.dll'
        notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 iconv...', opts)
        local ok, err = downloadWithRetry(spec.url, tmp, 60, 4096)
        if not ok then
            return nil, 'download iconv: ' .. tostring(err)
        end
        if spec.sha256 ~= '' then
            local verOk, verErr = verifyFile(tmp, spec)
            if not verOk then
                pcall(os.remove, tmp)
                return nil, 'verify iconv: ' .. tostring(verErr)
            end
        end
        downloaded.iconv = { spec = spec, tmp = tmp }
    end

    return downloaded
end

local function commitPlan(downloaded, manifest, allFiles)
    local stateFiles = {}
    for _, item in ipairs(downloaded) do
        local ok, err = installToDest(item.tmp, item.spec)
        if not ok then
            return false, err
        end
        stateFiles[item.spec.dest] = {
            sha256 = item.spec.sha256,
            bytes = item.spec.bytes,
        }
    end

    if downloaded.runtime then
        if not M.installRuntimeLibsZip(downloaded.runtime) then
            return false, 'runtime unpack failed'
        end
        pcall(os.remove, downloaded.runtime)
    end

    if downloaded.iconv then
        local dest = M.path(downloaded.iconv.spec.dest)
        if not copyFileAtomic(downloaded.iconv.tmp, dest) then
            return false, 'iconv install failed'
        end
        stateFiles[downloaded.iconv.spec.dest] = {
            sha256 = downloaded.iconv.spec.sha256,
            bytes = downloaded.iconv.spec.bytes,
        }
    end

    for _, spec in ipairs(allFiles) do
        if not stateFiles[spec.dest] then
            local ok = localFileMatches(spec)
            if ok then
                stateFiles[spec.dest] = {
                    sha256 = spec.sha256,
                    bytes = spec.bytes,
                }
            end
        end
    end

    local state = {
        version = tostring(manifest.version or ''),
        files = stateFiles,
        manifest_version = manifestUsesV2(manifest) and M.MANIFEST_VERSION or 1,
    }
    writeState(state)
    writeTextFile(M.path(M.LEGACY_CORE_VERSION), state.version .. '\n')

    clearStaging()
    package.loaded['report_desk_deps'] = nil
    package.loaded['lib.report_desk_deps'] = nil
    package.loaded['report_desk_autoupdate'] = nil
    package.loaded['lib.report_desk_autoupdate'] = nil
    return true
end

--[[ returns: needsReload, status ]]
function M.sync(manifest, opts)
    opts = opts or {}
    if not manifest then
        return false, 'offline'
    end
    local plan, state, allFiles = buildUpdatePlan(manifest, opts)
    local fileCount = #plan
    local hasExtra = plan.runtime ~= nil or plan.iconv ~= nil
    if fileCount == 0 and not hasExtra then
        return false, 'uptodate'
    end

    if opts.mode == 'bootstrap' and fileCount > 0 then
        local filtered = {}
        local keepRuntime = plan.runtime
        local keepIconv = plan.iconv
        for _, spec in ipairs(plan) do
            if spec.dest:find('admin_report_desk_core', 1, true) then
                if opts.includeCore then
                    filtered[#filtered + 1] = spec
                end
            else
                filtered[#filtered + 1] = spec
            end
        end
        plan = filtered
        plan.runtime = keepRuntime
        plan.iconv = keepIconv
        fileCount = #plan
        hasExtra = plan.runtime ~= nil or plan.iconv ~= nil
        if fileCount == 0 and not hasExtra then
            return false, 'uptodate'
        end
    end

    local remoteVer = tostring(manifest.version or '')
    notify('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 ' .. remoteVer .. ' (' .. tostring(fileCount + (hasExtra and 1 or 0)) .. ' \xF4\xE0\xE9\xEB\xEE\xE2)...', opts)

    local downloaded, dlErr = downloadPlan(plan, manifest, opts)
    if not downloaded then
        notify('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5 \xE7\xE0\xE3\xF0\xF3\xE7\xE8\xEB\xEE\xF1\xFC: ' .. tostring(dlErr), opts)
        return false, 'fail'
    end

    local ok, commitErr = commitPlan(downloaded, manifest, allFiles)
    if not ok then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8: ' .. tostring(commitErr), opts)
        return false, 'fail'
    end

    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE ' .. remoteVer, opts)
    local needsPendingReload = false
    for _, item in ipairs(downloaded) do
        if item.spec.pending then
            needsPendingReload = true
            break
        end
    end
    if needsPendingReload or opts.reload ~= false then
        if thisScript and thisScript().reload then
            thisScript():reload()
            return true, 'reload'
        end
    end
    return false, 'updated'
end

--[[ returns: needsReload, status ]]
function M.ensureBootstrap(manifest, opts)
    opts = opts or {}
    if not manifest then
        return false, 'offline'
    end
    opts.mode = 'bootstrap'
    opts.quietChat = opts.quietChat or (opts.say == nil)
    return M.sync(manifest, opts)
end

--[[ returns: needsReload, status ('uptodate'|'offline'|'fail'|'reload') ]]
function M.check(corePath)
    corePath = corePath or M.path('report_desk\\admin_report_desk_core.luac')
    local manifest, err = M.fetchRemoteManifest()
    if not manifest then
        log('manifest skip: ' .. tostring(err))
        if not doesFileExist(corePath) and not doesFileExist(M.path('report_desk\\admin_report_desk_core.lua')) then
            notify('\xDF\xE4\xF0\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE, \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xEE')
        end
        return false, 'offline'
    end
    return M.sync(manifest, { quietChat = true, mode = 'full', includeCore = true })
end

-- Публичный API модуля.
function M.forceDownload(corePath)
    local manifest = select(1, M.fetchRemoteManifest())
    if not manifest then
        return false, 'no manifest'
    end
    local _, status = M.sync(manifest, { quietChat = true, mode = 'repair', force = true, includeCore = true })
    if status == 'reload' or status == 'updated' then
        return true
    end
    if status == 'uptodate' then
        return true
    end
    return false, status
end

-- Публичный API модуля.
function M.repair()
    local manifest, err = M.fetchRemoteManifest()
    if not manifest then
        return false, err or 'no manifest'
    end
    return M.sync(manifest, { mode = 'repair', force = true, includeCore = true })
end

-- Публичный API модуля.
function M.diagnose()
    local result = {
        local_version = M.readLocalVersion(),
        remote_version = '',
        manifest_ok = false,
        manifest_error = nil,
        state_path = M.path(M.STATE_FILE),
        files = {},
        runtime_libs_ok = not needsRuntimeLibs(),
        core_present = doesFileExist(M.path('report_desk\\admin_report_desk_core.lua'))
            or doesFileExist(M.path('report_desk\\admin_report_desk_core.luac')),
    }
    local manifest, err = M.fetchRemoteManifest()
    if not manifest then
        result.manifest_error = err
        return result
    end
    result.manifest_ok = true
    result.remote_version = tostring(manifest.version or '')
    result.manifest_v2 = manifestUsesV2(manifest)

    local files = normalizeManifestFiles(manifest)
    for _, spec in ipairs(files) do
        local path = M.path(spec.dest)
        local entry = {
            dest = spec.dest,
            exists = doesFileExist(path),
            bytes = fileBytes(path),
            expected_bytes = spec.bytes,
            expected_sha256 = spec.sha256,
        }
        if entry.exists and spec.sha256 ~= '' then
            entry.sha256 = M.sha256File(path)
            entry.ok = entry.sha256 and entry.sha256:lower() == spec.sha256:lower()
        elseif entry.exists and spec.bytes > 0 then
            entry.ok = entry.bytes == spec.bytes
        else
            entry.ok = entry.exists
        end
        result.files[#result.files + 1] = entry
    end
    result.up_to_date = result.local_version == result.remote_version
    for _, entry in ipairs(result.files) do
        if not entry.ok then
            result.up_to_date = false
            break
        end
    end
    if not result.runtime_libs_ok then
        result.up_to_date = false
    end
    return result
end

-- Публичный API модуля.
function M.printDiagnostics()
    local d = M.diagnose()
    M.chatSay('\xC4\xE8\xE0\xE3\xED\xEE\xF1\xF2\xE8\xEA\xE0 \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE9:')
    if not d.manifest_ok then
        M.chatSay('manifest: \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xE5\xED (' .. tostring(d.manifest_error) .. ')')
        M.chatSay('local v' .. tostring(d.local_version) .. ', core=' .. (d.core_present and 'yes' or 'no'))
        return
    end
    M.chatSay('local v' .. d.local_version .. ' / remote v' .. d.remote_version
        .. (d.up_to_date and ' (\xE0\xEA\xF2\xF3\xE0\xEB\xFC\xED\xEE)' or ' (\xED\xF3\xE6\xED\xEE \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5)'))
    if not d.runtime_libs_ok then
        M.chatSay('runtime libs: \xED\xE5\xEF\xEE\xEB\xED\xFB\xE5')
    end
    local bad = 0
    for _, entry in ipairs(d.files) do
        if not entry.ok then
            bad = bad + 1
            if bad <= 4 then
                M.chatSay('  ! ' .. entry.dest)
            end
        end
    end
    if bad > 4 then
        M.chatSay('  ... \xE8 \xE5\xF9\xE5 ' .. tostring(bad - 4) .. ' \xF4\xE0\xE9\xEB\xEE\xE2')
    end
    if bad == 0 and d.up_to_date then
        M.chatSay('moonloader.log \xE4\xEB\xFF \xEF\xEE\xE4\xF0\xEE\xE1\xED\xEE\xF1\xF2\xE5\xE9')
    else
        M.chatSay('/deskrepair \xE4\xEB\xFF \xEF\xEE\xEB\xED\xEE\xE9 \xEF\xE5\xF0\xE5\xF3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE8')
    end
end

-- Публичный API модуля.
function M.applyPendingFiles()
    local root = M.root()
    local pendingSpecs = {
        { pending = root .. '\\admin_report_desk.lua.pending', dest = root .. '\\admin_report_desk.lua' },
        { pending = root .. '\\lib\\report_desk_autoupdate.lua.pending', dest = root .. '\\lib\\report_desk_autoupdate.lua' },
    }
    local changed = false
    for _, spec in ipairs(pendingSpecs) do
        if doesFileExist(spec.pending) then
            pcall(os.remove, spec.dest)
            if os.rename(spec.pending, spec.dest) then
                log('applied pending: ' .. spec.dest)
                changed = true
            end
        end
    end
    if changed then
        package.loaded['report_desk_autoupdate'] = nil
        package.loaded['lib.report_desk_autoupdate'] = nil
    end
    return changed
end

-- Legacy API (совместимость со старым launcher / deps)
function M.coreDir()
    return M.path('report_desk')
end

function M.installedCoreVersionPath()
    return M.path(M.LEGACY_CORE_VERSION)
end

function M.writeInstalledCoreVersion(version)
    local state = migrateLegacyState() or { files = {} }
    state.version = tostring(version or '')
    writeState(state)
    writeTextFile(M.path(M.LEGACY_CORE_VERSION), state.version .. '\n')
end

function M.coreIsCurrent(remoteVer, corePath)
    remoteVer = tostring(remoteVer or '')
    if remoteVer == '' then return false end
    if M.readLocalVersion() ~= remoteVer then return false end
    corePath = tostring(corePath or '')
    if corePath == '' then return false end
    return doesFileExist(corePath)
end

function M.corePathFromUrl(url, fallback)
    url = tostring(url or '')
    local name = url:match('/([^/%?]+)$')
    if name and name:find('%.luac?$', 1) then
        return M.coreDir() .. '\\' .. name
    end
    return fallback or (M.coreDir() .. '\\admin_report_desk_core.luac')
end

function M.installCore(tmpPath, corePath)
    return copyFileAtomic(tmpPath, corePath)
end

function M.downloadCore(url, corePath)
    ensureDirFor(corePath)
    local tmp = corePath .. '.download'
    local ok, err = downloadWithRetry(url, tmp, 180, 65536)
    if not ok then
        return false, err
    end
    if not M.installCore(tmp, corePath) then
        return false, 'install failed'
    end
    return true
end

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

function M.installAuxFile(url, relName)
    relName = tostring(relName or '')
    if relName == '' then return false end
    local dest = M.path(relName)
    local tmp = dest .. '.bootstrap'
    local ok, err = downloadWithRetry(url, tmp, 45, 32)
    if not ok then
        log('aux download failed: ' .. relName .. ' (' .. tostring(err) .. ')')
        return false
    end
    if doesFileExist(dest) then
        pcall(os.remove, dest)
    end
    if not copyFileAtomic(tmp, dest) then
        return false
    end
    return doesFileExist(dest)
end

function M.ensureIconvDll(manifest, opts)
    opts = opts or {}
    if doesFileExist(M.path(M.ICONV_DLL)) then
        return true, false
    end
    local spec = iconvSpec(manifest or {})
    if spec.url == '' then
        return false, false
    end
    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 iconv...', opts)
    ensureDirFor(M.path(M.ICONV_DLL))
    if not doesDirectoryExist(M.path('lib')) then
        createDirectory(M.path('lib'))
    end
    local tmp = M.path('report_desk\\_update_staging\\iconv.dll')
    ensureDirFor(tmp)
    local ok, err = downloadWithRetry(spec.url, tmp, 45, 4096)
    if not ok then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 iconv: ' .. tostring(err), opts)
        return false, false
    end
    if spec.sha256 ~= '' then
        local verOk, verErr = verifyFile(tmp, spec)
        if not verOk then
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 iconv: ' .. tostring(verErr), opts)
            return false, false
        end
    end
    if not copyFileAtomic(tmp, M.path(M.ICONV_DLL)) then
        return false, false
    end
    return true, true
end

function M.ensureRuntimeLibs(manifest, opts)
    opts = opts or {}
    if not needsRuntimeLibs() then
        return true, false
    end
    local spec = runtimeSpec(manifest or {})
    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 lib...', opts)
    local zipPath = M.path('report_desk\\' .. M.RUNTIME_LIBS_ZIP)
    ensureDirFor(zipPath)
    local ok, err = downloadWithRetry(spec.url, zipPath, 90, 1024)
    if not ok then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 lib: ' .. tostring(err), opts)
        return false, false
    end
    if spec.sha256 ~= '' then
        local verOk, verErr = verifyFile(zipPath, spec)
        if not verOk then
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 lib: ' .. tostring(verErr), opts)
            return false, false
        end
    end
    if not M.installRuntimeLibsZip(zipPath) then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xF0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE8 lib', opts)
        return false, false
    end
    notify('lib OK', opts)
    return true, true
end

function M.refreshAuxiliaryScripts(manifest, opts)
    local _, status = M.sync(manifest, opts or {})
    return status == 'updated' or status == 'reload'
end

function M.assetUrl(manifest, filename)
    filename = tostring(filename or '')
    if filename == '' then return nil end
    return M.releaseBaseUrl(manifest) .. '/' .. filename
end

return M
