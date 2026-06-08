--[[ Report Desk — проверка зависимостей (тонкая обёртка над autoupdate) ]]
local M = {}

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
    return pcall(require, 'mimgui') == true
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

    if #problems > 0 then
        local msg = 'need: ' .. table.concat(problems, ', ')
        print('[Report Desk] ' .. msg)
        if say then
            say(msg)
        end
    end
    return #problems == 0, problems
end

function M.ensureCoreDir(filePath)
    local dir = filePath:match('^(.*)\\[^\\]+$')
    if dir and dir ~= '' and not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

local function requireAutoupdate()
    local ok, mod = pcall(require, 'lib.report_desk_autoupdate')
    if ok then return mod end
    ok, mod = pcall(require, 'report_desk_autoupdate')
    if ok then return mod end
    return nil
end

function M.ensureAll(opts)
    opts = opts or {}
    local runtimeOk = M.checkRuntime(opts)
    if not runtimeOk then
        return false, false
    end

    local autoupdate = requireAutoupdate()
    if not autoupdate then
        if M.hasMimgui() and M.canRequireMimgui() then
            return true, false
        end
        if opts.say then
            opts.say('missing report_desk_autoupdate.lua')
        end
        return false, false
    end

    local manifest = opts.manifest
    if not manifest and autoupdate.fetchRemoteManifest then
        manifest = select(1, autoupdate.fetchRemoteManifest())
    end

    if autoupdate.ensureDependencies then
        return autoupdate.ensureDependencies(manifest, {
            say = opts.say,
            quietChat = opts.say == nil,
        })
    end

    if M.hasMimgui() and M.canRequireMimgui() then
        return true, false
    end
    return false, false
end

return M
