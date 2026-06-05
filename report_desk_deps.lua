--[[ Report Desk — проверка и установка зависимостей MoonLoader ]]
local M = {}

M.MIMGUI_ZIP_URL = 'https://github.com/THE-FYP/mimgui/releases/download/v1.7.1/mimgui-v1.7.1.zip'
M.MIMGUI_INIT = 'lib\\mimgui\\init.lua'
M.MIMGUI_DLL = 'lib\\mimgui\\cimguidx9.dll'

function M.root()
    return getWorkingDirectory()
end

function M.path(rel)
    return M.root() .. '\\' .. rel:gsub('/', '\\')
end

function M.hasMimgui()
    return doesFileExist(M.path(M.MIMGUI_INIT)) and doesFileExist(M.path(M.MIMGUI_DLL))
end

function M.canRequireMimgui()
    if package.loaded.mimgui then return true end
    local ok = pcall(require, 'mimgui')
    return ok == true
end

local function psLiteral(s)
    s = tostring(s or ''):gsub("'", "''")
    return "'" .. s .. "'"
end

function M.downloadSync(url, dest, timeoutSec)
    if not downloadUrlToFile then
        return false, 'downloadUrlToFile unavailable'
    end
    if doesFileExist(dest) then
        os.remove(dest)
    end
    downloadUrlToFile(url, dest)
    local deadline = os.clock() + (timeoutSec or 60)
    while os.clock() < deadline do
        if doesFileExist(dest) then
            local f = io.open(dest, 'rb')
            if f then
                local n = f:seek('end') or 0
                f:close()
                if n > 1024 then
                    return true
                end
            end
        end
        wait(100)
    end
    return false, 'timeout'
end

function M.installMimguiZip(zipPath)
    local root = M.root()
    local tmp = root .. '\\report_desk\\_deps_mimgui_tmp'
    local libDir = root .. '\\lib'
    local dest = libDir .. '\\mimgui'
    local ps = table.concat({
        'powershell -NoProfile -ExecutionPolicy Bypass -Command "& {',
        '$tmp=' .. psLiteral(tmp) .. ';',
        '$zip=' .. psLiteral(zipPath) .. ';',
        '$lib=' .. psLiteral(libDir) .. ';',
        '$dest=' .. psLiteral(dest) .. ';',
        'Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue;',
        'Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force;',
        'if (-not (Test-Path (Join-Path $tmp ''mimgui''))) { exit 2 };',
        'New-Item -ItemType Directory -Path $lib -Force | Out-Null;',
        'Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue;',
        'Copy-Item -LiteralPath (Join-Path $tmp ''mimgui'') -Destination $dest -Recurse -Force;',
        'Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue',
        '}"',
    }, ' ')
    local ok = os.execute(ps)
    if ok == 0 or ok == true then
        return M.hasMimgui()
    end
    return false
end

function M.checkRuntime(opts)
    opts = opts or {}
    local say = opts.say
    local problems = {}

    if getMoonloaderVersion and (tonumber(getMoonloaderVersion()) or 0) < 26 then
        problems[#problems + 1] = 'MoonLoader 0.26+'
    end
    if not isSampfuncsLoaded or not isSampfuncsLoaded() then
        problems[#problems + 1] = 'SAMPFUNCS'
    end
    if not isSampLoaded or not isSampLoaded() then
        problems[#problems + 1] = 'SAMP'
    end

    if #problems > 0 and say then
        say('need: ' .. table.concat(problems, ', '))
    end
    return #problems == 0, problems
end

function M.ensureMimgui(opts)
    opts = opts or {}
    local say = opts.say

    if M.hasMimgui() and M.canRequireMimgui() then
        return true, false
    end

    if say then
        say('\xD3\xF1\xF2\xE0\xED\xEE\xE2\xEA\xE0 mimgui...')
    end

    local zipPath = M.path('report_desk\\mimgui-v1.7.1.zip')
    M.ensureCoreDir(zipPath)
    local ok, err = M.downloadSync(M.MIMGUI_ZIP_URL, zipPath, 90)
    if not ok then
        if say then
            say('\xCE\xF8\xE8\xE1\xEA\xE0 mimgui: ' .. tostring(err))
        end
        return false, false
    end

    if not M.installMimguiZip(zipPath) then
        if say then
            say('\xCE\xF8\xE8\xE1\xEA\xE0 \xF0\xE0\xF1\xEF\xE0\xEA\xEE\xE2\xEA\xE8 mimgui')
        end
        return false, false
    end

    package.loaded.mimgui = nil
    if not M.canRequireMimgui() then
        if say then
            say('mimgui install failed (require)')
        end
        return false, false
    end

    if say then
        say('mimgui OK')
    end
    return true, true
end

function M.ensureCoreDir(filePath)
    local dir = filePath:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

function M.ensureAll(opts)
    opts = opts or {}
    local runtimeOk = M.checkRuntime(opts)
    if not runtimeOk then
        return false, false
    end
    return M.ensureMimgui(opts)
end

return M
