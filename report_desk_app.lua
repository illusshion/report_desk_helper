--[[ Report Desk application loader — loads domain chunks into one scope ]]
local M = {}

local MODULE_DIR = 'lib\\'

local CORE_CHUNK_FILES = {
    'report_desk_bootstrap.lua',
    'report_desk_constants.lua',
    'report_desk_theme.lua',
    'report_desk_state.lua',
    'report_desk_util.lua',
    'report_desk_profanity.lua',
    'report_desk_chat.lua',
    'report_desk_cheats.lua',
    'report_desk_skins.lua',
    'report_desk_input.lua',
    'report_desk_actions.lua',
    'report_desk_threads.lua',
    'report_desk_config.lua',
    'report_desk_ingest_runtime.lua',
    'report_desk_rules.lua',
    'report_desk_ui.lua',
    'report_desk_hooks.lua',
    'report_desk_env_export.lua',
    'report_desk_main.lua',
}

local LATE_CHUNK_FILES = {
    'report_desk_checker.lua',
}

local loaded = false
local env = nil

local function modulePath(wd, name)
    return wd .. '\\' .. MODULE_DIR .. name
end

local function readModuleText(wd, name)
    local path = modulePath(wd, name)
    if not doesFileExist(path) then
        error('[Report Desk] missing module: ' .. path)
    end
    local f, err = io.open(path, 'rb')
    if not f then
        error('[Report Desk] read failed: ' .. tostring(err))
    end
    local text = f:read('*a')
    f:close()
    return text
end

local function runChunkBundle(wd, names, targetEnv, label)
    _G.__REPORT_DESK_BUNDLE_ACTIVE = true
    local parts = {}
    for _, name in ipairs(names) do
        parts[#parts + 1] = readModuleText(wd, name)
    end
    local src = table.concat(parts, '\n')
    local fn, errLoad = loadstring(src, '@report_desk_app/' .. label)
    if not fn then
        _G.__REPORT_DESK_BUNDLE_ACTIVE = nil
        error('[Report Desk] load failed (' .. label .. '): ' .. tostring(errLoad))
    end
    setfenv(fn, targetEnv)
    local ok, errRun = pcall(fn)
    _G.__REPORT_DESK_BUNDLE_ACTIVE = nil
    if not ok then
        error('[Report Desk] init failed (' .. label .. '): ' .. tostring(errRun))
    end
end

function M.load()
    if loaded then return env end

    local wd = getWorkingDirectory()
    env = {}
    setmetatable(env, { __index = _G })

    runChunkBundle(wd, CORE_CHUNK_FILES, env, 'core')
    runChunkBundle(wd, LATE_CHUNK_FILES, env, 'checker')

    loaded = true
    return env
end

function M.unload()
    if not loaded then return end
    if env and type(env.deskUninstall) == 'function' then
        pcall(env.deskUninstall)
    end
    loaded = false
    env = nil
end

return M
