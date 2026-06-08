--[[ Модуль: парс репортов [PC]/[S]/[M] и chat events. ]]
local M = {}

local MAX_PLAYER_ID = 1000
local trim, stripTags, stripChatTimestamp, isExcludedChatLine, isValidPlayerNick
local ingestPc, ingestS, ingestM = true, true, true
local REPORT_CHANNEL_ORDER = { 'PC', 'S', 'M' }
local ingestAdminBracket = false

local ADMIN_ACTION_MARKERS = {
    '\xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2\xE8\xF0',
    '\xEF\xF0\xEE\xF1\xEC\xE0\xF2\xF0\xE8\xE2\xE0\xE5\xF2',
    '\xEF\xF0\xEE\xF1\xEC\xEE\xF2\xF0\xE5\xF2',
    '\xEF\xEE\xE4\xEA\xE8\xED\xF3\xEB',
    '\xEF\xEE\xE4\xEA\xE8\xED\xF3\xEB\xE0',
    '\xEF\xED\xF3\xEB',
    '\xEA\xE8\xEA\xED\xF3\xEB',
    '\xEA\xE8\xEA\xED\xF3\xEB\xE0',
    '\xE7\xE0\xEC\xF3\xF2\xE8\xEB',
    '\xE7\xE0\xE3\xEB\xF3\xF8\xE8\xEB',
    '\xEF\xEE\xF1\xE0\xE4\xE8\xEB',
    '\xEF\xEE\xF1\xE0\xE4\xE8\xEB\xE0',
    '\xED\xE0\xE7\xED\xE0\xF7\xE8\xEB',
    '\xE2\xFB\xE4\xE0\xEB',
    '\xE2\xFB\xED\xE5\xF1',
    '\xEF\xF0\xEE\xF1\xEC\xEE\xF2\xF0',
    '\xEF\xF0\xEE\xF1\xEC\xEE\xF2\xF0\xE5\xEB',
    '\xE4\xE0\xED\xED\xFB\xE5 \xE8\xE3\xF0\xEE\xEA\xE0',
    '\xEF\xEE\xEA\xE0\xE7\xE0\xEB',
    '\xEF\xEE\xEA\xE0\xE7\xE0\xEB\xE0',
    '\xF1\xEB\xE5\xE4\xE8\xF2',
    '\xF1\xEB\xE5\xE4\xE8\xF2\xE5',
    '\xEF\xEE\xE4\xEA\xE8\xED\xF3\xEB \xF2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2',
    '\xEF\xEE\xE4\xEA\xE8\xED\xF3\xEB \xF2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2',
    '\xED\xE5\xE2\xE8\xE4\xE8\xEC',
    '\xED\xE5\xE2\xE8\xE4\xE8\xEC\xEA',
    '\xE2\xFB\xF8\xE5\xEB',
    '\xE7\xE0\xF2\xFB\xF7',
    '\xE7\xE0\xF2\xFB\xF7\xEA',
    'jail', 'warn', 'mute', 'ban', 'kick', 'slap',
}

local ACTION_CLASS_RULES = {
    { marker = '\xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2\xE8\xF0', title = '\xD2\xE5\xEB\xE5\xEF\xEE\xF0\xF2', kind = 'tp' },
    { marker = '\xEF\xED\xF3\xEB', title = '\xCF\xED\xF3\xEB', kind = 'kick' },
    { marker = '\xEA\xE8\xEA\xED\xF3\xEB', title = '\xCF\xED\xF3\xEB', kind = 'kick' },
    { marker = '\xEF\xEE\xE4\xEA\xE8\xED\xF3\xEB \xF2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2', title = '\xD2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2', kind = 'veh' },
    { marker = '\xEF\xEE\xE4\xEA\xE8\xED\xF3\xEB', title = '\xD2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2', kind = 'veh' },
    { marker = '\xEF\xF0\xEE\xF1\xEC\xE0\xF2\xF0\xE8\xE2\xE0\xE5\xF2', title = '\xCF\xF0\xEE\xF1\xEC\xEE\xF2\xF0', kind = 'spec' },
    { marker = '\xEF\xF0\xEE\xF1\xEC\xEE\xF2\xF0', title = '\xCF\xF0\xEE\xF1\xEC\xEE\xF2\xF0', kind = 'spec' },
    { marker = '\xEF\xF0\xEE\xF1\xEC\xEE\xF2\xF0\xE5\xF2', title = '\xCF\xF0\xEE\xF1\xEC\xEE\xF2\xF0', kind = 'spec' },
    { marker = '\xEF\xF0\xEE\xF1\xEC\xEE\xF2\xF0\xE5\xEB', title = '\xCF\xF0\xEE\xF1\xEC\xEE\xF2\xF0', kind = 'spec' },
    { marker = '\xF1\xEB\xE5\xE4\xE8\xF2', title = '\xD1\xEB\xE5\xE4\xE8\xF2', kind = 'spec' },
    { marker = '\xE4\xE0\xED\xED\xFB\xE5 \xE8\xE3\xF0\xEE\xEA\xE0', title = '\xC4\xE0\xED\xED\xFB\xE5', kind = 'info' },
    { marker = '\xEF\xEE\xEA\xE0\xE7\xE0\xEB', title = '\xCF\xEE\xEA\xE0\xE7\xE0\xEB', kind = 'info' },
    { marker = '\xED\xE5\xE2\xE8\xE4\xE8\xEC', title = '\xCD\xE5\xE2\xE8\xE4\xE8\xEC\xEA\xE0', kind = 'mode' },
    { marker = '\xE2\xFB\xF8\xE5\xEB', title = '\xCD\xE5\xE2\xE8\xE4\xE8\xEC\xEA\xE0', kind = 'mode' },
    { marker = '\xEF\xEE\xF1\xE0\xE4\xE8\xEB', title = '\xCF\xEE\xF1\xE0\xE4\xEA\xE0', kind = 'veh' },
    { marker = '\xED\xE0\xE7\xED\xE0\xF7\xE8\xEB', title = '\xCD\xE0\xE7\xED\xE0\xF7\xE8\xEB', kind = 'other' },
    { marker = '\xE7\xE0\xEC\xF3\xF2\xE8\xEB', title = '\xC7\xE0\xEC\xF3\xF2\xE8\xEB', kind = 'mute' },
    { marker = '\xE7\xE0\xE3\xEB\xF3\xF8\xE8\xEB', title = '\xC7\xE0\xE3\xEB\xF3\xF8\xE8\xEB', kind = 'mute' },
    { marker = 'jail', title = 'Jail', kind = 'jail' },
    { marker = 'ban', title = 'Ban', kind = 'ban' },
    { marker = 'mute', title = 'Mute', kind = 'mute' },
    { marker = 'warn', title = 'Warn', kind = 'warn' },
    { marker = 'slap', title = 'Slap', kind = 'slap' },
    { marker = 'kick', title = 'Kick', kind = 'kick' },
}

-- Публичный API модуля.
function M.configure(deps)
    MAX_PLAYER_ID = deps.maxPlayerId or 1000
    trim = deps.trim
    stripTags = deps.stripTags
    stripChatTimestamp = deps.stripChatTimestamp
    isExcludedChatLine = deps.isExcludedChatLine
    isValidPlayerNick = deps.isValidPlayerNick
    if deps.ingest_pc ~= nil then ingestPc = deps.ingest_pc end
    if deps.ingest_s ~= nil then ingestS = deps.ingest_s end
    if deps.ingest_m ~= nil then ingestM = deps.ingest_m end
    if deps.ingest_admin_bracket ~= nil then ingestAdminBracket = deps.ingest_admin_bracket end
end

-- Finalize Nick Id
local function finalizeNickId(nick, id)
    nick = trim(nick or '')
    id = tonumber(id)
    if not nick or not id or id < 0 or id > MAX_PLAYER_ID then return nil end
    if nick:find('%[', 1, true) or nick:find('%]', 1, true) then return nil end
    if not isValidPlayerNick(nick) then return nil end
    return nick, id
end

-- Finalize Nick Id Body
local function finalizeNickIdBody(nick, id, body)
    body = trim(body or '')
    if body == '' then return nil end
    if M.looksLikePlayerStatusBody(body) then return nil end
    nick, id = finalizeNickId(nick, id)
    if not nick then return nil end
    return nick, id, body
end

-- Нормализация текста статуса (UTF-8 bubble / CP1251 чат → CP1251).
local function normalizeStatusText(text)
    text = trim(stripTags(text or ''))
    if text == '' then return '' end
    if isUtf8Text and isUtf8Text(text) then
        text = utf8ToCp1251(text) or text
    end
    return text
end

-- Публичный API модуля.
function M.looksLikePlayerStatusBody(body)
    body = normalizeStatusText(body)
    if body == '' then return true end
    if body:find('\xCD\xE0 \xEF\xE0\xF3\xE7\xE5', 1, true) then return true end
    local low = body:lower()
    if body:find('\xED\xE0 \xEF\xE0\xF3\xE7\xE5', 1, true) then return true end
    if body:match('^%([^)]*lvl') then return true end
    if body:match('^%d+%s*lvl') then return true end
    if body:match('^Voice') then return true end
    if body:match('^%<%s*%(') then return true end
    if body:find('\xED\xE0 \xEF\xE0\xF3\xE7\xE5', 1, true) then return true end
    if body:find('\xEF\xE0\xF3\xE7', 1, true) then return true end
    if body:find('pause', 1, true) then return true end
    if body:find('paused', 1, true) then return true end
    if body:find('AFK', 1, true) then return true end
    if body:find('\xF1\xED\xFF', 1, true) and body:find('\xEF\xE0\xF3\xE7', 1, true) then return true end
    if body:find('\xF1\xED\xFF', 1, true) and body:find('AFK', 1, true) then return true end
    if body:find('\xE8\xE3\xF0\xEE\xEA', 1, true) and body:find('\xEF\xE0\xF3\xE7', 1, true) then return true end
    if body:find('\xE2 \xEE\xED\xEB\xE0\xE9\xED', 1, true) then return true end
    if body:find('\xE2\xFB\xF8\xE5\xEB', 1, true) and #body < 48 then return true end
    if body:find('\xE7\xE0\xF8\xE5\xEB', 1, true) and #body < 48 then return true end
    if body:match('^%d+%s*[%xsec%:%.]') and body:find('\xEF\xE0\xF3\xE7', 1, true) then return true end
    return false
end

-- Строка чата целиком — статус / AFK / пауза (до парсинга nick[id]).
function M.looksLikePlayerStatusLine(plain)
    plain = normalizeStatusText(plain)
    if plain == '' then return true end
    if M.looksLikePlayerStatusBody(plain) then return true end
    local body = plain:match('^[%w][%w_]+%[%d+%]%s*:?%s*(.+)$')
    if body and M.looksLikePlayerStatusBody(body) then return true end
    body = plain:match('^%[%w+%]%s*[%w][%w_]+%[%d+%]%s*:?%s*(.+)$')
    if body and M.looksLikePlayerStatusBody(body) then return true end
    body = plain:match('^%-%s*(.+)%s+%([%w][%w_]*%)%[%d+%]%s*$')
    if body and M.looksLikePlayerStatusBody(body) then return true end
    body = plain:match('^%*%s*(.+)%s+%([%w][%w_]*%)%[%d+%]%s*$')
    if body and M.looksLikePlayerStatusBody(body) then return true end
    return false
end

-- Публичный API модуля.
function M.looksLikeAdminActionText(text)
    text = trim(text or ''):lower()
    if text == '' then return false end
    for _, m in ipairs(ADMIN_ACTION_MARKERS) do
        if text:find(m, 1, true) then return true end
    end
    if text:find('^%s*[%/%!]', 1) then return false end
    if text:find('^%s*%d+%s*lvl', 1) then return false end
    return false
end

-- Публичный API модуля.
function M.classifyAdminAction(body)
    body = trim(body or '')
    local low = body:lower()
    if low == '' then
        return { kind = 'other', title = '\xC4\xE5\xE9\xF1\xF2\xE2\xE8\xE5', detail = '' }
    end
    for _, rule in ipairs(ACTION_CLASS_RULES) do
        if low:find(rule.marker, 1, true) then
            return { kind = rule.kind, title = rule.title, detail = body }
        end
    end
    return { kind = 'other', title = '\xC7\xE0\xEF\xE8\xF1\xFC', detail = body }
end

-- Публичный API модуля.
function M.formatActionDisplay(adminNick, targetNick, targetId, body, classified)
    body = trim(body or '')
    adminNick = trim(adminNick or '')
    if body == '' then return adminNick end
    if adminNick ~= '' and not body:lower():find(adminNick:lower(), 1, true) then
        return adminNick .. ' ' .. body
    end
    return body
end

-- Extract Target From Action
local function extractTargetFromAction(text)
    text = trim(text or '')
    if text == '' then return nil end

    local nick, id = text:match('\xE8\xE3\xF0\xEE\xEA[ауе]?%s+([%w][%w_]*)%[(%d+)%]')
    if nick then return finalizeNickId(nick, id) end

    nick, id = text:match('([%w][%w_]*)%[(%d+)%]%s*$')
    if nick then return finalizeNickId(nick, id) end

    nick = text:match('\xE8\xE3\xF0\xEE\xEA[ауе]?%s+([%w][%w_]*)%s*$')
    if nick and isValidPlayerNick(trim(nick)) then return trim(nick), nil end

    nick = text:match('\xE4\xE0\xED\xED\xFB\xE5 \xE8\xE3\xF0\xEE\xEA\xE0%s+([%w][%w_]*)')
    if nick and isValidPlayerNick(trim(nick)) then return trim(nick), nil end

    return nil
end

-- Build Admin Action Ev
local function buildAdminActionEv(adminNick, adminId, body)
    body = trim(body or '')
    local targetNick, targetId = extractTargetFromAction(body)
    local classified = M.classifyAdminAction(body)
    if not targetNick and not targetId then
        classified.title = '\xC7\xE0\xEF\xE8\xF1\xFC \xE0\xE4\xEC\xE8\xED\xE0'
        classified.kind = 'note'
    end
    return {
        type = 'admin_action',
        adminNick = adminNick,
        adminId = adminId,
        targetNick = targetNick,
        targetId = targetId,
        text = body,
        actionTitle = classified.title,
        actionKind = classified.kind,
        actionDetail = classified.detail,
        displayText = M.formatActionDisplay(adminNick, targetNick, targetId, body, classified),
    }
end

-- Парсинг данных с сервера/чата.
local function parseChannelReport(text, channelTag)
    if not text or text == '' then return nil end
    local nick, id, body = text:match('^%[' .. channelTag .. '%]%s+([%w][%w_]*)%[(%d+)%]%s*:%s*(.+)$')
    if not nick then
        nick, id, body = text:match('^%[' .. channelTag .. '%]%s+([%w][%w_]*)%[(%d+)%]%s+:%s*(.+)$')
    end
    if not nick then return nil end
    body = trim(body)
    nick, id, body = finalizeNickIdBody(nick, id, body)
    if not nick then return nil end
    return nick, id, body, channelTag
end

-- Channel Ingest Enabled
local function channelIngestEnabled(tag)
    if tag == 'PC' then return ingestPc end
    if tag == 'S' then return ingestS end
    if tag == 'M' then return ingestM end
    return false
end

-- Line Starts Report Channel
local function lineStartsReportChannel(text)
    if not text or text == '' then return false end
    for _, tag in ipairs(REPORT_CHANNEL_ORDER) do
        if text:find('^%[' .. tag .. '%]', 1) then return true end
    end
    return false
end

-- Парсинг данных с сервера/чата.
local function parseAdvanceReportLine(text)
    for _, tag in ipairs(REPORT_CHANNEL_ORDER) do
        if channelIngestEnabled(tag) then
            local nick, id, body, ch = parseChannelReport(text, tag)
            if nick then return nick, id, body, ch end
        end
    end
    return nil
end

-- Парсинг данных с сервера/чата.
local function parsePlayerReportStrict(text)
    if not text or text == '' then return nil end
    if text:find('^%[A%]', 1) or text:find('%[A%]%s', 1) then return nil end
    if lineStartsReportChannel(text) then return nil end

    local nick, id, body = text:match('^([%w][%w_]*)%[(%d+)%]%s*:?%s*(.+)$')
    if not nick then
        nick, id, body = text:match('^([%w][%w_]*)%[(%d+)%]%s+:%s*(.+)$')
    end
    if not nick then return nil end

    body = trim(body)
    if M.looksLikeAdminActionText(body) then return nil end
    return finalizeNickIdBody(nick, id, body)
end

-- Парсинг данных с сервера/чата.
local function parseAdminBracketLine(text)
    if not text or text == '' then return nil end

    local adminNick, adminId, body = text:match('^%[A%]%s+([%w][%w_]*)%[(%d+)%]%s*:%s*(.+)$')
    if adminNick then
        adminNick, adminId = finalizeNickId(adminNick, adminId)
        if not adminNick then return nil end
        body = trim(body)
        if body == '' then return nil end
        if not M.looksLikeAdminActionText(body) then
            return buildAdminActionEv(adminNick, adminId, body)
        end
        return buildAdminActionEv(adminNick, adminId, body)
    end

    adminNick, adminId, body = text:match('^%[A%]%s+([%w][%w_]*)%[(%d+)%]%s+(.+)$')
    if not adminNick then return nil end
    adminNick, adminId = finalizeNickId(adminNick, adminId)
    if not adminNick then return nil end
    body = trim(body)
    if body == '' then return nil end
    if not M.looksLikeAdminActionText(body) then
        return buildAdminActionEv(adminNick, adminId, body)
    end
    return buildAdminActionEv(adminNick, adminId, body)
end

-- Публичный API модуля.
function M.formatPunishmentDisplay(adminNick, targetNick, rawText)
    rawText = trim(rawText or '')
    adminNick = trim(adminNick or '')
    targetNick = trim(targetNick or '')
    if rawText == '' then return '' end

    local reason = trim(rawText:match('\xCF\xF0\xE8\xF7\xE8\xED[%w\xC0-\xFF]*%s*:%s*(.+)') or '')
    local body = rawText:gsub('^%s*\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0%s+[%w][%w_%-]*%s*', '')
    body = trim(body)
    if reason ~= '' then
        body = trim(body:gsub('\xCF\xF0\xE8\xF7\xE8\xED[%w\xC0-\xFF]*%s*:%s*.+$', ''))
    end
    if body == '' then body = rawText end

    local lines = {}
    if adminNick ~= '' then
        lines[#lines + 1] = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 ' .. adminNick
    end
    lines[#lines + 1] = body
    if reason ~= '' then
        lines[#lines + 1] = '\xCF\xF0\xE8\xF7\xE8\xED\xE0: ' .. reason
    end
    local out = table.concat(lines, '\n')
    if #out > 280 then out = out:sub(1, 277) .. '...' end
    return out
end

-- Парсинг данных с сервера/чата.
local function parsePunishmentLine(text)
    if not text or text == '' then return nil end
    if text:find('^%[A%]', 1) then return nil end
    if lineStartsReportChannel(text) then return nil end

    if not text:find('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0', 1, true) then return nil end
    if text:find('\xE4\xEB\xFF', 1, true) then return nil end

    local adminNick = text:match('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0%s+([%w][%w_]*)')
    if not adminNick then return nil end
    adminNick = trim(adminNick):gsub('%[.*$', '')
    if not isValidPlayerNick(adminNick) then return nil end

    if not text:find('\xE2\xFB\xE4\xE0\xEB', 1, true)
        and not text:find('\xED\xE0\xEA\xE0\xE7\xE0\xEB', 1, true)
        and not text:find('\xED\xE0\xEA\xE0\xE7\xE0\xED', 1, true)
        and not text:find('\xE7\xE0\xF2\xFB\xF7', 1, true)
        and not text:find('\xEF\xEE\xF1\xF2\xE0\xE2\xE8\xEB', 1, true)
        and not text:find('warn', 1, true)
        and not text:find('ban', 1, true)
        and not text:find('jail', 1, true)
        and not text:find('mute', 1, true) then
        return nil
    end

    local targetNick = text:match('\xE8\xE3\xF0\xEE\xEA[ауе]?%s+([%w][%w_%.]+)')
    if not targetNick then
        targetNick = text:match('\xE8\xE3\xF0\xEE\xEA[ауе]?%s+([%w][%w_]*)')
    end
    targetNick = trim(targetNick or ''):gsub('%.$', ''):gsub('%[.*$', '')
    if targetNick == '' or not isValidPlayerNick(targetNick) then return nil end

    local reason = trim(text:match('\xCF\xF0\xE8\xF7\xE8\xED[%w\xC0-\xFF]*%s*:%s*(.+)') or '')
    if #reason > 220 then reason = reason:sub(1, 217) .. '...' end
    local displayText = M.formatPunishmentDisplay(adminNick, targetNick, text)

    return {
        type = 'punishment',
        adminNick = adminNick,
        targetNick = targetNick,
        targetId = nil,
        text = reason ~= '' and reason or displayText,
        rawText = text,
        punishReason = reason,
        displayText = displayText,
    }
end

-- Публичный API модуля.
function M.tryParsePlayerReport(text)
    if not text or text == '' then return nil end
    text = stripChatTimestamp(stripTags(text))
    if isExcludedChatLine(text) then return nil end
    local nick, id, body, ch = parseAdvanceReportLine(text)
    if nick then return nick, id, body, ch end
    return parsePlayerReportStrict(text)
end

-- Публичный API модуля.
function M.tryParseChatEvent(text, opts)
    opts = opts or {}
    if not text or text == '' then return nil end
    text = stripChatTimestamp(stripTags(text))

    if ingestAdminBracket then
        local ev = parseAdminBracketLine(text)
        if ev then return ev end
    end

    local ev = parsePunishmentLine(text)
    if ev then return ev end

    if opts.reportsOnly == false then
        return nil
    end

    if isExcludedChatLine(text) then return nil end

    local nick, id, body, channel = parseAdvanceReportLine(text)
    if nick then
        return {
            type = 'player_report',
            nick = nick,
            id = id,
            text = body,
            channel = channel,
        }
    end

    if not opts.chatStrictReports then
        nick, id, body = parsePlayerReportStrict(text)
        if nick then
            return {
                type = 'player_report',
                nick = nick,
                id = id,
                text = body,
                channel = nil,
            }
        end
    end
    return nil
end

-- Публичный API модуля.
function M.tryParseReport(text)
    local ev = M.tryParseChatEvent(text)
    if ev and ev.type == 'player_report' then
        return ev.nick, ev.id, ev.text
    end
    return nil
end

-- Публичный API модуля.
function M.isPlayerChannelMessage(rawOrText)
    local t = rawOrText or ''
    for _, tag in ipairs(REPORT_CHANNEL_ORDER) do
        if t:find('%[' .. tag .. '%]', 1, true) then return true end
    end
    return false
end

-- Normalize Report Channel
function M.normalizeReportChannel(tag)
    tag = trim(tostring(tag or '')):upper()
    if tag == 'PC' or tag == 'S' or tag == 'M' then return tag end
    return nil
end

-- Extract Report Channel
function M.extractReportChannel(rawOrTag)
    local ch = M.normalizeReportChannel(rawOrTag)
    if ch then return ch end
    local t = tostring(rawOrTag or '')
    if t == '' then return nil end
    for _, tag in ipairs(REPORT_CHANNEL_ORDER) do
        if t:find('%[' .. tag .. '%]', 1, true) then return tag end
    end
    return nil
end

-- Публичный API модуля.
function M.ingestDedupKey(id, body, rawLine, normalizeBody)
    local raw = rawLine or ''
    local ts = raw:match('(%[%d+:%d+:%d+%])')
        or raw:match('(%[%d%d%.%d%d%.%d%d%d%d%s+%d+:%d+:%d+%])')
    local norm = normalizeBody(body)
    if ts then
        return tostring(id) .. '|' .. norm .. '|' .. ts
    end
    if raw ~= '' and #raw > 8 then
        local h = 0
        for i = 1, math.min(#raw, 96) do
            h = (h * 31 + raw:byte(i)) % 2147483647
        end
        return tostring(id) .. '|' .. norm .. '|h' .. tostring(h)
    end
    return tostring(id) .. '|' .. norm
end

return M
