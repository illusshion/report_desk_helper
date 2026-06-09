--[[ Модуль: загрузка PNG с диска. ]]
local M = {}

local ffi = require 'ffi'

local DEFAULT_MAX_BYTES = 512000
local DEFAULT_STAGING_MAX = 16
local maxBytes = DEFAULT_MAX_BYTES
local stagingMax = DEFAULT_STAGING_MAX
local staging = {}
local stagingOrder = {}

-- Публичный API модуля.
function M.configure(opts)
    opts = opts or {}
    if opts.maxBytes then
        maxBytes = math.max(4096, math.min(512000, math.floor(opts.maxBytes)))
    end
    if opts.stagingMax then
        stagingMax = math.max(4, math.min(64, math.floor(opts.stagingMax)))
    end
end

-- Touch Staging
local function touchStaging(ns, id)
    if not stagingOrder[ns] then stagingOrder[ns] = {} end
    local order = stagingOrder[ns]
    for i, v in ipairs(order) do
        if v == id then
            table.remove(order, i)
            break
        end
    end
    order[#order + 1] = id
end

-- Evict Staging
local function evictStaging(ns)
    local order = stagingOrder[ns]
    local bucket = staging[ns]
    if not order or not bucket or #order == 0 then return end
    local id = table.remove(order, 1)
    if id then bucket[id] = nil end
end

-- Публичный API модуля.
function M.readFileBytes(path)
    if not path then return nil end
    local f = io.open(path, 'rb')
    if not f then return nil end
    local data = f:read(maxBytes + 1)
    f:close()
    if data and #data > 0 and #data <= maxBytes then
        return data
    end
    return nil
end

-- Публичный API модуля.
function M.storeStaging(ns, id, data, meta)
    id = tonumber(id) or id
    if not ns or not id or not data then return end
    if not staging[ns] then staging[ns] = {} end
    staging[ns][id] = { data = data, meta = meta }
    touchStaging(ns, id)
    while stagingOrder[ns] and #stagingOrder[ns] > stagingMax do
        evictStaging(ns)
    end
end

-- Публичный API модуля.
function M.hasStaging(ns, id)
    id = tonumber(id) or id
    if not ns or not id then return false end
    local bucket = staging[ns]
    return bucket and bucket[id] ~= nil
end

-- Публичный API модуля.
function M.takeStaging(ns, id)
    id = tonumber(id) or id
    if not ns or not id then return nil end
    local bucket = staging[ns]
    local entry = bucket and bucket[id]
    if not entry then return nil end
    bucket[id] = nil
    if stagingOrder[ns] then
        for i, v in ipairs(stagingOrder[ns]) do
            if v == id then
                table.remove(stagingOrder[ns], i)
                break
            end
        end
    end
    return entry.data, entry.meta
end

-- Публичный API модуля.
function M.dropStaging(ns, id)
    id = tonumber(id) or id
    if not ns or not id then return end
    local bucket = staging[ns]
    if bucket then bucket[id] = nil end
    if stagingOrder[ns] then
        for i, v in ipairs(stagingOrder[ns]) do
            if v == id then
                table.remove(stagingOrder[ns], i)
                break
            end
        end
    end
end

-- Публичный API модуля.
function M.clearStaging(ns)
    if ns then
        staging[ns] = nil
        stagingOrder[ns] = nil
    else
        staging = {}
        stagingOrder = {}
    end
end

-- Публичный API модуля.
function M.clearNamespace(ns)
    M.clearStaging(ns)
end

-- Публичный API модуля.
function M.clearAll()
    M.clearStaging()
end

-- Публичный API модуля.
function M.createFromMemory(imgui, data)
    if not imgui or not data or #data <= 0 then return nil end
    if not imgui.CreateTextureFromFileInMemory then return nil end
    local size = #data
    local ok, tex = pcall(imgui.CreateTextureFromFileInMemory, ffi.cast('const char*', data), size)
    if ok and tex then return tex end
    local buf = ffi.new('char[?]', size)
    ffi.copy(buf, data, size)
    ok, tex = pcall(imgui.CreateTextureFromFileInMemory, buf, size)
    if ok and tex then return tex end
    return nil
end

-- Публичный API модуля.
function M.decodeTexture(imgui, data, meta)
    return M.createFromMemory(imgui, data)
end

-- First Existing
local function firstExisting(paths)
    for _, p in ipairs(paths) do
        if p and doesFileExist(p) then return p end
    end
    return nil
end

local function assetsSkinsDir()
    return getWorkingDirectory() .. '\\config\\AdminDesk\\assets\\res\\report_desk_skins\\'
end

-- Публичный API модуля.
function M.resolveSkinPath(dir, entry)
    if not entry or not entry.id then return nil end
    local id = entry.id
    local png = string.format('%sskin-%d.png', dir, id)
    local candidates = { png, assetsSkinsDir() .. string.format('skin-%d.png', id) }
    if entry.file then
        local f = dir .. entry.file
        if f ~= png then candidates[#candidates + 1] = f end
    end
    local path = firstExisting(candidates)
    if path then return path, { format = 'png' } end
    return nil
end

-- Публичный API модуля.
function M.resolveVehPath(vehDir, overrideDir, entry)
    if not entry or not entry.id then return nil, false end
    local id = entry.id
    local lowQ = false
    local candidates = {
        { overrideDir .. string.format('veh-%d.png', id), false },
        { vehDir .. string.format('veh-%d.png', id), false },
    }
    if entry.file then
        local f = vehDir .. entry.file
        local isJpg = entry.file:lower():match('%.jpg$') ~= nil
        candidates[#candidates + 1] = { f, entry.lowQuality or isJpg }
    end
    candidates[#candidates + 1] = { vehDir .. string.format('veh-%d.jpg', id), true }
    for _, row in ipairs(candidates) do
        local p, low = row[1], row[2]
        if doesFileExist(p) then
            local ext = p:lower():match('%.([^.]+)$') or 'png'
            return p, low, { format = ext, lowQuality = low }
        end
    end
    return nil, false
end

-- Публичный API модуля.
function M.assetExistsSkin(dir, entry)
    return M.resolveSkinPath(dir, entry) ~= nil
end

-- Публичный API модуля.
function M.assetExistsVeh(vehDir, overrideDir, entry)
    return M.resolveVehPath(vehDir, overrideDir, entry) ~= nil
end

return M
