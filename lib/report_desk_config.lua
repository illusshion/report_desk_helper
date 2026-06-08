--[[ Модуль: load/save config Lua files. ]]
function scenarioLabelKey(label)
    label = trim(tostring(label or ''))
    if label == '' then return '' end
    if type(normalizeMatchText) == 'function' then
        return normalizeMatchText(label)
    end
    return string.lower(label)
end

function loadDefaultScenarioPack()
    if package and package.preload and package.preload['report_desk_user_defaults'] then
        local ok, data = pcall(require, 'report_desk_user_defaults')
        if ok and type(data) == 'table' then return data end
    end
    if doesFileExist(USER_DEFAULT_CONFIG_PATH) then
        local chunk, err = loadfile(USER_DEFAULT_CONFIG_PATH)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == 'table' then return data end
        elseif err then
            print('[Report Desk] default scenarios: ' .. tostring(err))
        end
    end
    return nil
end

function mergeScenarioPack(userList, defaultList)
    local seen = {}
    for _, sc in ipairs(userList or {}) do
        local key = scenarioLabelKey(sc.label)
        if key ~= '' then seen[key] = true end
    end
    local merged = cloneQuickScenarios(userList or {}, true)
    local added = 0
    for _, sc in ipairs(defaultList or {}) do
        local key = scenarioLabelKey(sc.label)
        if key ~= '' and not seen[key] then
            merged[#merged + 1] = cloneQuickScenarios({ sc }, true)[1]
            seen[key] = true
            added = added + 1
        end
    end
    return merged, added
end

function migrateScenariosPackIfNeeded()
    local userVer = tonumber(settings.scenarios_pack_version) or 0
    if userVer >= SCENARIOS_PACK_VERSION then return end
    local pack = loadDefaultScenarioPack()
    if not pack then return end
    local defaultList = pack.quick_scenarios
    if not scenariosHasContent(defaultList) then return end
    local merged, added = mergeScenarioPack(quickScenarios, defaultList)
    if added > 0 then
        quickScenarios = merged
        bumpScenariosGen()
        scenariosUiSynced = false
        print(string.format('[Report Desk] scenarios: +%d new (pack v%d)', added, SCENARIOS_PACK_VERSION))
    end
    settings.scenarios_pack_version = SCENARIOS_PACK_VERSION
    markDirtySettings()
end

function migrateLegacyAutoRules(src)
    if type(src) ~= 'table' then return end
    for _, r in ipairs(src) do
        if type(r) ~= 'table' then goto continue end
        local name = normalizeMatchText(r.name or '')
        if name == 'time' or name == '\xE2\xF0\xE5\xEC\xFF' then
            if r.enabled == false then settings.auto_time_enabled = false end
            local payload = trim(r.payload or '')
            if payload ~= '' then
                settings.time_reply = normalizeStoredText(payload, isUtf8Text(payload))
            end
        elseif name == 'gg' or name == '\xF1\xEF\xE0\xF1\xE8\xE1\xEE' then
            if r.enabled == false then settings.auto_gg_enabled = false end
            local payload = trim(r.payload or '')
            if payload ~= '' then
                settings.gg_reply = normalizeStoredText(payload, isUtf8Text(payload))
            end
        end
        ::continue::
    end
end

-- Load Config
function loadConfig()
    quickScenarios = cloneQuickScenarios(DEFAULT_QUICK_SCENARIOS)
    reloadProfanityWordsFromDict()
    threads = {}
    threadOrder = {}

    local configData = nil
    if doesFileExist(CONFIG_PATH) then
        local chunk, err = loadfile(CONFIG_PATH)
        if chunk then
            local ok, data = pcall(chunk)
            if ok and type(data) == 'table' then
                configData = data
            end
        else
            print('[Report Desk] load: ' .. tostring(err))
        end
    end

    local data = configData
    if not data then
        ensureCheatsSettings()
        bumpScenariosGen()
        deskConfigReady = not doesFileExist(CONFIG_PATH)
        if doesFileExist(USER_CONFIG_PATH) then
            pcall(loadUserConfig)
        else
            pcall(saveUserConfig)
        end
        return
    end

    if type(data.settings) == 'table' then
        for k, v in pairs(data.settings) do
            if k ~= 'cheats' then settings[k] = v end
        end
        if type(data.settings.cheats) == 'table' then
            settings.cheats = data.settings.cheats
        end
    end
    if settings.watch_notify then
        if looksCorruptedConfigText(settings.watch_notify) then markDirtySettings() end
        settings.watch_notify = repairStoredConfigText(settings.watch_notify, 'see')
    end
    if settings.gg_reply then
        if looksCorruptedConfigText(settings.gg_reply) then markDirtySettings() end
        settings.gg_reply = repairStoredConfigText(settings.gg_reply, DEFAULT_GG_REPLY)
    end
    if settings.time_reply then
        if looksCorruptedConfigText(settings.time_reply) then markDirtySettings() end
        settings.time_reply = repairStoredConfigText(settings.time_reply, DEFAULT_TIME_REPLY)
    end
    if settings.tech_reply then
        if looksCorruptedConfigText(settings.tech_reply) then markDirtySettings() end
        settings.tech_reply = repairStoredConfigText(settings.tech_reply, DEFAULT_TECH_REPLY)
    end
    ensureCheatsSettings()
    settings.poll_chat_log = nil
    settings.poll_events_only = nil
    settings.ingest_pc = nil
    settings.ingest_s = nil
    settings.ingest_m = nil
    settings.ingest_admin_actions = nil
    settings.debug = nil
    settings.history_limit = nil
    settings.max_threads = nil
    if settings.auto_rules_enabled == nil then settings.auto_rules_enabled = true end
    if settings.auto_time_enabled == nil then settings.auto_time_enabled = true end
    if settings.auto_gg_enabled == nil then settings.auto_gg_enabled = true end
    local al = tonumber(settings.admin_level)
    if al == nil or al < 1 then
        settings.admin_level = 3
    elseif al > 4 then
        settings.admin_level = 4
    else
        settings.admin_level = math.floor(al)
    end
    local sr = tonumber(settings.skin_radius)
    if sr == nil or sr < SKIN_RADIUS_MIN or sr > SKIN_RADIUS_MAX then
        settings.skin_radius = 20
    else
        settings.skin_radius = math.floor(sr)
    end
    if settings.skin_radius == 80 then
        settings.skin_radius = 20
    end
    cheatState.hudPlaced = false
    cheatState.hudPosValidated = false
    cheatsUiSynced = false
    if type(checkerState) == 'table' then
        checkerState.hudPlaced = false
        checkerState.hudPosValidated = false
    end
    if type(data.report_colors) == 'table' then
        for _, c in ipairs(data.report_colors) do
            REPORT_COLORS[normColor(c)] = true
        end
    end
    if type(data.rules) == 'table' and #data.rules > 0 then
        migrateLegacyAutoRules(data.rules)
    end
    local hadScenarios = false
    if type(data.quick_scenarios) == 'table' and #data.quick_scenarios > 0 then
        quickScenarios = cloneQuickScenarios(data.quick_scenarios)
        hadScenarios = true
    end
    if not hadScenarios then
        local ir = trim(settings.interview_reply or '')
        if ir ~= '' then
            for _, sc in ipairs(quickScenarios) do
                if sc.action == 'reply' then
                    sc.reply = ir
                    break
                end
            end
        end
    end
    rebuildProfanityNorm()
    if type(data.threads) == 'table' then
        local merged = {}
        for key, raw in pairs(data.threads) do
            if type(raw) == 'table' then
                local id = tonumber(raw.id) or tonumber(key)
                local nick = trim(raw.nick or '')
                if nick == '' and id then nick = 'ID:' .. id end
                local nk = nickKey(nick)
                if nk == '' and id then nk = 'id' .. tostring(id) end
                local msgs = {}
                if type(raw.messages) == 'table' then
                    for _, m in ipairs(raw.messages) do
                        if type(m) == 'table' and (m.text or m.note) then
                            local entry = {
                                dir = m.dir or 'in',
                                kind = m.kind,
                                text = normalizeStoredText(m.text or '', isUtf8Text(m.text or '')),
                                ts = tonumber(m.ts) or os.time(),
                                self = m.self,
                                note = normalizeStoredText(m.note or '', isUtf8Text(m.note or '')),
                            }
                            local adm = normalizeStoredText(m.adminNick or '', isUtf8Text(m.adminNick or ''))
                            if trim(adm) ~= '' then entry.adminNick = adm end
                            normalizeStoredMessage(entry)
                            msgs[#msgs + 1] = entry
                        end
                    end
                end
                trimMessages(msgs)
                if merged[nk] then
                    local ex = merged[nk]
                    for _, m in ipairs(msgs) do
                        ex.messages[#ex.messages + 1] = m
                    end
                    trimMessages(ex.messages)
                    if id and (not ex.id or ex.id == 0) then ex.id = id end
                else
                    merged[nk] = {
                        id = id or 0,
                        nick = nick,
                        lastId = tonumber(raw.lastId) or id,
                        status = 'open',
                        pinned = raw.pinned == true,
                        unread = 0,
                        lastAt = tonumber(raw.lastAt) or os.time(),
                        messages = msgs,
                    }
                end
            end
        end
        threads = merged
        rebuildThreadOrder()
        resetSessionUnread()
        pruneOldThreads()
    end
    bumpScenariosGen()

    if not doesFileExist(USER_CONFIG_PATH) then
        pcall(saveUserConfig)
    else
        local okUser = pcall(loadUserConfig)
        if not okUser or not scenariosHasContent(quickScenarios) then
            print('[Report Desk] user config empty/broken — keeping defaults')
        end
    end
    migrateScenariosPackIfNeeded()
    deskConfigReady = true
end

-- Backup User Config File
function backupUserConfigFile()
    if not doesFileExist(USER_CONFIG_PATH) then return end
    local rf = io.open(USER_CONFIG_PATH, 'rb')
    if not rf then return end
    local body = rf:read('*a')
    rf:close()
    if not body or body == '' then return end
    local wf = io.open(USER_CONFIG_BACKUP, 'wb')
    if not wf then return end
    wf:write(body)
    wf:close()
end

-- Save User Config
function saveUserConfig()
    if not scenariosHasContent(quickScenarios) then
        print('[Report Desk] user save skipped: empty scenarios')
        return false
    end

    backupUserConfigFile()

    local dir = getWorkingDirectory() .. '\\config'
    if not doesDirectoryExist(dir) then createDirectory(dir) end
    local f, err = io.open(USER_CONFIG_PATH, 'w')
    if not f then
        print('[Report Desk] user save: ' .. tostring(err))
        return false
    end

    f:write('-- Admin Report Desk user settings (UTF-8)\n')
    f:write('-- report-desk-user-config: utf-8\n')
    f:write('-- Scenarios. Auto-reply keywords are built-in; edit toggles/text in Report Desk settings.\n')
    f:write('return {\n')

    f:write('  strings = {\n')
    syncLegacyGgTechFromComposerButtons()
    f:write(string.format('    gg_reply = %s,\n', luaQuoteUtf8(getGgReplyText())))
    f:write(string.format('    tech_reply = %s,\n', luaQuoteUtf8(getTechReplyText())))
    f:write(string.format('    watch_notify = %s,\n', luaQuoteUtf8(settings.watch_notify or 'see')))
    f:write('  },\n')

    f:write('  composer_quick_buttons = {\n')
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        f:write('    {\n')
        f:write(string.format('      id = %q,\n', b.id or ''))
        f:write(string.format('      label = %s,\n', luaQuoteUtf8(b.label or '')))
        f:write(string.format('      text = %s,\n', luaQuoteUtf8(b.text or '')))
        f:write('    },\n')
    end
    f:write('  },\n')

    f:write(string.format('  scenarios_pack_version = %d,\n',
        tonumber(settings.scenarios_pack_version) or SCENARIOS_PACK_VERSION))

    f:write('  quick_scenarios = {\n')
    for _, sc in ipairs(quickScenarios) do
        f:write('    {\n')
        f:write(string.format('      label = %s,\n', luaQuoteUtf8(sc.label or '')))
        f:write(string.format('      enabled = %s,\n', sc.enabled ~= false and 'true' or 'false'))
        f:write(string.format('      match = %q,\n', sc.match or 'contains'))
        f:write(string.format('      priority = %d,\n', tonumber(sc.priority) or 0))
        f:write(string.format('      skip_if_report_id = %s,\n', sc.skip_if_report_id ~= false and 'true' or 'false'))
        f:write(string.format('      action = %q,\n', sc.action == 'watch' and 'watch' or 'reply'))
        f:write(string.format('      reply = %s,\n', luaQuoteUtf8(sc.reply or '')))
        f:write('      keywords = {')
        for i, kw in ipairs(sc.keywords or {}) do
            if i > 1 then f:write(', ') end
            f:write(luaQuoteUtf8(kw))
        end
        f:write('},\n')
        if type(sc.negative_keywords) == 'table' and #sc.negative_keywords > 0 then
            f:write('      negative_keywords = {')
            for i, kw in ipairs(sc.negative_keywords) do
                if i > 1 then f:write(', ') end
                f:write(luaQuoteUtf8(kw))
            end
            f:write('},\n')
        end
        f:write('    },\n')
    end
    f:write('  },\n')
    f:write('}\n')
    f:close()
    return true
end

-- Load User Config
function loadUserConfig()
    local path = USER_CONFIG_PATH
    if not doesFileExist(path) and doesFileExist(USER_CONFIG_BACKUP) then
        path = USER_CONFIG_BACKUP
        print('[Report Desk] user config: using backup')
    end
    if not doesFileExist(path) then return false end
    local chunk, err = loadfile(path)
    if not chunk then
        print('[Report Desk] user load: ' .. tostring(err))
        return false
    end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= 'table' then
        print('[Report Desk] user load: bad table')
        return false
    end

    if type(data.strings) == 'table' then
        if data.strings.gg_reply ~= nil and trim(data.strings.gg_reply) ~= '' then
            settings.gg_reply = normalizeStoredText(data.strings.gg_reply, true)
        end
        if data.strings.tech_reply ~= nil and trim(data.strings.tech_reply) ~= '' then
            settings.tech_reply = normalizeStoredText(data.strings.tech_reply, true)
        end
        if data.strings.watch_notify ~= nil and trim(data.strings.watch_notify) ~= '' then
            settings.watch_notify = normalizeStoredText(data.strings.watch_notify, true)
        end
    end
    if type(data.composer_quick_buttons) == 'table' and #data.composer_quick_buttons > 0 then
        local list = {}
        for _, raw in ipairs(data.composer_quick_buttons) do
            if type(raw) == 'table' then
                local b = normalizeComposerQuickButton(raw, true)
                if b then list[#list + 1] = b end
            end
        end
        if #list > 0 then settings.composer_quick_buttons = list end
    end
    ensureComposerQuickButtons()
    syncLegacyGgTechFromComposerButtons()
    if data.scenarios_pack_version ~= nil then
        settings.scenarios_pack_version = tonumber(data.scenarios_pack_version) or 0
    end
    if scenariosHasContent(data.quick_scenarios) then
        quickScenarios = cloneQuickScenarios(data.quick_scenarios, true)
        bumpScenariosGen()
    end
    if type(data.checker) == 'table' then
        local catalogPath = getWorkingDirectory() .. '\\config\\report_desk_checker_catalog.lua'
        if not doesFileExist(catalogPath) then
            rawset(_G, '__desk_pendingCheckerCatalog', data.checker)
        end
    end
    if rulesHasContent(data.rules) then
        migrateLegacyAutoRules(data.rules)
        ensureComposerQuickButtons()
        syncLegacyGgTechFromComposerButtons()
    end
    scenariosUiSynced = false
    return true
end

-- Save Config
function saveConfig()
    if not deskConfigReady and doesFileExist(CONFIG_PATH) then
        print('[Report Desk] save skipped: config was not loaded')
        return false
    end
    if dirtySettings then
        pcall(saveUserConfig)
    end

    local dir = getWorkingDirectory() .. '\\config'
    if not doesDirectoryExist(dir) then createDirectory(dir) end
    local f, err = io.open(CONFIG_PATH, 'w')
    if not f then
        print('[Report Desk] save: ' .. tostring(err))
        return false
    end

    f:write('return {\n')
    f:write('  settings = {\n')
    f:write(string.format('    hotkey = %d,\n', settings.hotkey or vkeys.VK_F7))
    f:write(string.format('    sound = %s,\n', settings.sound and 'true' or 'false'))
    f:write(string.format('    auto_only_unread = %s,\n', settings.auto_only_unread and 'true' or 'false'))
    f:write(string.format('    watch_notify = %s,\n', luaQuoteUtf8(settings.watch_notify or 'see')))
    f:write(string.format('    watch_auto_notify = %s,\n', settings.watch_auto_notify ~= false and 'true' or 'false'))
    f:write(string.format('    gg_reply = %s,\n', luaQuoteUtf8(getGgReplyText())))
    f:write(string.format('    tech_reply = %s,\n', luaQuoteUtf8(getTechReplyText())))
    f:write(string.format('    auto_rules_enabled = %s,\n', settings.auto_rules_enabled ~= false and 'true' or 'false'))
    f:write(string.format('    auto_time_enabled = %s,\n', settings.auto_time_enabled ~= false and 'true' or 'false'))
    f:write(string.format('    auto_gg_enabled = %s,\n', settings.auto_gg_enabled ~= false and 'true' or 'false'))
    f:write(string.format('    time_reply = %s,\n', luaQuoteUtf8(getTimeReplyText())))
    f:write(string.format('    ingest_srv_any_color = %s,\n', settings.ingest_srv_any_color and 'true' or 'false'))
    f:write(string.format('    profanity_filter_enabled = %s,\n', settings.profanity_filter_enabled and 'true' or 'false'))
    f:write(string.format('    profanity_filter_sound = %s,\n', settings.profanity_filter_sound ~= false and 'true' or 'false'))
    f:write(string.format('    profanity_filter_chat = %s,\n', settings.profanity_filter_chat and 'true' or 'false'))
    f:write(string.format('    remote_chat_samp_mirror = %s,\n', settings.remote_chat_samp_mirror ~= false and 'true' or 'false'))
    f:write(string.format('    admin_level = %d,\n', getLocalAdminLevel()))
    f:write(string.format('    skin_radius = %d,\n', tonumber(settings.skin_radius) or 20))
    f:write(string.format('    skin_apply_delay_ms = %d,\n', tonumber(settings.skin_apply_delay_ms) or 1200))
    f:write(string.format('    veh_spawn_count = %d,\n', tonumber(settings.veh_spawn_count) or 1))
    f:write(string.format('    veh_grid_rows = %d,\n', tonumber(settings.veh_grid_rows) or 1))
    f:write(string.format('    veh_grid_cols = %d,\n', tonumber(settings.veh_grid_cols) or 5))
    f:write(string.format('    veh_color1 = %d,\n', tonumber(settings.veh_color1) or 0))
    f:write(string.format('    veh_color2 = %d,\n', tonumber(settings.veh_color2) or 0))
    f:write(string.format('    spectate_hud = %s,\n', settings.spectate_hud ~= false and 'true' or 'false'))
    f:write(string.format('    spectate_auto_st = %s,\n', settings.spectate_auto_st ~= false and 'true' or 'false'))
    f:write(string.format('    spectate_auto_refresh = %s,\n', settings.spectate_auto_refresh ~= false and 'true' or 'false'))
    f:write(string.format('    spectate_hud_persist = %s,\n', settings.spectate_hud_persist ~= false and 'true' or 'false'))
    f:write(string.format('    spectate_sp_menu_sound = %s,\n', settings.spectate_sp_menu_sound == true and 'true' or 'false'))
    f:write(string.format('    spectate_hud_x = %d,\n', math.floor(tonumber(settings.spectate_hud_x) or 14)))
    f:write(string.format('    spectate_hud_y = %d,\n', math.floor(tonumber(settings.spectate_hud_y) or 120)))
    f:write(string.format('    spectate_hud_layout_v2 = %s,\n', settings.spectate_hud_layout_v2 and 'true' or 'false'))
    f:write(string.format('    spectate_sp_ui = %s,\n', settings.spectate_sp_ui ~= false and 'true' or 'false'))
    f:write(string.format('    spectate_sp_ui_custom = %s,\n', settings.spectate_sp_ui_custom == true and 'true' or 'false'))
    f:write(string.format('    spectate_sp_ui_x = %d,\n', math.floor(tonumber(settings.spectate_sp_ui_x) or -28)))
    f:write(string.format('    spectate_sp_ui_y = %d,\n', math.floor(tonumber(settings.spectate_sp_ui_y) or 0)))
    f:write(string.format('    spectate_sp_ui_layout_v2 = %s,\n', settings.spectate_sp_ui_layout_v2 and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud = %s,\n', settings.spectate_vehicle_hud ~= false and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud_x = %d,\n', math.floor(tonumber(settings.spectate_vehicle_hud_x) or -24)))
    f:write(string.format('    spectate_vehicle_hud_y = %d,\n', math.floor(tonumber(settings.spectate_vehicle_hud_y) or -132)))
    f:write(string.format('    spectate_vehicle_hud_custom = %s,\n', settings.spectate_vehicle_hud_custom == true and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud_layout_v2 = %s,\n', settings.spectate_vehicle_hud_layout_v2 and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud_layout_v3 = %s,\n', settings.spectate_vehicle_hud_layout_v3 and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud_layout_v4 = %s,\n', settings.spectate_vehicle_hud_layout_v4 and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud_layout_v5 = %s,\n', settings.spectate_vehicle_hud_layout_v5 and 'true' or 'false'))
    f:write(string.format('    spectate_vehicle_hud_layout_v6 = %s,\n', settings.spectate_vehicle_hud_layout_v6 and 'true' or 'false'))
    f:write(string.format('    spectate_keys_hud = %s,\n', settings.spectate_keys_hud ~= false and 'true' or 'false'))
    if settings.spectate_keys_hud_x ~= nil then
        f:write(string.format('    spectate_keys_hud_x = %d,\n', math.floor(tonumber(settings.spectate_keys_hud_x) or 0)))
    end
    if settings.spectate_keys_hud_y ~= nil then
        f:write(string.format('    spectate_keys_hud_y = %d,\n', math.floor(tonumber(settings.spectate_keys_hud_y) or -100)))
    end
    f:write(string.format('    spectate_keys_hud_custom = %s,\n', settings.spectate_keys_hud_custom == true and 'true' or 'false'))
    f:write(string.format('    spectate_wheel_zoom = %s,\n', settings.spectate_wheel_zoom ~= false and 'true' or 'false'))
    f:write(string.format('    checker_hud = %s,\n', settings.checker_hud ~= false and 'true' or 'false'))
    f:write(string.format('    checker_hud_persist = %s,\n', settings.checker_hud_persist ~= false and 'true' or 'false'))
    f:write(string.format('    checker_hud_x = %d,\n', math.floor(tonumber(settings.checker_hud_x) or 8)))
    f:write(string.format('    checker_hud_y = %d,\n', math.floor(tonumber(settings.checker_hud_y) or 8)))
    f:write(string.format('    checker_hud_h = %d,\n', math.floor(tonumber(settings.checker_hud_h) or 160)))
    f:write(string.format('    checker_show_admins = %s,\n', settings.checker_show_admins ~= false and 'true' or 'false'))
    f:write(string.format('    checker_show_leaders = %s,\n', settings.checker_show_leaders ~= false and 'true' or 'false'))
    f:write(string.format('    checker_show_friends = %s,\n', settings.checker_show_friends ~= false and 'true' or 'false'))
    f:write(string.format('    checker_notify_join = %s,\n', settings.checker_notify_join ~= false and 'true' or 'false'))
    f:write(string.format('    checker_notify_quit = %s,\n', settings.checker_notify_quit ~= false and 'true' or 'false'))
    f:write(string.format('    checker_notify_sound = %s,\n', settings.checker_notify_sound ~= false and 'true' or 'false'))
    f:write(string.format('    checker_notify_leader_join = %s,\n', settings.checker_notify_leader_join == true and 'true' or 'false'))
    f:write(string.format('    checker_notify_leader_quit = %s,\n', settings.checker_notify_leader_quit == true and 'true' or 'false'))
    f:write(string.format('    checker_auto_sync = %s,\n', settings.checker_auto_sync == true and 'true' or 'false'))
    f:write(string.format('    checker_auto_promote = %s,\n', settings.checker_auto_promote ~= false and 'true' or 'false'))
    f:write(string.format('    checker_auto_admin = %s,\n', settings.checker_auto_admin ~= false and 'true' or 'false'))
    f:write(string.format('    checker_dev_rpc_probe = %s,\n', settings.checker_dev_rpc_probe == true and 'true' or 'false'))
    ensureCheatsSettings()
    local ch = settings.cheats
    f:write('    cheats = {\n')
    f:write(string.format('      gm_on_start = %s,\n', ch.gm_on_start and 'true' or 'false'))
    f:write(string.format('      wh_on_start = %s,\n', ch.wh_on_start and 'true' or 'false'))
    f:write(string.format('      ab_speed = %.3f,\n', tonumber(ch.ab_speed) or 0.5))
    f:write(string.format('      show_hud = %s,\n', ch.show_hud ~= false and 'true' or 'false'))
    f:write(string.format('      marker_wheel = %s,\n', ch.marker_wheel ~= false and 'true' or 'false'))
    f:write(string.format('      gm_key1 = %d,\n', tonumber(ch.gm_key1) or 0))
    f:write(string.format('      gm_key2 = %d,\n', tonumber(ch.gm_key2) or 0))
    f:write(string.format('      gm_ctrl = %s,\n', ch.gm_ctrl and 'true' or 'false'))
    f:write(string.format('      gm_shift = %s,\n', ch.gm_shift and 'true' or 'false'))
    f:write(string.format('      gm_alt = %s,\n', ch.gm_alt and 'true' or 'false'))
    f:write(string.format('      wh_key1 = %d,\n', tonumber(ch.wh_key1) or 0))
    f:write(string.format('      wh_key2 = %d,\n', tonumber(ch.wh_key2) or 0))
    f:write(string.format('      wh_ctrl = %s,\n', ch.wh_ctrl and 'true' or 'false'))
    f:write(string.format('      wh_shift = %s,\n', ch.wh_shift and 'true' or 'false'))
    f:write(string.format('      wh_alt = %s,\n', ch.wh_alt and 'true' or 'false'))
    f:write(string.format('      ab_key1 = %d,\n', tonumber(ch.ab_key1) or 0))
    f:write(string.format('      ab_key2 = %d,\n', tonumber(ch.ab_key2) or 0))
    f:write(string.format('      ab_ctrl = %s,\n', ch.ab_ctrl and 'true' or 'false'))
    f:write(string.format('      ab_shift = %s,\n', ch.ab_shift and 'true' or 'false'))
    f:write(string.format('      ab_alt = %s,\n', ch.ab_alt and 'true' or 'false'))
    f:write(string.format('      marker_key1 = %d,\n', tonumber(ch.marker_key1) or 0))
    f:write(string.format('      marker_key2 = %d,\n', tonumber(ch.marker_key2) or 0))
    f:write(string.format('      marker_ctrl = %s,\n', ch.marker_ctrl and 'true' or 'false'))
    f:write(string.format('      marker_shift = %s,\n', ch.marker_shift and 'true' or 'false'))
    f:write(string.format('      marker_alt = %s,\n', ch.marker_alt and 'true' or 'false'))
    f:write(string.format('      tp_key1 = %d,\n', tonumber(ch.tp_key1) or 0))
    f:write(string.format('      tp_key2 = %d,\n', tonumber(ch.tp_key2) or 0))
    f:write(string.format('      tp_ctrl = %s,\n', ch.tp_ctrl and 'true' or 'false'))
    f:write(string.format('      tp_shift = %s,\n', ch.tp_shift and 'true' or 'false'))
    f:write(string.format('      tp_alt = %s,\n', ch.tp_alt and 'true' or 'false'))
    f:write(string.format('      veh_key1 = %d,\n', tonumber(ch.veh_key1) or 0))
    f:write(string.format('      veh_key2 = %d,\n', tonumber(ch.veh_key2) or 0))
    f:write(string.format('      veh_ctrl = %s,\n', ch.veh_ctrl and 'true' or 'false'))
    f:write(string.format('      veh_shift = %s,\n', ch.veh_shift and 'true' or 'false'))
    f:write(string.format('      veh_alt = %s,\n', ch.veh_alt and 'true' or 'false'))
    f:write(string.format('      hud_x = %d,\n', math.floor(tonumber(ch.hud_x) or 12)))
    f:write(string.format('      hud_y = %d,\n', math.floor(tonumber(ch.hud_y) or 80)))
    f:write('    },\n')
    f:write('  },\n')

    if type(settings.report_colors) == 'table' and #settings.report_colors > 0 then
        f:write('  report_colors = {\n')
        for _, c in ipairs(settings.report_colors) do
            f:write(string.format('    %d,\n', tonumber(c) or 0))
        end
        f:write('  },\n')
    end

    f:write('  -- scenarios: admin_report_desk_user.lua (UTF-8)\n')

    f:write('  threads = {\n')
    for key, t in pairs(threads) do
        f:write(string.format('    [%q] = {\n', key))
        f:write(string.format('      id = %d,\n', tonumber(t.id) or 0))
        f:write(string.format('      nick = %q,\n', t.nick or ''))
        if t.lastId and t.lastId ~= t.id then
            f:write(string.format('      lastId = %d,\n', tonumber(t.lastId) or 0))
        end
        f:write(string.format('      status = %q,\n', t.status or 'open'))
        f:write(string.format('      pinned = %s,\n', t.pinned and 'true' or 'false'))
        f:write(string.format('      unread = %d,\n', t.unread or 0))
        f:write(string.format('      lastAt = %d,\n', t.lastAt or 0))
        f:write('      messages = {\n')
        for _, m in ipairs(t.messages or {}) do
            f:write(string.format(
                '        { dir = %q, text = %s, ts = %d',
                m.dir or 'in', luaQuoteUtf8(m.text or ''), m.ts or 0
            ))
            if m.kind then
                f:write(string.format(', kind = %q', m.kind))
            end
            if m.self ~= nil then
                f:write(string.format(', self = %s', m.self and 'true' or 'false'))
            end
            if m.adminNick then
                f:write(string.format(', adminNick = %s', luaQuoteUtf8(m.adminNick)))
            end
            if m.note then
                f:write(string.format(', note = %s', luaQuoteUtf8(m.note)))
            end
            f:write(' },\n')
        end
        f:write('      },\n')
        f:write('    },\n')
    end
    f:write('  },\n')
    f:write('}\n')
    f:close()
    dirtySettings = false
    dirtyThreads = false
    return true
end

-- Is Excluded Chat Line
function isExcludedChatLine(text)
    if not text or text == '' then return true end
    if text:find('^%[A%]', 1) then return true end
    if text:match('^%[%d+:%d+:%d+%]') then return true end
    if text:find(L_SKIP_ADMINS, 1, true) then return true end
    if text:find(L_ADMINS_ONLINE, 1, true) then return true end
    if text:find(L_ADMIN_FOR, 1, true) then return true end
    if text:find(MSG_PREFIX_PLAIN, 1, true) then return true end
    if deskIngest.looksLikePlayerStatusLine and deskIngest.looksLikePlayerStatusLine(text) then
        return true
    end
    if deskIngest.looksLikePlayerStatusBody then
        local body = text:match('^[%w][%w_]+%[%d+%]%s*:?%s*(.+)$')
        if body and deskIngest.looksLikePlayerStatusBody(body) then return true end
    end
    return false
end

-- Is Valid Player Nick
function isValidPlayerNick(nick)
    if not nick or nick == '' then return false end
    if nick:find('[', 1, true) or nick:find(']', 1, true) then return false end
    if nick:find('{', 1, true) or nick:find(' ', 1, true) then return false end
    if nick:find(':', 1, true) then return false end
    if #nick < 1 or #nick > 32 then return false end
    if not nick:match('^[%w_]+$') and not nick:match('^[%w_%d]+$') then
        if not nick:match('^[%w_][%w_%-%.]*$') then return false end
    end
    return true
end

