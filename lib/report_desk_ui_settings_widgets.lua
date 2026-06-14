--[[ Модуль: общие виджеты настроек ImGui. ]]

function drawAccentStrip()
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetWindowPos()
    dl:AddRectFilled(pos, imgui.ImVec2(pos.x + imgui.GetWindowWidth(), pos.y + 2), toU32(col_accent))
    imgui.Dummy(imgui.ImVec2(0, 4))
end

function pushPanelStyle(bg)
    imgui.PushStyleColor(imgui.Col.ChildBg, bg or col_sidebar)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.18, 0.18, 0.22, 0.35))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(PANEL_PAD, PANEL_PAD))
end

function popPanelStyle()
    imgui.PopStyleVar(3)
    imgui.PopStyleColor(2)
end

function settingsSection(title)
    imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.TextColored(col_label, uiText(title))
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 8))
end

function settingsHint(text)
    imgui.TextColored(col_muted2, uiText(text))
    imgui.Dummy(imgui.ImVec2(0, 4))
end

function settingsBlockBegin(id, title, hint)
    imgui.Dummy(imgui.ImVec2(0, 8))
    imgui.TextColored(col_accent, uiText(title))
    if hint and hint ~= '' then
        imgui.TextWrapped(uiText(hint))
        imgui.Dummy(imgui.ImVec2(0, 2))
    end
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 6))
end

function settingsBlockEnd()
    imgui.Dummy(imgui.ImVec2(0, 4))
end

function settingsSubLabel(text)
    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextColored(col_muted, uiText(text))
    imgui.Dummy(imgui.ImVec2(0, 2))
end

function deskPanelChildFlags()
    return 0
end
