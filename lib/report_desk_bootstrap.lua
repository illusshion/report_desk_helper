--[[ Report Desk bootstrap: requires, encoding, imgui compat ]]

require 'lib.moonloader'
require 'lib.sampfuncs'

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
local encoding = require 'encoding'
local vkeys = require 'lib.vkeys'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

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
