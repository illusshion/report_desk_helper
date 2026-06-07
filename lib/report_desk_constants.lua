--[[ Модуль: глобальные константы Report Desk (пути, интервалы, лимиты UI, profanity). ]]
-- Без local: bundle core — один Lua-chunk (лимит 200 locals). Поля env, не locals.

-- Цвет SAMP-сообщения репорта [PC]/[S]/[M] (ARGB uint32).
REPORT_COLOR = 1724645631
REPORT_COLORS = {
    [1724645631] = true,
}

CONFIG_PATH = getWorkingDirectory() .. '\\config\\admin_report_desk.lua'
USER_CONFIG_PATH = getWorkingDirectory() .. '\\config\\admin_report_desk_user.lua'
USER_CONFIG_BACKUP = getWorkingDirectory() .. '\\config\\admin_report_desk_user.bak.lua'
SCENARIO_LEARN_PATH = getWorkingDirectory() .. '\\config\\scenario_learn.lua'
CHECKER_CATALOG_PATH = getWorkingDirectory() .. '\\config\\report_desk_checker_catalog.lua'
CHECKER_CATALOG_BACKUP = getWorkingDirectory() .. '\\config\\report_desk_checker_catalog.bak.lua'
SKINS_DIR = getWorkingDirectory() .. '\\res\\report_desk_skins\\'

SKIN_TEX_CACHE_MAX = 72      -- макс. skin-текстур в GPU-кэше
VEH_TEX_CACHE_MAX = 48       -- макс. vehicle-текстур в GPU-кэше
TEX_STAGING_MAX = 16         -- очередь staging перед upload
CATALOG_GPU_BUDGET = 5       -- текстур за tick каталога
CATALOG_IO_IDLE_MS = 12      -- пауза IO-потока каталога, мс
SKIN_MAX_FILE_BYTES = 512000 -- лимит размера PNG скина, байт
TEX_NS_SKIN = 'skin'         -- namespace tex pipeline для скинов
SKIN_NEARBY_CACHE_SEC = 0.6  -- кэш списка игроков в радиусе, сек
SKIN_SIDEBAR_W = 210         -- ширина sidebar каталога скинов, px
SKIN_THUMB_W, SKIN_THUMB_H = 68, 85
SKIN_THUMB_ASPECT = SKIN_THUMB_H / SKIN_THUMB_W
SKIN_PREVIEW_W, SKIN_PREVIEW_H = 168, 210

AUTOSAVE_SETTINGS_INTERVAL = 150  -- автосохранение настроек, сек
AUTOSAVE_THREADS_INTERVAL = 600   -- автосохранение тредов репортов, сек
PRUNE_MAP_INTERVAL = 90           -- очистка timed maps (dedup/seen), сек
INGEST_DEDUP_SEC = 3.0            -- dedup ingest одной строки, сек

-- Poll чата (fallback, если hook onServerMessage не сработал).
POLL_INTERVAL = 0.06              -- окно Report Desk открыто, сек
POLL_INTERVAL_CLOSED = 0.12       -- окно закрыто, сек
POLL_INTERVAL_HOOK = 0.20         -- hook активен, окно открыто
POLL_INTERVAL_CLOSED_HOOK = 0.50  -- hook активен, окно закрыто
CHAT_POLL_LINES_OPEN = 100        -- строк sampGetChatString при открытом окне
CHAT_POLL_LINES_CLOSED = 40
CHAT_POLL_LINES_HOOK = 24         -- меньше строк при активном hook
CHAT_POLL_LINES_CLOSED_HOOK = 16
DESK_OPEN_WARMUP_SEC = 0.25       -- после открытия окна — лёгкий poll, без тяжёлого burst
DESK_OPEN_POLL_LINES = 16         -- строк poll в warmup (вместо CHAT_POLL_LINES_OPEN)
HOOK_HEALTH_CHECK_INTERVAL = 30.0 -- переустановка SAMP hooks, сек

WIN_W, WIN_H = 980, 640           -- размер главного окна Report Desk, px
SESSION_WARMUP = 0
MAX_SEEN_LINES = 400                -- лимит chatSeen.lines
MAX_CONSUMED_REPORT_LINES = 1500
MAX_TIMED_MAP_ENTRIES = 512
TIMED_MAP_MAX_AGE = 120           -- возраст записи timed map, сек
DEFAULT_MAX_THREADS = 300           -- лимит тредов репортов в памяти
DEFAULT_HISTORY_LIMIT = 100         -- сообщений на тред; старые обрезаются автоматически

-- Profanity filter / dedup (PF = profanity).
PF = {
    SOUND = 1083,              -- GTA sound id уведомления
    SOUND_FE = 14,             -- frontend sound
    ALERT_COLOR = 0xB8B0C8,
    DEDUP_SEC = 300,           -- dedup алерта одного слова, сек
    MIN_WORD_LEN = 2,
    BODY_PREVIEW = 40,
    HOTKEY_CAPTURE_GRACE = 0.2,  -- пауза после capture hotkey, сек
    HOTKEY_TOGGLE_GRACE = 0.18,
}

-- Дальний чат (RC): dedup / rate limits.
RC = {
    DEDUP_SEC = 12.0,
    STATUS_DEDUP_SEC = 180.0,
    INGEST_MAX_PER_SEC = 4,
}

PROFANITY_DICT_MODULE = 'report_desk_profanity_words'

-- Строки чата (CP1251) для фильтра admin reply / checker.
L_SKIP_ADMINS = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0\xFB \xEE\xED\xEB\xE0\xE9\xED:'
L_ADMINS_ONLINE = '\xC0\xE4\xEC\xE8\xED\xFB \xEE\xED\xEB\xE0\xE9\xED:'
L_ADMIN_FOR = '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0'
MSG_PREFIX = '{9E7BEF}[Report Desk] {FFFFFF}'
MSG_PREFIX_PLAIN = '[Report Desk]'
PROFANITY_MSG_PREFIX = '{9E7BEF}[' .. '\xCC\xE0\xF2' .. ']{B0B0B8} '
MAX_PLAYER_ID = 1000  -- верхняя граница scan игроков SAMP
