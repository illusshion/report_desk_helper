--[[ Модуль: выдача скинов, каталог превью. ]]
function skinsLoadCatalog()
    if skinCatalog then return end
    skinCatalog = {}
    skinCatalogById = {}
    local indexPath = SKINS_DIR .. 'skins_index.lua'
    if doesFileExist(indexPath) then
        local chunk, err = loadfile(indexPath)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == 'table' then skinCatalog = data end
        else
            print('[Report Desk] skins index: ' .. tostring(err))
        end
    end
    if #skinCatalog == 0 then
        for id = 1, 311 do
            if id ~= 74 then
                local file = string.format('skin-%d.png', id)
                if doesFileExist(SKINS_DIR .. file) then
                    skinCatalog[#skinCatalog + 1] = { id = id, file = file }
                end
            end
        end
        table.sort(skinCatalog, function(a, b) return a.id < b.id end)
    end
    for _, e in ipairs(skinCatalog) do
        skinCatalogById[e.id] = e
    end
end

-- Skins Preload Progress
function skinsPreloadProgress()
    local pending = deskTexPipeline.pendingCount(TEX_NS_SKIN)
    local loaded = deskTex and deskTex.count(TEX_NS_SKIN) or 0
    return loaded, pending + loaded
end

-- Skins File Path
function skinsFilePath(entry)
    return deskTexLoad.resolveSkinPath(SKINS_DIR, entry)
end

-- Skins Path For Id
function skinsPathForId(id)
    skinsLoadCatalog()
    local entry = skinCatalogById[tonumber(id) or id]
    if not entry then return nil end
    return skinsFilePath(entry)
end

-- Skin Peek Texture
function skinPeekTexture(entry)
    if not entry or not entry.id then return nil end
    return deskTex.peek(TEX_NS_SKIN, entry.id)
end

-- Skin Draw Texture Safe
function skinDrawTextureSafe(tex, id, w, h, asButton, label)
    if not tex or not id or not deskTex.has(TEX_NS_SKIN, id) then return false, false end
    local size = imgui.ImVec2(w, h)
    if asButton and imgui.ImageButton then
        local ok, clicked = pcall(imgui.ImageButton, tex, size)
        return ok, ok and clicked
    end
    if imgui.Image then
        local ok = pcall(imgui.Image, tex, size)
        return ok, false
    end
    if label and imgui.Button then
        return true, imgui.Button(label, size)
    end
    return false, false
end

-- Skins Enqueue Visible
function skinsEnqueueVisible(firstIdx, lastIdx, items)
    if not deskTex then return end
    local ids = {}
    for i = firstIdx, lastIdx do
        local e = items[i]
        if e and e.id then ids[#ids + 1] = e.id end
    end
    deskTexPipeline.syncVisible(TEX_NS_SKIN, ids, deskTex, { priority = { skinSelectedId } })
end

-- Skins On Tab Enter
function skinsOnTabEnter()
    skinsLoadCatalog()
    deskTexPipeline.activate(TEX_NS_SKIN)
end

-- Skins On Tab Leave
function skinsOnTabLeave()
    deskTexPipeline.deactivate(TEX_NS_SKIN, deskTex)
    deskTexPipeline.requestDeferredFlush()
end

-- Init Desk Catalog Warmup
function initDeskCatalogWarmup()
    deskTexPipeline.configure({
        maxBytes = SKIN_MAX_FILE_BYTES,
        stagingMax = TEX_STAGING_MAX,
        gpuBudget = CATALOG_GPU_BUDGET,
        ioIdleMs = CATALOG_IO_IDLE_MS,
    })
    deskTex.configure(TEX_NS_SKIN, { max = SKIN_TEX_CACHE_MAX, persistent = false })
    deskTex.configure('veh', { max = VEH_TEX_CACHE_MAX, persistent = false })
    deskTexPipeline.registerNs(TEX_NS_SKIN, {
        pathForId = skinsPathForId,
        releaseFn = skinTexRelease,
    })
    catWarmup.inited = true
end

-- Ensure Desk Catalog Warmup
function ensureDeskCatalogWarmup()
    if catWarmup.inited then return end
    pcall(initDeskCatalogWarmup)
end

-- Reset Desk Catalog Warmup
function resetDeskCatalogWarmup()
    pcall(deskTexPipeline.halt, deskTex)
    catWarmup.inited = false
    pcall(ensureDeskCatalogWarmup)
end

-- Desk hook/helper.
function deskCatalogTabActive()
    return skinUiTabActive or (deskVeh and deskVeh.tabActive == true)
end

-- Desk hook/helper.
function deskCatalogTexTick()
    if deskTexPipeline.isDead and deskTexPipeline.isDead() then return end
    if not deskCatalogTabActive() then return end
    if isPauseMenuActive and isPauseMenuActive() then return end
    if isGamePaused and isGamePaused() then return end
    deskTexPipeline.tick(imgui, deskTex, CATALOG_GPU_BUDGET)
end

-- Desk hook/helper.
function deskFlushCatalogTexPending()
    if not deskCache.catalogTexFlushPending then return end
    deskCache.catalogTexFlushPending = false
    pcall(deskTexPipeline.flushDeferred, deskTex, imgui)
end

-- Skins Count Files
function skinsCountFiles()
    if not doesDirectoryExist or not doesDirectoryExist(SKINS_DIR) then return 0 end
    local n = 0
    for id = 1, 311 do
        if id ~= 74 and doesFileExist(SKINS_DIR .. string.format('skin-%d.png', id)) then
            n = n + 1
        end
    end
    return n
end

-- Skin Get Texture
function skinGetTexture(entry)
    if not entry or not entry.id then return nil end
    return deskTex.peek(TEX_NS_SKIN, entry.id)
end

-- Skins Get Nearby Count
function skinsGetNearbyCount()
    local r = skinsGetRadius()
    local now = os.clock()
    if skinNearbyCache.r == r and now - skinNearbyCache.t < SKIN_NEARBY_CACHE_SEC then
        return skinNearbyCache.n
    end
    skinNearbyCache.n = #skinsCollectNearby(r)
    skinNearbyCache.r = r
    skinNearbyCache.t = now
    return skinNearbyCache.n
end

-- Skins Rebuild Filter
function skinsRebuildFilter()
    skinsLoadCatalog()
    local filter = readInputBuf(skinFilterBuf)
    filter = filter:gsub('^%s+', ''):gsub('%s+$', '')
    if filter == deskCache.skinFilterSig and #skinFiltered > 0 then return end
    deskCache.skinFilterSig = filter
    skinFiltered = {}
    for _, e in ipairs(skinCatalog) do
        local idStr = tostring(e.id)
        if filter == '' or idStr:find(filter, 1, true) then
            skinFiltered[#skinFiltered + 1] = e
        end
    end
    deskCache.skinGridLayoutCache = nil
    deskCache.skinGridLayoutSig = ''
    deskCache.skinGridPage = 1
end

-- Skins Parse Target Ids
function skinsParseTargetIds(text)
    local ids = {}
    local seen = {}
    for part in tostring(text or ''):gmatch('%d+') do
        local pid = tonumber(part)
        if pid and pid >= 0 and not seen[pid] then
            seen[pid] = true
            ids[#ids + 1] = pid
        end
    end
    return ids
end

-- Skins Validate Skin Id
function skinsValidateSkinId(sid)
    sid = tonumber(sid) or 0
    if sid <= 0 or sid > 311 or sid == 74 then
        return nil
    end
    return sid
end

-- Skins Get Radius
function skinsGetRadius()
    local r = tonumber(uiSkinRadius[0]) or tonumber(settings.skin_radius) or 20
    r = math.max(SKIN_RADIUS_MIN, math.min(SKIN_RADIUS_MAX, math.floor(r)))
    uiSkinRadius[0] = r
    return r
end

-- Skins Set Radius
function skinsSetRadius(r)
    r = math.max(SKIN_RADIUS_MIN, math.min(SKIN_RADIUS_MAX, math.floor(tonumber(r) or 20)))
    uiSkinRadius[0] = r
    settings.skin_radius = r
    skinNearbyCache.t = 0
    markDirtySettings()
end

-- Skins Adjust Radius
function skinsAdjustRadius(delta)
    skinsSetRadius(skinsGetRadius() + (tonumber(delta) or 0))
end

-- Draw Skin Radius Control
function drawSkinRadiusControl()
    local radius = skinsGetRadius()
    local btnSz = 28
    local avail = imgui.GetContentRegionAvail().x
    local midW = math.max(56, avail - btnSz * 2 - 16)
    if imgui.Button('-##skin_rad_dec', imgui.ImVec2(btnSz, btnSz)) then
        skinsAdjustRadius(-1)
        radius = skinsGetRadius()
    end
    imgui.SameLine(0, 8)
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.14, 0.14, 0.18, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14, 0.14, 0.18, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.14, 0.14, 0.18, 1.0))
    imgui.Button(uiText(string.format('%d \xEC', radius)) .. '##skin_rad_val', imgui.ImVec2(midW, btnSz))
    imgui.PopStyleColor(3)
    imgui.SameLine(0, 8)
    if imgui.Button('+##skin_rad_inc', imgui.ImVec2(btnSz, btnSz)) then
        skinsAdjustRadius(1)
    end
end

-- Skins Collect Nearby
function skinsCollectNearby(radius)
    local list = {}
    if not sampGetMaxPlayerId or not sampIsPlayerConnected or not sampGetCharHandleBySampPlayerId then
        return list
    end
    if not doesCharExist(PLAYER_PED) then return list end
    radius = skinsGetRadius()
    local maxId = sampGetMaxPlayerId(true) or 0
    for pid = 0, maxId do
        if sampIsPlayerConnected(pid) then
            local ok, char = sampGetCharHandleBySampPlayerId(pid)
            if ok and char and doesCharExist(char) and char ~= PLAYER_PED then
                if locateCharAnyMeansChar3d(PLAYER_PED, char, radius, radius, radius, false) then
                    if not isCharInAnyCar(char) then
                        list[#list + 1] = pid
                    end
                end
            end
        end
    end
    table.sort(list)
    return list
end

-- Skins Cancel Apply Job
function skinsCancelApplyJob()
    if skinRadiusJob.active then
        skinRadiusJob.cancel = true
        say('\xCE\xF2\xEC\xE5\xED\xE0 \xE2\xFB\xE4\xE0\xF7\xE8 \xF1\xEA\xE8\xED\xEE\xE2...')
    end
end

-- Skins Start Apply Job
function skinsStartApplyJob(targets, sid)
    if skinRadiusJob.active then
        say('\xC2\xFB\xE4\xE0\xF7\xE0 \xF1\xEA\xE8\xED\xEE\xE2 \xF3\xE6\xE5 \xE8\xE4\xB8\xF2...')
        return false
    end
    if not targets or #targets < 1 then
        return false
    end
    local delayMs = math.max(2000, tonumber(settings.skin_apply_delay_ms) or 2500)
    skinRadiusJob.active = true
    skinRadiusJob.cancel = false
    skinApplyCooldownUntil = os.clock() + delayMs * 0.001 * #targets + 1
    say(string.format('\xC2\xFB\xE4\xE0\xF0\xE0 \xF1\xEA\xE8\xED %d: %d \xE8\xE3\xF0. (\xEF\xE0\xF3\xE7\xE0 %d \xEC\xF1)', sid, #targets, delayMs))
    lua_thread.create(function()
        local given = 0
        for _, pid in ipairs(targets) do
            if skinRadiusJob.cancel then break end
            sendChat(string.format('skin %d %d', pid, sid))
            given = given + 1
            if given < #targets and not skinRadiusJob.cancel then
                wait(delayMs)
            end
        end
        skinRadiusJob.active = false
        skinRadiusJob.cancel = false
        if given > 0 then
            say(string.format('\xC2\xFB\xE4\xE0\xED\xEE \xF1\xEA\xE8\xED\xEE\xE2: %d', given))
        else
            say('\xC2\xFB\xE4\xE0\xF7\xE0 \xEE\xF2\xEC\xE5\xED\xE5\xED\xE0')
        end
    end)
    return true
end

-- Skins Apply To Listed Targets
function skinsApplyToListedTargets()
    local now = os.clock()
    if now < skinApplyCooldownUntil then
        say('\xCF\xEE\xE4\xEE\xE6\xE4\xE8\xF2\xE5...')
        return
    end
    local sid = skinsValidateSkinId(skinSelectedId)
    if not sid then
        say('\xCD\xE5\xE2\xE5\xF0\xED\xFB\xE9 ID \xF1\xEA\xE8\xED\xE0')
        return
    end
    local targets = skinsParseTargetIds(readInputBuf(skinTargetBuf))
    if #targets == 0 then
        say('\xD3\xEA\xE0\xE6\xE8\xF2\xE5 ID \xE8\xE3\xF0\xEE\xEA\xEE\xE2 \xF7\xE5\xF0\xE5\xE7 \xE7\xE0\xEF\xFF\xF2\xF3\xFE')
        return
    end
    local total = #targets
    if total > SKIN_LIST_MAX_TARGETS then
        local trimmed = {}
        for i = 1, SKIN_LIST_MAX_TARGETS do trimmed[i] = targets[i] end
        targets = trimmed
        say(string.format('\xCB\xF3\xF7\xE0 %d \xE8\xE7 %d (\xEB\xE8\xEC\xE8\xF2 %d)', #targets, total, SKIN_LIST_MAX_TARGETS))
    end
    skinApplyCooldownUntil = now + SKIN_APPLY_COOLDOWN_SEC
    skinsStartApplyJob(targets, sid)
end

-- Skins Apply In Radius
function skinsApplyInRadius()
    local sid = skinsValidateSkinId(skinSelectedId)
    if not sid then
        say('\xCD\xE5\xE2\xE5\xF0\xED\xFB\xE9 ID \xF1\xEA\xE8\xED\xE0')
        return
    end
    local radius = skinsGetRadius()
    skinsSetRadius(radius)
    markDirtySettings()
    local targets = skinsCollectNearby(radius)
    if #targets == 0 then
        say(string.format('\xC2 \xF0\xE0\xE4\xE8\xF3\xF1\xE5 %d \xEC \xED\xE5\xF2 \xE8\xE3\xF0\xEE\xEA\xEE\xE2 (\xED\xE0 \xF0\xF3\xEA\xE0\xF5)', radius))
        return
    end
    local total = #targets
    if total > SKIN_RADIUS_MAX_TARGETS then
        local trimmed = {}
        for i = 1, SKIN_RADIUS_MAX_TARGETS do trimmed[i] = targets[i] end
        targets = trimmed
        say(string.format('\xCB\xF3\xF7\xE0 %d \xE8\xE7 %d (\xEB\xE8\xEC\xE8\xF2 %d)', #targets, total, SKIN_RADIUS_MAX_TARGETS))
    end
    skinsStartApplyJob(targets, sid)
end

-- Skins Draw Grid Cell
function skinsDrawGridCell(entry, layout)
    if not entry or not entry.id then return end
    if imgui.PushIDInt then imgui.PushIDInt(entry.id) end
    local selected = (entry.id == skinSelectedId)
    local tw = layout and layout.thumbW or SKIN_THUMB_W
    local th = layout and layout.thumbH or SKIN_THUMB_H
    if selected then
        imgui.PushStyleColor(imgui.Col.Button, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent)
    end
    local tex = skinPeekTexture(entry)
    local okDraw, clicked = skinDrawTextureSafe(
        tex, entry.id, tw, th, true, tostring(entry.id) .. '##sk_' .. entry.id
    )
    if not okDraw then
        clicked = imgui.Button(tostring(entry.id) .. '##sk_' .. entry.id, imgui.ImVec2(tw, th))
    end
    if selected then imgui.PopStyleColor(2) end
    if clicked then skinSelectedId = entry.id end
    if imgui.IsItemHovered() and imgui.SetTooltip then
        imgui.SetTooltip(uiText('ID ' .. entry.id))
    end
    if imgui.PopID then imgui.PopID() end
end

-- Draw Skins Tab
function drawSkinsTab()
    skinsLoadCatalog()
    if not skinsTabSynced then
        skinsSetRadius(tonumber(settings.skin_radius) or 20)
        uiSkinRadius[0] = skinsGetRadius()
        skinsRebuildFilter()
        skinsTabSynced = true
    end

    pushPanelStyle(col_chat_bg)
    imgui.BeginChild('##skins_panel', imgui.ImVec2(-1, -1), true)

    local fileCount = #skinCatalog > 0 and #skinCatalog or skinsCountFiles()
    if fileCount == 0 then
        imgui.TextColored(col_warn, uiText('\xCD\xE5\xF2 \xEA\xE0\xF0\xF2\xE8\xED\xEE\xEA \xF1\xEA\xE8\xED\xEE\xE2.'))
        imgui.TextWrapped(uiText('tools\\download_adv_skins.ps1'))
        imgui.EndChild()
        popPanelStyle()
        return
    end

    if #skinFiltered == 0 then skinsRebuildFilter() end
    local selEntry = skinCatalogById[skinSelectedId]

    local loadedPre, totalPre = skinsPreloadProgress()

    -- Левая панель: крупное превью и выдача
    imgui.BeginChild('##skin_sidebar', imgui.ImVec2(SKIN_SIDEBAR_W, -1), true)
    if selEntry then
        local prevTex = skinPeekTexture(selEntry)
        local pw, ph = deskGrid.fitPreview(SKIN_PREVIEW_W, SKIN_PREVIEW_H, imgui.GetContentRegionAvail().x)
        local okPrev = skinDrawTextureSafe(prevTex, selEntry.id, pw, ph, false, nil)
        if not okPrev then
            imgui.Button('...##skin_prev_ph', imgui.ImVec2(pw, ph))
        end
        imgui.TextColored(col_accent, uiText(string.format('ID %d', skinSelectedId)))
    else
        imgui.TextColored(col_muted, uiText('\xCD\xE5 \xE2\xFB\xE1\xF0\xE0\xED'))
    end
    local skinPending = deskTexPipeline.pendingCount(TEX_NS_SKIN)
    if skinPending > 0 and totalPre > loadedPre and imgui.ProgressBar then
        local frac = math.max(0, math.min(1, loadedPre / totalPre))
        imgui.ProgressBar(frac, imgui.ImVec2(-1, 0), '')
    end
    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextColored(col_muted2, uiText('\xC8\xE3\xF0\xEE\xEA\xE8 (ID \xF7\xE5\xF0\xE5\xE7 \xE7\xE0\xEF\xFF\xF2\xF3\xFE)'))
    imgui.PushItemWidth(-1)
    deskPushFlatInputStyle()
    local skinTargetsChanged = false
    if imgui.InputTextWithHint then
        skinTargetsChanged = imgui.InputTextWithHint(
            '##skin_targets',
            uiText('12, 34, 56'),
            skinTargetBuf,
            sizeof(skinTargetBuf)
        )
    else
        skinTargetsChanged = imgui.InputText('##skin_targets', skinTargetBuf, sizeof(skinTargetBuf))
    end
    deskPopFlatInputStyle()
    imgui.PopItemWidth()
    if skinRadiusJob.active then
        if imgui.Button(uiText('\xCE\xF2\xEC\xE5\xED\xE0') .. '##skin_apply_cancel', imgui.ImVec2(-1, 32)) then
            skinsCancelApplyJob()
        end
    else
        if imgui.Button(uiText('\xC2\xFB\xE4\xE0\xF2\xFC \xEF\xEE \xF1\xEF\xE8\xF1\xEA\xF3') .. '##skin_apply_list', imgui.ImVec2(-1, 32)) then
            skinsApplyToListedTargets()
        end
    end
    imgui.Separator()
    imgui.TextColored(col_muted2, uiText('\xC2 \xF0\xE0\xE4\xE8\xF3\xF1\xE5 (\xEC)'))
    drawSkinRadiusControl()
    imgui.Dummy(imgui.ImVec2(0, 4))
    local nearbyCount = skinRadiusJob.active and 0 or skinsGetNearbyCount()
    if not skinRadiusJob.active then
        if imgui.Button(uiText(string.format('\xC2\xF1\xE5\xEC (%d)', nearbyCount)) .. '##skin_radius_apply', imgui.ImVec2(-1, 28)) then
            skinsApplyInRadius()
        end
    end
    imgui.EndChild()

    imgui.SameLine()

    -- Правая часть: поиск + сетка
    imgui.BeginChild('##skin_main', imgui.ImVec2(-1, -1), true)
    drawDeskSearchClearRow('\xCF\xEE\xE8\xF1\xEA ID \xF1\xEA\xE8\xED\xE0', skinFilterBuf, sizeof(skinFilterBuf),
        skinsRebuildFilter, 'skin')
    imgui.TextColored(col_muted2, uiText(string.format(
        '\xCF\xEE\xEA\xE0\xE7\xE0\xED\xEE: %d',
        #skinFiltered)))

    local gridW = math.floor(deskGrid.contentWidth({ margin = 4 }))
    local layoutSig = tostring(gridW) .. '|' .. #skinFiltered
    if not deskCache.skinGridLayoutCache or deskCache.skinGridLayoutSig ~= layoutSig then
        deskCache.skinGridLayoutSig = layoutSig
        deskCache.skinGridLayoutCache = deskGrid.compute(gridW, SKIN_THUMB_ASPECT, {
            minCols = 2, maxCols = 5, minThumbW = 58, maxThumbW = 132, gap = 8,
        })
    end
    local layout = deskCache.skinGridLayoutCache

    imgui.BeginChild('##skin_grid', imgui.ImVec2(-1, -1), true)
    pcall(deskGrid.drawVirtual, skinFiltered, layout, skinsDrawGridCell, {
        overscanRows = 1,
        onVisible = skinsEnqueueVisible,
    })
    imgui.EndChild()
    imgui.EndChild()

    imgui.EndChild()
    popPanelStyle()
    pcall(deskCatalogTexTick)
end

