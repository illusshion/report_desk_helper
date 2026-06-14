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

local deskSha256
local deskZip
local deskFs

local function reloadDeskSupportModules()
    package.loaded['report_desk_sha256'] = nil
    package.loaded['lib.report_desk_sha256'] = nil
    package.loaded['report_desk_zip'] = nil
    package.loaded['lib.report_desk_zip'] = nil
    package.loaded['report_desk_fs'] = nil
    package.loaded['lib.report_desk_fs'] = nil
    deskSha256 = require 'report_desk_sha256'
    deskZip = require 'report_desk_zip'
    deskFs = require 'report_desk_fs'
end

reloadDeskSupportModules()

local UPDATE_PHASE = {
    IDLE = 'idle',
    FETCH = 'fetch',
    STAGE = 'stage',
    COMMIT = 'commit',
}
local updatePhase = UPDATE_PHASE.IDLE

function M.getUpdatePhase()
    return updatePhase
end

M.VERSION_JSON_URL = 'https://raw.githubusercontent.com/illusshion/report_desk_helper/main/release/version.json'
M.CHAT_PREFIX = '{9E7BEF}[Report Desk] {FFFFFF}'
M.CHAT_COLOR = 0xE8E8E8
M.MANIFEST_VERSION = 3
M.ASSETS_ZIP = 'report_desk_assets.zip'
M.ASSETS_CACHE_DIR = 'config\\AdminDesk\\assets'
M.ASSETS_MANIFEST = 'config\\AdminDesk\\assets\\manifest.json'
M.MIMGUI_ZIP = 'mimgui-v1.7.1.zip'
M.STATE_FILE = 'report_desk\\_install_state.json'
M.STAGING_DIR = 'report_desk\\_update_staging'
M.LEGACY_CORE_VERSION = 'report_desk\\_core_version.txt'
M.RUNTIME_LIBS_ZIP = 'report_desk_runtime_libs.zip'
M.ICONV_DLL = 'lib\\iconv.dll'
M.LATEST_RELEASE_BASE = 'https://github.com/illusshion/report_desk_helper/releases/latest/download'
M.DOWNLOAD_RETRIES = 3

local deskOverlay
local activeOverlayOpts = nil

local function getOverlay()
    if deskOverlay then return deskOverlay end
    local ok, mod = pcall(require, 'report_desk_update_overlay')
    if ok then deskOverlay = mod end
    return deskOverlay
end

local function overlayEnabled(opts)
    opts = opts or activeOverlayOpts
    if opts and opts.showOverlay == false then return false end
    return getOverlay() ~= nil
end

local function wantsMinimalOverlay(opts)
    opts = opts or activeOverlayOpts
    return opts and (opts.minimalOverlay == true or opts.firstInstall == true)
end

local function overlayShow(title, detail, opts)
    opts = opts or activeOverlayOpts
    if not overlayEnabled(opts) then return end
    local ov = getOverlay()
    if not ov then return end
    if wantsMinimalOverlay(opts) and ov.showMinimal then
        ov.showMinimal(detail or title or OVERLAY_FRIENDLY_CHECK)
    elseif ov.show then
        ov.show(title, detail)
    end
end

local function overlayUpdate(detail, fraction, opts)
    opts = opts or activeOverlayOpts
    if not overlayEnabled(opts) then return end
    local ov = getOverlay()
    if ov and ov.update then
        ov.update({
            detail = detail,
            fraction = fraction,
            indeterminate = fraction == nil,
            minimal = wantsMinimalOverlay(opts),
        })
    end
end

local function overlayHide()
    local ov = getOverlay()
    if ov and ov.hide then ov.hide() end
end

local function setOverlayContext(opts)
    activeOverlayOpts = opts
end

function M.hideUpdateOverlay()
    overlayHide()
    setOverlayContext(nil)
end

function M.showUpdateOverlay(title, detail, opts)
    opts = M.resolveUserNotifyOpts(opts or { showOverlay = true, userFacing = true })
    setOverlayContext(opts)
    if wantsMinimalOverlay(opts) then
        overlayShow(nil, detail or OVERLAY_FRIENDLY_CHECK, opts)
    else
        overlayShow(title or OVERLAY_TITLE, detail or OVERLAY_CHECK, opts)
    end
end

local function log(msg)
    print('[Report Desk] update: ' .. tostring(msg))
end

local function notify(msg, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    log(msg)
    if opts.quietChat or opts.say == false then return end
    M.chatSay(msg)
end

local function sayFriendly(msg, opts)
    opts = opts or {}
    if opts.userFacing then
        M.chatSay(msg)
    end
end

local OVERLAY_TITLE = '\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 Report Desk'
local OVERLAY_CHECK = '\xCF\xF0\xEE\xE2\xE5\xF0\xEA\xE0 \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE9...'
local OVERLAY_DOWNLOAD = '\xCA\xE0\xF7\xE0\xE5\xEC \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5...'
local OVERLAY_INSTALL = '\xD3\xF1\xF2\xE0\xED\xE0\xE2\xEB\xE8\xE2\xE0\xE5\xEC \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5...'
local OVERLAY_ASSETS = '\xCA\xE0\xF7\xE0\xE5\xEC \xEF\xF0\xE5\xE2\xFC\xFE \xF1\xEA\xE8\xED\xEE\xE2 \xE8 \xD2\xD1...'
local OVERLAY_DONE = '\xC3\xEE\xF2\xEE\xE2\xEE'
local OVERLAY_FRIENDLY_CHECK = '\xCF\xF0\xEE\xE2\xE5\xF0\xFF\xFE \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xFF...'
local OVERLAY_FRIENDLY_DOWNLOAD = '\xC7\xE0\xE3\xF0\xF3\xE6\xE0\xFE...'
local OVERLAY_FRIENDLY_INSTALL = '\xD3\xF1\xF2\xE0\xED\xE0\xE2\xEB\xE8\xE2\xE0\xFE...'
local FIRST_RUN_CHAT = '\xD6\xF2\xEE \xE2\xE0\xF8 \xEF\xE5\xF0\xE2\xFB\xE9 \xE7\xE0\xEF\xF3\xF1\xEA. \xCF\xF0\xEE\xE2\xE5\xF0\xFE \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xFF \xE8 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xFE \xE2\xF1\xB8 \xED\xF3\xE6\xED\xEE\xE5. \xC2\xEE\xE7\xEC\xEE\xE6\xED\xE0 \xEF\xF0\xEE\xF1\xE0\xE4\xEA\xE0 FPS \xED\xE0 \xEF\xE0\xF0\xF3 \xF1\xE5\xEA\xF3\xED\xE4 \xB7 \xFD\xF2\xEE \xED\xEE\xF0\xEC\xE0\xEB\xFC\xED\xEE.'
local FIRST_RUN_READY = '\xC3\xEE\xF2\xEE\xE2\xEE! \xCE\xF2\xEA\xF0\xEE\xE9\xF2\xE5 \xEE\xEA\xED\xEE \xEA\xEE\xEC\xE0\xED\xE4\xEE\xE9 /adesk'
local FIRST_RUN_FAIL = '\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xF3\xF1\xF2\xE0\xED\xEE\xE2\xE8\xF2\xFC. \xCF\xF0\xEE\xE2\xE5\xF0\xFC\xF2\xE5 \xE8\xED\xF2\xE5\xF0\xED\xE5\xF2 \xE8 \xEF\xEE\xEF\xF0\xEE\xE1\xF3\xE9\xF2\xE5 /deskrepair'
local UPDATE_START = '\xC2\xFB\xF8\xEB\xE0 \xED\xEE\xE2\xE0\xFF \xE2\xE5\xF0\xF1\xE8\xFF, \xEE\xE1\xED\xEE\xE2\xEB\xFF\xFE\xF1\xFC...'
local UPDATE_DONE = '\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xE7\xE0\xE2\xE5\xF0\xF8\xE5\xED\xEE.'

local OVERLAY_ASSET_LABELS = {
    ['AdminDeskCore.luac'] = '\xFF\xE4\xF0\xEE',
    ['AdminDeskCore.lua'] = '\xFF\xE4\xF0\xEE',
    ['AdminDesk.luac'] = 'launcher',
    ['AdminDesk.lua'] = 'launcher',
    ['report_desk_autoupdate.lua'] = '\xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xFF',
    ['report_desk_deps.lua'] = '\xE7\xE0\xE2\xE8\xF1\xE8\xEC\xEE\xF1\xF2\xE8',
    ['report_desk_sha256.lua'] = 'sha256',
    ['report_desk_zip.lua'] = 'zip',
    ['report_desk_fs.lua'] = 'fs',
    ['report_desk_update_overlay.lua'] = 'overlay',
    ['report_desk_runtime_libs.zip'] = 'runtime',
    ['mimgui-v1.7.1.zip'] = 'mimgui',
    ['iconv.dll'] = 'iconv',
    ['report_desk_assets.zip'] = '\xEF\xF0\xE5\xE2\xFC\xFE',
    ['admin_report_desk.lua'] = 'launcher',
}

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

function M.isDevEnvironment()
    if rawget(_G, '__REPORT_DESK_DEV') == true then return true end
    if type(getWorkingDirectory) ~= 'function' then return false end
    local root = getWorkingDirectory()
    for _, name in ipairs({ 'admin_report_desk.lua', 'admin_report_desk.lua.off' }) do
        if devEntryHeadLooksDev(readDevEntryHead(root .. '\\' .. name)) then
            return true
        end
    end
    return false
end

-- Resolve User Notify Opts
function M.resolveUserNotifyOpts(opts)
    opts = opts or {}
    if opts.userFacing then
        if opts.quietChat == nil then
            opts.quietChat = true
        end
        if opts.showOverlay == nil then
            opts.showOverlay = true
        end
        if opts.minimalOverlay == nil then
            opts.minimalOverlay = true
        end
    end
    return opts
end

function M.isFirstInstall()
    if M.isDevEnvironment() then return false end
    return not M.corePresent()
end

function M.sayFirstRunIntro()
    M.chatSay(FIRST_RUN_CHAT)
end

-- Read Manifest Changelog
function M.readManifestChangelog(manifest)
    manifest = manifest or {}
    local cp1251 = manifest.changelog_cp1251 or manifest.changelog_chat or ''
    cp1251 = tostring(cp1251):gsub('^%s+', ''):gsub('%s+$', '')
    if cp1251 ~= '' then
        return M.fromCp1251Escapes(cp1251)
    end
    local cl = manifest.changelog or manifest.release_notes or ''
    cl = tostring(cl):gsub('^%s+', ''):gsub('%s+$', '')
    if cl == '' then return '' end
    if #cl > 180 then
        cl = cl:sub(1, 177) .. '...'
    end
    return M.chatTextFromUtf8(cl)
end

local function fromCp1251Escapes(text)
    text = tostring(text or '')
    if text == '' then return text end
    if text:find('\\x', 1, true) then
        return (text:gsub('\\x(%x%x)', function(h)
            return string.char(tonumber(h, 16))
        end))
    end
    return text
end

local function chatTextFromUtf8(text)
    text = tostring(text or '')
    if text == '' then return text end
    if not text:find('[\208-\209][\128-\191]') then
        return text
    end
    local ok, enc = pcall(require, 'encoding')
    if ok and enc and enc.UTF8 then
        local convOk, converted = pcall(function()
            enc.default = 'CP1251'
            return enc.UTF8:decode(text)
        end)
        if convOk and type(converted) == 'string' and converted ~= '' then
            return converted
        end
    end
    local ok2, iconv_mod = pcall(require, 'iconv')
    if ok2 and iconv_mod and iconv_mod.new then
        local convOk2, converted2 = pcall(function()
            local cd = iconv_mod.new('CP1251//IGNORE', 'UTF-8')
            assert(cd)
            return cd:iconv(text)
        end)
        if convOk2 and type(converted2) == 'string' and converted2 ~= '' then
            return converted2
        end
    end
    return text
end

M.fromCp1251Escapes = fromCp1251Escapes
M.chatTextFromUtf8 = chatTextFromUtf8

-- Show Update Success Message
function M.showUpdateSuccessMessage(manifest)
    local ver = tostring(manifest and manifest.version or M.readLocalVersion() or '')
    local cl = M.readManifestChangelog(manifest)
    local msg
    if cl ~= '' then
        msg = '\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE: ' .. cl
    elseif ver ~= '' and ver ~= '0.0.0' then
        msg = '\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 ' .. ver .. ' \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE'
    else
        msg = '\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xF3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE'
    end
    M.chatSay(msg)
end

-- Show Update Fail Message
function M.showUpdateFailMessage(opts)
    opts = opts or {}
    if opts.firstInstall then
        M.chatSay(FIRST_RUN_FAIL)
    else
        M.chatSay('\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEE\xE1\xED\xEE\xE2\xE8\xF2\xFC. \xCF\xEE\xEF\xF0\xEE\xE1\xF3\xE9\xF2\xE5 /deskrepair')
    end
end

-- Show Welcome Message
function M.showWelcomeMessage(manifest, opts)
    opts = opts or {}
    if opts.firstInstall or opts.skipWelcome then
        return
    end
    M.chatSay('Report Desk \xB7 /adesk')
end

local function overlayAssetLabel(assetOrFallback)
    local asset = tostring(assetOrFallback or '')
    asset = asset:match('download%s+(.+)$') or asset
    asset = asset:gsub('^%s+', ''):gsub('%s+$', '')
    return OVERLAY_ASSET_LABELS[asset] or asset
end

local function overlayProgressDetail(opts, step, total, fallback)
    if wantsMinimalOverlay(opts) then
        if total and total > 0 and step > 0 then
            local frac = (step - 1) / total
            if frac < 0.2 then
                return OVERLAY_FRIENDLY_CHECK
            elseif frac < 0.82 then
                return OVERLAY_FRIENDLY_DOWNLOAD
            end
            return OVERLAY_FRIENDLY_INSTALL
        end
        return OVERLAY_FRIENDLY_DOWNLOAD
    end
    if opts and opts.userFacing then
        if total and total > 0 then
            local label = overlayAssetLabel(fallback)
            return string.format('(%d/%d) %s', step, total, label)
        end
        return OVERLAY_DOWNLOAD
    end
    return fallback or OVERLAY_DOWNLOAD
end

local function finishUserFacingUpdate(manifest, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    if not opts.userFacing then
        overlayHide()
        setOverlayContext(nil)
        return
    end
    if opts.firstInstall then
        if overlayEnabled(opts) then
            overlayUpdate(OVERLAY_DONE, 1.0, opts)
            wait(900)
        end
        overlayHide()
        setOverlayContext(nil)
        M.chatSay(FIRST_RUN_READY)
        return
    end
    if overlayEnabled(opts) then
        overlayUpdate(OVERLAY_DONE, 1.0, opts)
        wait(900)
    end
    overlayHide()
    setOverlayContext(nil)
    sayFriendly(UPDATE_DONE, opts)
end

local function failUserFacingUpdate(opts, technical)
    opts = M.resolveUserNotifyOpts(opts or {})
    log(tostring(technical or 'update failed'))
    overlayHide()
    if opts.userFacing then
        M.showUpdateFailMessage(opts)
    else
        notify(tostring(technical or 'update failed'), opts)
    end
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

-- Публичный API модуля.
function M.parseVersion(v)
    v = tostring(v or ''):gsub('^v', '')
    local majorBeta, betaNum = v:match('^(%d+)%s+[Bb]eta%.?(%d*)$')
    if majorBeta then
        local n = tonumber(betaNum) or 0
        if n < 0 then n = 0 end
        if n > 9999 then n = 9999 end
        local base = tonumber(majorBeta) * 1000000
        return base - 10000 + n
    end
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
function M.downloadSync(url, dest, timeoutSec, minBytes, progressLabel)
    if not downloadUrlToFile then
        return false, 'downloadUrlToFile unavailable'
    end
    minBytes = tonumber(minBytes) or 32
    progressLabel = tostring(progressLabel or '')
    ensureDirFor(dest)
    if doesFileExist(dest) then
        pcall(os.remove, dest)
    end
    downloadUrlToFile(url, dest)
    local deadline = os.clock() + (timeoutSec or 60)
    local expectBytes = minBytes > 32 and minBytes or nil
    while os.clock() < deadline do
        if doesFileExist(dest) then
            local f = io.open(dest, 'rb')
            if f then
                local n = f:seek('end') or 0
                f:close()
                if progressLabel ~= '' then
                    if expectBytes then
                        overlayUpdate(progressLabel, math.min(n / expectBytes, 0.98))
                    else
                        overlayUpdate(progressLabel, nil)
                    end
                end
                if n >= minBytes then
                    return true
                end
            end
        elseif progressLabel ~= '' then
            overlayUpdate(progressLabel, nil)
        end
        wait(100)
    end
    if doesFileExist(dest) then
        pcall(os.remove, dest)
    end
    return false, 'timeout'
end

local function downloadWithRetry(url, dest, timeoutSec, minBytes, progressLabel)
    local lastErr = 'unknown'
    for attempt = 1, M.DOWNLOAD_RETRIES do
        local ok, err = M.downloadSync(url, dest, timeoutSec, minBytes, progressLabel)
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
    return deskSha256.hashFile(path)
end

local function isValidLuaBytecode(path)
    path = tostring(path or '')
    if path == '' or not doesFileExist(path) then return false end
    local f = io.open(path, 'rb')
    if not f then return false end
    local h1, h2, h3 = f:read(1), f:read(1), f:read(1)
    local size = f:seek('end') or 0
    f:close()
    if size < 128 then return false end
    if not h1 or not h2 or not h3 then return false end
    return h1:byte() == 0x1b and h2:byte() == 0x4c and h3:byte() == 0x4a
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

local function manifestUsesFilesMap(manifest)
    return type(manifest) == 'table'
        and tonumber(manifest.manifest_version) >= 2
        and type(manifest.files) == 'table'
end

local function manifestUsesV2(manifest)
    return manifestUsesFilesMap(manifest)
end

local function normalizeManifestFiles(manifest)
    if manifestUsesFilesMap(manifest) then
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
    return {}
end

local CORE_FILE_NAMES = {
    'AdminDeskCore.luac',
    'AdminDeskCore.lua',
    'admin_report_desk_core.luac',
    'admin_report_desk_core.lua',
}

function M.resolveCorePath()
    local dir = M.path('report_desk')
    for _, name in ipairs(CORE_FILE_NAMES) do
        local path = dir .. '\\' .. name
        if doesFileExist(path) then
            return path
        end
    end
    return dir .. '\\AdminDeskCore.luac'
end

function M.corePresent()
    return doesFileExist(M.resolveCorePath())
        or doesFileExist(M.path('report_desk\\AdminDeskCore.lua'))
        or doesFileExist(M.path('report_desk\\admin_report_desk_core.lua'))
end

local function removeStaleCoreLuac(installedLuaDest)
    if not installedLuaDest or installedLuaDest == '' then return end
    if not installedLuaDest:find('%.lua$', 1) then return end
    local base = installedLuaDest:gsub('%.lua$', '')
    local staleLuac = base .. '.luac'
    if doesFileExist(staleLuac) then
        pcall(os.remove, staleLuac)
        log('removed stale core.luac: ' .. staleLuac)
    end
    if installedLuaDest:find('AdminDeskCore', 1, true) then
        local legacy = M.path('report_desk\\admin_report_desk_core.luac')
        if doesFileExist(legacy) then
            pcall(os.remove, legacy)
        end
    end
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
    if spec.pending and doesFileExist(path .. '.pending') then
        path = path .. '.pending'
    elseif not doesFileExist(path) then
        return false, 'missing'
    end
    local bytes = fileBytes(path) or 0
    if spec.bytes and spec.bytes > 0 then
        if bytes ~= spec.bytes then
            return false, 'size'
        end
        if spec.sha256 and spec.sha256 ~= '' then
            local hash = M.sha256File(path)
            if not hash or hash:lower() ~= spec.sha256:lower() then
                return false, 'hash'
            end
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

local RUNTIME_LIB_PATHS = {
    'lib\\samp\\events.lua',
    'lib\\samp\\raknet.lua',
    'lib\\samp\\synchronization.lua',
    'lib\\samp\\events\\bitstream_io.lua',
    'lib\\samp\\events\\core.lua',
    'lib\\samp\\events\\extra_types.lua',
    'lib\\samp\\events\\handlers.lua',
    'lib\\samp\\events\\utils.lua',
    'lib\\encoding.lua',
    'lib\\iconv.dll',
    'lib\\vkeys.lua',
    'lib\\vector3d.lua',
}

local function runtimeFilesPresent()
    for _, rel in ipairs(RUNTIME_LIB_PATHS) do
        if not doesFileExist(M.path(rel)) then
            return false
        end
    end
    return true
end

local function runtimeLibsSha256(manifest)
    if type(manifest) == 'table' and type(manifest.runtime_libs) == 'table' then
        local sha = tostring(manifest.runtime_libs.sha256 or ''):lower()
        if sha ~= '' then
            return sha
        end
    end
    return ''
end

local function runtimeLibsInstalled(manifest)
    if not runtimeFilesPresent() then
        return false
    end
    local want = runtimeLibsSha256(manifest)
    if want == '' then
        return true
    end
    local state = M.readState() or {}
    return tostring(state.runtime_libs_sha256 or ''):lower() == want
end

local function needsRuntimeLibs(manifest)
    return not runtimeLibsInstalled(manifest)
end

local function readTextHead(path, maxBytes)
    if not doesFileExist(path) then return nil end
    local f = io.open(path, 'r')
    if not f then return nil end
    local head = f:read(maxBytes or 16384) or ''
    f:close()
    return head
end

local function mimguiHasDeskPatch()
    local head = readTextHead(M.path('lib\\mimgui\\init.lua'), 16384)
    return head and head:find('deskPassesGameKey', 1, true) ~= nil
end

local function mimguiSha256(manifest)
    if type(manifest) == 'table' and type(manifest.mimgui) == 'table' then
        local sha = tostring(manifest.mimgui.sha256 or ''):lower()
        if sha ~= '' then
            return sha
        end
    end
    return ''
end

local function deskMimguiInstalled(manifest)
    if not doesFileExist(M.path('lib\\mimgui\\init.lua'))
        or not doesFileExist(M.path('lib\\mimgui\\cimguidx9.dll')) then
        return false
    end
    if not mimguiHasDeskPatch() then
        return false
    end
    local want = mimguiSha256(manifest)
    if want == '' then
        return true
    end
    local state = M.readState() or {}
    return tostring(state.mimgui_sha256 or ''):lower() == want
end

local function needsDeskMimgui(manifest)
    return not deskMimguiInstalled(manifest)
end

local function markRuntimeLibsInstalled(manifest)
    local want = runtimeLibsSha256(manifest)
    if want == '' then return end
    local state = M.readState() or {}
    state.runtime_libs_sha256 = want
    writeState(state)
end

local function markDeskMimguiInstalled(manifest)
    local want = mimguiSha256(manifest)
    if want == '' then return end
    local state = M.readState() or {}
    state.mimgui_sha256 = want
    writeState(state)
end

-- Публичный API модуля.
function M.needsRuntimeLibs(manifest)
    return needsRuntimeLibs(manifest)
end

-- Публичный API модуля.
function M.hasMimgui()
    return deskMimguiInstalled({})
end

function M.canRequireMimgui()
    if package.loaded.mimgui then return true end
    return pcall(require, 'mimgui') == true
end

function M.installMimguiZip(zipPath)
    reloadDeskSupportModules()
    local root = M.root()
    deskFs.ensureDir(root .. '\\lib')
    local ok, err = deskZip.extract(zipPath, root .. '\\lib')
    if not ok then
        log('mimgui extract: ' .. tostring(err))
        return false
    end
    return M.hasMimgui()
end

-- Публичный API модуля.
function M.installRuntimeLibsZip(zipPath)
    reloadDeskSupportModules()
    local root = M.root()
    local ok, err = deskZip.extract(zipPath, root)
    if not ok then
        log('runtime extract: ' .. tostring(err))
        return false
    end
    if not runtimeFilesPresent() then
        log('runtime install incomplete after extract')
        return false
    end
    return true
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

local function mimguiSpec(manifest)
    if type(manifest.mimgui) == 'table' then
        local spec = manifest.mimgui
        local url = tostring(spec.url or '')
        if url == '' then
            url = M.releaseBaseUrl(manifest) .. '/' .. tostring(spec.asset or M.MIMGUI_ZIP)
        end
        return {
            asset = tostring(spec.asset or M.MIMGUI_ZIP),
            url = url,
            sha256 = tostring(spec.sha256 or ''):lower(),
            bytes = tonumber(spec.bytes) or 0,
        }
    end
    return {
        asset = M.MIMGUI_ZIP,
        url = 'https://github.com/THE-FYP/mimgui/releases/download/v1.7.1/mimgui-v1.7.1.zip',
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
    deskFs.removeTree(dir)
    if not doesDirectoryExist(M.path('report_desk')) then
        createDirectory(M.path('report_desk'))
    end
    deskFs.ensureDir(dir)
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

local function copyFilePreserveSrc(src, dest)
    ensureDirFor(dest)
    local f = io.open(src, 'rb')
    if not f then return false end
    local data = f:read('*a')
    f:close()
    local out = io.open(dest, 'wb')
    if not out then return false end
    out:write(data)
    out:close()
    return doesFileExist(dest)
end

local function replaceFileVerified(src, dest, opts)
    opts = opts or {}
    if not doesFileExist(src) then return false end
    local tmp = dest .. '.new'
    local bak = dest .. '.bak'
    pcall(os.remove, tmp)
    if not copyFilePreserveSrc(src, tmp) then
        pcall(os.remove, tmp)
        return false
    end
    if opts.luac and not isValidLuaBytecode(tmp) then
        pcall(os.remove, tmp)
        return false
    end
    if opts.sha256 and opts.sha256 ~= '' then
        local hash = M.sha256File(tmp)
        if not hash or hash:lower() ~= opts.sha256:lower() then
            pcall(os.remove, tmp)
            return false
        end
    end
    if doesFileExist(dest) then
        pcall(os.remove, bak)
        if not os.rename(dest, bak) then
            pcall(os.remove, tmp)
            return false
        end
    end
    if not os.rename(tmp, dest) then
        if doesFileExist(bak) then
            pcall(os.rename, bak, dest)
        end
        pcall(os.remove, tmp)
        return false
    end
    pcall(os.remove, bak)
    return doesFileExist(dest)
end

local function launcherPendingExpected(destPath)
    local state = M.readState()
    if not state or type(state.files) ~= 'table' then return nil end
    local want = tostring(destPath or ''):gsub('/', '\\'):lower()
    local wantName = want:match('[^\\]+$') or want
    for path, meta in pairs(state.files) do
        local norm = tostring(path):gsub('/', '\\'):lower()
        if norm == want or norm:match('[^\\]+$') == wantName then
            return meta
        end
    end
    return nil
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
    if spec.pending and finalDest:match('%.luac%.pending$') and not isValidLuaBytecode(finalDest) then
        pcall(os.remove, finalDest)
        return false, 'invalid launcher bytecode: ' .. spec.dest
    end
    if spec.dest:find('%.lua$', 1) and spec.dest:find('report_desk', 1, true)
        and (spec.dest:find('AdminDeskCore', 1, true) or spec.dest:find('admin_report_desk_core', 1, true)) then
        removeStaleCoreLuac(M.path(spec.dest))
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
            local ok = localFileMatches(spec)
            if not ok then
                need = true
            end
        end
        if need then
            plan[#plan + 1] = spec
        end
    end

    local rt = runtimeSpec(manifest)
    if force or needsRuntimeLibs(manifest) then
        plan.runtime = rt
    end

    if force or needsDeskMimgui(manifest) then
        plan.mimgui = mimguiSpec(manifest)
    end

    local iv = iconvSpec(manifest)
    if force then
        plan.iconv = iv
    elseif not doesFileExist(M.path(iv.dest)) then
        plan.iconv = iv
    elseif iv.sha256 ~= '' then
        local ok = localFileMatches({
            dest = iv.dest,
            sha256 = iv.sha256,
            bytes = iv.bytes,
            pending = false,
        })
        if not ok then
            plan.iconv = iv
        end
    end

    return plan, state, files
end

function M.buildUpdatePlan(manifest, opts)
    return buildUpdatePlan(manifest, opts)
end

function M.planHasWork(manifest, opts)
    local plan = buildUpdatePlan(manifest, opts or {})
    local fileCount = #plan
    local hasExtra = plan.runtime ~= nil or plan.iconv ~= nil or plan.mimgui ~= nil
    return fileCount > 0 or hasExtra
end

local function downloadPlan(plan, manifest, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    clearStaging()
    local staging = M.path(M.STAGING_DIR)
    local downloaded = {}

    local extraCount = 0
    if plan.runtime then extraCount = extraCount + 1 end
    if plan.mimgui then extraCount = extraCount + 1 end
    if plan.iconv then extraCount = extraCount + 1 end
    local totalSteps = math.max(1, #plan + extraCount)
    local step = 0

    for _, spec in ipairs(plan) do
        step = step + 1
        local techLabel = 'download ' .. spec.asset
        local overlayLabel = overlayProgressDetail(opts, step, totalSteps, techLabel)
        overlayUpdate(overlayLabel, (step - 1) / totalSteps, opts)
        if opts.userFacing then
            log(techLabel)
        else
            notify('\xD1\xEA\xE0\xF7\xE8\xE2\xE0\xED\xE8\xE5 ' .. spec.asset .. '...', opts)
        end
        local tmp = staging .. '\\' .. spec.asset:gsub('[\\/]', '_')
        local minBytes = spec.bytes > 0 and spec.bytes or 32
        local ok, err = downloadWithRetry(spec.url, tmp, 180, minBytes, techLabel)
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
        step = step + 1
        local spec = plan.runtime
        local tmp = staging .. '\\' .. spec.asset
        local techLabel = 'download ' .. spec.asset
        overlayUpdate(overlayProgressDetail(opts, step, totalSteps, techLabel), (step - 1) / totalSteps, opts)
        if opts.userFacing then
            log(techLabel)
        else
            notify('\xD1\xEA\xE0\xF7\xE8\xE2\xE0\xED\xE8\xE5 ' .. spec.asset .. '...', opts)
        end
        local ok, err = downloadWithRetry(spec.url, tmp, 120, 512, techLabel)
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

    if plan.mimgui then
        step = step + 1
        local spec = plan.mimgui
        local tmp = staging .. '\\' .. spec.asset
        local techLabel = 'download mimgui'
        overlayUpdate(overlayProgressDetail(opts, step, totalSteps, techLabel), (step - 1) / totalSteps, opts)
        if opts.userFacing then
            log(techLabel)
        else
            notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 mimgui...', opts)
        end
        local ok, err = downloadWithRetry(spec.url, tmp, 120, 1024, techLabel)
        if not ok then
            return nil, 'download mimgui: ' .. tostring(err)
        end
        if spec.sha256 ~= '' then
            local verOk, verErr = verifyFile(tmp, spec)
            if not verOk then
                pcall(os.remove, tmp)
                return nil, 'verify mimgui: ' .. tostring(verErr)
            end
        end
        downloaded.mimgui = tmp
    end

    if plan.iconv then
        step = step + 1
        local spec = plan.iconv
        local tmp = staging .. '\\iconv.dll'
        local techLabel = 'download iconv.dll'
        overlayUpdate(overlayProgressDetail(opts, step, totalSteps, techLabel), (step - 1) / totalSteps, opts)
        if opts.userFacing then
            log(techLabel)
        else
            notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 iconv...', opts)
        end
        local ok, err = downloadWithRetry(spec.url, tmp, 60, 4096, techLabel)
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

local function disableLegacyLauncher()
    local legacy = M.path('admin_report_desk.lua')
    local off = legacy .. '.off'
    if doesFileExist(M.path('AdminDesk.luac')) and doesFileExist(legacy) then
        pcall(os.remove, off)
        if os.rename(legacy, off) then
            log('disabled legacy launcher: ' .. legacy)
        end
    end
end

local function assetMarkerOk()
    local paths = {
        M.path('res\\report_desk_skins\\skin-1.png'),
        M.path('config\\AdminDesk\\assets\\res\\report_desk_skins\\skin-1.png'),
    }
    for _, p in ipairs(paths) do
        if doesFileExist(p) then
            local sz = fileBytes(p)
            if type(sz) == 'number' and sz > 256 then
                return true
            end
        end
    end
    return false
end

local function commitPlan(downloaded, manifest, allFiles, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    local installLabel = wantsMinimalOverlay(opts) and OVERLAY_FRIENDLY_INSTALL
        or (opts.userFacing and OVERLAY_INSTALL or '\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 \xF4\xE0\xE9\xEB\xEE\xE2...')
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

    reloadDeskSupportModules()

    overlayUpdate(installLabel, 0.92, opts)

    if downloaded.runtime then
        overlayUpdate(wantsMinimalOverlay(opts) and OVERLAY_FRIENDLY_INSTALL or (opts.userFacing and OVERLAY_INSTALL or '\xD0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE0 runtime...'), 0.94, opts)
        if not M.installRuntimeLibsZip(downloaded.runtime) then
            return false, 'runtime unpack failed'
        end
        markRuntimeLibsInstalled(manifest)
        pcall(os.remove, downloaded.runtime)
    end

    if downloaded.mimgui then
        overlayUpdate(wantsMinimalOverlay(opts) and OVERLAY_FRIENDLY_INSTALL or (opts.userFacing and OVERLAY_INSTALL or '\xD0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE0 mimgui...'), 0.96, opts)
        if not M.installMimguiZip(downloaded.mimgui) then
            return false, 'mimgui unpack failed'
        end
        package.loaded.mimgui = nil
        markDeskMimguiInstalled(manifest)
        pcall(os.remove, downloaded.mimgui)
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
    local rtSha = runtimeLibsSha256(manifest)
    if rtSha ~= '' and runtimeFilesPresent() then
        state.runtime_libs_sha256 = rtSha
    end
    local mmSha = mimguiSha256(manifest)
    if mmSha ~= '' and deskMimguiInstalled(manifest) then
        state.mimgui_sha256 = mmSha
    end
    writeState(state)
    writeTextFile(M.path(M.LEGACY_CORE_VERSION), state.version .. '\n')

    clearStaging()
    package.loaded['report_desk_deps'] = nil
    package.loaded['lib.report_desk_deps'] = nil
    package.loaded['report_desk_autoupdate'] = nil
    package.loaded['lib.report_desk_autoupdate'] = nil
    disableLegacyLauncher()
    return true
end

--[[ returns: needsReload, status ]]
function M.sync(manifest, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    if M.isDevEnvironment() then
        return false, 'dev'
    end
    updatePhase = UPDATE_PHASE.FETCH
    if not manifest then
        updatePhase = UPDATE_PHASE.IDLE
        return false, 'offline'
    end
    local plan, state, allFiles = buildUpdatePlan(manifest, opts)
    local fileCount = #plan
    local hasExtra = plan.runtime ~= nil or plan.iconv ~= nil or plan.mimgui ~= nil or plan.mimgui ~= nil
    if fileCount == 0 and not hasExtra then
        overlayHide()
        setOverlayContext(nil)
        return false, 'uptodate'
    end

    if opts.mode == 'bootstrap' and fileCount > 0 then
        local filtered = {}
        local keepRuntime = plan.runtime
        local keepIconv = plan.iconv
        local keepMimgui = plan.mimgui
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
        plan.mimgui = keepMimgui
        fileCount = #plan
        hasExtra = plan.runtime ~= nil or plan.iconv ~= nil or plan.mimgui ~= nil
        if fileCount == 0 and not hasExtra then
            overlayHide()
            setOverlayContext(nil)
            return false, 'uptodate'
        end
    end

    local remoteVer = tostring(manifest.version or '')
    if opts.userFacing then
        log('sync ' .. remoteVer .. ' (' .. tostring(fileCount + (hasExtra and 1 or 0)) .. ' items)')
        if not opts.firstInstall then
            sayFriendly(UPDATE_START, opts)
        end
    else
        notify('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 ' .. remoteVer .. ' (' .. tostring(fileCount + (hasExtra and 1 or 0)) .. ' files)...', opts)
    end

    setOverlayContext(opts)
    if overlayEnabled(opts) then
        if wantsMinimalOverlay(opts) then
            overlayShow(nil, OVERLAY_FRIENDLY_CHECK, opts)
        elseif opts.userFacing then
            overlayShow(OVERLAY_TITLE, OVERLAY_DOWNLOAD, opts)
        else
            overlayShow('\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 Report Desk', '\xC2\xE5\xF0\xF1\xE8\xFF ' .. remoteVer, opts)
        end
    end

    updatePhase = UPDATE_PHASE.STAGE
    local downloaded, dlErr = downloadPlan(plan, manifest, opts)
    if not downloaded then
        updatePhase = UPDATE_PHASE.IDLE
        setOverlayContext(nil)
        failUserFacingUpdate(opts, 'download failed: ' .. tostring(dlErr))
        return false, 'fail'
    end

    updatePhase = UPDATE_PHASE.COMMIT
    local ok, commitErr = commitPlan(downloaded, manifest, allFiles, opts)
    if not ok then
        updatePhase = UPDATE_PHASE.IDLE
        setOverlayContext(nil)
        failUserFacingUpdate(opts, 'commit failed: ' .. tostring(commitErr))
        return false, 'fail'
    end
    updatePhase = UPDATE_PHASE.IDLE

    log('installed ' .. remoteVer)
    if opts.userFacing then
        finishUserFacingUpdate(manifest, opts)
    else
        overlayUpdate('\xC3\xEE\xF2\xEE\xE2\xEE', 1.0, opts)
        notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xEE ' .. remoteVer, opts)
        overlayHide()
    end
    setOverlayContext(nil)
    local needsPendingReload = false
    for _, item in ipairs(downloaded) do
        if item.spec.pending then
            needsPendingReload = true
            break
        end
    end
    if needsPendingReload then
        if opts.reload == false then
            return true, 'pending'
        end
        notify('\xCF\xE5\xF0\xE5\xE7\xE0\xE3\xF0\xF3\xE7\xEA\xE0 \xF1\xEA\xF0\xE8\xEF\xF2\xE0 (~2 \xF1\xE5\xEA)...', opts)
        wait(2000)
        if thisScript and thisScript().reload then
            thisScript():reload()
            return true, 'reload'
        end
        return true, 'pending'
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
    corePath = corePath or M.resolveCorePath()
    local manifest, err = M.fetchRemoteManifest()
    if not manifest then
        log('manifest skip: ' .. tostring(err))
        if not M.corePresent() then
            notify('\xDF\xE4\xF0\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE, \xEE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xEE')
        end
        return false, 'offline'
    end
    local willReload, status = M.sync(manifest, { quietChat = true, mode = 'full', includeCore = true })
    if willReload then
        return true, status
    end
    if M.needsAssets(manifest) then
        local ok, assetsUpdated = M.ensureAssets(manifest, { quietChat = true })
        if not ok then
            return false, 'assets_fail'
        end
    end
    return willReload, status
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
        if M.needsAssets(manifest) then
            local ok = M.ensureAssets(manifest, { quietChat = true })
            if not ok then
                return false, 'assets_fail'
            end
        end
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
    local willReload, status = M.sync(manifest, { mode = 'repair', force = true, includeCore = true, reload = false })
    if status == 'fail' then
        return false, status
    end
    if willReload then
        M.applyPendingFiles({ includeLauncher = false })
        package.loaded['report_desk_autoupdate'] = nil
        package.loaded['lib.report_desk_autoupdate'] = nil
        if M.applyLauncherPending and M.applyLauncherPending() then
            log('launcher pending committed on disk (next game start)')
        end
    end
    if M.needsAssets(manifest) then
        local ok, assetsUpdated = M.ensureAssets(manifest, { quietChat = false })
        if not ok then
            return false, 'assets_fail'
        end
    end
    return willReload, status
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
        runtime_libs_ok = false,
        mimgui_ok = false,
        core_present = M.corePresent(),
        assets_version = (M.readState() or {}).assets_version or '',
    }
    local manifest, err = M.fetchRemoteManifest()
    if not manifest then
        result.manifest_error = err
        return result
    end
    result.manifest_ok = true
    result.remote_version = tostring(manifest.version or '')
    result.manifest_v2 = manifestUsesV2(manifest)
    result.runtime_libs_ok = runtimeLibsInstalled(manifest)
    result.mimgui_ok = deskMimguiInstalled(manifest)
    if type(manifest.assets) == 'table' then
        result.remote_assets_version = tostring(manifest.assets.version or '')
        result.assets_ok = tostring(result.assets_version) == result.remote_assets_version
            and assetMarkerOk()
    end

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
    if not result.runtime_libs_ok or not result.mimgui_ok then
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
        M.chatSay('runtime libs: \xED\xE5\xEF\xEE\xEB\xED\xFB\xE5 \xE8\xEB\xE8 \xF3\xF1\xF2\xE0\xF0\xE5\xEB\xE8')
    end
    if not d.mimgui_ok then
        M.chatSay('mimgui: \xED\xF3\xE6\xE5\xED patched lib/mimgui (\xED\xE5 vanilla)')
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
function M.applyLauncherPending()
    local root = M.root()
    local specs = {
        { pending = root .. '\\AdminDesk.luac.pending', dest = root .. '\\AdminDesk.luac', luac = true },
        { pending = root .. '\\AdminDesk.lua.pending', dest = root .. '\\AdminDesk.lua', luac = false },
    }
    for _, spec in ipairs(specs) do
        if not doesFileExist(spec.pending) then
        else
            if spec.luac and not isValidLuaBytecode(spec.pending) then
                log('skip invalid launcher pending (bad bytecode): ' .. spec.pending)
                pcall(os.remove, spec.pending)
                return false
            end
            local pendingBytes = fileBytes(spec.pending) or 0
            if pendingBytes < 128 then
                log('skip invalid launcher pending (too small): ' .. spec.pending)
                pcall(os.remove, spec.pending)
                return false
            end
            local expected = launcherPendingExpected(spec.dest)
            if expected and expected.sha256 and expected.sha256 ~= '' then
                local hash = M.sha256File(spec.pending)
                if not hash or hash:lower() ~= expected.sha256:lower() then
                    log('skip launcher pending (sha256 mismatch): ' .. spec.pending)
                    pcall(os.remove, spec.pending)
                    return false
                end
            elseif spec.luac and doesFileExist(spec.dest) and isValidLuaBytecode(spec.dest) then
                local destBytes = fileBytes(spec.dest) or 0
                if pendingBytes < destBytes * 0.5 then
                    log('skip suspicious launcher pending (smaller than installed): ' .. spec.pending)
                    pcall(os.remove, spec.pending)
                    return false
                end
            end
            if not replaceFileVerified(spec.pending, spec.dest, {
                luac = spec.luac,
                sha256 = expected and expected.sha256 or '',
            }) then
                log('launcher pending replace failed, kept existing: ' .. spec.dest)
                pcall(os.remove, spec.pending)
                return false
            end
            pcall(os.remove, spec.pending)
            log('applied launcher pending: ' .. spec.dest)
            return true
        end
    end
    return false
end

-- Публичный API модуля.
function M.applyPendingFiles(opts)
    opts = opts or {}
    local includeLauncher = opts.includeLauncher == true
    local root = M.root()
    local pendingSpecs = {}
    if includeLauncher then
        pendingSpecs[#pendingSpecs + 1] = { pending = root .. '\\AdminDesk.luac.pending', dest = root .. '\\AdminDesk.luac' }
        pendingSpecs[#pendingSpecs + 1] = { pending = root .. '\\AdminDesk.lua.pending', dest = root .. '\\AdminDesk.lua' }
    end
    pendingSpecs[#pendingSpecs + 1] = { pending = root .. '\\admin_report_desk.lua.pending', dest = root .. '\\admin_report_desk.lua' }
    pendingSpecs[#pendingSpecs + 1] = { pending = root .. '\\lib\\report_desk_autoupdate.lua.pending', dest = root .. '\\lib\\report_desk_autoupdate.lua' }
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
    return fallback or (M.coreDir() .. '\\AdminDeskCore.luac')
end

function M.readLocalAssetsManifest()
    return M.readJsonFile(M.path(M.ASSETS_MANIFEST))
end

function M.writeLocalAssetsManifest(data)
    deskFs.ensureDirForFile(M.path(M.ASSETS_MANIFEST))
    return writeJsonFile(M.path(M.ASSETS_MANIFEST), data)
end

function M.assetsInstalledFor(manifest)
    manifest = manifest or {}
    if not assetMarkerOk() then
        return false
    end
    local assets = manifest.assets
    if type(assets) ~= 'table' then
        return true
    end
    local remoteSha = tostring(assets.sha256 or ''):lower()
    if remoteSha == '' then
        return true
    end
    local localMan = M.readLocalAssetsManifest() or {}
    local localSha = tostring(localMan.sha256 or ''):lower()
    return localSha ~= '' and localSha == remoteSha
end

function M.reconcileAssetsState(manifest)
    manifest = manifest or {}
    local assets = manifest.assets
    if type(assets) ~= 'table' or not assetMarkerOk() then
        return false
    end
    if M.needsAssets(manifest) then
        return false
    end
    local remoteVer = tostring(assets.version or manifest.version or '')
    local remoteSha = tostring(assets.sha256 or ''):lower()
    local state = migrateLegacyState() or { files = {} }
    state.assets_version = remoteVer
    writeState(state)
    M.writeLocalAssetsManifest({
        version = remoteVer,
        sha256 = remoteSha,
        installed = true,
    })
    log('assets state reconciled: ' .. remoteVer)
    return true
end

function M.needsAssets(manifest)
    manifest = manifest or {}
    if M.isDevEnvironment() then
        return false
    end
    local assets = manifest.assets
    if type(assets) ~= 'table' then
        return not assetMarkerOk()
    end
    local remoteSha = tostring(assets.sha256 or ''):lower()
    local remoteVer = tostring(assets.version or '')
    if remoteSha == '' and remoteVer == '' then
        return not assetMarkerOk()
    end
    if M.assetsInstalledFor(manifest) then
        return false
    end
    if not assetMarkerOk() then
        return true
    end
    if remoteSha ~= '' then
        local zipPath = M.path(M.ASSETS_CACHE_DIR .. '\\' .. M.ASSETS_ZIP)
        if doesFileExist(zipPath) then
            local ok = select(1, verifyFile(zipPath, {
                sha256 = remoteSha,
                bytes = tonumber(assets.bytes) or 0,
            }))
            if ok then
                return false
            end
        end
    end
    if remoteVer ~= '' then
        local localMan = M.readLocalAssetsManifest() or {}
        if tostring(localMan.version or '') == remoteVer then
            return false
        end
        local state = M.readState() or {}
        if tostring(state.assets_version or '') == remoteVer then
            return false
        end
    end
    return true
end

local function extractAssetsZip(zipPath)
    reloadDeskSupportModules()
    zipPath = tostring(zipPath or '')
    if zipPath == '' or not doesFileExist(zipPath) then
        return false, 'zip missing'
    end
    local destRoot = M.root()
    local estFiles = 520
    local ok, err = deskZip.extract(zipPath, destRoot, {
        yieldEvery = 64,
        onProgress = function(count)
            overlayUpdate('\xD0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE0 \xEF\xF0\xE5\xE2\xFC\xFE (' .. tostring(count) .. ')', math.min(count / estFiles, 0.99))
        end,
    })
    if not ok then
        return false, err or 'extract failed'
    end
    if assetMarkerOk() then
        return true
    end
    return false, 'marker missing'
end

function M.ensureAssets(manifest, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    manifest = manifest or {}
    if not M.needsAssets(manifest) then
        return true, false
    end
    local assets = manifest.assets
    if type(assets) ~= 'table' or not assets.url or assets.url == '' then
        if not assetMarkerOk() then
            if opts.userFacing then
                log('assets missing in manifest and no skin-1.png')
            else
                notify('\xCD\xE5\xF2 assets \xE2 manifest \xE8 \xED\xE5\xF2 skin-1.png', opts)
            end
            return false, false
        end
        return true, false
    end
    if opts.showOverlay ~= false and opts.userFacing then
        log('downloading assets')
        setOverlayContext(opts)
        if wantsMinimalOverlay(opts) then
            overlayShow(nil, OVERLAY_FRIENDLY_DOWNLOAD, opts)
        else
            overlayShow(OVERLAY_TITLE, OVERLAY_ASSETS, opts)
        end
    else
        log('downloading assets (background)')
    end
    local zipPath = M.path(M.ASSETS_CACHE_DIR .. '\\' .. M.ASSETS_ZIP)
    deskFs.ensureDirForFile(zipPath)
    local assetBytes = tonumber(assets.bytes) or 65536
    local dlLabel = opts.userFacing and OVERLAY_ASSETS or '\xC7\xE0\xE3\xF0\xF3\xE7\xEA\xE0 \xEF\xF0\xE5\xE2\xFC\xFE'
    local ok, err = downloadWithRetry(assets.url, zipPath, 300, assetBytes, dlLabel)
    if not ok then
        overlayHide()
        setOverlayContext(nil)
        if opts.userFacing then
            log('assets download failed: ' .. tostring(err))
        else
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 assets: ' .. tostring(err), opts)
        end
        return false, false
    end
    if assets.sha256 and assets.sha256 ~= '' then
        local verOk, verErr = verifyFile(zipPath, {
            sha256 = tostring(assets.sha256):lower(),
            bytes = tonumber(assets.bytes) or 0,
        })
        if not verOk then
            if opts.userFacing then
                log('assets verify failed: ' .. tostring(verErr))
            else
                notify('\xCE\xF8\xE8\xE1\xEA\xE0 assets: ' .. tostring(verErr), opts)
            end
            pcall(os.remove, zipPath)
            return false, false
        end
    end
    if opts.showOverlay ~= false and opts.userFacing then
        overlayUpdate(wantsMinimalOverlay(opts) and OVERLAY_FRIENDLY_INSTALL or OVERLAY_INSTALL, 0.85, opts)
    end
    local extracted, extractErr = extractAssetsZip(zipPath)
    if not extracted then
        overlayHide()
        setOverlayContext(nil)
        if opts.userFacing then
            log('assets extract failed: ' .. tostring(extractErr))
        else
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xF0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE8 assets: ' .. tostring(extractErr), opts)
        end
        return false, false
    end
    local state = migrateLegacyState() or { files = {} }
    state.assets_version = tostring(assets.version or manifest.version or '')
    writeState(state)
    M.writeLocalAssetsManifest({
        version = state.assets_version,
        sha256 = tostring(assets.sha256 or ''):lower(),
        installed = true,
    })
    log('assets OK')
    if opts.userFacing then
        overlayUpdate(OVERLAY_DONE, 1.0, opts)
        wait(800)
    else
        overlayUpdate('\xC3\xEE\xF2\xEE\xE2\xEE', 1.0, opts)
        notify('assets OK', opts)
    end
    overlayHide()
    setOverlayContext(nil)
    return true, true
end

function M.deferAssets(manifest, opts)
    if M.isDevEnvironment() then
        return false
    end
    opts = M.resolveUserNotifyOpts(opts or {})
    manifest = manifest or {}
    opts.showOverlay = false
    opts.quietChat = true
    if not M.needsAssets(manifest) then
        M.reconcileAssetsState(manifest)
        return false
    end
    if not lua_thread or not lua_thread.create then
        return M.ensureAssets(manifest, opts)
    end
    lua_thread.create(function()
        pcall(function()
            setOverlayContext(opts)
            M.ensureAssets(manifest, opts)
        end)
        overlayHide()
        setOverlayContext(nil)
    end)
    return true
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
    opts = M.resolveUserNotifyOpts(opts or {})
    if doesFileExist(M.path(M.ICONV_DLL)) then
        return true, false
    end
    local spec = iconvSpec(manifest or {})
    if spec.url == '' then
        return false, false
    end
    if opts.userFacing then
        log('installing iconv')
    else
        notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 iconv...', opts)
    end
    ensureDirFor(M.path(M.ICONV_DLL))
    if not doesDirectoryExist(M.path('lib')) then
        createDirectory(M.path('lib'))
    end
    local tmp = M.path('report_desk\\_update_staging\\iconv.dll')
    ensureDirFor(tmp)
    local ok, err = downloadWithRetry(spec.url, tmp, 45, 4096)
    if not ok then
        if opts.userFacing then
            log('iconv download failed: ' .. tostring(err))
        else
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 iconv: ' .. tostring(err), opts)
        end
        return false, false
    end
    if spec.sha256 ~= '' then
        local verOk, verErr = verifyFile(tmp, spec)
        if not verOk then
            if opts.userFacing then
                log('iconv verify failed: ' .. tostring(verErr))
            else
                notify('\xCE\xF8\xE8\xE1\xEA\xE0 iconv: ' .. tostring(verErr), opts)
            end
            return false, false
        end
    end
    if not copyFileAtomic(tmp, M.path(M.ICONV_DLL)) then
        return false, false
    end
    return true, true
end

function M.ensureRuntimeLibs(manifest, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    manifest = manifest or {}
    if not needsRuntimeLibs(manifest) then
        return true, false
    end
    local spec = runtimeSpec(manifest or {})
    if opts.userFacing then
        log('installing runtime libs')
    else
        notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 lib...', opts)
    end
    local zipPath = M.path('report_desk\\' .. M.RUNTIME_LIBS_ZIP)
    ensureDirFor(zipPath)
    local ok, err = downloadWithRetry(spec.url, zipPath, 90, 1024)
    if not ok then
        if opts.userFacing then
            log('runtime download failed: ' .. tostring(err))
        else
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 lib: ' .. tostring(err), opts)
        end
        return false, false
    end
    if spec.sha256 ~= '' then
        local verOk, verErr = verifyFile(zipPath, spec)
        if not verOk then
            if opts.userFacing then
                log('runtime verify failed: ' .. tostring(verErr))
            else
                notify('\xCE\xF8\xE8\xE1\xEA\xE0 lib: ' .. tostring(verErr), opts)
            end
            return false, false
        end
    end
    if not M.installRuntimeLibsZip(zipPath) then
        if opts.userFacing then
            log('runtime unpack failed')
        else
            notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xF0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE8 lib', opts)
        end
        return false, false
    end
    markRuntimeLibsInstalled(manifest)
    log('runtime libs OK')
    return true, true
end

function M.ensureDependencies(manifest, opts)
    opts = M.resolveUserNotifyOpts(opts or {})
    manifest = manifest or {}
    local changed = false

    local iv = iconvSpec(manifest)
    if not localFileMatches({
        dest = iv.dest,
        sha256 = iv.sha256,
        bytes = iv.bytes,
        pending = false,
    }) then
        local ok = select(1, M.ensureIconvDll(manifest, opts))
        if not ok then return false, false end
        changed = true
    end

    if needsRuntimeLibs(manifest) then
        local ok = select(1, M.ensureRuntimeLibs(manifest, opts))
        if not ok then return false, false end
        changed = true
    end

    if needsDeskMimgui(manifest) then
        local spec = mimguiSpec(manifest)
        if opts.userFacing then
            log('installing mimgui')
            if overlayEnabled(opts) then
                setOverlayContext(opts)
                if wantsMinimalOverlay(opts) then
                    overlayShow(nil, OVERLAY_FRIENDLY_DOWNLOAD, opts)
                else
                    overlayShow(OVERLAY_TITLE, OVERLAY_DOWNLOAD, opts)
                end
            end
        else
            notify('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 mimgui...', opts)
        end
        local zipPath = M.path('report_desk\\' .. spec.asset)
        deskFs.ensureDirForFile(zipPath)
        local ok, err = downloadWithRetry(spec.url, zipPath, 120, 1024, opts.userFacing and OVERLAY_DOWNLOAD or 'mimgui')
        if not ok then
            overlayHide()
            setOverlayContext(nil)
            if opts.userFacing then
                log('mimgui download failed: ' .. tostring(err))
            else
                notify('\xCE\xF8\xE8\xE1\xEA\xE0 mimgui: ' .. tostring(err), opts)
            end
            return false, false
        end
        if spec.sha256 ~= '' then
            local verOk, verErr = verifyFile(zipPath, spec)
            if not verOk then
                overlayHide()
                setOverlayContext(nil)
                if opts.userFacing then
                    log('mimgui verify failed: ' .. tostring(verErr))
                else
                    notify('\xCE\xF8\xE8\xE1\xEA\xE0 mimgui: ' .. tostring(verErr), opts)
                end
                return false, false
            end
        end
        if opts.userFacing then
            overlayUpdate(wantsMinimalOverlay(opts) and OVERLAY_FRIENDLY_INSTALL or OVERLAY_INSTALL, 0.9, opts)
        end
        if not M.installMimguiZip(zipPath) then
            overlayHide()
            setOverlayContext(nil)
            if opts.userFacing then
                log('mimgui unpack failed')
            else
                notify('\xCE\xF8\xE8\xE1\xEA\xE0 \xF0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE8 mimgui', opts)
            end
            return false, false
        end
        package.loaded.mimgui = nil
        if not M.canRequireMimgui() then
            overlayHide()
            setOverlayContext(nil)
            if opts.userFacing then
                log('mimgui require failed after install')
            else
                notify('mimgui install failed (require)', opts)
            end
            return false, false
        end
        if opts.userFacing then
            overlayUpdate(OVERLAY_DONE, 1.0, opts)
            wait(600)
            overlayHide()
            setOverlayContext(nil)
        end
        markDeskMimguiInstalled(manifest)
        log('mimgui OK')
        changed = true
    elseif not M.canRequireMimgui() then
        log('mimgui present but require failed')
        return false, false
    end

    overlayHide()
    setOverlayContext(nil)
    return true, changed
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
