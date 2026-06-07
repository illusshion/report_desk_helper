# Admin Report Desk — распространение и автообновление

## Идея

| Файл | Кто видит | Назначение |
|------|-----------|------------|
| `admin_report_desk.lua` | Текст (launcher) | Проверка версии на GitHub, скачивание ядра, запуск |
| `report_desk_autoupdate.lua` | Текст | Логика update |
| `report_desk_deps.lua` | Текст | mimgui и зависимости |
| `report_desk/admin_report_desk_core.lua` | Текст/байткод | Весь скрипт в одном bundle |
| `config/admin_report_desk_user.lua` | У пользователя | **Не трогаем** при обновлении ядра |

Разработка — отдельные `lib/report_desk_*.lua` + `admin_report_desk.lua` (dev entry).  
Пользователям — содержимое `dist/report_desk_helper_main.zip` после сборки.

## Версии

| Где | Пример | Назначение |
|-----|--------|------------|
| `admin_report_desk.lua` | `3.98.40` | Локальная dev-версия, **не для пользователей** |
| `tools/admin_report_desk_stub.lua` | `1.0.8` | Release-версия launcher + manifest |
| `release/version.json` | `1.0.8` | То, что видят админы при автообновлении |

## Один раз: настройка GitHub

В `release/repo.config.json`:

```json
{
  "github_owner": "illusshion",
  "github_repo": "report_desk_helper",
  "branch": "main",
  "release_tag_prefix": "v"
}
```

## Сборка релиза (автоматизированный пайплайн)

```powershell
cd "C:\Program Files (x86)\Advance Games\moonloader\tools"

# 1. Поднять script_version в tools\admin_report_desk_stub.lua
# 2. Записать CHANGELOG.md

.\publish_release.ps1 -Version 1.0.9 -Changelog "..." -SkipLuac -GitCommit
git push origin main
```

Скрипт делает:
1. `bundle_report_desk.ps1` — собирает core из всех `lib/report_desk_*.lua`
2. Пишет `release/version.json` (core_url + fallback + zip_url)
3. Копирует core в `report_desk/` (raw fallback на main)
4. Собирает `dist/report_desk_helper_main.zip` (launcher, autoupdate, deps, mimgui, config, res)
5. **Проверяет:** dist core = repo core = core внутри zip; версии совпадают
6. Пишет `release/build_manifest.json` с SHA256 для загрузки на GitHub

### Публикация на GitHub (строго по порядку)

1. `git push origin main` — **до** создания Release (fallback core на main должен совпадать)
2. GitHub → **Releases** → тег `v1.0.9`
3. Прикрепить из `dist/` (сверить SHA256 с `release/build_manifest.json`):
   - `report_desk\admin_report_desk_core.lua` (или `.luac`)
   - `report_desk_helper_main.zip`

> **Кэш GitHub:** raw-файлы обновляются с задержкой 1–5 мин после push. Release assets кэшируются меньше.

## Установка у админа

1. Распаковать `report_desk_helper_main.zip` в **moonloader** (не в подпапку)
2. `/reload` или перезапуск игры

Первый запуск: launcher проверит manifest и при необходимости скачает свежее ядро.

## Luac

Нужен **Lua 5.1** `luac` (как у MoonLoader 0.26) — положить `luac.exe` в корень moonloader.

Без `luac` сборка отдаёт `.lua` (флаг `-SkipLuac` или автоматически). Launcher грузит и `.lua`, и `.luac`.

## Что обновляется автоматически vs вручную

| Компонент | Автообновление ядра | Нужен новый zip |
|-----------|---------------------|-----------------|
| `report_desk/admin_report_desk_core.*` | Да | — |
| `lib/report_desk_*.lua` (внутри core) | Да (через core) | — |
| `admin_report_desk.lua` (launcher) | Нет | Да |
| `report_desk_autoupdate.lua` | Нет | Да |
| `report_desk_deps.lua` | Нет | Да |
| `lib/mimgui/` | Нет | Да |
| `config/`, `res/` | Нет (сохраняются) | Только если нужны новые дефолты |

## Что не входит в core (остаётся у пользователя)

- `config/admin_report_desk_user.lua` — сценарии и автоответы
- `config/admin_report_desk.lua` — настройки окна
- `res/report_desk_skins/`, `res/report_desk_vehicles/` — превью

## Структура dist после сборки

```
dist/
  admin_report_desk.lua
  report_desk_autoupdate.lua
  report_desk_deps.lua
  report_desk/
    admin_report_desk_core.lua
    admin_report_desk_core.luac   (если есть luac)
  report_desk_helper_main.zip
release/
  version.json
  build_manifest.json             ← SHA256 для проверки перед upload
```

## Разработка vs прод

| Режим | Файлы в moonloader |
|-------|-------------------|
| **Dev** | `admin_report_desk.lua` + `lib/report_desk_*.lua` |
| **Пользователи** | launcher + autoupdate + deps + `report_desk\core.*` |

Переключение dev ↔ prod: `tools\desk_switch.ps1 -User` / `-Dev`

Не кладите одновременно dev-entry и launcher с именем `admin_report_desk.lua`.

## Типичные ошибки (исправлены в пайплайне)

- Собрали Release, но не запушили core на `main` → fallback отдаёт старый код
- Залили на GitHub не те файлы из `dist/` → `build_manifest.json` для сверки SHA256
- `assume-unchanged` на core скрывал незакоммиченные изменения → снимается при сборке
- `bundle` без `build_release` → нет verify и рассинхрон версий
