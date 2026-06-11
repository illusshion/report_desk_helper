# -*- coding: cp1251 -*-
path = r'c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_exact_time.lua'
with open(path, 'r', encoding='cp1251', errors='replace') as f:
    text = f.read()

start = text.find('function drawExactTimeTab()')
if start < 0:
    raise SystemExit('drawExactTimeTab not found')
idx = text.find('    popPanelStyle()\nend\n', start)
if idx < 0:
    raise SystemExit('end marker not found')
end = idx + len('    popPanelStyle()\nend\n')

new_func = r'''function drawExactTimeTab()
    if not exactTimeUiSynced then
        syncExactTimeUiFromSettings()
        exactTimeUiSynced = true
    end
    etEnsureOnlinePeriods()

    pushPanelStyle(col_chat_bg)
    local panelFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        panelFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##help_panel', imgui.ImVec2(-1, -1), false, panelFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))

    deskFormPanelBegin('##help_c60')
    drawSettingsCardHeader('\xD2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF',
        '\xCA\xEE\xEC\xE0\xED\xE4\xE0 /c 60 \xE2 \xF7\xE0\xF2\xE5 \xEE\xF2\xEA\xF0\xFB\xE2\xE0\xE5\xF2 \xEE\xEA\xED\xEE \xF1 \xF7\xE0\xF1\xE0\xEC\xE8 \xE8 \xEF\xF0\xEE\xE3\xF0\xE5\xF1\xF1\xEE\xEC')
    if uiExactTimeEnabled and deskFormCheckboxRow('\xC7\xE0\xEC\xE5\xED\xE0 \xE4\xE8\xE0\xEB\xEE\xE3 /c 60', uiExactTimeEnabled, function(v)
        settings.exact_time_enabled = v
        if not v then etCloseWindow() end
        markDirtySettings()
    end, 'et_en') then end
    deskFormPanelEnd()

    deskFormPanelBegin('##help_norms')
    drawSettingsCardHeader('\xCD\xEE\xF0\xEC\xFB \xEE\xED\xEB\xE0\xE9\xED\xE0',
        '\xC7\xE0\xE4\xE0\xE9\xF2\xE5 \xF6\xE5\xEB\xE8 \xE4\xEB\xFF \xEF\xF0\xEE\xE2\xE5\xF0\xE8 \xED\xE5\xE4\xE5\xEB\xE8 \xE8 \xEC\xE5\xF1\xFF\xF6\xE0')
    if uiExactTimeWeeklyH then
        etDrawNormIntRow('\xCD\xE5\xE4\xE5\xEB\xFF', uiExactTimeWeeklyH, 'et_week', 1, 168, function(v)
            settings.exact_time_weekly_norm_h = v
            markDirtySettings()
        end)
    end
    if uiExactTimeMonthlyH then
        etDrawNormIntRow('\xCC\xE5\xF1\xFF\xF6', uiExactTimeMonthlyH, 'et_month', 1, 744, function(v)
            settings.exact_time_monthly_norm_h = v
            markDirtySettings()
        end)
    end
    local monthMin = etGetMonthlyCleanMin()
    local monthNorm = etMonthlyNormMin()
    local monthOk = monthMin >= monthNorm
    etDrawSummaryChip(
        '\xCC\xE5\xF1\xFF\xF6:',
        string.format('%s / %s',
            etFormatMinutesAsRussianDuration(monthMin),
            etFormatMinutesAsRussianDuration(monthNorm)),
        monthOk and ET_COL_OK or ET_COL_FAIL)
    deskFormPanelEnd()

    deskFormPanelBegin('##help_stats')
    drawSettingsCardHeader('\xD1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xE0',
        '\xCE\xED\xEB\xE0\xE9\xED \xEF\xEE \xE4\xED\xFF\xEC \xE8 \xEE\xF2\xE2\xE5\xF2\xFB /ans \xE7\xE0 \xED\xE5\xE4\xE5\xEB\xFE')
    etDrawHelpWeekTable()
    deskFormPanelEnd()

    imgui.PopStyleVar(2)
    imgui.Dummy(imgui.ImVec2(0, 12))
    imgui.EndChild()
    popPanelStyle()
end
'''

text = text[:start] + new_func + text[end:]
with open(path, 'w', encoding='cp1251', errors='replace', newline='\n') as f:
    f.write(text)
print('OK')
