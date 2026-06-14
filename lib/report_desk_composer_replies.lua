--[[ Модуль: быстрые ответы и composer (GG/tech/time). ]]

function sendAnsToThread(t, text)
    text = trim(text)
    if text == '' then return false end
    local tk = threadStorageKey(t)
    local ok = sendOutgoingAns(t, text, { threadKey = tk })
    return ok
end

function defaultComposerQuickButtons()
    return {
        { id = 'gg', label = 'GG', text = DEFAULT_GG_REPLY },
        { id = 'tech', label = '\xD2\xE5\xF5\xED\xE8\xF7\xEA\xE0', text = DEFAULT_TECH_REPLY },
    }
end

function normalizeComposerQuickButton(raw, fromUtf8)
    if type(raw) ~= 'table' then return nil end
    fromUtf8 = fromUtf8 or raw._utf8
    local label = trim(normalizeStoredText(raw.label or '', fromUtf8))
    local text = trim(normalizeStoredText(raw.text or '', fromUtf8))
    if type(ensureWireCp1251) == 'function' then
        label = ensureWireCp1251(label)
        text = ensureWireCp1251(text)
    end
    if label == '' or text == '' then return nil end
    local id = trim(tostring(raw.id or ''))
    if id == '' then id = 'qb_' .. tostring(os.clock()):gsub('%.', '') end
    return { id = id, label = label, text = text }
end

function ensureComposerQuickButtons()
    if type(settings.composer_quick_buttons) ~= 'table' or #settings.composer_quick_buttons == 0 then
        local gg = trim(settings.gg_reply or '')
        local tech = trim(settings.tech_reply or '')
        if type(ensureWireCp1251) == 'function' then
            gg = ensureWireCp1251(gg)
            tech = ensureWireCp1251(tech)
        end
        settings.composer_quick_buttons = {
            { id = 'gg', label = 'GG', text = gg ~= '' and gg or DEFAULT_GG_REPLY },
            { id = 'tech', label = '\xD2\xE5\xF5\xED\xE8\xF7\xEA\xE0', text = tech ~= '' and tech or DEFAULT_TECH_REPLY },
        }
        bumpComposerQuickGen()
        return
    end
    local out = {}
    for i, raw in ipairs(settings.composer_quick_buttons) do
        local b = normalizeComposerQuickButton(raw)
        if b then out[#out + 1] = b end
    end
    if #out == 0 then
        settings.composer_quick_buttons = defaultComposerQuickButtons()
    else
        settings.composer_quick_buttons = out
    end
    bumpComposerQuickGen()
end

function syncLegacyGgTechFromComposerButtons()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'gg' then settings.gg_reply = b.text end
        if b.id == 'tech' then settings.tech_reply = b.text end
    end
end

function getTimeReplyText()
    local text = trim(settings.time_reply or '')
    if text == '' then text = DEFAULT_TIME_REPLY end
    if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
    return text
end

function syncGgReplyToComposer(text)
    text = trim(text or '')
    if text == '' then return end
    settings.gg_reply = text
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'gg' then b.text = text end
    end
end

function getGgReplyText()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'gg' then
            local text = b.text
            if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
            return text
        end
    end
    local text = trim(settings.gg_reply or '')
    if text == '' then text = DEFAULT_GG_REPLY end
    if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
    return text
end

function getTechReplyText()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'tech' then
            local text = b.text
            if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
            return text
        end
    end
    local text = trim(settings.tech_reply or '')
    if text == '' then text = DEFAULT_TECH_REPLY end
    if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
    return text
end

function sendReplyToSelected()
    local t, key = getSelectedThread()
    if not t then return false end
    local text = expandTemplate(readInputBuf(replyBuf), getResolvedAnsId(t))
    if text == '' then return false end
    local uiKey = (key or threadStorageKey(t) or '') .. '|' .. normalizeOutboundBody(text)
    local now = os.clock()
    if replyUi.key == uiKey and (now - replyUi.at) < 0.8 then
        return false
    end
    local ok, err = sendOutgoingAns(t, text, { threadKey = key })
    if ok then
        clearThreadRuleCooldowns(key or threadStorageKey(t))
        replyUi.key = uiKey
        replyUi.at = now
        return true
    end
    if err then say(tostring(err)) end
    return false
end

function sendPresetReplyToSelected(kind, getText)
    local t, key = getSelectedThread()
    if not t then return false end
    local text = expandTemplate(getText(), getResolvedAnsId(t))
    local uiKey = (key or threadStorageKey(t) or '') .. '|' .. (kind or 'preset') .. '|' .. normalizeOutboundBody(text)
    local now = os.clock()
    if replyUi.key == uiKey and (now - replyUi.at) < 0.8 then
        return false
    end
    local ok, err = sendOutgoingAns(t, text, { threadKey = key })
    if ok then
        clearThreadRuleCooldowns(key or threadStorageKey(t))
        replyUi.key = uiKey
        replyUi.at = now
        return true
    end
    if err then say(tostring(err)) end
    return false
end

function sendGgReplyToSelected()
    return sendPresetReplyToSelected('gg', getGgReplyText)
end

function sendTechReplyToSelected()
    return sendPresetReplyToSelected('tech', getTechReplyText)
end

function runHelperCmd(cmd)
    local t = getSelectedThread()
    if not t then return end
    local id, err = resolveAnsIdForReply(t)
    if not id then
        if err then say(err) end
        return
    end
    cmd = trim(cmd):gsub('^/', '')
    if cmd == '' then return end
    sendChat(cmd .. ' ' .. id)
end
