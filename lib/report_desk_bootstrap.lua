--[[ Модуль: bootstrap — require зависимостей, imgui compat, encoding CP1251. ]]
require 'lib.moonloader'
require 'lib.sampfuncs'

pcall(function()
    if package.loaded['lib.sampfuncs'] and not package.loaded['sampfuncs'] then
        package.loaded['sampfuncs'] = package.loaded['lib.sampfuncs']
    end
end)

local function ensureIconvDll()
    local iconvPath = getWorkingDirectory() .. '\\lib\\iconv.dll'
    if doesFileExist(iconvPath) then
        return true
    end
    if not downloadUrlToFile then
        return false
    end
    local libDir = getWorkingDirectory() .. '\\lib'
    if not doesDirectoryExist(libDir) then
        createDirectory(libDir)
    end
    local url = 'https://github.com/illusshion/report_desk_helper/releases/latest/download/iconv.dll'
    local tmp = iconvPath .. '.download'
    downloadUrlToFile(url, tmp)
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        if doesFileExist(tmp) then
            local f = io.open(tmp, 'rb')
            if f then
                local n = f:seek('end') or 0
                f:close()
                if n > 4096 then
                    if doesFileExist(iconvPath) then
                        os.remove(iconvPath)
                    end
                    os.rename(tmp, iconvPath)
                    if doesFileExist(iconvPath) then
                        print('[Report Desk] iconv.dll installed')
                        return true
                    end
                end
            end
        end
        wait(50)
    end
    return doesFileExist(iconvPath)
end

local sampev = require 'lib.samp.events'
local imgui = require 'mimgui'
local deskVeh = require 'report_desk_vehicles'
local deskGrid = require 'report_desk_catalog_grid'
local deskTex = require 'report_desk_texcache'
local deskTexLoad = require 'report_desk_tex_loader'
local deskTexPipeline = require 'report_desk_tex_pipeline'
local deskSpectateStats = require 'report_desk_spectate_stats'
local deskIngest = require 'report_desk_ingest'
local ffi = require 'ffi'
local memory = require 'memory'
local cheat_user32 = nil
pcall(function()
    ffi.cdef[[short GetAsyncKeyState(int vKey);]]
    cheat_user32 = ffi.load('user32')
end)
if not ensureIconvDll() then
    error('[Report Desk] missing lib/iconv.dll (network required once)')
end
local encoding = require 'encoding'
local vkeys = require 'lib.vkeys'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Совместимость старых версий mimgui (RadioButton, PushID).
if imgui and not imgui.RadioButton then
    if imgui.RadioButtonIntPtr then
        imgui.RadioButton = imgui.RadioButtonIntPtr
    elseif imgui.RadioButtonBool then
        imgui.RadioButton = function(label, v, v_button)
            local active = (tonumber(v[0]) or 0) == (tonumber(v_button) or 0)
            if imgui.RadioButtonBool(label, active) then
                v[0] = v_button
                return true
            end
            return false
        end
    end
end

if imgui and not imgui.PushID then
    function imgui.PushID(id)
        if imgui.PushIDStr and type(id) == 'string' then
            imgui.PushIDStr(id)
        elseif imgui.PushIDInt and type(id) == 'number' then
            imgui.PushIDInt(id)
        elseif imgui.PushIDStr then
            imgui.PushIDStr(tostring(id))
        end
    end
end

local new, sizeof = imgui.new, ffi.sizeof
