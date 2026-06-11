--[[ Модуль: общий ImGui chrome для /sp HUD/checker. ]]
local M = {}

local imgui = require 'mimgui'

M.PANEL_W = 240
M.HUD_LIST_W = 218
M.HUD_OVERLAY_ALPHA = 0.80
M.HUD_LABEL_W = 104
M.WINDOW_ROUNDING = 12
M.FRAME_ROUNDING = 8
M.BG_ALPHA = 0.80

-- Публичный API модуля.
function M.windowBg(alpha)
    alpha = tonumber(alpha) or M.BG_ALPHA
    return imgui.ImVec4(0.11, 0.09, 0.16, alpha)
end

-- Публичный API модуля.
function M.borderCol()
    return imgui.ImVec4(0.62, 0.48, 0.92, 0.28)
end

-- Публичный API модуля.
function M.separatorCol()
    return imgui.ImVec4(0.50, 0.38, 0.72, 0.22)
end

-- Публичный API модуля.
function M.labelCol()
    return imgui.ImVec4(0.56, 0.54, 0.64, 0.90)
end

-- Публичный API модуля.
function M.valueCol()
    return imgui.ImVec4(0.94, 0.94, 0.98, 1.0)
end

-- Публичный API модуля.
function M.idCol()
    return imgui.ImVec4(0.62, 0.60, 0.70, 0.82)
end

-- Color U32
local function colorU32(col)
    if imgui.ColorConvertFloat4ToU32 then
        return imgui.ColorConvertFloat4ToU32(col)
    end
    return 0xFFFFFFFF
end

-- Публичный API модуля.
function M.setColorConverter(fn)
    if type(fn) == 'function' then
        colorU32 = fn
    end
end

-- Публичный API модуля.
function M.pushOverlayChrome(bgAlpha)
    bgAlpha = tonumber(bgAlpha) or M.BG_ALPHA
    imgui.PushStyleColor(imgui.Col.WindowBg, M.windowBg(bgAlpha))
    imgui.PushStyleColor(imgui.Col.Border, M.borderCol())
    if imgui.Col.Separator then
        imgui.PushStyleColor(imgui.Col.Separator, M.separatorCol())
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, M.WINDOW_ROUNDING)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(12, 11))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(6, 3))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, M.FRAME_ROUNDING)
end

-- Публичный API модуля.
function M.popOverlayChrome()
    imgui.PopStyleVar(5)
    if imgui.Col.Separator then
        imgui.PopStyleColor(3)
    else
        imgui.PopStyleColor(2)
    end
end

-- Chrome overlay-HUD: тот же стиль, что у /sp меню.
function M.pushHudChrome(bgAlpha)
    bgAlpha = tonumber(bgAlpha) or M.HUD_OVERLAY_ALPHA
    if imgui.SetNextWindowBgAlpha then
        imgui.SetNextWindowBgAlpha(bgAlpha)
    end
    M.pushOverlayChrome(bgAlpha)
end

-- Публичный API модуля.
function M.popHudChrome()
    M.popOverlayChrome()
end

-- Тонкая рамка-подсветка панели (без лишних блоков под текстом).
function M.drawPanelFrame()
    pcall(function()
        local dl = imgui.GetWindowDrawList()
        if not dl then return end
        local p = imgui.GetWindowPos()
        local s = imgui.GetWindowSize()
        local r = M.WINDOW_ROUNDING
        dl:AddRect(
            imgui.ImVec2(p.x + 0.5, p.y + 0.5),
            imgui.ImVec2(p.x + s.x - 0.5, p.y + s.y - 0.5),
            colorU32(M.borderCol()),
            r, 0, 1.0)
    end)
end

-- Градиентная линия-разделитель под шапкой.
function M.drawHeaderRule(colAccent)
    colAccent = colAccent or imgui.ImVec4(0.62, 0.44, 0.86, 0.70)
    local ok = pcall(function()
        local dl = imgui.GetWindowDrawList()
        if not dl then return end
        local p = imgui.GetCursorScreenPos()
        local w = imgui.GetContentRegionAvail().x
        local y = p.y + 1
        local fade = imgui.ImVec4(colAccent.x, colAccent.y, colAccent.z, 0.06)
        if dl.AddRectFilledMultiColor then
            dl:AddRectFilledMultiColor(
                imgui.ImVec2(p.x, y),
                imgui.ImVec2(p.x + w, y + 1),
                colorU32(colAccent),
                colorU32(fade),
                colorU32(fade),
                colorU32(colAccent))
        else
            dl:AddLine(imgui.ImVec2(p.x, y), imgui.ImVec2(p.x + w, y), colorU32(colAccent), 1.2)
        end
    end)
    if not ok then
        imgui.Separator()
    end
    imgui.Dummy(imgui.ImVec2(0, 7))
end

-- Публичный API модуля: nick + [id] — только типографика, без подложки.
function M.drawPlayerHeader(nick, playerId, nickCol, uiTextFn, opts)
    opts = type(opts) == 'table' and opts or {}
    uiTextFn = uiTextFn or function(s) return s end
    nickCol = nickCol or imgui.ImVec4(0.96, 0.96, 0.99, 1.0)
    local idCol = M.idCol()
    local scale = tonumber(opts.scale) or 1.0
    local accentCol = opts.accentCol or imgui.ImVec4(0.62, 0.44, 0.86, 0.70)

    if scale ~= 1.0 and imgui.SetWindowFontScale then
        imgui.SetWindowFontScale(scale)
    end

    local nickText = uiTextFn(nick or '')
    local idText = playerId and uiTextFn(' [' .. tostring(playerId) .. ']') or ''
    if nickText ~= '' then
        imgui.TextColored(nickCol, nickText)
        if idText ~= '' then
            imgui.SameLine(0, 2)
            imgui.TextColored(idCol, idText)
        end
    elseif idText ~= '' then
        imgui.TextColored(idCol, idText)
    end

    if scale ~= 1.0 and imgui.SetWindowFontScale then
        imgui.SetWindowFontScale(1.0)
    end

    M.drawHeaderRule(accentCol)
end

-- Алиас без «glass»-подложки.
function M.drawGlassPlayerHeader(nick, playerId, nickCol, uiTextFn, opts)
    M.drawPlayerHeader(nick, playerId, nickCol, uiTextFn, opts)
end

-- Публичный API модуля.
function M.drawHeaderAccent(colAccent)
    M.drawHeaderRule(colAccent)
end

-- Публичный API модуля: label | value.
function M.drawHudKvRow(label, value, valueCol, labelW, uiTextFn)
    uiTextFn = uiTextFn or function(s) return s end
    labelW = tonumber(labelW) or M.HUD_LABEL_W
    valueCol = valueCol or M.valueCol()
    label = label or ''
    value = tostring(value or '')
    if value == '' then return end
    if label ~= '' then
        imgui.TextColored(M.labelCol(), uiTextFn(label))
        imgui.SameLine(labelW)
    end
    imgui.TextColored(valueCol, uiTextFn(value))
end

-- Публичный API модуля.
function M.drawPanelTitle(title, subtitle, colAccent, colMuted, uiTextFn)
    uiTextFn = uiTextFn or function(s) return s end
    colAccent = colAccent or imgui.ImVec4(0.76, 0.58, 0.98, 1.0)
    colMuted = colMuted or M.labelCol()
    imgui.TextColored(colAccent, uiTextFn(title or ''))
    if subtitle and subtitle ~= '' then
        imgui.SameLine(0, 6)
        imgui.TextColored(colMuted, uiTextFn(subtitle))
    end
    M.drawHeaderRule(colAccent)
end

-- Публичный API модуля.
function M.drawSectionLabel(text, colMuted, uiTextFn)
    uiTextFn = uiTextFn or function(s) return s end
    colMuted = colMuted or M.labelCol()
    imgui.Dummy(imgui.ImVec2(0, 2))
    imgui.TextColored(colMuted, uiTextFn(text or ''))
end

-- Публичный API модуля.
function M.pushListRowStyle()
    imgui.PushStyleColor(imgui.Col.Header, imgui.ImVec4(0.14, 0.11, 0.20, 0.36))
    imgui.PushStyleColor(imgui.Col.HeaderHovered, imgui.ImVec4(0.22, 0.17, 0.30, 0.52))
    imgui.PushStyleColor(imgui.Col.HeaderActive, imgui.ImVec4(0.58, 0.40, 0.82, 0.50))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(6, 3))
end

-- Публичный API модуля.
function M.popListRowStyle()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(3)
end

-- Legacy no-op.
function M.drawWindowGlassShine() end
function M.drawZebraRow() end
function M.rowHeight(extra)
    extra = tonumber(extra) or 2
    local lh = imgui.GetTextLineHeight and imgui.GetTextLineHeight() or 14
    return lh + extra
end
function M.drawStatRow(index, label, value, valueCol, labelW, uiTextFn)
    M.drawHudKvRow(label, value, valueCol, labelW, uiTextFn)
end
function M.drawCompactPair(index, l1, v1, c1, l2, v2, c2, uiTextFn, labelW)
    M.drawHudKvRow(l1, v1, c1, labelW, uiTextFn)
    if l2 and v2 then
        M.drawHudKvRow(l2, v2, c2, labelW, uiTextFn)
    end
end
function M.drawLinkRow(index, text, col, idSuffix, uiTextFn, onClick)
    uiTextFn = uiTextFn or function(s) return s end
    col = col or M.valueCol()
    imgui.PushStyleColor(imgui.Col.Text, col)
    if imgui.Selectable(uiTextFn(text or '') .. '##' .. tostring(idSuffix or index), false) then
        if type(onClick) == 'function' then onClick() end
    end
    imgui.PopStyleColor()
end

return M
