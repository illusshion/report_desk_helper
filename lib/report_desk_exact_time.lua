--[[ /c 60 — кастомное окно «Точное время» (интеграция ARP Exact Time). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local ET_WIN_W = 408
local ET_LINE = imgui.ImVec4(1.0, 1.0, 1.0, 0.10)
local ET_ROW_GAP = 5
local ET_LABEL_W = 228
local ET_WEEKLY_COLOR = imgui.ImVec4(0.38, 0.78, 0.58, 1.0)
local ET_MONTHLY_COLOR = imgui.ImVec4(0.52, 0.62, 0.92, 1.0)
local ET_HELP_WEEK_MAX_BACK = 52
local ET_ONLINE_RETAIN_DAYS = 400
local EXACT_TIME_TIMEOUT = 10.0
local SAMP_DIALOG_ACTIVE_OFF = 40

local ET_ONLINE_PATH = getWorkingDirectory() .. '\\config\\arp_exact_time_online.ini'
local ET_ANS_PATH = getWorkingDirectory() .. '\\config\\report_desk_help_ans.ini'
local ET_PUNISH_PATH = getWorkingDirectory() .. '\\config\\report_desk_help_punish.jsonl'
local ET_PUNISH_RETAIN_DAYS = 6
local ET_PUNISH_MAX_STORE = 2000
local ET_PUNISH_UI_MAX = 100
local ET_LEGACY_ONLINE = getWorkingDirectory() .. '\\config\\arp_helper_online.ini'
local ET_LEGACY_CONFIG = getWorkingDirectory() .. '\\config\\arp_exact_time.ini'

local ET_WD_SHORT = {
    ['Mon'] = '\xCF\xED', ['Tue'] = '\xC2\xF2', ['Wed'] = '\xD1\xF0',
    ['Thu'] = '\xD7\xF2', ['Fri'] = '\xCF\xF2', ['Sat'] = '\xD1\xE1', ['Sun'] = '\xC2\xF1',
}
local ET_COL_OK = imgui.ImVec4(0.38, 0.78, 0.58, 1.0)
local ET_COL_FAIL = imgui.ImVec4(0.92, 0.42, 0.42, 1.0)

local L_ET_ONLINE_TODAY = '\xCE\xED\xEB\xE0\xE9\xED \xE7\xE0 \xF1\xE5\xE3\xEE\xE4\xED\xFF'
local L_ET_AFK_TODAY = 'AFK \xE7\xE0 \xF1\xE5\xE3\xEE\xE4\xED\xFF'
local L_ET_PER_HOUR = '\xC2\xF0\xE5\xEC\xFF \xE2 \xE8\xE3\xF0\xE5 \xE7\xE0 \xF7\xE0\xF1'
local L_ET_ONLINE_YDAY = '\xCE\xED\xEB\xE0\xE9\xED \xE2\xF7\xE5\xF0\xE0'
local L_ET_AFK_YDAY = 'AFK \xE7\xE0 \xE2\xF7\xE5\xF0\xE0'
local L_ET_CLEAN = '\xD7\xE8\xF1\xF2\xFB\xE9 \xEE\xED\xEB\xE0\xE9\xED'
local L_ET_CLEAN_WEEK = '\xD7\xE8\xF1\xF2\xFB\xE9 \xEE\xED\xEB\xE0\xE9\xED \xE7\xE0 \xED\xE5\xE4\xE5\xEB\xFE'
local L_ET_CLEAN_MONTH = '\xD7\xE8\xF1\xF2\xFB\xE9 \xEE\xED\xEB\xE0\xE9\xED \xE7\xE0 \xEC\xE5\xF1\xFF\xF6'
local L_TITLE = '\xD2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF'
local L_CLOSE = '\xC7\xE0\xEA\xF0\xFB\xF2\xFC'

local ET_COL = {
    accent   = imgui.ImVec4(0.62, 0.48, 0.92, 1.0),
    muted    = imgui.ImVec4(0.55, 0.55, 0.60, 1.0),
    label    = imgui.ImVec4(0.92, 0.92, 0.95, 1.0),
    value    = imgui.ImVec4(0.90, 0.90, 0.93, 1.0),
    time     = imgui.ImVec4(0.93, 0.93, 0.96, 1.0),
}
local LAW_BTN   = imgui.ImVec4(0.16, 0.16, 0.19, 1.0)
local LAW_BTN_H = imgui.ImVec4(0.20, 0.20, 0.24, 1.0)
local LAW_BTN_A = imgui.ImVec4(0.24, 0.24, 0.28, 1.0)

local etState = {
    pendingCmdAt = nil,
    showOpen = false,
    data = {},
    online = { weekKey = nil, monthKey = nil, days = {} },
    ans = { days = {}, backfilled = false },
    punish = { entries = {}, filter = 'all', weekCache = nil },
    helpWeekOffset = 0,
}
exactTimeUiSynced = false

local uiExactTimeEnabled = imgui and imgui.new and imgui.new.bool(true) or nil
local uiExactTimeDailyH = imgui and imgui.new and imgui.new.int(4) or nil
local uiExactTimeMonthlyH = imgui and imgui.new and imgui.new.int(112) or nil
local etShowWindowBuf = imgui and imgui.new and imgui.new.bool(false) or nil

local function etPushWindowStyle()
    imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0.10, 0.10, 0.12, 0.98))
    imgui.PushStyleColor(imgui.Col.TitleBg, imgui.ImVec4(0.08, 0.08, 0.10, 1.0))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, imgui.ImVec4(0.11, 0.10, 0.14, 1.0))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.22, 0.22, 0.26, 0.40))
    imgui.PushStyleColor(imgui.Col.Button, LAW_BTN)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, LAW_BTN_H)
    imgui.PushStyleColor(imgui.Col.ButtonActive, LAW_BTN_A)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 8)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 5)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
end

local function etPopWindowStyle()
    imgui.PopStyleVar(4)
    imgui.PopStyleColor(7)
end

function ensureExactTimeSettings()
    if type(settings) ~= 'table' then return end
    if settings.exact_time_enabled == nil then settings.exact_time_enabled = true end
    if settings.exact_time_daily_norm_h == nil then
        local wh = tonumber(settings.exact_time_weekly_norm_h)
        if wh and wh >= 7 then
            settings.exact_time_daily_norm_h = math.max(1, math.min(24, math.floor(wh / 7)))
        else
            settings.exact_time_daily_norm_h = 4
        end
    end
    local dh = tonumber(settings.exact_time_daily_norm_h)
    if not dh or dh < 1 or dh > 24 then settings.exact_time_daily_norm_h = 4 end
    local mh = tonumber(settings.exact_time_monthly_norm_h)
    if not mh or mh < 1 or mh > 744 then settings.exact_time_monthly_norm_h = 112 end
end

local function etEnabled()
    return type(settings) == 'table' and settings.exact_time_enabled ~= false
end

local function etDailyNormMin()
    ensureExactTimeSettings()
    return math.floor(tonumber(settings.exact_time_daily_norm_h) or 4) * 60
end

local function etMonthlyNormMin()
    ensureExactTimeSettings()
    return math.floor(tonumber(settings.exact_time_monthly_norm_h) or 112) * 60
end

local function etSetNativeDialogVisible(visible)
    if not sampGetDialogInfoPtr or not memory or not memory.setint32 then return end
    local ptr = sampGetDialogInfoPtr()
    if not ptr or ptr == 0 then return end
    pcall(function()
        memory.setint32(ptr + SAMP_DIALOG_ACTIVE_OFF, visible and 1 or 0, true)
    end)
end

local function etResolveCloseButton(button1, button2)
    local function isClose(label)
        label = trim(stripTags(label or ''))
        return label ~= '' and (label:find(L_CLOSE, 1, true) or label:lower():find('close', 1, true))
    end
    if isClose(button1) then return 1 end
    if isClose(button2) then return 0 end
    if trim(stripTags(button2 or '')) == '' then return 1 end
    return 0
end

-- Скрытый диалог: только RPC-ответ серверу + сброс active (без UI-close и без chat enable).
local function etSendDialogResponseOnce(dialogId, button1, button2)
    etSetNativeDialogVisible(false)
    if not dialogId or not sampSendDialogResponse then return end
    local btn = etResolveCloseButton(button1, button2)
    pcall(function() sampSendDialogResponse(dialogId, btn, 0, '') end)
    etSetNativeDialogVisible(false)
end

local function etSendDialogClose(dialogId, button1, button2)
    etSendDialogResponseOnce(dialogId, button1, button2)
    if not dialogId or not lua_thread or not lua_thread.create then return end
    local id, b1, b2 = dialogId, button1, button2
    lua_thread.create(function()
        wait(150)
        if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then
            etSendDialogResponseOnce(id, b1, b2)
        end
    end)
end

local function etClearData()
    etState.data = {}
end

local etCloseWindow

etCloseWindow = function()
    if not etState.showOpen then return end
    local d = etState.data
    local id, b1, b2 = d.dialogId, d.button1, d.button2
    etState.showOpen = false
    if etShowWindowBuf then etShowWindowBuf[0] = false end
    etClearData()
    if id then
        etSendDialogClose(id, b1, b2)
    else
        etSetNativeDialogVisible(false)
    end
    if type(updateMimguiGameInputPassthrough) == 'function' then
        pcall(updateMimguiGameInputPassthrough)
    end
end

local function etParseDialogLines(text)
    text = stripTags(text or '')
    local rows, seen = {}, {}
    for raw in (text .. '\n'):gmatch('([^\r\n]+)') do
        local line = trim(raw)
        if line ~= '' then
            local label, value = line:match('^(.-)[:\t]+(.+)$')
            if label and value then
                label, value = trim(label), trim(value)
                if label ~= '' and value ~= '' then
                    local key = label:lower()
                    if not seen[key] then
                        seen[key] = true
                        rows[#rows + 1] = { label = label, value = value }
                    end
                end
            end
        end
    end
    return rows
end

local function etParseRussianPlayTimeToMinutes(s)
    if not s or s == '' then return nil end
    s = trim(stripTags(s))
    local h, m = s:match('(%d+)%s*[\xF7ч]%s*(%d+)%s*[\xEC\xE8\xEDmin]+')
    if h then return tonumber(h) * 60 + tonumber(m) end
    h = tonumber(s:match('(%d+)%s*[\xF7ч]')) or 0
    m = tonumber(s:match('(%d+)%s*[\xEC\xE8\xEDmin]+')) or 0
    if h == 0 and m == 0 then return nil end
    return h * 60 + m
end

local function etFormatMinutesAsRussianDuration(totalMin)
    totalMin = math.max(0, math.floor(tonumber(totalMin) or 0))
    local h = math.floor(totalMin / 60)
    local m = totalMin % 60
    if h > 0 and m > 0 then return string.format('%d \xF7 %d \xEC\xE8\xED', h, m) end
    if h > 0 then return string.format('%d \xF7', h) end
    return string.format('%d \xEC\xE8\xED', m)
end

local ET_HELP_DAY_HDR = '\xC4\xE5\xED\xFC'
local ET_HELP_DATE_HDR = '\xC4\xE0\xF2\xE0'
local ET_HELP_TOTAL_LABEL = '\xC8\xF2\xEE\xE3\xEE'
local ET_HELP_ANS_HDR = '\xCE\xF2\xE2\xE5\xF2\xEE\xE2 \xE2 \xF0\xE5\xEF\xEE\xF0\xF2'
local ET_HELP_ONLINE_HDR = '\xD7\xE8\xF1\xF2\xFB\xE9 \xEE\xED\xEB\xE0\xE9\xED'

local function etHelpColTextW(text, pad)
    pad = pad or 8
    return imgui.CalcTextSize(uiText(text or '')).x + pad
end

local ET_HELP_COL_GAP = 16

local function etHelpTableWidths(availW)
    availW = math.max(260, tonumber(availW) or 260)
    local wDay = etHelpColTextW(ET_HELP_DAY_HDR, 10)
    wDay = math.max(wDay, etHelpColTextW(ET_HELP_TOTAL_LABEL, 12))
    for _, wd in pairs(ET_WD_SHORT) do
        wDay = math.max(wDay, etHelpColTextW(wd, 6))
    end
    local wDate = math.max(etHelpColTextW(ET_HELP_DATE_HDR, 10), etHelpColTextW('31.12', 8))
    local wGap = ET_HELP_COL_GAP
    local wAns = etHelpColTextW(ET_HELP_ANS_HDR, 10)
    local wOnline = availW - wDay - wDate - wGap - wAns - 12
    if wOnline < 80 then
        wOnline = 80
        wAns = math.max(etHelpColTextW('0', 10), availW - wDay - wDate - wGap - wOnline - 12)
    end
    return wDay, wDate, wGap, wOnline, wAns
end

local function etFindRowValue(rows, ...)
    local needles = { ... }
    for _, row in ipairs(rows) do
        for _, n in ipairs(needles) do
            local enc = normalizeStoredText(n, isUtf8Text(n))
            if row.label:find(enc, 1, true) or row.label:find(n, 1, true) then
                return row.value
            end
        end
    end
    return nil
end

local function etExtractTextAfterLabel(text, labelUtf8)
    text = stripTags(text or '')
    local label = normalizeStoredText(labelUtf8, isUtf8Text(labelUtf8))
    local chunk = text:match(label .. '[%s:]*([^\r\n]+)')
    if not chunk then return nil end
    chunk = trim(chunk)
    if chunk == '' then return nil end
    for segment in chunk:gmatch('[^\t]+') do
        segment = trim(segment)
        if segment ~= '' then return segment end
    end
    return chunk
end

local function etExtractDurationAfterLabel(text, labelUtf8)
    text = stripTags(text or '')
    local label = normalizeStoredText(labelUtf8, isUtf8Text(labelUtf8))
    local chunk = text:match(label .. '[%s:]*([^\r\n]+)')
    if chunk then
        for segment in chunk:gmatch('[^\t]+') do
            local mins = etParseRussianPlayTimeToMinutes(segment)
            if mins ~= nil then return mins end
        end
    end
    chunk = text:match(label .. '[%s:\r\n]+([^\r\n]+)')
    if chunk then return etParseRussianPlayTimeToMinutes(chunk) end
    local idx = text:find(label, 1, true)
    if idx then
        local slice = text:sub(idx, idx + 160)
        local dur = slice:match('(%d+%s*[\xF7ч]%s*%d+%s*[\xEC\xE8\xEDmin]+)')
            or slice:match('(%d+%s*[\xEC\xE8\xEDmin]+)')
            or slice:match('(%d+%s*[\xF7ч])')
        if dur then return etParseRussianPlayTimeToMinutes(dur) end
    end
    return nil
end

local function etMinutesFromDialogRows(rows, ...)
    local val = etFindRowValue(rows, ...)
    if val then return etParseRussianPlayTimeToMinutes(val) end
    return nil
end

local function etParseServerClock(text, rows)
    local plain = stripTags(text or '')
    local serverTime = etFindRowValue(rows, 'Текущее время', 'Точное время', 'Серверное время', 'Время на сервере')
        or etExtractTextAfterLabel(text, 'Текущее время')
        or etExtractTextAfterLabel(text, 'Точное время')
        or plain:match('(%d%d:%d%d:%d%d)') or plain:match('(%d%d:%d%d)')
    local serverDate = etFindRowValue(rows, 'Дата', 'Текущая дата', 'Сегодняшняя дата')
        or etExtractTextAfterLabel(text, 'Дата')
        or plain:match('(%d%d%.%d%d%.%d%d%d%d)')
        or os.date('%d.%m.%Y')
    local weekday = etFindRowValue(rows, 'День недели', 'День')
        or etExtractTextAfterLabel(text, 'День недели')
    return serverTime, serverDate, weekday
end

local function etParseClockHms(timeStr)
    local plain = trim(stripTags(timeStr or ''))
    if plain == '' then return nil end
    local h, m, s = plain:match('(%d%d):(%d%d):(%d%d)')
    if h then return tonumber(h), tonumber(m), tonumber(s) end
    h, m = plain:match('(%d%d):(%d%d)')
    if h then return tonumber(h), tonumber(m), 0 end
    return nil
end

local function etLiveClockValue(timeStr)
    local d = etState.data
    local base = d.clockBase
    if base then
        local elapsed = math.floor(os.clock() - base.at)
        if d._clockTick == elapsed and d._clockStr then
            return d._clockStr
        end
        local total = (base.h * 3600 + base.m * 60 + base.s + elapsed) % 86400
        d._clockStr = string.format('%02d:%02d:%02d',
            math.floor(total / 3600), math.floor((total % 3600) / 60), total % 60)
        d._clockTick = elapsed
        return d._clockStr
    end
    d._clockTick = nil
    d._clockStr = nil
    local plain = trim(stripTags(timeStr or ''))
    if plain == '' then return os.date('%H:%M:%S') end
    local h, m, s = plain:match('(%d%d):(%d%d):(%d%d)')
    if h then return string.format('%s:%s:%s', h, m, s) end
    h, m = plain:match('(%d%d):(%d%d)')
    if h then return string.format('%s:%s:%02d', h, m, tonumber(os.date('%S'))) end
    return os.date('%H:%M:%S')
end

local function etFormatDateLine(parts)
    if not parts or #parts == 0 then return nil end
    if #parts == 1 then return parts[1] end
    local weekday, dateStr = parts[1], parts[2]
    if weekday:find('%d%d%d%d', 1, true) or weekday:find(' - ', 1, true) then
        return weekday
    end
    return weekday .. '  \xB7  ' .. dateStr
end

local function etBuildDisplayList(text, dialogRows, cleanStr, playStr, afkStr)
    local serverTime, serverDate, weekday = etParseServerClock(text, dialogRows)
    local display = {}
    local function add(labelCp1251, value, kind)
        if value and value ~= '' then
            display[#display + 1] = { label = labelCp1251, value = value, kind = kind }
        end
    end
    add('Текущее время', etFindRowValue(dialogRows, 'Текущее время') or serverTime, 'time')
    add('День недели', etFindRowValue(dialogRows, 'День недели') or weekday, 'date')
    add('Сегодняшняя дата', etFindRowValue(dialogRows, 'Сегодняшняя дата', 'Дата', 'Текущая дата') or serverDate, 'date')
    add(L_ET_ONLINE_TODAY, playStr, 'today')
    add(L_ET_AFK_TODAY, afkStr, 'today')
    add(L_ET_PER_HOUR, etFindRowValue(dialogRows, 'Время в игре за час') or etExtractTextAfterLabel(text, 'Время в игре за час'), 'today')
    add(L_ET_CLEAN, cleanStr, 'accent')
    local playYdayRaw = etFindRowValue(dialogRows, 'Время в игре вчера', 'Онлайн вчера')
        or etExtractTextAfterLabel(text, 'Время в игре вчера')
        or etExtractTextAfterLabel(text, 'Онлайн вчера')
    local afkYdayRaw = etFindRowValue(dialogRows, 'AFK за вчера', 'AFK вчера')
        or etExtractTextAfterLabel(text, 'AFK за вчера')
        or etExtractTextAfterLabel(text, 'AFK вчера')
    add(L_ET_ONLINE_YDAY, playYdayRaw, 'yesterday')
    add(L_ET_AFK_YDAY, afkYdayRaw, 'yesterday')
    return display
end

local function etIsExactTimeDialog(title, text)
    local tit = stripTags(title or '')
    local txt = stripTags(text or '')
    if tit:find(normalizeStoredText('Точное время', isUtf8Text('Точное время')), 1, true) then return true end
    if tit:find(normalizeStoredText('точного времени', isUtf8Text('точного времени')), 1, true) then return true end
    if tit:find(normalizeStoredText('Служба точного', isUtf8Text('Служба точного')), 1, true) then return true end
    if etState.pendingCmdAt and (os.clock() - etState.pendingCmdAt) <= EXACT_TIME_TIMEOUT then
        if txt:find(normalizeStoredText('Время в игре сегодня', isUtf8Text('Время в игре сегодня')), 1, true)
            and (txt:find(normalizeStoredText('AFK за сегодня', isUtf8Text('AFK за сегодня')), 1, true) or txt:find('AFK', 1, true)) then
            return true
        end
    end
    return false
end

local function etParseServerDateKey(serverDate)
    local d, m, y = tostring(serverDate or ''):match('(%d%d)%.(%d%d)%.(%d%d%d%d)')
    if d then return string.format('%s-%s-%s', y, m, d) end
    return os.date('%Y-%m-%d')
end

local function etCurrentWeekMondayKey(ts)
    ts = ts or os.time()
    local w = tonumber(os.date('%w', ts)) or 0
    local daysSinceMonday = (w == 0) and 6 or (w - 1)
    return os.date('%Y-%m-%d', ts - daysSinceMonday * 86400)
end

local function etMondayTsFromKey(weekKey)
    local y, m, d = tostring(weekKey or ''):match('(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return nil end
    return os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = 12, min = 0, sec = 0,
    })
end

local function etHelpViewWeekMondayKey()
    local offset = math.max(0, math.min(ET_HELP_WEEK_MAX_BACK,
        math.floor(tonumber(etState.helpWeekOffset) or 0)))
    etState.helpWeekOffset = offset
    if offset == 0 then return etCurrentWeekMondayKey() end
    local curTs = etMondayTsFromKey(etCurrentWeekMondayKey())
    if not curTs then return etCurrentWeekMondayKey() end
    return os.date('%Y-%m-%d', curTs - offset * 7 * 86400)
end

local function etWeekRangeLabel(weekMondayKey)
    local baseTs = etMondayTsFromKey(weekMondayKey)
    if not baseTs then return '' end
    return string.format('%s \xB7 %s', os.date('%d.%m', baseTs), os.date('%d.%m', baseTs + 6 * 86400))
end

local function etPruneOldOnlineDays()
    local cutoffKey = os.date('%Y-%m-%d', os.time() - ET_ONLINE_RETAIN_DAYS * 86400)
    local store = etState.online
    local changed = false
    for dateKey in pairs(store.days) do
        if dateKey < cutoffKey then
            store.days[dateKey] = nil
            changed = true
        end
    end
    if changed then pcall(etSaveOnlineStore) end
end

local function etCurrentMonthKey(ts)
    ts = ts or os.time()
    return os.date('%Y-%m', ts)
end

local function etEnsureOnlinePeriods()
    local weekKey = etCurrentWeekMondayKey()
    local monthKey = etCurrentMonthKey()
    local store = etState.online
    if store.weekKey ~= weekKey then
        store.weekKey = weekKey
    end
    if store.monthKey ~= monthKey then
        store.monthKey = monthKey
    end
    etPruneOldOnlineDays()
    return weekKey, monthKey
end

local function etOpenIni(primary, legacy)
    local f = io.open(primary, 'r')
    if f then return f end
    if legacy then return io.open(legacy, 'r') end
end

function etLoadOnlineStore()
    etState.online.weekKey = nil
    etState.online.monthKey = nil
    etState.online.days = {}
    local f = etOpenIni(ET_ONLINE_PATH, ET_LEGACY_ONLINE)
    if f then
        for line in f:lines() do
            local week = line:match('^%s*week%s*=%s*(%S+)%s*$')
            if week then
                etState.online.weekKey = week
            else
                local month = line:match('^%s*month%s*=%s*(%S+)%s*$')
                if month then
                    etState.online.monthKey = month
                else
                    local dateKey, mins = line:match('^(%d%d%d%d%-%d%d%-%d%d)%s*=%s*(%d+)%s*$')
                    if dateKey and mins then
                        etState.online.days[dateKey] = tonumber(mins)
                    end
                end
            end
        end
        f:close()
    end
    etEnsureOnlinePeriods()
end

function etSaveOnlineStore()
    local f = io.open(ET_ONLINE_PATH, 'w')
    if not f then return end
    local store = etState.online
    if store.weekKey then f:write('week=' .. store.weekKey .. '\n') end
    if store.monthKey then f:write('month=' .. store.monthKey .. '\n') end
    for dateKey, mins in pairs(store.days) do
        f:write(string.format('%s=%d\n', dateKey, mins))
    end
    f:close()
end

local function etLoadAnsStore()
    etState.ans.days = {}
    local f = io.open(ET_ANS_PATH, 'r')
    if not f then return end
    for line in f:lines() do
        local dateKey, cnt = line:match('^(%d%d%d%d%-%d%d%-%d%d)%s*=%s*(%d+)%s*$')
        if dateKey and cnt then
            etState.ans.days[dateKey] = tonumber(cnt)
        end
    end
    f:close()
end

local function etSaveAnsStore()
    local f = io.open(ET_ANS_PATH, 'w')
    if not f then return end
    for dateKey, cnt in pairs(etState.ans.days) do
        f:write(string.format('%s=%d\n', dateKey, tonumber(cnt) or 0))
    end
    f:close()
end

local function etBackfillAnsFromThreads()
    if etState.ans.backfilled then return end
    etState.ans.backfilled = true
    for _ in pairs(etState.ans.days) do return end
    if type(threads) ~= 'table' then return end
    local changed = false
    for _, t in pairs(threads) do
        if type(t.messages) == 'table' then
            for _, m in ipairs(t.messages) do
                if m and m.dir == 'out' and m.self ~= false and m.ts then
                    local body = trim(m.text or m.rawText or '')
                    if body:match('^/ans%s') or body:match('^ans%s') then
                        local dateKey = os.date('%Y-%m-%d', m.ts)
                        etState.ans.days[dateKey] = (tonumber(etState.ans.days[dateKey]) or 0) + 1
                        changed = true
                    end
                end
            end
        end
    end
    if changed then pcall(etSaveAnsStore) end
end

function helpStatsRecordAns(ts)
    ts = tonumber(ts) or os.time()
    local dateKey = os.date('%Y-%m-%d', ts)
    etState.ans.days[dateKey] = (tonumber(etState.ans.days[dateKey]) or 0) + 1
    pcall(etSaveAnsStore)
end

function exactTimeNoteOutgoingAns(msg)
    if type(msg) ~= 'string' then return end
    local s = trim(msg)
    if s:sub(1, 1) == '/' then s = trim(s:sub(2)) end
    local id, body = s:match('^ans%s+(%d+)%s+(.+)$')
    if not id or not body or trim(body) == '' then return end
    helpStatsRecordAns()
end

local ET_PUNISH_HEAD_TO_KIND = {
    jail = 'jail', unjail = 'jail', offjail = 'jail',
    mute = 'mute', unmute = 'mute', offmute = 'mute',
    kick = 'kick', skick = 'kick',
    ban = 'ban', unban = 'ban', offban = 'ban',
    warn = 'warn', unwarn = 'warn', offwarn = 'warn',
}

local ET_PUNISH_FILTERS = {
    { id = 'all',  label = '\xC2\xF1\xE5' },
    { id = 'jail', label = 'Jail' },
    { id = 'mute', label = 'Mute' },
    { id = 'kick', label = 'Kick' },
    { id = 'ban',  label = 'Ban' },
    { id = 'warn', label = 'Warn' },
}

local function etPunishCmdHead(cmd)
    cmd = trim(tostring(cmd or ''))
    if cmd == '' then return '' end
    local inner = cmd:match('^/?a%s+(/.*)$')
    if inner then cmd = trim(inner) end
    if cmd:sub(1, 1) ~= '/' then cmd = '/' .. cmd end
    local head = cmd:match('^/(%S+)')
    return head and head:lower() or ''
end

local function etPunishKindFromCmd(cmd)
    return ET_PUNISH_HEAD_TO_KIND[etPunishCmdHead(cmd)] or 'other'
end

local function etPunishIsTrackedEntry(e)
    if type(e) ~= 'table' then return false end
    local kind = trim(tostring(e.kind or ''))
    if kind == 'tr' then return false end
    local head = etPunishCmdHead(e.cmd)
    if head == 'tr' then return false end
    return true
end

local function etInvalidatePunishWeekCache()
    etState.punish.weekCache = nil
end

local function etPunishNormalizeEntry(raw)
    if type(raw) ~= 'table' then return nil end
    local ts = tonumber(raw.ts)
    if ts and ts > 0 then
        ts = math.floor(ts)
    else
        ts = 0
    end
    local cmd = trim(tostring(raw.cmd or ''))
    local kind = trim(tostring(raw.kind or ''))
    if kind == '' then kind = etPunishKindFromCmd(cmd) end
    return {
        ts = ts,
        dateKey = os.date('%Y-%m-%d', ts),
        kind = kind,
        action = trim(tostring(raw.action or '-')),
        player = trim(tostring(raw.player or '?')),
        pid = tonumber(raw.pid) or -1,
        term = trim(tostring(raw.term or '-')),
        reason = trim(tostring(raw.reason or '-')),
        cmd = cmd,
        reqAdmin = trim(tostring(raw.reqAdmin or '')),
        reqAdminId = tonumber(raw.reqAdminId),
        src = trim(tostring(raw.src or 'manual')),
    }
end

local function etPunishEntrySort(a, b)
    if a.ts ~= b.ts then return a.ts < b.ts end
    return (a.cmd or '') < (b.cmd or '')
end

local function etRewritePunishStore()
    if not encodeJson then return end
    local f = io.open(ET_PUNISH_PATH, 'w')
    if not f then return end
    for _, e in ipairs(etState.punish.entries) do
        local ok, line = pcall(encodeJson, e)
        if ok and line then f:write(line .. '\n') end
    end
    f:close()
end

local function etPunishPruneStore(rewrite)
    if #etState.punish.entries == 0 then return false end
    local cutoffKey = os.date('%Y-%m-%d', os.time() - ET_PUNISH_RETAIN_DAYS * 86400)
    local kept = {}
    for _, e in ipairs(etState.punish.entries) do
        local dk = e.dateKey or os.date('%Y-%m-%d', tonumber(e.ts) or 0)
        if dk >= cutoffKey then
            kept[#kept + 1] = e
        end
    end
    if #kept > ET_PUNISH_MAX_STORE then
        local trimmed = {}
        local start = #kept - ET_PUNISH_MAX_STORE + 1
        for i = start, #kept do
            trimmed[#trimmed + 1] = kept[i]
        end
        kept = trimmed
    end
    local changed = #kept ~= #etState.punish.entries
    if changed then
        etState.punish.entries = kept
        etInvalidatePunishWeekCache()
        if rewrite then pcall(etRewritePunishStore) end
    end
    return changed
end

local function etAppendPunishStoreLine(e)
    if not encodeJson then
        if not etState.punish.encodeWarned then
            etState.punish.encodeWarned = true
            print('[Report Desk] punish log: encodeJson missing (dkjson?)')
        end
        pcall(etRewritePunishStore)
        return
    end
    local ok, line = pcall(encodeJson, e)
    if not ok or not line then return end
    local f = io.open(ET_PUNISH_PATH, 'a')
    if f then
        f:write(line .. '\n')
        f:close()
    end
end

local function etLoadPunishStore()
    etState.punish.entries = {}
    if not decodeJson then
        print('[Report Desk] punish log: decodeJson missing on load')
        return
    end
    local f = io.open(ET_PUNISH_PATH, 'r')
    if not f then return end
    for line in f:lines() do
        line = trim(line)
        if line ~= '' and decodeJson then
            local ok, row = pcall(decodeJson, line)
            if ok then
                local e = etPunishNormalizeEntry(row)
                if e then etState.punish.entries[#etState.punish.entries + 1] = e end
            end
        end
    end
    f:close()
    table.sort(etState.punish.entries, etPunishEntrySort)
    etPunishPruneStore(true)
end

function helpStatsRecordPunish(raw)
    local ok, err = pcall(function()
        local e = etPunishNormalizeEntry(raw)
        if not e or not etPunishIsTrackedEntry(e) then return end
        if not e.ts or e.ts <= 0 then
            e.ts = os.time()
            e.dateKey = os.date('%Y-%m-%d', e.ts)
        end
        etState.punish.entries[#etState.punish.entries + 1] = e
        etInvalidatePunishWeekCache()
        if etPunishPruneStore(true) then
            return
        end
        etAppendPunishStoreLine(e)
    end)
    if not ok then
        print('[Report Desk] punish log: ' .. tostring(err))
    end
end

local ET_PUNISH_KIND_LABEL = {
    jail = 'Jail', mute = 'Mute', kick = 'Kick', ban = 'Ban', warn = 'Warn',
}

local ET_PUNISH_HEAD_LABEL = {
    unjail = 'Unjail', unmute = 'Unmute', unwarn = 'Unwarn', unban = 'Unban',
    offjail = 'OffJail', offmute = 'OffMute', offban = 'OffBan', offwarn = 'OffWarn',
    skick = 'SKick',
}

local function etFormatPunishDateLine(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return '?' end
    local wd = os.date('%a', ts)
    local day = ET_WD_SHORT[wd] or wd
    return string.format('%s \xB7 %s', day, os.date('%d.%m', ts))
end

local function etFormatPunishClockLine(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return '?' end
    return os.date('%H:%M:%S', ts)
end

local function etFormatPunishKindLabel(e)
    if type(e) ~= 'table' then return '?' end
    local head = etPunishCmdHead(e.cmd or '')
    if head ~= '' and ET_PUNISH_HEAD_LABEL[head] then
        return ET_PUNISH_HEAD_LABEL[head]
    end
    local kind = e.kind or etPunishKindFromCmd(e.cmd)
    if kind and ET_PUNISH_KIND_LABEL[kind] then
        return ET_PUNISH_KIND_LABEL[kind]
    end
    if kind and kind ~= '' then
        return kind:sub(1, 1):upper() .. kind:sub(2)
    end
    return '?'
end

local function etFormatPunishPlayer(e)
    local nick = trim(e.player or '?')
    local pid = tonumber(e.pid)
    if pid and pid >= 0 then
        return string.format('%s[%d]', nick, pid)
    end
    return nick
end

local ET_PUNISH_TERM_EMPTY = '-'

local ET_PUNISH_NO_TERM_KIND = {
    kick = true, skick = true, warn = true, unwarn = true,
    unjail = true, unmute = true, unban = true, tr = true,
}

local ET_PUNISH_NO_TERM_HEAD = {
    kick = true, skick = true, warn = true, unwarn = true,
    unjail = true, unmute = true, unban = true, tr = true,
}

local function etPunishHasTerm(e)
    if type(e) ~= 'table' then return false end
    local kind = e.kind or etPunishKindFromCmd(e.cmd or '')
    if ET_PUNISH_NO_TERM_KIND[kind] then return false end
    return not ET_PUNISH_NO_TERM_HEAD[etPunishCmdHead(e.cmd or '')]
end

local function etPunishTermIsDays(e)
    if type(e) ~= 'table' then return false end
    local head = etPunishCmdHead(e.cmd or '')
    return head == 'ban' or head == 'offban'
end

local function etFormatDaysRu(days)
    days = math.floor(tonumber(days) or 0)
    if days <= 0 then return ET_PUNISH_TERM_EMPTY end
    local mod10 = days % 10
    local mod100 = days % 100
    local unit
    if mod10 == 1 and mod100 ~= 11 then
        unit = '\xE4\xE5\xED\xFC'
    elseif mod10 >= 2 and mod10 <= 4 and (mod100 < 10 or mod100 >= 20) then
        unit = '\xE4\xED\xFF'
    else
        unit = '\xE4\xED\xE5\xE9'
    end
    return string.format('%d %s', days, unit)
end

local function etFormatPunishTerm(e)
    if type(e) == 'table' and not etPunishHasTerm(e) then
        return ET_PUNISH_TERM_EMPTY
    end
    local term = type(e) == 'table' and e.term or e
    term = trim(tostring(term or ''))
    if term == '' or term == '-' then return ET_PUNISH_TERM_EMPTY end
    local n = tonumber(term)
    if n then
        n = math.floor(n)
        if n <= 0 then return ET_PUNISH_TERM_EMPTY end
        if type(e) == 'table' and etPunishTermIsDays(e) then
            return etFormatDaysRu(n)
        end
        if n >= 60 and n % 60 == 0 then
            return string.format('%d \xF7', math.floor(n / 60))
        end
        return string.format('%d \xEC\xE8\xED', n)
    end
    return term
end

local function etFormatPunishAction(e)
    return etFormatPunishKindLabel(e)
end

local function etPunishKindIsRemoval(e)
    local head = etPunishCmdHead(e.cmd or '')
    return head == 'unjail' or head == 'unmute' or head == 'unwarn' or head == 'unban'
end

local function etPunishKindColor(e)
    if etPunishKindIsRemoval(e) then
        return ET_COL_OK
    end
    return col_punish_label or ET_COL_FAIL
end

local function etPunishEntriesForViewWeek()
    local weekKey = etHelpViewWeekMondayKey()
    local baseTs = etMondayTsFromKey(weekKey)
    if not baseTs then return {}, weekKey end
    local weekEnd = os.date('%Y-%m-%d', baseTs + 6 * 86400)
    local cache = etState.punish.weekCache
    if cache and cache.weekKey == weekKey then
        return cache.rows, weekKey, cache.counts
    end

    local rows = {}
    local counts = { all = 0, jail = 0, mute = 0, kick = 0, ban = 0, warn = 0, other = 0 }
    local entries = etState.punish.entries
    for i = #entries, 1, -1 do
        local e = entries[i]
        if not etPunishIsTrackedEntry(e) then goto continue_entry end
        local dk = e.dateKey or os.date('%Y-%m-%d', e.ts or 0)
        if dk < weekKey then break end
        if dk <= weekEnd then
            rows[#rows + 1] = e
            counts.all = counts.all + 1
            local kind = e.kind or etPunishKindFromCmd(e.cmd)
            if counts[kind] ~= nil then
                counts[kind] = counts[kind] + 1
            else
                counts.other = counts.other + 1
            end
        end
        ::continue_entry::
    end

    etState.punish.weekCache = { weekKey = weekKey, rows = rows, counts = counts }
    return rows, weekKey, counts
end

local function etPunishFilterRows(rows, filterId)
    filterId = filterId or 'all'
    if filterId == 'all' or filterId == '' then return rows end
    local out = {}
    for _, e in ipairs(rows) do
        local kind = e.kind or etPunishKindFromCmd(e.cmd)
        if kind == filterId then out[#out + 1] = e end
    end
    return out
end

local ET_PUNISH_DATE_HDR = '\xC4\xE0\xF2\xE0'
local ET_PUNISH_CLOCK_HDR = '\xC2\xF0\xE5\xEC\xFF'
local ET_PUNISH_PLAYER_HDR = '\xC8\xE3\xF0\xEE\xEA'
local ET_PUNISH_ACTION_HDR = '\xD2\xE8\xEF'
local ET_PUNISH_TERM_HDR = '\xD1\xF0\xEE\xEA'
local ET_PUNISH_REASON_HDR = '\xCF\xF0\xE8\xF7\xE8\xED\xE0'

local ET_PUNISH_COL_PAD = 12
local ET_PUNISH_ROW_GAP = 8
local ET_PUNISH_SCROLL_MIN_H = 320
local ET_PUNISH_SCROLL_MAX_H = 480

local function etPunishClipCol(text, colW)
    text = text or ''
    if text == ET_PUNISH_TERM_EMPTY or text == '-' then
        return uiText(ET_PUNISH_TERM_EMPTY)
    end
    colW = tonumber(colW) or 0
    if colW < 8 then return uiText(ET_PUNISH_TERM_EMPTY) end
    if type(ellipsizeToWidth) == 'function' then
        return ellipsizeToWidth(text, colW - 4)
    end
    return uiText(text)
end

local function etPunishLineH()
    local sp = imgui.GetStyle().ItemSpacing
    return imgui.GetTextLineHeight() + sp.y
end

local function etPunishTableLayout(availW, rows)
    availW = math.floor(math.max(320, tonumber(availW) or 320))
    local pad = ET_PUNISH_COL_PAD

    local minDate = etHelpColTextW(ET_PUNISH_DATE_HDR, pad)
    for _, wd in pairs(ET_WD_SHORT) do
        minDate = math.max(minDate, etHelpColTextW(wd .. ' \xB7 31.12', 8))
    end
    local minClock = math.max(
        etHelpColTextW(ET_PUNISH_CLOCK_HDR, pad),
        etHelpColTextW('23:59:59', 8))
    local minPlayer = etHelpColTextW(ET_PUNISH_PLAYER_HDR, pad)
    local minAction = etHelpColTextW(ET_PUNISH_ACTION_HDR, pad)
    local minTerm = math.max(
        etHelpColTextW(ET_PUNISH_TERM_HDR, pad),
        etHelpColTextW(ET_PUNISH_TERM_EMPTY, 8),
        etHelpColTextW('999 \xEC\xE8\xED', 8),
        etHelpColTextW('99 \xF7', 8),
        etHelpColTextW('21 \xE4\xE5\xED\xFC', 8),
        etHelpColTextW('5 \xE4\xED\xE5\xE9', 8))

    for _, lbl in pairs(ET_PUNISH_KIND_LABEL) do
        minAction = math.max(minAction, etHelpColTextW(lbl, 8))
    end
    for _, lbl in pairs(ET_PUNISH_HEAD_LABEL) do
        minAction = math.max(minAction, etHelpColTextW(lbl, 8))
    end

    local shown = 0
    for _, e in ipairs(rows or {}) do
        if shown >= ET_PUNISH_UI_MAX then break end
        shown = shown + 1
        minPlayer = math.max(minPlayer, etHelpColTextW(etFormatPunishPlayer(e), 8))
        minAction = math.max(minAction, etHelpColTextW(etFormatPunishKindLabel(e), 8))
        minTerm = math.max(minTerm, etHelpColTextW(etFormatPunishTerm(e), 8))
    end

    local wDate = math.max(minDate, math.floor(availW * 0.11))
    local wClock = math.max(minClock, math.floor(availW * 0.10))
    local wPlayer = math.max(minPlayer, math.floor(availW * 0.26))
    local wAction = math.max(minAction, math.floor(availW * 0.08))
    local wTerm = math.max(minTerm, math.floor(availW * 0.09))
    local wReason = availW - wDate - wClock - wPlayer - wAction - wTerm

    if wReason < math.floor(availW * 0.28) then
        wPlayer = math.max(minPlayer, wPlayer - (math.floor(availW * 0.28) - wReason))
        wReason = availW - wDate - wClock - wPlayer - wAction - wTerm
    end
    if wReason < 80 then
        wReason = 80
        wPlayer = math.max(minPlayer, availW - wDate - wClock - wAction - wTerm - wReason)
    end

    local widths = { wDate, wClock, wPlayer, wAction, wTerm, wReason }
    local xs = { 0, wDate, wDate + wClock, wDate + wClock + wPlayer,
        wDate + wClock + wPlayer + wAction,
        wDate + wClock + wPlayer + wAction + wTerm }
    return widths, xs, availW
end

local function etPunishTextCell(x, y, w, text, color)
    imgui.SetCursorPos(imgui.ImVec2(x, y))
    imgui.PushTextWrapPos(x + math.max(16, w) - 4)
    imgui.TextColored(color, text)
    imgui.PopTextWrapPos()
end

local function etPunishDrawSep(x, y, w)
    local dl = imgui.GetWindowDrawList()
    if not dl then return y + ET_PUNISH_ROW_GAP end
    imgui.SetCursorPos(imgui.ImVec2(x, y))
    local sp = imgui.GetCursorScreenPos()
    dl:AddLine(sp, imgui.ImVec2(sp.x + w, sp.y), toU32(imgui.ImVec4(1.0, 1.0, 1.0, 0.12)), 1.0)
    return y + ET_PUNISH_ROW_GAP
end

local function etPunishScrollHeight()
    local remainY = imgui.GetContentRegionAvail().y
    local scrollH = remainY - 52
    if scrollH < ET_PUNISH_SCROLL_MIN_H then scrollH = ET_PUNISH_SCROLL_MIN_H end
    if scrollH > ET_PUNISH_SCROLL_MAX_H then scrollH = ET_PUNISH_SCROLL_MAX_H end
    return scrollH
end

local function etDrawPunishFilterBar(counts)
    if not etState.punish.filter or etState.punish.filter == '' then
        etState.punish.filter = 'all'
    end
    if etState.punish.filter == 'tr' then
        etState.punish.filter = 'all'
    end
    local sel = etState.punish.filter
    local gap = 6
    local btnH = 26
    local n = #ET_PUNISH_FILTERS
    local rowW = imgui.GetContentRegionAvail().x
    local baseW = math.floor((rowW - gap * (n - 1)) / n)
    local x0 = imgui.GetCursorPosX()
    local y0 = imgui.GetCursorPosY()
    local accentDim = col_accent_dim or imgui.ImVec4(0.28, 0.22, 0.42, 0.95)
    local accent = col_accent or imgui.ImVec4(0.34, 0.26, 0.50, 1.0)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 4)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(8, 5))

    local posX = x0
    for i, f in ipairs(ET_PUNISH_FILTERS) do
        local btnW = (i == n) and (rowW - (posX - x0)) or baseW
        imgui.SetCursorPos(imgui.ImVec2(posX, y0))
        local cnt = tonumber(counts and counts[f.id]) or 0
        local label = uiText(f.label) .. ' (' .. tostring(cnt) .. ')'
        local active = sel == f.id
        if active then
            imgui.PushStyleColor(imgui.Col.Button, accentDim)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, accent)
        end
        if imgui.Button(label .. '##pf_' .. f.id, imgui.ImVec2(btnW, btnH)) then
            etState.punish.filter = f.id
        end
        if active then imgui.PopStyleColor(2) end
        posX = posX + btnW + gap
    end
    imgui.SetCursorPos(imgui.ImVec2(x0, y0 + btnH + 10))
    imgui.PopStyleVar(2)
end

local function etDrawHelpPunishLog()
    local weekRows, _, counts = etPunishEntriesForViewWeek()
    etDrawPunishFilterBar(counts)

    local filterId = etState.punish.filter or 'all'
    local rows = etPunishFilterRows(weekRows, filterId)
    local weekTotal = counts and counts.all or #weekRows

    if weekTotal == 0 then
        drawSettingsHint('\xCD\xE5\xF2 \xE2\xFB\xE4\xE0\xED\xED\xFB\xF5 \xED\xE0\xEA\xE0\xE7\xE0\xED\xE8\xE9 \xE7\xE0 \xE2\xFB\xE1\xF0\xE0\xED\xED\xF3\xFE \xED\xE5\xE4\xE5\xEB\xFE')
        return
    end
    if #rows == 0 then
        local filterLabel = filterId
        for _, f in ipairs(ET_PUNISH_FILTERS) do
            if f.id == filterId then filterLabel = f.label break end
        end
        drawSettingsHint(string.format(
            '\xCD\xE5\xF2 \xE7\xE0\xEF\xE8\xF1\xE5\xE9 \xAB%s\xBB \xE7\xE0 \xE2\xFB\xE1\xF0\xE0\xED\xED\xF3\xFE \xED\xE5\xE4\xE5\xEB\xFE \xB7 \xE2\xF1\xE5\xE3\xEE %d',
            filterLabel, weekTotal))
        return
    end

    local hdrCol = col_muted2 or imgui.ImVec4(0.62, 0.60, 0.68, 1.0)
    local valCol = col_label or imgui.ImVec4(0.92, 0.92, 0.95, 1.0)
    local childFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        childFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end

    imgui.BeginChild('##help_punish_scroll', imgui.ImVec2(-1, etPunishScrollHeight()), true, childFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))

    local widths, xs, tableW = etPunishTableLayout(imgui.GetContentRegionAvail().x, rows)
    local x0 = imgui.GetCursorPosX()
    local y = imgui.GetCursorPosY()
    local lineH = etPunishLineH()

    etPunishTextCell(x0 + xs[1], y, widths[1], uiText(ET_PUNISH_DATE_HDR), hdrCol)
    etPunishTextCell(x0 + xs[2], y, widths[2], uiText(ET_PUNISH_CLOCK_HDR), hdrCol)
    etPunishTextCell(x0 + xs[3], y, widths[3], uiText(ET_PUNISH_PLAYER_HDR), hdrCol)
    etPunishTextCell(x0 + xs[4], y, widths[4], uiText(ET_PUNISH_ACTION_HDR), hdrCol)
    etPunishTextCell(x0 + xs[5], y, widths[5], uiText(ET_PUNISH_TERM_HDR), hdrCol)
    etPunishTextCell(x0 + xs[6], y, widths[6], uiText(ET_PUNISH_REASON_HDR), hdrCol)

    y = y + lineH + 2
    y = etPunishDrawSep(x0, y, tableW)

    local shown = 0
    for _, e in ipairs(rows) do
        if shown >= ET_PUNISH_UI_MAX then break end
        shown = shown + 1
        local reason = e.reason or '-'
        if e.src == 'auto' and trim(e.reqAdmin or '') ~= '' then
            reason = reason .. string.format(
                ' \xB7 \xE7\xE0\xEF\xF0\xEE\xF1 %s[%s]',
                e.reqAdmin, tostring(e.reqAdminId or '?'))
        elseif e.src == 'a_request' then
            reason = reason .. ' \xB7 \xE2 \xE0\xE4\xEC\xE8\xED-\xF7\xE0\xF2'
        end
        etPunishTextCell(x0 + xs[1], y, widths[1], uiText(etFormatPunishDateLine(e.ts)), valCol)
        etPunishTextCell(x0 + xs[2], y, widths[2], uiText(etFormatPunishClockLine(e.ts)), col_muted2)
        etPunishTextCell(x0 + xs[3], y, widths[3], etPunishClipCol(etFormatPunishPlayer(e), widths[3]), valCol)
        etPunishTextCell(x0 + xs[4], y, widths[4], etPunishClipCol(etFormatPunishKindLabel(e), widths[4]), etPunishKindColor(e))
        etPunishTextCell(x0 + xs[5], y, widths[5], etPunishClipCol(etFormatPunishTerm(e), widths[5]), col_muted2)
        etPunishTextCell(x0 + xs[6], y, widths[6], etPunishClipCol(reason, widths[6]), col_muted2)
        y = y + lineH
    end

    imgui.SetCursorPos(imgui.ImVec2(x0, y))
    imgui.Dummy(imgui.ImVec2(tableW, 1))
    imgui.PopStyleVar()
    imgui.EndChild()

    imgui.Dummy(imgui.ImVec2(0, 4))

    drawSettingsHint(string.format(
        '\xCF\xEE\xEA\xE0\xE7\xE0\xED\xEE %d \xE8\xE7 %d',
        shown, #rows))
end

local function etAnsCount(dateKey)
    return tonumber(etState.ans.days[dateKey]) or 0
end

local function etSumAns(filterFn)
    local total = 0
    for dateKey, cnt in pairs(etState.ans.days) do
        if filterFn(dateKey) then
            total = total + (tonumber(cnt) or 0)
        end
    end
    return total
end

local function etWeekAnsTotal(weekMondayKey)
    local baseTs = etMondayTsFromKey(weekMondayKey)
    if not baseTs then return 0 end
    local weekEnd = os.date('%Y-%m-%d', baseTs + 6 * 86400)
    return etSumAns(function(k) return k >= weekMondayKey and k <= weekEnd end)
end

local function etBuildWeekDayRows(weekMondayKey)
    weekMondayKey = weekMondayKey or etCurrentWeekMondayKey()
    local y, m, d = weekMondayKey:match('(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return {} end
    local baseTs = os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = 12, min = 0, sec = 0,
    })
    local todayKey = os.date('%Y-%m-%d')
    local viewingCurrent = weekMondayKey == etCurrentWeekMondayKey()
    local dailyNorm = etDailyNormMin()
    local rows = {}
    for i = 0, 6 do
        local ts = baseTs + i * 86400
        local dateKey = os.date('%Y-%m-%d', ts)
        local enWd = os.date('%a', ts)
        local onlineMin = tonumber(etState.online.days[dateKey])
        local ansCnt = etAnsCount(dateKey)
        local normOk = nil
        if onlineMin ~= nil then
            normOk = onlineMin >= dailyNorm
        end
        rows[#rows + 1] = {
            dateKey = dateKey,
            weekday = ET_WD_SHORT[enWd] or enWd,
            dateLabel = os.date('%d.%m', ts),
            onlineMin = onlineMin,
            ansCnt = ansCnt,
            normOk = normOk,
            isToday = viewingCurrent and dateKey == todayKey,
        }
    end
    return rows
end

local function etDrawActivityBar(valueMin, normMin, fillColor)
    valueMin = math.max(0, tonumber(valueMin) or 0)
    normMin = math.max(1, tonumber(normMin) or 1)
    local frac = math.max(0, math.min(1, valueMin / normMin))
    local barW = imgui.GetContentRegionAvail().x
    local barH = 3
    local p = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    dl:AddRectFilled(p, imgui.ImVec2(p.x + barW, p.y + barH), toU32(imgui.ImVec4(0.18, 0.18, 0.22, 1.0)), 2.0)
    if frac > 0.001 then
        dl:AddRectFilled(p, imgui.ImVec2(p.x + barW * frac, p.y + barH), toU32(fillColor or ET_COL.accent), 2.0)
    end
    imgui.Dummy(imgui.ImVec2(0, barH + 8))
end

local function etDrawHelpWeekNav(viewWeekKey)
    local offset = tonumber(etState.helpWeekOffset) or 0
    local rowW = imgui.GetContentRegionAvail().x
    local btnSz = imgui.GetFrameHeight()
    local dirLeft = (imgui.Dir and imgui.Dir.Left) or 0
    local dirRight = (imgui.Dir and imgui.Dir.Right) or 1
    local rangeText = uiText(etWeekRangeLabel(viewWeekKey))
    local textW = imgui.CalcTextSize(rangeText).x
    local y0 = imgui.GetCursorPosY()
    local x0 = imgui.GetCursorPosX()
    local textX = x0 + math.max(btnSz + 6, (rowW - textW) * 0.5)
    local textY = y0 + math.max(0, (btnSz - imgui.GetTextLineHeight()) * 0.5)
    local labelCol = col_accent or ET_COL.accent

    if type(deskPushFlatInputStyle) == 'function' then deskPushFlatInputStyle() end
    if offset < ET_HELP_WEEK_MAX_BACK then
        if imgui.ArrowButton('##et_wk_prev', dirLeft) then
            etState.helpWeekOffset = offset + 1
        end
    else
        imgui.Dummy(imgui.ImVec2(btnSz, btnSz))
    end
    if type(deskPopFlatInputStyle) == 'function' then deskPopFlatInputStyle() end

    if offset > 0 then
        imgui.SetCursorPos(imgui.ImVec2(textX, y0))
        if imgui.InvisibleButton('##et_wk_now', imgui.ImVec2(textW, btnSz)) then
            etState.helpWeekOffset = 0
        end
    end
    imgui.SetCursorPos(imgui.ImVec2(textX, textY))
    imgui.TextColored(labelCol, rangeText)

    imgui.SetCursorPos(imgui.ImVec2(x0 + rowW - btnSz, y0))
    if offset > 0 then
        if type(deskPushFlatInputStyle) == 'function' then deskPushFlatInputStyle() end
        if imgui.ArrowButton('##et_wk_next', dirRight) then
            etState.helpWeekOffset = offset - 1
        end
        if type(deskPopFlatInputStyle) == 'function' then deskPopFlatInputStyle() end
    end

    imgui.SetCursorPos(imgui.ImVec2(x0, y0 + btnSz + 6))
end

local function etDrawHelpWeekTable()
    local viewWeekKey = etHelpViewWeekMondayKey()
    local rows = etBuildWeekDayRows(viewWeekKey)
    if #rows == 0 then
        drawSettingsHint('\xCD\xE5\xF2 \xE4\xE0\xED\xED\xFB\xF5 \xE7\xE0 \xED\xE5\xE4\xE5\xEB\xFE')
        return
    end
    local weekAns = etWeekAnsTotal(viewWeekKey)

    etDrawHelpWeekNav(viewWeekKey)

    local hdrCol = col_muted2 or imgui.ImVec4(0.62, 0.60, 0.68, 1.0)
    local valCol = col_label or imgui.ImVec4(0.92, 0.92, 0.95, 1.0)

    local availW = imgui.GetContentRegionAvail().x
    local wDay, wDate, wGap, wOnline, wAns = etHelpTableWidths(availW)

    imgui.Columns(5, '##help_week_cols', false)
    if imgui.SetColumnWidth then
        imgui.SetColumnWidth(0, wDay)
        imgui.SetColumnWidth(1, wDate)
        imgui.SetColumnWidth(2, wGap)
        imgui.SetColumnWidth(3, wOnline)
        imgui.SetColumnWidth(4, wAns)
    end

    imgui.TextColored(hdrCol, uiText(ET_HELP_DAY_HDR))
    imgui.NextColumn()
    imgui.TextColored(hdrCol, uiText(ET_HELP_DATE_HDR))
    imgui.NextColumn()
    imgui.NextColumn()
    imgui.TextColored(hdrCol, uiText(ET_HELP_ONLINE_HDR))
    imgui.NextColumn()
    imgui.TextColored(hdrCol, uiText(ET_HELP_ANS_HDR))
    imgui.NextColumn()

    imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
    imgui.Separator()
    imgui.PopStyleColor()

    for _, row in ipairs(rows) do
        local dayCol = row.isToday and valCol or col_muted2
        local dateCol = row.isToday and valCol or col_muted2
        imgui.TextColored(dayCol, uiText(row.weekday))
        imgui.NextColumn()
        imgui.TextColored(dateCol, uiText(row.dateLabel))
        imgui.NextColumn()
        imgui.NextColumn()
        if row.onlineMin ~= nil then
            local onlineCol = row.normOk and ET_COL_OK or ET_COL_FAIL
            imgui.TextColored(onlineCol, uiText(etFormatMinutesAsRussianDuration(row.onlineMin)))
        else
            imgui.TextColored(col_muted2, uiText('\xB7'))
        end
        imgui.NextColumn()
        local ansCol = (row.ansCnt or 0) > 0 and valCol or col_muted2
        imgui.TextColored(ansCol, uiText(tostring(row.ansCnt or 0)))
        imgui.NextColumn()
    end

    imgui.PushStyleColor(imgui.Col.Separator, imgui.ImVec4(1.0, 1.0, 1.0, 0.08))
    imgui.Separator()
    imgui.PopStyleColor()

    imgui.TextColored(hdrCol, uiText(ET_HELP_TOTAL_LABEL))
    imgui.NextColumn()
    imgui.NextColumn()
    imgui.NextColumn()
    imgui.NextColumn()
    local ansTotalCol = weekAns > 0 and valCol or col_muted2
    imgui.TextColored(ansTotalCol, uiText(tostring(weekAns)))
    imgui.NextColumn()

    imgui.Columns(1)

    local offset = tonumber(etState.helpWeekOffset) or 0
    if offset > 0 then
        drawSettingsHint('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 \xED\xE0 \xE4\xE0\xF2\xF3 \xE8\xEB\xE8 \xF1\xF2\xF0\xE5\xEB\xEA\xF3 \xE2\xEF\xF0\xE0\xE2\xEE \xE4\xEB\xFF \xF2\xE5\xEA\xF3\xF9\xE5\xE9 \xED\xE5\xE4\xE5\xEB\xE8')
    end
end

local function etUpdateStoredDay(dateKey, minutes)
    if not dateKey or minutes == nil then return end
    minutes = math.max(0, math.floor(tonumber(minutes) or 0))
    etEnsureOnlinePeriods()
    local cutoffKey = os.date('%Y-%m-%d', os.time() - ET_ONLINE_RETAIN_DAYS * 86400)
    if dateKey < cutoffKey then return end
    local prev = etState.online.days[dateKey]
    if prev == nil or minutes > prev then
        etState.online.days[dateKey] = minutes
        pcall(etSaveOnlineStore)
    end
end

local function etSumCleanMinutes(filterFn)
    etEnsureOnlinePeriods()
    local total = 0
    for dateKey, mins in pairs(etState.online.days) do
        if filterFn(dateKey) then
            total = total + (tonumber(mins) or 0)
        end
    end
    return total
end

local function etGetTodayCleanMin()
    etEnsureOnlinePeriods()
    local todayKey = os.date('%Y-%m-%d')
    return tonumber(etState.online.days[todayKey]) or 0
end

local function etGetMonthlyCleanMin()
    local monthKey = etCurrentMonthKey()
    return etSumCleanMinutes(function(dateKey) return dateKey:sub(1, 7) == monthKey end)
end

local function etSyncOnlineHistory(serverDate, cleanToday, cleanYesterday)
    local todayKey = etParseServerDateKey(serverDate)
    etUpdateStoredDay(todayKey, cleanToday)
    if cleanYesterday ~= nil then
        local y, m, d = todayKey:match('(%d%d%d%d)%-(%d%d)%-(%d%d)')
        if y then
            local yesterdayKey = os.date('%Y-%m-%d', os.time({
                year = tonumber(y), month = tonumber(m), day = tonumber(d),
                hour = 12, min = 0, sec = 0,
            }) - 86400)
            etUpdateStoredDay(yesterdayKey, cleanYesterday)
        end
    end
end

local function etMigrateLegacyNorms()
    ensureExactTimeSettings()
    local f = io.open(ET_LEGACY_CONFIG, 'r')
    if not f then return end
    local changed = false
    for line in f:lines() do
        local weekH = line:match('^%s*week_norm_h%s*=%s*(%d+)')
        if weekH and tonumber(weekH) > 0 and (tonumber(settings.exact_time_daily_norm_h) or 4) == 4 then
            settings.exact_time_daily_norm_h = math.max(1, math.min(24, math.floor(tonumber(weekH) / 7)))
            changed = true
        end
        local monthH = line:match('^%s*month_norm_h%s*=%s*(%d+)')
        if monthH and tonumber(monthH) > 0 and (tonumber(settings.exact_time_monthly_norm_h) or 112) == 112 then
            settings.exact_time_monthly_norm_h = tonumber(monthH)
            changed = true
        end
    end
    f:close()
    if changed then markDirtySettings() end
end

local function etInstallWmHandler()
    if not deskWmDispatch or not deskWmDispatch.register then return end
    deskWmDispatch.unregister('exact_time')
    deskWmDispatch.register('exact_time', 88, function(msg, wparam, lparam)
        if not etState.showOpen then return false end
        local wm = deskCache and deskCache.wm
        if not wm then return false end
        msg = tonumber(msg) or 0
        wparam = tonumber(wparam) or 0
        if msg ~= wm.KEYDOWN and msg ~= wm.SYSKEYDOWN and msg ~= wm.KEYUP and msg ~= wm.SYSKEYUP then
            return false
        end
        local vkEsc = vkeys and vkeys.VK_ESCAPE
        local vkRet = (vkeys and vkeys.VK_RETURN) or 0x0D
        if wparam ~= vkEsc and wparam ~= vkRet then return false end
        if msg == wm.KEYDOWN or msg == wm.SYSKEYDOWN then
            consumeWindowMessage(true, false, true)
            return true
        end
        if etCloseWindow then etCloseWindow() end
        consumeWindowMessage(true, false, true)
        return true
    end)
end

function exactTimeInit()
    ensureExactTimeSettings()
    pcall(etMigrateLegacyNorms)
    pcall(etLoadOnlineStore)
    pcall(etLoadAnsStore)
    pcall(etLoadPunishStore)
    pcall(etBackfillAnsFromThreads)
    pcall(etInstallWmHandler)
end

function exactTimeWantsImguiInput()
    return etState.showOpen == true
end

function exactTimeShouldDraw()
    return etState.showOpen and etState.data.playToday ~= nil
end

function exactTimeNoteOutgoing(msg)
    if not etEnabled() then return end
    if type(msg) ~= 'string' then return end
    local s = trim(msg)
    if s:sub(1, 1) == '/' then s = trim(s:sub(2)) end
    local num = s:match('^[cC]%s*(%d+)$') or s:match('^[cC](%d+)$')
    if not num and s:match('^[cC]$') then num = '60' end
    if num and tonumber(num) == 60 then
        etState.pendingCmdAt = os.clock()
    end
end

function exactTimeOnShowDialog(dialogId, style, title, button1, button2, text)
    if not etEnabled() then return false end
    if etState.pendingCmdAt and (os.clock() - etState.pendingCmdAt) > EXACT_TIME_TIMEOUT then
        etState.pendingCmdAt = nil
    end
    if not etIsExactTimeDialog(title, text) then return false end
    etState.pendingCmdAt = nil

    local dialogRows = etParseDialogLines(text)
    local playToday = etExtractDurationAfterLabel(text, 'Время в игре сегодня')
        or etMinutesFromDialogRows(dialogRows, 'Время в игре сегодня', 'Онлайн сегодня')
    local afkToday = etExtractDurationAfterLabel(text, 'AFK за сегодня')
        or etExtractDurationAfterLabel(text, 'AFK сегодня')
        or etMinutesFromDialogRows(dialogRows, 'AFK за сегодня', 'AFK сегодня')
    if playToday == nil or afkToday == nil then
        if type(say) == 'function' then
            say('{FF6666}[Exact Time] {FFFFFF}\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEF\xF0\xEE\xF7\xE8\xF2\xE0\xF2\xFC \xE2\xF0\xE5\xEC\xFF.')
        end
        etSendDialogClose(dialogId, button1, button2)
        return true
    end

    local cleanMin = math.max(0, playToday - afkToday)
    local serverTime, serverDate = etParseServerClock(text, dialogRows)
    local playYday = etExtractDurationAfterLabel(text, 'Время в игре вчера')
        or etMinutesFromDialogRows(dialogRows, 'Время в игре вчера', 'Онлайн вчера')
    local afkYday = etExtractDurationAfterLabel(text, 'AFK за вчера')
        or etExtractDurationAfterLabel(text, 'AFK вчера')
        or etMinutesFromDialogRows(dialogRows, 'AFK за вчера', 'AFK вчера')
    local cleanYday = (playYday ~= nil and afkYday ~= nil) and math.max(0, playYday - afkYday) or nil

    pcall(function() etSyncOnlineHistory(serverDate, cleanMin, cleanYday) end)

    local d = etState.data
    d.playToday = playToday
    d.afkToday = afkToday
    d.cleanMin = cleanMin
    d.cleanMonthMin = etGetMonthlyCleanMin()
    d.dialogId = dialogId
    d.button1 = button1
    d.button2 = button2
    d.displayRows = etBuildDisplayList(text, dialogRows,
        etFormatMinutesAsRussianDuration(cleanMin),
        etFormatMinutesAsRussianDuration(playToday),
        etFormatMinutesAsRussianDuration(afkToday))
    local ch, cm, cs = etParseClockHms(serverTime)
    d._clockTick = nil
    d._clockStr = nil
    if ch then
        d.clockBase = { h = ch, m = cm, s = cs, at = os.clock() }
    else
        d.clockBase = nil
    end
    etState.showOpen = true
    if etShowWindowBuf then etShowWindowBuf[0] = true end
    etSetNativeDialogVisible(false)
    return true
end

local function etDrawAccentStrip()
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetWindowPos()
    dl:AddRectFilled(pos, imgui.ImVec2(pos.x + imgui.GetWindowWidth(), pos.y + 2), toU32(ET_COL.accent))
    imgui.Dummy(imgui.ImVec2(0, 6))
end

local function etCenterText(text, color, scale)
    scale = scale or 1.0
    if scale ~= 1.0 and imgui.SetWindowFontScale then imgui.SetWindowFontScale(scale) end
    local tw = imgui.CalcTextSize(text).x
    imgui.SetCursorPosX(math.max(imgui.GetStyle().WindowPadding.x, (imgui.GetWindowWidth() - tw) * 0.5))
    imgui.TextColored(color, text)
    if scale ~= 1.0 and imgui.SetWindowFontScale then imgui.SetWindowFontScale(1.0) end
end

local function etCenterLabelValue(labelCp1251, value, valueColor)
    valueColor = valueColor or ET_COL.accent
    local label = uiText(labelCp1251 .. ': ')
    local val = uiText(value)
    local tw = imgui.CalcTextSize(label).x + imgui.CalcTextSize(val).x
    imgui.SetCursorPosX(math.max(imgui.GetStyle().WindowPadding.x, (imgui.GetWindowWidth() - tw) * 0.5))
    imgui.TextColored(ET_COL.muted, label)
    imgui.SameLine(0, 0)
    imgui.TextColored(valueColor, val)
end

local function etDrawStatRows(rows, colId)
    if #rows == 0 then return end
    imgui.Columns(2, colId, false)
    imgui.SetColumnWidth(0, ET_LABEL_W)
    for i, row in ipairs(rows) do
        if row.value and row.value ~= '' then
            imgui.TextColored(ET_COL.muted, uiText(row.label))
            imgui.NextColumn()
            imgui.TextColored(ET_COL.value, uiText(row.value))
            imgui.NextColumn()
            if i < #rows then
                imgui.Dummy(imgui.ImVec2(0, ET_ROW_GAP))
                imgui.NextColumn()
                imgui.Dummy(imgui.ImVec2(0, ET_ROW_GAP))
                imgui.NextColumn()
            end
        end
    end
    imgui.Columns(1)
end

function drawExactTimeWindow()
    if not exactTimeShouldDraw() then return end
    etSetNativeDialogVisible(false)

    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    if sw < 100 then sw = 1920 end
    if sh < 100 then sh = 1080 end
    imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh * 0.5), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(ET_WIN_W, 0), imgui.ImVec2(ET_WIN_W, 9999))

    local winFlags = imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoScrollbar
    etPushWindowStyle()
    if not etShowWindowBuf then
        etShowWindowBuf = imgui.new.bool(etState.showOpen)
    end
    if not imgui.Begin(uiText(L_TITLE) .. '###desk_exact_time', etShowWindowBuf, winFlags) then
        etPopWindowStyle()
        imgui.End()
        if etState.showOpen then etCloseWindow() end
        return
    end

    etDrawAccentStrip()
    local d = etState.data
    local timeRow, cleanRow = nil, nil
    local dateParts, todayRows, yesterdayRows = {}, {}, {}
    if d.displayRows then
        for _, row in ipairs(d.displayRows) do
            if row.kind == 'time' then timeRow = row
            elseif row.kind == 'accent' then cleanRow = row
            elseif row.kind == 'date' then dateParts[#dateParts + 1] = row.value
            elseif row.kind == 'today' then todayRows[#todayRows + 1] = row
            elseif row.kind == 'yesterday' then yesterdayRows[#yesterdayRows + 1] = row
            end
        end
    end

    if #dateParts > 0 then
        local dateLine = etFormatDateLine(dateParts)
        if dateLine then
            etCenterText(uiText(dateLine), ET_COL.muted, 0.92)
            imgui.Dummy(imgui.ImVec2(0, 6))
        end
    end

    if timeRow and timeRow.value ~= '' then
        etCenterText(uiText(etLiveClockValue(timeRow.value)), ET_COL.time, 1.42)
        imgui.Dummy(imgui.ImVec2(0, 4))
    end

    if cleanRow and cleanRow.value ~= '' then
        etCenterLabelValue(L_ET_CLEAN, cleanRow.value)
        imgui.Dummy(imgui.ImVec2(0, 6))
        etDrawActivityBar(d.cleanMin, etDailyNormMin(), ET_COL.accent)
    end

    if d.cleanMonthMin ~= nil then
        etCenterLabelValue(L_ET_CLEAN_MONTH, etFormatMinutesAsRussianDuration(d.cleanMonthMin), ET_MONTHLY_COLOR)
        imgui.Dummy(imgui.ImVec2(0, 6))
        etDrawActivityBar(d.cleanMonthMin, etMonthlyNormMin(), ET_MONTHLY_COLOR)
    end

    if #todayRows > 0 or #yesterdayRows > 0 then
        imgui.PushStyleColor(imgui.Col.Separator, ET_LINE)
        imgui.Separator()
        imgui.PopStyleColor()
        imgui.Dummy(imgui.ImVec2(0, 6))
    end

    if #todayRows > 0 then etDrawStatRows(todayRows, '##et_today') end
    if #todayRows > 0 and #yesterdayRows > 0 then
        imgui.Dummy(imgui.ImVec2(0, 10))
        imgui.PushStyleColor(imgui.Col.Separator, ET_LINE)
        imgui.Separator()
        imgui.PopStyleColor()
        imgui.Dummy(imgui.ImVec2(0, 8))
    end
    if #yesterdayRows > 0 then etDrawStatRows(yesterdayRows, '##et_yday') end

    imgui.Dummy(imgui.ImVec2(0, 4))
    if imgui.Button(uiText(L_CLOSE) .. '##et_close', imgui.ImVec2(-1, 32)) then
        etCloseWindow()
    end

    imgui.End()
    etPopWindowStyle()

    if etShowWindowBuf and not etShowWindowBuf[0] and etState.showOpen then
        etCloseWindow()
    end
end

function syncExactTimeUiFromSettings()
    ensureExactTimeSettings()
    if uiExactTimeEnabled then uiExactTimeEnabled[0] = settings.exact_time_enabled ~= false end
    if uiExactTimeDailyH then uiExactTimeDailyH[0] = math.floor(tonumber(settings.exact_time_daily_norm_h) or 4) end
    if uiExactTimeMonthlyH then uiExactTimeMonthlyH[0] = math.floor(tonumber(settings.exact_time_monthly_norm_h) or 112) end
end

function drawExactTimeTab()
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
    drawSettingsCardHeader('\xCD\xEE\xF0\xEC\xFB \xEE\xED\xEB\xE0\xE9\xED\xE0', '')
    if uiExactTimeDailyH and drawSettingsInputInt then
        drawSettingsInputInt('\xC4\xE5\xED\xFC', uiExactTimeDailyH, 'et_day', 1, 24, function(v)
            settings.exact_time_daily_norm_h = v
            markDirtySettings()
        end, '\xF7')
    end
    if uiExactTimeMonthlyH and drawSettingsInputInt then
        drawSettingsInputInt('\xCC\xE5\xF1\xFF\xF6', uiExactTimeMonthlyH, 'et_month', 1, 744, function(v)
            settings.exact_time_monthly_norm_h = v
            markDirtySettings()
        end, '\xF7')
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##help_stats')
    drawSettingsCardHeader('\xD1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xE0',
        '\xD1\xE2\xEE\xE4\xED\xE0\xFF \xF2\xE0\xE1\xEB\xE8\xF6\xE0 \xEF\xEE \xE2\xE0\xF8\xE5\xEC\xF3 \xEE\xED\xEB\xE0\xE9\xED\xF3 \xE8 \xE0\xEA\xF2\xE8\xE2\xED\xEE\xF1\xF2\xE8 \xE2 \xF0\xE5\xEF\xEE\xF0\xF2')
    etDrawHelpWeekTable()
    deskFormPanelEnd()

    deskFormPanelBegin('##help_punish')
    drawSettingsCardHeader('\xC2\xFB\xE4\xE0\xED\xED\xFB\xE5 \xED\xE0\xEA\xE0\xE7\xE0\xED\xE8\xFF',
        '\xCB\xEE\xE3\x20\xED\xE0\xEA\xE0\xE7\xE0\xED\xE8\xE9\x2C\x20\xEA\xEE\xF2\xEE\xF0\xFB\xE5\x20\xE2\xFB\x20\xE2\xFB\xE4\xE0\xE2\xE0\xEB\xE8\x2E')
    etDrawHelpPunishLog()
    deskFormPanelEnd()

    imgui.PopStyleVar(2)
    imgui.Dummy(imgui.ImVec2(0, 12))
    imgui.EndChild()
    popPanelStyle()
end
