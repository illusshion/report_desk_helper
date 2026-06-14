--[[ Временное лидерство (/templeader) и работы (/tempwork) для админов. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local TL_ROW_H = 40
local TL_ACCENT_W = 3

-- Clist-цвета фракций (те же, что CHECKER_ORG_CLIST_COLOR в report_desk_checker.lua).
local TL_ORG_GOV = 1
local TL_ORG_MVD = 2
local TL_ORG_MO = 3
local TL_ORG_MZ = 4
local TL_ORG_SMI = 5
local TL_ORG_GROVE = 6
local TL_ORG_BALLAS = 7
local TL_ORG_VAGOS = 8
local TL_ORG_AZTECAS = 9
local TL_ORG_RIFA = 10
local TL_ORG_LCN = 11
local TL_ORG_YAKUZA = 12
local TL_ORG_RMAF = 13

local TL_ORG_CLIST = {
    [TL_ORG_GOV] = 0xFFCCFF00,
    [TL_ORG_MVD] = 0xFF0000FF,
    [TL_ORG_MO] = 0xFF996633,
    [TL_ORG_MZ] = 0xFFFF6666,
    [TL_ORG_SMI] = 0xFFFF6600,
    [TL_ORG_GROVE] = 0xFF009900,
    [TL_ORG_BALLAS] = 0xFF800080,
    [TL_ORG_VAGOS] = 0xFFFFCD00,
    [TL_ORG_AZTECAS] = 0xFF00CCFF,
    [TL_ORG_RIFA] = 0xFF6666FF,
    [TL_ORG_LCN] = 0xFF993366,
    [TL_ORG_YAKUZA] = 0xFFBB0000,
    [TL_ORG_RMAF] = 0xFF007575,
    [0] = 0xFFAAAAAA,
}

local function tlSampColorToImVec4(color)
    if type(sampColorToImVec4) == 'function' then
        return sampColorToImVec4(color)
    end
    return nil
end

local function tlOrgClistColor(orgId)
    orgId = tonumber(orgId) or 0
    if type(checkerLeaderOrgClistColor) == 'function' then
        return checkerLeaderOrgClistColor(orgId)
    end
    return TL_ORG_CLIST[orgId] or TL_ORG_CLIST[0]
end

local function tlOrgTint(orgId)
    return tlSampColorToImVec4(tlOrgClistColor(orgId)) or col_accent
end

local function tlColorU32(tint, alpha)
    if not tint then return nil end
    alpha = tonumber(alpha) or 0.9
    local col = imgui.ImVec4(tint.x, tint.y, tint.z, alpha)
    if type(toU32) == 'function' then return toU32(col) end
    local r = math.floor(col.x * 255 + 0.5)
    local g = math.floor(col.y * 255 + 0.5)
    local b = math.floor(col.z * 255 + 0.5)
    local a = math.floor(col.w * 255 + 0.5)
    if bit and bit.bor and bit.lshift then
        return bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r)
    end
    return a * 16777216 + b * 65536 + g * 256 + r
end

local function tlDrawButtonAccent(tint, hovered, active)
    if not tint or not imgui.GetWindowDrawList then return end
    local dl = imgui.GetWindowDrawList()
    local min = imgui.GetItemRectMin()
    local max = imgui.GetItemRectMax()
    local pad = 7
    local alpha = active and 0.95 or (hovered and 0.82 or 0.58)
    dl:AddRectFilled(
        imgui.ImVec2(min.x + 3, min.y + pad),
        imgui.ImVec2(min.x + 3 + TL_ACCENT_W, max.y - pad),
        tlColorU32(tint, alpha),
        2
    )
end

local function tlDrawOrgDot(tint)
    if not tint then return end
    local size = 7
    local p = imgui.GetCursorScreenPos()
    local lh = imgui.GetTextLineHeight and imgui.GetTextLineHeight() or 14
    local dl = imgui.GetWindowDrawList()
    if dl and dl.AddCircleFilled then
        dl:AddCircleFilled(
            imgui.ImVec2(p.x + size * 0.5, p.y + lh * 0.5),
            size * 0.45,
            tlColorU32(tint, 0.88))
    end
    imgui.Dummy(imgui.ImVec2(size + 2, lh))
end

local function tlOrgIdFromArgs(args)
    return tonumber(tostring(args or ''):match('^(%d+)'))
end

local TL_RESTORE_MSG_BANK = '    \xC1\xC0\xCD\xCA\xCE\xC2\xD1\xCA\xC8\xC9 \xD7\xC5\xCA'
local TL_RESTORE_MSG_LOGIN = '\xC2\xFB \xE2\xEE\xF8\xEB\xE8 \xEA\xE0\xEA \xE0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 \xF7\xE5\xF2\xE2\xB8\xF0\xF2\xEE\xE3\xEE \xF3\xF0\xEE\xE2\xED\xFF'

local TL_ORGS = {
    {
        key = 'gov',
        short = '\xCF\xF0\xE0\xE2-\xE2\xEE',
        label = '\xCF\xF0\xE0\xE2\xE8\xF2\xE5\xEB\xFC\xF1\xF2\xE2\xEE',
        orgId = TL_ORG_GOV,
        kind = 'leader',
        items = {
            { label = '\xCF\xF0\xE5\xE7\xE8\xE4\xE5\xED\xF2', args = '1 1' },
            { label = '\xCC\xFD\xF0 \xE3. \xCB\xEE\xF1-\xD1\xE0\xED\xF2\xEE\xF1', args = '1 2' },
            { label = '\xCC\xFD\xF0 \xE3. \xD1\xE0\xED-\xD4\xE8\xE5\xF0\xF0\xEE', args = '1 3' },
            { label = '\xCC\xFD\xF0 \xE3. \xCB\xE0\xF1-\xC2\xE5\xED\xF2\xF3\xF0\xE0\xF1', args = '1 4' },
        },
    },
    {
        key = 'mvd',
        short = '\xCC\xC2\xC4',
        label = '\xCC\xE8\xED\xE8\xF1\xF2\xE5\xF0\xF1\xF2\xE2\xEE \xC2\xED\xF3\xF2\xF0\xE5\xED\xED\xE8\xF5 \xC4\xE5\xEB',
        orgId = TL_ORG_MVD,
        kind = 'leader',
        items = {
            { label = '\xCC\xE8\xED\xE8\xF1\xF2\xF0 \xC2\xED\xF3\xF2\xF0\xE5\xED\xED\xE8\xF5 \xC4\xE5\xEB', args = '2 0' },
            { label = '\xC3\xE5\xED\xE5\xF0\xE0\xEB \xEF\xEE\xEB\xE8\xF6\xE8\xE8 \xE3. \xCB\xEE\xF1-\xD1\xE0\xED\xF2\xEE\xF1', args = '2 1' },
            { label = '\xC3\xE5\xED\xE5\xF0\xE0\xEB \xEF\xEE\xEB\xE8\xF6\xE8\xE8 \xE3. \xD1\xE0\xED-\xD4\xE8\xE5\xF0\xF0\xEE', args = '2 2' },
            { label = '\xC3\xE5\xED\xE5\xF0\xE0\xEB \xEF\xEE\xEB\xE8\xF6\xE8\xE8 \xE3. \xCB\xE0\xF1-\xC2\xE5\xED\xF2\xF3\xF0\xE0\xF1', args = '2 3' },
            { label = '\xC4\xE8\xF0\xE5\xEA\xF2\xEE\xF0 \xD4\xC1\xD0', args = '2 4' },
        },
    },
    {
        key = 'mo',
        short = '\xCC\xCE',
        label = '\xCC\xE8\xED\xE8\xF1\xF2\xE5\xF0\xF1\xF2\xE2\xEE \xCE\xE1\xEE\xF0\xEE\xED\xFB',
        orgId = TL_ORG_MO,
        kind = 'leader',
        items = {
            { label = '\xCC\xE8\xED\xE8\xF1\xF2\xF0 \xCE\xE1\xEE\xF0\xEE\xED\xFB', args = '3 0' },
            { label = '\xC3\xE5\xED\xE5\xF0\xE0\xEB \xD1\xF3\xF5\xEE\xEF\xF3\xF2\xED\xFB\xF5 \xC2\xEE\xE9\xF1\xEA', args = '3 1' },
            { label = '\xC3\xE5\xED\xE5\xF0\xE0\xEB \xC2\xEE\xE5\xED\xED\xEE-\xC2\xEE\xE7\xE4\xF3\xF8\xED\xFB\xF5 \xD1\xE8\xEB', args = '3 2' },
            { label = '\xC0\xE4\xEC\xE8\xF0\xE0\xEB \xC2\xEE\xE5\xED\xED\xEE-\xCC\xEE\xF0\xF1\xEA\xEE\xE3\xEE \xD4\xEB\xEE\xF2\xE0', args = '3 3' },
        },
    },
    {
        key = 'mz',
        short = '\xCC\xC7',
        label = '\xCC\xE8\xED\xE8\xF1\xF2\xE5\xF0\xF1\xF2\xE2\xEE \xC7\xE4\xF0\xE0\xE2\xEE\xEE\xF5\xF0\xE0\xED\xE5\xED\xE8\xFF',
        orgId = TL_ORG_MZ,
        kind = 'leader',
        items = {
            { label = '\xCC\xE8\xED\xE8\xF1\xF2\xF0 \xC7\xE4\xF0\xE0\xE2\xEE\xEE\xF5\xF0\xE0\xED\xE5\xED\xE8\xFF', args = '4 0' },
            { label = '\xC3\xEB\xE0\xE2. \xE2\xF0\xE0\xF7 \xE1\xEE\xEB\xFC\xED\xE8\xF6\xFB \xE3. \xCB\xEE\xF1-\xD1\xE0\xED\xF2\xEE\xF1', args = '4 1' },
            { label = '\xC3\xEB\xE0\xE2. \xE2\xF0\xE0\xF7 \xE1\xEE\xEB\xFC\xED\xE8\xF6\xFB \xE3. \xD1\xE0\xED-\xD4\xE8\xE5\xF0\xF0\xEE', args = '4 2' },
            { label = '\xC3\xEB\xE0\xE2. \xE2\xF0\xE0\xF7 \xE1\xEE\xEB\xFC\xED\xE8\xF6\xFB \xE3. \xCB\xE0\xF1-\xC2\xE5\xED\xF2\xF3\xF0\xE0\xF1', args = '4 3' },
        },
    },
    {
        key = 'smi',
        short = '\xD1\xCC\xC8',
        label = '\xD1\xF0\xE5\xE4\xF1\xF2\xE2\xE0 \xCC\xE0\xF1\xF1\xEE\xE2\xEE\xE9 \xC8\xED\xF4\xEE\xF0\xEC\xE0\xF6\xE8\xE8',
        orgId = TL_ORG_SMI,
        kind = 'leader',
        items = {
            { label = '\xD3\xEF\xF0\xE0\xE2\xEB\xFF\xFE\xF9\xE8\xE9 \xD1\xCC\xC8', args = '5 0' },
            { label = '\xC4\xE8\xF0\xE5\xEA\xF2\xEE\xF0 \xF0\xE0\xE4\xE8\xEE\xF6\xE5\xED\xF2\xF0\xE0 \xE3. \xCB\xEE\xF1-\xD1\xE0\xED\xF2\xEE\xF1', args = '5 1' },
            { label = '\xC4\xE8\xF0\xE5\xEA\xF2\xEE\xF0 \xF0\xE0\xE4\xE8\xEE\xF6\xE5\xED\xF2\xF0\xE0 \xE3. \xD1\xE0\xED-\xD4\xE8\xE5\xF0\xF0\xEE', args = '5 2' },
            { label = '\xC4\xE8\xF0\xE5\xEA\xF2\xEE\xF0 \xF0\xE0\xE4\xE8\xEE\xF6\xE5\xED\xF2\xF0\xE0 \xE3. \xCB\xE0\xF1-\xC2\xE5\xED\xF2\xF3\xF0\xE0\xF1', args = '5 3' },
            { label = '\xC4\xE8\xF0\xE5\xEA\xF2\xEE\xF0 \xF2\xE5\xEB\xE5\xF6\xE5\xED\xF2\xF0\xE0', args = '5 4' },
        },
    },
    {
        key = 'gangs',
        short = '\xC1\xE0\xED\xE4\xFB',
        label = '\xC1\xE0\xED\xE4\xFB',
        kind = 'leader',
        items = {
            { label = 'Grove Street', args = '6 0', orgId = TL_ORG_GROVE },
            { label = 'The Ballas', args = '7 0', orgId = TL_ORG_BALLAS },
            { label = 'Los Santos Vagos', args = '8 0', orgId = TL_ORG_VAGOS },
            { label = 'The Rifa', args = '9 0', orgId = TL_ORG_RIFA },
            { label = 'Varios Los Aztecas', args = '10 0', orgId = TL_ORG_AZTECAS },
        },
    },
    {
        key = 'mafia',
        short = '\xCC\xE0\xF4\xE8\xE8',
        label = '\xCC\xE0\xF4\xE8\xE8',
        kind = 'leader',
        items = {
            { label = 'La Cosa Nostra', args = '11 0', orgId = TL_ORG_LCN },
            { label = 'Yakuza', args = '12 0', orgId = TL_ORG_YAKUZA },
            { label = '\xD0\xF3\xF1\xF1\xEA\xE0\xFF \xEC\xE0\xF4\xE8\xFF', args = '13 0', orgId = TL_ORG_RMAF },
        },
    },
    {
        key = 'works',
        short = '\xD0\xE0\xE1\xEE\xF2\xFB',
        label = '\xD0\xE0\xE1\xEE\xF2\xFB',
        tint = imgui.ImVec4(0.55, 0.72, 0.92, 1.0),
        kind = 'work',
        items = {
            { label = '\xC2\xEE\xE4\xE8\xF2\xE5\xEB\xFC \xE0\xE2\xF2\xEE\xE1\xF3\xF1\xE0', workId = 1 },
            { label = '\xD2\xE0\xEA\xF1\xE8\xF1\xF2', workId = 2 },
            { label = '\xCC\xE0\xF8\xE8\xED\xE8\xF1\xF2', workId = 3 },
            { label = '\xCF\xE8\xEB\xEE\xF2', workId = 4 },
            { label = '\xCF\xEE\xE6\xE0\xF0\xED\xFB\xE9', workId = 5 },
            { label = '\xC0\xE2\xF2\xEE\xEC\xE5\xF5\xE0\xED\xE8\xEA', workId = 6 },
            { label = '\xD0\xE0\xE7\xE2\xEE\xE7\xF7\xE8\xEA \xEF\xF0\xEE\xE4\xF3\xEA\xF2\xEE\xE2 \xE8 \xF2\xEE\xEF\xEB\xE8\xE2\xE0', workId = 7 },
            { label = '\xD3\xEB\xE8\xF7\xED\xFB\xE9 \xF2\xEE\xF0\xE3\xEE\xE2\xE5\xF6', workId = 8 },
            { label = '\xC2\xEE\xE4\xE8\xF2\xE5\xEB\xFC \xF2\xF0\xE0\xEC\xE2\xE0\xFF', workId = 9 },
        },
    },
}

local function tlOrgTintForArgs(args)
    args = tostring(args or ''):match('^%s*(.-)%s*$') or ''
    if args == '' or args == '0 0' then return col_muted end
    for _, org in ipairs(TL_ORGS) do
        if org.kind == 'leader' and type(org.items) == 'table' then
            for _, item in ipairs(org.items) do
                if item.args == args then
                    local oid = item.orgId or org.orgId or tlOrgIdFromArgs(args)
                    return tlOrgTint(oid)
                end
            end
        end
    end
    return tlOrgTint(tlOrgIdFromArgs(args))
end

tempLeadershipUiSynced = false
tlSelectedOrg = 1
tlPendingRestoreCmd = nil

local uiTempLeadershipAutoRestore = imgui and imgui.new and imgui.new.bool(true) or nil

local function tlTrim(s)
    if type(trim) == 'function' then return trim(s) end
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

local function tlArgsMap()
    local map = {}
    for _, org in ipairs(TL_ORGS) do
        if org.kind == 'leader' and type(org.items) == 'table' then
            for _, item in ipairs(org.items) do
                if item.args then map[item.args] = item.label end
            end
        end
    end
    map['0 0'] = nil
    return map
end

function ensureTempLeadershipSettings()
    if type(settings) ~= 'table' then return end
    if settings.temp_leadership_auto_restore == nil then
        settings.temp_leadership_auto_restore = true
    end
    local org = tlTrim(settings.temp_leadership_org or '0 0')
    if org == '' then org = '0 0' end
    settings.temp_leadership_org = org
end

function tempLeadershipOrgLabel(args)
    args = tlTrim(args or '')
    if args == '' or args == '0 0' then
        return '\xED\xE5 \xE7\xE0\xE4\xE0\xED\xEE'
    end
    local map = tlArgsMap()
    return map[args] or args
end

function setTempLeadership(args, save)
    args = tlTrim(args or '')
    if args == '' then return false end
    if type(sendChat) ~= 'function' then return false end
    local ok = sendChat('templeader ' .. args)
    if ok ~= false and save ~= false and type(settings) == 'table' then
        settings.temp_leadership_org = args
        markDirtySettings()
    end
    return ok ~= false
end

function setTempWork(workId)
    workId = tonumber(workId)
    if not workId or workId < 0 or workId > 9 then return false end
    if type(sendChat) ~= 'function' then return false end
    return sendChat('tempwork ' .. tostring(math.floor(workId))) ~= false
end

function syncTempLeadershipUiFromSettings()
    ensureTempLeadershipSettings()
    if uiTempLeadershipAutoRestore then
        uiTempLeadershipAutoRestore[0] = settings.temp_leadership_auto_restore ~= false
    end
end

function tempLeadershipOnServerMessage(color, text)
    if type(settings) ~= 'table' then return end
    if settings.temp_leadership_auto_restore == false then return end
    if not text or text == '' then return end
    local org = tlTrim(settings.temp_leadership_org or '0 0')
    if org == '' or org == '0 0' then return end
    if text ~= TL_RESTORE_MSG_BANK and text ~= TL_RESTORE_MSG_LOGIN then return end
    tlPendingRestoreCmd = 'templeader ' .. org
end

function tempLeadershipPumpPending()
    if not tlPendingRestoreCmd then return end
    if type(sendChat) ~= 'function' then
        tlPendingRestoreCmd = nil
        return
    end
    sendChat(tlPendingRestoreCmd)
    tlPendingRestoreCmd = nil
end

local function tlTabBarFlags()
    local flags = 0
    if imgui.TabBarFlags then
        if imgui.TabBarFlags.FittingPolicyScroll then
            flags = flags + imgui.TabBarFlags.FittingPolicyScroll
        end
        if imgui.TabBarFlags.NoTooltip then
            flags = flags + imgui.TabBarFlags.NoTooltip
        end
    end
    return flags
end

local function tlDrawTopBar()
    deskFormPanelBegin('##tl_top')
    local saved = tlTrim(settings.temp_leadership_org or '0 0')
    local savedLabel = tempLeadershipOrgLabel(saved)
    imgui.TextColored(col_muted2, uiText('\xD1\xEE\xF5\xF0\xE0\xED\xE5\xED\xEE:'))
    imgui.SameLine()
    if saved == '0 0' then
        imgui.TextColored(col_muted, uiText(savedLabel))
    else
        local savedTint = tlOrgTintForArgs(saved)
        tlDrawOrgDot(savedTint)
        imgui.SameLine(0, 6)
        imgui.TextColored(col_label, uiText(savedLabel))
    end
    if uiTempLeadershipAutoRestore and deskFormCheckboxRow(
            '\xC0\xE2\xF2\xEE\xE2\xEE\xF1\xF1\xF2\xE0\xED\xEE\xE2\xEB\xE5\xED\xE8\xE5 \xEF\xEE\xF1\xEB\xE5 \xE2\xF5\xEE\xE4\xE0',
            uiTempLeadershipAutoRestore,
            function(v)
                settings.temp_leadership_auto_restore = v
                markDirtySettings()
            end, 'tl_auto') then end
    local actW = math.max(150, (imgui.GetContentRegionAvail().x - 8) * 0.5)
    if type(pushPlayerActionBtnStyle) == 'function' then pushPlayerActionBtnStyle() end
    if imgui.Button(uiText('\xD1\xED\xFF\xF2\xFC \xEB\xE8\xE4\xE5\xF0\xF1\xF2\xE2\xEE') .. '##tl_clear_leader', imgui.ImVec2(actW, 30)) then
        setTempLeadership('0 0', true)
    end
    imgui.SameLine(0, 8)
    if imgui.Button(uiText('\xD3\xE2\xEE\xEB\xE8\xF2\xFC\xF1\xFF \xF1 \xF0\xE0\xE1\xEE\xF2\xFB') .. '##tl_clear_work', imgui.ImVec2(actW, 30)) then
        setTempWork(0)
    end
    if type(popPlayerActionBtnStyle) == 'function' then popPlayerActionBtnStyle() end
    deskFormPanelEnd()
end

local function tlDrawPositionList(org)
    local rowW = math.max(120, imgui.GetContentRegionAvail().x)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 6))
    for idx, item in ipairs(org.items or {}) do
        local orgId = item.orgId or org.orgId or tlOrgIdFromArgs(item.args)
        local tint = org.kind == 'leader' and tlOrgTint(orgId) or nil
        if type(pushPlayerActionBtnStyle) == 'function' then pushPlayerActionBtnStyle() end
        local label = uiText(item.label or '?')
        if imgui.Button(label .. '##tl_row_' .. org.key .. '_' .. tostring(idx), imgui.ImVec2(rowW, TL_ROW_H)) then
            if org.kind == 'work' then
                setTempWork(item.workId)
            else
                setTempLeadership(item.args, true)
            end
        end
        if tint then
            tlDrawButtonAccent(tint, imgui.IsItemHovered(), imgui.IsItemActive())
        end
        if type(popPlayerActionBtnStyle) == 'function' then popPlayerActionBtnStyle() end
    end
    imgui.PopStyleVar()
end

local function tlBodyFlags()
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        return imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    return 0
end

function drawTempLeadershipTab()
    if not tempLeadershipUiSynced then
        syncTempLeadershipUiFromSettings()
        tempLeadershipUiSynced = true
    end
    ensureTempLeadershipSettings()
    if tlSelectedOrg < 1 then tlSelectedOrg = 1 end
    if tlSelectedOrg > #TL_ORGS then tlSelectedOrg = #TL_ORGS end

    pushPanelStyle(col_chat_bg)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))

    tlDrawTopBar()
    imgui.Dummy(imgui.ImVec2(0, 4))

    local bodyH = math.max(160, imgui.GetContentRegionAvail().y)

    if imgui.BeginTabBar('##tl_orgs', tlTabBarFlags()) then
        for i, org in ipairs(TL_ORGS) do
            local tabLabel = uiText(org.short or org.label)
            local tabOpen = imgui.BeginTabItem(tabLabel .. '##tl_tab_' .. org.key)
            if tabOpen then
                tlSelectedOrg = i
                imgui.BeginChild('##tl_body_' .. org.key, imgui.ImVec2(-1, bodyH), false, tlBodyFlags())
                tlDrawPositionList(org)
                imgui.EndChild()
                imgui.EndTabItem()
            elseif org.label ~= org.short and imgui.IsItemHovered() and imgui.SetTooltip then
                imgui.SetTooltip(uiText(org.label))
            end
        end
        imgui.EndTabBar()
    end

    imgui.PopStyleVar(2)
    popPanelStyle()
end
