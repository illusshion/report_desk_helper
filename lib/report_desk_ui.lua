--[[ Модуль: ImGui окно Report Desk (список, чат, настройки). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

-- Draw Settings Card End
function drawSettingsCardEnd()
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Draw Settings Card Header
function drawSettingsCardHeader(title, desc)
    deskFormSection(title)
    if desc and desc ~= '' then
        drawSettingsHint(desc)
    end
end

-- Draw Settings Hint
function drawSettingsHint(text)
    if not text or text == '' then return end
    imgui.PushTextWrapPos(imgui.GetCursorPosX() + math.max(120, imgui.GetContentRegionAvail().x))
    imgui.TextColored(col_muted2, uiText(text))
    imgui.PopTextWrapPos()
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Draw Settings Subsection
function drawSettingsSubsection(title)
    imgui.Dummy(imgui.ImVec2(0, 8))
    imgui.TextColored(col_muted2, uiText(title))
    imgui.Dummy(imgui.ImVec2(0, 6))
end

-- Draw Settings Hotkey Bind
function drawSettingsHotkeyBind()
    local hkPreview = deskCache.hotkeyCapture and cheatLiveBindPreview() or vkToLabel(settings.hotkey or vkeys.VK_F7)
    drawDeskBindRow({
        label = '\xCE\xF2\xEA\xF0\xFB\xF2\xFC \xEC\xE5\xED\xFE',
        inline = false,
        previewText = hkPreview,
        idleText = 'F7, M4, M5...',
        capturing = deskCache.hotkeyCapture,
        keyCapId = '##hk_cap',
        onCapture = beginHotkeyCapture,
        onClear = function()
            settings.hotkey = vkeys.VK_F7
            markDirtySettings()
        end,
    })
end

function deskLocalAdminRoleLineWidth(parts)
    if not parts then return 0 end
    local w = 0
    if parts.name and parts.name ~= '' then
        w = w + imgui.CalcTextSize(uiText(parts.name)).x
        w = w + imgui.CalcTextSize(uiText(' | ')).x
    end
    if parts.role and parts.role ~= '' then
        w = w + imgui.CalcTextSize(uiText(parts.role)).x
    end
    return w
end

function drawDeskAdminRoleBadgeLine(parts, alignRight)
    if not parts then return end
    local textCol = col_muted2 or col_label
    local sepCol = col_muted or imgui.ImVec4(0.45, 0.42, 0.52, 0.75)
    local tint = parts.tint or col_accent
    if alignRight then
        local tw = deskLocalAdminRoleLineWidth(parts)
        local availW = imgui.GetContentRegionAvail().x
        if availW > tw + 2 then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + availW - tw)
        end
    end
    imgui.BeginGroup()
    if parts.name and parts.name ~= '' then
        imgui.TextColored(tint, uiText(parts.name))
        imgui.SameLine(0, 0)
        imgui.TextColored(sepCol, uiText(' | '))
        imgui.SameLine(0, 0)
    end
    if parts.role and parts.role ~= '' then
        imgui.TextColored(textCol, uiText(parts.role))
    end
    imgui.EndGroup()
end

function drawDeskAdminRoleBadgeFooter(h)
    h = tonumber(h) or 28
    if type(deskRefreshLocalAdminLevel) == 'function' then
        pcall(deskRefreshLocalAdminLevel)
    end
    if type(deskLocalAdminRoleParts) ~= 'function' then return end
    local parts = deskLocalAdminRoleParts()
    if not parts then return end

    local crMin = imgui.GetWindowContentRegionMin()
    local crMax = imgui.GetWindowContentRegionMax()
    local y = crMax.y - h
    if y < crMin.y then y = crMin.y end

    local wp = imgui.GetWindowPos()
    local x0 = wp.x + crMin.x
    local x1 = wp.x + crMax.x
    local y0 = wp.y + y
    local y1 = wp.y + crMax.y

    local dl = imgui.GetWindowDrawList()
    if dl and dl.AddRectFilled and type(toU32) == 'function' then
        dl:AddRectFilled(
            imgui.ImVec2(x0, y0),
            imgui.ImVec2(x1, y1),
            toU32(imgui.ImVec4(0.08, 0.07, 0.11, 0.55)))
        if dl.AddLine then
            dl:AddLine(
                imgui.ImVec2(x0, y0),
                imgui.ImVec2(x1, y0),
                toU32(imgui.ImVec4(1, 1, 1, 0.05)),
                1.0)
        end
    end

    local lh = imgui.GetTextLineHeight and imgui.GetTextLineHeight() or 14
    imgui.SetCursorPos(imgui.ImVec2(crMin.x + 14, y + math.max(0, (h - lh) * 0.5)))
    drawDeskAdminRoleBadgeLine(parts, false)
end

function deskAdminFooterHeight()
    if type(deskLocalAdminLevelKnown) == 'function' and deskLocalAdminLevelKnown() then
        return 28
    end
    return 0
end

-- Desk hook/helper.
function deskPushFlatInputStyle()
    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.12, 0.12, 0.15, 1))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.22, 0.20, 0.28, 0.35))
    if imgui.StyleVar and imgui.StyleVar.FrameBorderSize then
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 0)
    end
end

-- Desk hook/helper.
function deskPopFlatInputStyle()
    if imgui.StyleVar and imgui.StyleVar.FrameBorderSize then
        imgui.PopStyleVar()
    end
    imgui.PopStyleColor(2)
end

-- Draw Settings Slider Int
function drawSettingsSliderInt(label, var, id, vmin, vmax, onApply)
    local rowW = deskFormRowAvail(label, DESK_FORM_LABEL_W)
    imgui.PushItemWidth(rowW)
    deskPushFlatInputStyle()
    if imgui.SliderInt('##' .. id, var, vmin, vmax, '%d') then
        if onApply then onApply(var[0]) end
    end
    deskPopFlatInputStyle()
    imgui.PopItemWidth()
end

-- Draw Settings Input Int
function drawSettingsInputInt(label, var, id, vmin, vmax, onApply, suffix)
    local suffixW = 0
    if suffix and suffix ~= '' then
        suffixW = imgui.CalcTextSize(uiText(suffix)).x + 14
    end
    local rowW = deskFormRowAvail(label, DESK_FORM_LABEL_W)
    local inputW = math.max(84, math.min(112, rowW - suffixW - 4))
    imgui.PushItemWidth(inputW)
    deskPushFlatInputStyle()
    if imgui.InputInt('##' .. id, var) then
        var[0] = math.max(vmin, math.min(vmax, var[0]))
        if onApply then onApply(var[0]) end
    end
    deskPopFlatInputStyle()
    imgui.PopItemWidth()
    if suffix and suffix ~= '' then
        imgui.SameLine(0, 8)
        if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
        imgui.TextColored(col_muted2, uiText(suffix))
    end
end

-- Draw Desk Search Clear Row
function drawDeskSearchClearRow(inputLabel, filterBuf, filterBufSize, onChanged, idSuffix)
    local clrText = uiText('\xCE\xF7\xE8\xF1\xF2\xE8\xF2\xFC')
    local clrW = math.max(78, imgui.CalcTextSize(clrText).x + 18)
    imgui.PushItemWidth(math.max(60, imgui.GetContentRegionAvail().x - clrW - 8))
    deskPushFlatInputStyle()
    local changed = false
    if imgui.InputTextWithHint then
        changed = imgui.InputTextWithHint('##flt' .. idSuffix, uiText(inputLabel), filterBuf, filterBufSize)
    else
        changed = imgui.InputText('##flt' .. idSuffix, filterBuf, filterBufSize)
    end
    deskPopFlatInputStyle()
    imgui.PopItemWidth()
    imgui.SameLine(0, 8)
    if imgui.Button(clrText .. '##clr' .. idSuffix, imgui.ImVec2(clrW, DESK_FORM_ROW_H)) then
        ffi.fill(filterBuf, filterBufSize)
        if onChanged then onChanged() end
    elseif changed and onChanged then
        onChanged()
    end
end

-- Draw Avatar
function drawAvatar(dl, cx, cy, radius, letter, col)
    dl:AddCircleFilled(imgui.ImVec2(cx, cy), radius, toU32(col or col_accent_dim))
    local ch = uiText(letter or '?')
    local ts = imgui.CalcTextSize(ch)
    dl:AddText(
        imgui.ImVec2(cx - ts.x * 0.5, cy - ts.y * 0.5),
        toU32(col_label),
        ch
    )
end

-- Utf8 Next Codepoint
local function utf8Next(s, i)
    if i > #s then return nil end
    local b = s:byte(i)
    if not b or b < 0x80 then return i + 1 end
    if b < 0xE0 then return i + 2 end
    if b < 0xF0 then return i + 3 end
    return i + 4
end

-- Utf8 Char Count
local function utf8CharCount(s)
    local n, i = 0, 1
    while i <= #s do
        n = n + 1
        i = utf8Next(s, i) or (#s + 1)
    end
    return n
end

-- Utf8 Sub Chars
local function utf8SubChars(s, maxChars)
    local i, count = 1, 0
    while i <= #s and count < maxChars do
        i = utf8Next(s, i) or (#s + 1)
        count = count + 1
    end
    return s:sub(1, i - 1)
end

-- Ellipsize To Width
function ellipsizeToWidth(text, maxW)
    local display = uiText(text or '')
    if display == '' or maxW < 12 then return '' end
    maxW = tonumber(maxW) or 0
    local cacheKey = display .. '|' .. tostring(math.floor(maxW))
    local cached = ellipsizeCacheGet(cacheKey)
    if cached then return cached end

    local fullW = imgui.CalcTextSize(display).x
    if fullW <= maxW then
        ellipsizeCachePut(cacheKey, display)
        return display
    end

    local ell = uiText('...')
    local ellW = imgui.CalcTextSize(ell).x
    local budget = maxW - ellW
    if budget < 8 then
        ellipsizeCachePut(cacheKey, ell)
        return ell
    end

    local total = utf8CharCount(display)
    if total < 1 then
        ellipsizeCachePut(cacheKey, ell)
        return ell
    end

    local lo, hi, best = 1, total, 0
    while lo <= hi do
        local mid = math.floor((lo + hi) * 0.5)
        local part = utf8SubChars(display, mid)
        if imgui.CalcTextSize(part).x <= budget then
            best = mid
            lo = mid + 1
        else
            hi = mid - 1
        end
    end

    local result = best > 0 and (utf8SubChars(display, best) .. ell) or ell
    ellipsizeCachePut(cacheKey, result)
    return result
end

-- Draw Unread Badge
function drawUnreadBadge(dl, xRight, centerY, count)
    if not count or count < 1 then return end
    local label = count > 99 and '99+' or tostring(count)
    local ts = imgui.CalcTextSize(label)
    local padX, padY = 3, 1
    local w = ts.x + padX * 2
    local h = ts.y + padY * 2
    local x0 = xRight - w
    local y0 = centerY - h * 0.5
    dl:AddRectFilled(imgui.ImVec2(x0, y0), imgui.ImVec2(x0 + w, y0 + h), toU32(col_unread), h * 0.5)
    dl:AddText(imgui.ImVec2(x0 + padX, y0 + padY), toU32(col_label), label)
end

-- Draw Date Separator
function drawDateSeparator(fullW, ts)
    local label = formatDateSeparator(ts)
    if label == '' then return end
    local dl = imgui.GetWindowDrawList()
    local localX = imgui.GetCursorPosX()
    local localY = imgui.GetCursorPosY()
    local rowW = math.max(80, imgui.GetContentRegionAvail().x)
    local pos = imgui.GetCursorScreenPos()
    local tsz = imgui.CalcTextSize(label)
    local blockH = tsz.y + 20
    local y = pos.y + 8
    local cx = pos.x + rowW * 0.5
    local lineCol = toU32(imgui.ImVec4(0.25, 0.25, 0.30, 0.8))
    finishChatMessageRow(localX, localY, blockH, rowW)
    dl:AddLine(imgui.ImVec2(pos.x + 8, y + tsz.y * 0.5), imgui.ImVec2(cx - tsz.x * 0.5 - 8, y + tsz.y * 0.5), lineCol)
    dl:AddLine(imgui.ImVec2(cx + tsz.x * 0.5 + 8, y + tsz.y * 0.5), imgui.ImVec2(pos.x + rowW - 8, y + tsz.y * 0.5), lineCol)
    dl:AddText(imgui.ImVec2(cx - tsz.x * 0.5, y), toU32(col_muted2), label)
    sealChatMessageRow(localX, localY, blockH)
end

-- Draw Bubble Message
function drawBubbleMessage(m, fullW, msgIdx, reporter, opts)
    if not m or fullW < 80 then return end
    opts = opts or {}
    local showAuthor = opts.showAuthor ~= false
    local compactSpacing = opts.compactSpacing == true

    local dl = imgui.GetWindowDrawList()
    local localX = imgui.GetCursorPosX()
    local localY = imgui.GetCursorPosY()
    local rowW = math.max(80, imgui.GetContentRegionAvail().x)
    local pos = imgui.GetCursorScreenPos()
    local padSide = BUBBLE_SIDE
    local maxInner = math.floor(rowW * BUBBLE_MAX_FRAC)
    if maxInner < 100 then maxInner = 100 end

    local dir = messageDisplayDir(m)
    local kind = messageKind(m)
    local line, bg, fg, alignRight, sub, subCol
    local actionInline = false
    local punishCard = false

    if dir == 'event' then
        alignRight = false
        if kind == 'punish' then
            punishCard = true
            local tgt = reporter and trim(reporter.nick or '') or ''
            line = trim(m.displayText or '')
            if line == '' and m.adminNick then
                line = deskIngest.formatPunishmentDisplay(
                    m.adminNick, tgt, m.rawText or m.text or '')
            end
            if line == '' then line = trim(m.text or '') end
            maxInner = math.floor(rowW * 0.88)
            bg = col_bubble_punish
            fg = col_label
            sub = '\xCD\xE0\xEA\xE0\xE7\xE0\xED\xE8\xE5'
            subCol = col_punish_label
        else
            actionInline = true
            line = actionLineForChat(m, reporter)
            fg = col_muted2
            sub = nil
            subCol = nil
            maxInner = math.max(120, rowW - padSide * 2 - 8)
        end
    elseif dir == 'system' then
        line = m.note or ''
        bg = col_bubble_sys
        fg = col_muted
        sub = 'auto'
        subCol = col_muted2
        maxInner = math.floor(rowW * 0.82)
        alignRight = false
    elseif dir == 'out' then
        line = m.text or ''
        alignRight = true
        if m.self then
            bg = col_bubble_self
            fg = col_label
            sub = '\xC2\xFB'
            subCol = imgui.ImVec4(0.55, 0.90, 0.65, 1.0)
        else
            bg = col_bubble_other
            fg = col_label
            sub = '\xC0\xE4\xEC\xE8\xED: ' .. (m.adminNick or '?')
            subCol = col_admin_label
        end
    else
        line = m.text or ''
        bg = col_bubble_in
        fg = col_label
        local repNick = reporter and trim(reporter.nick or '') or ''
        sub = repNick ~= '' and repNick or '\xC8\xE3\xF0\xEE\xEA'
        subCol = imgui.ImVec4(0.55, 0.70, 0.95, 1.0)
        alignRight = false
    end

    -- clist репортёра только для его входящих сообщений; «Вы» и админ — свои цвета
    if opts.nickCol and dir == 'in' then
        subCol = opts.nickCol
    end
    if opts.profanityHighlight then
        bg = col_bubble_punish
    end

    local profanityHighlight = opts.profanityHighlight == true
    local scenarioBody = ''
    local quickBtns = {}
    local corpusCandidate = false
    local corpusOpts = nil
    if reporter and messageShowsScenarioButtons(m) then
        scenarioBody = messageBodyForScenarios(m)
        if scenarioBody == '' then scenarioBody = line end
        local sig = tostring(intentsGen) .. '|' .. tostring(#deskIntents)
        if m._intentQuickSig ~= sig or type(m._intentQuickBtns) ~= 'table' then
            m._intentQuickBtns = collectQuickButtonsForMessage(scenarioBody)
            m._intentQuickSig = sig
        end
        quickBtns = m._intentQuickBtns
    end
    local showReplyBtns = opts.noQuickButtons ~= true
    local watchBtns, replyBtns = splitQuickButtons(quickBtns)
    if reporter and scenarioBody ~= '' then
        prepareQuickButtonWidths(quickBtns, reporter, scenarioBody)
    end
    if not showReplyBtns then replyBtns = {} end
    if dir == 'in' and reporter and messageShowsScenarioButtons(m)
            and intentMessageCorpusEligible(scenarioBody) then
        corpusCandidate = true
        corpusOpts = {
            matched = intentCorpusMatchedFromQuickBtns(quickBtns),
            context = quickBtns[1] and quickBtns[1].context or nil,
        }
    end
    local watchInlineW = quickButtonsInlineWidth(watchBtns)
    local corpusInlineW = corpusCandidate and (intentCorpusBtnWidth(scenarioBody) + 8) or 0
    local btnAreaW = math.max(80, rowW - padSide * 2)
    local replyBtnRows, replyBtnBlockH = layoutQuickButtonRows(replyBtns, btnAreaW)

    if not showAuthor then
        sub = nil
        subCol = nil
    end

    if actionInline then
        local wrapInner = maxInner
        local x0 = pos.x + padSide
        local topPad = compactSpacing and 2 or BUBBLE_SUB_GAP
        local rowY = pos.y + topPad
        local gapAfter = compactSpacing and BUBBLE_GAP_GROUPED or BUBBLE_GAP
        local timeDisp = uiText(formatTimeShort(m.ts))
        local timeSz = imgui.CalcTextSize(timeDisp)
        local _, textH = measureBubbleText(line, wrapInner, m)
        local timeY = rowY + textH + CHAT_TIME_GAP
        local blockH = topPad + textH + CHAT_TIME_GAP + timeSz.y + CHAT_TIME_PAD + gapAfter

        finishChatMessageRow(localX, localY, blockH, rowW)
        drawBubbleBodyText(dl, x0, rowY, wrapInner, line, fg, m)
        dl:AddText(imgui.ImVec2(x0, timeY), toU32(col_muted2), timeDisp)
        sealChatMessageRow(localX, localY, blockH)
        return
    end

    local subDisp = sub and uiText(sub) or ''
    local subSz = subDisp ~= '' and imgui.CalcTextSize(subDisp) or imgui.ImVec2(0, 0)
    local maxBubbleW = math.max(64, rowW - padSide * 2 - watchInlineW - corpusInlineW)
    local wrapInner = math.min(maxInner, math.max(48, maxBubbleW - BUBBLE_PAD_X * 2))
    local estW, estH = measureBubbleText(line, wrapInner, m)
    local padY = compactSpacing and BUBBLE_PAD_Y_GROUPED or BUBBLE_PAD_Y
    local bubbleW = math.max(64, math.min(maxBubbleW, estW + BUBBLE_PAD_X * 2))
    local textH = estH
    local bubbleH = textH + padY * 2

    local timeDispPre = uiText(formatTimeShort(m.ts))
    local timeSzPre = imgui.CalcTextSize(timeDispPre)
    local gapAfter = punishCard and 8 or (compactSpacing and BUBBLE_GAP_GROUPED or BUBBLE_GAP)
    local topPad = compactSpacing and 2 or BUBBLE_SUB_GAP
    local authorH = 0
    if subDisp ~= '' then
        authorH = subSz.y + BUBBLE_SUB_GAP
    end
    local timeBlockH = timeSzPre.y + CHAT_TIME_PAD
    local blockH = topPad + authorH + bubbleH + CHAT_TIME_GAP + timeBlockH + replyBtnBlockH + gapAfter

    local x0 = pos.x + padSide
    if dir == 'system' then
        x0 = pos.x + math.max(padSide, (rowW - bubbleW) * 0.5)
    elseif alignRight then
        x0 = pos.x + rowW - bubbleW - padSide
    end

    local bubbleY = pos.y + topPad + authorH
    local bMin = imgui.ImVec2(x0, bubbleY)
    local bMax = imgui.ImVec2(x0 + bubbleW, bubbleY + bubbleH)
    local textX = x0 + BUBBLE_PAD_X
    local textY = bubbleY + padY
    local timeY = bMax.y + CHAT_TIME_GAP
    local timeX = alignRight and (bMax.x - timeSzPre.x) or x0

    finishChatMessageRow(localX, localY, blockH, rowW)

    if subDisp ~= '' then
        local subX = alignRight and (x0 + bubbleW - subSz.x) or x0
        dl:AddText(imgui.ImVec2(subX, pos.y + topPad), toU32(subCol), subDisp)
    end

    dl:AddRectFilled(bMin, bMax, toU32(bg), BUBBLE_RADIUS)
    if punishCard then
        dl:AddRect(bMin, bMax, toU32(imgui.ImVec4(0.55, 0.22, 0.22, 0.5)), BUBBLE_RADIUS, 0, 1.0)
    elseif profanityHighlight then
        dl:AddRect(bMin, bMax, toU32(imgui.ImVec4(0.72, 0.38, 0.42, 0.55)), BUBBLE_RADIUS, 0, 1.0)
    end

    drawBubbleBodyText(dl, textX, textY, wrapInner, line, fg, m)
    dl:AddText(imgui.ImVec2(timeX, timeY), toU32(col_muted2), timeDispPre)

    if not alignRight then
        local inlineBtnY = localY + topPad + authorH + math.max(0, (bubbleH - QUICK_BTN_H) * 0.5)
        local inlineBtnX = localX + padSide + bubbleW + 8
        if #watchBtns > 0 then
            drawInlineWatchButtons(watchBtns, localX, localY, inlineBtnX, inlineBtnY, scenarioBody, reporter, msgIdx)
            inlineBtnX = inlineBtnX + math.max(0, watchInlineW - 8)
        end
        if corpusCandidate then
            local corpusBtnY = localY + topPad + authorH + math.max(0, (bubbleH - INTENT_CORPUS_BTN_H) * 0.5)
            drawIntentCorpusQueueButton(scenarioBody, reporter, msgIdx, inlineBtnX, corpusBtnY, corpusOpts)
        end
    end

    if #replyBtnRows > 0 then
        local btnRowY = topPad + authorH + bubbleH + CHAT_TIME_GAP + timeBlockH + QUICK_BTN_BLOCK_TOP
        drawQuickScenarioButtons(replyBtns, localX, localY, btnRowY, rowW, padSide, scenarioBody, reporter, msgIdx)
    end

    sealChatMessageRow(localX, localY, blockH)
end

-- Chat Header Player State
local function chatHeaderResolvePlayer(t)
    local nick = trim(t and t.nick or '')
    local liveId = nick ~= '' and findPlayerIdByNick(nick) or nil
    if liveId ~= nil then
        if t.id ~= liveId then
            t.lastId = t.id
            t.id = liveId
            markDirtyThreads()
        end
        if t.stale then
            t.stale = nil
            markDirtyThreads()
        end
        return liveId, true
    end
    return tonumber(t.id) or -1, false
end

-- Chat Header Nick Color
function chatHeaderNickColor(pid, online)
    pid = tonumber(pid) or -1
    if online and pid >= 0 then
        if type(sampGetPlayerColor) == 'function' and sampIsPlayerConnected
                and sampIsPlayerConnected(pid) then
            local ok, raw = pcall(sampGetPlayerColor, pid)
            if ok and raw and type(sampColorToImVec4) == 'function' then
                local c = sampColorToImVec4(raw)
                if c then return c end
            end
        end
        if type(sampPlayerColorChatHex) == 'function' then
            local hex = sampPlayerColorChatHex(pid)
            if hex and hex ~= '' and type(chatHexToImVec4) == 'function' then
                local c = chatHexToImVec4(hex)
                if c then return c end
            end
        end
    end
    return col_player_nick_offline or imgui.ImVec4(0.82, 0.42, 0.42, 1.0)
end

-- Report Channel Chip Style
local function reportChannelChipStyle(tag)
    if tag == 'PC' then
        return {
            label = '\xCB\xE0\xF3\xED\xF7\xE5\xF0',
            tip = '\xCB\xE0\xF3\xED\xF7\xE5\xF0 ARP',
            accent = imgui.ImVec4(0.74, 0.56, 0.98, 0.90),
        }
    end
    if tag == 'S' then
        return {
            label = 'SA-MP',
            tip = '\xCA\xEB\xE8\xE5\xED\xF2 SA-MP',
            accent = imgui.ImVec4(0.56, 0.74, 0.96, 0.90),
        }
    end
    if tag == 'M' then
        return {
            label = '\xCC\xEE\xE1\xE0\xE9\xEB',
            tip = '\xCC\xEE\xE1\xE8\xEB\xFC\xED\xEE\xE5 \xEF\xF0\xE8\xEB\xEE\xE6\xE5\xED\xE8\xE5',
            accent = imgui.ImVec4(0.50, 0.84, 0.66, 0.90),
        }
    end
    return nil
end

-- Draw Report Channel Chip
function drawReportChannelChip(channelTag, online)
    channelTag = deskIngest.normalizeReportChannel(channelTag)
    if not channelTag then return end
    local style = reportChannelChipStyle(channelTag)
    if not style then return end
    local sepCol = imgui.ImVec4(col_muted2.x, col_muted2.y, col_muted2.z, 0.50)
    imgui.TextColored(sepCol, uiText(' \xB7 '))
    imgui.SameLine(0, 2)
    local alpha = online == false and 0.52 or 1.0
    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.TextColored(style.accent, uiText(style.label))
    if imgui.IsItemHovered() and imgui.SetTooltip and style.tip then
        imgui.SetTooltip(uiText(style.tip))
    end
    imgui.PopStyleVar()
end

-- Draw Chat Header Spectate Btn
function drawChatHeaderSpectateBtn(pid, online)
    pid = tonumber(pid) or -1
    if pid < 0 then return end
    local specLbl = '\xD1\xEB\xE5\xE4\xE8\xF2\xFC'
    local btnH = 28
    local btnW = math.max(80, headerActionBtnWidth(specLbl))
    local canSpec = online == true
    if not canSpec then
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.42)
    end
    if type(pushPlayerActionBtnStyle) == 'function' then pushPlayerActionBtnStyle() end
    if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
    local clicked = false
    if canSpec then
        clicked = imgui.Button(uiText(specLbl) .. '##hdr_sp', imgui.ImVec2(btnW, btnH))
    else
        imgui.Button(uiText(specLbl) .. '##hdr_sp_off', imgui.ImVec2(btnW, btnH))
    end
    if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end
    if imgui.IsItemHovered() and imgui.SetTooltip then
        if canSpec then
            imgui.SetTooltip(uiText('/sp ' .. pid))
        else
            imgui.SetTooltip(uiText('\xC8\xE3\xF0\xEE\xEA \xED\xE5 \xE2 \xF1\xE5\xF2\xE8'))
        end
    end
    if canSpec and clicked then
        sendGameCmd('sp ' .. pid)
    end
    if type(popPlayerActionBtnStyle) == 'function' then popPlayerActionBtnStyle() end
    if not canSpec then
        imgui.PopStyleVar()
    end
end

-- Draw Chat Header
function drawChatHeader(t)
    local pid, online = chatHeaderResolvePlayer(t)
    local nickCol = chatHeaderNickColor(pid, online, t.nick)

    local padR = 12
    local textX = 22
    local lineH = imgui.GetTextLineHeight()
    local specBtnH = 28
    local specLbl = '\xD1\xEB\xE5\xE4\xE8\xF2\xFC'
    local specBtnW = pid >= 0 and math.max(80, headerActionBtnWidth(specLbl)) or 0

    imgui.PushStyleColor(imgui.Col.ChildBg, col_header)
    imgui.BeginChild('##chat_hdr', imgui.ImVec2(-1, CHAT_HEADER_H), false)

    local dl = imgui.GetWindowDrawList()
    if dl and type(toU32) == 'function' then
        local crMin = imgui.GetWindowContentRegionMin()
        local crMax = imgui.GetWindowContentRegionMax()
        local wp = imgui.GetWindowPos()
        local x0 = wp.x + crMin.x
        local y0 = wp.y + crMin.y
        local y1 = wp.y + crMax.y
        local stripeCol = online and nickCol or imgui.ImVec4(0.62, 0.34, 0.34, 0.85)
        dl:AddRectFilled(
            imgui.ImVec2(x0 + 8, y0 + 10),
            imgui.ImVec2(x0 + 8 + 3, y1 - 10),
            toU32(stripeCol),
            2)
    end

    local rowY = math.floor((CHAT_HEADER_H - lineH) * 0.5 + 0.5)
    local btnY = math.floor((CHAT_HEADER_H - specBtnH) * 0.5 + 0.5)
    imgui.SetCursorPos(imgui.ImVec2(textX, rowY))
    imgui.TextColored(nickCol, uiText(t.nick or '?'))
    imgui.SameLine(0, 6)
    imgui.TextColored(col_muted2, uiText('[' .. tostring(pid >= 0 and pid or '?') .. ']'))

    local reportChannel = resolveThreadReportChannel(t)
    if reportChannel then
        imgui.SameLine(0, 0)
        drawReportChannelChip(reportChannel, online)
    end
    if not online then
        imgui.SameLine(0, 8)
        imgui.TextColored(imgui.ImVec4(0.72, 0.42, 0.42, 0.82), uiText('\xED\xE5 \xE2 \xF1\xE5\xF2\xE8'))
    end

    if specBtnW > 0 then
        local rmax = imgui.GetWindowContentRegionMax()
        imgui.SetCursorPos(imgui.ImVec2(rmax.x - padR - specBtnW, btnY))
        drawChatHeaderSpectateBtn(pid, online)
    end

    if dl and dl.AddLine and type(toU32) == 'function' then
        local crMin = imgui.GetWindowContentRegionMin()
        local crMax = imgui.GetWindowContentRegionMax()
        local wp = imgui.GetWindowPos()
        local x0 = wp.x + crMin.x + 12
        local x1 = wp.x + crMax.x - 12
        local y = wp.y + crMax.y - 0.5
        local sepCol = col_header_sep or imgui.ImVec4(0.36, 0.36, 0.42, 0.50)
        dl:AddLine(imgui.ImVec2(x0, y), imgui.ImVec2(x1, y), toU32(sepCol), 1.0)
    end

    imgui.EndChild()
    imgui.PopStyleColor()
end

-- Отправка команды/сообщения на сервер.
function sendComposerQuickButton(btn)
    if not btn or not btn.text then return false end
    local textFn = function()
        local t = getSelectedThread()
        if not t then return '' end
        return expandTemplate(btn.text, getResolvedAnsId(t))
    end
    return sendPresetReplyToSelected(btn.id or 'quick', textFn)
end

-- Desk hook/helper.
function deskComposerQuickReplies()
    ensureComposerQuickButtons()
    local gen = deskCache.composerQuickGen or 0
    if deskCache.composerQuickItems and deskCache.composerQuickGenCached == gen then
        return deskCache.composerQuickItems
    end
    local out = {}
    for i, b in ipairs(settings.composer_quick_buttons) do
        out[#out + 1] = {
            id = b.id or ('qb' .. i),
            label = b.label,
            tip = b.text,
            btn = b,
            btnW = b.btnW or composerQuickBtnWidth(b.label),
            onClick = function()
                sendComposerQuickButton(b)
            end,
        }
    end
    deskCache.composerQuickItems = out
    deskCache.composerQuickGenCached = gen
    return out
end

-- Desk hook/helper.
function deskComposerQuickRowCount(availW, items)
    items = items or deskComposerQuickReplies()
    if #items == 0 then return 0 end
    availW = tonumber(availW) or 400
    if availW < 120 then availW = 400 end
    local x = 0
    local rows = 1
    for i, item in ipairs(items) do
        local bw = item.btnW or composerQuickBtnWidth(item.label)
        local gap = (i > 1) and COMPOSER_QUICK_GAP or 0
        if x > 0 and x + gap + bw > availW then
            rows = rows + 1
            x = bw
        else
            x = x + gap + bw
        end
    end
    return rows
end

-- Desk hook/helper.
function deskComposerInputHeight()
    local lh = (imgui.GetTextLineHeight and imgui.GetTextLineHeight()) or 16
    return math.ceil(lh + 14 + 2)
end

-- Desk hook/helper.
function deskComposerHeight(availW, items)
    local pad = 20
    local h = pad + deskComposerInputHeight()
    local rows = deskComposerQuickRowCount(availW, items)
    if rows > 0 then
        h = h + COMPOSER_ROW_GAP + rows * COMPOSER_QUICK_H + math.max(0, rows - 1) * COMPOSER_QUICK_GAP
    end
    return h + 4
end

-- Composer Quick Btn Width
function composerQuickBtnWidth(label)
    local w = imgui.CalcTextSize(uiText(label or '?')).x + 20
    if w < 52 then w = 52 end
    if w > 120 then w = 120 end
    return w
end

-- Draw Composer Quick Row
function drawComposerQuickRow(items, canSend, availW)
    items = items or deskComposerQuickReplies()
    if #items == 0 then return end

    availW = tonumber(availW) or imgui.GetContentRegionAvail().x
    if availW < 120 then availW = 400 end

    imgui.Dummy(imgui.ImVec2(0, COMPOSER_ROW_GAP))
    local rowStartX = imgui.GetCursorPosX()
    for i, item in ipairs(items) do
        local bw = item.btnW or composerQuickBtnWidth(item.label)
        if i > 1 then
            if imgui.GetCursorPosX() - rowStartX + COMPOSER_QUICK_GAP + bw > availW then
                imgui.Dummy(imgui.ImVec2(0, COMPOSER_QUICK_GAP))
                rowStartX = imgui.GetCursorPosX()
            else
                imgui.SameLine(0, COMPOSER_QUICK_GAP)
            end
        end
        local label = uiText(item.label or '?')
        if type(pushPlayerActionBtnStyle) == 'function' then pushPlayerActionBtnStyle() end
        if not canSend and imgui.PushStyleVarFloat then
            imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, 0.42)
        end
        if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
        local clicked = imgui.Button(label .. '##' .. (item.id or i), imgui.ImVec2(bw, COMPOSER_QUICK_H))
        if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end
        if not canSend and imgui.PopStyleVar then imgui.PopStyleVar() end
        if type(popPlayerActionBtnStyle) == 'function' then popPlayerActionBtnStyle() end
        if item.tip and imgui.IsItemHovered() then
            local tip = type(item.tip) == 'function' and item.tip() or item.tip
            if tip and tip ~= '' then imgui.SetTooltip(uiText(tip)) end
        end
        if canSend and clicked and item.onClick then
            item.onClick()
        end
    end
end

-- Draw Composer
function drawComposer(composerH, quickItems)
    composerH = tonumber(composerH) or COMPOSER_H
    local composerFlags = 0
    if imgui.WindowFlags then
        if imgui.WindowFlags.NoScrollbar then composerFlags = composerFlags + imgui.WindowFlags.NoScrollbar end
        if imgui.WindowFlags.NoScrollWithMouse then composerFlags = composerFlags + imgui.WindowFlags.NoScrollWithMouse end
    end

    imgui.PushStyleColor(imgui.Col.ChildBg, col_composer)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(12, 10))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 0))
    imgui.BeginChild('##composer', imgui.ImVec2(-1, composerH), false, composerFlags)

    if deskInputState.focusReplyNext and imgui.SetKeyboardFocusHere then
        imgui.SetKeyboardFocusHere(0)
        deskInputState.keyboardStickyUntil = os.clock() + 2.0
        deskInputState.replyFocused = true
        deskInputState.focusReplyNext = false
        deskInputState.focusReplyReason = nil
    end

    local canSend = getSelectedThread() ~= nil
    local flags = 0
    if imgui.InputTextFlags and imgui.InputTextFlags.EnterReturnsTrue then
        flags = imgui.InputTextFlags.EnterReturnsTrue
    end

    local gap = 8
    local availW = imgui.GetContentRegionAvail().x
    local sendLbl = uiText('\xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC')
    local sendW = math.max(COMPOSER_SEND_MIN_W or 78, math.floor(imgui.CalcTextSize(sendLbl).x + 24))
    local inputW = math.max(80, availW - sendW - gap)
    local hint = uiText('\xCE\xF2\xE2\xE5\xF2 \xE2 \xF0\xE5\xEF\xEE\xF0\xF2...')

    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 7))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
    deskPushFlatInputStyle()

    imgui.PushItemWidth(inputW)
    local sent
    if imgui.InputTextWithHint then
        sent = imgui.InputTextWithHint('##reply', hint, replyBuf, sizeof(replyBuf), flags)
    else
        sent = imgui.InputText('##reply', replyBuf, sizeof(replyBuf), flags)
    end
    if imgui.IsItemClicked and imgui.IsItemClicked(0) then
        deskInputState.keyboardStickyUntil = os.clock() + 2.0
        deskInputState.replyFocused = true
    end
    deskKeepInputOnActiveItem()
    local replyActive = false
    if imgui.IsItemActive then replyActive = imgui.IsItemActive() end
    if not replyActive and imgui.IsItemFocused then replyActive = imgui.IsItemFocused() end
    deskInputState.replyInputActive = replyActive
    local inputH = (imgui.GetFrameHeight and imgui.GetFrameHeight()) or deskComposerInputHeight()
    imgui.PopItemWidth()
    deskPopFlatInputStyle()
    imgui.PopStyleVar(2)

    imgui.SameLine(0, gap)
    if canSend then
        imgui.PushStyleColor(imgui.Col.Button, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent)
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.45, 0.22, 0.72, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.14, 0.14, 0.16, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16, 0.16, 0.18, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.14, 0.14, 0.16, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, col_muted2)
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 5))
    if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
    local sendClicked = imgui.Button(sendLbl .. '##desk_send', imgui.ImVec2(sendW, inputH))
    if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(4)

    if canSend and (sendClicked or sent) then
        if sendReplyToSelected() then
            ffi.copy(replyBuf, '')
            deskInputState.focusReplyNext = true
            deskInputState.focusReplyReason = 'send'
            deskInputState.replyFocused = true
            if selectedKey then
                requestChatSnapBottom(selectedKey)
            end
        end
    end

    drawComposerQuickRow(quickItems, canSend, availW)

    imgui.PopStyleVar(2)
    imgui.EndChild()
    imgui.PopStyleColor()
end

-- Draw Empty Chat Placeholder
function drawEmptyChatPlaceholder()
    local avail = imgui.GetContentRegionAvail()
    imgui.SetCursorPos(imgui.ImVec2(avail.x * 0.5 - 80, avail.y * 0.5 - 24))
    imgui.BeginGroup()
    imgui.TextColored(col_accent, uiText('REPORT DESK'))
    imgui.TextColored(col_muted, uiText('\xC2\xFB\xE1\xE5\xF0\xE8\xF2\xE5 \xE4\xE8\xE0\xEB\xEE\xE3 \xF1\xEB\xE5\xE2\xE0'))
    imgui.EndGroup()
end

-- Draw Thread Row
function drawThreadRow(t, key, sel)
    local availX = imgui.GetContentRegionAvail().x
    local rowH = THREAD_ROW_H
    local dl = imgui.GetWindowDrawList()

    if imgui.InvisibleButton('##thr' .. key, imgui.ImVec2(availX, rowH)) then
        local unread = t.unread or 0
        if unread > 0 then
            totalUnread = math.max(0, totalUnread - unread)
        end
        selectedKey = key
        t.unread = 0
        deskInputState.chatFollowBottom = true
        requestChatSnapBottom(key)
        deskInputState.focusReplyNext = true
        deskInputState.focusReplyReason = 'select'
        markDirtyThreads()
    end

    local min = imgui.GetItemRectMin()
    local max = imgui.GetItemRectMax()
    local unread = t.unread or 0
    if sel then
        dl:AddRectFilled(min, max, toU32(col_row_sel), 8)
    elseif imgui.IsItemHovered() then
        dl:AddRectFilled(min, max, toU32(col_row_hover), 8)
    end

    local accentCol = unread > 0 and col_unread or (sel and col_accent or imgui.ImVec4(0.35, 0.22, 0.50, 0.9))
    dl:AddRectFilled(
        imgui.ImVec2(min.x + 4, min.y + 8),
        imgui.ImVec2(min.x + 4 + THREAD_ACCENT_W, max.y - 8),
        toU32(accentCol),
        2
    )
    local rightEdge = max.x - THREAD_PAD_L
    local textX = min.x + THREAD_TEXT_OFF
    local timeStr = uiText(formatTimeShort(t.lastAt))
    local timeW = imgui.CalcTextSize(timeStr).x
    local badgeReserve = unread > 0 and THREAD_BADGE_W or 0
    local nameMaxW = rightEdge - textX - timeW - 8
    if nameMaxW < 40 then nameMaxW = 40 end
    local previewMaxW = rightEdge - textX - badgeReserve - 6
    if previewMaxW < 50 then previewMaxW = 50 end

    local liveId = findPlayerIdByNick(t.nick)

    local nameCol = sel and col_accent or (unread > 0 and imgui.ImVec4(0.95, 0.90, 1.0, 1.0) or col_label)
    local nameRaw = t.nick or ''
    if t.pinned then
        nameRaw = '^ ' .. nameRaw
    end
    if liveId ~= nil then
        nameRaw = nameRaw .. ' [' .. tostring(liveId) .. ']'
    end
    dl:AddText(imgui.ImVec2(textX, min.y + 10), toU32(nameCol), ellipsizeToWidth(nameRaw, nameMaxW))
    dl:AddText(
        imgui.ImVec2(rightEdge - timeW, min.y + 12),
        toU32(col_muted2),
        timeStr
    )

    local previewY = min.y + 34
    local previewCol = unread > 0 and imgui.ImVec4(0.72, 0.72, 0.78, 1.0) or col_muted
    dl:AddText(
        imgui.ImVec2(textX, previewY),
        toU32(previewCol),
        ellipsizeToWidth(t._previewText or lastPreview(t), previewMaxW)
    )

    if unread > 0 then
        drawUnreadBadge(dl, rightEdge, previewY + 6, unread)
    end

    dl:AddLine(
        imgui.ImVec2(textX, max.y - 1),
        imgui.ImVec2(max.x - THREAD_PAD_L, max.y - 1),
        toU32(imgui.ImVec4(0.18, 0.18, 0.22, 0.75))
    )
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Fill Composer Quick Editor
function fillComposerQuickEditor(idx)
    ensureComposerQuickButtons()
    local b = settings.composer_quick_buttons[idx]
    if not b then return end
    setInputBuf(editCqLabel, b.label or '')
    setInputBuf(editCqText, b.text or '')
    composerQuickEditorDirty = false
end

-- Сброс/отправка очереди.
function flushComposerQuickEditor()
    ensureComposerQuickButtons()
    if composerQuickSelected < 1 or composerQuickSelected > #settings.composer_quick_buttons then return end
    local b = settings.composer_quick_buttons[composerQuickSelected]
    b.label = readInputBuf(editCqLabel)
    b.text = readInputBuf(editCqText)
    b.btnW = composerQuickBtnWidth(b.label)
    syncLegacyGgTechFromComposerButtons()
    bumpComposerQuickGen()
    markDirtySettings()
    composerQuickEditorDirty = false
end

-- Draw Composer Quick Tab Inner
function drawComposerQuickTabInner()
    ensureComposerQuickButtons()
    pushPanelStyle()
    imgui.BeginChild('##cq_list', imgui.ImVec2(200, -1), true)
    if imgui.Button(uiText('+ \xCA\xED\xEE\xEF\xEA\xE0'), imgui.ImVec2(-1, 28)) then
        flushComposerQuickEditor()
        local n = #settings.composer_quick_buttons + 1
        settings.composer_quick_buttons[n] = {
            id = 'qb' .. tostring(n),
            label = '\xCD\xEE\xE2\xE0\xFF',
            text = '',
            btnW = composerQuickBtnWidth('\xCD\xEE\xE2\xE0\xFF'),
        }
        composerQuickSelected = n
        fillComposerQuickEditor(n)
        bumpComposerQuickGen()
        markDirtySettings()
    end
    imgui.Dummy(imgui.ImVec2(0, 6))
    for i, b in ipairs(settings.composer_quick_buttons) do
        local name = trim(b.label or '')
        if name == '' then name = '\xCA\xED\xEE\xEF\xEA\xE0 ' .. i end
        if imgui.Selectable(uiText(name) .. '##cq_' .. i, composerQuickSelected == i) then
            if composerQuickEditorDirty then flushComposerQuickEditor() end
            composerQuickSelected = i
            fillComposerQuickEditor(i)
        end
    end
    imgui.EndChild()
    imgui.SameLine()
    imgui.BeginChild('##cq_edit', imgui.ImVec2(-1, -1), true)
    if composerQuickSelected < 1 or composerQuickSelected > #settings.composer_quick_buttons then
        imgui.TextColored(col_muted, uiText('\xC2\xFB\xE1\xE5\xF0\xE8\xF2\xE5 \xEA\xED\xEE\xEF\xEA\xF3 \xE8\xEB\xE8 \xE4\xEE\xE1\xE0\xE2\xFC\xF2\xE5 \xED\xEE\xE2\xF3\xFE'))
    else
        imgui.TextColored(col_muted2, uiText('\xCF\xEE\xE4\xEF\xE8\xF1\xFC \xED\xE0 \xEA\xED\xEE\xEF\xEA\xE5 \xEF\xEE\xE4 \xEF\xEE\xEB\xE5\xEC \xE2\xE2\xEE\xE4\xE0. \xD2\xE5\xE3\xE8: {datetime} {time} {date} {id}'))
        imgui.Dummy(imgui.ImVec2(0, 6))
        imgui.TextColored(col_muted2, uiText('\xCF\xEE\xE4\xEF\xE8\xF1\xFC'))
        imgui.PushItemWidth(-1)
        if imgui.InputText('##cq_lbl', editCqLabel, sizeof(editCqLabel)) then
            composerQuickEditorDirty = true
        end
        if imguiItemEdited() then composerQuickEditorDirty = true end
        imgui.PopItemWidth()
        imgui.TextColored(col_muted2, uiText('\xD2\xE5\xEA\xF1\xF2 \xEE\xF2\xE2\xE5\xF2\xE0 (/ans)'))
        imgui.PushItemWidth(-1)
        if imgui.InputTextMultiline then
            if imgui.InputTextMultiline('##cq_txt', editCqText, sizeof(editCqText), imgui.ImVec2(-1, 120)) then
                composerQuickEditorDirty = true
            end
        elseif imgui.InputText('##cq_txt', editCqText, sizeof(editCqText)) then
            composerQuickEditorDirty = true
        end
        if imguiItemEdited() then composerQuickEditorDirty = true end
        imgui.PopItemWidth()
        imgui.Dummy(imgui.ImVec2(0, 8))
        if imgui.Button(uiText('\xD1\xEE\xF5\xF0\xE0\xED\xE8\xF2\xFC'), imgui.ImVec2(-1, 28)) then
            flushComposerQuickEditor()
            flushDirtyConfigNow()
        end
        local rowW = imgui.GetContentRegionAvail().x
        local canUp = composerQuickSelected > 1
        local canDn = composerQuickSelected < #settings.composer_quick_buttons
        if canUp and canDn then
            local halfW = math.max(80, (rowW - 8) * 0.5)
            if imgui.Button(uiText('\xC2\xE2\xE5\xF0\xF5') .. '##cq_up', imgui.ImVec2(halfW, 28)) then
                flushComposerQuickEditor()
                local list = settings.composer_quick_buttons
                list[composerQuickSelected], list[composerQuickSelected - 1] =
                    list[composerQuickSelected - 1], list[composerQuickSelected]
                composerQuickSelected = composerQuickSelected - 1
                fillComposerQuickEditor(composerQuickSelected)
                markDirtySettings()
            end
            imgui.SameLine(0, 8)
            if imgui.Button(uiText('\xC2\xED\xE8\xE7') .. '##cq_dn', imgui.ImVec2(halfW, 28)) then
                flushComposerQuickEditor()
                local list = settings.composer_quick_buttons
                list[composerQuickSelected], list[composerQuickSelected + 1] =
                    list[composerQuickSelected + 1], list[composerQuickSelected]
                composerQuickSelected = composerQuickSelected + 1
                fillComposerQuickEditor(composerQuickSelected)
                markDirtySettings()
            end
        elseif canUp then
            if imgui.Button(uiText('\xC2\xE2\xE5\xF0\xF5') .. '##cq_up', imgui.ImVec2(-1, 28)) then
                flushComposerQuickEditor()
                local list = settings.composer_quick_buttons
                list[composerQuickSelected], list[composerQuickSelected - 1] =
                    list[composerQuickSelected - 1], list[composerQuickSelected]
                composerQuickSelected = composerQuickSelected - 1
                fillComposerQuickEditor(composerQuickSelected)
                markDirtySettings()
            end
        elseif canDn then
            if imgui.Button(uiText('\xC2\xED\xE8\xE7') .. '##cq_dn', imgui.ImVec2(-1, 28)) then
                flushComposerQuickEditor()
                local list = settings.composer_quick_buttons
                list[composerQuickSelected], list[composerQuickSelected + 1] =
                    list[composerQuickSelected + 1], list[composerQuickSelected]
                composerQuickSelected = composerQuickSelected + 1
                fillComposerQuickEditor(composerQuickSelected)
                markDirtySettings()
            end
        end
        if imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##cq_del', imgui.ImVec2(-1, 28)) then
            flushComposerQuickEditor()
            table.remove(settings.composer_quick_buttons, composerQuickSelected)
            if composerQuickSelected > #settings.composer_quick_buttons then
                composerQuickSelected = #settings.composer_quick_buttons
            end
            if composerQuickSelected < 1 then composerQuickSelected = 1 end
            if #settings.composer_quick_buttons > 0 then
                fillComposerQuickEditor(composerQuickSelected)
            end
            syncLegacyGgTechFromComposerButtons()
            markDirtySettings()
        end
    end
    imgui.EndChild()
    popPanelStyle()
end

-- Draw Composer Quick Tab
function drawComposerQuickTab()
    if not composerQuickUiSynced then
        ensureComposerQuickButtons()
        if composerQuickSelected < 1 then composerQuickSelected = 1 end
        if composerQuickSelected > #settings.composer_quick_buttons then
            composerQuickSelected = math.max(1, #settings.composer_quick_buttons)
        end
        if #settings.composer_quick_buttons > 0 then fillComposerQuickEditor(composerQuickSelected) end
        composerQuickUiSynced = true
    end
    local ok, err = pcall(drawComposerQuickTabInner)
    if composerQuickEditorDirty then flushComposerQuickEditor() end
    if not ok then
        imgui.TextColored(col_warn, 'Quick replies UI error:')
        imgui.TextWrapped(tostring(err))
        print('[Report Desk] composer quick UI: ' .. tostring(err))
    end
end

-- Apply Chat Scroll If Needed
function applyChatScrollIfNeeded(msgCount)
    msgCount = tonumber(msgCount) or 0

    -- Snap всегда первым: должен отработать даже когда ##reply в фокусе.
    if deskInputState.snapPending and deskInputState.snapKey == selectedKey then
        local maxY = (imgui.GetScrollMaxY and imgui.GetScrollMaxY()) or 0
        if maxY > 0 and imgui.SetScrollY then
            imgui.SetScrollY(maxY)
            deskInputState.snapPending = false
            deskInputState.snapKey = nil
        else
            deskInputState.chatScrollUntil = os.clock() + 0.12
        end
        return
    end

    -- SetScrollY не забирает фокус у ##reply (в отличие от SetScrollHereY).
    if deskInputState.focusReplyNext and deskInputState.focusReplyReason ~= 'send' then return end

    local wantFollow = (not deskInputState.snapPending)
        and (os.clock() < (deskInputState.chatScrollUntil or 0))
    if not wantFollow then return end

    -- SetScrollHereY забирает клавиатурный фокус у ##reply (см. REPORT_DESK_CHAT_UI.md).
    imgui.Dummy(imgui.ImVec2(0, 1))
    local maxY = (imgui.GetScrollMaxY and imgui.GetScrollMaxY()) or 0
    if maxY > 0 and imgui.SetScrollY then
        imgui.SetScrollY(maxY)
    else
        deskInputState.chatScrollUntil = os.clock() + 0.12
    end
end

-- Draw Chat New Message Button
function drawChatNewMessageButton()
    if deskInputState.chatFollowBottom or not deskInputState.hasUnseenMessages then return end
    local btnW, btnH = 160, 32
    local inset = 12
    local wPos = imgui.GetWindowPos()
    local wSize = imgui.GetWindowSize()
    local btnX = wPos.x + wSize.x - btnW - inset
    local btnY = wPos.y + wSize.y - btnH - inset
    imgui.SetCursorScreenPos(imgui.ImVec2(btnX, btnY))
    local clicked = imgui.InvisibleButton('##chat_new_msg', imgui.ImVec2(btnW, btnH))
    local hovered = imgui.IsItemHovered and imgui.IsItemHovered()
    local dl = imgui.GetWindowDrawList()
    local bgCol = hovered and col_accent or col_accent_dim
    local r = btnH * 0.5
    dl:AddRectFilled(imgui.ImVec2(btnX, btnY), imgui.ImVec2(btnX + btnW, btnY + btnH), toU32(bgCol), r)
    local label = uiText('\xCD\xEE\xE2\xEE\xE5 \xF1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5')
    local arrow = '\xE2\x86\x93'
    local arrowSz = imgui.CalcTextSize(arrow)
    local labelSz = imgui.CalcTextSize(label)
    local gap = 6
    local totalW = arrowSz.x + gap + labelSz.x
    local textX = btnX + (btnW - totalW) * 0.5
    local textY = btnY + (btnH - labelSz.y) * 0.5
    dl:AddText(imgui.ImVec2(textX, textY), toU32(col_label), arrow)
    dl:AddText(imgui.ImVec2(textX + arrowSz.x + gap, textY), toU32(col_label), label)
    if clicked then
        deskInputState.chatFollowBottom = true
        deskInputState.hasUnseenMessages = false
        requestChatScrollBottom()
    end
end

-- Update Chat Follow Bottom
function updateChatFollowBottom()
    if not imgui.GetScrollY or not imgui.GetScrollMaxY then return end
    local scrollY = imgui.GetScrollY()
    local scrollMax = imgui.GetScrollMaxY()
    if scrollMax <= 0 then
        deskInputState.chatFollowBottom = true
        deskInputState.chatLastScrollY = scrollY
        return
    end
    local atBottom = (scrollMax - scrollY) < 80
    if atBottom then
        deskInputState.chatFollowBottom = true
        deskInputState.hasUnseenMessages = false
    elseif imgui.IsWindowHovered and imgui.IsWindowHovered() then
        local io = imgui.GetIO()
        if io and io.MouseWheel and io.MouseWheel > 0 then
            deskInputState.chatFollowBottom = false
        end
        local lastY = deskInputState.chatLastScrollY
        if lastY ~= nil and scrollY < lastY - 2 and not atBottom then
            deskInputState.chatFollowBottom = false
        end
    end
    deskInputState.chatLastScrollY = scrollY
end

-- Draw Chat Panel
function drawChatPanel()
    local t = getSelectedThread()
    if not t then
        deskInputState.replyInputActive = false
        pushPanelStyle(col_chat_bg)
        imgui.BeginChild('##chat_empty', imgui.ImVec2(-1, -1), false)
        drawEmptyChatPlaceholder()
        imgui.EndChild()
        popPanelStyle()
        return
    end

    pushPanelStyle(col_chat_bg)
    imgui.BeginChild('##chat_col', imgui.ImVec2(-1, -1), false)

    local p = getPendingAutoForSelected()
    if p then
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.28, 0.20, 0.10, 1.0))
        imgui.BeginChild('##pending_auto', imgui.ImVec2(-1, 40), false)
        imgui.TextColored(col_warn, uiText('\xC0\xE2\xF2\xEE: ' .. (p.rule.name or '')))
        imgui.SameLine()
        if imgui.Button(uiText('\xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC') .. '##pa_ok', imgui.ImVec2(90, 0)) then
            if selectedKey then confirmPendingAuto(selectedKey) end
        end
        imgui.SameLine()
        if imgui.Button(uiText('\xD1\xEA\xE8\xEF') .. '##pa_no', imgui.ImVec2(60, 0)) then
            if selectedKey then pendingAuto[selectedKey] = nil end
        end
        imgui.EndChild()
        imgui.PopStyleColor()
    end

    drawChatHeader(t)

    local colW = imgui.GetContentRegionAvail().x
    local quickItems = deskComposerQuickReplies()
    local composerH = deskComposerHeight(colW, quickItems)
    local logH = imgui.GetContentRegionAvail().y - composerH
    if logH < 100 then logH = 100 end
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(CHAT_LOG_PAD, CHAT_LOG_PAD))
    imgui.BeginChild('##chat_log', imgui.ImVec2(-1, logH), true)
    imgui.PopStyleVar()
    local msgs = t.messages or {}
    local fullW = imgui.GetContentRegionAvail().x - CHAT_LOG_PAD
    if fullW < 80 then fullW = 80 end
    if #msgs == 0 then
        imgui.Dummy(imgui.ImVec2(0, 40))
        imgui.TextColored(col_muted, uiText('\xCD\xE5\xF2 \xF1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE9 \xE2 \xFD\xF2\xEE\xEC \xF2\xF0\xE5\xE4\xE5'))
    else
        imgui.Dummy(imgui.ImVec2(0, 6))
        local renderFrom = 1
        local chatRenderMax = CHAT_UI_RENDER_MAX
        if #msgs > chatRenderMax then
            renderFrom = #msgs - chatRenderMax + 1
            imgui.TextColored(col_muted2, uiText(string.format(
                '\xCF\xEE\xEA\xE0\xE7\xE0\xED\xEE \xEF\xEE\xF1\xEB\xE5\xE4\xED\xE8\xE5 %d \xE8\xE7 %d',
                chatRenderMax, #msgs)))
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        local lastDay = nil
        local scenarioSig = tostring(intentsGen) .. '|' .. tostring(renderFrom) .. '|' .. tostring(#msgs)
            .. '|' .. tostring(deskCache.threadMsgRev or 0) .. '|' .. tostring(selectedKey or '')
        if deskCache.scenarioBtnSig ~= scenarioSig then
            deskCache.scenarioBtnIdx = findLastPlayerScenarioMsgIdx(msgs, renderFrom)
            deskCache.scenarioBtnSig = scenarioSig
        end
        local scenarioBtnIdx = deskCache.scenarioBtnIdx
        local threadPid, threadOnline = chatHeaderResolvePlayer(t)
        local threadNickCol = chatHeaderNickColor(threadPid, threadOnline, t.nick)
        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))
        for i = renderFrom, #msgs do
            local m = msgs[i]
            local dk = messageDayKey(m.ts)
            if dk ~= '' and dk ~= lastDay then
                drawDateSeparator(fullW, m.ts)
                lastDay = dk
            end
            local prev = i > renderFrom and msgs[i - 1] or nil
            local groupedWithPrev = prev and canGroupChatMessages(prev, m)
            drawBubbleMessage(m, fullW, i, t, {
                showAuthor = not groupedWithPrev,
                compactSpacing = groupedWithPrev,
                noQuickButtons = scenarioBtnIdx ~= i,
                nickCol = threadNickCol,
            })
        end
        imgui.PopStyleVar()
    end
    updateChatFollowBottom()
    applyChatScrollIfNeeded(#msgs)
    drawChatNewMessageButton()
    imgui.EndChild()

    drawComposer(composerH, quickItems)
    imgui.EndChild()
    popPanelStyle()
end

-- Прочитать все — на всю ширину, высота как у поля поиска.
function drawReadAllThreadsButton()
    if (tonumber(totalUnread) or 0) <= 0 then return end
    local frameH = (imgui.GetFrameHeight and imgui.GetFrameHeight()) or 26
    if imgui.Button(uiText('\xCF\xF0\xEE\xF7\xE8\xF2\xE0\xF2\xFC \xE2\xF1\xE5') .. '##read_all_threads', imgui.ImVec2(-1, frameH)) then
        resetSessionUnread()
        markDirtyThreads()
        markUiCacheDirty()
    end
end

-- Draw Filter Chips
function drawFilterChips()
    local labels = {
        uiText('\xCD\xE5\xEF\xF0.'),
        uiText('\xC2\xF1\xE5'),
    }
    if totalUnread > 0 then
        local n = totalUnread > 99 and '99+' or tostring(totalUnread)
        labels[1] = labels[1] .. ' (' .. n .. ')'
    end
    local chipW = math.floor((imgui.GetContentRegionAvail().x - 8) / 2)
    if chipW < 72 then chipW = 72 end
    for i, lbl in ipairs(labels) do
        local active = filterMode[0] == i - 1
        if active then
            imgui.PushStyleColor(imgui.Col.Button, col_accent_dim)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent)
        end
        if imgui.Button(lbl .. '##chip' .. i, imgui.ImVec2(chipW, 26)) then
            filterMode[0] = i - 1
            markUiCacheDirty()
        end
        if active then imgui.PopStyleColor(2) end
        if i < #labels then imgui.SameLine(0, 6) end
    end
end

-- Draw Thread List
function drawThreadList()
    pushPanelStyle(col_sidebar)
    imgui.BeginChild('##sidebar', imgui.ImVec2(LIST_W, -1), false)

    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.PushItemWidth(-1)
    imgui.InputTextWithHint('##search', uiText('\xCF\xEE\xE8\xF1\xEA...'), searchBuf, sizeof(searchBuf))
    imgui.PopItemWidth()
    if (tonumber(totalUnread) or 0) > 0 then
        imgui.Dummy(imgui.ImVec2(0, 6))
        drawReadAllThreadsButton()
    end
    imgui.Dummy(imgui.ImVec2(0, 8))
    drawFilterChips()
    imgui.Dummy(imgui.ImVec2(0, 6))

    imgui.BeginChild('##threads', imgui.ImVec2(-1, -1), true)
    local keys = getFilteredThreadKeys()
    if #keys == 0 then
        local q = trim(readInputBuf(searchBuf))
        local emptyMsg = (filterMode[0] == 0 and q == '')
            and '\xD0\xE5\xEF\xEE\xF0\xF2 \xE7\xE0\xF2\xE0\xF9\xE8\xEB\xE8, \xED\xEE\xE2\xEE\xE3\xEE \xED\xE5\xF2'
            or '\xCD\xE8\xF7\xE5\xE3\xEE \xED\xE5 \xED\xE0\xE9\xE4\xE5\xED\xEE'
        imgui.Dummy(imgui.ImVec2(0, 28))
        local pad = 14
        local wrapW = math.max(120, imgui.GetContentRegionAvail().x - pad * 2)
        imgui.SetCursorPosX(imgui.GetCursorPosX() + pad)
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + wrapW)
        imgui.TextColored(col_muted2, uiText(emptyMsg))
        imgui.PopTextWrapPos()
    elseif imgui.ImGuiListClipper then
        local rowH = THREAD_ROW_H
        local clipper = imgui.ImGuiListClipper()
        clipper:Begin(#keys, rowH)
        while clipper:Step() do
            for ri = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                local key = keys[ri + 1]
                local th = key and threads[key]
                if th then
                    drawThreadRow(th, key, selectedKey == key)
                end
            end
        end
        clipper:End()
    else
        for _, key in ipairs(keys) do
            local th = threads[key]
            if th then
                drawThreadRow(th, key, selectedKey == key)
            end
        end
    end
    imgui.EndChild()

    imgui.EndChild()
    popPanelStyle()
end

-- Draw Auto Replies Settings
function drawAutoRepliesSettings()
    if deskFormCheckboxRow('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB \xE2\xEA\xEB\xFE\xF7\xE5\xED\xFB', uiAutoRulesEnabled, function(v)
        settings.auto_rules_enabled = v
        markDirtySettings()
    end, 'auto_on') then end

    drawSettingsSubsection('\xD2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF')
    if deskFormCheckboxRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xEE', uiAutoTimeEnabled, function(v)
        settings.auto_time_enabled = v
        markDirtySettings()
    end, 'auto_time_en') then end
    imgui.PushItemWidth(-1)
    deskPushFlatInputStyle()
    local timeChanged
    if imgui.InputTextMultiline then
        timeChanged = imgui.InputTextMultiline('##auto_time_reply', deskReplyBuf.time, sizeof(deskReplyBuf.time),
            imgui.ImVec2(-1, 56))
    else
        timeChanged = imgui.InputText('##auto_time_reply', deskReplyBuf.time, sizeof(deskReplyBuf.time))
    end
    deskPopFlatInputStyle()
    deskKeepInputOnActiveItem()
    if timeChanged or imguiItemEdited() then
        settings.time_reply = readInputBuf(deskReplyBuf.time)
        markDirtySettings()
    end
    imgui.PopItemWidth()
    drawSettingsHint('{datetime}')

    drawSettingsSubsection('\xD1\xEF\xE0\xF1\xE8\xE1\xEE / GG')
    if deskFormCheckboxRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xEE', uiAutoGgEnabled, function(v)
        settings.auto_gg_enabled = v
        markDirtySettings()
    end, 'auto_gg_en') then end
    imgui.PushItemWidth(-1)
    deskPushFlatInputStyle()
    local ggChanged
    if imgui.InputTextMultiline then
        ggChanged = imgui.InputTextMultiline('##auto_gg_reply', deskReplyBuf.gg, sizeof(deskReplyBuf.gg),
            imgui.ImVec2(-1, 56))
    else
        ggChanged = imgui.InputText('##auto_gg_reply', deskReplyBuf.gg, sizeof(deskReplyBuf.gg))
    end
    deskPopFlatInputStyle()
    deskKeepInputOnActiveItem()
    if ggChanged or imguiItemEdited() then
        syncGgReplyToComposer(readInputBuf(deskReplyBuf.gg))
        markDirtySettings()
    end
    imgui.PopItemWidth()
end

-- Sync Settings Ui From Settings
function syncSettingsUiFromSettings()
    uiAutoRulesEnabled[0] = settings.auto_rules_enabled ~= false
    uiAutoTimeEnabled[0] = settings.auto_time_enabled ~= false
    uiAutoGgEnabled[0] = settings.auto_gg_enabled ~= false
    uiSpecHud[0] = settings.spectate_hud ~= false
    uiSpecNearbyHud[0] = settings.spectate_nearby_hud ~= false
    uiWatchAutoNotify[0] = settings.watch_auto_notify ~= false
    uiSpecAutoRefresh[0] = settings.spectate_auto_refresh ~= false
    uiSpecHudPersist[0] = settings.spectate_hud_persist ~= false
    uiSpecSpMenuSound[0] = settings.spectate_sp_menu_sound == true
    uiSpecVehicleHud[0] = settings.spectate_vehicle_hud ~= false
    uiSpecKeysHud[0] = settings.spectate_keys_hud ~= false
    uiSpecWheelZoom[0] = settings.spectate_wheel_zoom ~= false
    uiProfanityFilter[0] = settings.profanity_filter_enabled ~= false
    uiRemoteChatSamp[0] = settings.remote_chat_samp_mirror ~= false
    uiProfanitySound[0] = settings.profanity_filter_sound ~= false
end

-- Draw Settings Tab
function drawSettingsTab()
    if not settingsUiSynced then
        syncSettingsUiFromSettings()
        setInputBuf(deskReplyBuf.watch, settings.watch_notify or 'see')
        setInputBuf(deskReplyBuf.time, getTimeReplyText())
        setInputBuf(deskReplyBuf.gg, getGgReplyText())
        settingsUiSynced = true
    end

    pushPanelStyle(col_chat_bg)
    local childFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        childFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##settings_panel', imgui.ImVec2(-1, -1), false, childFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))
    deskFormPanelBegin('##set_main')
    drawSettingsCardHeader('\xCE\xF1\xED\xEE\xE2\xED\xEE\xE5', '')
    drawSettingsHotkeyBind()
    deskFormPanelEnd()

    deskFormPanelBegin('##set_chat')
    drawSettingsCardHeader('\xD7\xE0\xF2', '')

    if deskFormCheckboxRow('\xC4\xE0\xEB\xFC\xED\xE8\xE9 \xF7\xE0\xF2', uiRemoteChatSamp, function(v)
        settings.remote_chat_samp_mirror = v
        if type(remoteChatSetMirrorEnabled) == 'function' then
            pcall(remoteChatSetMirrorEnabled, v)
        elseif v == false and type(remoteChatClearQueue) == 'function' then
            pcall(remoteChatClearQueue)
        end
        markDirtySettings()
    end, 'remote_chat_samp') then end

    if deskFormCheckboxRow('\xCE\xF2\xF1\xEB\xE5\xE6\xE8\xE2\xE0\xF2\xFC \xEC\xE0\xF2', uiProfanityFilter, function(v)
        settings.profanity_filter_enabled = v
        markDirtySettings()
    end, 'prof_on') then end
    if uiProfanityFilter[0] then
        if deskFormCheckboxRow('\xC7\xE2\xF3\xEA \xEF\xF0\xE8 \xEE\xE1\xED\xE0\xF0\xF3\xE6\xE5\xED\xE8\xE8', uiProfanitySound, function(v)
            settings.profanity_filter_sound = v
            markDirtySettings()
        end, 'prof_snd') then end
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##set_auto')
    drawSettingsCardHeader('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB', '')
    drawAutoRepliesSettings()
    deskFormPanelEnd()

    deskFormPanelBegin('##set_spec')
    drawSettingsCardHeader('\xCF\xEE\xEC\xEE\xF9\xED\xE8\xEA /sp', '')

    drawSettingsSubsection('HUD')
    if deskFormCheckboxRow('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xF2\xFC \xF1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xF3 \xE8\xE3\xF0\xEE\xEA\xE0', uiSpecHud, function(v)
        settings.spectate_hud = v
        markDirtySettings()
    end, 'spec_hud') then end
    if deskFormCheckboxRow('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xF2\xFC \xAB\xD0\xFF\xE4\xEE\xEC\xBB \xE2 HUD', uiSpecNearbyHud, function(v)
        settings.spectate_nearby_hud = v
        markDirtySettings()
    end, 'spec_nearby_hud') then end
    if deskFormCheckboxRow('\xCA\xE0\xF1\xF2\xEE\xEC\xED\xFB\xE9 \xF1\xEF\xE8\xE4\xEE\xEC\xE5\xF2\xF0', uiSpecVehicleHud, function(v)
        settings.spectate_vehicle_hud = v
        markDirtySettings()
    end, 'spec_vehicle_hud') then end
    if deskFormCheckboxRow('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xF2\xFC \xEA\xEB\xE0\xE2\xE8\xE0\xF2\xF3\xF0\xF3 \xE8\xE3\xF0\xEE\xEA\xE0', uiSpecKeysHud, function(v)
        settings.spectate_keys_hud = v
        markDirtySettings()
    end, 'spec_keys_hud') then end
    if deskFormCheckboxRow('\xC7\xF3\xEC \xEA\xE0\xEC\xE5\xF0\xFB \xEA\xEE\xEB\xB8\xF1\xE8\xEA\xEE\xEC', uiSpecWheelZoom, function(v)
        settings.spectate_wheel_zoom = v
        markDirtySettings()
    end, 'spec_wheel_zoom') then end

    drawSettingsSubsection('\xCF\xEE\xE2\xE5\xE4\xE5\xED\xE8\xE5')
    if deskFormCheckboxRow('\xCE\xF2\xEF\xF0\xE0\xE2\xEB\xFF\xF2\xFC \xF0\xE5\xEF\xEE\xF0\xF2\xE5\xF0\xF3 \xEF\xF0\xE8 \xED\xE0\xE1\xEB\xFE\xE4\xE5\xED\xE8\xE8', uiWatchAutoNotify, function(v)
        settings.watch_auto_notify = v
        markDirtySettings()
    end, 'watch_auto_notify') then end
    if uiWatchAutoNotify[0] then
        imgui.PushItemWidth(-1)
        deskPushFlatInputStyle()
        local watchChanged = imgui.InputText('##watch_notify_reply', deskReplyBuf.watch, sizeof(deskReplyBuf.watch))
        deskPopFlatInputStyle()
        deskKeepInputOnActiveItem()
        if watchChanged or imguiItemEdited() then
            settings.watch_notify = readInputBuf(deskReplyBuf.watch)
            markDirtySettings()
        end
        imgui.PopItemWidth()
        drawSettingsHint('\xD1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5 \xF0\xE5\xEF\xEE\xF0\xF2\xE5\xF0\xF3 \xEF\xEE\xF1\xEB\xE5 /sp (\xED\xE0\xEF\xF0. see)')
    end
    if deskFormCheckboxRow('\xCE\xE1\xED\xEE\xE2\xEB\xFF\xF2\xFC /sp \xEF\xF0\xE8 \xF2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2\xE5 \xE8 \xE8\xED\xF2\xE5\xF0\xFC\xE5\xF0\xE5', uiSpecAutoRefresh, function(v)
        settings.spectate_auto_refresh = v
        markDirtySettings()
    end, 'spec_refresh') then end
    if deskFormCheckboxRow('\xCE\xF1\xF2\xE0\xE2\xEB\xFF\xF2\xFC HUD \xEF\xEE\xF1\xEB\xE5 /sp', uiSpecHudPersist, function(v)
        settings.spectate_hud_persist = v
        markDirtySettings()
    end, 'spec_persist') then end

    if deskFormCheckboxRow('\xCD\xE0\xE2\xE8\xE3\xE0\xF6\xE8\xFF /sp', uiSpecSpMenuSound, function(v)
        settings.spectate_sp_menu_sound = v
        markDirtySettings()
        if v then
            local menuMod = package.loaded['report_desk_spectate_menu']
            if menuMod and menuMod.previewMenuSound then
                pcall(menuMod.previewMenuSound)
            elseif playSoundFrontEnd then
                pcall(playSoundFrontEnd, 4)
            end
        end
    end, 'spec_menu_snd') then end
    deskFormPanelEnd()

    deskFormPanelBegin('##set_service')
    drawSettingsCardHeader('\xD1\xEB\xF3\xE6\xE5\xE1\xED\xEE\xE5')
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.38, 0.14, 0.18, 0.9))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55, 0.20, 0.26, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.45, 0.16, 0.22, 1.0))
    if imgui.Button(uiText('\xCE\xF7\xE8\xF1\xF2\xE8\xF2\xFC \xE2\xF1\xE5 \xE4\xE8\xE0\xEB\xEE\xE3\xE8') .. '##clr_threads', imgui.ImVec2(-1, DESK_FORM_ROW_H)) then
        threads = {}
        threadOrder = {}
        threadCount = 0
        deskCache.nickKeys = {}
        deskCache.threadStructRev = 0
        deskCache.threadMsgRev = 0
        deskCache.threadRev = 0
        selectedKey = nil
        chatLogReady = false
        totalUnread = 0
        seedSeenChatLines()
        markUiCacheDirty()
        markDirtyThreads()
        markDirtySettings()
        flushDirtyConfigNow()
        say('\xC4\xE8\xE0\xEB\xEE\xE3\xE8 \xEE\xF7\xE8\xF9\xE5\xED\xFB')
    end
    imgui.PopStyleColor(3)
    deskFormPanelEnd()

    imgui.PopStyleVar(2)
    imgui.Dummy(imgui.ImVec2(0, 12))
    imgui.EndChild()
    popPanelStyle()
end

-- Toggle Window
function toggleWindow()
    if not sessionLive or not chatLogReady then return end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return end
    if showWindow[0] then
        closeDeskWindow()
        return
    end
    releaseDeskInputCapture(true)
    clearDeskImguiInputState(true)
    showWindow[0] = true
    if deskCache.deskWindowFrame then
        deskCache.deskWindowFrame.HideCursor = false
    end
    if deskSpectatingNow() then
        deskRememberSpectateCursorMode()
        deskEnableUiCursorForSamp()
    end
    settingsUiSynced = false
    adminPunishUiSynced = false
    exactTimeUiSynced = false
    tempLeadershipUiSynced = false
    local selThread = getSelectedThread()
    deskInputState.focusReplyNext = selThread ~= nil
    deskInputState.focusReplyReason = selThread ~= nil and 'open' or nil
    deskInputState.windowOpenSince = os.clock()
    if selThread ~= nil then
        deskInputState.replyInputActive = false
        deskInputState.keyboardStickyUntil = os.clock() + 2.0
        if selectedKey then
            requestChatSnapBottom(selectedKey)
        end
    else
        deskInputState.keyboardStickyUntil = 0
    end
    deskInputState.chatFollowBottom = true
    refreshMyNick()
    if type(deskRefreshLocalAdminLevel) == 'function' then
        pcall(deskRefreshLocalAdminLevel)
    end
    deskInputState.wasOpen = true
    deskApplyInputPolicy()
    updateDeskInputCapture()
end

-- Apply Main Window Layout (fullscreen only on explicit toggle via F11)
local function deskMainTabBarFlags()
    if imgui.TabBarFlags and imgui.TabBarFlags.NoTooltip then
        return imgui.TabBarFlags.NoTooltip
    end
    return 32
end

local function deskApplyMainWindowLayout(sw, sh)
    sw = tonumber(sw) or 1920
    sh = tonumber(sh) or 1080
    if type(deskCache) ~= 'table' then
        imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh * 0.5), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.Appearing)
        return
    end
    if deskCache.deskWinNeedLayout then
        if deskCache.deskWinFullscreen then
            imgui.SetNextWindowPos(imgui.ImVec2(0, 0), imgui.Cond.Always)
            imgui.SetNextWindowSize(imgui.ImVec2(sw, sh), imgui.Cond.Always)
        elseif type(deskCache.deskWinRestore) == 'table' then
            local r = deskCache.deskWinRestore
            if r.w and r.h and r.w > 80 and r.h > 80 then
                imgui.SetNextWindowPos(imgui.ImVec2(r.x or 0, r.y or 0), imgui.Cond.Always)
                imgui.SetNextWindowSize(imgui.ImVec2(r.w, r.h), imgui.Cond.Always)
            else
                imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh * 0.5), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
                imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.Appearing)
            end
        end
        deskCache.deskWinNeedLayout = false
        return
    end
    if not deskCache.deskWinFullscreen then
        imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh * 0.5), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.Appearing)
    end
end

function deskToggleWindowFullscreen()
    if type(deskCache) ~= 'table' or not showWindow[0] then return end
    if deskCache.deskWinFullscreen then
        deskCache.deskWinFullscreen = false
        deskCache.deskWinNeedLayout = true
        return
    end
    local r = deskCache.deskWinLastNormal
    if type(r) == 'table' and r.w and r.h and r.w > 80 and r.h > 80 then
        deskCache.deskWinRestore = { x = r.x, y = r.y, w = r.w, h = r.h }
    end
    deskCache.deskWinFullscreen = true
    deskCache.deskWinNeedLayout = true
end

-- Draw Main Window
-- === Главное окно Report Desk (sidebar + chat + tabs) ===
function drawMainWindow()
    if not styleApplied then
        applyModernDarkStyle()
        styleApplied = true
    end

    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    if sw < 100 then sw = 1920 end
    if sh < 100 then sh = 1080 end
    deskApplyMainWindowLayout(sw, sh)
    imgui.SetNextWindowBgAlpha(0.97)

    local winFlags = imgui.WindowFlags.NoCollapse + (imgui.WindowFlags.NoNav or 0)
    if type(deskCache) == 'table' and deskCache.deskWinFullscreen and imgui.WindowFlags.NoResize then
        winFlags = winFlags + imgui.WindowFlags.NoResize
    end

    if not imgui.Begin(uiText('Report Desk') .. '###ReportDesk', showWindow, winFlags) then
        if not showWindow[0] then
            closeDeskWindow()
        end
        imgui.End()
        if showWindow[0] then
            pcall(updateDeskInputCapture)
        end
        return
    end

    if type(deskCache) == 'table' and not deskCache.deskWinFullscreen then
        local okPos, wp = pcall(imgui.GetWindowPos)
        local okSz, ws = pcall(imgui.GetWindowSize)
        if okPos and okSz and wp and ws and ws.x and ws.y and ws.x > 80 and ws.y > 80 then
            deskCache.deskWinLastNormal = { x = wp.x, y = wp.y, w = ws.x, h = ws.y }
        end
    end

    if filterMode[0] > 1 then filterMode[0] = 0 end

    local footH = type(deskAdminFooterHeight) == 'function' and deskAdminFooterHeight() or 0
    local bodyFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.NoScrollbar then
        bodyFlags = imgui.WindowFlags.NoScrollbar
    end
    if footH > 0 then
        local bodyH = imgui.GetContentRegionAvail().y - footH
        if bodyH < 80 then bodyH = imgui.GetContentRegionAvail().y end
        imgui.BeginChild('##desk_body', imgui.ImVec2(-1, bodyH), false, bodyFlags)
    end

    local chatTabActive = false
    if imgui.BeginTabBar('##tabs', deskMainTabBarFlags()) then
        if imgui.BeginTabItem(uiText('\xD0\xE5\xEF\xEE\xF0\xF2\xFB') .. '##tab_chat') then
            chatTabActive = true
            drawThreadList()
            imgui.SameLine(0, 0)
            drawChatPanel()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xC1\xFB\xF1\xF2\xF0\xFB\xE5 \xEE\xF2\xE2\xE5\xF2\xFB') .. '##tab_cq') then
            local okCq, errCq = pcall(drawComposerQuickTab)
            if not okCq then
                imgui.TextColored(col_warn, 'Quick replies UI error:')
                imgui.TextWrapped(tostring(errCq))
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xCA\xEE\xEC\xE0\xED\xE4\xFB') .. '##tab_cmd') then
            if type(drawCmdBindsTab) ~= 'function' then
                imgui.TextColored(col_warn, uiText('\xCC\xEE\xE4\xF3\xEB\xFC \xEA\xEE\xEC\xE0\xED\xE4 \xED\xE5 \xE7\xE0\xE3\xF0\xF3\xE6\xE5\xED. /reload'))
            else
                local okCmd, errCmd = pcall(drawCmdBindsTab)
                if not okCmd then
                    imgui.TextColored(col_warn, 'Cmd binds UI error:')
                    imgui.TextWrapped(tostring(errCmd))
                    print('[Report Desk] cmd binds UI: ' .. tostring(errCmd))
                end
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xD7\xE8\xF2\xFB') .. '##tab_cheats') then
            local okCh, errCh = pcall(drawCheatsTab)
            if not okCh then
                imgui.TextColored(col_warn, 'Cheats UI error:')
                imgui.TextWrapped(tostring(errCh))
                print('[Report Desk] cheats UI: ' .. tostring(errCh))
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xD7\xE5\xEA\xE5\xF0') .. '##tab_checker') then
            if type(drawCheckerTab) ~= 'function' then
                imgui.TextColored(col_warn, uiText('\xCC\xEE\xE4\xF3\xEB\xFC \xF7\xE5\xEA\xE5\xF0\xE0 \xED\xE5 \xE7\xE0\xE3\xF0\xF3\xE6\xE5\xED. /reload'))
            else
                local okCk, errCk = pcall(drawCheckerTab)
                if not okCk then
                    imgui.TextColored(col_warn, 'Checker UI error:')
                    imgui.TextWrapped(tostring(errCk))
                    print('[Report Desk] checker UI: ' .. tostring(errCk))
                end
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xD1\xEA\xE8\xED\xFB') .. '##tab_skins') then
            skinUiTabActive = true
            if not skinTabEntered then
                skinTabEntered = true
                pcall(skinsOnTabEnter)
            end
            local okSk, errSk = pcall(drawSkinsTab)
            if not okSk then
                imgui.TextColored(col_warn, 'Skins UI error:')
                imgui.TextWrapped(tostring(errSk))
                print('[Report Desk] skins UI: ' .. tostring(errSk))
            end
            imgui.EndTabItem()
        elseif skinTabEntered then
            skinTabEntered = false
            skinUiTabActive = false
            pcall(skinsOnTabLeave)
        end
        if imgui.BeginTabItem(uiText('\xD2\xD1') .. '##tab_veh') then
            if not deskVeh.tabActive then
                deskVeh.tabActive = true
                pcall(deskVeh.onTabEnter)
            end
            local okVh, errVh = pcall(deskVeh.drawTab)
            if not okVh then
                imgui.TextColored(col_warn, 'Vehicles UI error:')
                imgui.TextWrapped(tostring(errVh))
                print('[Report Desk] vehicles UI: ' .. tostring(errVh))
            end
            imgui.EndTabItem()
        elseif deskVeh.tabActive then
            deskVeh.tabActive = false
            pcall(deskVeh.onTabLeave)
        end
        if imgui.BeginTabItem(uiText('\xCD\xE0\xEA\xE0\xE7\xE0\xED\xE8\xFF') .. '##tab_ap') then
            local okAp, errAp = pcall(drawAdminPunishTab)
            if not okAp then
                imgui.TextColored(col_warn, 'Admin punish UI error:')
                imgui.TextWrapped(tostring(errAp))
                print('[Report Desk] admin punish UI: ' .. tostring(errAp))
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xCB\xE8\xE4\xE5\xF0\xF1\xF2\xE2\xEE') .. '##tab_tl') then
            local okTl, errTl = pcall(drawTempLeadershipTab)
            if not okTl then
                imgui.TextColored(col_warn, 'Temp leadership UI error:')
                imgui.TextWrapped(tostring(errTl))
                print('[Report Desk] temp leadership UI: ' .. tostring(errTl))
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xD1\xEF\xF0\xE0\xE2\xEA\xE0') .. '##tab_help') then
            local okEt, errEt = pcall(drawExactTimeTab)
            if not okEt then
                imgui.TextColored(col_warn, 'Help tab UI error:')
                imgui.TextWrapped(tostring(errEt))
                print('[Report Desk] help tab UI: ' .. tostring(errEt))
            end
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xCD\xE0\xF1\xF2\xF0\xEE\xE9\xEA\xE8') .. '##tab_set') then
            local okSet, errSet = pcall(drawSettingsTab)
            if not okSet then
                imgui.TextColored(col_warn, 'Settings UI error:')
                imgui.TextWrapped(tostring(errSet))
                print('[Report Desk] settings UI: ' .. tostring(errSet))
            end
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end

    if footH > 0 then
        imgui.EndChild()
        drawDeskAdminRoleBadgeFooter(footH)
    end

    deskInputState.chatTabActive = chatTabActive and true or false
    if not chatTabActive then
        deskInputState.replyInputActive = false
    end

    imgui.End()
    if not showWindow[0] then
        closeDeskWindow()
        return
    end
    updateDeskInputCapture()
end

function installDeskD3DHandlers()
    if type(deskCache) ~= 'table' or deskCache.d3dHandlersInstalled then return end
    uninstallDeskD3DHandlers()
    deskCache.d3dLostHandler = function()
        if not catWarmup.inited then return end
        pcall(deskTexPipeline.halt, deskTex)
        catWarmup.inited = false
    end
    deskCache.d3dResetHandler = function()
        pcall(ensureDeskCatalogWarmup)
        if skinUiTabActive then pcall(skinsOnTabEnter) end
        if deskVeh and deskVeh.tabActive then pcall(deskVeh.onTabEnter) end
    end
    if addEventHandler then
        addEventHandler('onD3DDeviceLost', deskCache.d3dLostHandler)
        addEventHandler('onD3DDeviceReset', deskCache.d3dResetHandler)
    end
    deskCache.d3dHandlersInstalled = true
end

function uninstallDeskD3DHandlers()
    if type(deskCache) ~= 'table' then return end
    if deskCache.d3dLostHandler and removeEventHandler then
        pcall(removeEventHandler, 'onD3DDeviceLost', deskCache.d3dLostHandler)
    end
    if deskCache.d3dResetHandler and removeEventHandler then
        pcall(removeEventHandler, 'onD3DDeviceReset', deskCache.d3dResetHandler)
    end
    deskCache.d3dLostHandler = nil
    deskCache.d3dResetHandler = nil
    deskCache.d3dHandlersInstalled = false
end

function installDeskUiFrames()
    if type(deskCache) ~= 'table' or deskCache.deskUiFramesInstalled then return end
    if type(imgui) ~= 'table' or type(imgui.OnFrame) ~= 'function' then return end

    if rawget(_G, '__desk_imgui_init_hooked') ~= true and imgui.OnInitialize then
        rawset(_G, '__desk_imgui_init_hooked', true)
        imgui.OnInitialize(function()
            local io = imgui.GetIO()
            io.IniFilename = nil
            if imgui.ConfigFlags and imgui.ConfigFlags.NoMouseCursorChange then
                io.ConfigFlags = bit.bor(io.ConfigFlags, imgui.ConfigFlags.NoMouseCursorChange)
            end
            if not styleApplied then
                pcall(applyModernDarkStyle)
                styleApplied = true
            end
            pcall(ensureDeskCatalogWarmup)
        end)
    end
    pcall(installDeskD3DHandlers)

    local function trackDeskUiFrame(frame)
        if type(deskCache.deskUiFrames) ~= 'table' then deskCache.deskUiFrames = {} end
        deskCache.deskUiFrames[#deskCache.deskUiFrames + 1] = frame
        return frame
    end

    local function setupDeskFrame(frame, hideCursor, lockPlayer)
        frame.HideCursor = hideCursor and true or false
        frame.LockPlayer = lockPlayer and true or false
        return trackDeskUiFrame(frame)
    end

    -- Превью каталога грузятся в drawSkinsTab / deskVeh.drawTab (лениво, по видимым ячейкам).

    setupDeskFrame(imgui.OnFrame(
        function() return cheatState.airbreak end,
        function(self)
            self.HideCursor = true
            self.LockPlayer = false
            pcall(cheatsTickAirbreakMovement)
            pcall(drawAirbreakHudOverlay)
        end
    ), true, false)

    deskCache.catalogFlushFrame = setupDeskFrame(imgui.OnFrame(
        function() return deskCache.catalogTexFlushPending == true end,
        function()
            pcall(deskFlushCatalogTexPending)
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            return type(skinsPrewarmActive) == 'function' and skinsPrewarmActive()
        end,
        function(self)
            pcall(skinsPrewarmTick)
            self.HideCursor = true
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if not showWindow[0] then return false end
            return type(deskCatalogTabActive) == 'function' and deskCatalogTabActive()
        end,
        function(self)
            pcall(deskCatalogTexTick)
            self.HideCursor = true
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            pcall(ensureCheatsSettings)
            if type(settings) ~= 'table' or type(settings.cheats) ~= 'table' then return false end
            return settings.cheats.show_hud ~= false
        end,
        function(self)
            pcall(drawCheatsHudOverlay)
            local hudWants = type(cheatsHudWantsInput) == 'function' and cheatsHudWantsInput()
            self.HideCursor = deskMimguiHideCursor(hudWants)
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            if type(settings) ~= 'table' or settings.spectate_vehicle_hud == false then return false end
            if type(deskSpectateStats) ~= 'table' or not deskSpectateStats.shouldShowVehicleHud then return false end
            local okShow, show = pcall(deskSpectateStats.shouldShowVehicleHud, settings)
            return okShow and show == true
        end,
        function(self)
            if deskSpectateStats.drawVehicleHud then
                pcall(deskSpectateStats.drawVehicleHud, settings)
            end
            self.HideCursor = deskMimguiHideCursor()
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            if type(settings) ~= 'table' or settings.spectate_keys_hud == false then return false end
            if type(deskSpectateStats) ~= 'table' or not deskSpectateStats.shouldShowKeysHud then return false end
            local okShow, show = pcall(deskSpectateStats.shouldShowKeysHud, settings)
            return okShow and show == true
        end,
        function(self)
            if deskSpectateStats.drawKeysHud then
                pcall(deskSpectateStats.drawKeysHud, settings)
            end
            self.HideCursor = deskMimguiHideCursor(
                type(deskSpectateStats.wantsKeysHudInput) == 'function'
                    and deskSpectateStats.wantsKeysHudInput())
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            return deskSpSpectateOverlayVisible()
        end,
        function(self)
            pcall(drawDeskSpSpectateOverlay)
            self.HideCursor = deskMimguiHideCursor()
            self.LockPlayer = false
        end
    ), true, false)

    deskCache.deskWindowFrame = setupDeskFrame(imgui.OnFrame(
        function()
            if not sessionLive then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            return showWindow[0]
        end,
        function(self)
            self.LockPlayer = deskOpenLocksPlayer()
            self.HideCursor = false
            local ok, err = pcall(drawMainWindow)
            if not ok then
                print('[Report Desk] UI: ' .. tostring(err))
                closeDeskWindow()
            end
        end
    ), false, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if not sessionLive then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            return type(adminPunishHasPending) == 'function' and adminPunishHasPending()
        end,
        function(self)
            self.HideCursor = true
            self.LockPlayer = false
            pcall(drawAdminPunishOverlay)
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if not sessionLive then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            return type(exactTimeShouldDraw) == 'function' and exactTimeShouldDraw()
        end,
        function(self)
            self.HideCursor = false
            self.LockPlayer = false
            pcall(drawExactTimeWindow)
        end
    ), false, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            return cheatState.marker.active
        end,
        function()
            pcall(drawMarkerHudOverlay)
        end
    ), true, false)

    -- Один раз за кадр, после всех HUD (hover уже известен).
    setupDeskFrame(imgui.OnFrame(
        function()
            if not sessionLive then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            return true
        end,
        function(self)
            self.HideCursor = deskMimguiHideCursor()
            self.LockPlayer = false
            pcall(updateMimguiGameInputPassthrough)
        end
    ), true, false)

    deskCache.deskUiFramesInstalled = true
end

pcall(installDeskUiFrames)

-- Draw Desk Sp Spectate Overlay
function drawDeskSpSpectateOverlay()
    if type(settings) ~= 'table' then return end
    if type(deskSpectateStats) ~= 'table' then return end
    if deskSpectateStats.shouldShowHud then
        local okShow, show = pcall(deskSpectateStats.shouldShowHud, settings)
        if okShow and show then
            pcall(deskSpectateStats.drawOverlay, settings)
        end
    end
    if deskSpectateStats.drawSpMenu then
        pcall(deskSpectateStats.drawSpMenu, settings)
    end
end

-- Desk hook/helper.
function deskCheckerHudVisible()
    return type(checkerHudVisible) == 'function' and checkerHudVisible() == true
end

-- Desk hook/helper.
function deskSpSpectateOverlayVisible()
    if not sessionLive then return false end
    if type(settings) ~= 'table' then return false end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
    local tid = -1
    if deskSpectateStats.getTargetId then
        local ok, v = pcall(deskSpectateStats.getTargetId)
        if ok then tid = tonumber(v) or -1 end
    end
    if tid >= 0 then return true end
    if type(deskSpectateStats) == 'table' and deskSpectateStats.shouldShowHud then
        local okShow, show = pcall(deskSpectateStats.shouldShowHud, settings)
        if okShow and show then return true end
    end
    return false
end

function uninstallDeskUiFrames()
    if type(deskCache) ~= 'table' then return end
    local frames = deskCache.deskUiFrames
    if type(frames) == 'table' then
        for i = 1, #frames do
            local f = frames[i]
            if f and type(f.Unsubscribe) == 'function' then
                pcall(function() f:Unsubscribe() end)
            end
        end
    end
    deskCache.deskUiFrames = nil
    deskCache.deskWindowFrame = nil
    deskCache.catalogFlushFrame = nil
    deskCache.deskUiFramesInstalled = false
end

-- Desk hook/helper.
function deskPassesGameKey(wparam)
    if deskCache.gamePassVks[wparam] then return true end
    local hk = (type(settings) == 'table' and settings.hotkey) or (vkeys and vkeys.VK_F7) or 0x76
    if wparam == hk then return true end
    if showWindow[0] and vkeys and wparam == vkeys.VK_F11 then return true end
    if vkeys then
        if wparam == vkeys.VK_CONTROL or wparam == vkeys.VK_SHIFT
            or wparam == vkeys.VK_MENU or wparam == vkeys.VK_LWIN
            or wparam == vkeys.VK_RWIN then
            return true
        end
    end
    return false
end

_G.deskPassesGameKey = deskPassesGameKey

-- Apply Cheat Key Capture
function applyCheatKeyCapture(msg, wparam, lparam)
    if not deskCache.cheatCapture then return false end
    if os.clock() - deskCache.cheatCaptureAt < PF.HOTKEY_CAPTURE_GRACE then return true end
    local prefix = CHEAT_BIND_PREFIX[deskCache.cheatCapture]
    if not prefix then
        finishDeskBindCapture()
        return true
    end
    wparam = tonumber(wparam) or 0
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        if wparam == vkeys.VK_ESCAPE then
            finishDeskBindCapture()
        elseif wparam == vkeys.VK_DELETE or wparam == vkeys.VK_BACK then
            cheatClearBind(prefix)
            finishDeskBindCapture()
        else
            local capKey = deskBindCaptureKeyFromKeyboard(wparam)
            if capKey then
                deskCache.bindCapVk = capKey
                if deskBindMouseCommitsOnDown(capKey) then
                    deskBindCapSaveCheat(prefix)
                end
            end
        end
        return true
    end
    if msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
        local capKey = deskBindCaptureKeyFromKeyboard(wparam)
        deskBindCapTrySaveOnUp(capKey, deskBindCapSaveCheat, prefix)
        return true
    end
    local mvk = parseMouseButtonVk(msg, wparam, lparam)
    if mvk then
        if deskBindMouseUiClickVk(mvk)
                and os.clock() < (tonumber(deskCache.bindCapIgnoreMouseUntil) or 0) then
            return true
        end
        deskCache.bindCapVk = mvk
        if deskBindMouseCommitsOnDown(mvk) then
            deskBindCapSaveCheat(prefix)
        end
        return true
    end
    local relMv = parseMouseButtonReleaseVk(msg, wparam, lparam)
    if relMv then
        if deskBindMouseUiClickVk(relMv)
                and os.clock() < (tonumber(deskCache.bindCapIgnoreMouseUntil) or 0) then
            return true
        end
        deskBindCapTrySaveOnUp(relMv, deskBindCapSaveCheat, prefix)
        return true
    end
    return true
end

-- XButton index from wparam (HIWORD on Windows).
local function xbuttonIndex(wparam)
    wparam = tonumber(wparam) or 0
    local hi = bit.rshift(wparam, 16)
    if hi == 1 or hi == 2 then return hi end
    local lo = bit.band(wparam, 0xFFFF)
    if lo == 1 or lo == 2 then return lo end
    return nil
end

-- Парсинг данных с сервера/чата.
function parseMouseButtonVk(msg, wparam, lparam)
    if msg == deskCache.wm.LBUTTONDOWN then return vkeys.VK_LBUTTON end
    if msg == deskCache.wm.RBUTTONDOWN then return vkeys.VK_RBUTTON end
    if msg == deskCache.wm.MBUTTONDOWN then return vkeys.VK_MBUTTON end
    if msg == deskCache.wm.XBUTTONDOWN then
        local btn = xbuttonIndex(wparam)
        if btn == 1 then return vkeys.VK_XBUTTON1 end
        if btn == 2 then return vkeys.VK_XBUTTON2 end
    end
    return nil
end

-- Парсинг данных с сервера/чата.
function parseMouseButtonReleaseVk(msg, wparam, lparam)
    if msg == 0x0202 then return vkeys.VK_LBUTTON end
    if msg == 0x0205 then return vkeys.VK_RBUTTON end
    if msg == 0x0209 then return vkeys.VK_MBUTTON end
    if msg == 0x020C then
        local btn = xbuttonIndex(wparam)
        if btn == 1 then return vkeys.VK_XBUTTON1 end
        if btn == 2 then return vkeys.VK_XBUTTON2 end
    end
    return nil
end

-- Apply Hotkey Capture
function applyHotkeyCapture(msg, wparam, lparam)
    if not deskCache.hotkeyCapture then return false end
    if os.clock() - deskCache.hotkeyCaptureAt < PF.HOTKEY_CAPTURE_GRACE then
        return true
    end
    wparam = tonumber(wparam) or 0
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        if wparam == vkeys.VK_ESCAPE then
            finishDeskBindCapture()
        elseif wparam == vkeys.VK_DELETE or wparam == vkeys.VK_BACK then
            settings.hotkey = vkeys.VK_F7
            markDirtySettings()
            finishDeskBindCapture()
        else
            local capKey = deskBindCaptureKeyFromKeyboard(wparam)
            if capKey then
                deskCache.bindCapVk = capKey
                if deskBindMouseCommitsOnDown(capKey) then
                    deskBindCapSaveHotkey(capKey)
                end
            end
        end
        return true
    end
    if msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
        local capKey = deskBindCaptureKeyFromKeyboard(wparam)
        deskBindCapTrySaveOnUp(capKey, deskBindCapSaveHotkey, capKey)
        return true
    end
    local mvk = parseMouseButtonVk(msg, wparam, lparam)
    if mvk then
        if deskBindMouseUiClickVk(mvk)
                and os.clock() < (tonumber(deskCache.bindCapIgnoreMouseUntil) or 0) then
            return true
        end
        deskCache.bindCapVk = mvk
        if deskBindMouseCommitsOnDown(mvk) then
            deskBindCapSaveHotkey(mvk)
        end
        return true
    end
    local relMv = parseMouseButtonReleaseVk(msg, wparam, lparam)
    if relMv then
        if deskBindMouseUiClickVk(relMv)
                and os.clock() < (tonumber(deskCache.bindCapIgnoreMouseUntil) or 0) then
            return true
        end
        deskBindCapTrySaveOnUp(relMv, deskBindCapSaveHotkey, relMv)
        return true
    end
    return true
end

if vkeys and vkeys.VK_SNAPSHOT then deskCache.gamePassVks[vkeys.VK_SNAPSHOT] = true end
if vkeys and vkeys.VK_F12 then deskCache.gamePassVks[vkeys.VK_F12] = true end
if vkeys and vkeys.VK_F8 then deskCache.gamePassVks[vkeys.VK_F8] = true end

local function installDeskWmHandlers()
    if type(registerDeskChatWmHandler) == 'function' then
        registerDeskChatWmHandler()
    end
    deskWmDispatch.register('admin_punish', 101, function(msg, wparam, lparam)
        if type(tryHandleAdminPunishBindMessage) == 'function'
                and tryHandleAdminPunishBindMessage(msg, wparam, lparam) then
            return true
        end
    end)

    deskWmDispatch.register('hotkey', 100, function(msg, wparam, lparam)
        if tryHandleDeskHotkeyMessage(msg, wparam, lparam) then
            return true
        end
    end)

    deskWmDispatch.register('main', 50, function(msg, wparam, lparam)
        if deskCache.adminPunishBindCapture then
            if type(applyAdminPunishBindCapture) == 'function'
                    and applyAdminPunishBindCapture(msg, wparam, lparam) then
                consumeWindowMessage(true, true, true)
                return true
            end
        elseif deskCache.cheatCapture then
            if applyCheatKeyCapture(msg, wparam, lparam) then
                consumeWindowMessage(true, true, true)
                return true
            end
        else
            local mvk = parseMouseButtonVk(msg, wparam, lparam)
            if mvk and MOUSE_BIND_VKS[mvk] then
                deskCache.cheatBindPrev[mvk] = false
            end
            local relMv = parseMouseButtonReleaseVk(msg, wparam, lparam)
            if relMv and MOUSE_BIND_VKS[relMv] then
                deskCache.hotkeyPrev[relMv] = false
                deskCache.cheatBindPrev[relMv] = false
            end
        end
        if deskCache.hotkeyCapture then
            if applyHotkeyCapture(msg, wparam, lparam) then
                consumeWindowMessage(true, true, true)
                return true
            end
        end

        if not showWindow[0] then return end

        if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
            if wparam == vkeys.VK_F11 then
                if not deskCache.deskFsKeyPrev then
                    deskCache.deskFsKeyPrev = true
                    pcall(deskToggleWindowFullscreen)
                end
                consumeWindowMessage(true, false, true)
                return true
            end
        elseif msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
            if wparam == vkeys.VK_F11 then
                deskCache.deskFsKeyPrev = false
            end
        end

        if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN or msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
            if wparam == vkeys.VK_ESCAPE then
                if deskImguiTypingActive() then
                    return
                end
                if type(deskSampDialogActive) == 'function' and deskSampDialogActive() then
                    return
                end
                if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
                    consumeWindowMessage(true, false, true)
                    return true
                end
                if msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
                    if deskCache.hotkeyCapture or deskCache.cheatCapture or deskCache.adminPunishBindCapture then
                        cancelDeskBindCapture()
                    else
                        closeDeskWindow()
                    end
                    consumeWindowMessage(true, false, true)
                    return true
                end
            end
        end
    end)
end

installDeskWmHandlers()

-- Try Intercept Split Ans Command
function tryInterceptSplitAnsCommand(command)
    if type(outbound) ~= 'table' then return false end
    command = trim(command or '')
    if command == '' then return false end
    local id, body = command:match('^/?ans%s+(%d+)%s+(.+)$')
    if not id or not body then return false end
    body = normalizeOutboundBody(body)
    local idNum = tonumber(id)
    if not idNum or not ansReplyNeedsSplit(idNum, body) then return false end

    local liveNick = liveNickForPlayerId(idNum)
    if wasOutboundEchoHandled(idNum, body, liveNick) then
        local echoTk0 = outboundEchoThreadKey(idNum, body, liveNick)
        local th0 = echoTk0 and threads[echoTk0]
        if th0 and threadFindOutgoingMessage(th0, body, { self = true }) then
            return true
        end
    end

    if outbound.pending then
        local p = outbound.pending
        if tonumber(p.id) == idNum and os.clock() - (p.at or 0) < PENDING_OUTBOUND_SEC then
            local pNk = p.nickKey or ''
            local lNk = nickKey(liveNick)
            if pNk == '' or lNk == '' or pNk == lNk then
                return true
            end
        end
    end

    refreshMyNick()
    local t, threadKey = resolveThreadForPlayerId(idNum, liveNick)
    if t and threadKey then
        if not threadFindOutgoingMessage(t, body, { self = true }) then
            threadApplyOutgoing(t, threadKey, body, { self = true })
        end
        setPendingOutbound(t, body, idNum, true)
    end
    transmitAnsWire(idNum, body, { threadKey = threadKey, markEcho = true })
    return true
end

-- Handle Outgoing Ans Command
function handleOutgoingAnsCommand(message)
    if type(outbound) ~= 'table' or type(threads) ~= 'table' then return end
    if not message then return end
    message = trim(message)
    local id, body = message:match('^/?ans%s+(%d+)%s+(.+)$')
    if not id or not body then return end
    body = normalizeOutboundBody(body)
    local idNum = tonumber(id)
    if not idNum or body == '' then return end

    local liveNick = liveNickForPlayerId(idNum)

    if outbound.pending then
        local p = outbound.pending
        if tonumber(p.id) == idNum and os.clock() - (p.at or 0) < PENDING_OUTBOUND_SEC then
            local pNk = p.nickKey or ''
            local lNk = nickKey(liveNick)
            if pNk == '' or lNk == '' or pNk == lNk then
                local tk = p.threadKey
                local th = tk and threads[tk]
                local wantBody = normalizeOutboundBody(p.body)
                if th and wantBody ~= '' and not threadFindOutgoingMessage(th, wantBody, { self = true }) then
                    threadApplyOutgoing(th, tk, wantBody, { self = true })
                end
                if th and (wantBody == '' or threadFindOutgoingMessage(th, wantBody, { self = true })) then
                    markOutboundEchoHandled(idNum, body, tk, liveNick)
                end
                if p.split and body ~= wantBody then
                    return
                end
                clearPendingOutbound()
                return
            end
        end
    end

    local echoTk = outboundEchoThreadKey(idNum, body, liveNick)
    if echoTk and threads[echoTk] then
        local th = threads[echoTk]
        if not threadFindOutgoingMessage(th, body, { self = true }) then
            threadApplyOutgoing(th, echoTk, body, { self = true })
        end
        markOutboundEchoHandled(idNum, body, echoTk, liveNick)
        clearPendingOutbound()
        return
    end

    if wasOutboundEchoHandled(idNum, body, liveNick) then
        local echoTk2 = outboundEchoThreadKey(idNum, body, liveNick)
        local th2 = echoTk2 and threads[echoTk2]
        if th2 and threadFindOutgoingMessage(th2, body, { self = true }) then
            return
        end
    end

    refreshMyNick()
    local t, key = resolveThreadForPlayerId(idNum, liveNick)
    if t and key and not threadFindOutgoingMessage(t, body, { self = true }) then
        threadApplyOutgoing(t, key, body, { self = true })
        markOutboundEchoHandled(idNum, body, key, liveNick)
    end
end

