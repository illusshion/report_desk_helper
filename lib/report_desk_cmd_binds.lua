--[[ Модуль: чат-команды /cmd id → /ans id текст (как ARP Helper). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local CMD_BIND_RESERVED = {
    ans = true, adesk = true, reportdesk = true, hist = true, iget = true, ilog = true, iskill = true,
    warnlast = true, banlast = true, jaillast = true, mutelast = true,
    acar = true, guns = true,
    helper = true, sp = true, st = true, admins = true, adms = true, leaders = true,
    deskupdate = true, deskrepair = true, reload = true, r = true,
    c = true, cc = true, me = true, b = true, w = true, f = true, g = true,
    time = true,
}

local DEFAULT_CMD_BINDS = {
    {
        cmd = 'atir',
        text = '\xD2\xE8\xF0 \xED\xE0\xF5\xEE\xE4\xE8\xF2\xF1\xFF \xEF\xEE GPS 7 - 2',
        enabled = true,
    },
}

cmdBindSelected = 1
cmdBindUiSynced = false
cmdBindEditorDirty = false
local cmdBindRegistered = {}
local cmdBindStatusMsg = ''
local cmdBindStatusUntil = 0
local editCmdBindCmd = new.char[32]()
local editCmdBindText = new.char[512]()
local editCmdBindEnabled = new.bool(true)

-- Default Cmd Binds
function defaultCmdBinds()
    local out = {}
    for i, e in ipairs(DEFAULT_CMD_BINDS) do
        out[i] = { cmd = e.cmd, text = e.text, enabled = e.enabled ~= false }
    end
    return out
end

-- Normalize Cmd Bind
function normalizeCmdBind(raw, fromUtf8)
    if type(raw) ~= 'table' then return nil end
    fromUtf8 = fromUtf8 or raw._utf8
    local cmd = trim(tostring(raw.cmd or '')):lower()
    local text = trim(normalizeStoredText(raw.text or '', fromUtf8))
    if cmd == '' or text == '' then return nil end
    if CMD_BIND_RESERVED[cmd] then return nil end
    if not cmd:match('^[%w_]+$') then return nil end
    return { cmd = cmd, text = text, enabled = raw.enabled ~= false }
end

-- Clone Cmd Binds
function cloneCmdBinds(list)
    local out = {}
    for i, raw in ipairs(list or {}) do
        local e = normalizeCmdBind(raw, raw._utf8)
        if e then out[#out + 1] = e end
    end
    return out
end

-- Ensure Cmd Binds
function ensureCmdBinds()
    if type(settings.cmd_binds) ~= 'table' then
        settings.cmd_binds = defaultCmdBinds()
        return
    end
    if #settings.cmd_binds == 0 then
        settings.cmd_binds = defaultCmdBinds()
        return
    end
    local out = cloneCmdBinds(settings.cmd_binds)
    if #out == 0 then
        settings.cmd_binds = defaultCmdBinds()
        return
    end
    settings.cmd_binds = out
end

-- Find Cmd Bind By Name
function findCmdBindByName(cmdName)
    ensureCmdBinds()
    cmdName = trim(tostring(cmdName or '')):lower()
    for _, entry in ipairs(settings.cmd_binds) do
        if entry.cmd == cmdName then return entry end
    end
end

-- Parse Cmd Bind Player Id
function parseCmdBindPlayerId(arg)
    if not arg or arg == '' then return nil end
    return tonumber(arg:match('(%d+)'))
end

-- Cmd Bind Set Status
function cmdBindSetStatus(msg)
    cmdBindStatusMsg = msg or ''
    cmdBindStatusUntil = os.clock() + 4
end

-- Cmd Bind Is Valid Name
function cmdBindIsValidName(cmd)
    cmd = trim(tostring(cmd or '')):lower()
    if cmd == '' then return false end
    if CMD_BIND_RESERVED[cmd] then return false end
    return cmd:match('^[%w_]+$') ~= nil
end

-- Cmd Bind Is Duplicate
function cmdBindIsDuplicate(idx, cmd)
    ensureCmdBinds()
    cmd = trim(cmd):lower()
    for i, e in ipairs(settings.cmd_binds) do
        if i ~= idx and e.cmd == cmd then return true end
    end
    return false
end

-- Run Cmd Bind
function runCmdBind(entry, arg)
    if not entry then return end
    if not entry.enabled then
        say('\xCA\xEE\xEC\xE0\xED\xE4\xE0 \xEE\xF2\xEA\xEB\xFE\xF7\xE5\xED\xE0.')
        return
    end
    local id = parseCmdBindPlayerId(arg)
    if not id then
        say(string.format('\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xEE\xE2\xE0\xED\xE8\xE5: /%s [id]', entry.cmd))
        return
    end
    local text = expandTemplate(entry.text, id)
    local thread = type(findThreadByPlayerId) == 'function' and findThreadByPlayerId(id) or nil
    if thread and type(transmitAnsWire) == 'function' then
        transmitAnsWire(id, text, { thread = thread, threadKey = threadStorageKey(thread) })
        return
    end
    if type(transmitAnsWire) == 'function' then
        transmitAnsWire(id, text, {})
        return
    end
    sendChat(string.format('ans %d %s', id, text))
end

-- Register one chat command bind (MoonLoader cannot unregister; new names register on rename).
local function registerOneCmdBind(name)
    name = trim(tostring(name or '')):lower()
    if name == '' or cmdBindRegistered[name] then return false end
    cmdBindRegistered[name] = true
    sampRegisterChatCommand(name, function(arg)
        runCmdBind(findCmdBindByName(name), arg)
    end)
    return true
end

-- Register Cmd Binds
function registerCmdBinds()
    ensureCmdBinds()
    for _, entry in ipairs(settings.cmd_binds) do
        registerOneCmdBind(entry.cmd)
    end
end

-- Init Cmd Binds
function initCmdBinds()
    ensureCmdBinds()
    registerCmdBinds()
end

-- Fill Cmd Bind Editor
function fillCmdBindEditor(idx)
    ensureCmdBinds()
    local e = settings.cmd_binds[idx]
    if not e then return end
    setInputBuf(editCmdBindCmd, e.cmd or '')
    setInputBuf(editCmdBindText, e.text or '')
    editCmdBindEnabled[0] = e.enabled ~= false
    cmdBindEditorDirty = false
end

-- Apply Cmd Bind Editor
function applyCmdBindEditor()
    ensureCmdBinds()
    if cmdBindSelected < 1 or cmdBindSelected > #settings.cmd_binds then return false end
    local entry = settings.cmd_binds[cmdBindSelected]
    local cmd = trim(readInputBuf(editCmdBindCmd)):lower()
    local text = readInputBuf(editCmdBindText)
    if not cmdBindIsValidName(cmd) then
        cmdBindSetStatus('\xCD\xE5\xE2\xE5\xF0\xED\xEE\xE5 \xE8\xEC\xFF \xEA\xEE\xEC\xE0\xED\xE4\xFB (\xEB\xE0\xF2\xE8\xED\xE8\xF6\xE0, \xF6\xE8\xF4\xF0\xFB, _)')
        return false
    end
    if cmdBindIsDuplicate(cmdBindSelected, cmd) then
        cmdBindSetStatus('\xCA\xEE\xEC\xE0\xED\xE4\xE0 \xF3\xE6\xE5 \xE5\xF1\xF2\xFC')
        return false
    end
    if trim(text) == '' then
        cmdBindSetStatus('\xD2\xE5\xEA\xF1\xF2 \xED\xE5 \xEC\xEE\xE6\xE5\xF2 \xE1\xFB\xF2\xFC \xEF\xF3\xF1\xF2\xFB\xEC')
        return false
    end
    local prevCmd = trim(tostring(entry.cmd or '')):lower()
    settings.cmd_binds[cmdBindSelected] = {
        cmd = cmd,
        text = text,
        enabled = editCmdBindEnabled[0],
    }
    if cmd ~= prevCmd then
        registerOneCmdBind(cmd)
    end
    markDirtySettings()
    cmdBindEditorDirty = false
    return true
end

-- Flush Cmd Bind Editor
function flushCmdBindEditor()
    if not cmdBindEditorDirty then return end
    applyCmdBindEditor()
end

-- Sync Cmd Bind Editor If Dirty
function syncCmdBindEditorIfDirty()
    if not cmdBindEditorDirty then return end
    if #settings.cmd_binds < 1 then
        cmdBindEditorDirty = false
        return
    end
    applyCmdBindEditor()
end

-- Draw Cmd Bind Edit Panel
function drawCmdBindEditPanel()
    local cmdRowW = math.max(120, imgui.GetContentRegionAvail().x - 18)
    imgui.TextColored(col_muted, '/')
    imgui.SameLine(0, 4)
    imgui.PushItemWidth(cmdRowW)
    if imgui.InputText('##cmd_bind_name', editCmdBindCmd, sizeof(editCmdBindCmd)) then
        cmdBindEditorDirty = true
    end
    if imguiItemEdited() then cmdBindEditorDirty = true end
    imgui.PopItemWidth()

    if deskFormToggleRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xE0', editCmdBindEnabled, function()
        cmdBindEditorDirty = true
        flushCmdBindEditor()
    end, 'cmd_bind_en') then end

    drawSettingsSubsection('\xD2\xE5\xEA\xF1\xF2 \xEE\xF2\xE2\xE5\xF2\xE0')
    imgui.PushItemWidth(-1)
    if imgui.InputTextMultiline('##cmd_bind_text', editCmdBindText, sizeof(editCmdBindText), imgui.ImVec2(-1, 200)) then
        cmdBindEditorDirty = true
    end
    if imguiItemEdited() then cmdBindEditorDirty = true end
    imgui.PopItemWidth()

    if cmdBindStatusMsg ~= '' and os.clock() < cmdBindStatusUntil then
        imgui.TextColored(col_accent, uiText(cmdBindStatusMsg))
    end

    imgui.Dummy(imgui.ImVec2(0, 10))
    if imgui.Button(uiText('\xD1\xEE\xF5\xF0\xE0\xED\xE8\xF2\xFC'), imgui.ImVec2(-1, 28)) then
        if applyCmdBindEditor() then
            flushDirtyConfigNow()
            registerCmdBinds()
            cmdBindSetStatus('\xD1\xEE\xF5\xF0\xE0\xED\xE5\xED\xEE')
        end
    end
    if imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC \xEA\xEE\xEC\xE0\xED\xE4\xF3'), imgui.ImVec2(-1, 28)) then
        flushCmdBindEditor()
        if cmdBindSelected >= 1 and cmdBindSelected <= #settings.cmd_binds then
            table.remove(settings.cmd_binds, cmdBindSelected)
            if cmdBindSelected > #settings.cmd_binds then cmdBindSelected = #settings.cmd_binds end
            if cmdBindSelected < 1 then cmdBindSelected = 1 end
            if #settings.cmd_binds > 0 then fillCmdBindEditor(cmdBindSelected) end
            markDirtySettings()
            flushDirtyConfigNow()
            cmdBindSetStatus('\xD3\xE4\xE0\xEB\xE5\xED\xEE')
        end
    end
end

-- Draw Cmd Binds Tab Inner
function drawCmdBindsTabInner()
    ensureCmdBinds()
    pushPanelStyle()
    imgui.BeginChild('##cmd_bind_list', imgui.ImVec2(DESK_EDITOR_LIST_W, -1), true)
    if imgui.Button(uiText('+ \xCA\xEE\xEC\xE0\xED\xE4\xE0'), imgui.ImVec2(-1, 28)) then
        flushCmdBindEditor()
        local n = #settings.cmd_binds + 1
        settings.cmd_binds[n] = {
            cmd = 'new' .. tostring(n),
            text = '\xD2\xE5\xEA\xF1\xF2 \xEE\xF2\xE2\xE5\xF2\xE0',
            enabled = true,
        }
        cmdBindSelected = n
        fillCmdBindEditor(n)
        markDirtySettings()
    end
    imgui.Dummy(imgui.ImVec2(0, 6))
    for i, row in ipairs(settings.cmd_binds) do
        local name = trim(row.cmd or '')
        if name == '' then name = '?' end
        local label = '/' .. name .. (row.enabled and '' or ' (off)')
        if drawEditorListSelectable(label, '##cmdb' .. i, cmdBindSelected == i) then
            if cmdBindSelected ~= i then
                flushCmdBindEditor()
                cmdBindSelected = i
                fillCmdBindEditor(i)
            end
        end
    end
    imgui.EndChild()
    popPanelStyle()

    imgui.SameLine()
    pushPanelStyle(col_chat_bg)
    imgui.BeginChild('##cmd_bind_edit', imgui.ImVec2(0, -1), true)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 8))
    if #settings.cmd_binds == 0 then
        imgui.Dummy(imgui.ImVec2(0, 24))
        imgui.TextColored(col_muted, uiText('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 + \xCA\xEE\xEC\xE0\xED\xE4\xE0'))
    else
        drawCmdBindEditPanel()
    end
    imgui.PopStyleVar(2)
    imgui.EndChild()
    popPanelStyle()
end

-- Draw Cmd Binds Tab
function drawCmdBindsTab()
    if not cmdBindUiSynced then
        ensureCmdBinds()
        if cmdBindSelected < 1 then cmdBindSelected = 1 end
        if cmdBindSelected > #settings.cmd_binds then
            cmdBindSelected = math.max(1, #settings.cmd_binds)
        end
        if #settings.cmd_binds > 0 then fillCmdBindEditor(cmdBindSelected) end
        cmdBindUiSynced = true
    end
    local ok, err = pcall(drawCmdBindsTabInner)
    syncCmdBindEditorIfDirty()
    if not ok then
        imgui.TextColored(col_warn, 'Cmd binds UI error:')
        imgui.TextWrapped(tostring(err))
        print('[Report Desk] cmd binds UI: ' .. tostring(err))
    end
end
