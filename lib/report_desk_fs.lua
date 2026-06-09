--[[ Report Desk — filesystem helpers (pure Lua + lfs, no shell) ]]
local M = {}

local lfs
pcall(function() lfs = require 'lfs' end)

function M.ensureDir(path)
    path = tostring(path or ''):gsub('/', '\\')
    if path == '' then return false end
    if doesDirectoryExist and doesDirectoryExist(path) then
        return true
    end
    local parts = {}
    for part in path:gmatch('[^\\]+') do
        parts[#parts + 1] = part
    end
    if #parts == 0 then return false end
    local cur = parts[1]
    if cur:match(':$') then
        cur = cur .. '\\' .. (parts[2] or '')
        local start = 3
        if not doesDirectoryExist(cur) and createDirectory then
            createDirectory(cur)
        end
        for i = start, #parts do
            cur = cur .. '\\' .. parts[i]
            if not doesDirectoryExist(cur) and createDirectory then
                createDirectory(cur)
            end
        end
        return doesDirectoryExist(cur)
    end
    for i = 2, #parts do
        cur = cur .. '\\' .. parts[i]
        if not doesDirectoryExist(cur) and createDirectory then
            createDirectory(cur)
        end
    end
    return doesDirectoryExist(path)
end

function M.ensureDirForFile(filePath)
    local dir = tostring(filePath or ''):match('^(.*)\\[^\\]+$')
    if not dir or dir == '' then return true end
    return M.ensureDir(dir)
end

function M.copyFile(src, dest)
    src, dest = tostring(src or ''), tostring(dest or '')
    if src == '' or dest == '' then return false end
    M.ensureDirForFile(dest)
    local f = io.open(src, 'rb')
    if not f then return false end
    local data = f:read('*a')
    f:close()
    local out = io.open(dest, 'wb')
    if not out then return false end
    out:write(data)
    out:close()
    return doesFileExist(dest)
end

local function removeFile(path)
    if doesFileExist(path) then
        pcall(os.remove, path)
    end
end

function M.removeTree(path)
    path = tostring(path or ''):gsub('/', '\\')
    if path == '' then return true end
    if not doesDirectoryExist(path) then
        return true
    end
    if lfs and lfs.dir then
        local function rmDir(dir)
            for entry in lfs.dir(dir) do
                if entry ~= '.' and entry ~= '..' then
                    local full = dir .. '\\' .. entry
                    local attr = lfs.attributes(full)
                    if attr and attr.mode == 'directory' then
                        rmDir(full)
                    else
                        removeFile(full)
                    end
                end
            end
            pcall(lfs.rmdir, dir)
        end
        rmDir(path)
        return not doesDirectoryExist(path)
    end
    return false
end

function M.copyTree(srcRoot, destRoot, opts)
    opts = opts or {}
    srcRoot = tostring(srcRoot or ''):gsub('/', '\\'):gsub('\\+$', '')
    destRoot = tostring(destRoot or ''):gsub('/', '\\'):gsub('\\+$', '')
    if srcRoot == '' or destRoot == '' then return false, 'bad path' end
    if not lfs or not lfs.dir then
        return false, 'lfs unavailable'
    end
    local copied = 0
    local function walk(rel)
        local dir = srcRoot .. (rel ~= '' and ('\\' .. rel) or '')
        for entry in lfs.dir(dir) do
            if entry ~= '.' and entry ~= '..' then
                local subRel = rel == '' and entry or (rel .. '\\' .. entry)
                local full = dir .. '\\' .. entry
                local attr = lfs.attributes(full)
                if attr and attr.mode == 'directory' then
                    M.ensureDir(destRoot .. '\\' .. subRel)
                    walk(subRel)
                else
                    if not opts.filter or opts.filter(subRel) then
                        if M.copyFile(full, destRoot .. '\\' .. subRel) then
                            copied = copied + 1
                        end
                    end
                end
            end
        end
    end
    M.ensureDir(destRoot)
    walk('')
    return copied > 0, copied
end

return M
