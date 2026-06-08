--[[ Модуль: быстрый /ans bar в spectate (клавиша C). ]]
local M = {}

local ffi = require 'ffi'
local imgui = require 'mimgui'
local spTheme = require 'report_desk_sp_theme'

local deps = {}
local ANS_BUF_SIZE = 384
local ansBuf = imgui.new.char[ANS_BUF_SIZE]()

-- Полный цикл KEYDOWN/KEYUP для C и Enter; без os.clock/debounce/grace.
local state = {
    open = false,
    focusPending = false,
    waitChatRelease = false,
    waitEnterRelease = false,
}

local BAR_W = 460
local BAR_H = 92
local BAR_BOTTOM_INSET = 28

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

local function resetKeyLatch()
    state.waitChatRelease = false
    state.waitEnterRelease = false
    state.focusPending = false
end

-- Только SAMP chat hotkeys (T/I/Y/…); WM_CHAR не трогаем — его нужен mimgui InputText.
local function blockSampChatHotkey(msg, wparam)
    if not state.open then return false end
    msg = tonumber(msg) or 0
    if msg ~= WM_KEYDOWN and msg ~= WM_SYSKEYDOWN then return false end
    return SAMP_CHAT_KEYS[tonumber(wparam) or 0] == true
end

-- Пока C не отпущена после открытия — не пускаем WM_CHAR в ImGui (остаток от клавиши C).
local function blockOpeningKeyLeak(msg)
    if not state.open or not state.waitChatRelease then return false end
    msg = tonumber(msg) or 0
    return msg == WM_CHAR
end

local function isKeyDownMsg(msg)
    msg = tonumber(msg) or 0
    return msg == WM_KEYDOWN or msg == WM_SYSKEYDOWN
end

local function isKeyUpMsg(msg)
    msg = tonumber(msg) or 0
    return msg == WM_KEYUP or msg == WM_SYSKEYUP
end

local function isKeyRepeat(lparam)
    lparam = tonumber(lparam) or 0
    if bit and bit.band then
        return bit.band(lparam, 0x40000000) ~= 0
    end
    return false
end

local function chatKeyVk()
    local vkeys = deps.vkeys or {}
    return vkeys.VK_C or 0x43
end

local function isChatKey(wparam)
    return (tonumber(wparam) or 0) == chatKeyVk()
end

local function isEnterKey(wparam)
    wparam = tonumber(wparam) or 0
    local vkeys = deps.vkeys or {}
    return wparam == (vkeys.VK_RETURN or 0x0D) or wparam == 0x0D
end

local function modifierBlocksChat()
    if not deps.isVkDown or not deps.vkeys then return false end
    local v = deps.vkeys
    if deps.isVkDown(v.VK_CONTROL or 0x11) then return true end
    if deps.isVkDown(v.VK_LCONTROL or 0xA2) then return true end
    if deps.isVkDown(v.VK_RCONTROL or 0xA3) then return true end
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

local function inputBlocked()
    if deps.isGameTextInputActive and deps.isGameTextInputActive() then return true end
    if deps.isDeskTypingActive and deps.getShowWindow and deps.getShowWindow()
            and deps.isDeskTypingActive() then
        return true
    end
    return false
end

local function notifyInputChanged()
    if deps.onInputChanged then pcall(deps.onInputChanged) end
end

local function releaseInputCapture()
    if type(deskReleaseImguiCapture) == 'function' then
        pcall(deskReleaseImguiCapture)
    else
        if imgui.CaptureKeyboardFromApp then pcall(imgui.CaptureKeyboardFromApp, false) end
        if imgui.CaptureMouseFromApp then pcall(imgui.CaptureMouseFromApp, false) end
    end
    if deps.updateInputPassthrough then pcall(deps.updateInputPassthrough) end
end

local function syncInputCapture()
    if not state.open then return end
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(true) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

-- KEYUP C иногда не доходит до lua-хендлера; дублируем через isVkDown в draw.
local function chatKeyReleased()
    if not deps.isVkDown then return true end
    local ok, down = pcall(deps.isVkDown, chatKeyVk())
    if not ok then return true end
    return down ~= true
end

local function armInputFocus()
    state.waitChatRelease = false
    state.focusPending = true
    if deps.markTypingActive then pcall(deps.markTypingActive) end
end

function M.isOpen()
    return state.open == true
end

function M.wantsInput()
    return state.open == true
end

function M.close()
    if not state.open then return end
    state.open = false
    state.focusPending = false
    state.waitChatRelease = false
    if type(deskInputState) == 'table' then
        deskInputState.keyboardStickyUntil = 0
    end
    releaseInputCapture()
    notifyInputChanged()
end

function M.reset()
    resetKeyLatch()
    M.close()
    ansBuf[0] = 0
end

function M.open()
    if not spectatingWithTarget() or inputBlocked() then return false end
    state.open = true
    state.focusPending = false
    state.waitChatRelease = true
    if type(deskHoldSampChatInput) == 'function' then
        pcall(deskHoldSampChatInput)
    end
    if deps.markTypingActive then pcall(deps.markTypingActive) end
    notifyInputChanged()
    syncInputCapture()
    return true
end

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

function M.handleWindowMessage(msg, wparam, lparam)
    if not spectatingWithTarget() or inputBlocked() then return false end

    msg = tonumber(msg) or 0
    wparam = tonumber(wparam) or 0

    if blockSampChatHotkey(msg, wparam) then return true end
    if blockOpeningKeyLeak(msg) then return true end

    local keyDown = isKeyDownMsg(msg)
    local keyUp = isKeyUpMsg(msg)
    if not keyDown and not keyUp then return false end
    if keyDown and isKeyRepeat(lparam) then return false end

    local vkeys = deps.vkeys
    if not vkeys then return false end
    local vkEsc = vkeys.VK_ESCAPE or 0x1B

    -- Enter KEYUP: сброс latch после отправки/закрытия.
    if keyUp and isEnterKey(wparam) then
        if state.waitEnterRelease then
            state.waitEnterRelease = false
            return true
        end
        return false
    end

    -- C KEYUP: отпускание клавиши открытия → можно ставить фокус в поле.
    if keyUp and isChatKey(wparam) then
        if state.waitChatRelease and state.open then
            armInputFocus()
            return true
        end
        return false
    end

    if not keyDown then return false end

    -- Открытие на C KEYDOWN (только чистое нажатие, без залипшего Enter).
    if not state.open then
        if not isChatKey(wparam) or modifierBlocksChat() then return false end
        if state.waitChatRelease or state.waitEnterRelease then return true end
        if M.open() then return true end
        return false
    end

    -- Панель открыта.
    if wparam == vkEsc then
        M.close()
        return true
    end

    if isChatKey(wparam) then
        return true
    end

    if isEnterKey(wparam) then
        if state.waitChatRelease or state.waitEnterRelease then return true end
        sendAns()
        state.waitEnterRelease = true
        return true
    end

    return false
end

function M.draw(settings)
    if not state.open or not spectatingWithTarget() then
        return
    end
    if imgui and imgui.DisableInput ~= nil then
        imgui.DisableInput = false
    end
    if deps.updateInputPassthrough then pcall(deps.updateInputPassthrough) end

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

        if state.waitChatRelease and chatKeyReleased() then
            armInputFocus()
        end

        local sendW = 84
        local gap = 8
        local inputW = math.max(140, imgui.GetContentRegionAvail().x - sendW - gap)

        imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 8))
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
        imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(0.08, 0.08, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.48, 0.36, 0.72, 0.55))
        imgui.PushStyleColor(imgui.Col.Text, col_label)

        if state.focusPending and imgui.SetKeyboardFocusHere then
            imgui.SetKeyboardFocusHere(0)
        end

        imgui.PushItemWidth(inputW)
        local hint = uiText('\xD1\xEE\xEE\xE1\xF9\xE5\xED\xE8\xE5 \xE4\xEB\xFF /ans...')
        if imgui.InputTextWithHint then
            imgui.InputTextWithHint('##sp_ans_input', hint, ansBuf, ANS_BUF_SIZE)
        else
            imgui.InputText('##sp_ans_input', ansBuf, ANS_BUF_SIZE)
        end
        imgui.PopItemWidth()

        if type(deskKeepInputOnActiveItem) == 'function' then
            pcall(deskKeepInputOnActiveItem)
        end
        if state.focusPending and imgui.IsItemFocused and imgui.IsItemFocused() then
            state.focusPending = false
        end

        imgui.PopStyleColor(3)
        imgui.PopStyleVar(2)

        imgui.SameLine(0, gap)
        imgui.PushStyleColor(imgui.Col.Button, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent)
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.44, 0.30, 0.66, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 1, 1, 1))
        if imgui.PushAllowKeyboardFocus then imgui.PushAllowKeyboardFocus(false) end
        local clicked = imgui.Button(uiText('\xCE\xF2\xEF\xF0\xE0\xE2\xE8\xF2\xFC'), imgui.ImVec2(sendW, 0))
        if imgui.PopAllowKeyboardFocus then imgui.PopAllowKeyboardFocus() end
        imgui.PopStyleColor(4)

        if clicked and not state.waitChatRelease then
            sendAns()
        end

        syncInputCapture()
        imgui.End()
    end
    spTheme.popOverlayChrome()
end

function M.install(installDeps)
    if type(installDeps) == 'table' then
        for k, v in pairs(installDeps) do
            deps[k] = v
        end
    end
end

return M
