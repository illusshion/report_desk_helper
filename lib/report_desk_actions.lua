--[[ Модуль: действия admin (ans, sp, history, nick cache). ]]
function sendSlapPlayer(targetId)
    targetId = clampSuspectPlayerId(targetId)
    if not targetId then
        say('\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEE\xEF\xF0\xE5\xE4\xE5\xEB\xE8\xF2\xFC ID \xE8\xE3\xF0\xEE\xEA\xE0')
        return
    end
    sendGameCmd('slap ' .. targetId)
end

-- Отправка команды/сообщения на сервер.
function sendTrPlayer(targetId)
    targetId = clampSuspectPlayerId(targetId)
    if not targetId then
        say('\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEE\xEF\xF0\xE5\xE4\xE5\xEB\xE8\xF2\xFC ID \xE8\xE3\xF0\xEE\xEA\xE0')
        return
    end
    if getLocalAdminLevel() <= 2 then
        sendChat(string.format('/a /tr %d', targetId))
        return
    end
    if showWindow[0] then
        sendGameCmd('tr ' .. targetId)
    else
        sendMenuOutbound('tr ' .. targetId)
    end
end

-- Отправка команды/сообщения на сервер.
function sendHistoryByPlayerId(arg)
    local id = clampSuspectPlayerId(tonumber(trim(tostring(arg or '')):match('(%d+)')))
    if not id then
        say('\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /hist [ID \xE8\xE3\xF0\xEE\xEA\xE0].')
        return false
    end
    if not isSampAvailable() then return false end
    if type(sampIsPlayerConnected) ~= 'function' or not sampIsPlayerConnected(id) then
        say('\xC8\xE3\xF0\xEE\xEA\xE0 \xF1 \xF2\xE0\xEA\xE8\xEC ID \xED\xE0 \xF1\xE5\xF0\xE2\xE5\xF0\xE5 \xED\xE5\xF2.')
        return false
    end
    local nick = (type(sampGetPlayerNickname) == 'function' and sampGetPlayerNickname(id)) or ''
    nick = trim(nick)
    if nick == '' then
        say('\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEF\xEE\xEB\xF3\xF7\xE8\xF2\xFC \xED\xE8\xEA \xE8\xE3\xF0\xEE\xEA\xE0.')
        return false
    end
    if sendChat('history ' .. nick) then
        return true
    end
    return false
end

-- Header Action Btn Width
function headerActionBtnWidth(label)
    return math.max(52, math.floor(imgui.CalcTextSize(uiText(label or '?')).x + 18 + 0.5))
end

-- Push Player Action Btn Style
function pushPlayerActionBtnStyle()
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.16, 0.24, 0.96))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.28, 0.22, 0.38, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
    imgui.PushStyleColor(imgui.Col.Text, col_label)
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(8, 4))
end

-- Pop Player Action Btn Style
function popPlayerActionBtnStyle()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(4)
end

-- Clamp Suspect Player Id
function clampSuspectPlayerId(id)
    id = tonumber(id)
    if not id or id < 0 or id > MAX_PLAYER_ID then return nil end
    return math.floor(id)
end

local REPORT_ID_MARKERS = {
    'dm', 'id', '\xF3\xE1\xE8\xEB', '\xF3\xE1\xE8\xEB\xE0', '\xF7\xE8\xF2', '\xF7\xE8\xF2\xE5\xF0',
    'hack', 'cheat', 'kill', 'killed', '\xED\xE0\xF0\xF3\xF8', 'report', '\xF0\xE5\xEF\xEE\xF0\xF2',
}

-- Text Looks Like Player Report
function textLooksLikePlayerReport(text)
    local low = normalizeMatchText(text)
    if low == '' then return false end
    if deskIngest.looksLikeAdminActionText(text) then return false end
    for _, m in ipairs(REPORT_ID_MARKERS) do
        if low:find(m, 1, true) then return true end
    end
    return false
end

--[[
    Извлекает ID из текста жалобы: "43 dm", "114id чит", "id 55", "43 убил" и т.п.
    Без маркеров репорта произвольные числа (время, уровень) не считаются ID.
]]
function extractSuspectIdFromReport(text)
    text = trim(text or '')
    if text == '' or not text:find('%d') then return nil end

    local id = text:match('(%d+)%s*[iI][dD]')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('[iI][dD]%s*(%d+)')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('(%d+)%s*dm')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('(%d+)%s*DM')
    if id then return clampSuspectPlayerId(id) end

    if not textLooksLikePlayerReport(text) then return nil end

    id = text:match('^(%d+)%s+')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('(%d+)%s+[%a\xC0-\xFF]')
    if id then return clampSuspectPlayerId(id) end

    return nil
end

--[[ ID для кнопки «Следить»: строгие правила + первое число в тексте (кроме HH:MM:SS). ]]
function extractSuspectIdForWatch(text)
    text = trim(text or '')
    if text == '' then return nil end
    if deskIngest.looksLikePlayerStatusBody and deskIngest.looksLikePlayerStatusBody(text) then return nil end
    local id = extractSuspectIdFromReport(text)
    if id then return id end
    text = trim(text or '')
    if text == '' or not text:find('%d') then return nil end
    id = text:match('^(%d+)$')
    if id then return clampSuspectPlayerId(id) end
    id = text:match('^(%d+)[%s%,%.%-%)]')
    if id then return clampSuspectPlayerId(id) end
    local scrubbed = text:gsub('%d%d?:%d%d:?%d%d?', ' '):gsub('%s+', ' ')
    for num in scrubbed:gmatch('(%d+)') do
        id = clampSuspectPlayerId(num)
        if id then return id end
    end
    return nil
end

-- Find Enabled Watch Scenario
function findEnabledWatchScenario()
    for _, sc in ipairs(quickScenarios) do
        if sc.action == 'watch' and sc.enabled then return sc end
    end
    return nil
end

-- Get Watch Button Scenario
function getWatchButtonScenario()
    local sc = findEnabledWatchScenario()
    if sc then return sc end
    return {
        label = '\xD1\xEB\xE5\xE4\xE8\xF2\xFC',
        enabled = true,
        action = 'watch',
        reply = settings.watch_notify or 'see',
    }
end

-- Schedule Watch Notify
function scheduleWatchNotify(reporterNick, ansId, notify)
    reporterNick = trim(reporterNick or '')
    notify = trim(notify or '')
    if reporterNick == '' or not ansId or notify == '' then return end
    lua_thread.create(function()
        wait(WATCH_ANS_DELAY_MS)
        if not isSampAvailable() then return end
        local key = findThreadKeyByNick(reporterNick) or nickKey(reporterNick)
        local th = (key and threads[key]) or nil
        local ok, res = false, 'no thread'
        if th then
            ok, res = sendOutgoingAns(th, notify, { threadKey = key })
        end
        if not ok then
            if th then
                threadApplyOutgoing(th, threadStorageKey(th), notify, { self = true })
                setPendingOutbound(th, notify, ansId, false)
            end
            sendChat(string.format('ans %d %s', ansId, notify))
            if res and settings.debug then
                print('[Report Desk] watch ans fallback: ' .. tostring(res))
            end
        end
    end)
end

-- Clone Quick Scenarios
function cloneQuickScenarios(src, fromUtf8)
    fromUtf8 = fromUtf8 == true
    local out = {}
    for i, sc in ipairs(src or {}) do
        local kw = {}
        if type(sc.keywords) == 'table' then
            for _, k in ipairs(sc.keywords) do
                kw[#kw + 1] = normalizeStoredText(k, fromUtf8)
            end
        end
        local neg = {}
        if type(sc.negative_keywords) == 'table' then
            for _, k in ipairs(sc.negative_keywords) do
                neg[#neg + 1] = normalizeStoredText(k, fromUtf8)
            end
        end
        out[i] = {
            label = normalizeStoredText(sc.label or '', fromUtf8),
            enabled = sc.enabled ~= false,
            match = sc.match or 'contains',
            keywords = kw,
            negative_keywords = neg,
            reply = normalizeStoredText(sc.reply or '', fromUtf8),
            action = sc.action == 'watch' and 'watch' or 'reply',
            priority = tonumber(sc.priority) or 0,
            skip_if_report_id = sc.skip_if_report_id ~= false,
        }
    end
    return out
end

-- Quick Scenario Matches
function quickScenarioMatches(sc, body)
    local keywords = sc.keywords or {}
    local learned = scenarioLearnGetKeywordsForScenario and scenarioLearnGetKeywordsForScenario(sc.label or '')
    if type(learned) == 'table' and #learned > 0 then
        local merged = {}
        for i = 1, #keywords do merged[i] = keywords[i] end
        for i = 1, #learned do merged[#keywords + i] = learned[i] end
        keywords = merged
    end
    return keywordMatches({
        match = sc.match or 'contains',
        keywords = keywords,
    }, body)
end

-- Quick Scenario Negative Matches
function quickScenarioNegativeMatches(sc, body)
    local neg = sc.negative_keywords
    if type(neg) ~= 'table' or #neg < 1 then return false end
    return keywordMatches({
        match = sc.match or 'contains',
        keywords = neg,
    }, body)
end

-- Get Sorted Quick Scenario Indices
function getSortedQuickScenarioIndices()
    if cachedSortedScenarioIdx and cachedSortedScenariosGen == scenariosGen then
        return cachedSortedScenarioIdx
    end
    local idx = {}
    for i = 1, #quickScenarios do idx[i] = i end
    table.sort(idx, function(a, b)
        local la = quickScenarios[a].label or ''
        local lb = quickScenarios[b].label or ''
        if la ~= lb then return la < lb end
        return a < b
    end)
    cachedSortedScenarioIdx = idx
    cachedSortedScenariosGen = scenariosGen
    return idx
end

-- Push Quick Scenario Btn Style
function pushQuickScenarioBtnStyle(isWatch)
    if isWatch then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.22, 0.26, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16, 0.34, 0.40, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.22, 0.48, 0.52, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.75, 0.95, 0.98, 1.0))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.16, 0.28, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.30, 0.22, 0.42, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.Text, col_label)
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 10)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(8, 4))
end

-- Pop Quick Scenario Btn Style
function popQuickScenarioBtnStyle()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(4)
end

-- Quick Btn Width
function quickBtnWidth(label)
    local w = imgui.CalcTextSize(uiText(label or '?')).x + 18
    if w < QUICK_BTN_MIN_W then w = QUICK_BTN_MIN_W end
    if w > QUICK_BTN_MAX_W then w = QUICK_BTN_MAX_W end
    return w
end

-- Layout Quick Button Rows
function layoutQuickButtonRows(quickBtns, maxWidth)
    local rows = {}
    local cur = {}
    local curW = 0
    maxWidth = math.max(80, tonumber(maxWidth) or 80)
    for _, qb in ipairs(quickBtns or {}) do
        local w = qb.btnW or QUICK_BTN_MIN_W
        local add = w + (#cur > 0 and QUICK_BTN_PAD or 0)
        if #cur > 0 and curW + add > maxWidth then
            rows[#rows + 1] = cur
            cur = { qb }
            curW = w
        else
            cur[#cur + 1] = qb
            curW = curW + add
        end
    end
    if #cur > 0 then rows[#rows + 1] = cur end
    local h = 0
    if #rows > 0 then
        h = #rows * QUICK_BTN_H + (#rows - 1) * QUICK_BTN_ROW_GAP + QUICK_BTN_BLOCK_TOP
    end
    return rows, h
end

-- Split Quick Buttons
function splitQuickButtons(quickBtns)
    local watch, reply = {}, {}
    for _, qb in ipairs(quickBtns or {}) do
        if qb.scenario and qb.scenario.action == 'watch' then
            watch[#watch + 1] = qb
        else
            reply[#reply + 1] = qb
        end
    end
    return watch, reply
end

-- Quick Buttons Inline Width
function quickButtonsInlineWidth(btns)
    local w = 0
    for _, qb in ipairs(btns or {}) do
        w = w + (qb.btnW or QUICK_BTN_MIN_W) + QUICK_BTN_PAD
    end
    if w > 0 then w = w + 8 end
    return w
end

local LBL_ACT_SLAP = '\xCF\xE5\xF0\xE5\xE2\xE5\xF0\xED\xF3\xF2\xFC'
local LBL_ACT_TR = '\xC8\xE7 \xE2\xEE\xE4\xFB'

-- Message Body For Scenarios
function messageBodyForScenarios(m)
    if not m then return '' end
    local body = trim(m.text or '')
    if body == '' then body = trim(m.displayText or '') end
    if body == '' then body = trim(m.rawText or '') end
    if body == '' and m.raw then body = trim(tostring(m.raw)) end
    return body
end

-- Player Message Scenario Body
function playerMessageScenarioBody(m)
    if not messageShowsScenarioButtons(m) then return '' end
    local body = messageBodyForScenarios(m)
    if body == '' then body = trim(m.text or '') end
    return body
end

-- Get Last Player Scenario Body
function getLastPlayerScenarioBody(t)
    if not t or type(t.messages) ~= 'table' then return '' end
    for i = #t.messages, 1, -1 do
        local body = playerMessageScenarioBody(t.messages[i])
        if body ~= '' and #collectQuickButtonsForMessage(body) > 0 then
            return body
        end
    end
    return ''
end

-- Find Last Player Scenario Msg Idx
function findLastPlayerScenarioMsgIdx(msgs, renderFrom)
    renderFrom = tonumber(renderFrom) or 1
    if type(msgs) ~= 'table' then return nil end
    for i = #msgs, renderFrom, -1 do
        local body = playerMessageScenarioBody(msgs[i])
        if body ~= '' and #collectQuickButtonsForMessage(body) > 0 then
            return i
        end
    end
    return nil
end

-- Message Shows Scenario Buttons
function messageShowsScenarioButtons(m)
    if not m then return false end
    local k = messageKind(m)
    if k == 'player' then return true end
    if m.dir == 'in' and k ~= 'action' and k ~= 'punish' and k ~= 'reply' and k ~= 'reply_self' then
        return true
    end
    return false
end

-- Preview Quick Scenario Text
function previewQuickScenarioText(sc, reporter, messageText)
    if not sc then return '' end
    if sc.action == 'watch' then
        local suspectId = extractSuspectIdForWatch(messageText or '')
        local notify = trim(sc.reply or '')
        if notify == '' then notify = trim(settings.watch_notify or 'see') end
        notify = expandTemplate(notify, getResolvedAnsId(reporter))
        return '/sp ' .. tostring(suspectId or '?') .. '\n' .. notify
    end
    local text = trim(sc.reply or '')
    if text == '' then
        return '\xCF\xF3\xF1\xF2\xEE\xE9 \xEE\xF2\xE2\xE5\xF2 \xE2 \xF1\xF6\xE5\xED\xE0\xF0\xE8\xE8'
    end
    return expandTemplate(text, getResolvedAnsId(reporter))
end

-- Draw Quick Scenario Tooltip
function drawQuickScenarioTooltip(sc, reporter, messageText)
    if not sc then return end
    local body = previewQuickScenarioText(sc, reporter, messageText)
    if body == '' then return end
    imgui.TextWrapped(uiText(truncate(body, 220)))
end

-- Quick Scenario Display Label
function quickScenarioDisplayLabel(label)
    return ellipsizeToWidth(uiText(label or '?'), QUICK_BTN_MAX_W - 12)
end

-- Draw Quick Scenario Button
function drawQuickScenarioButton(sc, lbl, btnId, btnW, scenarioText, reporter)
    local isWatch = sc and sc.action == 'watch'
    pushQuickScenarioBtnStyle(isWatch)
    local clicked = imgui.Button(lbl .. btnId, imgui.ImVec2(btnW, QUICK_BTN_H))
    if imgui.IsItemHovered() then
        if imgui.BeginTooltip then
            imgui.BeginTooltip()
            if imgui.PushTextWrapPos then imgui.PushTextWrapPos(380) end
            drawQuickScenarioTooltip(sc, reporter, scenarioText)
            if imgui.PopTextWrapPos then imgui.PopTextWrapPos() end
            imgui.EndTooltip()
        elseif imgui.SetTooltip then
            local body = truncate(previewQuickScenarioText(sc, reporter, scenarioText), 120)
            if body ~= '' then
                imgui.SetTooltip(uiText(body))
            end
        end
    end
    if clicked then
        executeQuickScenario(sc, reporter, scenarioText)
    end
    popQuickScenarioBtnStyle()
end

-- Draw Inline Watch Buttons
function drawInlineWatchButtons(watchBtns, localX, localY, btnX, btnY, scenarioText, reporter, msgIdx)
    if not watchBtns or #watchBtns < 1 then return end
    imgui.PushID((msgIdx or 0) * 1000 + 7)
    imgui.SetCursorPos(imgui.ImVec2(btnX, btnY))
    for qi, qb in ipairs(watchBtns) do
        if qi > 1 then imgui.SameLine(0, QUICK_BTN_PAD) end
        local sc = qb.scenario
        local disp = quickScenarioDisplayLabel(sc.label or '?')
        drawQuickScenarioButton(sc, disp, '##qbw' .. qi, qb.btnW, scenarioText, reporter)
    end
    imgui.PopID()
end

-- Draw Quick Scenario Buttons
function drawQuickScenarioButtons(quickBtns, localX, localY, btnRowY, rowW, padSide, scenarioText, reporter, msgIdx)
    if not quickBtns or #quickBtns < 1 then return end
    local btnAreaW = math.max(80, rowW - padSide * 2)
    local rows, _ = layoutQuickButtonRows(quickBtns, btnAreaW)
    if #rows < 1 then return end

    imgui.PushID(msgIdx or 0)
    local startX = localX + padSide
    for ri, row in ipairs(rows) do
        local y = localY + btnRowY + (ri - 1) * (QUICK_BTN_H + QUICK_BTN_ROW_GAP)
        imgui.SetCursorPos(imgui.ImVec2(startX, y))
        for qi, qb in ipairs(row) do
            if qi > 1 then imgui.SameLine(0, QUICK_BTN_PAD) end
            local sc = qb.scenario
            local disp = quickScenarioDisplayLabel(sc.label or '?')
            drawQuickScenarioButton(sc, disp, '##qb' .. ri .. '_' .. qi, qb.btnW, scenarioText, reporter)
        end
    end
    imgui.PopID()
end

-- Scenario Guard Blocks
function scenarioGuardBlocks(sc, text)
    if not sc or not text then return false end
    local reply = trim(sc.reply or '')
    local msg, _, msgTypo = matchMessageVariants(text)
    local bags = { msg, msgTypo }
    local function anyPat(pat)
        for _, bag in ipairs(bags) do
            if bag ~= '' and bag:find(pat) then return true end
        end
        return false
    end
    if reply:find('/c 090', 1, true) then
        if anyPat('\xEA\xE2\xE5\xF1\xF2') and anyPat('\xEC\xE5\xF5\xE0\xED\xE8\xEA') then return true end
        if anyPat('\xE7\xE0\xEA\xEB\xE0\xE4') then return true end
        if anyPat('\xF3\xF7\xE0\xF1\xF2\xEA') and not anyPat('090') then return true end
        if anyPat('\xEC\xE5\xF5\xE0\xED\xE8\xEA') and not anyPat('\xE2\xFB\xE7\xE2\xE0\xF2\xFC')
            and not anyPat('090') and not anyPat('\xFD\xE2\xE0\xEA\xF3\xE0\xF2\xEE\xF0')
            and not anyPat('010') and not anyPat('\xEF\xEE\xEB\xEE\xEC') then
            return true
        end
    end
    if reply:find('\xC0\xC7\xD1', 1, true) or reply:find('\xEA\xE0\xED\xE8\xF1\xF2\xF0', 1, true) then
        if anyPat('\xE7\xE0\xEF\xF0\xE0\xE2') and anyPat('\xE8\xE3\xF0\xEE\xEA')
            and not anyPat('\xE1\xE5\xED\xE7\xE8\xED') and not anyPat('\xF2\xEE\xEF\xEB\xE8\xE2')
            and not anyPat('\xEA\xE0\xED\xE8\xF1\xF2\xF0') then
            return true
        end
        if anyPat('\xEA\xEE\xED\xF2\xF0\xE0\xEA\xF2') and not anyPat('\xE1\xE5\xED\xE7\xE8\xED')
            and not anyPat('\xE0\xE7\xF1') then
            return true
        end
    end
    if reply:find('creditshelp', 1, true) then
        if not anyPat('\xE0\xE4\xE2\xE0\xED\xF1') and not anyPat('credits') and not anyPat('donate')
            and not anyPat('credit') and anyPat('\xEA\xF0\xE5\xE4\xE8\xF2') then
            return true
        end
    end
    if reply:find('/bp', 1, true) or reply:find('/mn 8', 1, true) then
        if anyPat('\xEA\xE2\xE5\xF1\xF2') and not anyPat('\xE1\xEF') and not anyPat('battle')
            and not anyPat('\xE1\xE0\xF2\xEB') then
            return true
        end
    end
    return false
end

-- Scenario Visible On Message
function scenarioVisibleOnMessage(sc, text)
    if not sc or not sc.enabled then return false end
    if sc.action == 'watch' then
        return extractSuspectIdForWatch(text) ~= nil
    end
    if sc.skip_if_report_id ~= false
        and textLooksLikePlayerReport(text)
        and extractSuspectIdFromReport(text) then
        return false
    end
    if scenarioGuardBlocks(sc, text) then return false end
    if not quickScenarioMatches(sc, text) then return false end
    if quickScenarioNegativeMatches(sc, text) then return false end
    return true
end

-- Collect Quick Buttons For Message
function collectQuickButtonsForMessage(text)
    local cacheKey = normalizeMatchText(text)
    local sig = tostring(scenariosGen) .. '|' .. tostring(#quickScenarios)
    if cacheKey ~= '' then
        local hit = deskCache.quickBtn[cacheKey]
        if hit and hit.sig == sig then return hit.btns end
    end
    local candidates = {}
    for i = 1, #quickScenarios do
        local sc = quickScenarios[i]
        if scenarioVisibleOnMessage(sc, text) then
            local score = scenarioMatchScore(sc, text)
            if score <= 0 and quickScenarioMatches(sc, text) then
                score = 10
            end
            if score > 0 then
                candidates[#candidates + 1] = {
                    scenario = sc,
                    idx = i,
                    score = score,
                    btnW = quickBtnWidth(sc.label),
                    suspectId = sc.action == 'watch' and extractSuspectIdForWatch(text) or nil,
                }
            end
        end
    end
    table.sort(candidates, function(a, b)
        local pa = tonumber(a.scenario.priority) or 0
        local pb = tonumber(b.scenario.priority) or 0
        if pa ~= pb then return pa > pb end
        if a.score ~= b.score then return a.score > b.score end
        return (a.scenario.label or '') < (b.scenario.label or '')
    end)
    local out = {}
    for i = 1, math.min(6, #candidates) do
        out[i] = candidates[i]
    end
    local watchId = extractSuspectIdForWatch(text)
    if watchId then
        local hasWatch = false
        for _, qb in ipairs(out) do
            if qb.scenario and qb.scenario.action == 'watch' then
                hasWatch = true
                break
            end
        end
        if not hasWatch then
            local wsc = getWatchButtonScenario()
            table.insert(out, 1, {
                scenario = wsc,
                idx = 0,
                btnW = quickBtnWidth(wsc.label),
                suspectId = watchId,
            })
        end
    end
    if cacheKey ~= '' then
        deskCache.quickBtn[cacheKey] = { sig = sig, btns = out }
    end
    return out
end

-- Execute Quick Scenario
function executeQuickScenario(sc, reporter, messageText)
    if not sc or not reporter then return end
    if sc.action == 'watch' then
        local suspectId = extractSuspectIdForWatch(messageText or '')
        if not suspectId then return end
        local notify = trim(sc.reply or '')
        if notify == '' then notify = trim(settings.watch_notify or 'see') end
        executeWatchSuspect(reporter, suspectId, notify)
        return
    end
    local text = trim(sc.reply or '')
    if text == '' then
        say('\xCF\xF3\xF1\xF2\xEE\xE9 \xEE\xF2\xE2\xE5\xF2 \xEF\xF3\xF1\xF2')
        return
    end
    text = expandTemplate(text, getResolvedAnsId(reporter))
    local tk = threadStorageKey(reporter)
    local ok, res = sendOutgoingAns(reporter, text, {
        threadKey = tk,
        scenarioLabel = sc.label or '',
        scenarioQuestion = messageText or '',
    })
    if ok then
        clearThreadRuleCooldowns(tk)
        say('\xCE\xF2\xEF\xF0\xE0\xE2\xEB\xE5\xED\xEE: ' .. (sc.label or ''))
    elseif res then
        say(res)
    end
end

-- Execute Watch Suspect
function executeWatchSuspect(reporter, suspectId, notifyOverride)
    if not reporter or not suspectId then return end
    local notify = trim(notifyOverride or settings.watch_notify or 'see')
    if notify == '' then notify = 'see' end
    local ansId, err = resolveAnsIdForReply(reporter)
    if not ansId then
        say(err or '\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC \xF0\xE5\xEF\xEE\xF0\xF2\xE5\xF0\xF3')
        releaseDeskInputCapture(true)
        closeDeskWindow()
        sendChat('sp ' .. suspectId)
        return
    end
    notify = expandTemplate(notify, ansId)
    local reporterNick = reporter.nick or ''
    releaseDeskInputCapture(true)
    closeDeskWindow()
    sendChat('sp ' .. suspectId)
    if settings.watch_auto_notify ~= false then
        scheduleWatchNotify(reporterNick, ansId, notify)
    end
end

-- Normalize Stored Message
function normalizeStoredMessage(m)
    if type(m) ~= 'table' then return end
    if m.adminNick and m.dir ~= 'system' and m.dir ~= 'out' and m.dir ~= 'event' then
        m.dir = 'out'
        m.self = false
    end
    if m.dir == 'event' then return end
    if m.kind then return end
    local txt = trim(m.text or '')
    if m.dir == 'in' and txt ~= '' then
        if deskIngest.isPlayerChannelMessage(m.raw or m.channel or '') then
            m.kind = 'player'
            return
        end
        if deskIngest.looksLikeAdminActionText(txt) then
            m.dir = 'event'
            m.kind = 'action'
            return
        end
        if txt:find('\xE2\xFB\xE4\xE0\xEB', 1, true) or txt:find('\xED\xE0\xEA\xE0\xE7', 1, true)
            or txt:find('warn', 1, true) or txt:find('jail', 1, true)
            or txt:find('ban', 1, true) or txt:find('mute', 1, true) then
            m.dir = 'event'
            m.kind = 'punish'
            return
        end
    end
    if m.dir == 'out' then
        m.kind = m.self and 'reply_self' or 'reply'
        return
    end
    if m.dir == 'in' then
        m.kind = 'player'
    end
end

-- Message Kind
function messageKind(m)
    if not m then return 'player' end
    if m.kind then return m.kind end
    if m.dir == 'event' then return 'action' end
    if m.dir == 'system' then return 'system' end
    if m.dir == 'out' then return m.self and 'reply_self' or 'reply' end
    return 'player'
end

-- Message Display Dir
function messageDisplayDir(m)
    local k = messageKind(m)
    if k == 'action' or k == 'punish' then return 'event' end
    if k == 'reply' or k == 'reply_self' then return 'out' end
    if k == 'system' then return 'system' end
    if m.adminNick and m.dir == 'in' then return 'out' end
    return m.dir or 'in'
end

-- Message Author Key
function messageAuthorKey(m)
    if not m then return '' end
    local dir = messageDisplayDir(m)
    local kind = messageKind(m)
    if dir == 'system' then return 'system' end
    if dir == 'event' then
        if kind == 'punish' then return 'event:punish' end
        return 'event:action:' .. tostring(m.actionKind or 'other')
    end
    if dir == 'out' then
        if m.self then return 'self' end
        return 'admin:' .. trim(m.adminNick or '?')
    end
    return 'player'
end

-- Can Group Chat Messages
function canGroupChatMessages(prev, curr)
    if not prev or not curr then return false end
    local pDir = messageDisplayDir(prev)
    local cDir = messageDisplayDir(curr)
    if pDir == 'event' or pDir == 'system' or cDir == 'event' or cDir == 'system' then
        return false
    end
    if pDir ~= cDir then return false end
    if messageAuthorKey(prev) ~= messageAuthorKey(curr) then return false end
    local pts = tonumber(prev.ts) or 0
    local cts = tonumber(curr.ts) or 0
    if pts > 0 and cts > 0 and math.abs(cts - pts) > CHAT_GROUP_MAX_SEC then
        return false
    end
    return true
end

-- Action Line For Chat
function actionLineForChat(m, reporter)
    local body = trim(m.text or '')
    local adminNick = trim(m.adminNick or '')
    if trim(m.displayText or '') ~= '' and not m.displayText:find('\n') then
        return trim(m.displayText)
    end
    local tgt = reporter and trim(reporter.nick or '') or trim(m.targetNick or '')
    local tid = m.targetId or (reporter and reporter.id)
    return deskIngest.formatActionDisplay(adminNick, tgt, tid, body, {
        title = m.actionTitle,
        detail = body,
        kind = m.actionKind,
    })
end

-- Truncate
function truncate(s, n)
    s = trim(s or '')
    if #s <= n then return s end
    return s:sub(1, n - 3) .. '...'
end

-- Clone Rules
function cloneRules(src, fromUtf8)
    fromUtf8 = fromUtf8 == true
    local out = {}
    for i, r in ipairs(src or {}) do
        local kw = {}
        if type(r.keywords) == 'table' then
            for _, k in ipairs(r.keywords) do
                kw[#kw + 1] = normalizeStoredText(k, fromUtf8)
            end
        end
        out[i] = {
            name = normalizeStoredText(r.name or '', fromUtf8),
            enabled = r.enabled ~= false,
            match = r.match or 'exact',
            keywords = kw,
            action = r.action or 'ans_text',
            payload = normalizeStoredText(r.payload or '', fromUtf8),
            cooldown = tonumber(r.cooldown) or 120,
            mode = r.mode or 'instant',
            priority = tonumber(r.priority) or 0,
            skip_if_report_id = r.skip_if_report_id ~= false,
        }
    end
    return out
end

-- Rule Name Exists
function ruleNameExists(name)
    return false
end

-- Append Faq Pack Rules
function appendFaqPackRules()
    return 0
end

-- Trim Messages
function trimMessages(msgs)
    local limit = DEFAULT_HISTORY_LIMIT
    while #msgs > limit do
        table.remove(msgs, 1)
    end
end

-- Nick Key
function nickKey(nick)
    return trim(nick or ''):lower()
end

-- Sync Thread Ids From Player Cache
function syncThreadIdsFromPlayerCache()
    local dirty = false
    for _, t in pairs(threads) do
        local liveId = playerNickToId[nickKey(t.nick)]
        if liveId ~= nil and t.id ~= liveId then
            t.lastId = t.id
            t.id = liveId
            dirty = true
        end
    end
    if dirty then markDirtyThreads() end
end

-- Refresh Player Nick Cache
function refreshPlayerNickCache(force)
    local now = os.clock()
    if not force and playerNickCacheAt > 0 and (now - playerNickCacheAt) < PLAYER_NICK_CACHE_INTERVAL then
        return false
    end
    playerNickCacheAt = now
    playerNickToId = {}
    if not isSampAvailable() then return true end
    local maxId = MAX_PLAYER_ID
    if sampGetMaxPlayerId then
        maxId = sampGetMaxPlayerId(false) or maxId
    end
    for i = 0, maxId do
        if sampIsPlayerConnected(i) then
            local pn = sampGetPlayerNickname(i)
            if pn then
                local nk = nickKey(pn)
                if nk ~= '' then
                    playerNickToId[nk] = i
                end
            end
        end
    end
    syncThreadIdsFromPlayerCache()
    return true
end

-- Find Player Id By Nick
function findPlayerIdByNick(nick)
    refreshPlayerNickCache(false)
    local nk = nickKey(nick)
    if nk == '' then return nil end
    return playerNickToId[nk]
end

-- Find Thread Key By Nick
function findThreadKeyByNick(nick)
    local nk = nickKey(nick)
    if nk == '' then return nil end
    if threads[nk] then return nk end
    return deskCache.nickKeys[nk]
end

-- Register Nick Index
function registerNickIndex(key, t)
    if not key or not t then return end
    local nk = nickKey(t.nick)
    if nk ~= '' then deskCache.nickKeys[nk] = key end
end

-- Live Nick For Player Id
function liveNickForPlayerId(id)
    id = tonumber(id)
    if not id or id < 0 then return '' end
    if type(sampIsPlayerConnected) == 'function' and sampIsPlayerConnected(id) then
        return trim(sampGetPlayerNickname(id) or '')
    end
    return ''
end

-- Find Threads By Player Id
function findThreadsByPlayerId(id)
    id = tonumber(id)
    local out = {}
    if not id then return out end
    for key, t in pairs(threads) do
        if tonumber(t.id) == id then
            out[#out + 1] = { key = key, t = t }
        end
    end
    return out
end

-- Threads Same Identity
function threadsSameIdentity(a, b)
    if not a or not b or a == b then return true end
    if nickKey(a.nick) == nickKey(b.nick) and nickKey(a.nick) ~= '' then return true end
    local aid, bid = tonumber(a.id), tonumber(b.id)
    if aid and bid and aid == bid then
        local live = liveNickForPlayerId(aid)
        if live ~= '' and nickKey(live) == nickKey(a.nick) and nickKey(live) == nickKey(b.nick) then
            return true
        end
    end
    return false
end

-- Unique Thread Key
function uniqueThreadKey(base)
    base = trim(base or '')
    if base == '' then base = 'thread' end
    if not threads[base] then return base end
    for n = 2, 99 do
        local k = base .. '#' .. n
        if not threads[k] then return k end
    end
    return base .. '#' .. tostring(os.time())
end

-- Migrate Thread Auxiliaries
function migrateThreadAuxiliaries(oldKey, newKey)
    if not oldKey or not newKey or oldKey == newKey then return end
    if pendingAuto[oldKey] then
        pendingAuto[newKey] = pendingAuto[oldKey]
        pendingAuto[oldKey] = nil
    end
    local prefix = tostring(oldKey) .. ':'
    local toMove = {}
    for rk, untilTs in pairs(ruleCooldowns) do
        if rk:sub(1, #prefix) == prefix then
            toMove[#toMove + 1] = { rk = rk, suffix = rk:sub(#prefix + 1), untilTs = untilTs }
        end
    end
    for _, item in ipairs(toMove) do
        ruleCooldowns[newKey .. ':' .. item.suffix] = item.untilTs
        ruleCooldowns[item.rk] = nil
    end
    for _, e in pairs(outbound.echo) do
        if e.threadKey == oldKey then e.threadKey = newKey end
    end
end

-- Migrate Thread Key
function migrateThreadKey(oldKey, newKey)
    if not oldKey or not newKey or oldKey == newKey then return newKey end
    local src = threads[oldKey]
    if not src then return newKey end
    local dst = threads[newKey]
    if dst and dst ~= src then
        if threadsSameIdentity(src, dst) then
            local seen = {}
            for _, m in ipairs(dst.messages or {}) do
                local mk = (m.dir or '') .. '|' .. normalizeOutboundBody(m.text or m.note or '') .. '|' .. tostring(m.ts or 0)
                seen[mk] = true
            end
            for _, m in ipairs(src.messages or {}) do
                local mk = (m.dir or '') .. '|' .. normalizeOutboundBody(m.text or m.note or '') .. '|' .. tostring(m.ts or 0)
                if not seen[mk] then
                    dst.messages[#dst.messages + 1] = m
                    seen[mk] = true
                end
            end
            trimMessages(dst.messages)
            dst.unread = (dst.unread or 0) + (src.unread or 0)
            if (src.lastAt or 0) > (dst.lastAt or 0) then dst.lastAt = src.lastAt end
            if src.pinned then dst.pinned = true end
        else
            newKey = uniqueThreadKey(newKey)
            threads[newKey] = src
        end
    else
        threads[newKey] = src
    end
    threads[oldKey] = nil
    for i, k in ipairs(threadOrder) do
        if k == oldKey then
            threadOrder[i] = newKey
            break
        end
    end
    if selectedKey == oldKey then selectedKey = newKey end
    migrateThreadAuxiliaries(oldKey, newKey)
    local moved = threads[newKey]
    if moved then moved._storageKey = newKey end
    registerNickIndex(newKey, moved)
    bumpThreadStructRev()
    markDirtyThreads()
    return newKey
end

