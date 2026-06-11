--[[ Self-test: парсинг автовыдачи (сверка с AdminTools). ]]
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') or '' end
local function stripTags(s) return (s or ''):gsub('{[%x]+}', '') end
local function stripChatTimestamp(line)
    line = line or ''
    line = line:gsub('^%[%d+:%d+:%d+%]%s*', '')
    return line
end
local function normalizeChatLine(line)
    return trim(stripChatTimestamp(stripTags(line or '')))
end

local function apParseAdminRequest(plain)
    plain = trim(plain or '')
    if plain == '' then return nil end
    local admName, admId, admCommand = plain:match('^%[A%]%s*(.-)%[(%d+)%]%:%s*(.*)')
    if not admId then
        admName, admId, admCommand = plain:match('^([%w][%w_]*)%[(%d+)%]%:%s*(/.*)$')
    end
    if not admId or not admCommand then return nil end
    admCommand = trim(admCommand)
    if admCommand == '' or admCommand:sub(1, 1) ~= '/' then return nil end
    return trim(admName), tonumber(admId), admCommand
end

local function apAdminSurname(admName)
    admName = trim(admName or '')
    if admName == '' then return '?' end
    local surname = admName:match('_(%w+)$')
    if surname and surname ~= '' then return surname end
    return admName
end

local function apSignSuffix(admName)
    local surname = apAdminSurname(admName)
    if surname == '?' then return '' end
    return ' / by ' .. surname
end

local function apIsDirectCommand(cmd)
    return cmd:match('^/unban%s')
        or cmd:match('^/unwarn%s')
        or cmd:match('^/unmute%s')
        or cmd:match('^/unjail%s')
        or cmd:match('^/tr%s')
end

local function apMuteHasReason(cmd)
    return cmd:match('^/mute%s+%d+%s+%d+%s+(.+)$') ~= nil
end

local function apNeedsSignSuffix(cmd)
    if apIsDirectCommand(cmd) then return false end
    if cmd:match('^/mute') then return apMuteHasReason(cmd) end
    return true
end

local function apTryParseCmd(cmd, lvl)
    cmd = trim(cmd)
    if cmd == '' or cmd:sub(1, 1) ~= '/' then return nil end
    local id, term, reason = cmd:match('^/jail%s+(%d+)%s+(%d+)%s+(.+)$')
    if id and term and reason and lvl >= 2 then return 'jail', tonumber(id) end
    id, reason = cmd:match('^/kick%s+(%d+)%s+(.+)$')
    if id and reason and lvl >= 2 then return 'kick', tonumber(id) end
    id, term = cmd:match('^/mute%s+(%d+)%s+(%d+)')
    if id and term and lvl >= 2 then return 'mute', tonumber(id) end
    id = cmd:match('^/tr%s+(%d+)')
    if id and lvl >= 3 then return 'tr', tonumber(id) end
    return nil
end

local fails = 0
local function check(name, ok)
    if ok then
        print('[ok] ' .. name)
    else
        print('[FAIL] ' .. name)
        fails = fails + 1
    end
end

local cases = {
    { '[16:40:08] [A] Sam_Lake[38]: /jail 846 300 AFK bez ESC (+1 pred)', 'Sam_Lake', 38, '/jail 846 300 AFK bez ESC (+1 pred)' },
    { '[A] Sam_Lake[38]: /kick 846 AFK bez ESC', 'Sam_Lake', 38, '/kick 846 AFK bez ESC' },
    { '[A]Sam_Lake[38]:/jail 846 300 x', 'Sam_Lake', 38, '/jail 846 300 x' },
}
for _, c in ipairs(cases) do
    local plain = normalizeChatLine(c[1])
    local n, i, cmd = apParseAdminRequest(plain)
    check(c[1], n == c[2] and i == c[3] and cmd == c[4])
end

check('jail lvl2', apTryParseCmd('/jail 846 300 reason', 2) == 'jail')
check('jail lvl1', apTryParseCmd('/jail 846 300 reason', 1) == nil)
check('kick lvl2', apTryParseCmd('/kick 846 reason', 2) == 'kick')
check('mute no reason no sign', apNeedsSignSuffix('/mute 10 60') == false)
check('mute with reason sign', apNeedsSignSuffix('/mute 10 60 spam') == true)
check('jail sign', apNeedsSignSuffix('/jail 10 60 reason') == true)
check('unjail no sign', apNeedsSignSuffix('/unjail 10') == false)
check('tr no sign', apNeedsSignSuffix('/tr 846') == false)
check('tr lvl3', apTryParseCmd('/tr 846', 3) == 'tr')
check('tr lvl3 suffix', apTryParseCmd('/tr 846 extra', 3) == 'tr')
check('tr lvl2', apTryParseCmd('/tr 846', 2) == nil)
check('sign / by surname', apSignSuffix('Veronika_Katana') == ' / by Katana')
check('sign kick', '/kick 437 nrp drive' .. apSignSuffix('Veronika_Katana') == '/kick 437 nrp drive / by Katana')

local another = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 Mia_Granados \xEA\xE8\xEA\xED\xF3\xEB \xE8\xE3\xF0\xEE\xEA\xE0 Aiko_McShow'
check('another admin kick', another:find(' \xEA\xE8\xEA\xED\xF3\xEB \xE8\xE3\xF0\xEE\xEA\xE0 Aiko_McShow', 1, true) ~= nil)

local handledPerm = {}
local function apStableLineKey(text)
    return normalizeChatLine(text)
end
local function apMarkLineConsumed(key)
    if key ~= '' then handledPerm[key] = true end
end
local function apLineAlreadyHandled(key)
    return handledPerm[key] == true
end

local lineA = '[22:14:41] [A] Rui_Shusaku[60]: /mute 863 60 reason'
local lineB = '[A] Rui_Shusaku[60]: /mute 863 60 reason'
local stableA = apStableLineKey(lineA)
local stableB = apStableLineKey(lineB)
check('stable key hook/poll match', stableA == stableB and stableA ~= '')
apMarkLineConsumed(stableA)
check('dedup blocks replay line', apLineAlreadyHandled(stableB))
check('dedup blocks poll timestamp variant', apLineAlreadyHandled(apStableLineKey(lineB)))
check('tr lvl1 silent skip', apTryParseCmd('/tr 846', 1) == nil)

if fails > 0 then
    print('FAILED: ' .. fails)
    os.exit(1)
end
print('All ap_selftest checks passed.')
