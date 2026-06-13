#!/usr/bin/env python3
"""Fix intermittent /st stats HUD updates in report_desk_spectate_stats.lua."""
import pathlib
import sys

path = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua")
text = path.read_text(encoding="utf-8")
orig = text


def R(s: str) -> str:
    return s.replace("\r\n", "\n")


replacements = [
    (
        R("""local function scheduleAutoStats(id, force)
    id = tonumber(id)
    if not id or id < 0 then return end
    local now = os.clock()
    if state.pendingStId == id and (now - (state.pendingStAt or 0)) < 1.0 then
        return
    end
    if now - (state.lastAutoStScheduleAt or 0) < 0.45 then
        return
    end
    if M.getTargetId() ~= id then return end
    if specSession.isActive and not specSession.isActive() then return end
    state.lastAutoStScheduleAt = now
    M.requestStats(id, { force = force == true })
end"""),
        R("""local function scheduleAutoStats(id, force)
    id = tonumber(id)
    if not id or id < 0 then return end
    local now = os.clock()
    if M.hasPendingSt() and state.pendingStId == id then
        return
    end
    if not force and now - (state.lastAutoStScheduleAt or 0) < 0.45 then
        return
    end
    if M.getTargetId() ~= id then return end
    local spectating = specPlayerActive()
        or (specSession.isActive and specSession.isActive())
    if not spectating then return end
    state.lastAutoStScheduleAt = now
    M.requestStats(id, { force = force == true })
end"""),
    ),
    (
        R("""    local nowSync = os.clock()
    if state.targetId == id and state.lastSyncFromSessionAt
            and (nowSync - state.lastSyncFromSessionAt) < 0.35 then
        return
    end
    state.lastSyncFromSessionAt = nowSync

    local prevId = state.targetId
    if prevId ~= id then
        state.hudPlaced = false
        pcall(specMenuMod.resetMenuSelection)
        clearPendingSt()"""),
        R("""    local nowSync = os.clock()
    if state.targetId == id and state.lastSyncFromSessionAt
            and (nowSync - state.lastSyncFromSessionAt) < 0.35 then
        if not syncOpts.skipAutoSt and syncOpts.forceAutoSt
                and settings and settings.spectate_hud ~= false
                and not M.hasFullStats(id) then
            scheduleAutoStats(id, true)
        end
        return
    end
    state.lastSyncFromSessionAt = nowSync

    local prevId = state.targetId
    if prevId ~= id then
        state.lastAutoStScheduleAt = 0
        state.lastAutoStAt = 0
        state.hudPlaced = false
        pcall(specMenuMod.resetMenuSelection)
        clearPendingSt()"""),
    ),
    (
        R("""-- Advance /st: title "Статистика игрока" + tablist body with server stat labels.
local ST_DIALOG_TITLE = '\\xD1\\xF2\\xE0\\xF2\\xE8\\xF1\\xF2\\xE8\\xEA\\xE0 \\xE8\\xE3\\xF0\\xEE\\xEA\\xE0'
local ST_DIALOG_BODY_MARKERS = {
    '\\xC8\\xEC\\xFF',
    '\\xD3\\xF0\\xEE\\xE2\\xE5\\xED',
    '\\xCD\\xE0\\xEB\\xE8\\xF7',
    '\\xD1\\xE5\\xEC\\xFC',
    '\\xCE\\xF0\\xE3\\xE0\\xED',
    '\\xC8\\xE3\\xF0\\xEE\\xE2\\xEE\\xE9 \\xF1\\xF2\\xE0\\xF2',
}

local function isAdvanceStStatsDialog(title, text)
    local titlePlain = stripDialogMarkup(title or '')
    local plain = stripDialogMarkup(text or '')
    if plain == '' or titlePlain == '' then return false end
    if titlePlain ~= ST_DIALOG_TITLE
            and not titlePlain:find(ST_DIALOG_TITLE, 1, true) then
        return false
    end
    local hits = 0
    for _, marker in ipairs(ST_DIALOG_BODY_MARKERS) do
        if plain:find(marker, 1, true) then
            hits = hits + 1
        end
    end
    return hits >= 4
end"""),
        R("""-- Advance /st: title "Статистика игрока" + tablist body with server stat labels.
local ST_DIALOG_TITLE = '\\xD1\\xF2\\xE0\\xF2\\xE8\\xF1\\xF2\\xE8\\xEA\\xE0 \\xE8\\xE3\\xF0\\xEE\\xEA\\xE0'
local ST_DIALOG_TITLE_UTF8 = 'Статистика игрока'

local function stDialogTitleMatches(titlePlain)
    if titlePlain == '' then return false end
    if titlePlain == ST_DIALOG_TITLE or titlePlain:find(ST_DIALOG_TITLE, 1, true) then
        return true
    end
    if titlePlain == ST_DIALOG_TITLE_UTF8 or titlePlain:find(ST_DIALOG_TITLE_UTF8, 1, true) then
        return true
    end
    local low = titlePlain:lower()
    return low:find('статистик', 1, true) ~= nil and low:find('игрок', 1, true) ~= nil
end

local function isAdvanceStStatsDialog(title, text)
    local titlePlain = stripDialogMarkup(title or '')
    local plain = stripDialogMarkup(text or '')
    if plain == '' or titlePlain == '' then return false end
    if not stDialogTitleMatches(titlePlain) then return false end
    return dialogHasStatsBody(text)
end"""),
    ),
    (
        R("""function M.hasPendingSt()
    local pid = state.pendingStId
    if not pid then
        state.stShowNative = false
        return false
    end
    if (os.clock() - (state.pendingStAt or 0)) > PENDING_ST_SEC then
        state.pendingStId = nil
        state.stShowNative = false
        return false
    end
    return true
end"""),
        R("""function M.hasPendingSt()
    local pid = state.pendingStId
    if not pid then
        state.stShowNative = false
        return false
    end
    if (os.clock() - (state.pendingStAt or 0)) > PENDING_ST_SEC then
        local expiredId = pid
        state.pendingStId = nil
        state.stShowNative = false
        if expiredId and M.getTargetId() == expiredId then
            state.lastAutoStAt = 0
        end
        return false
    end
    return true
end"""),
    ),
    (
        R("""    local stRetryId = M.getTargetId()
    if stRetryId >= 0 and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then
        local s = getSettings and getSettings()
        if s and s.spectate_hud ~= false
                and (now - (state.lastAutoStAt or 0)) >= AUTO_ST_COOLDOWN then
            state.lastAutoStAt = now
            M.requestStats(stRetryId, { force = true })
        end
    end"""),
        R("""    local stRetryId = M.getTargetId()
    if stRetryId >= 0 and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then
        local s = getSettings and getSettings()
        local stCooldown = M.hasStats(stRetryId) and AUTO_ST_COOLDOWN or 2.0
        if s and s.spectate_hud ~= false
                and (now - (state.lastAutoStAt or 0)) >= stCooldown then
            state.lastAutoStAt = now
            M.requestStats(stRetryId, { force = true })
        end
    end"""),
    ),
    (
        R("""            local src = meta.source
            if spRefresh.shouldSkipAutoSt and spRefresh.shouldSkipAutoSt(id) then
                syncOpts.skipAutoSt = true
            elseif src == 'sp_line' or src == 'spectate_player' or src == 'reload_recover' then
                syncOpts.forceAutoSt = true
                if src == 'spectate_player' then
                    if lastSpecStepAt and (os.clock() - lastSpecStepAt) < SPEC_STEP_AUTO_ST_DELAY
                            and M.hasFullStats(id) then
                        syncOpts.skipAutoSt = true
                    end
                end
            end"""),
        R("""            local src = meta.source
            if src == 'sp_line' or src == 'reload_recover' then
                syncOpts.forceAutoSt = true
            elseif spRefresh.shouldSkipAutoSt and spRefresh.shouldSkipAutoSt(id) then
                syncOpts.skipAutoSt = true
            elseif src == 'spectate_player' then
                syncOpts.forceAutoSt = true
                if lastSpecStepAt and (os.clock() - lastSpecStepAt) < SPEC_STEP_AUTO_ST_DELAY
                        and M.hasFullStats(id) then
                    syncOpts.skipAutoSt = true
                end
            end"""),
    ),
]

for old, new in replacements:
    old_n = R(old)
    new_n = R(new)
    if old_n not in text:
        # try CRLF version in file
        old_crlf = old_n.replace("\n", "\r\n")
        if old_crlf in text:
            text = text.replace(old_crlf, new_n.replace("\n", "\r\n"), 1)
            continue
        print("MISSING BLOCK:\n", old_n[:200], file=sys.stderr)
        sys.exit(1)
    text = text.replace(old_n, new_n, 1)

if text == orig:
    print("No changes applied", file=sys.stderr)
    sys.exit(1)

path.write_text(text.replace("\n", "\r\n"), encoding="utf-8")
print(f"Patched {path} ({len(replacements)} blocks)")
