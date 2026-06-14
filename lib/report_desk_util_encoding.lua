--[[ Encoding helpers (split from report_desk_util.lua). ]]
function cp1251ToUtf8(text)
    if not text or text == '' then return '' end
    if text:find('\239\191\189', 1, true) then return text end
    if isUtf8Text(text) then return text end
    local ok, r = pcall(function() return u8(text) end)
    if ok and r and r ~= '' and not r:find('\239\191\189', 1, true) then
        return r
    end
    return text
end

function isUtf8Text(s)
    return type(s) == 'string' and s:find('[\208-\209][\128-\191]') ~= nil
end

function utf8ToCp1251(text)
    if not text or text == '' then return '' end
    if not isUtf8Text(text) then return text end
    if type(u8) ~= 'table' or type(u8.decode) ~= 'function' then return text end
    local ok, r = pcall(function() return u8:decode(text) end)
    if ok and type(r) == 'string' then return r end
    return text
end

-- Текст для SAMP wire (/ans, чат): всегда CP1251.
function ensureWireCp1251(text)
    text = trim(tostring(text or ''))
    if text == '' then return '' end
    return normalizeStoredText(text, isUtf8Text(text))
end

-- Безопасный вызов предыдущего хука в цепочке SAMP (изоляция ошибок чужих скриптов).