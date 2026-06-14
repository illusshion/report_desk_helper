--[[ Report Desk: загрузчик core + checker chunks в общий Lua env. ]]
local M = {}

local MODULE_DIR = 'lib\\'

local function loadBundleManifest()
    local path = getWorkingDirectory() .. '\\config\\report_desk_bundle_manifest.lua'
    if not doesFileExist(path) then
        error('[Report Desk] missing bundle manifest: ' .. path)
    end
    local chunk, err = loadfile(path)
    if not chunk then
        error('[Report Desk] bundle manifest load failed: ' .. tostring(err))
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then
        error('[Report Desk] bundle manifest invalid: ' .. tostring(data))
    end
    return data
end

local manifest = loadBundleManifest()

-- Lua 5.1 / LuaJIT: один loadstring-chunk не может иметь >200 local-переменных.
local CORE_A_FILES_A = manifest.core_a_a
local CORE_A_FILES_B = manifest.core_a_b
local CORE_A_FILES_B2 = manifest.core_a_b2
local CORE_A_FILES_C = manifest.core_a_c
local LATE_CHUNK_FILES = manifest.late
local REMOTE_CHAT_CHUNK_FILES = manifest.remote_chat

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
    -- UTF-8 BOM mid-chunk breaks loadstring (io.open rb preserves it).
    if text:sub(1, 3) == '\239\187\191' then
        text = text:sub(4)
    end
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

    runChunkBundle(wd, CORE_A_FILES_A, env, 'core_a')
    runChunkBundle(wd, CORE_A_FILES_B, env, 'core_b')
    runChunkBundle(wd, CORE_A_FILES_B2, env, 'core_b2')
    runChunkBundle(wd, CORE_A_FILES_C, env, 'core_c')
    local okRemote, errRemote = pcall(runChunkBundle, wd, REMOTE_CHAT_CHUNK_FILES, env, 'remote_chat')
    if not okRemote then
        print('[Report Desk] remote chat disabled: ' .. tostring(errRemote))
    end
    runChunkBundle(wd, LATE_CHUNK_FILES, env, 'late')

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

