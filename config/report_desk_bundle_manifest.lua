--[[ Single source of truth for Report Desk bundle chunk lists (dev app + release PS1). ]]
return {
    core_a_a = {
        'report_desk_bootstrap.lua',
        'report_desk_constants.lua',
        'report_desk_theme.lua',
        'report_desk_state.lua',
        'report_desk_util_encoding.lua',
        'report_desk_util.lua',
        'report_desk_match_normalize.lua',
        'report_desk_match_context.lua',
        'report_desk_intent_match.lua',
        'report_desk_intent_legacy.lua',
        'report_desk_intent_extensions.lua',
        'report_desk_intents.lua',
        'report_desk_profanity.lua',
        'report_desk_chat.lua',
        'report_desk_cheats.lua',
        'report_desk_cheats_marker.lua',
        'report_desk_mask_id.lua',
        'report_desk_skins.lua',
        'report_desk_input.lua',
        'report_desk_actions.lua',
        'report_desk_env_export.lua',
    },
    core_a_b = {
        'report_desk_admin_punish.lua',
        'report_desk_threads.lua',
        'report_desk_config.lua',
        'report_desk_ingest_runtime.lua',
        'report_desk_rules.lua',
    },
    core_a_b2 = {
        'report_desk_exact_time.lua',
        'report_desk_temp_leadership.lua',
    },
    core_a_c = {
        'report_desk_ui.lua',
        'report_desk_hooks.lua',
        'report_desk_hooks_sp_menu.lua',
        'report_desk_main.lua',
    },
    -- checker.lua MUST be first: Catalog/CHECKER_HUD_W are chunk locals (Lua forward-ref = global nil).
    late = {
        'report_desk_checker.lua',
        'report_desk_checker_sync.lua',
        'report_desk_checker_hud.lua',
        'report_desk_cmd_binds.lua',
    },
    remote_chat = {
        'report_desk_remote_chat.lua',
    },
}
