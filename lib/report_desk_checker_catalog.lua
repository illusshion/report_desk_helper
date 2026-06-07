--[[ Модуль: хранение каталога checker (admins/leaders/friends). ]]
local M = {}

local CATALOG_VERSION = 1

M.PATH = getWorkingDirectory() .. '\\config\\report_desk_checker_catalog.lua'
M.BACKUP_PATH = getWorkingDirectory() .. '\\config\\report_desk_checker_catalog.bak.lua'

M.dirty = false

-- Lua Quote Utf8
local function luaQuoteUtf8(s)
    s = tostring(s or '')
    return string.format('%q', s)
end

-- Ensure Config Dir
local function ensureConfigDir()
    local dir = getWorkingDirectory() .. '\\config'
    if not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

-- Публичный API модуля.
function M.exists()
    return doesFileExist(M.PATH)
end

-- Публичный API модуля.
function M.markDirty()
    M.dirty = true
end

-- Публичный API модуля.
function M.clearDirty()
    M.dirty = false
end

-- Публичный API модуля.
function M.isDirty()
    return M.dirty == true
end

-- Публичный API модуля.
function M.load()
    local path = M.PATH
    if not doesFileExist(path) and doesFileExist(M.BACKUP_PATH) then
        path = M.BACKUP_PATH
        print('[Report Desk] checker catalog: using backup file')
    end
    if not doesFileExist(path) then
        return nil
    end
    local chunk, err = loadfile(path)
    if not chunk then
        print('[Report Desk] checker catalog load: ' .. tostring(err))
        return nil
    end
    if setfenv then
        setfenv(chunk, {})
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then
        print('[Report Desk] checker catalog load: bad table')
        return nil
    end
    return data
end

-- Write Snapshot Body
local function writeSnapshotBody(f, snapshot)
    snapshot = type(snapshot) == 'table' and snapshot or {}
    local parts = {
        string.format('  version = %d,\n', CATALOG_VERSION),
        string.format('  updated_at = %d,\n', os.time()),
        '  admins = {\n',
    }
    for _, e in ipairs(snapshot.admins or {}) do
        if type(e) == 'table' and (e.nick or '') ~= '' then
            parts[#parts + 1] = string.format(
                '    { nick = %s, level = %d },\n',
                luaQuoteUtf8(e.nick),
                math.floor(tonumber(e.level) or 0))
        end
    end
    parts[#parts + 1] = '  },\n  leaders = {\n'
    for _, e in ipairs(snapshot.leaders or {}) do
        if type(e) == 'table' and (e.nick or '') ~= '' then
            local row = string.format('    { nick = %s, org = %d',
                luaQuoteUtf8(e.nick), math.floor(tonumber(e.org) or 0))
            if (e.org_name or '') ~= '' then
                row = row .. ', org_name = ' .. luaQuoteUtf8(e.org_name)
            end
            if (e.role or '') ~= '' then
                row = row .. ', role = ' .. luaQuoteUtf8(e.role)
            end
            if e.hidden == true then
                row = row .. ', hidden = true'
            end
            parts[#parts + 1] = row .. ' },\n'
        end
    end
    parts[#parts + 1] = '  },\n  hidden_nicks = {\n'
    for _, nick in ipairs(snapshot.hidden_nicks or {}) do
        if type(nick) == 'string' and nick ~= '' then
            parts[#parts + 1] = '    ' .. luaQuoteUtf8(nick) .. ',\n'
        end
    end
    parts[#parts + 1] = '  },\n  friends = {\n'
    for _, e in ipairs(snapshot.friends or {}) do
        if type(e) == 'table' and (e.nick or '') ~= '' then
            parts[#parts + 1] = '    { nick = ' .. luaQuoteUtf8(e.nick) .. ' },\n'
        end
    end
    parts[#parts + 1] = '  },\n'
    f:write(table.concat(parts))
end

-- Публичный API модуля.
function M.save(snapshot)
    ensureConfigDir()
    if doesFileExist(M.PATH) then
        pcall(function()
            if doesFileExist(M.BACKUP_PATH) then
                os.remove(M.BACKUP_PATH)
            end
            os.rename(M.PATH, M.BACKUP_PATH)
        end)
    end
    local f, err = io.open(M.PATH, 'w')
    if not f then
        print('[Report Desk] checker catalog save: ' .. tostring(err))
        return false
    end
    f:write('-- Report Desk checker catalog (auto-generated)\n')
    f:write('return {\n')
    writeSnapshotBody(f, snapshot)
    f:write('}\n')
    f:close()
    M.clearDirty()
    return true
end

return M
