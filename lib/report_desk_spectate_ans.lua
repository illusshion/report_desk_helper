--[[ Модуль: быстрый /ans bar в spectate (клавиша C). ]]
local M = {}

local ffi = require 'ffi'
local imgui = require 'mimgui'
local spTheme = require 'report_desk_sp_theme'

local deps = {}
local ANS_BUF_SIZE = 384
local ansBuf = imgui.new.char[ANS_BUF_SIZE]()
local state = {
    open = false,
    focusPending = false,
    openedAt = 0,
    hovered = false,
}

local BAR_W = 460
local BAR_H = 92
local BAR_BOTTOM_INSET = 28
local CHAT_KEY_DEBOUNCE_SEC = 0.22
local OPEN_CLICK_GRACE_SEC = 0.18
local OPEN_INPUT_GRACE_SEC = 0.28
local lastChatKeyAt = 0
local WM_KEYDOWN = 0x0100
local WM_SYSKEYDOWN = 0x0104
local WM_KEYUP = 0x0101
local WM_SYSKEYUP = 0x0105
local WM_CHAR = 0x0102

local SAMP_CHAT_KEYS = {
    [0x54] = true, [0x49] = true, [0x59] = true, [0x42] = true,
    [0x4F] = true, [0x50] = true, [0x4E] = true, [0xC0] = true,
    [0x75] = true, [0x7A] = true,
}

-- Block Samp Chat Key
local function blockSampChatKey(msg, wparam)
    if not state.open then return false end
    msg = tonumber(msg) or 0
    if msg == WM_CHAR or msg == 0x0106 or msg == 0x0109 or msg == 0x0286 then
        return true
    end
    if msg == WM_KEYDOWN or msg == WM_SYSKEYDOWN or msg == WM_KEYUP or msg == WM_SYSKEYUP then
        if SAMP_CHAT_KEYS[tonumber(wparam) or 0] then
            return true
        end
    end
    return false
end

-- Is Key Repeat
local function isKeyRepeat(lparam)
    lparam = tonumber(lparam) or 0
    if bit and bit.band then
        return bit.band(lparam, 0x40000000) ~= 0
    end
    return false
end

-- Chat Key Vk
local function chatKeyVk()
    local vkeys = deps.vkeys or {}
    return vkeys.VK_C or 0x43
end

-- Chat Key Down
local function chatKeyDown()
    if not deps.isVkDown then return false end
    return deps.isVkDown(chatKeyVk()) == true
end

-- Is Chat Key
local function isChatKey(wparam)
    wparam = tonumber(wparam) or 0
    return wparam == chatKeyVk()
end

-- Modifier Blocks Chat
local function modifierBlocksChat()
    if not deps.isVkDown or not deps.vkeys then return false end
    local v = deps.vkeys
    if deps.isVkDown(v.VK_CONTROL or 0x11) then return true end
    if deps.isVkDown(v.VK_LCONTROL or 0xA2) then return true end
    if deps.isVkDown(v.VK_RCONTROL or 0xA3) then return true end
    return false
end

-- Open Grace Active
local function openGraceActive()
    return (os.clock() - (state.openedAt or 0)) < OPEN_INPUT_GRACE_SEC
end

-- Open Chat Debounced
local function openChatDebounced()
    local now = os.clock()
    if state.open then return false end
    if now - lastChatKeyAt < CHAT_KEY_DEBOUNCE_SEC then return false end
    if M.open() then
        lastChatKeyAt = now
        return true
    end
    return false
end

local function trim(s)
    if deps.trim then return deps.trim(s) end
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

local function uiText(s)
    if deps.uiText then return deps.uiText(s) end
    return s or ''
end

-- Screen Size
local function screenSize()
    local sw, sh = 1280, 720
    if imgui.GetIO then
        local io = imgui.GetIO()
        if io and io.DisplaySize and io.DisplaySize.x > 0 then
            sw = io.DisplaySize.x
            sh = io.DisplaySize.y
        end
    end
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    return sw, sh
end

-- Spectating With Target
local function spectatingWithTarget()
    local id = deps.getTargetId and tonumber(deps.getTargetId()) or -1
    if id < 0 then return false end
    if deps.isSpectating then
        local ok, v = pcall(deps.isSpectating)
        if ok and v then return true end
    end
    if deps.getPlayerSpectating then
        local ok, v = pcall(deps.getPlayerSpectating)
        if ok and v then return true end
    end
    return true
end

-- Input Blocked
local function inputBlocked()
    if deps.isGameTextInputActive and deps.isGameTextInputActive() then return true end
    if deps.isDeskTypingActive and deps.getShowWindow and deps.getShowWindow()
            and deps.isDeskTypingActive() then
        return true
    end
    return false
end

-- Notify Input Changed
local function notifyInputChanged()
    if deps.onInputChanged then pcall(deps.onInputChanged) end
end

-- Release Input Capture
local function releaseInputCapture()
    if type(deskReleaseImguiCapture) == 'function' then
        pcall(deskReleaseImguiCapture)
    else
        if imgui.CaptureKeyboardFromApp then pcall(imgui.CaptureKeyboardFromApp, false) end
        if imgui.CaptureMouseFromApp then pcall(imgui.CaptureMouseFromApp, false) end
    end
    if deps.updateInputPassthrough then pcall(deps.updateInputPassthrough) end
end

-- Sync Input Capture
local function syncInputCapture()
    if not state.open then return end
    local io = imgui.GetIO and imgui.GetIO()
    if not io then return end
    local wantKb = io.WantCaptureKeyboard or io.WantTextInput
    if imgui.IsAnyItemActive and imgui.IsAnyItemActive() then wantKb = true end
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(wantKb) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(true) end
end

-- Публичный API модуля.
function M.isOpen()
    return state.open == true
end

-- Публичный API модуля.
function M.wantsInput()
    return state.open == true
end

-- Публичный API модуля.
function M.close()
    if not state.open then return end
    state.open = false
    state.focusPending = false
    state.hovered = false
    if type(deskInputState) == 'table' then
        deskInputState.keyboardStickyUntil = 0
    end
    releaseInputCapture()
    notifyInputChanged()
end

-- Публичный API модуля.
function M.reset()
    M.close()
    ansBuf[0] = 0
end

-- Публичный API модуля.
function M.open()
    if not spectatingWithTarget() or inputBlocked() then return false end
    state.open = true
    state.openedAt = os.clock()
    state.focusPending = true
    if type(deskHoldSampChatInput) == 'function' then
        pcall(deskHoldSampChatInput)
    end
    if deps.markTypingActive then pcall(deps.markTypingActive) end
    notifyInputChanged()
    if deps.enableSpectateCursor then pcall(deps.enableSpectateCursor) end
    return true
end

-- Read Ans Buf
local function readAnsBuf()
    if deps.readInputBuf then
        local ok, s = pcall(deps.readInputBuf, ansBuf)
        if ok and s then return trim(s) end
    end
    local ok, s = pcall(function()
        return ffi.string(ansBuf):match('^[^%z]*') or ''
    end)
    s = ok and trim(s) or ''
    if deps.utf8ToCp1251 then
        local ok2, out = pcall(deps.utf8ToCp1251, s)
        if ok2 and out then return out end
    end
    return s
end

-- Отправка команды/сообщения на сервер.
local function sendAns(text)
    if text == nil or text == '' then
        text = readAnsBuf()
    else
        text = trim(text)
        if deps.utf8ToCp1251 then
            local ok, out = pcall(deps.utf8ToCp1251, text)
            if ok and out then text = out end
        end
    end
    if text == '' then
        M.close()
        return false
    end
    local id = deps.getTargetId and tonumber(deps.getTargetId()) or -1
    if id < 0 then return false end
    if deps.transmitAns then
        pcall(deps.transmitAns, id, text)
    elseif deps.sendMenuOutbound then
        pcall(deps.sendMenuOutbound, 'ans ' .. tostring(id) .. ' ' .. text)
    elseif deps.sendChat then
        pcall(deps.sendChat, 'ans ' .. tostring(id) .. ' ' .. text)
    else
        return false
    end
    ansBuf[0] = 0
    M.close()
    return true
end

-- Публичный API модуля.
function M.handleWindowMessage(msg, wparam, lparam)
    if not spectatingWithTarget() or inputBlocked() then return false end
    if blockSampChatKey(msg, wparam) then return true end
    if msg ~= WM_KEYDOWN and msg ~= WM_SYSKEYDOWN then return false end
    if isKeyRepeat(lparam) then return false end

    local vkeys = deps.vkeys
    if not vkeys then return false end
    wparam = tonumber(wparam) or 0
    local vkEnter = vkeys.VK_RETURN or 0x0D

    if state.open then
        if wparam == (vkeys.VK_ESCAPE or 0x1B) then
            M.close()
            return true
        end
        if wparam == vkEnter and openGraceActive() then
            return true
        end
        return false
    end

    if not isChatKey(wparam) or modifierBlocksChat() then return false end
    if openChatDebounced() then
        return true
    end
    return false
end

-- Публичный API модуля.
function M.draw(settings)
    if not state.open or not spectatingWithTarget() then
        state.hovered = false
        return
    end
    settings = settings or (deps.getSettings and deps.getSettings()) or {}
    if settings.spectate_sp_ans == false then
        M.close()
        return
    end

    local targetId = tonumber(deps.getTargetId and deps.getTargetId()) or -1
    if targetId < 0 then
        M.close()
        return
    end

    local nick = ''
    if deps.getTargetNick then
        local ok, nk = pcall(deps.getTargetNick)
        if ok and nk then nick = trim(nk) end
    end
    if nick == '' and deps.sampGetPlayerNickname and deps.sampIsPlayerConnected then
        pcall(function()
            if deps.sampIsPlayerConnected(targetId) then
                nick = trim(deps.sampGetPlayerNickname(targetId) or '')
            end
        end)
    end

    local col_accent = deps.col_accent or imgui.ImVec4(0.62, 0.44, 0.86, 1.0)
    local col_accent_dim = deps.col_accent_dim or imgui.ImVec4(0.52, 0.36, 0.78, 1.0)
    local col_muted2 = deps.col_muted2 or imgui.ImVec4(0.55, 0.55, 0.62, 0.85)
    local col_label = deps.col_label or imgui.ImVec4(0.95, 0.95, 0.98, 1.0)

    local sw, sh = screenSize()
    local posX = math.max(8, (sw - BAR_W) * 0.5)
    local posY = math.max(8, sh - BAR_H - BAR_BOTTOM_INSET)

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoMove
        + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoCollapse

    imgui.SetNextWindowBgAlpha(0.96)
    imgui.SetNextWindowSize(imgui.ImVec2(BAR_W, BAR_H), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Always)

    spTheme.pushOverlayChrome(0.96)
    local began = imgui.Begin('###desk_sp_ans_bar', nil, flags)
    if began then
        state.hovered = false
        pcall(function()
            local wp = imgui.GetWindowPos()
            local ww = imgui.GetWindowWidth()
            local wh = imgui.GetWindowHeight()
            local mp = imgui.GetIO().MousePos
            state.hovered = mp.x >= wp.x and mp.x < wp.x + ww and mp.y >= wp.y and mp.y < wp.y + wh
        end)

        spTheme.drawHeaderAccent(col_accent)

        local who = nick ~= '' and nick or ('ID ' .. tostring(targetId))
        imgui.TextColored(col_muted2, uiText('\xCE\xF2\xE2\xE5\xF2 \xE2'))
        imgui.SameLine(0, 4)
        imgui.TextColored(col_label, uiText(who))
        imgui.SameLine(0, 4)
        imgui.TextColored(col_muted2, uiText('[' .. tostring(targetId) .. ']'))
        imgui.SameLine(0, 8)
        imgui.TextColored(imgui.ImVec4(0.45, 0.45, 0.52, 0.75), uiText('Enter / Esc'))

        imgui.Dummy(imgui.ImVec2(0, 6))

        if state.focusPending and imgui.SetKeyboardFocusHere then
            imgui.SetKeyboardFocusHere(0)
            state.focusPending = false
        end

        local inputFlags = 0
        if imgui.InputTextFlags and imgui.InputTextFlags.EnterReturnsTrue then
            inputFlags = imgui.InputTextFlags.EnterReturnsTrue
        end

        local sendW = 84
        local gap = 8
        local inputW = math.max(140, imgui.GetContentRegionAvail().x - sendW - gap)

        imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 8))
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
        imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08, 0.08, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.48, 0.36, 0.72, 0.55))
        imgui.PushStyleColor(imgui.Col.Text, col_label)

        imgui.PushItemWidth(inputW)
        local submitted = false
        local hint = uiText('\xD1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5 \xE4\xEB\xFF /ans...')
        if imgui.InputTextWithHint then
            submitted = imgui.InputTextWithHint(
                '##sp_ans_input',
                hint,
                ansBuf,
                ANS_BUF_SIZE,
                inputFlags)
        else
            submitted = imgui.InputText('##sp_ans_input', ansBuf, ANS_BUF_SIZE, inputFlags)
        end
        imgui.PopItemWidth()

        if imgui.IsItemActive and imgui.IsItemActive() then
            state.hovered = true
        end

        imgui.PopStyleColor(3)
        imgui.PopStyleVar(2)

        imgui.SameLine(0, gap)
        imgui.PushStyleColor(imgui.Col.Button, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent)
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.44, 0.30, 0.66, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
        local clicked = imgui.Button(uiText('\xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC'), imgui.ImVec2(sendW, 0))
        imgui.PopStyleColor(4)

        local inputGraceOver = not openGraceActive()
        if inputGraceOver and (submitted or clicked) then
            sendAns()
        end

        local graceOver = (os.clock() - (state.openedAt or 0)) >= OPEN_CLICK_GRACE_SEC
        if graceOver and imgui.IsMouseClicked and imgui.IsMouseClicked(0)
                and not state.hovered and not (imgui.IsAnyItemActive and imgui.IsAnyItemActive()) then
            M.close()
        end

        syncInputCapture()
        imgui.End()
    end
    spTheme.popOverlayChrome()
end

-- Публичный API модуля.
function M.install(installDeps)
    if type(installDeps) == 'table' then
        for k, v in pairs(installDeps) do
            deps[k] = v
        end
    end
end

return M
