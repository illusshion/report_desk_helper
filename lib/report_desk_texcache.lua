--[[ Модуль: GPU кэш ImGui текстур. ]]
local M = {}

local DEFAULT_MAX = 512
local caches = {}
local pendingRelease = {}

-- Ns Data
local function nsData(ns)
    if not caches[ns] then
        caches[ns] = {
            max = DEFAULT_MAX,
            persistent = false,
            map = {},
            order = {},
            fail = {},
        }
    end
    return caches[ns]
end

-- Публичный API модуля.
function M.configure(ns, opts)
    opts = opts or {}
    local d = nsData(ns)
    if opts.persistent ~= nil then d.persistent = opts.persistent == true end
    if opts.max then
        d.max = math.max(8, math.min(2048, math.floor(opts.max)))
    elseif d.persistent then
        d.max = DEFAULT_MAX
    end
end

-- Публичный API модуля.
function M.isPersistent(ns)
    return nsData(ns).persistent
end

-- Публичный API модуля.
function M.clearFailed(ns, id)
    local d = nsData(ns)
    id = tonumber(id) or id
    if id then d.fail[id] = nil end
end

-- Публичный API модуля.
function M.clearAllFailed(ns)
    nsData(ns).fail = {}
end

-- Queue Release
local function queueRelease(tex, releaseFn)
    if tex and releaseFn then
        pendingRelease[#pendingRelease + 1] = { tex = tex, fn = releaseFn }
    end
end

-- Публичный API модуля.
function M.flushPendingRelease(maxCount)
    maxCount = maxCount or #pendingRelease
    local n = 0
    while n < maxCount and #pendingRelease > 0 do
        local item = table.remove(pendingRelease, 1)
        if item and item.tex and item.fn then
            pcall(item.fn, item.tex)
        end
        n = n + 1
    end
end

-- Touch
local function touch(d, id)
    for i, v in ipairs(d.order) do
        if v == id then
            table.remove(d.order, i)
            break
        end
    end
    d.order[#d.order + 1] = id
end

-- Evict One
local function evictOne(d, releaseFn, defer)
    local id = table.remove(d.order, 1)
    if not id then return end
    local entry = d.map[id]
    d.map[id] = nil
    if entry and entry.tex and releaseFn then
        if defer then
            queueRelease(entry.tex, releaseFn)
        else
            pcall(releaseFn, entry.tex)
        end
    end
end

-- Публичный API модуля.
function M.trim(ns, releaseFn, keepSet, deferRelease)
    local d = nsData(ns)
    if d.persistent then return end
    keepSet = keepSet or {}
    local i = 1
    while i <= #d.order do
        local id = d.order[i]
        if not keepSet[id] then
            local entry = d.map[id]
            d.map[id] = nil
            table.remove(d.order, i)
            if entry and entry.tex and releaseFn then
                if deferRelease then
                    queueRelease(entry.tex, releaseFn)
                else
                    pcall(releaseFn, entry.tex)
                end
            end
        else
            i = i + 1
        end
    end
    while #d.order > d.max do
        evictOne(d, releaseFn, deferRelease)
    end
end

-- Публичный API модуля.
function M.releaseAll(ns, releaseFn, deferRelease)
    local d = nsData(ns)
    for id, entry in pairs(d.map) do
        if entry and entry.tex and releaseFn then
            if deferRelease then
                queueRelease(entry.tex, releaseFn)
            else
                pcall(releaseFn, entry.tex)
            end
        end
        d.map[id] = nil
    end
    d.order = {}
    d.fail = {}
end

-- Публичный API модуля.
function M.get(ns, id, loadFn, releaseFn)
    id = tonumber(id) or id
    if not id then return nil end
    local d = nsData(ns)
    local entry = d.map[id]
    if entry and entry.tex then
        touch(d, id)
        return entry.tex
    end
    if not loadFn then return nil end

    local okLoad, tex = pcall(loadFn, id)
    if not okLoad or not tex then
        d.fail[id] = (tonumber(d.fail[id]) or 0) + 1
        return nil
    end
    d.fail[id] = nil
    if not d.persistent then
        while #d.order >= d.max do
            evictOne(d, releaseFn, true)
        end
    end
    d.map[id] = { tex = tex }
    touch(d, id)
    return tex
end

-- Публичный API модуля.
function M.ensure(ns, id, loadFn, releaseFn)
    id = tonumber(id) or id
    if not id then return nil end
    local d = nsData(ns)
    if d.map[id] and d.map[id].tex then
        touch(d, id)
        return d.map[id].tex
    end
    if (tonumber(d.fail[id]) or 0) >= 5 then
        return nil
    end
    return M.get(ns, id, loadFn, releaseFn)
end

-- Публичный API модуля.
function M.has(ns, id)
    id = tonumber(id) or id
    local e = nsData(ns).map[id]
    return e and e.tex ~= nil
end

-- Публичный API модуля.
function M.isFailed(ns, id)
    id = tonumber(id) or id
    local d = nsData(ns)
    return (tonumber(d.fail[id]) or 0) >= 5
end

-- Публичный API модуля.
function M.markFailed(ns, id)
    id = tonumber(id) or id
    if id then nsData(ns).fail[id] = 5 end
end

-- Публичный API модуля.
function M.peek(ns, id)
    id = tonumber(id) or id
    local e = nsData(ns).map[id]
    if e and e.tex then return e.tex end
    return nil
end

-- Публичный API модуля.
function M.adopt(ns, id, tex, releaseFn)
    id = tonumber(id) or id
    if not id or not tex then return nil end
    local d = nsData(ns)
    local existing = d.map[id]
    if existing and existing.tex then
        if releaseFn then pcall(releaseFn, tex) end
        touch(d, id)
        return existing.tex
    end
    if not d.persistent then
        while #d.order >= d.max do
            evictOne(d, releaseFn, true)
        end
    end
    d.fail[id] = nil
    d.map[id] = { tex = tex }
    touch(d, id)
    return tex
end

-- Публичный API модуля.
function M.count(ns)
    return #nsData(ns).order
end

return M
