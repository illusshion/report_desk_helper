#!/usr/bin/env python3
import pathlib

path = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua")
text = path.read_text(encoding="utf-8").replace("\r\n", "\n")

OLD_IS = """local function isAdvanceStStatsDialog(title, text)



    local titlePlain = stripDialogMarkup(title or '')



    local plain = stripDialogMarkup(text or '')



    if plain == '' or titlePlain == '' then return false end



    if not stDialogTitleMatches(titlePlain) then return false end



    return dialogHasStatsBody(text)



end"""

NEW_IS = """local function isAdvanceStStatsDialog(title, text)



    local titlePlain = stripDialogMarkup(title or '')



    local plain = stripDialogMarkup(text or '')



    if plain == '' then return false end



    if not dialogHasStatsBody(text) then return false end



    if titlePlain ~= '' and stDialogTitleMatches(titlePlain) then return true end



    if M.hasPendingSt() and state.pendingStId then return true end



    if titlePlain == '' and M.getTargetId() >= 0 then return true end



    return false



end"""

OLD_RESOLVE_HEAD = """local function resolveStatsDialogOwner(title, text)



    if not isAdvanceStStatsDialog(title, text) then



        return nil



    end"""

NEW_RESOLVE_HEAD = """local function resolveStatsDialogOwner(title, text)



    local pendingId = state.pendingStId



    local pendingFresh = pendingId and (os.clock() - (state.pendingStAt or 0)) <= PENDING_ST_SEC



    if pendingFresh and pendingId and dialogHasStatsBody(text) then



        return pendingId



    end



    if not isAdvanceStStatsDialog(title, text) then



        return nil



    end"""

OLD_PARSE = """function M.parseSpServerLine(text)



    text = stripTags(text or '')



    local nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%]%s*|%s*PING%s+(%d+)')"""

NEW_PARSE = """local SP_EXIT_CP1251 = '\\xC2\\xFB\\xE5\\xEE\\xE4'



local function spChatLineIsExit(text)



    text = stripTags(text or '')



    if text == '' then return false end



    if text:find(SP_EXIT_CP1251, 1, true) then return true end



    local low = text:lower()



    if low:find('выход', 1, true) or low:find('exit', 1, true) then return true end



    return false



end



function M.parseSpServerLine(text)



    text = stripTags(text or '')



    if spChatLineIsExit(text) then return false end



    local nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%]%s*|%s*PING%s+(%d+)')"""

repls = [
    (OLD_IS, NEW_IS, "isAdvanceStStatsDialog"),
    (OLD_RESOLVE_HEAD, NEW_RESOLVE_HEAD, "resolveStatsDialogOwner"),
    (OLD_PARSE, NEW_PARSE, "parseSpServerLine"),
]

for old, new, label in repls:
    if old not in text:
        if label == "parseSpServerLine" and "spChatLineIsExit" in text:
            continue
        raise SystemExit(f"MISSING {label}")
    text = text.replace(old, new, 1)

# tickSpectateHealth
OLD_TICK = """    if M.hasPendingSp() then



        orphanSinceAt = nil



        orphanRecoveryTried = false



        targetOfflineSinceAt = nil



        return



    end



    local stRetryId = M.getTargetId()"""

NEW_TICK = """    local sessionConfirmed = specSession.isActive and specSession.isActive()



    if M.hasPendingSp() and not sessionConfirmed then



        orphanSinceAt = nil



        orphanRecoveryTried = false



        targetOfflineSinceAt = nil



        return



    end



    if M.hasPendingSp() and sessionConfirmed then



        M.cancelPendingSp()



    end



    local stRetryId = M.getTargetId()"""

if "if M.hasPendingSp() and sessionConfirmed then" not in text:
    if OLD_TICK not in text:
        raise SystemExit("MISSING tick block")
    text = text.replace(OLD_TICK, NEW_TICK, 1)

OLD_ST = """    if stRetryId >= 0 and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then"""

NEW_ST = """    if stRetryId >= 0 and sessionConfirmed and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then"""

if "sessionConfirmed and not M.hasPendingSt()" not in text:
    text = text.replace(OLD_ST, NEW_ST, 1)

# drawOverlay retry
if "sessionConfirmedForHud" not in text:
    text = text.replace(
        """function M.drawOverlayImpl(settings)



    if not settings or settings.spectate_hud == false then return end""",
        """local function sessionConfirmedForHud(id)



    id = tonumber(id)



    if not id or id < 0 then return false end



    if specSession.isActive and specSession.isActive()



            and specSession.getTargetId and specSession.getTargetId() == id then



        return true



    end



    return specPlayerActive() and M.getTargetId() == id



end



function M.drawOverlayImpl(settings)



    if not settings or settings.spectate_hud == false then return end""",
        1,
    )

OLD_WAIT = """        elseif not hasAny then



            imgui.TextColored(col_muted2, uiText('\\xCE\\xE6\\xE8\\xE4\\xE0\\xED\\xE8\\xE5 /st \\xE8\\xEB\\xE8 \\xab\\xCE\\xE1\\xED\\xEE\\xE2\\xE8\\xF2\\xFC\\xbb'))



        end"""

NEW_WAIT = """        elseif not hasAny then



            imgui.TextColored(col_muted2, uiText('\\xCE\\xE6\\xE8\\xE4\\xE0\\xED\\xE8\\xE5 /st \\xE8\\xEB\\xE8 \\xab\\xCE\\xE1\\xED\\xEE\\xE2\\xE8\\xF2\\xFC\\xbb'))



            if id == M.getTargetId() and sessionConfirmedForHud(id)



                    and not pendingSt and not M.hasPendingSt() then



                local stGap = os.clock() - (state.lastAutoStAt or 0)



                if stGap >= 2.0 and stGap <= 60.0 then



                    state.lastAutoStAt = os.clock()



                    scheduleAutoStats(id, true)



                end



            end



        end"""

if "scheduleAutoStats(id, true)" not in text.split("drawOverlayImpl", 1)[-1][:8000]:
    if OLD_WAIT not in text:
        raise SystemExit("MISSING wait block")
    text = text.replace(OLD_WAIT, NEW_WAIT, 1)

path.write_text(text.replace("\n", "\r\n"), encoding="utf-8")
print("patched stats")
