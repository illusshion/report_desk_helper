# Report Desk Helper

Admin Report Desk для GTA SA / MTA (MoonLoader): репорты, автоответы, спектейт, чекер, каталог скинов/ТС.

Репозиторий: [github.com/illusshion/report_desk_helper](https://github.com/illusshion/report_desk_helper)

## Быстрая установка (другому админу)

1. Скачать **последний** [Release](https://github.com/illusshion/report_desk_helper/releases) → `report_desk_helper_main.zip`
2. Распаковать **в папку moonloader** (рядом с `lib`, не в подпапку)
3. Зайти в игру — launcher сам подтянет ядро при необходимости

**В zip уже есть:**
- launcher + autoupdate + deps + ядро
- `lib/mimgui/` — UI-библиотека
- `config/` — базовые настройки + **все сценарии и автоответы** (редактируются локально)
- `res/report_desk_skins/`, `res/report_desk_vehicles/` — превью для каталогов

**При автообновлении ядра не трогается:** `config/`, `res/`, launcher, autoupdate, deps — только `report_desk\admin_report_desk_core.*`.

Если в релизе менялись launcher / autoupdate / deps / mimgui — админу нужен **новый zip**, не только автообновление ядра.

## Как работает автообновление

| Файл | Где |
|------|-----|
| `release/version.json` | Ветка `main` на GitHub (manifest) |
| `admin_report_desk_core.lua` / `.luac` | GitHub Releases (ядро) + raw fallback на `main` |
| `report_desk_helper_main.zip` | GitHub Releases (полная установка) |

Launcher при старте читает manifest, сравнивает версию и качает новое ядро.

## Релиз новой версии (для тебя)

Версия для пользователей — в **`tools/admin_report_desk_stub.lua`** (`script_version`, сейчас линия `1.x.x`).  
Версия в `admin_report_desk.lua` (`3.xx`) — только для локальной разработки.

```powershell
cd "C:\Program Files (x86)\Advance Games\moonloader\tools"

# 1. Поднять script_version в tools\admin_report_desk_stub.lua
# 2. Записать изменения в CHANGELOG.md

.\publish_release.ps1 -Version 1.0.9 -Changelog "..." -SkipLuac -GitCommit
git push origin main
```

Дальше на GitHub → **Releases** → тег `v1.0.9` → прикрепить **ровно** (SHA256 в `release\build_manifest.json`):

- `dist\report_desk\AdminDeskCore.lua` (или `.luac` через `tools\luajit-compiler\luajit\luajit.exe -b`)
- `dist\report_desk_helper_main.zip`

**Порядок важен:** сначала `git push main` (чтобы fallback core на main совпадал с Release), потом создать Release.

## Разработка (локально)

| Режим | Файлы |
|-------|--------|
| **Dev** | `admin_report_desk.lua` + модули `lib/report_desk_*.lua` |
| **Пользователи** | launcher stub + `report_desk_autoupdate.lua` + `report_desk_deps.lua` + `report_desk\admin_report_desk_core.*` |

Не держи одновременно dev-entry и launcher с одним именем `admin_report_desk.lua`.

Сборка bundle без релиза (только для отладки):

```powershell
.\bundle_report_desk.ps1
```

Полный релиз (bundle + verify + zip + manifest):

```powershell
.\build_release.ps1 -Version 1.0.9 -SkipLuac
```

## Требования

- **MoonLoader 0.26+** + **SAMP** + **SAMPFUNCS**
- **mimgui** — уже в zip (`lib/mimgui/`); если нет, `report_desk_deps.lua` скачает при первом запуске

## Структура

```
lib/report_desk_*.lua      — исходники (dev)
tools/admin_report_desk_stub.lua — launcher (источник)
lib/report_desk_autoupdate.lua   — логика update
lib/report_desk_deps.lua         — mimgui и зависимости
release/version.json       — manifest для клиентов
release/build_manifest.json — SHA256 артефактов последней сборки
report_desk/admin_report_desk_core.lua — bundled core (git fallback)
tools/                     — bundle, build, publish
```
