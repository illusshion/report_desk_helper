--[[ Единый диспетчер onWindowMessage для Report Desk (приоритетная цепочка). ]]
local M = {}

local slots = {}
local installed = false
local masterHandler = nil
local sortedCache = nil

local function rebuildSortedCache()
    sortedCache = {}
    for name, slot in pairs(slots) do
        sortedCache[#sortedCache + 1] = { name = name, priority = slot.priority or 0, fn = slot.fn }
    end
    table.sort(sortedCache, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.name < b.name
    end)
end

local function sortedSlots()
    if not sortedCache then
        rebuildSortedCache()
    end
    return sortedCache
end

function M.register(name, priority, fn)
    if not name or type(fn) ~= 'function' then return false end
    slots[name] = { priority = tonumber(priority) or 0, fn = fn }
    sortedCache = nil
    M.ensureInstalled()
    return true
end

function M.unregister(name)
    slots[name] = nil
    sortedCache = nil
    if installed and not next(slots) then
        if masterHandler and removeEventHandler then
            pcall(removeEventHandler, 'onWindowMessage', masterHandler)
        end
        masterHandler = nil
        installed = false
    end
end

function M.install()
    if masterHandler and removeEventHandler then
        pcall(removeEventHandler, 'onWindowMessage', masterHandler)
    end
    masterHandler = function(msg, wparam, lparam)
        for _, slot in ipairs(sortedSlots()) do
            local ok, consumed = pcall(slot.fn, msg, wparam, lparam)
            if ok and consumed then
                return
            end
            if not ok then
                print('[Report Desk] wm ' .. slot.name .. ': ' .. tostring(consumed))
            end
        end
    end
    addEventHandler('onWindowMessage', masterHandler, true)
    installed = true
end

function M.uninstall()
    if masterHandler and removeEventHandler then
        pcall(removeEventHandler, 'onWindowMessage', masterHandler)
    end
    masterHandler = nil
    installed = false
    slots = {}
    sortedCache = nil
end

function M.ensureInstalled()
    if not installed then
        M.install()
    end
end

return M
