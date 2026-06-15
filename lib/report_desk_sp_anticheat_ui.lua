--[[ Модуль: вкладка «Античит» в /adesk. ]]
local M = {}

local spAc = require 'report_desk_sp_anticheat'

local uiSynced = false
local imgui = require 'mimgui'
local new = imgui.new

local uiTracers = new.bool(true)
local uiTracersAll = new.bool(true)
local uiTracersSound = new.bool(true)
local uiTracersText3d = new.bool(true)
local uiTracersSoundId = new.int(1058)
local uiTracersMax = new.int(10)
local uiTracersLive = new.int(5)
local uiTracersWarn = new.int(15)
local uiTracersBorder = new.float(2.0)

local uiAimLine = new.bool(true)
local uiAimColor = new.float[4](0.55, 0.21, 1.0, 1.0)
local uiAimBorder = new.int(2)

local uiShotWarn = new.bool(true)
local uiShotDeagle = new.float(0.3)
local uiShotM4 = new.float(0.01)

local uiAnimCancel = new.bool(true)

local getSettingsFn
local markDirtySettingsFn, flushDirtyConfigNowFn
local uiTextFn
local col_accent_ref, col_chat_bg_ref
local pushPanelStyleFn, popPanelStyleFn
local deskFormPanelBeginFn, deskFormPanelEndFn, deskFormCheckboxRowFn
local drawSettingsCardHeaderFn, settingsHintFn
local deskFormRowAvailFn, deskFormPushBindButtonStyleFn, deskFormPopBindButtonStyleFn

local function settingsTbl()
    if getSettingsFn then
        local ok, s = pcall(getSettingsFn)
        if ok and type(s) == 'table' then return s end
    end
    local g = rawget(_G, 'settings')
    if type(g) == 'table' then return g end
    return nil
end

local function uiTextSafe(s)
    if uiTextFn then return uiTextFn(s) end
    if type(_G.uiText) == 'function' then return _G.uiText(s) end
    return s
end

local function ac()
    spAc.ensureSettings(getSettingsFn)
    local s = settingsTbl()
    return s and s.sp_anticheat
end

function M.configure(deps)
    if type(deps) ~= 'table' then return end
    if deps.getSettings ~= nil then getSettingsFn = deps.getSettings end
    if deps.markDirtySettings ~= nil then markDirtySettingsFn = deps.markDirtySettings end
    if deps.flushDirtyConfigNow ~= nil then flushDirtyConfigNowFn = deps.flushDirtyConfigNow end
    if deps.uiText ~= nil then uiTextFn = deps.uiText end
    if deps.col_accent ~= nil then col_accent_ref = deps.col_accent end
    if deps.col_chat_bg ~= nil then col_chat_bg_ref = deps.col_chat_bg end
    if deps.pushPanelStyle ~= nil then pushPanelStyleFn = deps.pushPanelStyle end
    if deps.popPanelStyle ~= nil then popPanelStyleFn = deps.popPanelStyle end
    if deps.deskFormPanelBegin ~= nil then deskFormPanelBeginFn = deps.deskFormPanelBegin end
    if deps.deskFormPanelEnd ~= nil then deskFormPanelEndFn = deps.deskFormPanelEnd end
    if deps.deskFormCheckboxRow ~= nil then deskFormCheckboxRowFn = deps.deskFormCheckboxRow end
    if deps.drawSettingsCardHeader ~= nil then drawSettingsCardHeaderFn = deps.drawSettingsCardHeader end
    if deps.settingsHint ~= nil then settingsHintFn = deps.settingsHint end
    if deps.deskFormRowAvail ~= nil then deskFormRowAvailFn = deps.deskFormRowAvail end
    if deps.deskFormPushBindButtonStyle ~= nil then deskFormPushBindButtonStyleFn = deps.deskFormPushBindButtonStyle end
    if deps.deskFormPopBindButtonStyle ~= nil then deskFormPopBindButtonStyleFn = deps.deskFormPopBindButtonStyle end
    spAc.configure(deps)
end

function M.syncFromSettings()
    spAc.ensureSettings(getSettingsFn)
    local s = settingsTbl()
    if not s or not s.sp_anticheat then return end
    s = s.sp_anticheat
    uiTracers[0] = s.tracers ~= false
    uiTracersAll[0] = s.tracers_all_vision ~= false
    uiTracersSound[0] = s.tracers_hit_sound ~= false
    uiTracersText3d[0] = s.tracers_text3d ~= false
    uiTracersSoundId[0] = tonumber(s.tracers_sound_id) or 1058
    uiTracersMax[0] = tonumber(s.tracers_max) or 10
    uiTracersLive[0] = tonumber(s.tracers_live_sec) or 5
    uiTracersWarn[0] = tonumber(s.tracers_warn_sec) or 15
    uiTracersBorder[0] = tonumber(s.tracers_line_border) or 2.0
    uiAimLine[0] = s.aim_line ~= false
    uiAimColor[0] = tonumber(s.aim_line_r) or 0.55
    uiAimColor[1] = tonumber(s.aim_line_g) or 0.21
    uiAimColor[2] = tonumber(s.aim_line_b) or 1.0
    uiAimColor[3] = tonumber(s.aim_line_a) or 1.0
    uiAimBorder[0] = tonumber(s.aim_line_border) or 2
    uiShotWarn[0] = s.shot_warn ~= false
    uiShotDeagle[0] = tonumber(s.shot_deagle_sec) or 0.3
    uiShotM4[0] = tonumber(s.shot_m4_sec) or 0.01
    uiAnimCancel[0] = s.anim_cancel ~= false
    uiSynced = true
end

local function persist()
    if markDirtySettingsFn then pcall(markDirtySettingsFn) end
end

local function sliderInt(label, var, vmin, vmax, id)
    local labelW = rawget(_G, 'DESK_FORM_LABEL_W') or 200
    local inputW = rawget(_G, 'DESK_FORM_INPUT_W') or 180
    local rowAvail = deskFormRowAvailFn or rawget(_G, 'deskFormRowAvail')
    local w = inputW
    if type(rowAvail) == 'function' then
        w = math.min(inputW, rowAvail(label, labelW))
    end
    imgui.PushItemWidth(w)
    local changed = imgui.SliderInt(label .. id, var, vmin, vmax)
    imgui.PopItemWidth()
    return changed
end

local function sliderFloat(label, var, vmin, vmax, fmt, id)
    local labelW = rawget(_G, 'DESK_FORM_LABEL_W') or 200
    local inputW = rawget(_G, 'DESK_FORM_INPUT_W') or 180
    local rowAvail = deskFormRowAvailFn or rawget(_G, 'deskFormRowAvail')
    local w = inputW
    if type(rowAvail) == 'function' then
        w = math.min(inputW, rowAvail(label, labelW))
    end
    imgui.PushItemWidth(w)
    local changed
    if fmt then
        changed = imgui.SliderFloat(label .. id, var, vmin, vmax, fmt)
    else
        changed = imgui.SliderFloat(label .. id, var, vmin, vmax)
    end
    imgui.PopItemWidth()
    return changed
end

function M.drawTab()
    if not uiSynced then M.syncFromSettings() end
    spAc.ensureSettings(getSettingsFn)

    local settings = settingsTbl()
    if not settings then
        imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), 'settings unavailable')
        return
    end

    local uiText = uiTextSafe
    local col_accent = col_accent_ref or rawget(_G, 'col_accent') or imgui.ImVec4(0.62, 0.48, 0.92, 1)
    local col_chat_bg = col_chat_bg_ref or rawget(_G, 'col_chat_bg') or imgui.ImVec4(0.11, 0.09, 0.16, 0.95)
    local pushPanelStyle = pushPanelStyleFn or rawget(_G, 'pushPanelStyle')
    local popPanelStyle = popPanelStyleFn or rawget(_G, 'popPanelStyle')
    local deskFormPanelBegin = deskFormPanelBeginFn or rawget(_G, 'deskFormPanelBegin')
    local deskFormPanelEnd = deskFormPanelEndFn or rawget(_G, 'deskFormPanelEnd')
    local deskFormCheckboxRow = deskFormCheckboxRowFn or rawget(_G, 'deskFormCheckboxRow')
    local drawSettingsCardHeader = drawSettingsCardHeaderFn or rawget(_G, 'drawSettingsCardHeader')
    local settingsHint = settingsHintFn or rawget(_G, 'settingsHint')
    local deskFormRowAvail = deskFormRowAvailFn or rawget(_G, 'deskFormRowAvail')
    local deskFormPushBindButtonStyle = deskFormPushBindButtonStyleFn or rawget(_G, 'deskFormPushBindButtonStyle')
    local deskFormPopBindButtonStyle = deskFormPopBindButtonStyleFn or rawget(_G, 'deskFormPopBindButtonStyle')
    local flushDirtyConfigNow = flushDirtyConfigNowFn or rawget(_G, 'flushDirtyConfigNow')

    if not pushPanelStyle or not deskFormPanelBegin then
        imgui.TextColored(imgui.ImVec4(1, 0.4, 0.4, 1), 'UI helpers unavailable')
        return
    end

    pushPanelStyle(col_chat_bg)
    local panelFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        panelFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##sp_ac_panel', imgui.ImVec2(-1, -1), false, panelFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))

    imgui.TextColored(col_accent, uiText('\xC0\xED\xF2\xE8\xF7\xE8\xF2 \xEF\xF0\xE8 \xED\xE0\xE1\xEB\xFE\xE4\xE5\xED\xE8\xE8'))
    imgui.TextWrapped(uiText(
        '\xC2\xE8\xE7\xF3\xE0\xEB\xFC\xED\xFB\xE5 \xEF\xEE\xE4\xF1\xEA\xE0\xE7\xEA\xE8 \xE8 \xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xFF \xEF\xF0\xE8 \xED\xE0\xE1\xEB\xFE\xE4\xE5\xED\xE8\xE8 \xE7\xE0 \xE8\xE3\xF0\xEE\xEA\xEE\xEC.'))
    imgui.Dummy(imgui.ImVec2(0, 6))

    deskFormPanelBegin('##sp_ac_tr')
    drawSettingsCardHeader('\xD2\xF0\xE0\xF1\xF1\xE5\xF0\xFB \xE2\xFB\xF1\xF2\xF0\xE5\xEB\xEE\xE2', '')
    if deskFormCheckboxRow('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xF2\xFC \xEB\xE8\xED\xE8\xE8 \xE2\xFB\xF1\xF2\xF0\xE5\xEB\xEE\xE2', uiTracers, function(v)
        ac().tracers = v; persist()
    end, 'sp_ac_tr') then end
    if uiTracers[0] then
        if deskFormCheckboxRow('\xC2\xF1\xE5 \xF2\xF0\xE0\xF1\xF1\xE5\xF0\xFB (\xE8\xEB\xE8 \xF3\xE4\xE5\xF0\xE6. ALT)', uiTracersAll, function(v)
            ac().tracers_all_vision = v; persist()
        end, 'sp_ac_tr_all') then end
        if deskFormCheckboxRow('\xC7\xE2\xF3\xEA \xEF\xF0\xE8 \xEF\xEE\xEF\xE0\xE4\xE0\xED\xE8\xE8 \xF6\xE5\xEB\xE8', uiTracersSound, function(v)
            ac().tracers_hit_sound = v; persist()
        end, 'sp_ac_tr_snd') then end
        if deskFormCheckboxRow('3D-\xF2\xE5\xEA\xF1\xF2 \xF2\xEE\xF7\xED\xEE\xF1\xF2\xE8 \xED\xE0 \xF1\xEA\xE8\xED\xE5', uiTracersText3d, function(v)
            ac().tracers_text3d = v
            if not v and spAc.onText3dDisabled then pcall(spAc.onText3dDisabled) end
            persist()
        end, 'sp_ac_tr_3d') then end
        if sliderFloat(uiText('\xD2\xEE\xEB\xF9\xE8\xED\xE0 \xEB\xE8\xED\xE8\xE8'), uiTracersBorder, 0.1, 5.0, '%.1f', '##sp_ac_tr_b') then
            ac().tracers_line_border = uiTracersBorder[0]; persist()
        end
        if sliderInt(uiText('\xCC\xE0\xEA\xF1. \xF2\xF0\xE0\xF1\xF1\xE5\xF0\xEE\xE2 \xED\xE0 \xE8\xE3\xF0\xEE\xEA\xE0'), uiTracersMax, 3, 100, '##sp_ac_tr_m') then
            ac().tracers_max = uiTracersMax[0]; persist()
        end
        if sliderInt(uiText('\xC2\xF0\xE5\xEC\xFF \xE6\xE8\xE7\xED\xE8 \xEB\xE8\xED\xE8\xE8 (\xF1\xE5\xEA)'), uiTracersLive, 1, 50, '##sp_ac_tr_l') then
            ac().tracers_live_sec = uiTracersLive[0]; persist()
        end
        if sliderInt(uiText('\xC2\xF0\xE5\xEC\xFF \xEA\xF0\xE0\xF1\xED\xEE\xE9 \xEB\xE8\xED\xE8\xE8 (\xF1\xE5\xEA)'), uiTracersWarn, 1, 50, '##sp_ac_tr_w') then
            ac().tracers_warn_sec = uiTracersWarn[0]; persist()
        end
        imgui.PushItemWidth(math.min(120, deskFormRowAvail('Sound ID', DESK_FORM_LABEL_W or 200)))
        if imgui.InputInt(uiText('\xC8\xD7 \xE7\xE2\xF3\xEA\xE0 \xEF\xEE\xEF\xE0\xE4\xE0\xED\xE8\xFF') .. '##sp_ac_sid', uiTracersSoundId) then
            ac().tracers_sound_id = uiTracersSoundId[0]; persist()
        end
        imgui.PopItemWidth()
        imgui.SameLine()
        if imgui.Button(uiText('\xCF\xF0\xEE\xF1\xEB\xF3\xF8\xE0\xF2\xFC') .. '##sp_ac_prev_snd') then
            ac().tracers_sound_id = uiTracersSoundId[0]
            pcall(spAc.previewHitSound)
        end
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##sp_ac_aim')
    drawSettingsCardHeader('\xCD\xE0\xEF\xF0\xE0\xE2\xEB\xE5\xED\xE8\xE5 \xE2\xE7\xE3\xEB\xFF\xE4\xE0', '')
    if deskFormCheckboxRow('\xCB\xE8\xED\xE8\xFF \xEA\xF3\xE4\xE0 \xF1\xEC\xEE\xF2\xF0\xE8\xF2 \xF6\xE5\xEB\xFC', uiAimLine, function(v)
        ac().aim_line = v; persist()
    end, 'sp_ac_aim') then end
    if uiAimLine[0] then
        if imgui.ColorEdit4('##sp_ac_aim_col', uiAimColor, imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.AlphaBar) then
            ac().aim_line_r = uiAimColor[0]
            ac().aim_line_g = uiAimColor[1]
            ac().aim_line_b = uiAimColor[2]
            ac().aim_line_a = uiAimColor[3]
            persist()
        end
        imgui.SameLine()
        imgui.Text(uiText('\xF6\xE2\xE5\xF2 \xEB\xE8\xED\xE8\xE8'))
        if sliderInt(uiText('\xD2\xEE\xEB\xF9\xE8\xED\xE0'), uiAimBorder, 1, 10, '##sp_ac_aim_b') then
            ac().aim_line_border = uiAimBorder[0]; persist()
        end
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##sp_ac_warn')
    drawSettingsCardHeader('\xC1\xFB\xF1\xF2\xF0\xE0\xFF \xF1\xF2\xF0\xE5\xEB\xFC\xE1\xE0', '')
    if deskFormCheckboxRow('\xCF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xFF Deagle / M4', uiShotWarn, function(v)
        ac().shot_warn = v; persist()
    end, 'sp_ac_sw') then end
    if uiShotWarn[0] then
        if sliderFloat(uiText('Deagle (\xF1\xE5\xEA \xEC\xE5\xE6\xE4\xF3 \xE2\xFB\xF1\xF2\xF0\xE5\xEB\xE0\xEC\xE8)'), uiShotDeagle, 0.01, 1.5, '%.2f', '##sp_ac_dg') then
            ac().shot_deagle_sec = uiShotDeagle[0]; persist()
        end
        if sliderFloat(uiText('M4 (\xF1\xE5\xEA \xEC\xE5\xE6\xE4\xF3 \xE2\xFB\xF1\xF2\xF0\xE5\xEB\xE0\xEC\xE8)'), uiShotM4, 0.01, 0.5, '%.2f', '##sp_ac_m4') then
            ac().shot_m4_sec = uiShotM4[0]; persist()
        end
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##sp_ac_anim')
    drawSettingsCardHeader('\xC0\xED\xE8\xEC\xE0\xF6\xE8\xE8', '')
    if deskFormCheckboxRow('\xD1\xE1\xE8\xE2 \xE0\xED\xE8\xEC\xE0\xF6\xE8\xE8 \xE0\xEF\xF2\xE5\xF7\xEA\xE8', uiAnimCancel, function(v)
        ac().anim_cancel = v; persist()
    end, 'sp_ac_anim') then end
    deskFormPanelEnd()

    imgui.Dummy(imgui.ImVec2(0, 8))
    local btnW = math.min(220, math.max(140, imgui.GetContentRegionAvail().x - 8))
    imgui.SetCursorPosX(math.max(0, (imgui.GetContentRegionAvail().x - btnW) * 0.5))
    deskFormPushBindButtonStyle()
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
    if imgui.Button(uiText('\xD1\xE1\xF0\xEE\xF1 \xED\xE0\xF1\xF2\xF0\xEE\xE5\xEA \xE0\xED\xF2\xE8\xF7\xE8\xF2\xE0') .. '##sp_ac_rst', imgui.ImVec2(btnW, (rawget(_G, 'DESK_FORM_ROW_H') or 28))) then
        settings.sp_anticheat = spAc.defaultSettings()
        uiSynced = false
        M.syncFromSettings()
        pcall(spAc.onText3dDisabled)
        persist()
        if type(flushDirtyConfigNow) == 'function' then pcall(flushDirtyConfigNow) end
    end
    imgui.PopStyleVar()
    deskFormPopBindButtonStyle()

    imgui.PopStyleVar(2)
    imgui.EndChild()
    popPanelStyle()
end

return M
