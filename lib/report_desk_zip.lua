--[[ Report Desk — pure Lua ZIP extract (store method, no external processes) ]]
local M = {}

local fs = require 'report_desk_fs'

local function u16(data, off)
    local b1, b2 = string.byte(data, off, off + 1)
    return (b1 or 0) + (b2 or 0) * 256
end

local function u32(data, off)
    local b1, b2, b3, b4 = string.byte(data, off, off + 3)
    return (b1 or 0) + (b2 or 0) * 256 + (b3 or 0) * 65536 + (b4 or 0) * 16777216
end

local function readZipEntries(data)
    local len = #data
    if len < 22 then return nil, 'too small' end
    local eocd = nil
    for i = len - 21, math.max(1, len - 65556), -1 do
        if u32(data, i) == 0x06054b50 then
            eocd = i
            break
        end
    end
    if not eocd then return nil, 'eocd not found' end
    local cdSize = u32(data, eocd + 12)
    local cdOffset = u32(data, eocd + 16)
    local entries = {}
    local pos = cdOffset + 1
    local cdEnd = cdOffset + cdSize
    while pos <= cdEnd do
        if u32(data, pos) ~= 0x02014b50 then break end
        local compMethod = u16(data, pos + 10)
        local compSize = u32(data, pos + 20)
        local nameLen = u16(data, pos + 28)
        local extraLen = u16(data, pos + 30)
        local commentLen = u16(data, pos + 32)
        local localOffset = u32(data, pos + 42)
        local name = data:sub(pos + 46, pos + 46 + nameLen - 1)
        entries[#entries + 1] = {
            name = name:gsub('/', '\\'),
            method = compMethod,
            compSize = compSize,
            localOffset = localOffset,
        }
        pos = pos + 46 + nameLen + extraLen + commentLen
    end
    return entries
end

local function extractEntry(data, entry)
    local pos = entry.localOffset + 1
    if u32(data, pos) ~= 0x04034b50 then
        return nil, 'bad local header'
    end
    local nameLen = u16(data, pos + 26)
    local extraLen = u16(data, pos + 28)
    local payload = pos + 30 + nameLen + extraLen
    local comp = data:sub(payload, payload + entry.compSize - 1)
    if entry.method == 0 then
        return comp
    end
    return nil, 'unsupported compression method ' .. tostring(entry.method) .. ' (need store zip)'
end

function M.extract(zipPath, destRoot, opts)
    opts = opts or {}
    zipPath = tostring(zipPath or '')
    destRoot = tostring(destRoot or ''):gsub('/', '\\'):gsub('\\+$', '')
    if zipPath == '' or destRoot == '' then
        return false, 'bad args'
    end
    if not doesFileExist(zipPath) then
        return false, 'zip missing'
    end
    local f = io.open(zipPath, 'rb')
    if not f then return false, 'open failed' end
    local data = f:read('*a')
    f:close()
    local entries, err = readZipEntries(data)
    if not entries then return false, err end
    local count = 0
    for _, entry in ipairs(entries) do
        local name = entry.name
        if name ~= '' and name:sub(-1) ~= '\\' then
            if not opts.filter or opts.filter(name) then
                local body, exErr = extractEntry(data, entry)
                if not body then return false, exErr or ('extract failed: ' .. name) end
                local outPath = destRoot .. '\\' .. name
                fs.ensureDirForFile(outPath)
                local out = io.open(outPath, 'wb')
                if not out then return false, 'write failed: ' .. name end
                out:write(body)
                out:close()
                count = count + 1
                if opts.onProgress and count % 50 == 0 then
                    opts.onProgress(count, name)
                end
                if opts.yieldEvery and count % opts.yieldEvery == 0 and wait then
                    wait(0)
                end
            end
        elseif name ~= '' then
            fs.ensureDir(destRoot .. '\\' .. name:gsub('\\+$', ''))
        end
    end
    return true, count
end

function M.extractSubdir(zipPath, subdirName, destRoot, opts)
    subdirName = tostring(subdirName or ''):gsub('\\', '/')
    if subdirName ~= '' and subdirName:sub(-1) ~= '/' then
        subdirName = subdirName .. '/'
    end
    local prefixLen = #subdirName
    return M.extract(zipPath, destRoot, {
        filter = function(name)
            local n = name:gsub('\\', '/')
            if subdirName == '' then return true end
            if n:sub(1, prefixLen):lower() ~= subdirName:lower() then
                return false
            end
            return true
        end,
        onProgress = opts and opts.onProgress,
    })
end

return M
