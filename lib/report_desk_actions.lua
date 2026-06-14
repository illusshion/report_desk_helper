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

-- ID онлайн-игрока -> ник (общая логика /hist, /iget, /ilog, /iskill).
function resolveOnlinePlayerNickByArg(arg)
    local id = clampSuspectPlayerId(tonumber(trim(tostring(arg or '')):match('(%d+)')))
    if not id then return nil, 'usage' end
    if not isSampAvailable() then return nil, 'samp' end
    if type(sampIsPlayerConnected) ~= 'function' or not sampIsPlayerConnected(id) then
        return nil, 'offline'
    end
    local nick = (type(sampGetPlayerNickname) == 'function' and sampGetPlayerNickname(id)) or ''
    nick = trim(nick)
    if nick == '' then return nil, 'nick' end
    return id, nick
end

function sendNickLookupCommand(arg, serverCmd, minLevel, usageMsg, levelDeniedMsg)
    serverCmd = trim(tostring(serverCmd or ''))
    if serverCmd == '' then return false end
    minLevel = tonumber(minLevel) or 1
    if getLocalAdminLevel() < minLevel then
        if levelDeniedMsg and levelDeniedMsg ~= '' then
            say(levelDeniedMsg)
        end
        return false
    end
    local _, nickOrErr = resolveOnlinePlayerNickByArg(arg)
    if not _ then
        if nickOrErr == 'usage' then
            say(usageMsg or '\xCD\xE5\xE2\xE5\xF0\xED\xFB\xE9 \xE0\xF0\xE3\xF3\xEC\xE5\xED\xF2 \xEA\xEE\xEC\xE0\xED\xE4\xFB.')
        elseif nickOrErr == 'offline' then
            say('\xC8\xE3\xF0\xEE\xEA\xE0 \xF1 \xF2\xE0\xEA\xE8\xEC ID \xED\xE0 \xF1\xE5\xF0\xE2\xE5\xF0\xE5 \xED\xE5\xF2.')
        elseif nickOrErr == 'nick' then
            say('\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEF\xEE\xEB\xF3\xF7\xE8\xF2\xFC \xED\xE8\xEA \xE8\xE3\xF0\xEE\xEA\xE0.')
        end
        return false
    end
    return sendChat(serverCmd .. ' ' .. nickOrErr) == true
end

function getLastSpectateSubject()
    if type(deskSpectateStats) ~= 'table' or type(deskSpectateStats.getLastSubject) ~= 'function' then
        return nil
    end
    local ok, subj = pcall(deskSpectateStats.getLastSubject)
    if not ok or type(subj) ~= 'table' then return nil end
    local nick = trim(subj.nick or '')
    if nick == '' then return nil end
    return {
        id = tonumber(subj.id) or -1,
        nick = nick,
        offline = subj.offline == true,
    }
end

function sendLastOffPunish(cmdBody, minDirectLevel)
    cmdBody = trim(tostring(cmdBody or ''))
    if cmdBody == '' then return false end
    minDirectLevel = tonumber(minDirectLevel) or 4
    if getLocalAdminLevel() >= minDirectLevel then
        return sendChat('/' .. cmdBody) == true
    end
    return sendChat('/a /' .. cmdBody) == true
end

function sendLastOffCommand(arg, usageMsg, minDirectLevel, offCmd, needLeadingNumber)
    arg = trim(tostring(arg or ''))
    if arg == '' then
        say(usageMsg)
        return false
    end
    if needLeadingNumber and not arg:match('^(%d+)') then
        say(usageMsg)
        return false
    end
    local subj = getLastSpectateSubject()
    if not subj then
        say('\xC2\xFB \xE5\xF9\xE5 \xED\xE8 \xE7\xE0 \xEA\xE5\xEC \xED\xE5 \xF1\xEB\xE5\xE4\xE8\xEB\xE8.')
        return false
    end
    offCmd = trim(tostring(offCmd or ''))
    if offCmd == '' then return false end
    return sendLastOffPunish(string.format('%s %s %s.', offCmd, subj.nick, arg), minDirectLevel)
end

function sendHistoryByPlayerId(arg)
    return sendNickLookupCommand(
        arg,
        'history',
        1,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /hist [ID \xE8\xE3\xF0\xEE\xEA\xE0].'
    )
end

function sendGetByPlayerId(arg)
    return sendNickLookupCommand(
        arg,
        'get',
        3,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /iget [ID \xE8\xE3\xF0\xEE\xEA\xE0].',
        '\xC4\xE0\xED\xED\xE0\xFF \xEA\xEE\xEC\xE0\xED\xE4\xE0 \xEF\xF0\xE5\xE4\xED\xE0\xE7\xED\xE0\xF7\xE5\xED\xE0 \xE4\xEB\xFF \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xEE\xE2 3 \xF3\xF0\xEE\xE2\xED\xFF \xE8\xEB\xE8 \xE2\xFB\xF8\xE5.'
    )
end

function sendLogByPlayerId(arg)
    return sendNickLookupCommand(
        arg,
        'log',
        2,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /ilog [ID \xE8\xE3\xF0\xEE\xEA\xE0].',
        '\xC4\xE0\xED\xED\xE0\xFF \xEA\xEE\xEC\xE0\xED\xE4\xE0 \xEF\xF0\xE5\xE4\xED\xE0\xE7\xED\xE0\xF7\xE5\xED\xE0 \xE4\xEB\xFF \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xEE\xE2 2 \xF3\xF0\xEE\xE2\xED\xFF \xE8\xEB\xE8 \xE2\xFB\xF8\xE5.'
    )
end

function sendAskillByPlayerId(arg)
    return sendNickLookupCommand(
        arg,
        'askill',
        1,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /iskill [ID \xE8\xE3\xF0\xEE\xEA\xE0].'
    )
end

function sendWarnLast(arg)
    arg = trim(tostring(arg or ''))
    if arg == '' then
        say('\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /warnlast [\xCF\xF0\xE8\xF7\xE8\xED\xE0].')
        return false
    end
    local subj = getLastSpectateSubject()
    if not subj then
        say('\xC2\xFB \xE5\xF9\xE5 \xED\xE8 \xE7\xE0 \xEA\xE5\xEC \xED\xE5 \xF1\xEB\xE5\xE4\xE8\xEB\xE8.')
        return false
    end
    return sendLastOffPunish(string.format('offwarn %s %s.', subj.nick, arg), 4)
end

function sendBanLast(arg)
    return sendLastOffCommand(
        arg,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /banlast [\xCA\xEE\xEB\xE8\xF7\xE5\xF1\xF2\xE2\xEE \xE4\xED\xE5\xE9] [\xCF\xF0\xE8\xF7\xE8\xED\xE0].',
        4,
        'offban',
        true
    )
end

function sendJailLast(arg)
    return sendLastOffCommand(
        arg,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /jaillast [\xCC\xE8\xED\xF3\xF2\xFB] [\xCF\xF0\xE8\xF7\xE8\xED\xE0].',
        3,
        'offjail',
        true
    )
end

function sendMuteLast(arg)
    return sendLastOffCommand(
        arg,
        '\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /mutelast [\xCC\xE8\xED\xF3\xF2\xFB] [\xCF\xF0\xE8\xF7\xE8\xED\xE0].',
        3,
        'offmute',
        true
    )
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

-- Text Looks Like Player Report
function textLooksLikePlayerReport(text)
    local low = normalizeMatchText(text)
    if low == '' then return false end
    if deskIngest.looksLikeAdminActionText(text) then return false end
    local markers = type(getReportIdMarkers) == 'function' and getReportIdMarkers() or {}
    for _, m in ipairs(markers) do
        if low:find(m, 1, true) then return true end
    end
    return false
end

--[[
    Явный ID нарушителя в репорте (единый источник для «Следить», контекста, ingest).
    Без эвристики «первое число в тексте» — только документированные шаблоны.
    Порядок: N id/ид / id N / N dm → только N → N в начале строки → при маркерах репорта.
]]
local function stripReportSuspectText(text)
    text = trim(text or '')
    if text == '' then return '' end
    if type(stripChatTimestamp) == 'function' then
        text = trim(stripChatTimestamp(text))
    end
    if text == '' then return '' end
    -- Ведущее HH:MM:SS в теле сообщения (не ID нарушителя).
    text = text:gsub('^%d%d?:%d%d:?%d%d?%s+', '')
    return trim(text)
end

local function extractReportSuspectIdCore(text, opts)
    opts = opts or {}
    text = trim(text or '')
    if text == '' or not text:find('%d') then return nil end
    if opts.prepareText then
        text = stripReportSuspectText(text)
        if text == '' then return nil end
    end
    if opts.rejectStatusBody
            and deskIngest.looksLikePlayerStatusBody
            and deskIngest.looksLikePlayerStatusBody(text) then
        return nil
    end

    local id = text:match('(%d+)%s*[iI\xE8\xC8][dD\xE4\xC4]')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('[iI\xE8\xC8][dD\xE4\xC4]%s*(%d+)')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('(%d+)%s*[dD][mM]')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('^(%d+)$')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('^(%d+)[%s%,%.%-%):;]')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('^(%d+)%s+[%a\xC0-\xFF]')
    if id then return clampSuspectPlayerId(id) end

    if not textLooksLikePlayerReport(text) then return nil end

    id = text:match('(%d+)%s+[%a\xC0-\xFF]')
    if id then return clampSuspectPlayerId(id) end

    id = text:match('[%s%p](%d+)%s*$')
    if id then return clampSuspectPlayerId(id) end

    return nil
end

function extractReportSuspectId(text)
    return extractReportSuspectIdCore(text, { prepareText = true, rejectStatusBody = true })
end

function extractSuspectIdFromReport(text)
    return extractReportSuspectIdCore(text, { prepareText = false, rejectStatusBody = false })
end

function extractSuspectIdForWatch(text)
    return extractReportSuspectId(text)
end

-- Message Eligible For Watch Button
function messageEligibleForWatchButton(text, context)
    if context == INTENT_CONTEXT_THANKS then
        return false
    end
    return extractReportSuspectId(text) ~= nil
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

-- Push Quick Scenario Btn Style
function pushQuickScenarioBtnStyle(isWatch)
    if isWatch then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.22, 0.26, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16, 0.34, 0.40, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.22, 0.48, 0.52, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.75, 0.95, 0.98, 1.0))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.16, 0.24, 0.96))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.28, 0.22, 0.38, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.Text, col_label)
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 10)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 5))
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

-- Last Player Scenario Body
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

-- Message Qualifies For Scenario Actions
function messageQualifiesForScenarioActions(body)
    body = trim(body or '')
    if body == '' then return false end
    if #collectQuickButtonsForMessage(body) > 0 then return true end
    if type(intentMessageCorpusCandidate) == 'function' and intentMessageCorpusCandidate(body) then
        return true
    end
    return false
end

-- Find Last Player Scenario Msg Idx
function findLastPlayerScenarioMsgIdx(msgs, renderFrom)
    renderFrom = tonumber(renderFrom) or 1
    if type(msgs) ~= 'table' then return nil end
    for i = #msgs, renderFrom, -1 do
        local body = playerMessageScenarioBody(msgs[i])
        if messageQualifiesForScenarioActions(body) then
            return i
        end
    end
    return nil
end

-- Message Shows Scenario Buttons
function messageShowsScenarioButtons(m)
    if not m then return false end
    return messageKind(m) == 'player'
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

-- Текст на кнопке = то, что уйдёт игроку (не заголовок сценария).
function quickScenarioButtonPlainText(sc, reporter, scenarioText)
    local body = previewQuickScenarioText(sc, reporter, scenarioText)
    body = body:gsub('\r\n', '\n'):gsub('\n+', ' · ')
    return trim(body)
end

function quickScenarioButtonCaption(sc, reporter, scenarioText)
    if sc and sc.action == 'watch' then
        local lbl = trim(sc.label or '') ~= '' and sc.label or '\xD1\xEB\xE5\xE4\xE8\xF2\xFC'
        return ellipsizeToWidth(uiText(lbl), QUICK_BTN_MAX_W - 12)
    end
    local body = quickScenarioButtonPlainText(sc, reporter, scenarioText)
    if body == '' then body = trim(sc and sc.label or '') or '?' end
    return ellipsizeToWidth(uiText(body), QUICK_BTN_MAX_W - 12)
end

function quickBtnWidthForScenario(sc, reporter, scenarioText)
    if sc and sc.action == 'watch' then
        local lbl = trim(sc.label or '') ~= '' and sc.label or '\xD1\xEB\xE5\xE4\xE8\xF2\xFC'
        return quickBtnWidth(lbl)
    end
    local body = quickScenarioButtonPlainText(sc, reporter, scenarioText)
    if body == '' then body = trim(sc and sc.label or '') or '?' end
    return quickBtnWidth(body)
end

function prepareQuickButtonWidths(quickBtns, reporter, scenarioText)
    for _, qb in ipairs(quickBtns or {}) do
        if qb.scenario then
            qb.btnW = quickBtnWidthForScenario(qb.scenario, reporter, scenarioText)
        end
    end
end

-- Draw Quick Scenario Button
function drawQuickScenarioButton(sc, lbl, btnId, btnW, scenarioText, reporter)
    local isWatch = sc and sc.action == 'watch'
    pushQuickScenarioBtnStyle(isWatch)
    local clicked = imgui.Button(lbl .. btnId, imgui.ImVec2(btnW, QUICK_BTN_H))
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
        local disp = quickScenarioButtonCaption(sc, reporter, scenarioText)
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
            local disp = quickScenarioButtonCaption(sc, reporter, scenarioText)
            drawQuickScenarioButton(sc, disp, '##qb' .. ri .. '_' .. qi, qb.btnW, scenarioText, reporter)
        end
    end
    imgui.PopID()
end

-- Collect Quick Buttons For Message
function collectQuickButtonsForMessage(text)
    local bags = intentNormalizeBags(text)
    local cacheKey = bags.key
    local sig = tostring(intentsGen) .. '|' .. tostring(#deskIntents)
    if cacheKey ~= '' and type(deskCache) == 'table' and deskCache.quickBtn then
        local hit = deskCache.quickBtn[cacheKey]
        if hit and hit.sig == sig then return hit.btns end
    end

    local results, ctx = resolveMessageIntents(text)
    local out = {}
    for _, r in ipairs(results) do
        local sc = intentToQuickScenario(r.intent)
        if sc then
            out[#out + 1] = {
                scenario = sc,
                idx = 0,
                score = r.score,
                btnW = quickBtnWidth(sc.reply or sc.label),
                suspectId = sc.action == 'watch' and extractSuspectIdForWatch(text) or nil,
                intentId = r.id,
                context = ctx,
            }
        end
    end

    if cacheKey ~= '' and type(deskCache) == 'table' and type(touchLruCache) == 'function' then
        deskCache.quickBtn = deskCache.quickBtn or {}
        deskCache.quickBtnOrder = deskCache.quickBtnOrder or {}
        touchLruCache(deskCache.quickBtn, deskCache.quickBtnOrder, cacheKey, { sig = sig, btns = out }, 500)
    end
    return out
end

-- Intent corpus queue: ручное «В базу» у промахов в чате треда.
INTENT_CORPUS_BTN_H = 20
intentCorpusQueue = intentCorpusQueue or { seen = {}, loaded = false }

local function intentCorpusJsonUnescape(s)
    s = tostring(s or '')
    return s:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\"', '"'):gsub('\\\\', '\\')
end

local function intentCorpusJsonStr(s)
    s = tostring(s or '')
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', '\\r'):gsub('\n', '\\n')
    return '"' .. s .. '"'
end

-- JSONL хранит UTF-8; в Lua/игре строки CP1251.
local function intentCorpusTextFromFile(raw)
    raw = intentCorpusJsonUnescape(raw or '')
    if raw == '' then return '' end
    if isUtf8Text(raw) then return utf8ToCp1251(raw) end
    return raw
end

local function intentCorpusTextToFile(cp1251Text)
    cp1251Text = tostring(cp1251Text or '')
    if cp1251Text == '' then return '' end
    if type(configStoreText) == 'function' then
        return configStoreText(cp1251Text)
    end
    return cp1251ToUtf8(cp1251Text)
end

local function intentCorpusParseMatchedIds(line)
    local block = line:match('"matched"%s*:%s*%[([^%]]*)%]')
    if not block or block == '' then return nil end
    local out = {}
    for id in block:gmatch('"([^"\\]*(?:\\.[^"\\]*)*)"') do
        id = intentCorpusTextFromFile(id)
        if trim(id) ~= '' then out[#out + 1] = id end
    end
    if #out < 1 then return nil end
    return out
end

local function intentCorpusParseLine(line)
    if not line or line == '' then return nil end
    local phrase = line:match('"phrase"%s*:%s*"([^"\\]*(?:\\.[^"\\]*)*)"')
    if not phrase then return nil end
    local reply = line:match('"reply"%s*:%s*"([^"\\]*(?:\\.[^"\\]*)*)"') or ''
    return {
        phrase = phrase,
        reply = reply,
    }
end

local function intentCorpusFormatMatchedIds(matched)
    if type(matched) ~= 'table' or #matched < 1 then return '' end
    local parts = {}
    for _, id in ipairs(matched) do
        id = trim(tostring(id or ''))
        if id ~= '' then
            parts[#parts + 1] = intentCorpusJsonStr(intentCorpusTextToFile(id))
        end
    end
    if #parts < 1 then return '' end
    return ',"matched":[' .. table.concat(parts, ',') .. ']'
end

local function intentCorpusFormatLine(entry)
    local phrase = intentCorpusTextToFile(intentCorpusTextFromFile(entry.phrase))
    local reply = intentCorpusTextToFile(intentCorpusTextFromFile(entry.reply or ''))
    return string.format(
        '{"phrase":%s,"reply":%s}',
        intentCorpusJsonStr(phrase), intentCorpusJsonStr(reply)
    )
end

local function intentCorpusFileNeedsUtf8Migrate(path)
    local f = io.open(path, 'rb')
    if not f then return false end
    for line in f:lines() do
        local phrase = line:match('"phrase"%s*:%s*"([^"\\]*(?:\\.[^"\\]*)*)"')
        if phrase then
            phrase = intentCorpusJsonUnescape(phrase)
            if phrase ~= '' and not isUtf8Text(phrase) and phrase:find('[\128-\255]') then
                f:close()
                return true
            end
        end
    end
    f:close()
    return false
end

local function migrateIntentCorpusQueueToUtf8(path)
    local f = io.open(path, 'rb')
    if not f then return end
    local entries = {}
    for line in f:lines() do
        local ok, entry = pcall(intentCorpusParseLine, line)
        if ok and entry then entries[#entries + 1] = entry end
    end
    f:close()
    if #entries == 0 then return end
    local out = io.open(path, 'wb')
    if not out then return end
    for i, entry in ipairs(entries) do
        out:write(intentCorpusFormatLine(entry))
        if i < #entries then out:write('\n') end
    end
    out:write('\n')
    out:close()
end

function loadIntentCorpusQueueSeen()
    if intentCorpusQueue.loaded then return end
    intentCorpusQueue.loaded = true
    intentCorpusQueue.seen = {}
    local path = INTENT_CORPUS_QUEUE_PATH
    if not path or path == '' then return end
    if intentCorpusFileNeedsUtf8Migrate(path) then
        pcall(migrateIntentCorpusQueueToUtf8, path)
    end
    local f = io.open(path, 'rb')
    if not f then return end
    for line in f:lines() do
        local phrase = line:match('"phrase"%s*:%s*"([^"\\]*(?:\\.[^"\\]*)*)"')
        if phrase then
            phrase = intentCorpusTextFromFile(phrase)
            local key = normalizeMatchText(phrase)
            if key ~= '' then intentCorpusQueue.seen[key] = true end
        end
    end
    f:close()
end

function intentCorpusQueueContains(phrase)
    loadIntentCorpusQueueSeen()
    local key = normalizeMatchText(phrase)
    return key ~= '' and intentCorpusQueue.seen[key] == true
end

function appendIntentCorpusPhrase(phrase, meta)
    phrase = trim(phrase or '')
    if phrase == '' or #phrase < 3 then return false, 'empty' end
    loadIntentCorpusQueueSeen()
    local key = normalizeMatchText(phrase)
    if key == '' then return false, 'empty' end
    if intentCorpusQueue.seen[key] then return false, 'dup' end

    local path = INTENT_CORPUS_QUEUE_PATH
    if not path or path == '' then return false, 'io' end
    local f = io.open(path, 'ab')
    if not f then return false, 'io' end
    f:write(intentCorpusFormatLine({
        phrase = phrase,
        reply = '',
    }) .. '\n')
    f:close()
    intentCorpusQueue.seen[key] = true
    return true, 'ok'
end

-- Кнопка «В базу» на входящих репортах (кроме спасибо / пустых / unknown).
function intentMessageCorpusEligible(text)
    text = trim(text or '')
    if text == '' or #text < 3 then return false end
    ensureDeskIntentsLoaded()
    local _, ctx = resolveMessageIntents(text)
    if ctx == INTENT_CONTEXT_THANKS or ctx == INTENT_CONTEXT_UNKNOWN then return false end
    return true
end

function intentCorpusMatchedFromQuickBtns(quickBtns)
    local out, seen = {}, {}
    for _, qb in ipairs(quickBtns or {}) do
        local id = trim(tostring(qb.intentId or ''))
        if id ~= '' and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    if #out < 1 then return nil end
    return out
end

function intentMessageCorpusCandidate(text)
    if not intentMessageCorpusEligible(text) then return false end
    local results = resolveMessageIntents(text)
    return #results < 1
end

function intentCorpusBtnWidth(phrase)
    local saved = intentCorpusQueueContains(phrase)
    local label = saved and '\xC2\xE1\xE0\xE7\xE5' or '\xC2\xE1\xE0\xE7\xF3'
    local w = imgui.CalcTextSize(uiText(label)).x + 14
    if w < 44 then w = 44 end
    if w > 72 then w = 72 end
    return w
end

function pushIntentCorpusBtnStyle(saved)
    if saved then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10, 0.24, 0.16, 0.72))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.10, 0.24, 0.16, 0.72))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.10, 0.24, 0.16, 0.72))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.50, 0.82, 0.58, 0.92))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.16, 0.14, 0.20, 0.42))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.24, 0.20, 0.30, 0.78))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.28, 0.22, 0.36, 0.92))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.68, 0.64, 0.78, 0.88))
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 10)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(6, 2))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, saved and 0 or 1)
    if not saved then
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.38, 0.34, 0.48, 0.35))
    end
end

function popIntentCorpusBtnStyle(saved)
    imgui.PopStyleVar(3)
    imgui.PopStyleColor(4)
    if not saved then imgui.PopStyleColor() end
end

function drawIntentCorpusQueueButton(phrase, reporter, msgIdx, btnX, btnY, opts)
    phrase = trim(phrase or '')
    if phrase == '' then return end
    opts = type(opts) == 'table' and opts or {}
    local saved = intentCorpusQueueContains(phrase)
    local label = saved and '\xC2\xE1\xE0\xE7\xE5' or '\xC2\xE1\xE0\xE7\xF3'
    local btnW = intentCorpusBtnWidth(phrase)
    local matched = opts.matched
    local hasWrongMatch = type(matched) == 'table' and #matched > 0

    imgui.PushID((msgIdx or 0) * 1000 + 99)
    imgui.SetCursorPos(imgui.ImVec2(btnX, btnY))
    pushIntentCorpusBtnStyle(saved)
    local clicked = false
    if saved then
        imgui.Button(uiText(label) .. '##icq', imgui.ImVec2(btnW, INTENT_CORPUS_BTN_H))
    else
        clicked = imgui.Button(uiText(label) .. '##icq', imgui.ImVec2(btnW, INTENT_CORPUS_BTN_H))
    end
    if imgui.IsItemHovered() and imgui.SetTooltip then
        if saved then
            imgui.SetTooltip(uiText(
                '\xD3\xE6\xE5 \xE2 \xE1\xE0\xE7\xE5 \xE4\xEB\xFF \xF0\xE0\xF1\xF8\xE8\xF0\xE5\xED\xE8\xFF \xF2\xF0\xE8\xE3\xE3\xE5\xF0\xEE\xE2'))
        elseif hasWrongMatch then
            imgui.SetTooltip(uiText(
                '\xCE\xF2\xEC\xE5\xF2\xE8\xF2\xFC \xED\xE5\xE2\xE5\xF0\xED\xFB\xE9 \xF1\xF6\xE5\xED\xE0\xF0\xE8\xE9: '
                .. table.concat(matched, ', ')))
        else
            imgui.SetTooltip(uiText(
                '\xD1\xEE\xF5\xF0\xE0\xED\xE8\xF2\xFC \xE2\xEE\xEF\xF0\xEE\xF1 \xE2 \xE1\xE0\xE7\xF3 \xEF\xF0\xEE\xEC\xE0\xF5\xEE\xE2'))
        end
    end
    popIntentCorpusBtnStyle(saved)
    if clicked then
        local ok = appendIntentCorpusPhrase(phrase, {
            thread = reporter and reporter.nick or '',
            threadId = reporter and reporter.id or 0,
            context = opts.context,
            matched = matched,
        })
        if ok and type(say) == 'function' then
            say('\xC4\xEE\xE1\xE0\xE2\xEB\xE5\xED\xEE \xE2 \xE1\xE0\xE7\xF3 intent')
        end
    end
    imgui.PopID()
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
    })
    if ok then
        clearThreadRuleCooldowns(tk)
    elseif res then
        say(res)
    end
end

-- Execute Watch Suspect
function executeWatchSuspect(reporter, suspectId, notifyOverride)
    if not reporter or not suspectId then return end
    suspectId = clampSuspectPlayerId(suspectId)
    if not suspectId then return end
    local notify = trim(notifyOverride or settings.watch_notify or 'see')
    if notify == '' then notify = 'see' end
    local ansId, err = resolveAnsIdForReply(reporter)
    local reporterNick = reporter.nick or ''
    if not ansId then
        say(err or '\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xEE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC \xF0\xE5\xEF\xEE\xF0\xF2\xE5\xF0\xF3')
    else
        notify = expandTemplate(notify, ansId)
    end
    -- Тот же путь, что /sp в шапке: sendGameCmd → sendMenuOutbound (skipSpHookLocal).
    sendGameCmd('sp ' .. suspectId)
    if ansId and settings.watch_auto_notify ~= false then
        scheduleWatchNotify(reporterNick, ansId, notify)
    end
end

-- Сообщение привязано к админу (пустая строка в Lua — truthy, не считать).
function messageHasAdminNick(m)
    return type(m) == 'table' and trim(m.adminNick or '') ~= ''
end

-- Normalize Stored Message
function normalizeStoredMessage(m)
    if type(m) ~= 'table' then return end
    if trim(m.adminNick or '') == '' then
        m.adminNick = nil
    end
    if messageHasAdminNick(m) and m.dir ~= 'system' and m.dir ~= 'out' and m.dir ~= 'event' then
        m.dir = 'out'
        m.self = false
    end
    if m.dir == 'event' then return end
    if m.kind then return end
    local txt = trim(m.text or '')
    if m.dir == 'in' and txt ~= '' then
        if not m.channel then
            m.channel = deskIngest.extractReportChannel(m.raw)
        end
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
    -- Починка: раньше adminNick='' (truthy в Lua) превращал репорт игрока в «ответ админа».
    if m.dir == 'out' and m.self ~= true and not messageHasAdminNick(m) and m.kind == 'reply' then
        m.dir = 'in'
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
    if messageHasAdminNick(m) and m.dir == 'in' then return 'out' end
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
    name = trim(tostring(name or '')):lower()
    if name == '' then return false end
    if type(getActiveBuiltinAutoRules) == 'function' then
        for _, r in ipairs(getActiveBuiltinAutoRules()) do
            if trim(tostring(r and r.name or '')):lower() == name then
                return true
            end
        end
    end
    return false
end

-- Trim Messages
function trimMessages(msgs)
    local limit = DEFAULT_HISTORY_LIMIT
    local removeCount = #msgs - limit
    if removeCount <= 0 then return end
    for i = 1, removeCount do
        local msg = msgs[i]
        if msg then
            msg._cachedWrapW = nil
            msg._cachedLines = nil
        end
    end
    for _ = 1, removeCount do
        table.remove(msgs, 1)
    end
end

-- Nick Key
function nickKey(nick)
    if type(cp1251Lower) == 'function' then
        return cp1251Lower(trim(nick or ''))
    end
    return trim(nick or ''):lower()
end

-- Sync Thread Ids From Player Cache
function syncThreadIdsFromPlayerCache()
    local dirty = false
    for _, t in pairs(threads) do
        local liveId = onlinePlayersGetIdByNick(t.nick)
        if liveId ~= nil then
            if t.id ~= liveId then
                t.lastId = t.id
                t.id = liveId
                dirty = true
            end
            if t.stale then
                t.stale = nil
                dirty = true
            end
        end
    end
    if dirty then markDirtyThreads() end
end

-- Refresh Player Nick Cache (delegates to OnlinePlayers SSOT)
function refreshPlayerNickCache(force)
    return onlinePlayersRescan(force == true)
end

-- Find Player Id By Nick
function findPlayerIdByNick(nick)
    return onlinePlayersGetIdByNick(nick)
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

