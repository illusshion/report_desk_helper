#!/usr/bin/env python3
"""Fix stats HUD: SP exit lines + looser /st dialog intercept + health retry."""
import pathlib
import sys

ROOT = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader")


def norm(s):
    return s.replace("\r\n", "\n").replace("\r", "\n")


def read(rel):
    return norm((ROOT / rel).read_text(encoding="utf-8"))


def write(rel, text):
    (ROOT / rel).write_text(norm(text).replace("\n", "\r\n"), encoding="utf-8")


def patch(text, old, new, label):
    if norm(old) not in norm(text):
        print(f"MISSING [{label}]", file=sys.stderr)
        print(repr(norm(old)[:200]), file=sys.stderr)
        sys.exit(1)
    return norm(text).replace(norm(old), norm(new), 1)


NL = "\n\n"


# --- spectate_session ---
sess = read("lib/report_desk_spectate_session.lua")
sess = patch(
    sess,
    f"function M.parseSpLine(text){NL}    text = stripTags(text or ''){NL}    if text == '' or not text:find('[SP]', 1, true) then return false end",
    f"""local SP_EXIT_CP1251 = '\\xC2\\xFB\\xE5\\xEE\\xE4'

local function spChatLineIsExit(text)
    text = stripTags(text or '')
    if text == '' then return false end
    if text:find(SP_EXIT_CP1251, 1, true) then return true end
    local low = text:lower()
    if low:find('выход', 1, true) or low:find('exit', 1, true) then return true end
    return false
end

function M.parseSpLine(text){NL}    text = stripTags(text or ''){NL}    if text == '' or not text:find('[SP]', 1, true) then return false end{NL}    if spChatLineIsExit(text) then
        local _, exitId = text:match('%[SP%]%s*(.-)%[(%d+)%]')
        exitId = tonumber(exitId)
        if exitId and exitId >= 0 and session.active and session.targetId == exitId then
            M.endSession()
        end
        return false
    end""",
    "session parseSpLine",
)
write("lib/report_desk_spectate_session.lua", sess)

stats = read("lib/report_desk_spectate_stats.lua")

stats = patch(
    stats,
    f"function M.parseSpServerLine(text){NL}    text = stripTags(text or ''){NL}    local nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%]%s*|%s*PING%s+(%d+)')",
    f"""local SP_EXIT_CP1251 = '\\xC2\\xFB\\xE5\\xEE\\xE4'

local function spChatLineIsExit(text)
    text = stripTags(text or '')
    if text == '' then return false end
    if text:find(SP_EXIT_CP1251, 1, true) then return true end
    local low = text:lower()
    if low:find('выход', 1, true) or low:find('exit', 1, true) then return true end
    return false
end

function M.parseSpServerLine(text){NL}    text = stripTags(text or ''){NL}    if spChatLineIsExit(text) then return false end{NL}    local nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%]%s*|%s*PING%s+(%d+)')""",
    "parseSpServerLine",
)

stats = patch(
    stats,
    f"""local function isAdvanceStStatsDialog(title, text)
    local titlePlain = stripDialogMarkup(title or '')
    local plain = stripDialogMarkup(text or '')
    if plain == '' or titlePlain == '' then return false end
    if not stDialogTitleMatches(titlePlain) then return false end
    return dialogHasStatsBody(text)
end""",
    f"""local function isAdvanceStStatsDialog(title, text)
    local titlePlain = stripDialogMarkup(title or '')
    local plain = stripDialogMarkup(text or '')
    if plain == '' then return false end
    if not dialogHasStatsBody(text) then return false end
    if titlePlain ~= '' and stDialogTitleMatches(titlePlain) then return true end
    if M.hasPendingSt() and state.pendingStId then return true end
    if titlePlain == '' and M.getTargetId() >= 0 then return true end
    return false
end""",
    "isAdvanceStStatsDialog",
)

stats = patch(
    stats,
    f"""local function resolveStatsDialogOwner(title, text)
    if not isAdvanceStStatsDialog(title, text) then
        return nil
    end

    local titleId = extractDialogPlayerIdFromTitle(title)""",
    f"""local function resolveStatsDialogOwner(title, text)
    local pendingId = state.pendingStId
    local pendingFresh = pendingId and (os.clock() - (state.pendingStAt or 0)) <= PENDING_ST_SEC
    if pendingFresh and pendingId and dialogHasStatsBody(text) then
        return pendingId
    end
    if not isAdvanceStStatsDialog(title, text) then
        return nil
    end

    local titleId = extractDialogPlayerIdFromTitle(title)""",
    "resolveStatsDialogOwner",
)

stats = patch(
    stats,
    f"""    if M.hasPendingSp() then
        orphanSinceAt = nil
        orphanRecoveryTried = false
        targetOfflineSinceAt = nil
        return
    end
    local stRetryId = M.getTargetId()""",
    f"""    local sessionConfirmed = specSession.isActive and specSession.isActive()
    if M.hasPendingSp() and not sessionConfirmed then
        orphanSinceAt = nil
        orphanRecoveryTried = false
        targetOfflineSinceAt = nil
        return
    end
    if M.hasPendingSp() and sessionConfirmed then
        M.cancelPendingSp()
    end
    local stRetryId = M.getTargetId()""",
    "tick pending sp",
)

stats = patch(
    stats,
    f"""    if stRetryId >= 0 and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then
        local s = getSettings and getSettings()
        local stCooldown = M.hasStats(stRetryId) and AUTO_ST_COOLDOWN or 2.0
        if s and s.spectate_hud ~= false
                and (now - (state.lastAutoStAt or 0)) >= stCooldown then
            state.lastAutoStAt = now
            M.requestStats(stRetryId, {{ force = true }})
        end
    end
    local sessionConfirmed = specSession.isActive and specSession.isActive()""",
    f"""    if stRetryId >= 0 and sessionConfirmed and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then
        local s = getSettings and getSettings()
        local stCooldown = M.hasStats(stRetryId) and AUTO_ST_COOLDOWN or 2.0
        if s and s.spectate_hud ~= false
                and (now - (state.lastAutoStAt or 0)) >= stCooldown then
            state.lastAutoStAt = now
            M.requestStats(stRetryId, {{ force = true }})
        end
    end
    local sessionConfirmed = specSession.isActive and specSession.isActive()""",
    "tick st retry",
)

if "sessionConfirmedForHud" not in stats:
    stats = patch(
        stats,
        f"function M.drawOverlayImpl(settings){NL}    if not settings or settings.spectate_hud == false then return end",
        f"""local function sessionConfirmedForHud(id)
    id = tonumber(id)
    if not id or id < 0 then return false end
    if specSession.isActive and specSession.isActive()
            and specSession.getTargetId and specSession.getTargetId() == id then
        return true
    end
    return specPlayerActive() and M.getTargetId() == id
end

function M.drawOverlayImpl(settings){NL}    if not settings or settings.spectate_hud == false then return end""",
        "sessionConfirmedForHud",
    )

stats = patch(
    stats,
    f"""        elseif not hasAny then
            imgui.TextColored(col_muted2, uiText('\\xCE\\xE6\\xE8\\xE4\\xE0\\xED\\xE8\\xE5 /st \\xE8\\xEB\\xE8 \\xAB\\xCE\\xE1\\xED\\xEE\\xE2\\xE8\\xF2\\xFC\\xBB'))
        end""",
    f"""        elseif not hasAny then
            imgui.TextColored(col_muted2, uiText('\\xCE\\xE6\\xE8\\xE4\\xE0\\xED\\xE8\\xE5 /st \\xE8\\xEB\\xE8 \\xab\\xCE\\xE1\\xED\\xEE\\xE2\\xE8\\xF2\\xFC\\xbb'))
            if id == M.getTargetId() and sessionConfirmedForHud(id)
                    and not pendingSt and not M.hasPendingSt() then
                local stGap = os.clock() - (state.lastAutoStAt or 0)
                if stGap >= 2.0 and stGap <= 60.0 then
                    state.lastAutoStAt = os.clock()
                    scheduleAutoStats(id, true)
                end
            end
        end""",
    "drawOverlay retry",
)

write("lib/report_desk_spectate_stats.lua", stats)
print("OK: patched session + stats")
