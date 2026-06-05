# Admin Report Desk — распространение и автообновление

## Идея

| Файл | Кто видит | Назначение |
|------|-----------|------------|
| `admin_report_desk.lua` | Текст (launcher) | Проверка версии на GitHub, скачивание ядра, запуск |
| `report_desk_autoupdate.lua` | Текст | Логика update (можно править URL) |
| `report_desk/admin_report_desk_core.luac` | Байткод | Весь скрипт в одном файле |
| `config/admin_report_desk_user.lua` | У пользователя | **Не трогаем** при обновлении |

Разработка у вас — как сейчас: отдельные `.lua` в корне moonloader.  
Пользователям отдаёте содержимое `dist/` после сборки.

## Один раз: настройка GitHub

1. Создайте репозиторий (публичный).
2. В `release/repo.config.json` укажите:

```json
{
  "github_owner": "illusshion",
  "github_repo": "report_desk_helper",
  "branch": "main",
  "release_tag_prefix": "v"
}
```

3. Соберите релиз:

```powershell
cd "C:\Program Files (x86)\Advance Games\moonloader\tools"
.\build_release.ps1 -Version 3.35.2
```

4. На GitHub → **Releases** → тег `v3.35.2`:
   - прикрепите `dist\report_desk\admin_report_desk_core.luac`
   - прикрепите `dist\report_desk_helper_main.zip` (установочный архив)
5. Закоммитьте в репозиторий `release/version.json` (обновится скриптом сборки).

Пользователь при каждом запуске качает `release/version.json` с raw.githubusercontent.com, сравнивает версию с `script_version` launcher'а и при необходимости качает новый `.luac`.

> **Кэш GitHub:** raw-файлы иногда обновляются с задержкой 1–5 минут после push. Для `core.luac` используйте **GitHub Releases** (ссылка в `core_url`), там кэша почти нет.

## Установка у админа

1. Распаковать zip в папку **moonloader** (не в подпапку):
   - `admin_report_desk.lua`
   - `report_desk_autoupdate.lua`
   - `report_desk\admin_report_desk_core.luac` (или скачается при первом входе в игру)
2. Папки `config\`, `res\` — по желанию (сценарии, скины DDS, ТС).
3. `/reload` или перезапуск игры.

Первый запуск без `.luac`: launcher сам скачает ядро с URL из `version.json`.

## Luac

Нужен **Lua 5.1** `luac` (как у MoonLoader 0.26):

- положите `luac.exe` в корень moonloader, или
- добавьте в PATH.

Если `luac` нет — сборка создаёт `admin_report_desk_core.lua`; launcher умеет грузить и `.lua`, и `.luac`.

Только bundle без релиза:

```powershell
.\bundle_report_desk.ps1
```

## Что не входит в core (остаётся у пользователя)

- `config/admin_report_desk_user.lua` — сценарии и автоответы
- `config/admin_report_desk.lua` — настройки окна
- `res/report_desk_skins/`, `res/report_desk_vehicles/` — превью (PNG/DDS)

Обновление ядра **не перезаписывает** user config.

## Новая версия для всех

1. Правите исходники, поднимаете `script_version` в `admin_report_desk.lua`.
2. `.\build_release.ps1 -Version X.Y.Z`
3. GitHub Release + push `release/version.json`.
4. Игроки получают update при следующем заходе в игру (launcher reload).

## Структура dist после сборки

```
dist/
  admin_report_desk.lua          ← launcher (копия stub)
  report_desk_autoupdate.lua
  report_desk/
    admin_report_desk_core.lua   ← для отладки / без luac
    admin_report_desk_core.luac  ← для пользователей
  report_desk_helper_main.zip
```

## Разработка vs прод

| Режим | Файлы в moonloader |
|-------|-------------------|
| **Вы (dev)** | `admin_report_desk.lua` + все `report_desk_*.lua` как сейчас |
| **Пользователи** | launcher + `report_desk_autoupdate.lua` + `report_desk\*.luac` |

Не кладите одновременно полный `admin_report_desk.lua` (dev) и launcher с тем же именем — будет конфликт. Для dev переименуйте launcher или отключите его в `moonloader.cfg`.
