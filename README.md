# Report Desk Helper

Admin Report Desk для GTA SA / MTA (MoonLoader): репорты, автоответы, спектейт, чекер, каталог скинов/ТС.

Репозиторий: [github.com/illusshion/report_desk_helper](https://github.com/illusshion/report_desk_helper)

## Быстрая установка (другому админу)

1. Скачать **последний** [Release](https://github.com/illusshion/report_desk_helper/releases) → `AdminReportDesk-X.Y.Z.zip`
2. Распаковать **в папку moonloader** (рядом с `lib`, не в подпапку)
3. Зайти в игру — launcher сам подтянет ядро при необходимости

**В zip уже есть:**
- launcher + autoupdate + ядро
- `config/` — базовые настройки + **все сценарии и автоответы** (редактируются локально)
- `res/report_desk_skins/`, `res/report_desk_vehicles/` — превью для каталогов

**При автообновлении не трогается:** `config/`, `res/` — только ядро в `report_desk\`.

## Как работает автообновление

| Файл | Где |
|------|-----|
| `release/version.json` | Ветка `main` на GitHub (manifest) |
| `admin_report_desk_core.luac` / `.lua` | GitHub Releases (ядро) |

Launcher при старте читает manifest, сравнивает версию и качает новое ядро.

## Релиз новой версии (для тебя)

```powershell
cd "C:\Program Files (x86)\Advance Games\moonloader\tools"

# 1. Поднять версию в admin_report_desk_stub.lua (script_version)
# 2. Записать изменения в CHANGELOG.md

.\publish_release.ps1 -Version 3.49.12 -SkipLuac
```

Дальше:

1. `git add` / `commit` / `push` (в репозиторий уходит `release/version.json` + исходники)
2. GitHub → **Releases** → тег `v3.49.12` → прикрепить:
   - `dist\report_desk\admin_report_desk_core.lua` (или `.luac` если есть `luac.exe`)
   - `dist\AdminReportDesk-3.49.12.zip`

Подробнее: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)

## Разработка (локально)

| Режим | Файлы |
|-------|--------|
| **Dev** | `admin_report_desk.lua` + модули `lib/report_desk_*.lua` |
| **Пользователи** | launcher stub + `report_desk\admin_report_desk_core.*` |

Не держи одновременно dev-entry и launcher с одним именем `admin_report_desk.lua`.

Сборка bundle без релиза:

```powershell
.\bundle_report_desk.ps1
```

## Требования

- MoonLoader 0.26+
- SAMP + SAMPFUNCS + mimgui (как в moonloader)

## Структура

```
lib/report_desk_*.lua   — исходники
admin_report_desk_stub.lua — launcher (→ dist при сборке)
report_desk_autoupdate.lua — логика update
release/version.json  — manifest для клиентов
tools/                — bundle, build, publish
docs/                 — чеклисты и распространение
```
