--[[ Модуль: спавн транспорта, каталог. ]]
local imgui = require 'mimgui'
local deskGrid = require 'report_desk_catalog_grid'
local deskTexLoad = require 'report_desk_tex_loader'
local deskTexPipeline = require 'report_desk_tex_pipeline'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new, sizeof = imgui.new, ffi.sizeof

local VEH_DIR = getWorkingDirectory() .. '\\res\\report_desk_vehicles\\'
local VEH_OVERRIDE_DIR = VEH_DIR .. 'overrides\\'
local TEX_NS_VEH = 'veh'
local VEH_SIDEBAR_W = 230
local VEH_THUMB_W, VEH_THUMB_H = 118, 72
local VEH_THUMB_ASPECT = VEH_THUMB_H / VEH_THUMB_W
local VEH_PREVIEW_W, VEH_PREVIEW_H = 204, 125

local M = {
    tabActive = false,
}

local vehCatalog, vehCatalogById = nil, {}
local vehSelectedId = 411
local vehFilterBuf = new.char[48]()
local vehFiltered = {}
local vehFilterSig = ''
local vehTabSynced = false
local vehLoadFailLogged = false
local vehGridLayoutCache = nil
local vehGridLayoutSig = ''
local uiVehSpawnCount = new.int(1)

local col_accent = imgui.ImVec4(0.67, 0.33, 1.0, 1.0)
local col_accent_dim = imgui.ImVec4(0.45, 0.22, 0.72, 1.0)
local col_muted = imgui.ImVec4(0.55, 0.55, 0.60, 1.0)
local col_muted2 = imgui.ImVec4(0.42, 0.42, 0.48, 1.0)
local col_warn = imgui.ImVec4(0.95, 0.75, 0.35, 1.0)
local col_chat_bg = imgui.ImVec4(0.05, 0.05, 0.07, 0.98)

local settingsRef, sendChatFn, sayFn, markDirtyFn, deskTex

local function uiText(s)
    if not s then return '' end
    local ok, t = pcall(u8, s)
    return ok and t or s
end

-- Read Buf
local function readBuf(buf)
    if not buf then return '' end
    return ffi.string(buf):gsub('%z.*$', '')
end

-- Публичный API модуля.
function M.texRelease(tex)
    if tex and imgui.ReleaseTexture then pcall(imgui.ReleaseTexture, tex) end
end

-- Публичный API модуля.
function M.releaseTextures()
    if deskTex then
        deskTex.releaseAll(TEX_NS_VEH, M.texRelease, true)
    end
    deskTexLoad.clearNamespace(TEX_NS_VEH)
    deskTexPipeline.requestDeferredFlush()
end

-- Публичный API модуля.
function M.bind(ctx)
    settingsRef = ctx.settings
    sendChatFn = ctx.sendChat
    sayFn = ctx.say
    markDirtyFn = ctx.markDirtySettings
    deskTex = ctx.deskTex
    col_accent = ctx.col_accent or col_accent
    col_accent_dim = ctx.col_accent_dim or col_accent_dim
    col_muted = ctx.col_muted or col_muted
    col_muted2 = ctx.col_muted2 or col_muted2
    col_warn = ctx.col_warn or col_warn
    col_chat_bg = ctx.col_chat_bg or col_chat_bg
end

-- Push Panel
local function pushPanel()
    imgui.PushStyleColor(imgui.Col.ChildBg, col_chat_bg)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.18, 0.18, 0.22, 0.35))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(10, 10))
end

-- Pop Panel
local function popPanel()
    imgui.PopStyleVar(3)
    imgui.PopStyleColor(2)
end

-- Публичный API модуля.
function M.loadCatalog()
    if vehCatalog then return end
    vehCatalog = {}
    vehCatalogById = {}
    local idxPath = VEH_DIR .. 'vehicles_index.lua'
    if doesFileExist(idxPath) then
        local ok, data = pcall(dofile, idxPath)
        if ok and type(data) == 'table' then
            for _, e in ipairs(data) do
                if type(e) == 'table' and e.id then
                    vehCatalog[#vehCatalog + 1] = e
                    vehCatalogById[e.id] = e
                end
            end
        end
    end
    if #vehCatalog == 0 then
        for id = 400, 611 do
            local file
            local ovr = string.format('overrides\\veh-%d.png', id)
            if doesFileExist(VEH_DIR .. ovr) then
                file = ovr
            elseif doesFileExist(VEH_DIR .. string.format('veh-%d.png', id)) then
                file = string.format('veh-%d.png', id)
            elseif doesFileExist(VEH_DIR .. string.format('veh-%d.jpg', id)) then
                file = string.format('veh-%d.jpg', id)
            end
            if file then
                local e = { id = id, file = file, name = 'ID ' .. id }
                vehCatalog[#vehCatalog + 1] = e
                vehCatalogById[id] = e
            end
        end
    end
    table.sort(vehCatalog, function(a, b) return (a.id or 0) < (b.id or 0) end)
end

-- Ensure Ctx
local function ensureCtx()
    if imgui.SwitchContext then pcall(imgui.SwitchContext) end
end

-- Публичный API модуля.
function M.pipelinePathForId(id)
    M.loadCatalog()
    local entry = vehCatalogById[tonumber(id) or id]
    if not entry then return nil end
    local path, lowQ, meta = deskTexLoad.resolveVehPath(VEH_DIR, VEH_OVERRIDE_DIR, entry)
    if not path then return nil end
    if meta then meta.lowQuality = lowQ end
    return path, meta or { lowQuality = lowQ }
end

-- Публичный API модуля.
function M.pipelineOnUploaded(id, meta)
    local entry = vehCatalogById[tonumber(id) or id]
    if entry and meta and meta.lowQuality then
        entry.lowQuality = true
    end
end

-- Peek Tex
local function peekTex(entry)
    if not entry or not deskTex then return nil end
    return deskTex.peek(TEX_NS_VEH, entry.id)
end

-- Mark Dirty
local function markDirty()
    if markDirtyFn then markDirtyFn() end
end

-- Публичный API модуля.
function M.preloadProgress()
    local pending = deskTexPipeline.pendingCount(TEX_NS_VEH)
    local loaded = deskTex and deskTex.count(TEX_NS_VEH) or 0
    return loaded, pending + loaded
end

-- Enqueue Visible
local function enqueueVisible(firstIdx, lastIdx, items)
    if not deskTex then return end
    local ids = {}
    for i = firstIdx, lastIdx do
        local e = items[i]
        if e and e.id then ids[#ids + 1] = e.id end
    end
    deskTexPipeline.syncVisible(TEX_NS_VEH, ids, deskTex, { priority = { vehSelectedId } })
end

-- Публичный API модуля.
function M.onTabEnter()
    M.loadCatalog()
    deskTexPipeline.registerNs(TEX_NS_VEH, {
        pathForId = M.pipelinePathForId,
        releaseFn = M.texRelease,
        onUploaded = M.pipelineOnUploaded,
    })
    deskTexPipeline.activate(TEX_NS_VEH)
end

-- Публичный API модуля.
function M.onTabLeave()
    deskTexPipeline.deactivate(TEX_NS_VEH, deskTex)
    deskTexPipeline.requestDeferredFlush()
end

-- Rebuild Filter
local function rebuildFilter()
    M.loadCatalog()
    local filter = readBuf(vehFilterBuf):lower()
    if filter == vehFilterSig and #vehFiltered > 0 then return end
    vehFilterSig = filter
    vehFiltered = {}
    for _, e in ipairs(vehCatalog) do
        local idStr = tostring(e.id)
        local nameStr = (e.name or ''):lower()
        local catStr = (e.category or ''):lower()
        if filter == '' or idStr:find(filter, 1, true) or nameStr:find(filter, 1, true)
            or catStr:find(filter, 1, true) then
            vehFiltered[#vehFiltered + 1] = e
        end
    end
    vehGridLayoutCache = nil
end

-- Veh Layout For Count
local function vehLayoutForCount(count)
    count = math.max(1, math.min(30, math.floor(tonumber(count) or 1)))
    if count <= 5 then
        return 1, count
    end
    local cols = math.min(5, math.ceil(math.sqrt(count)))
    local rows = math.ceil(count / cols)
    return rows, cols
end

-- Spawn Vehicles
local function spawnVehicles()
    local id = tonumber(vehSelectedId) or 0
    local count = math.max(1, math.min(30, uiVehSpawnCount[0]))
    local rows, cols = vehLayoutForCount(count)
    local c1, c2 = 0, 0
    if id < 400 or id > 611 then
        sayFn('\xCD\xE5\xE2\xE5\xF0\xED\xFB\xE9 ID \xD2\xD1')
        return
    end
    if settingsRef then
        settingsRef.veh_spawn_count = count
        settingsRef.veh_grid_rows = rows
        settingsRef.veh_grid_cols = cols
        markDirty()
    end
    if sendChatFn then
        sendChatFn(string.format('carsp %d %d %d %d %d', rows, cols, id, c1, c2))
        sayFn(string.format('/carsp %d \xF8\xF2. (%dx%d)', count, rows, cols))
    end
end

-- Draw Cell
local function drawCell(entry, layout)
    if not entry or not entry.id then return end
    local tex = peekTex(entry)
    local sel = (entry.id == vehSelectedId)
    local tw = layout and layout.thumbW or VEH_THUMB_W
    local th = layout and layout.thumbH or VEH_THUMB_H
    local thumb = imgui.ImVec2(tw, th)
    if sel then
        imgui.PushStyleColor(imgui.Col.Button, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent)
    end
    local clicked = false
    if tex and deskTex and deskTex.has(TEX_NS_VEH, entry.id) and imgui.ImageButton then
        local ok, res = pcall(imgui.ImageButton, tex, thumb)
        clicked = ok and res
        if not ok then
            local label = entry.lowQuality and (tostring(entry.id) .. '~') or tostring(entry.id)
            clicked = imgui.Button(label .. '##vf_' .. entry.id, thumb)
        end
    else
        local label = entry.lowQuality and (tostring(entry.id) .. '~') or tostring(entry.id)
        clicked = imgui.Button(label .. '##v_' .. entry.id, thumb)
    end
    if sel then imgui.PopStyleColor(2) end
    if clicked then vehSelectedId = entry.id end
    if imgui.IsItemHovered() then
        if imgui.IsMouseDoubleClicked and imgui.IsMouseDoubleClicked(0) then
            vehSelectedId = entry.id
            spawnVehicles()
        end
        if imgui.SetTooltip then
            imgui.SetTooltip(uiText((entry.name or '') .. ' | ID ' .. entry.id))
        end
    end
end

-- Публичный API модуля.
function M.drawTab()
    M.loadCatalog()
    if not vehTabSynced then
        rebuildFilter()
        local n = tonumber(settingsRef and settingsRef.veh_spawn_count)
        if not n or n < 1 then
            local r = tonumber(settingsRef and settingsRef.veh_grid_rows) or 1
            local c = tonumber(settingsRef and settingsRef.veh_grid_cols) or 1
            n = math.max(1, r * c)
        end
        uiVehSpawnCount[0] = math.max(1, math.min(30, math.floor(n)))
        vehTabSynced = true
    end

    pushPanel()
    imgui.BeginChild('##veh_panel', imgui.ImVec2(-1, -1), true)

    if #vehCatalog == 0 then
        imgui.TextColored(col_warn, uiText('\xCD\xE5\xF2 \xEA\xE0\xF0\xF2\xE8\xED\xEE\xEA \xD2\xD1.'))
        imgui.TextWrapped(uiText('tools\\VEHICLE_ASSETS.md'))
        imgui.EndChild()
        popPanel()
        return
    end

    if #vehFiltered == 0 then rebuildFilter() end
    local sel = vehCatalogById[vehSelectedId]
    local loadedPre, totalPre = M.preloadProgress()

    imgui.BeginChild('##veh_side', imgui.ImVec2(VEH_SIDEBAR_W, -1), true)
    if sel then
        local tex = peekTex(sel)
        local pw, ph = deskGrid.fitPreview(VEH_PREVIEW_W, VEH_PREVIEW_H, imgui.GetContentRegionAvail().x)
        if tex and deskTex and deskTex.has(TEX_NS_VEH, sel.id) and imgui.Image then
            pcall(imgui.Image, tex, imgui.ImVec2(pw, ph))
        else
            imgui.Button('...##veh_ph', imgui.ImVec2(pw, ph))
        end
        imgui.TextColored(col_accent, uiText(sel.name or ''))
        imgui.TextColored(col_muted2, uiText('ID ' .. sel.id))
        if sel.lowQuality then
            imgui.TextColored(col_warn, uiText('\xCD\xE8\xE7\xEA. \xEA\xE0\xF7\xE5\xF1\xF2\xE2\xEE \x97 \xE7\xE0\xEC\xE5\xED\xE8\xF2\xE5 PNG'))
        end
        if sel.category and sel.category ~= '' then
            imgui.TextColored(col_muted, uiText(sel.category))
        end
    end
    local vehPending = deskTexPipeline.pendingCount(TEX_NS_VEH)
    if vehPending > 0 and totalPre > loadedPre and imgui.ProgressBar then
        local frac = math.max(0, math.min(1, loadedPre / totalPre))
        imgui.ProgressBar(frac, imgui.ImVec2(-1, 0), '')
    end
    imgui.Separator()
    imgui.TextColored(col_muted2, uiText('\xCA\xEE\xEB\xE8\xF7\xE5\xF1\xF2\xE2\xEE'))
    imgui.PushItemWidth(-1)
    if imgui.InputInt('##veh_count', uiVehSpawnCount) then
        uiVehSpawnCount[0] = math.max(1, math.min(30, uiVehSpawnCount[0]))
        if settingsRef then settingsRef.veh_spawn_count = uiVehSpawnCount[0]; markDirty() end
    end
    imgui.PopItemWidth()
    if imgui.Button(uiText(string.format('\xD1\xEF\xE0\xE2\xED\xE8\xF2\xFC (%d \xF8\xF2.)', uiVehSpawnCount[0])) .. '##veh_spawn', imgui.ImVec2(-1, 34)) then
        spawnVehicles()
    end
    imgui.EndChild()

    imgui.SameLine()
    imgui.BeginChild('##veh_main', imgui.ImVec2(-1, -1), true)
    if drawDeskSearchClearRow then
        drawDeskSearchClearRow('\xCF\xEE\xE8\xF1\xEA \xD2\xD1', vehFilterBuf, sizeof(vehFilterBuf),
            rebuildFilter, 'veh')
    else
        imgui.PushItemWidth(-90)
        if imgui.InputText(uiText('\xCF\xEE\xE8\xF1\xEA') .. '##veh_f', vehFilterBuf, sizeof(vehFilterBuf)) then
            rebuildFilter()
        end
        imgui.PopItemWidth()
        imgui.SameLine(0, 8)
        if imgui.Button(uiText('\xCE\xF7\xE8\xF1\xF2\xE8\xF2\xFC') .. '##veh_clr', imgui.ImVec2(86, 28)) then
            ffi.fill(vehFilterBuf, sizeof(vehFilterBuf))
            rebuildFilter()
        end
    end
    imgui.TextColored(col_muted2, uiText(string.format(
        '\xCF\xEE\xEA\xE0\xE7\xE0\xED\xEE: %d',
        #vehFiltered)))

    local gridW = math.floor(deskGrid.contentWidth({ margin = 4 }))
    local layoutSig = tostring(gridW) .. '|' .. #vehFiltered
    if not vehGridLayoutCache or vehGridLayoutSig ~= layoutSig then
        vehGridLayoutSig = layoutSig
        vehGridLayoutCache = deskGrid.compute(gridW, VEH_THUMB_ASPECT, {
            minCols = 2, maxCols = 5, minThumbW = 88, maxThumbW = 200, gap = 8,
        })
    end
    local layout = vehGridLayoutCache

    imgui.BeginChild('##veh_grid', imgui.ImVec2(-1, -1), true)
    pcall(deskGrid.drawVirtual, vehFiltered, layout, drawCell, {
        overscanRows = 1,
        onVisible = enqueueVisible,
    })
    imgui.EndChild()
    imgui.EndChild()

    imgui.EndChild()
    popPanel()
    pcall(deskCatalogTexTick)
end

-- Публичный API модуля.
function M.preloadDone()
    return deskTexPipeline.pendingCount(TEX_NS_VEH) == 0
end

return M
