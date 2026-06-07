--[[ Модуль: ImGui окно Report Desk (список, чат, настройки). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

-- Draw Settings Card Begin
function drawSettingsCardBegin(id, h)
end

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
    imgui.Dummy(imgui.ImVec2(0, 6))
    imgui.TextColored(col_muted, uiText(title))
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Draw Settings Hotkey Bind
function drawSettingsHotkeyBind()
    local hkPreview = deskCache.hotkeyCapture and cheatLiveBindPreview() or vkToLabel(settings.hotkey or vkeys.VK_F7)
    local hkPresets = {
        { 'F7', vkeys.VK_F7 },
        { 'F8', vkeys.VK_F8 },
        { 'M4', vkeys.VK_XBUTTON1 },
        { 'M5', vkeys.VK_XBUTTON2 },
        { uiText('\xCF\xCA\xCC'), vkeys.VK_RBUTTON },
    }
    drawDeskBindRow({
        label = '\xCE\xF2\xEA\xF0\xFB\xF2\xFC \xEE\xEA\xED\xEE',
        previewText = hkPreview,
        capturing = deskCache.hotkeyCapture,
        keyCapId = '##hk_cap',
        onCapture = beginHotkeyCapture,
        popupId = '##desk_hk_presets',
        menuBtnId = '##hk_menu',
        chipPrefix = 'hk',
        drawPopup = function()
            if imgui.Selectable(uiText('\xCD\xE0\xE7\xED\xE0\xF7\xE8\xF2\xFC \xE2\xF0\xF3\xF7\xED\xF3\xFE') .. '##hk_man') then
                beginHotkeyCapture()
                if imgui.CloseCurrentPopup then imgui.CloseCurrentPopup() end
            end
            if imgui.Selectable(uiText('\xD1\xE1\xF0\xEE\xF1\xE8\xF2\xFC \xED\xE0 F7') .. '##hk_rst') then
                settings.hotkey = vkeys.VK_F7
                markDirtySettings()
                if imgui.CloseCurrentPopup then imgui.CloseCurrentPopup() end
            end
        end,
        presets = hkPresets,
        onPresetPick = function(vk)
            settings.hotkey = vk
            markDirtySettings()
        end,
    })
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

    if opts.nickCol then
        subCol = opts.nickCol
    end
    if opts.profanityHighlight then
        bg = col_bubble_punish
    end

    local profanityHighlight = opts.profanityHighlight == true
    local scenarioBody = ''
    local quickBtns = {}
    if not opts.noQuickButtons and reporter and messageShowsScenarioButtons(m) then
        scenarioBody = messageBodyForScenarios(m)
        if scenarioBody == '' then scenarioBody = line end
        quickBtns = collectQuickButtonsForMessage(scenarioBody)
    end
    local watchBtns, replyBtns = splitQuickButtons(quickBtns)
    local watchInlineW = quickButtonsInlineWidth(watchBtns)
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
    local maxBubbleW = math.max(64, rowW - padSide * 2 - watchInlineW)
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

    if #watchBtns > 0 and not alignRight then
        local watchBtnY = localY + topPad + authorH + math.max(0, (bubbleH - QUICK_BTN_H) * 0.5)
        local watchBtnX = localX + padSide + bubbleW + 8
        drawInlineWatchButtons(watchBtns, localX, localY, watchBtnX, watchBtnY, scenarioBody, reporter, msgIdx)
    end

    if #replyBtnRows > 0 then
        local btnRowY = topPad + authorH + bubbleH + CHAT_TIME_GAP + timeBlockH + QUICK_BTN_BLOCK_TOP
        if replyBtnBlockH > 0 then
            dl:AddRectFilled(
                imgui.ImVec2(pos.x + padSide - 4, pos.y + btnRowY - 3),
                imgui.ImVec2(pos.x + rowW - padSide + 4, pos.y + btnRowY + replyBtnBlockH + 2),
                toU32(imgui.ImVec4(0.14, 0.14, 0.18, 0.42)),
                6)
        end
        drawQuickScenarioButtons(replyBtns, localX, localY, btnRowY, rowW, padSide, scenarioBody, reporter, msgIdx)
    end

    sealChatMessageRow(localX, localY, blockH)
end

-- Chat Header Nick Color
function chatHeaderNickColor(pid, online)
    if online and pid >= 0 then
        if deskSpectateStats.getEntry and deskSpectateStats.nickColorFor then
            local e = deskSpectateStats.getEntry(pid)
            if e then
                return deskSpectateStats.nickColorFor(pid, e)
            end
        end
        return col_label
    end
    return imgui.ImVec4(0.82, 0.42, 0.42, 1.0)
end

-- Draw Chat Header
function drawChatHeader(t)
    local liveId = findPlayerIdByNick(t.nick)
    if liveId ~= nil and t.id ~= liveId then
        t.lastId = t.id
        t.id = liveId
    end

    local online = liveId ~= nil
    local pid = tonumber(liveId or t.id) or -1
    local nickCol = chatHeaderNickColor(pid, online)

    local padL = 12
    local btnH = 28
    local gap = 6
    local lineH = imgui.GetTextLineHeight()
    local specLbl = '\xD1\xEB\xE5\xE4\xE8\xF2\xFC'
    local modTargetId = threadActionTargetId(t)

    local hdrBtns = {}
    if pid >= 0 then
        hdrBtns[#hdrBtns + 1] = {
            lbl = specLbl,
            id = 'sp',
            w = headerActionBtnWidth(specLbl),
            tip = '/sp ' .. pid,
            fn = function()
                sendGameCmd('sp ' .. pid)
            end,
        }
    end
    if modTargetId then
        hdrBtns[#hdrBtns + 1] = {
            lbl = LBL_ACT_SLAP,
            id = 'slap',
            w = headerActionBtnWidth(LBL_ACT_SLAP),
            tip = '/slap ' .. modTargetId,
            fn = function() sendSlapPlayer(modTargetId) end,
        }
        local trTip = getLocalAdminLevel() <= 2
            and ('/a /tr ' .. modTargetId)
            or ('/tr ' .. modTargetId)
        hdrBtns[#hdrBtns + 1] = {
            lbl = LBL_ACT_TR,
            id = 'tr',
            w = headerActionBtnWidth(LBL_ACT_TR),
            tip = trTip,
            fn = function() sendTrPlayer(modTargetId) end,
        }
    end
    local btnsTotalW = 0
    for i, b in ipairs(hdrBtns) do
        btnsTotalW = btnsTotalW + b.w + (i > 1 and gap or 0)
    end

    imgui.PushStyleColor(imgui.Col.ChildBg, col_header)
    imgui.BeginChild('##chat_hdr', imgui.ImVec2(-1, CHAT_HEADER_H), false)

    local rowY = math.floor((CHAT_HEADER_H - lineH) * 0.5 + 0.5)
    local btnY = math.floor((CHAT_HEADER_H - btnH) * 0.5 + 0.5)
    imgui.SetCursorPos(imgui.ImVec2(padL, rowY))
    imgui.TextColored(nickCol, uiText(t.nick or '?'))
    imgui.SameLine(0, 8)
    imgui.TextColored(col_muted2, uiText('[' .. tostring(pid >= 0 and pid or '?') .. ']'))

    local rmax = imgui.GetWindowContentRegionMax()
    local btnX = rmax.x - btnsTotalW
    if btnX < padL + 80 then btnX = padL + 80 end
    imgui.SetCursorPos(imgui.ImVec2(btnX, btnY))
    if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
    for i, b in ipairs(hdrBtns) do
        if i > 1 then imgui.SameLine(0, gap) end
        pushPlayerActionBtnStyle()
        if imgui.Button(uiText(b.lbl) .. '##hdr_' .. b.id, imgui.ImVec2(b.w, btnH)) then
            b.fn()
        end
        if imgui.IsItemHovered() and imgui.SetTooltip and b.tip then
            imgui.SetTooltip(uiText(b.tip))
        end
        popPlayerActionBtnStyle()
    end
    if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end

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
function deskComposerHeight(availW, items)
    local pad = 20
    local h = pad + COMPOSER_INPUT_H + COMPOSER_ROW_GAP
    local rows = deskComposerQuickRowCount(availW, items)
    if rows > 0 then
        h = h + rows * COMPOSER_QUICK_H + math.max(0, rows - 1) * COMPOSER_QUICK_GAP
    end
    return math.max(86, h)
end

-- Composer Quick Btn Width
function composerQuickBtnWidth(label)
    local w = imgui.CalcTextSize(uiText(label or '?')).x + 20
    if w < 52 then w = 52 end
    if w > 120 then w = 120 end
    return w
end

-- Push Composer Quick Btn Style
function pushComposerQuickBtnStyle(enabled)
    if enabled then
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
end

-- Pop Composer Quick Btn Style
function popComposerQuickBtnStyle()
    imgui.PopStyleVar()
    imgui.PopStyleColor(4)
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
        pushComposerQuickBtnStyle(canSend)
        if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
        local clicked = imgui.Button(label .. '##' .. (item.id or i), imgui.ImVec2(bw, COMPOSER_QUICK_H))
        if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end
        popComposerQuickBtnStyle()
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

    if focusReplyNext and imgui.SetKeyboardFocusHere then
        imgui.SetKeyboardFocusHere(0)
        deskInputState.keyboardStickyUntil = os.clock() + 0.15
        focusReplyNext = false
    end

    local canSend = getSelectedThread() ~= nil
    local flags = 0
    if imgui.InputTextFlags and imgui.InputTextFlags.EnterReturnsTrue then
        flags = imgui.InputTextFlags.EnterReturnsTrue
    end

    local gap = 8
    local sendSz = COMPOSER_SEND_SZ
    local availW = imgui.GetContentRegionAvail().x
    local inputW = math.max(80, availW - sendSz - gap)
    local hint = uiText('\xCE\xF2\xE2\xE5\xF2 \xE2 \xF0\xE5\xEF\xEE\xF0\xF2...')

    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 7))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08, 0.08, 0.10, 1.0))
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.22, 0.20, 0.28, 0.45))

    imgui.PushItemWidth(inputW)
    local sent
    if imgui.InputTextWithHint then
        sent = imgui.InputTextWithHint('##reply', hint, replyBuf, sizeof(replyBuf), flags)
    else
        sent = imgui.InputText('##reply', replyBuf, sizeof(replyBuf), flags)
    end
    do
        local replyActive = false
        if imgui.IsItemActive then replyActive = imgui.IsItemActive() end
        if not replyActive and imgui.IsItemFocused then replyActive = imgui.IsItemFocused() end
        if replyActive or (imgui.IsItemClicked and imgui.IsItemClicked(0)) then
            deskInputState.replyFocused = true
        end
    end
    imgui.PopItemWidth()
    imgui.PopStyleColor(2)

    imgui.SameLine(0, gap)
    local rowY = imgui.GetCursorPosY()
    imgui.SetCursorPosY(rowY + math.max(0, (COMPOSER_INPUT_H - sendSz) * 0.5))

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

    if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
    local sendClicked = imgui.Button('>##desk_send', imgui.ImVec2(sendSz, sendSz))
    if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end

    imgui.PopStyleVar()
    imgui.PopStyleColor(4)

    if imgui.IsItemHovered() and canSend then
        imgui.SetTooltip(uiText('\xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC (Enter)'))
    end

    if canSend and (sendClicked or sent) then
        if sendReplyToSelected() then
            ffi.copy(replyBuf, '')
            focusReplyNext = true
            deskInputState.replyFocused = true
        end
    end

    drawComposerQuickRow(quickItems, canSend, availW)

    imgui.PopStyleVar(2)
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
        selectedId = t.id
        t.unread = 0
        chatScrollToBottom = false
        deskInputState.chatFollowBottom = true
        requestChatSnapBottom(key)
        focusReplyNext = true
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

    local liveId = playerNickToId[nickKey(t.nick)]

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

-- Fill Rule Editor
function fillRuleEditor(idx)
    local r = rules[idx]
    if not r then return end
    setInputBuf(editRuleName, r.name or '')
    syncRuleKwEditFromRule(r)
    setInputBuf(editRulePayload, r.payload or '')
    editRuleEnabled[0] = r.enabled ~= false
    rulesEditorDirty = false
end

-- Apply Rule Editor
function applyRuleEditor()
    if selectedRuleIdx < 1 or selectedRuleIdx > #rules then return false end
    syncRuleKeywordsFromBulkBuf()
    local name = readInputBuf(editRuleName)
    local payload = readInputBuf(editRulePayload)
    if name == '' or payload == '' then return false end
    local prev = rules[selectedRuleIdx]
    local kw = {}
    for _, k in ipairs(ruleKwEdit) do
        local part = trim(k)
        if part ~= '' then kw[#kw + 1] = part end
    end
    if #kw == 0 then return false end
    rules[selectedRuleIdx] = {
        name = name,
        enabled = editRuleEnabled[0],
        match = 'exact',
        keywords = kw,
        action = 'ans_text',
        payload = payload,
        cooldown = math.max(5, tonumber(prev and prev.cooldown) or 60),
        mode = 'instant',
        priority = 0,
        skip_if_report_id = false,
    }
    markDirtySettings()
    rulesEditorDirty = false
    return true
end

-- Try Add Keywords From Bulk
function tryAddKeywordsFromBulk()
    local block = trim(readInputBuf(ruleKwBulk))
    if block == '' then return 0 end
    block = block:gsub('[\r\n]+', ',')
    return addKeywordsToRuleEdit(parseKeywordList(block))
end

-- Run Rule Match Test
function runRuleMatchTest()
    local sample = trim(readInputBuf(ruleTestBuf))
    if sample == '' then
        setInputBuf(ruleTestResult, uiText('\xE2\xE2\xE5\xE4\xE8\xF2\xE5 \xF2\xE5\xEA\xF1\xF2'))
        return
    end
    local rule = findMatchingRule(sample)
    if rule then
        setInputBuf(ruleTestResult, (rule.name or '?') .. ' [' .. ruleMatchModeLabel(rule.match) .. ']')
    else
        setInputBuf(ruleTestResult, uiText('\xED\xE5\xF2 \xF1\xEE\xE2\xEF\xE0\xE4\xE5\xED\xE8\xFF'))
    end
end

-- Sync Rule Editor If Dirty
function syncRuleEditorIfDirty()
    if not rulesEditorDirty then return end
    if #rules < 1 then
        rulesEditorDirty = false
        return
    end
    if selectedRuleIdx < 1 or selectedRuleIdx > #rules then
        rulesEditorDirty = false
        return
    end
    applyRuleEditor()
end

-- Mark Rule Editor Dirty
function markRuleEditorDirty()
    rulesEditorDirty = true
end

-- Fill Scenario Editor
function fillScenarioEditor(idx)
    local sc = quickScenarios[idx]
    if not sc then return end
    setInputBuf(editScLabel, sc.label or '')
    setInputBuf(editScReply, sc.reply or '')
    syncScKwEditFromScenario(sc)
    editScEnabled[0] = sc.enabled ~= false
    editScWatch[0] = sc.action == 'watch'
    editScSkipReportId[0] = sc.skip_if_report_id ~= false
    editScPriority[0] = tonumber(sc.priority) or 0
    scenariosEditorDirty = false
end

-- Сброс/отправка очереди.
function flushScenarioKeywordsPreview()
    if selectedScenarioIdx < 1 or selectedScenarioIdx > #quickScenarios then return end
    local sc = quickScenarios[selectedScenarioIdx]
    if not sc then return end
    local kw = {}
    for _, k in ipairs(scKwEdit) do
        local part = trim(k)
        if part ~= '' then kw[#kw + 1] = part end
    end
    sc.keywords = kw
    markDirtySettings()
    bumpScenariosGen()
end

-- Сброс/отправка очереди.
function flushScenarioEditorToScenario()
    if selectedScenarioIdx < 1 or selectedScenarioIdx > #quickScenarios then return end
    local sc = quickScenarios[selectedScenarioIdx]
    if not sc then return end
    local label = readInputBuf(editScLabel)
    if label ~= '' then
        sc.label = label
    elseif trim(sc.label or '') == '' then
        sc.label = '\xD1\xE1\xE5\xE7 \xED\xE0\xE7\xE2\xE0\xED\xE8\xFF'
    end
    sc.reply = readInputBuf(editScReply)
    sc.enabled = editScEnabled[0]
    sc.match = 'contains'
    sc.priority = tonumber(editScPriority[0]) or 0
    sc.action = editScWatch[0] and 'watch' or 'reply'
    sc.skip_if_report_id = editScWatch[0] and false or editScSkipReportId[0]
    local kw = {}
    for _, k in ipairs(scKwEdit) do
        local part = trim(k)
        if part ~= '' then kw[#kw + 1] = part end
    end
    sc.keywords = kw
    markDirtySettings()
    bumpScenariosGen()
end

-- Mark Scenario Editor Dirty
function markScenarioEditorDirty()
    scenariosEditorDirty = true
end

-- Sync Sc Kw Edit From Scenario
function syncScKwEditFromScenario(sc)
    scKwEdit = {}
    if not sc then
        setInputBuf(scKwBulk, '')
        return
    end
    local seen = {}
    local lines = {}
    for _, k in ipairs(sc.keywords or {}) do
        local part = trim(k)
        if part ~= '' then
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                scKwEdit[#scKwEdit + 1] = part
                lines[#lines + 1] = part
            end
        end
    end
    setInputBuf(scKwBulk, table.concat(lines, '\n'))
    setInputBuf(scKwNew, '')
end

-- Sync Scenario Keywords From Bulk Buf
function syncScenarioKeywordsFromBulkBuf()
    local block = readInputBuf(scKwBulk)
    scKwEdit = {}
    if block == '' then
        markScenarioEditorDirty()
        return
    end
    local seen = {}
    for line in block:gmatch('[^\r\n]+') do
        for _, part in ipairs(parseKeywordList(line)) do
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                scKwEdit[#scKwEdit + 1] = part
            end
        end
    end
    markScenarioEditorDirty()
end

-- Remove Scenario Keyword At
function removeScenarioKeywordAt(idx)
    if not scKwEdit[idx] then return end
    table.remove(scKwEdit, idx)
    markScenarioEditorDirty()
    flushScenarioEditorToScenario()
end

-- Add Keywords To Scenario Edit
function addKeywordsToScenarioEdit(words)
    local seen = {}
    for _, ex in ipairs(scKwEdit) do
        seen[keywordDedupeKey(ex)] = true
    end
    local added = 0
    for _, w in ipairs(words) do
        local part = trim(w)
        if part ~= '' then
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                scKwEdit[#scKwEdit + 1] = part
                added = added + 1
            end
        end
    end
    if added > 0 then
        markScenarioEditorDirty()
        flushScenarioEditorToScenario()
    end
    return added
end

-- Try Add Scenario Keyword From Input
function tryAddScenarioKeywordFromInput()
    local line = trim(readInputBuf(scKwNew))
    if line == '' then return 0 end
    local words
    if line:find('[,;]') then
        words = parseKeywordList(line)
    else
        words = { line }
    end
    local n = addKeywordsToScenarioEdit(words)
    setInputBuf(scKwNew, '')
    return n
end

-- Try Add Scenario Keywords From Bulk
function tryAddScenarioKeywordsFromBulk()
    local block = trim(readInputBuf(scKwBulk))
    if block == '' then return 0 end
    block = block:gsub('[\r\n]+', ',')
    return addKeywordsToScenarioEdit(parseKeywordList(block))
end

-- Apply Scenario Editor
function applyScenarioEditor()
    if selectedScenarioIdx < 1 or selectedScenarioIdx > #quickScenarios then return false end
    local label = readInputBuf(editScLabel)
    if label == '' then return false end
    local action = editScWatch[0] and 'watch' or 'reply'
    local kw = {}
    for _, k in ipairs(scKwEdit) do
        local part = trim(k)
        if part ~= '' then kw[#kw + 1] = part end
    end
    if action == 'reply' and #kw == 0 then return false end
    quickScenarios[selectedScenarioIdx] = {
        label = label,
        enabled = editScEnabled[0],
        match = 'contains',
        keywords = kw,
        reply = readInputBuf(editScReply),
        action = action,
        priority = tonumber(editScPriority[0]) or 0,
        skip_if_report_id = action == 'watch' and false or editScSkipReportId[0],
    }
    markDirtySettings()
    bumpScenariosGen()
    scenariosEditorDirty = false
    return true
end

-- Sync Scenario Editor If Dirty
function syncScenarioEditorIfDirty()
    if not scenariosEditorDirty then return end
    if #quickScenarios < 1 then
        scenariosEditorDirty = false
        return
    end
    if selectedScenarioIdx < 1 or selectedScenarioIdx > #quickScenarios then
        scenariosEditorDirty = false
        return
    end
    applyScenarioEditor()
end

-- Run Scenario Match Test
function runScenarioMatchTest()
    local sample = trim(readInputBuf(scTestBuf))
    if sample == '' then
        setInputBuf(scTestResult, uiText('\xE2\xE2\xE5\xE4\xE8\xF2\xE5 \xF2\xE5\xEA\xF1\xF2'))
        return
    end
    local names = {}
    for _, i in ipairs(getSortedQuickScenarioIndices()) do
        local sc = quickScenarios[i]
        if scenarioVisibleOnMessage(sc, sample) then
            names[#names + 1] = sc.label or '?'
        end
    end
    if #names == 0 then
        setInputBuf(scTestResult, uiText('\xED\xE5\xF2 \xEA\xED\xEE\xEF\xEE\xEA'))
    else
        setInputBuf(scTestResult, table.concat(names, ', '))
    end
end

-- Draw Scenarios Edit Panel
function drawScenariosEditPanel()
    imgui.TextColored(col_muted2, uiText('\xCD\xE0\xE7\xE2\xE0\xED\xE8\xE5'))
    imgui.PushItemWidth(-1)
    imgui.InputText('##sc_label', editScLabel, sizeof(editScLabel))
    if imguiItemEdited() then flushScenarioEditorToScenario() end
    imgui.PopItemWidth()

    imgui.TextColored(col_muted2, uiText('\xD2\xF0\xE8\xE3\xE3\xE5\xF0\xFB (\xEF\xEE \xF1\xF2\xF0\xEE\xEA\xE5, + \xE4\xEB\xFF \xE2\xF1\xE5\xF5 \xF1\xEB\xEE\xE2)'))
    imgui.TextColored(col_muted, string.format('(%d)', #scKwEdit))
    imgui.PushItemWidth(-1)
    if imgui.InputTextMultiline('##sc_kw_bulk', scKwBulk, sizeof(scKwBulk), imgui.ImVec2(-1, 120)) then
        syncScenarioKeywordsFromBulkBuf()
        flushScenarioEditorToScenario()
    end
    if imguiItemEdited() then
        syncScenarioKeywordsFromBulkBuf()
        flushScenarioEditorToScenario()
    end
    imgui.PopItemWidth()

    if deskFormToggleRow('\xD1\xEB\xE5\xE4\xE8\xF2\xFC', editScWatch, function()
        flushScenarioEditorToScenario()
    end) then end

    if not editScWatch[0] then
        imgui.TextColored(col_muted2, uiText('\xCE\xF2\xE2\xE5\xF2 /ans'))
        imgui.PushItemWidth(-1)
        if imgui.InputTextMultiline('##sc_reply', editScReply, sizeof(editScReply), imgui.ImVec2(-1, 64)) then
            flushScenarioEditorToScenario()
        end
        if imguiItemEdited() then flushScenarioEditorToScenario() end
        imgui.PopItemWidth()

        if deskFormToggleRow('\xD1\xEA\xF0\xFB\xF2\xE0\xF2\xFC \xED\xE0 \xE6\xE0\xEB\xEE\xE1\xE0\xF5 \xF1 ID \xED\xE0\xF0\xF3\xF8\xE8\xF2\xE5\xEB\xFF', editScSkipReportId, function()
            flushScenarioEditorToScenario()
        end) then end
    else
        imgui.TextColored(col_muted2, uiText('\xD1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5 \xE4\xEB\xFF sp'))
        imgui.PushItemWidth(-1)
        local scWatchChanged = false
        if imgui.InputTextWithHint then
            scWatchChanged = imgui.InputTextWithHint(
                '##sc_reply', uiText(TEMPLATE_PAYLOAD_HINT), editScReply, sizeof(editScReply))
        else
            scWatchChanged = imgui.InputText('##sc_reply', editScReply, sizeof(editScReply))
        end
        if scWatchChanged then flushScenarioEditorToScenario() end
        if imguiItemEdited() then flushScenarioEditorToScenario() end
        imgui.PopItemWidth()
    end

    if deskFormToggleRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xEE', editScEnabled, function()
        flushScenarioEditorToScenario()
    end, 'sc_en') then end

    imgui.Dummy(imgui.ImVec2(0, 6))
    imgui.TextColored(col_muted2, uiText('\xD2\xE5\xF1\xF2'))
    local testBtnW = 64
    imgui.PushItemWidth(math.max(80, imgui.GetContentRegionAvail().x - testBtnW - 8))
    imgui.InputText('##sc_test', scTestBuf, sizeof(scTestBuf))
    imgui.PopItemWidth()
    imgui.SameLine(0, 8)
    if imgui.Button(uiText('\xD2\xE5\xF1\xF2') .. '##sc_test_go', imgui.ImVec2(testBtnW, DESK_FORM_ROW_H)) then
        runScenarioMatchTest()
    end
    imgui.TextColored(col_muted, readInputBuf(scTestResult))

    imgui.Dummy(imgui.ImVec2(0, 8))
    if imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC \xF1\xF6\xE5\xED\xE0\xF0\xE8\xE9'), imgui.ImVec2(-1, 26)) then
        if selectedScenarioIdx >= 1 and selectedScenarioIdx <= #quickScenarios then
            table.remove(quickScenarios, selectedScenarioIdx)
            if selectedScenarioIdx > #quickScenarios then selectedScenarioIdx = #quickScenarios end
            if selectedScenarioIdx < 1 then selectedScenarioIdx = 1 end
            if #quickScenarios > 0 then fillScenarioEditor(selectedScenarioIdx) end
            markDirtySettings()
            bumpScenariosGen()
        end
    end
end

-- Draw Scenarios Tab Inner
function drawScenariosTabInner()
    settingsScenarioLearn[0] = settings.scenario_learn_enabled ~= false
    if deskFormToggleRow(
        '\xD3\xF7\xE8\xF2\xFC \xED\xE0 \xF5\xEE\xE4\xF3 (\xEA\xEB\xFE\xF7\xE8 \xE8\xE7 \xF0\xE5\xEF\xEE\xF0\xF2\xEE\xE2)',
        settingsScenarioLearn,
        function()
            settings.scenario_learn_enabled = settingsScenarioLearn[0]
            markDirtySettings()
        end,
        'sc_learn'
    ) then end
    do
        local st = (type(scenarioLearnData) == 'table' and scenarioLearnData.stats) or {}
        local sess = tonumber(st.session_records) or 0
        local kwNew = tonumber(st.session_keywords) or 0
        local kwAll = (type(scenarioLearnCountKeywords) == 'function' and scenarioLearnCountKeywords()) or 0
        imgui.TextColored(col_muted, string.format(
            uiText('\xD1\xE5\xF1\xF1\xE8\xFF: %d \xEE\xF2\xE2\xE5\xF2\xEE\xE2, +%d \xEA\xEB\xFE\xF7\xE5\xE9. \xC2\xF1\xE5\xE3\xEE \xEA\xEB\xFE\xF7\xE5\xE9: %d'),
            sess, kwNew, kwAll
        ))
    end
    imgui.Dummy(imgui.ImVec2(0, 6))
    pushPanelStyle()
    imgui.BeginChild('##sc_list', imgui.ImVec2(DESK_EDITOR_LIST_W, -1), true)
    if imgui.Button(uiText('+ \xD1\xF6\xE5\xED\xE0\xF0\xE8\xE9'), imgui.ImVec2(-1, 28)) then
        flushScenarioEditorToScenario()
        table.insert(quickScenarios, {
            label = '\xCD\xEE\xE2\xEE\xE5',
            enabled = true,
            match = 'contains',
            keywords = {},
            reply = '',
            action = 'reply',
            priority = 0,
            skip_if_report_id = true,
        })
        selectedScenarioIdx = #quickScenarios
        fillScenarioEditor(selectedScenarioIdx)
        markDirtySettings()
        bumpScenariosGen()
    end
    imgui.Dummy(imgui.ImVec2(0, 6))
    for i, sc in ipairs(quickScenarios) do
        local name = trim(sc.label or '')
        if name == '' then
            name = '\xD1\xE1\xE5\xE7 \xED\xE0\xE7\xE2\xE0\xED\xE8\xFF'
        end
        local label = name .. (sc.enabled and '' or ' (off)')
        if drawEditorListSelectable(label, '##sc' .. i, selectedScenarioIdx == i) then
            if selectedScenarioIdx ~= i then
                flushScenarioEditorToScenario()
                selectedScenarioIdx = i
                fillScenarioEditor(i)
            end
        end
    end
    imgui.EndChild()
    popPanelStyle()

    imgui.SameLine()
    pushPanelStyle(col_chat_bg)
    imgui.BeginChild('##sc_edit', imgui.ImVec2(0, -1), true)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 8))
    if #quickScenarios == 0 then
        imgui.Dummy(imgui.ImVec2(0, 24))
        imgui.TextColored(col_muted, uiText('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 + \xD1\xF6\xE5\xED\xE0\xF0\xE8\xE9'))
    else
        drawScenariosEditPanel()
    end
    imgui.PopStyleVar(2)
    imgui.EndChild()
    popPanelStyle()
end

-- Draw Scenarios Tab
function drawScenariosTab()
    if not scenariosUiSynced then
        if selectedScenarioIdx < 1 then selectedScenarioIdx = 1 end
        if selectedScenarioIdx > #quickScenarios then selectedScenarioIdx = math.max(1, #quickScenarios) end
        if #quickScenarios > 0 then fillScenarioEditor(selectedScenarioIdx) end
        scenariosUiSynced = true
    end
    local okSc, errSc = pcall(drawScenariosTabInner)
    syncScenarioEditorIfDirty()
    if not okSc then
        imgui.TextColored(col_warn, 'Scenarios UI error:')
        imgui.TextWrapped(tostring(errSc))
        print('[Report Desk] scenarios UI: ' .. tostring(errSc))
    end
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
    local snapKey = deskInputState.chatSnapBottomKey
    local wantSnap = snapKey and snapKey == selectedKey and msgCount > 0
    local wantFollow = not snapKey
        and (chatScrollToBottom or (deskInputState.chatScrollFrames or 0) > 0)

    if not wantSnap and not wantFollow then return end

    imgui.Dummy(imgui.ImVec2(0, 1))
    if imgui.SetScrollHereY then
        imgui.SetScrollHereY(1.0)
    end
    local maxY = (imgui.GetScrollMaxY and imgui.GetScrollMaxY()) or 0
    if maxY > 0 and imgui.SetScrollY then
        imgui.SetScrollY(maxY)
    end

    if wantSnap then
        if maxY <= 0 then
            deskInputState.chatSnapAttempts = (tonumber(deskInputState.chatSnapAttempts) or 0) + 1
            if deskInputState.chatSnapAttempts >= 6 then
                deskInputState.chatSnapBottomKey = nil
                deskInputState.chatSnapAttempts = 0
            end
            return
        end
        deskInputState.chatSnapBottomKey = nil
        deskInputState.chatSnapAttempts = 0
        return
    end

    local fr = tonumber(deskInputState.chatScrollFrames) or 0
    if fr > 0 then
        deskInputState.chatScrollFrames = fr - 1
    elseif chatScrollToBottom then
        chatScrollToBottom = false
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
    local atBottom = (scrollMax - scrollY) < 48
    if atBottom then
        deskInputState.chatFollowBottom = true
    elseif imgui.IsWindowHovered and imgui.IsWindowHovered() then
        local io = imgui.GetIO()
        if io and io.MouseWheel and io.MouseWheel < 0 then
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
        if #msgs > CHAT_UI_RENDER_MAX then
            renderFrom = #msgs - CHAT_UI_RENDER_MAX + 1
            imgui.TextColored(col_muted2, uiText(string.format(
                '\xCF\xEE\xEA\xE0\xE7\xE0\xED\xEE \xEF\xEE\xF1\xEB\xE5\xE4\xED\xE8\xE5 %d \xE8\xE7 %d',
                CHAT_UI_RENDER_MAX, #msgs)))
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        local lastDay = nil
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
            })
        end
        imgui.PopStyleVar()
    end
    updateChatFollowBottom()
    applyChatScrollIfNeeded(#msgs)
    imgui.EndChild()

    drawComposer(composerH, quickItems)
    imgui.EndChild()
    popPanelStyle()
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
            invalidateUiCaches()
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

-- Sync Rules Checkboxes From Settings
function syncRulesCheckboxesFromSettings()
    uiAutoRulesEnabled[0] = settings.auto_rules_enabled ~= false
    uiAutoOnlyUnread[0] = settings.auto_only_unread == true
    uiAutoTimeEnabled[0] = settings.auto_time_enabled ~= false
    uiAutoGgEnabled[0] = settings.auto_gg_enabled ~= false
end

-- Draw Rules Tab Inner
function drawRulesTabInner()
    deskFormPanelBegin('##auto_general')
    drawSettingsCardHeader('\xCE\xE1\xF9\xE5\xE5')
    if deskFormCheckboxRow('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB \xE2\xEA\xEB\xFE\xF7\xE5\xED\xFB', uiAutoRulesEnabled, function(v)
        settings.auto_rules_enabled = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xD2\xEE\xEB\xFC\xEA\xEE \xED\xE0 \xED\xE5\xEF\xF0\xEE\xF7\xE8\xF2\xE0\xED\xED\xFB\xE5', uiAutoOnlyUnread, function(v)
        settings.auto_only_unread = v
        markDirtySettings()
    end) then end
    imgui.TextColored(col_muted, uiText(
        '\xD1\xEB\xEE\xE2\xE0-\xF2\xF0\xE8\xE3\xE3\xE5\xF0\xFB \xE2 \xEA\xEE\xE4\xE5 (\xF6\xE5\xEB\xEE\xE5 \xF1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5). \xC7\xE4\xE5\xF1\xFC \xF2\xEE\xEB\xFC\xEA\xEE \xE2\xEA\xEB/ \xE2\xFB\xEA\xEB \xE8 \xF2\xE5\xEA\xF1\xF2.'))
    deskFormPanelEnd()

    deskFormPanelBegin('##auto_time')
    drawSettingsCardHeader('\xD2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF')
    if deskFormCheckboxRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xEE', uiAutoTimeEnabled, function(v)
        settings.auto_time_enabled = v
        markDirtySettings()
    end, 'auto_time_en') then end
    imgui.TextColored(col_muted2, uiText('\xD2\xE5\xEA\xF1\xF2 \xEE\xF2\xE2\xE5\xF2\xE0'))
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
    imgui.TextColored(col_muted, uiText('{datetime}'))
    deskFormPanelEnd()

    deskFormPanelBegin('##auto_gg')
    drawSettingsCardHeader('\xD1\xEF\xE0\xF1\xE8\xE1\xEE / GG')
    if deskFormCheckboxRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xEE', uiAutoGgEnabled, function(v)
        settings.auto_gg_enabled = v
        markDirtySettings()
    end, 'auto_gg_en') then end
    imgui.TextColored(col_muted2, uiText('\xD2\xE5\xEA\xF1\xF2 \xEE\xF2\xE2\xE5\xF2\xE0'))
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
    deskFormPanelEnd()
end

-- Draw Rules Tab
function drawRulesTab()
    if not rulesUiSynced then
        setInputBuf(deskReplyBuf.time, getTimeReplyText())
        setInputBuf(deskReplyBuf.gg, getGgReplyText())
        syncRulesCheckboxesFromSettings()
        rulesUiSynced = true
    end

    pushPanelStyle(col_chat_bg)
    local childFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        childFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##auto_rules_panel', imgui.ImVec2(-1, -1), false, childFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 6))

    local okRules, errRules = pcall(drawRulesTabInner)
    if not okRules then
        imgui.TextColored(col_warn, 'Rules UI error:')
        imgui.TextWrapped(tostring(errRules))
        print('[Report Desk] rules UI: ' .. tostring(errRules))
    end

    imgui.PopStyleVar()
    imgui.EndChild()
    popPanelStyle()
end

-- Sync Settings Ui From Settings
function syncSettingsUiFromSettings()
    uiSound[0] = settings.sound
    uiWatchAutoNotify[0] = settings.watch_auto_notify ~= false
    uiSpecHud[0] = settings.spectate_hud ~= false
    uiSpecAutoSt[0] = settings.spectate_auto_st ~= false
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
        settingsUiSynced = true
    end

    pushPanelStyle(col_chat_bg)
    local childFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        childFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##settings_panel', imgui.ImVec2(-1, -1), false, childFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 6))
    drawDeskBindCaptureBanner()

    deskFormPanelBegin('##set_main')
    drawSettingsCardHeader('\xCE\xF1\xED\xEE\xE2\xED\xEE\xE5',
        '\xC3\xEE\xF0\xFF\xF7\xE0\xFF \xEA\xEB\xE0\xE2\xE8\xF8\xE0 \xE8 \xF3\xE2\xE5\xE4\xEE\xEC\xEB\xE5\xED\xE8\xFF')
    drawSettingsHotkeyBind()

    drawSettingsSubsection('\xC7\xE2\xF3\xEA')
    if deskFormCheckboxRow('\xCD\xEE\xE2\xFB\xE9 \xF0\xE5\xEF\xEE\xF0\xF2', uiSound, function(v)
        settings.sound = v
        markDirtySettings()
    end, 'snd_report') then end

    drawSettingsSubsection('\xD1\xF6\xE5\xED\xE0\xF0\xE8\xE9 \xAB\xD1\xEB\xE5\xE4\xE8\xF2\xFC\xBB')
    if deskFormCheckboxRow('\xCE\xF2\xEF\xF0\xE0\xE2\xEB\xFF\xF2\xFC \xEE\xF2\xE2\xE5\xF2 \xE0\xE2\xF2\xEE\xEC\xE0\xF2\xE8\xF7\xE5\xF1\xEA\xE8', uiWatchAutoNotify, function(v)
        settings.watch_auto_notify = v
        markDirtySettings()
    end, 'watch_auto') then end
    if uiWatchAutoNotify[0] then
        deskFormRowLabel('\xD2\xE5\xEA\xF1\xF2 \xEE\xF2\xE2\xE5\xF2\xE0')
        imgui.PushItemWidth(-1)
        local wnChanged
        if imgui.InputTextWithHint then
            wnChanged = imgui.InputTextWithHint('##watch_notify',
                uiText(TEMPLATE_PAYLOAD_HINT),
                deskReplyBuf.watch, sizeof(deskReplyBuf.watch))
        else
            wnChanged = imgui.InputText('##watch_notify', deskReplyBuf.watch, sizeof(deskReplyBuf.watch))
        end
        deskKeepInputOnActiveItem()
        if wnChanged or imguiItemEdited() then
            settings.watch_notify = readInputBuf(deskReplyBuf.watch)
            markDirtySettings()
        end
        imgui.PopItemWidth()
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##set_chat')
    drawSettingsCardHeader('\xD7\xE0\xF2',
        'Bubble-\xF0\xE5\xF7\xFC \xE8\xE3\xF0\xEE\xEA\xEE\xE2, \xF4\xE8\xEB\xFC\xF2\xF0 \xEC\xE0\xF2\xE0')

    drawSettingsSubsection('Bubble-\xF0\xE5\xF7\xFC [B]')
    if deskFormCheckboxRow('\xC4\xF3\xE1\xEB\xE8\xF0\xEE\xE2\xE0\xF2\xFC \xE2 SAMP-\xF7\xE0\xF2', uiRemoteChatSamp, function(v)
        settings.remote_chat_samp_mirror = v
        if type(remoteChatSetMirrorEnabled) == 'function' then
            pcall(remoteChatSetMirrorEnabled, v)
        elseif v == false and type(remoteChatClearQueue) == 'function' then
            pcall(remoteChatClearQueue)
        end
        markDirtySettings()
    end, 'remote_chat_samp') then end
    drawSettingsHint('\xD0\xE5\xF7\xFC, /me \xE8 /do \xE8\xE3\xF0\xEE\xEA\xEE\xE2 \xF1 \xF2\xE5\xE3\xEE\xEC [B] \xE2 \xEE\xE1\xF9\xE8\xE9 \xF7\xE0\xF2')

    drawSettingsSubsection('\xD4\xE8\xEB\xFC\xF2\xF0 \xEC\xE0\xF2\xE0')
    if deskFormCheckboxRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED', uiProfanityFilter, function(v)
        settings.profanity_filter_enabled = v
        markDirtySettings()
    end, 'prof_on') then end
    if uiProfanityFilter[0] then
        if deskFormCheckboxRow('\xC7\xE2\xF3\xEA \xEF\xF0\xE8 \xEE\xE1\xED\xE0\xF0\xF3\xE6\xE5\xED\xE8\xE8', uiProfanitySound, function(v)
            settings.profanity_filter_sound = v
            markDirtySettings()
        end, 'prof_snd') then end
    end
    drawSettingsHint('\xD2\xEE\xEB\xFC\xEA\xEE bubble-\xF0\xE5\xF7\xFC \xE8\xE3\xF0\xEE\xEA\xEE\xE2 \xB7 ' .. tostring(#profanity_words) .. ' \xF1\xEB\xEE\xE2 \xE2 \xF1\xEB\xEE\xE2\xE0\xF0\xE5')
    deskFormPanelEnd()

    deskFormPanelBegin('##set_spec')
    drawSettingsCardHeader('\xD1\xEF\xE5\xEA\xF2\xE5\xE9\xF2 /sp',
        'HUD \xE8 \xEF\xEE\xE2\xE5\xE4\xE5\xED\xE8\xE5 \xEF\xF0\xE8 \xED\xE0\xE1\xEB\xFE\xE4\xE5\xED\xE8\xE8 \xE7\xE0 \xE8\xE3\xF0\xEE\xEA\xEE\xEC')
    uiAdminLevel[0] = getLocalAdminLevel()
    drawSettingsSliderInt('\xD3\xF0\xEE\xE2\xE5\xED\xFC \xE0\xE4\xEC\xE8\xED\xE0', uiAdminLevel, 'adm_lvl', 1, 4, function(v)
        settings.admin_level = v
        markDirtySettings()
    end)
    drawSettingsHint('1\x962 \x97 tr \xF7\xE5\xF0\xE5\xE7 /a \xB7 3+ \x97 \xEA\xEE\xEC\xE0\xED\xE4\xE0 /tr')

    drawSettingsSubsection('HUD')
    if deskFormCheckboxRow('\xCF\xE0\xED\xE5\xEB\xFC \xF1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xE8', uiSpecHud, function(v)
        settings.spectate_hud = v
        markDirtySettings()
    end, 'spec_hud') then end
    if deskFormCheckboxRow('\xD1\xEF\xE8\xE4\xEE\xEC\xE5\xF2\xF0 \xE2 \xEC\xE0\xF8\xE8\xED\xE5', uiSpecVehicleHud, function(v)
        settings.spectate_vehicle_hud = v
        markDirtySettings()
    end, 'spec_vehicle_hud') then end
    if deskFormCheckboxRow('\xCA\xEB\xE0\xE2\xE8\xE0\xF2\xF3\xF0\xE0 \xE8\xE3\xF0\xEE\xEA\xE0', uiSpecKeysHud, function(v)
        settings.spectate_keys_hud = v
        markDirtySettings()
    end, 'spec_keys_hud') then end
    if deskFormCheckboxRow('\xC7\xF3\xEC \xEA\xE0\xEC\xE5\xF0\xFB \xEA\xEE\xEB\xB8\xF1\xE8\xEA\xEE\xEC', uiSpecWheelZoom, function(v)
        settings.spectate_wheel_zoom = v
        markDirtySettings()
    end, 'spec_wheel_zoom') then end
    drawSettingsHint('\xCF\xE0\xED\xE5\xEB\xE8 \xEC\xEE\xE6\xED\xEE \xEF\xE5\xF0\xE5\xF2\xE0\xF1\xEA\xE8\xE2\xE0\xF2\xFC \xEC\xFB\xF8\xFC\xFE \xE2 /sp \xB7 \xEA\xEB\xE0\xE2\xE8\xE0\xF2\xF3\xF0\xF3 \xE2 \xE7\xEE\xED\xE5 \xF6\xE5\xED\xF2\xF0\xE0 \xF1\xED\xE8\xE7\xF3')

    drawSettingsSubsection('\xCF\xEE\xE2\xE5\xE4\xE5\xED\xE8\xE5')
    if deskFormCheckboxRow('\xC7\xE0\xEF\xF0\xE0\xF8\xE8\xE2\xE0\xF2\xFC /st \xEF\xF0\xE8 \xE2\xF5\xEE\xE4\xE5', uiSpecAutoSt, function(v)
        settings.spectate_auto_st = v
        markDirtySettings()
    end, 'spec_st') then end
    if deskFormCheckboxRow('\xCE\xF1\xF2\xE0\xE2\xEB\xFF\xF2\xFC HUD \xEF\xEE\xF1\xEB\xE5 /sp', uiSpecHudPersist, function(v)
        settings.spectate_hud_persist = v
        markDirtySettings()
    end, 'spec_persist') then end

    drawSettingsSubsection('\xC7\xE2\xF3\xEA \xEC\xE5\xED\xFE')
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
        selectedId = -1
        selectedKey = nil
        chatLogReady = false
        totalUnread = 0
        seedSeenChatLines()
        invalidateUiCaches()
        invalidateFilterCache()
        markDirtyThreads()
        markDirtySettings()
        saveConfig()
        say('\xC4\xE8\xE0\xEB\xEE\xE3\xE8 \xEE\xF7\xE8\xF9\xE5\xED\xFB')
    end
    imgui.PopStyleColor(3)
    deskFormPanelEnd()

    imgui.PopStyleVar()
    imgui.Dummy(imgui.ImVec2(0, 12))
    imgui.EndChild()
    popPanelStyle()
end

-- Toggle Window
function toggleWindow()
    if not sessionLive then return end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return end
    if showWindow[0] then
        closeDeskWindow()
        return
    end
    releaseDeskInputCapture(true)
    clearDeskImguiInputState(true)
    showWindow[0] = true
    deskInputState.openWarmupUntil = os.clock() + DESK_OPEN_WARMUP_SEC
    deskInputState.openPollHoldUntil = os.clock() + 0.08
    rulesUiSynced = false
    settingsUiSynced = false
    scenariosUiSynced = false
    focusReplyNext = false
    deskInputState.windowOpenSince = os.clock()
    deskInputState.keyboardStickyUntil = 0
    deskInputState.chatFollowBottom = true
    refreshMyNick()
    deskInputState.wasOpen = true
    deskApplyInputPolicy()
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
    imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh * 0.5), imgui.Cond.Appearing, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(WIN_W, WIN_H), imgui.Cond.Appearing)
    imgui.SetNextWindowBgAlpha(0.97)

    if not imgui.Begin(uiText('Report Desk') .. '###ReportDesk', showWindow, imgui.WindowFlags.NoCollapse
            + (imgui.WindowFlags.NoNav or 0)) then
        if not showWindow[0] then
            closeDeskWindow()
        end
        imgui.End()
        return
    end

    if filterMode[0] > 1 then filterMode[0] = 0 end

    if imgui.BeginTabBar('##tabs') then
        if imgui.BeginTabItem(uiText('\xD0\xE5\xEF\xEE\xF0\xF2\xFB') .. '##tab_chat') then
            drawThreadList()
            imgui.SameLine(0, 0)
            drawChatPanel()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2\xFB') .. '##tab_rules') then
            drawRulesTab()
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(uiText('\xD1\xF6\xE5\xED\xE0\xF0\xE8\xE8') .. '##tab_sc') then
            drawScenariosTab()
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


    drawDeskBindCaptureBanner()

    imgui.End()
    if not showWindow[0] then
        closeDeskWindow()
        return
    end
    updateDeskInputCapture()
end

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

addEventHandler('onD3DDeviceLost', function()
    if not catWarmup.inited then return end
    pcall(deskTexPipeline.halt, deskTex)
    catWarmup.inited = false
end)

addEventHandler('onD3DDeviceReset', function()
    pcall(ensureDeskCatalogWarmup)
    if skinUiTabActive then pcall(skinsOnTabEnter) end
    if deskVeh and deskVeh.tabActive then pcall(deskVeh.onTabEnter) end
end)

-- Desk hook/helper.
function deskPassesGameKey(wparam)
    if deskCache.gamePassVks[wparam] then return true end
    local hk = settings.hotkey or (vkeys and vkeys.VK_F7) or 0x76
    if wparam == hk then return true end
    if vkeys then
        if wparam == vkeys.VK_CONTROL or wparam == vkeys.VK_SHIFT
            or wparam == vkeys.VK_MENU or wparam == vkeys.VK_LWIN
            or wparam == vkeys.VK_RWIN then
            return true
        end
    end
    return false
end


-- Draw Desk Sp Spectate Overlay
function drawDeskSpSpectateOverlay()
    if type(settings) ~= 'table' then return end
    if deskSpectateStats.shouldShowHud and deskSpectateStats.shouldShowHud(settings) then
        pcall(deskSpectateStats.drawOverlay, settings)
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
    if deskSpectateStats.shouldShowHud and deskSpectateStats.shouldShowHud(settings) then return true end
    return false
end

do
    local function setupDeskFrame(frame, hideCursor, lockPlayer)
        frame.HideCursor = hideCursor and true or false
        frame.LockPlayer = lockPlayer and true or false
        return frame
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

    deskCache.mainPanelFrame =     setupDeskFrame(imgui.OnFrame(
        function() return deskCache.catalogTexFlushPending == true end,
        function()
            pcall(deskFlushCatalogTexPending)
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
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
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            ensureCheatsSettings()
            return settings.cheats.show_hud ~= false
        end,
        function(self)
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            pcall(drawCheatsHudOverlay)
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            local wantCursor = showWindow[0]
                or (type(cheatsHudWantsInput) == 'function' and cheatsHudWantsInput())
            self.HideCursor = not wantCursor
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            if not sessionLive then return false end
            if settings.spectate_vehicle_hud == false then return false end
            return deskSpectateStats.shouldShowVehicleHud and deskSpectateStats.shouldShowVehicleHud(settings)
        end,
        function(self)
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            if deskSpectateStats.drawVehicleHud then
                pcall(deskSpectateStats.drawVehicleHud, settings)
            end
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            self.HideCursor = true
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
            if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
            if not sessionLive then return false end
            if settings.spectate_keys_hud == false then return false end
            return deskSpectateStats.shouldShowKeysHud and deskSpectateStats.shouldShowKeysHud(settings)
        end,
        function(self)
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            if deskSpectateStats.drawKeysHud then
                pcall(deskSpectateStats.drawKeysHud, settings)
            end
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            self.HideCursor = true
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
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            drawDeskSpSpectateOverlay()
            if type(updateMimguiGameInputPassthrough) == 'function' then
                pcall(updateMimguiGameInputPassthrough)
            end
            self.HideCursor = true
            self.LockPlayer = false
        end
    ), true, false)

    setupDeskFrame(imgui.OnFrame(
        function()
            return deskSpectateStats.isAnsBarOpen and deskSpectateStats.isAnsBarOpen()
        end,
        function(self)
            self.HideCursor = false
            self.LockPlayer = false
            if deskSpectateStats.drawSpAns then
                pcall(deskSpectateStats.drawSpAns, settings)
            end
            pcall(updateMimguiGameInputPassthrough)
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
end

-- Apply Cheat Key Capture
function applyCheatKeyCapture(msg, wparam)
    if not deskCache.cheatCapture then return false end
    if os.clock() - deskCache.cheatCaptureAt < PF.HOTKEY_CAPTURE_GRACE then return true end
    local prefix = CHEAT_BIND_PREFIX[deskCache.cheatCapture]
    if not prefix then
        deskCache.cheatCapture = nil
        return true
    end
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        if wparam == vkeys.VK_ESCAPE then
            deskCache.cheatCapture = nil
        elseif wparam and wparam > 0 and wparam < 256 then
            ensureCheatsSettings()
            local c = settings.cheats
            if deskCache.cheatCaptureSlot == 'key2' then
                c[prefix .. '_key2'] = wparam
            elseif wparam ~= vkeys.VK_CONTROL and wparam ~= vkeys.VK_SHIFT and wparam ~= vkeys.VK_MENU then
                c[prefix .. '_key1'] = wparam
                c[prefix .. '_ctrl'] = cheatModDown(vkeys.VK_CONTROL)
                c[prefix .. '_shift'] = cheatModDown(vkeys.VK_SHIFT)
                c[prefix .. '_alt'] = cheatModDown(vkeys.VK_MENU)
            end
            markDirtySettings()
            deskCache.cheatCapture = nil
        end
        return true
    end
    local mvk = parseMouseButtonVk(msg, wparam, lparam)
    if mvk then
        ensureCheatsSettings()
        local c = settings.cheats
        if deskCache.cheatCaptureSlot == 'key2' then
            c[prefix .. '_key2'] = mvk
        else
            c[prefix .. '_key1'] = mvk
            c[prefix .. '_ctrl'] = cheatModDown(vkeys.VK_CONTROL)
            c[prefix .. '_shift'] = cheatModDown(vkeys.VK_SHIFT)
            c[prefix .. '_alt'] = cheatModDown(vkeys.VK_MENU)
        end
        markDirtySettings()
        deskCache.cheatCapture = nil
        return true
    end
    return true
end

-- Парсинг данных с сервера/чата.
function parseMouseButtonVk(msg, wparam, lparam)
    if msg == deskCache.wm.LBUTTONDOWN then return vkeys.VK_LBUTTON end
    if msg == deskCache.wm.RBUTTONDOWN then return vkeys.VK_RBUTTON end
    if msg == deskCache.wm.MBUTTONDOWN then return vkeys.VK_MBUTTON end
    if msg == deskCache.wm.XBUTTONDOWN then
        local btn = bit.rshift(tonumber(wparam) or 0, 16)
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
        local btn = bit.rshift(tonumber(wparam) or 0, 16)
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
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        if wparam == vkeys.VK_ESCAPE then
            deskCache.hotkeyCapture = false
        elseif wparam and wparam > 0 and wparam < 256 then
            if not deskHotkeyBlockedByMarkerWheel(wparam) then
                settings.hotkey = wparam
                deskCache.hotkeyCapture = false
                markDirtySettings()
            end
        end
        return true
    end
    local mvk = parseMouseButtonVk(msg, wparam, lparam)
    if mvk then
        if not deskHotkeyBlockedByMarkerWheel(mvk) then
            settings.hotkey = mvk
            deskCache.hotkeyCapture = false
            markDirtySettings()
        end
        return true
    end
    return true
end

if vkeys and vkeys.VK_SNAPSHOT then deskCache.gamePassVks[vkeys.VK_SNAPSHOT] = true end
if vkeys and vkeys.VK_F12 then deskCache.gamePassVks[vkeys.VK_F12] = true end
if vkeys and vkeys.VK_F8 then deskCache.gamePassVks[vkeys.VK_F8] = true end

local DESK_WM_KEYS = {
    hotkey = '__rd_wm_hotkey__',
    gamePass = '__rd_wm_gamepass__',
    main = '__rd_wm_main__',
}

local function uninstallDeskWm(key)
    local prev = _G[DESK_WM_KEYS[key]]
    if prev and removeEventHandler then
        pcall(removeEventHandler, 'onWindowMessage', prev)
    end
    _G[DESK_WM_KEYS[key]] = nil
end

local function installDeskWm(key, fn, front)
    uninstallDeskWm(key)
    addEventHandler('onWindowMessage', fn, front == true)
    _G[DESK_WM_KEYS[key]] = fn
end

local function installDeskWmHandlers()
    installDeskWm('hotkey', function(msg, wparam, lparam)
        if tryHandleDeskHotkeyMessage(msg, wparam, lparam) then return end
    end, true)

    installDeskWm('gamePass', function(msg, wparam, lparam)
        if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
            if deskCache.gamePassVks[wparam] then
                updateMimguiGameInputPassthrough()
                return
            end
        end
    end, true)

    installDeskWm('main', function(msg, wparam, lparam)
        if deskCache.cheatCapture then
            if applyCheatKeyCapture(msg, wparam, lparam) then
                consumeWindowMessage(true, true, true)
                return
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
                return
            end
        end

        if not showWindow[0] then return end

        if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN or msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
            if wparam == vkeys.VK_ESCAPE then
                if deskImguiTypingActive() then
                    return
                end
                if sampIsDialogActive and sampIsDialogActive() then
                    return
                end
                if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
                    consumeWindowMessage(true, false, true)
                    return
                end
                if msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
                    if deskCache.hotkeyCapture or deskCache.cheatCapture then
                        cancelDeskBindCapture()
                    else
                        closeDeskWindow()
                    end
                    consumeWindowMessage(true, false, true)
                    return
                end
            end
        end
    end, false)
end

installDeskWmHandlers()

-- Try Intercept Split Ans Command
function tryInterceptSplitAnsCommand(command)
    command = trim(command or '')
    if command == '' then return false end
    local id, body = command:match('^/?ans%s+(%d+)%s+(.+)$')
    if not id or not body then return false end
    body = normalizeOutboundBody(body)
    local idNum = tonumber(id)
    if not idNum or not ansReplyNeedsSplit(idNum, body) then return false end

    local liveNick = liveNickForPlayerId(idNum)
    if wasOutboundEchoHandled(idNum, body, liveNick) then return true end

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
                markOutboundEchoHandled(idNum, body, tk, liveNick)
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
        return
    end

    refreshMyNick()
    local t, key = resolveThreadForPlayerId(idNum, liveNick)
    if t and key and not threadFindOutgoingMessage(t, body, { self = true }) then
        threadApplyOutgoing(t, key, body, { self = true })
        markOutboundEchoHandled(idNum, body, key, liveNick)
    end
end

-- Fallback poll sampGetChatString когда hook пропустил строку.
-- === Fallback poll ingest чата (sampGetChatString) ===
function pollReportIngest()
    if not sampGetChatString then return end
    if showWindow[0] and deskInputState.openPollHoldUntil then
        if os.clock() < deskInputState.openPollHoldUntil then return end
        deskInputState.openPollHoldUntil = nil
    end
    if not chatLogReady then
        seedSeenChatLines()
        return
    end
    local hookActive = type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive()
    local maxLines
    if hookActive then
        maxLines = showWindow[0] and CHAT_POLL_LINES_HOOK or CHAT_POLL_LINES_CLOSED_HOOK
    else
        maxLines = showWindow[0] and CHAT_POLL_LINES_OPEN or CHAT_POLL_LINES_CLOSED
    end
    if showWindow[0] and deskInputState.openWarmupUntil then
        if os.clock() < deskInputState.openWarmupUntil then
            if maxLines > DESK_OPEN_POLL_LINES then
                maxLines = DESK_OPEN_POLL_LINES
            end
        else
            deskInputState.openWarmupUntil = nil
        end
    end
    local maxLine = maxLines - 1
    for i = 0, maxLine do
        local line = sampGetChatString(i) or ''
        if line == '' then goto continue end
        local key = chatLineSeenKey(line)
        if key == '' then goto continue end
        if chatSeen.lines[key] then goto continue end
        local plain = normalizeChatLine(line)
        if tryIngestAdminReplyLine(plain) then
            markChatLineSeen(key)
            chatSeen.deferred[key] = nil
            goto continue
        end
        if looksLikeAdminReplyLine(plain) then
            local deferAt = chatSeen.deferred[key]
            if not deferAt then
                chatSeen.deferred[key] = os.clock()
                goto continue
            end
            if os.clock() - deferAt < CHAT_DEFERRED_ADMIN_SEC then
                goto continue
            end
            chatSeen.deferred[key] = nil
        end
        if settings.profanity_filter_enabled then
            pcall(checkProfanityFromChatLine, plain, key)
        end
        local pollDelay = showWindow[0] and POLL_INTERVAL or POLL_INTERVAL_CLOSED
        if processChatLineIngest(plain, 0, 'chat', true, line, { delay = pollDelay }) then
            markChatLineSeen(key)
            chatSeen.deferred[key] = nil
        end
        ::continue::
    end
end

-- Poll/опрос.
function pollChatLog()
    pollReportIngest()
end

