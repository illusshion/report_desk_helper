--[[ Report Desk — overlay загрузки/обновления (render*, без imgui). ]]
local M = {}

local state = {
    active = false,
    title = '',
    detail = '',
    hint = '',
    fraction = nil,
    started = 0,
}

local handler = nil
local fontTitle = nil
local fontBody = nil
local fontSmall = nil

local COL_PANEL = 0xE812121A
local COL_PANEL_BORDER = 0xFF9E7BEF
local COL_BAR_BG = 0xFF1E1C28
local COL_BAR_FILL = 0xFF9E7BEF
local COL_BAR_GLOW = 0x669E7BEF
local COL_TEXT = 0xFFF2F0FA
local COL_MUTED = 0xFF9890A8

local function ensureFonts()
    if fontTitle and fontBody and fontSmall then return end
    if not renderCreateFont then return end
    fontTitle = renderCreateFont('Arial', 13, 5)
    fontBody = renderCreateFont('Arial', 11, 4)
    fontSmall = renderCreateFont('Arial', 9, 4)
end

local function screenSize()
    if getScreenResolution then
        return getScreenResolution()
    end
    return 640, 480
end

local function drawPanel()
    if not state.active then return end
    if not renderDrawBox or not renderFontDrawText then return end
    ensureFonts()
    if not fontTitle then return end

    local sw, sh = screenSize()
    local panelW = math.min(460, math.max(320, sw - 80))
    local panelH = 118
    local x = math.floor((sw - panelW) * 0.5)
    local y = sh - panelH - 28

    renderDrawBox(x, y, panelW, panelH, COL_PANEL, true)
    renderDrawBox(x, y, panelW, 2, COL_PANEL_BORDER, true)

    local tx = x + 18
    renderFontDrawText(fontTitle, state.title ~= '' and state.title or 'Report Desk', tx, y + 12, COL_TEXT, 1.0)
    if state.detail ~= '' then
        renderFontDrawText(fontBody, state.detail, tx, y + 34, COL_MUTED, 1.0)
    end

    local barX = x + 18
    local barY = y + panelH - 36
    local barW = panelW - 36
    local barH = 10
    renderDrawBox(barX, barY, barW, barH, COL_BAR_BG, true)

    local frac = tonumber(state.fraction)
    if frac == nil then
        local t = os.clock() - (state.started or os.clock())
        local pulseW = math.max(48, barW * 0.28)
        local travel = barW - pulseW
        local phase = (t * 0.55) % 1.0
        local px = barX + math.floor(travel * phase)
        renderDrawBox(px, barY, pulseW, barH, COL_BAR_GLOW, true)
        renderDrawBox(px + 2, barY + 2, pulseW - 4, barH - 4, COL_BAR_FILL, true)
    else
        frac = math.max(0, math.min(1, frac))
        local fillW = math.max(0, math.floor(barW * frac))
        if fillW > 0 then
            renderDrawBox(barX, barY, fillW, barH, COL_BAR_FILL, true)
        end
        local pct = math.floor(frac * 100 + 0.5)
        renderFontDrawText(fontSmall, pct .. '%', barX + barW - 34, barY - 14, COL_MUTED, 1.0)
    end

    if state.hint ~= '' then
        renderFontDrawText(fontSmall, state.hint, tx, y + 56, COL_MUTED, 1.0)
    end
end

local function installHandler()
    if handler then return end
    handler = function()
        drawPanel()
    end
    addEventHandler('onD3DPresent', handler)
end

local function removeHandler()
    if handler and removeEventHandler then
        pcall(removeEventHandler, 'onD3DPresent', handler)
    end
    handler = nil
end

function M.show(title, detail, hint)
    state.active = true
    state.title = tostring(title or 'Report Desk')
    state.detail = tostring(detail or '')
    state.hint = tostring(hint or '\xC8\xE3\xF0\xE0 \xEC\xEE\xE6\xE5\xF2 \xEF\xEE\xE4\xF2\xEE\xF0\xEC\xE0\xE6\xE8\xE2\xE0\xF2\xFC \xB7 \xFD\xF2\xEE \xED\xEE\xF0\xEC\xE0\xEB\xFC\xED\xEE')
    state.fraction = nil
    state.started = os.clock()
    installHandler()
end

function M.update(opts)
    opts = opts or {}
    if opts.title ~= nil then state.title = tostring(opts.title) end
    if opts.detail ~= nil then state.detail = tostring(opts.detail) end
    if opts.hint ~= nil then state.hint = tostring(opts.hint) end
    if opts.fraction ~= nil then
        local f = tonumber(opts.fraction)
        state.fraction = f
    end
    if opts.indeterminate == true then
        state.fraction = nil
    end
    state.active = true
    installHandler()
end

function M.hide()
    state.active = false
    state.fraction = nil
    state.detail = ''
    removeHandler()
end

function M.isActive()
    return state.active == true
end

return M
