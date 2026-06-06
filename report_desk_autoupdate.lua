--[[
    GitHub auto-update для Admin Report Desk (тонкий launcher → core.luac).
    Перед публикацией укажите URL в release/repo.config.json и пересоберите release/version.json.
]]
local M = {}

M.VERSION_JSON_URL = 'https://raw.githubusercontent.com/illusshion/report_desk_helper/main/release/version.json'
M.CHAT_PREFIX = '{9E7BEF}[Report Desk] {FFFFFF}'
M.CHAT_COLOR = 0xE8E8E8

local function log(msg)
    print('[Report Desk] update: ' .. tostring(msg))
end

function M.chatSay(text)
    text = tostring(text or '')
    if text == '' then return end
    if not isSampAvailable or not isSampAvailable() or not sampAddChatMessage then return end
    pcall(sampAddChatMessage, M.CHAT_PREFIX .. text, M.CHAT_COLOR)
end

local function notify(msg, opts)
    opts = opts or {}
    log(msg)
    if opts.quietChat then return end
    M.chatSay(msg)
end

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
        -- 1.0.0-beta.N < 1.0.0; beta.1 < beta.2 < …
        return base - 10000 + tonumber(beta)
    end
    -- Прочие pre-release ниже финального релиза той же версии.
    return base - 5000
end

function M.readLocalVersion()
    if thisScript and thisScript().version then
        return tostring(thisScript().version)
    end
    return '0.0.0'
end

function M.downloadSync(url, dest, timeoutSec)
    if not downloadUrlToFile then
        return false, 'downloadUrlToFile unavailable'
    end
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
                if n > 64 then
                    return true
                end
            end
        end
        wait(100)
    end
    return false, 'timeout'
end

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
    if version and core_url then
        return { version = version, core_url = core_url }
    end
    return nil
end

function M.fetchRemoteManifest(tmpJson)
    if M.VERSION_JSON_URL:find('YOUR_GITHUB_USER', 1, true) then
        return nil, 'update URL not configured'
    end
    tmpJson = tmpJson or (getWorkingDirectory() .. '\\report_desk\\_update_manifest.json')
    local ok, err = M.downloadSync(M.VERSION_JSON_URL, tmpJson, 25)
    if not ok then
        return nil, err
    end
    return M.readJsonFile(tmpJson), nil
end

function M.coreDir()
    return getWorkingDirectory() .. '\\report_desk'
end

function M.corePathFromUrl(url, fallback)
    url = tostring(url or '')
    local name = url:match('/([^/%?]+)$')
    if name and name:find('%.luac?$', 1) then
        return M.coreDir() .. '\\' .. name
    end
    return fallback or (M.coreDir() .. '\\admin_report_desk_core.luac')
end

function M.ensureCoreDir(corePath)
    local dir = corePath:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

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

function M.downloadCore(url, corePath)
    M.ensureCoreDir(corePath)
    local tmp = corePath .. '.download'
    local ok, err = M.downloadSync(url, tmp, 120)
    if not ok then
        return false, err
    end
    if not M.installCore(tmp, corePath) then
        return false, 'install failed'
    end
    return true
end

--[[ returns: needsReload, status ('uptodate'|'offline'|'fail'|'reload') ]]
function M.check(corePath)
    corePath = corePath or (getWorkingDirectory() .. '\\report_desk\\admin_report_desk_core.luac')
    local localVer = M.readLocalVersion()
    local manifest, err = M.fetchRemoteManifest()
    if not manifest then
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
    if M.parseVersion(remoteVer) <= M.parseVersion(localVer) and doesFileExist(corePath) then
        log('up to date (' .. localVer .. ')')
        return false, 'uptodate'
    end
    notify('\xD1\xEA\xE0\xF7\xE8\xE2\xE0\xED\xE8\xE5 ' .. remoteVer .. '...')
    local ok, derr = M.downloadCore(coreUrl, corePath)
    if not ok then
        notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE8: ' .. tostring(derr))
        return false, 'fail'
    end
    notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE ' .. remoteVer)
    if thisScript and thisScript().reload then
        thisScript():reload()
        return true, 'reload'
    end
    return false, 'fail'
end

function M.forceDownload(corePath)
    corePath = corePath or (getWorkingDirectory() .. '\\report_desk\\admin_report_desk_core.luac')
    local manifest = select(1, M.fetchRemoteManifest())
    if not manifest or not manifest.core_url then
        return false, 'no manifest'
    end
    corePath = M.corePathFromUrl(manifest.core_url, corePath)
    return M.downloadCore(manifest.core_url, corePath)
end

return M
