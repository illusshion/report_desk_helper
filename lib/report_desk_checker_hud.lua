--[[ Checker ImGui HUD (split from report_desk_checker.lua). ]]
function checkerHudVisible()
    ensureCheckerSettings()
    if settings.checker_hud == false then return false end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
    if type(isSampAvailable) == 'function' and not isSampAvailable() then return false end
    if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then
        if checkerState.hudDrag then checkerState.hudDrag.active = false end
        return false
    end
    return true
end

-- Checker (admin HUD/catalog).
function checkerIsHudVisible()
    return checkerHudVisible()
end

-- Uninstall Checker Hud Frame
function uninstallCheckerHudFrame()
    local prev = rawget(_G, '__desk_checkerHudFrame')
    if (not prev or type(prev.Unsubscribe) ~= 'function')
            and type(deskCache) == 'table' and deskCache.checkerHudFrame then
        prev = deskCache.checkerHudFrame
    end
    if prev and type(prev.Unsubscribe) == 'function' then
        pcall(function() prev:Unsubscribe() end)
    end
    if type(deskCache) == 'table' then deskCache.checkerHudFrame = nil end
    rawset(_G, '__desk_checkerHudFrame', nil)
    if type(checkerState) == 'table' then checkerState.hudFrameInstalled = false end
end

-- Install Checker Hud Frame
function installCheckerHudFrame()
    if toU32 and checkerSpTheme.setColorConverter then
        pcall(checkerSpTheme.setColorConverter, toU32)
    end
    uninstallCheckerHudFrame()
    if type(imgui) ~= 'table' or type(imgui.OnFrame) ~= 'function' then
        checkerState.hudFrameInstalled = true
        return
    end
    local frame = imgui.OnFrame(
        function()
            return checkerHudVisible()
        end,
        function(self)
            local ok, err = pcall(drawCheckerHudOverlay)
            if not ok then
                print('[Report Desk] checker HUD draw: ' .. tostring(err))
            end
            self.HideCursor = deskMimguiHideCursor(
                type(checkerHudWantsInput) == 'function' and checkerHudWantsInput())
            self.LockPlayer = false
        end
    )
    if frame then
        frame.HideCursor = true
        frame.LockPlayer = false
        if type(deskCache) == 'table' then deskCache.checkerHudFrame = frame end
        rawset(_G, '__desk_checkerHudFrame', frame)
    end
    checkerState.hudFrameInstalled = true
end

-- Checker (admin HUD/catalog).
function checkerSafePlayerColor(id)
    id = tonumber(id)
    if not id then return nil end
    if type(sampIsPlayerConnected) ~= 'function' or type(sampGetPlayerColor) ~= 'function' then return nil end
    if not sampIsPlayerConnected(id) then return nil end
    local ok, color = SafeCall('sampGetPlayerColor', function()
        return sampGetPlayerColor(id)
    end)
    if not ok or not color then return nil end
    return checkerSampColorToImVec4(color)
end

-- Checker (admin HUD/catalog).
function checkerScreenSize()
    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    return sw, sh
end

-- Checker (admin HUD/catalog).
function checkerClampHudPos(hx, hy, winW, winH)
    local sw, sh = checkerScreenSize()
    winW = math.max(CHECKER_HUD_W, tonumber(winW) or CHECKER_HUD_W)
    winH = math.max(48, tonumber(winH) or 120)
    hx = math.max(8, math.min(hx, sw - winW - 8))
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

-- Checker (admin HUD/catalog).
function checkerHudSavedHeight(fallback)
    local h = tonumber(settings.checker_hud_h)
    if h and h >= 48 then return h end
    return math.max(48, tonumber(fallback) or 120)
end

-- Checker (admin HUD/catalog).
function checkerGuardHudOffScreen(hx, hy, winW, winH)
    local sw, sh = checkerScreenSize()
    winW = math.max(CHECKER_HUD_W, tonumber(winW) or CHECKER_HUD_W)
    winH = checkerHudSavedHeight(winH)
    if hx >= 8 and hy >= 8 and hx + winW <= sw - 8 and hy + winH <= sh - 8 then
        return hx, hy, false
    end
    local nx, ny = checkerClampHudPos(hx, hy, winW, winH)
    settings.checker_hud_x = math.floor(nx + 0.5)
    settings.checker_hud_y = math.floor(ny + 0.5)
    markDirtySettings()
    return nx, ny, true
end

-- Checker (admin HUD/catalog).
function checkerPersistHudPos(hx, hy, winW, winH, flushNow)
    hx, hy = checkerClampHudPos(hx, hy, winW, winH)
    local nx = math.floor(hx + 0.5)
    local ny = math.floor(hy + 0.5)
    local nh = math.floor(math.max(48, tonumber(winH) or 120) + 0.5)
    local ox = math.floor(tonumber(settings.checker_hud_x) or 8)
    local oy = math.floor(tonumber(settings.checker_hud_y) or 8)
    local oh = math.floor(tonumber(settings.checker_hud_h) or 160)
    checkerState.hudPlaced = true
    if nx == ox and ny == oy and nh == oh then
        return
    end
    settings.checker_hud_x = nx
    settings.checker_hud_y = ny
    settings.checker_hud_h = nh
    markDirtySettings()
    if flushNow and type(flushDirtyConfigNow) == 'function' then
        SafeCall('flushDirtyConfigNow', flushDirtyConfigNow)
    end
end

-- Checker (admin HUD/catalog).
function checkerIsHudDragActive()
    return checkerState.hudDrag and checkerState.hudDrag.active == true
end

-- Checker (admin HUD/catalog).
function checkerHudWantsInput()
    if not checkerHudVisible() or checkerIsSuspended() then return false end
    if checkerState.hudDrag and checkerState.hudDrag.active then return true end
    if checkerState.hudHovered then return true end
    local r = checkerState.hudRect
    if r then
        local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
            or type(deskPointerInRect) == 'function' and deskPointerInRect
        if pin and pin(r) then return true end
        if imgui and type(imgui.GetIO) == 'function' then
            local ok, io = pcall(imgui.GetIO)
            if ok and io and io.MousePos then
                local mp = io.MousePos
                if mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1 then
                    return true
                end
            end
        end
    end
    local hx = tonumber(settings.checker_hud_x) or 8
    local hy = tonumber(settings.checker_hud_y) or 8
    local estW = tonumber(checkerState.hudLastW) or (CHECKER_HUD_W + 80)
    local estH = tonumber(checkerState.hudLastH) or checkerHudSavedHeight(160)
    local est = { x0 = hx, y0 = hy, x1 = hx + estW, y1 = hy + estH }
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin and pin(est) then return true end
    if imgui and type(imgui.GetIO) == 'function' then
        local ok, io = pcall(imgui.GetIO)
        if ok and io and io.MousePos then
            local mp = io.MousePos
            return mp.x >= est.x0 and mp.x < est.x1 and mp.y >= est.y0 and mp.y < est.y1
        end
    end
    return false
end

-- HUD-СЃС‚СЂРѕРєР°: РѕРґРЅР° Р»РёРЅРёСЏ, Р±РµР· РїРµСЂРµРЅРѕСЃР° (СѓСЂРѕРІРµРЅСЊ/С‚РµРі РЅРµ СѓРµР·Р¶Р°РµС‚ РЅР° СЃС‚СЂРѕРєСѓ РЅРёР¶Рµ).
local function drawCheckerHudRow(label, col)
    imgui.PushTextWrapPos(0)
    imgui.TextColored(col, uiText(label))
    imgui.PopTextWrapPos()
end

-- Checker (admin HUD/catalog).
function checkerOnlineTags(e)
    if e and e.afk then return ' AFK' end
    return ''
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerAdminRow(e, index, idSuffix, indent)
    indent = tonumber(indent) or 0
    local lv = math.floor(tonumber(e.level) or 0)
    local col = checkerAdminColor(lv)
    local prefix = indent > 0 and '  ' or ''
    local label = string.format('%s%i. %s [%i]', prefix, index, e.nick or '', e.id or -1)
    local lvlText = checkerFormatAdminLevelDisplay(lv, e.nick)
    if lvlText ~= '' then
        label = label .. '  ' .. lvlText
    end
    label = label .. checkerOnlineTags(e)
    drawCheckerHudRow(label, col)
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerAdminsBlock()
    local list = select(1, checkerHudLists())
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    local executive, regular, special = checkerSplitAdminLists(list)
    local shown = 0
    if #executive > 0 then
        for _, e in ipairs(executive) do
            shown = shown + 1
            drawCheckerAdminRow(e, shown, 'adm_e_', 0)
        end
    end
    if #regular > 0 then
        if #executive > 0 then
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        shown = 0
        for _, e in ipairs(regular) do
            shown = shown + 1
            drawCheckerAdminRow(e, shown, 'adm_', 0)
        end
    end
    if #special > 0 then
        if #executive > 0 or #regular > 0 then
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        checkerSpTheme.drawSectionLabel(
            '\x50\x52 \xE8 \xF2\xE5\xF5\xED\xE0\xF0\xE8:',
            col_muted2, uiText)
        local sIndex = 0
        for _, e in ipairs(special) do
            sIndex = sIndex + 1
            drawCheckerAdminRow(e, sIndex, 'adm_s_', 0)
        end
    end
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerColorListBlock(list, emptyText, idPrefix)
    idPrefix = idPrefix or 'pl'
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText(emptyText))
        return
    end
    local shown = 0
    for _, e in ipairs(list) do
        shown = shown + 1
        local col = checkerSafePlayerColor(e.id) or col_accent
        local label = string.format('%i. %s [%i]%s', shown, e.nick, e.id, checkerOnlineTags(e))
        drawCheckerHudRow(label, col)
    end
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerLeadersBlock()
    local list = select(2, checkerHudLists())
    if #list == 0 then
        imgui.TextColored(col_muted2, uiText('\xCB\xE8\xE4\xE5\xF0\xEE\xE2 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2'))
        return
    end
    local shown = 0
    for _, e in ipairs(list) do
        shown = shown + 1
        local col = checkerSafePlayerColor(e.id) or col_accent
        local label = string.format('%i. %s [%i]%s', shown, e.nick, e.id, checkerOnlineTags(e))
        drawCheckerHudRow(label, col)
    end
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerFriendsBlock()
    ensureCheckerCatalog()
    local list = select(3, checkerHudLists())
    local filtered = {}
    for _, e in ipairs(list) do
        if e and e.nick and not Catalog.getAdmin(e.nick) then
            filtered[#filtered + 1] = e
        end
    end
    drawCheckerColorListBlock(filtered, '\xC4\xF0\xF3\xE7\xE5\xE9 \xE2 \xF1\xE5\xF2\xE8 \xED\xE5\xF2', 'fr')
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerFriendsSettings()
    ensureCheckerCatalog()
    if not checkerUi.friendNick then return end
    imgui.TextColored(col_muted2, uiText('\xCD\xE8\xEA \xE4\xF0\xF3\xE3\xE0 (\xED\xE5 \xE8\xE7 \xEA\xE0\xF2\xE0\xEB\xEE\xE3\xE0 \xE0\xE4\xEC\xE8\xED\xEE\xE2):'))
    imgui.Dummy(imgui.ImVec2(0, 4))
    if imgui.InputTextWithHint then
        imgui.InputTextWithHint('##chk_fr_nick', uiText('Nick_Name'), checkerUi.friendNick, sizeof(checkerUi.friendNick))
    else
        imgui.InputText('##chk_fr_nick', checkerUi.friendNick, sizeof(checkerUi.friendNick))
    end
    imgui.SameLine()
    if imgui.Button(uiText('\xC4\xEE\xE1\xE0\xE2\xE8\xF2\xFC') .. '##chk_fr_add') then
        local nick = readInputBuf(checkerUi.friendNick)
        if checkerAddFriend(nick) then
            checkerUi.friendNick[0] = 0
        end
    end
    imgui.Spacing()
    local visible = {}
    for _, e in ipairs(checkerCatalog.friends) do
        if e and e.nick and not Catalog.getAdmin(e.nick) then
            visible[#visible + 1] = e
        end
    end
    if #visible == 0 then
        imgui.TextColored(col_muted2, uiText('\xD1\xEF\xE8\xF1\xEE\xEA \xE4\xF0\xF3\xE7\xE5\xE9 \xEF\xF3\xF1\xF2'))
        return
    end
    for i, e in ipairs(visible) do
        local nick = e.nick or ''
        local uid = nickKey(nick)
        local id = checkerLookupOnlineId(nick)
        local online = id and checkerPlayerConnectedSafe(id)
        local nickCol = online and checkerSafePlayerColor(id) or col_muted2
        imgui.PushID('chk_fr_' .. uid)
        if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
        imgui.TextColored(nickCol, uiText(nick))
        if online then
            imgui.SameLine(0, 6)
            imgui.TextColored(col_muted2, uiText('[' .. tostring(id) .. ']'))
        end
        imgui.SameLine(0, 12)
        local removed = false
        if imgui.SmallButton then
            removed = imgui.SmallButton(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##chk_fr_rm_' .. uid)
        elseif imgui.Button then
            removed = imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC') .. '##chk_fr_rm_' .. uid)
        end
        if removed then
            checkerRemoveFriend(nick)
        end
        imgui.PopID()
    end
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
local function drawCheckerLeaderSubsectionHeader(factionKey, count)
    local meta = checkerLeaderFactionMeta(factionKey)
    local col = meta.headerColor or col_muted2
    if checkerSpTheme and checkerSpTheme.drawSectionLabel then
        checkerSpTheme.drawSectionLabel(meta.title, col, uiText)
    else
        imgui.TextColored(col, uiText(meta.title))
    end
    imgui.SameLine(0, 6)
    imgui.TextColored(col_muted2, uiText('(' .. tostring(count or 0) .. ')'))
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
local function drawCheckerLeaderFactionHeader(factionKey, count, firstSection)
    local meta = checkerLeaderFactionMeta(factionKey)
    local headerCol = checkerLeaderFactionClistImColor(factionKey, true)
    if not firstSection then
        imgui.Dummy(imgui.ImVec2(0, 8))
    end
    if checkerSpTheme and checkerSpTheme.drawSectionLabel then
        checkerSpTheme.drawSectionLabel(meta.title, headerCol, uiText)
    else
        imgui.TextColored(headerCol, uiText(meta.title))
    end
    imgui.SameLine(0, 6)
    imgui.TextColored(col_muted2, uiText('(' .. tostring(count or 0) .. ')'))
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerLeaderSettingsRow(entry)
    local nick = entry.nick or ''
    local ref = checkerLeaderShowRef(nick)
    if not ref then return end
    local uid = nickKey(nick)
    local visible = ref[0] and true or false
    local nickCol = checkerLeaderFactionColor(entry, visible)
    local sub = checkerLeaderSubline(entry)
    local id = entry.id or checkerLookupOnlineId(nick)
    if id and checkerPlayerConnectedSafe(id) then
        sub = (sub ~= '' and (sub .. '  \xB7  ') or '') .. '\xE2 \xF1\xE5\xF2\xE8'
    end

    imgui.PushID('chk_ld_' .. uid)
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    local changed = false
    if imgui.Checkbox('##vis', ref) then
        changed = true
    end
    imgui.SameLine(0, 8)
    imgui.TextColored(nickCol, uiText(nick))
    if sub ~= '' then
        imgui.SameLine(0, 6)
        imgui.TextColored(col_muted2, checkerLeaderUiText(sub))
    end
    imgui.PopID()
    if changed then
        checkerSetLeaderHidden(nick, not ref[0])
    end
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerLeadersSettings()
    ensureCheckerCatalog()
    local leaders = checkerCatalog.leaders
    if #leaders == 0 then
        imgui.TextColored(col_muted2, uiText('\xCA\xE0\xF2\xE0\xEB\xEE\xE3 \xEB\xE8\xE4\xE5\xF0\xEE\xE2 \xEF\xF3\xF1\xF2 \x2014 \xE7\xE0\xE3\xF0\xF3\xE6\xE0\xE5\xF2\xF1\xFF \xE0\xE2\xF2\xEE\xEC\xE0\xF2\xE8\xF7\xE5\xF1\xEA\xE8 \xEF\xF0\xE8 \xE2\xF5\xEE\xE4\xE5'))
        return
    end

    local order, groups = checkerBuildLeaderFactionGroups(leaders)
    if #order == 0 then
        return
    end
    for gi, fk in ipairs(order) do
        if fk == 'illegal' then
            local bands = groups.band or {}
            local mafias = groups.mafia or {}
            if gi > 1 then
                imgui.Dummy(imgui.ImVec2(0, 8))
            end
            if #bands > 0 then
                drawCheckerLeaderSubsectionHeader('band', #bands)
                for _, e in ipairs(bands) do
                    drawCheckerLeaderSettingsRow(e)
                end
            end
            if #bands > 0 and #mafias > 0 then
                imgui.Dummy(imgui.ImVec2(0, 4))
            end
            if #mafias > 0 then
                drawCheckerLeaderSubsectionHeader('mafia', #mafias)
                for _, e in ipairs(mafias) do
                    drawCheckerLeaderSettingsRow(e)
                end
            end
        else
            local entries = groups[fk]
            drawCheckerLeaderFactionHeader(fk, #entries, gi == 1)
            for _, e in ipairs(entries) do
                drawCheckerLeaderSettingsRow(e)
            end
        end
    end
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
-- === Checker HUD ImGui overlay ===
function drawCheckerHudOverlay()
    if not checkerHudVisible() then return end
    ensureCheckerSettings()
    local hudAdmins = select(1, checkerHudLists())
    if #hudAdmins > 0 then
        checkerState.hudHealAttempts = 0
        checkerState.healResetAt = 0
    end

    local hudH = checkerHudSavedHeight(120)
    local rawHx = tonumber(settings.checker_hud_x) or 8
    local rawHy = tonumber(settings.checker_hud_y) or 8
    local hx, hy = checkerClampHudPos(rawHx, rawHy, CHECKER_HUD_W, hudH)
    if not checkerState.hudDrag then
        checkerState.hudDrag = { active = false, offX = 0, offY = 0 }
    end
    local drag = checkerState.hudDrag
    if drag.active then
        hx = drag.offX
        hy = drag.offY
    elseif not checkerState.hudPlaced
            and (math.floor(hx + 0.5) ~= math.floor(rawHx + 0.5)
            or math.floor(hy + 0.5) ~= math.floor(rawHy + 0.5)) then
        checkerPersistHudPos(hx, hy, CHECKER_HUD_W, hudH, true)
    end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoNav + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoSavedSettings then
        flags = flags + imgui.WindowFlags.NoSavedSettings
    end

    imgui.SetNextWindowSizeConstraints(
        imgui.ImVec2(CHECKER_HUD_W, 0), imgui.ImVec2(CHECKER_HUD_W + 80, 900))
    if imgui.SetNextWindowBgAlpha then
        imgui.SetNextWindowBgAlpha(checkerSpTheme.HUD_OVERLAY_ALPHA or 0.80)
    end
    imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)

    checkerSpTheme.pushHudChrome()
    if imgui.Begin('###desk_checker_hud', nil, flags) then
        checkerState.hudHovered = false
        checkerSpTheme.drawPanelFrame()
        local hudAdmins, hudLeaders, hudFriends = checkerHudLists()
        checkerSpTheme.drawPanelTitle(
            '\xD7\xE5\xEA\xE5\xF0',
            string.format('(%i/%i/%i)', #hudAdmins, #hudLeaders, #hudFriends),
            col_accent, col_muted2, uiText)

        if settings.checker_show_admins ~= false then
            checkerSpTheme.drawSectionLabel(
                '\xC0\xE4\xEC\xE8\xED\xFB:',
                col_muted2, uiText)
            drawCheckerAdminsBlock()
            imgui.Spacing()
        end
        if settings.checker_show_leaders ~= false then
            checkerSpTheme.drawSectionLabel(
                '\xCB\xE8\xE4\xE5\xF0\xFB:',
                col_muted2, uiText)
            drawCheckerLeadersBlock()
            imgui.Spacing()
        end
        if settings.checker_show_friends ~= false then
            checkerSpTheme.drawSectionLabel(
                '\xC4\xF0\xF3\xE7\xFC\xFF:',
                col_muted2, uiText)
            drawCheckerFriendsBlock()
            imgui.Spacing()
        end

        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        checkerState.hudLastW = ww
        checkerState.hudLastH = wh
        checkerState.hudRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }

        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        imgui.InvisibleButton('##checker_hud_drag', imgui.ImVec2(-1, -1))
        if imgui.IsItemHovered() or imgui.IsItemActive() or drag.active then
            checkerState.hudHovered = true
        end
        if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
            local delta = imgui.GetMouseDragDelta(0)
            if not drag.active then
                drag.active = true
                drag.startX = wp.x
                drag.startY = wp.y
                imgui.ResetMouseDragDelta(0)
                delta = imgui.GetMouseDragDelta(0)
            end
            drag.offX = drag.startX + delta.x
            drag.offY = drag.startY + delta.y
            drag.offX, drag.offY = checkerClampHudPos(drag.offX, drag.offY, ww, wh)
        elseif drag.active and not imgui.IsMouseDown(0) then
            drag.active = false
            checkerPersistHudPos(wp.x, wp.y, ww, wh, true)
        end

        imgui.End()
    end
    checkerSpTheme.popHudChrome()
end

-- РћС‚СЂРёСЃРѕРІРєР° checker UI.
function drawCheckerTab()
    if not checkerState.uiSynced then syncCheckerUiFromSettings() end
    if settings.checker_auto_sync ~= false and checkerIsSpawned()
            and not checkerState.spawnLeadersHandled
            and not checkerState.spawnCatalogSyncRunning
            and type(checkerRequestLeadersSync) == 'function'
            and type(checkerIsLeadersOnlySyncBlocked) == 'function'
            and type(checkerSyncLeadersActive) == 'function'
            and not checkerIsLeadersOnlySyncBlocked()
            and not checkerSyncLeadersActive(os.clock()) then
        local now = os.clock()
        local last = tonumber(checkerState.leadersTabSyncAt) or 0
        if now - last >= 12.0 then
            checkerState.leadersTabSyncAt = now
            SafeCall('checkerTabLeadersSync', checkerRequestLeadersSync, false, true)
        end
    end
    pushPanelStyle(col_chat_bg)
    local childFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        childFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##checker_panel', imgui.ImVec2(-1, -1), false, childFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 6))

    deskFormPanelBegin('##chk_hud')
    drawSettingsCardHeader('\xCE\xE2\xE5\xF0\xEB\xE5\xE9 \xED\xE0 \xFD\xEA\xF0\xE0\xED\xE5')
    if deskFormCheckboxRow('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xF2\xFC HUD', checkerUi.hud, function(v)
        settings.checker_hud = v
        if not v then checkerState.hudPlaced = false end
        markDirtySettings()
    end) then end
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_show')
    drawSettingsCardHeader('\xD1\xE5\xEA\xF6\xE8\xE8')
    if deskFormCheckboxRow('\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xFB', checkerUi.showAdmins, function(v)
        settings.checker_show_admins = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xCB\xE8\xE4\xE5\xF0\xFB', checkerUi.showLeaders, function(v)
        settings.checker_show_leaders = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xC4\xF0\xF3\xE7\xFC\xFF', checkerUi.showFriends, function(v)
        settings.checker_show_friends = v
        markDirtySettings()
    end) then end
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_friends')
    drawSettingsCardHeader('\xC4\xF0\xF3\xE7\xFC\xFF')
    drawCheckerFriendsSettings()
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_leaders_vis')
    drawSettingsCardHeader('\xCB\xE8\xE4\xE5\xF0\xFB \xE2 HUD')
    drawCheckerLeadersSettings()
    deskFormPanelEnd()

    deskFormPanelBegin('##chk_notify')
    drawSettingsCardHeader('\xD3\xE2\xE5\xE4\xEE\xEC\xEB\xE5\xED\xE8\xFF')
    if deskFormCheckboxRow('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5 (\xE0\xE4\xEC\xE8\xED\xFB)', checkerUi.notifyJoin, function(v)
        settings.checker_notify_join = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xCF\xEE\xE4\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5 (\xEB\xE8\xE4\xE5\xF0\xFB)', checkerUi.notifyLeaderJoin, function(v)
        settings.checker_notify_leader_join = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xCE\xF2\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE5 (\xE0\xE4\xEC\xE8\xED\xFB \xE8 \xEB\xE8\xE4\xE5\xF0\xFB)', checkerUi.notifyQuit, function(v)
        settings.checker_notify_quit = v
        markDirtySettings()
    end) then end
    if deskFormCheckboxRow('\xC7\xE2\xF3\xEA \xEF\xF0\xE8 \xEF\xEE\xE4\xEA\xEB\xFE\xF7\xE5\xED\xE8\xE8', checkerUi.notifySound, function(v)
        settings.checker_notify_sound = v
        markDirtySettings()
    end) then end
    deskFormPanelEnd()

    imgui.PopStyleVar()
    imgui.EndChild()
    popPanelStyle()
end
