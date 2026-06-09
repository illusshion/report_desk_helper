--[[ Report Desk: загрузчик core + checker chunks в общий Lua env. ]]
local M = {}

local MODULE_DIR = 'lib\\'

local CORE_A_FILES = {
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
    'report_desk_cmd_binds.lua',
}

local REMOTE_CHAT_CHUNK_FILES = {
    'report_desk_remote_chat.lua',
}

local loaded = false
local env = nil

-- Module Path
local function modulePath(wd, name)
    return wd .. '\\' .. MODULE_DIR .. name
end

-- Read Module Text
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

-- Run Chunk Bundle
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

-- Загружает core + checker chunks в общий env.
function M.load()
    if loaded then return env end

    local wd = getWorkingDirectory()
    env = {}
    setmetatable(env, { __index = _G })
    env.outbound = { pending = nil, fromDesk = nil, selfAns = nil, echo = {} }
    env.chatSeen = { lines = {}, order = {}, deferred = {}, consumed = {}, consumedOrder = {} }

    runChunkBundle(wd, CORE_A_FILES, env, 'core')
    local okRemote, errRemote = pcall(runChunkBundle, wd, REMOTE_CHAT_CHUNK_FILES, env, 'remote_chat')
    if not okRemote then
        print('[Report Desk] remote chat disabled: ' .. tostring(errRemote))
    end
    local okLate, errLate = pcall(runChunkBundle, wd, LATE_CHUNK_FILES, env, 'late')
    if not okLate then
        print('[Report Desk] late modules disabled: ' .. tostring(errLate))
    end

    loaded = true
    return env
end

-- Выгрузка bundle, deskUninstall.
function M.unload()
    if not loaded then return end
    if env and type(env.deskUninstall) == 'function' then
        pcall(env.deskUninstall)
    end
    loaded = false
    env = nil
end

return M

