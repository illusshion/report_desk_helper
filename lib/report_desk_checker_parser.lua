--[[ Парсер /adms и /admins для checker HUD. ]]
local M = {}

local CHECKER_LVL_SPECIAL_BASE = 100

-- SA-MP nick: буквы, цифры, _, точка, дефис.
local NICK_CLASS = '[%w][%w_%.%-]*'

local BLOB_PATTERNS = {
    { '(' .. NICK_CLASS .. ')%[(%d+)%]%s*%(([Ss]?%d+)%s*lvl%)', true },
    { '(' .. NICK_CLASS .. ')%[(%d+)%]%s*%(([Ss]?%d*)%s*lvl%)', true },
    { '(' .. NICK_CLASS .. ')%s*%(([Ss]?%d+)%s*lvl%)', false },
    { '(' .. NICK_CLASS .. ')%s*%(([Ss]?%d*)%s*lvl%)', false },
}

local CHIEF_LINE_PATTERN = '^(' .. NICK_CLASS .. ')%[(%d+)%]%s*$'

local trimFn
local stripTagsFn

local L_ADMINS_ONLINE = '\xC0\xE4\xEC\xE8\xED\xFB \xEE\xED\xEB\xE0\xE9\xED'
local L_ADMIN_WORD = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0'

-- Публичный API модуля.
function M.configure(deps)
    deps = type(deps) == 'table' and deps or {}
    if deps.trim then trimFn = deps.trim end
    if deps.stripTags then stripTagsFn = deps.stripTags end
    if not trimFn then trimFn = _G.trim end
    if not stripTagsFn then stripTagsFn = _G.stripTags end
    if deps.lAdminsOnline then L_ADMINS_ONLINE = deps.lAdminsOnline end
    if deps.lAdminWord then L_ADMIN_WORD = deps.lAdminWord end
end

local function trim(s)
    if trimFn then return trimFn(s) end
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

local function stripTags(s)
    if stripTagsFn then return stripTagsFn(s) end
    return tostring(s or '')
end

-- Публичный API модуля.
function M.nickPattern()
    return NICK_CLASS
end

-- Публичный API модуля.
function M.parseAdminLevel(lvlStr)
    lvlStr = trim(lvlStr or '')
    if lvlStr == '' then return nil end
    local sn = lvlStr:match('^[Ss](%d+)$')
    if sn then
        sn = math.floor(tonumber(sn) or 0)
        if sn >= 1 and sn <= 9 then
            return CHECKER_LVL_SPECIAL_BASE + sn
        end
        return nil
    end
    if lvlStr:upper() == 'S' then
        return CHECKER_LVL_SPECIAL_BASE + 1
    end
    local n = lvlStr:match('^(%d+)$')
    if n then return math.floor(tonumber(n)) end
    return nil
end

-- Публичный API модуля.
function M.normalizeAdminListLine(plain)
    plain = trim(stripTags(plain or ''))
    if plain == '' then return '' end
    plain = plain:gsub('^%[%d+:%d+:%d+%]%s*', '')
    plain = plain:gsub('^%d+%.%s*', '')
    plain = plain:gsub('^[%*%-%•]%s*', '')
    return trim(plain)
end

-- Публичный API модуля.
function M.isAdminsListNoise(plain, alreadyNormalized)
    if alreadyNormalized then
        plain = trim(plain or '')
    else
        plain = M.normalizeAdminListLine(plain)
    end
    if plain == '' then return true end
    if plain:find(L_ADMINS_ONLINE, 1, true) then return true end
    if plain:find('admins online', 1, true) then return true end
    if plain:find('\xCF\xF0', 1, true) and plain:find('\xF2\xE5\xF5\xED', 1, true) then return true end
    if plain:find('\xC3\xEB%.', 1, true) and plain:find('\xE0\xE4\xEC\xE8\xED', 1, true) then return true end
    if plain:find('\xC7\xE3\xEF', 1, true) and plain:find('\xE0\xE4\xEC\xE8\xED', 1, true) then return true end
    if plain:find(L_ADMIN_WORD, 1, true) and not plain:find('%[', 1, true) and not plain:find('%(', 1, true) then
        return true
    end
    if plain:find('\xF3\xF0\xEE\xE2\xED', 1, true) and not plain:find('%[', 1, true) then return true end
    if plain:find('^voice', 1, true) or plain:find('^afk', 1, true) then return true end
    if plain:find('\xED\xE5\xE2\xE8\xE4\xE8\xEC', 1, true) and not plain:find('%[', 1, true) then return true end
    return false
end

local function stripAdminLineSuffix(plain)
    plain = plain:gsub('%s+%([^)]*%)$', '')
    plain = plain:gsub('%s+[Vv]oice.*$', '')
    plain = plain:gsub('%s+AFK.*$', '')
    plain = plain:gsub('%s+\xED\xE5\xE2\xE8\xE4\xE8\xEC.*$', '')
    return plain
end

local function nickPidLevelPatterns(plain)
    local pat = '^(' .. NICK_CLASS .. ')%[(%d+)%]%s*%(([Ss]?%d+)%s*lvl%)'
    local nick, pid, lvlStr = plain:match(pat)
    if nick then return nick, pid, lvlStr end
    pat = '^(' .. NICK_CLASS .. ')%[(%d+)%]%s*%(([Ss]?%d*)%s*lvl%)'
    nick, pid, lvlStr = plain:match(pat)
    if nick then return nick, pid, lvlStr end
    pat = '^(' .. NICK_CLASS .. ')%s*%(([Ss]?%d+)%s*lvl%)'
    nick, lvlStr = plain:match(pat)
    if nick then return nick, nil, lvlStr end
    pat = '^(' .. NICK_CLASS .. ')%s*%(([Ss]?%d*)%s*lvl%)'
    nick, lvlStr = plain:match(pat)
    if nick then return nick, nil, lvlStr end
    return nil
end

local function adminLevelRank(level)
    level = math.floor(tonumber(level) or 0)
    if level >= 200 then return 3000 + level end
    if level >= CHECKER_LVL_SPECIAL_BASE then return 2000 + level end
    if level >= 1 and level <= 7 then return 1000 + level end
    return 0
end

local function pickBetterAdminLevel(a, b)
    if not a then return b end
    if not b then return a end
    return adminLevelRank(a) >= adminLevelRank(b) and a or b
end

local function parseAdminLineCore(plain)
    if plain == '' then return nil end
    plain = stripAdminLineSuffix(plain)
    local nick, pid, lvlStr = nickPidLevelPatterns(plain)
    if nick then
        local level = M.parseAdminLevel(lvlStr)
        if level then return nick, level, tonumber(pid) end
    end
    local chiefNick, chiefPid = plain:match(CHIEF_LINE_PATTERN)
    if chiefNick and chiefPid then
        return chiefNick, nil, tonumber(chiefPid)
    end
    return nil
end

-- Публичный API модуля: nick, level, id | nil.
function M.parseAdminLine(plain)
    plain = M.normalizeAdminListLine(plain)
    if plain == '' then return nil end
    return parseAdminLineCore(plain)
end

local function parseAdminEntryFromNormalized(line, opts)
    opts = type(opts) == 'table' and opts or {}
    if line == '' then return nil end
    local nick, level, pid = parseAdminLineCore(line)
    if nick and level then
        return { nick = nick, level = level, id = pid }
    end
    if nick and not level and type(opts.resolveChief) == 'function' then
        local chief = opts.resolveChief(nick)
        if chief and chief.level then
            return { nick = nick, level = chief.level, id = pid }
        end
    end
    if type(opts.splitCols) == 'function' then
        local cols = opts.splitCols(line)
        if type(cols) == 'table' and #cols >= 1 then
            local colNick = trim(cols[1] or '')
            nick = colNick:match('^(' .. NICK_CLASS .. ')')
                or colNick:match('(' .. NICK_CLASS .. ')%[%d+%]')
            pid = colNick:match('%[(%d+)%]')
            if nick then
                local bestLevel = nil
                for i = 2, #cols do
                    local cell = trim(cols[i] or '')
                    local lv = M.parseAdminLevel(cell)
                        or M.parseAdminLevel(cell:match('([Ss]?%d+)%s*lvl'))
                        or M.parseAdminLevel(cell:match('([Ss]?%d+)'))
                    if lv then
                        bestLevel = pickBetterAdminLevel(bestLevel, lv)
                    end
                end
                if bestLevel then
                    return { nick = nick, level = bestLevel, id = tonumber(pid) }
                end
                local lvlStr = colNick:match('%(([Ss]?%d*)%s*lvl%)')
                level = M.parseAdminLevel(lvlStr)
                if level then
                    return { nick = nick, level = level, id = tonumber(pid) }
                end
            end
        end
    end
    return nil
end

-- Публичный API модуля: { nick, level, id } | nil.
function M.parseAdminEntry(line, opts)
    line = M.normalizeAdminListLine(line or '')
    return parseAdminEntryFromNormalized(line, opts)
end

-- Публичный API модуля.
function M.scanAdminsBlob(plain, opts)
    opts = type(opts) == 'table' and opts or {}
    local list = {}
    plain = stripTags(plain or ''):gsub('\r', '')
    if plain == '' then return list end
    local seen = {}
    local function add(nick, level, id)
        nick = trim(nick or '')
        level = math.floor(tonumber(level) or 0)
        if nick == '' or level <= 0 then return end
        if type(opts.effectiveLevel) == 'function' then
            level = opts.effectiveLevel(nick, level)
        end
        if type(opts.isValidLevel) == 'function' and not opts.isValidLevel(level) then return end
        local key = nick:lower()
        if key == '' or seen[key] then return end
        seen[key] = true
        list[#list + 1] = { nick = nick, level = level, id = tonumber(id) }
    end
    for _, spec in ipairs(BLOB_PATTERNS) do
        local pat, hasPid = spec[1], spec[2]
        if hasPid then
            for nick, pid, lvlStr in plain:gmatch(pat) do
                add(nick, M.parseAdminLevel(lvlStr), pid)
            end
        else
            for nick, lvlStr in plain:gmatch(pat) do
                add(nick, M.parseAdminLevel(lvlStr), nil)
            end
        end
    end
    if type(opts.resolveChief) == 'function' then
        for line in plain:gmatch('[^\n]+') do
            local nick, pid = trim(line):match(CHIEF_LINE_PATTERN)
            if nick and pid then
                local chief = opts.resolveChief(nick)
                if chief then add(nick, chief.level, pid) end
            end
        end
    end
    return list
end

local function scanAdminsTabBlob(plain, opts)
    opts = type(opts) == 'table' and opts or {}
    local list = {}
    local seen = {}
    local function add(nick, level, id)
        nick = trim(nick or '')
        level = math.floor(tonumber(level) or 0)
        if nick == '' or level <= 0 then return end
        if type(opts.effectiveLevel) == 'function' then
            level = opts.effectiveLevel(nick, level)
        end
        if type(opts.isValidLevel) == 'function' and not opts.isValidLevel(level) then return end
        local key = nick:lower()
        if key == '' or seen[key] then return end
        seen[key] = true
        list[#list + 1] = { nick = nick, level = level, id = tonumber(id) }
    end
    for nick, lvlStr in plain:gmatch('(' .. NICK_CLASS .. ')\t([Ss]%d+)\t') do
        add(nick, M.parseAdminLevel(lvlStr), nil)
    end
    for nick, lvlStr in plain:gmatch('(' .. NICK_CLASS .. ')\t(%d+)\t') do
        add(nick, M.parseAdminLevel(lvlStr), nil)
    end
    for nick, pid, lvlStr in plain:gmatch('(' .. NICK_CLASS .. ')%[(%d+)%]\t([Ss]%d+)\t') do
        add(nick, M.parseAdminLevel(lvlStr), pid)
    end
    return list
end

-- Публичный API модуля.
function M.parseAdminsDialog(text, style, opts)
    opts = type(opts) == 'table' and opts or {}
    local list, seen = {}, {}
    local function addEntry(entry)
        if not entry or not entry.nick or not entry.level then return end
        local nick = trim(entry.nick)
        local level = math.floor(tonumber(entry.level) or 0)
        if nick == '' or level <= 0 then return end
        if type(opts.effectiveLevel) == 'function' then
            level = opts.effectiveLevel(nick, level)
        end
        if type(opts.isValidLevel) == 'function' and not opts.isValidLevel(level) then return end
        local key = nick:lower()
        if key == '' or seen[key] then return end
        seen[key] = true
        list[#list + 1] = {
            nick = nick,
            level = level,
            id = tonumber(entry.id),
        }
    end
    local plain = stripTags(text or ''):gsub('\r', '')
    local lines = {}
    for line in plain:gmatch('[^\n]+') do
        line = trim(line)
        if line ~= '' then lines[#lines + 1] = line end
    end
    local startRow = 1
    if #lines > 1 then
        local firstCols = type(opts.splitCols) == 'function' and opts.splitCols(lines[1]) or {}
        local skipHeader = false
        if type(opts.isAdminsHeaderRow) == 'function' and opts.isAdminsHeaderRow(firstCols) then
            skipHeader = true
        elseif style == 5 and firstCols[1] and firstCols[1]:find('\xCD\xE8\xEA', 1, true) then
            skipHeader = true
        end
        if skipHeader then startRow = 2 end
    end
    for i = startRow, #lines do
        local cols = type(opts.splitCols) == 'function' and opts.splitCols(lines[i]) or {}
        if not (type(opts.isAdminsHeaderRow) == 'function' and opts.isAdminsHeaderRow(cols)) then
            local norm = M.normalizeAdminListLine(lines[i])
            if norm ~= '' then
                addEntry(parseAdminEntryFromNormalized(norm, opts))
            end
        end
    end
    if #list > 0 and #lines > 1 then
        return list
    end
    if #list == 0 and plain:find('\t', 1, true) then
        for _, entry in ipairs(scanAdminsTabBlob(plain, opts)) do
            addEntry(entry)
        end
    end
    if #list == 0 then
        for _, entry in ipairs(M.scanAdminsBlob(plain, opts)) do
            addEntry(entry)
        end
    end
    return list
end


return M
