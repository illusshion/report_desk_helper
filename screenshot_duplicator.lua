script_name('Screenshot Duplicator')
script_author('Simple Version')
script_description('Копирует скрины в E:\\Скрины самп')

require 'lib.moonloader'
local ffi = require 'ffi'

ffi.cdef[[
	int CopyFileA(const char* src, const char* dst, int failIfExists);
]]

local function src_dir()
	return getFolderPath(0x5) .. '\\GTA San Andreas User Files\\Advance\\screens\\'
end

-- CP1251: Скрины самп
local function dst_dir()
	return 'E:\\' .. string.char(
		0xD1, 0xEA, 0xF0, 0xE8, 0xED, 0xFB, 0x20, 0xF1, 0xE0, 0xEC, 0xEF
	) .. '\\'
end

local function ensure_dst()
	local dir = dst_dir():sub(1, -2)
	if not doesDirectoryExist(dir) then
		createDirectory(dir)
	end
end

local function newest_screenshot()
	local dir = src_dir()
	local best

	local handle, name = findFirstFile(dir .. '*.jpg')
	if not handle then
		return nil
	end

	while name do
		if name:find('^screenshot ', 1, true) == 1 then
			if not best or name > best then
				best = name
			end
		end
		name = findNextFile(handle)
	end
	findClose(handle)

	return best
end

local function make_name()
	local base = os.date('%d.%m %H-%M')
	local dir = dst_dir()
	local path = dir .. base .. '.jpg'
	if not doesFileExist(path) then
		return path
	end
	local n = 1
	while doesFileExist(dir .. base .. ' (' .. n .. ').jpg') do
		n = n + 1
	end
	return dir .. base .. ' (' .. n .. ').jpg'
end

local function copy_shot(filename)
	local src = src_dir() .. filename
	if not doesFileExist(src) then
		return false
	end

	ensure_dst()
	local dst = make_name()
	return ffi.C.CopyFileA(src, dst, 0) ~= 0
end

function main()
	while not isSampLoaded() do
		wait(100)
	end

	ensure_dst()
	local last = newest_screenshot()

	while true do
		wait(500)

		local cur = newest_screenshot()
		if cur and cur ~= last then
			wait(500)
			if copy_shot(cur) then
				last = cur
			end
		end
	end
end
