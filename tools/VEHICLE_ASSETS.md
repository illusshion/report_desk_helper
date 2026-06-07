# Report Desk — превью транспорта (качественные PNG)

Цель: превью как у скинов (`res/report_desk_skins/`), без мелких JPG-заглушек.

## Структура папок

```
res/report_desk_vehicles/
  veh-400.png              # основной файл (приоритет)
  overrides/
    veh-411.png            # ручная замена (высший приоритет)
  vehicles_index.lua       # каталог (имя, категория, file)
  vehicles_manifest.csv    # отчёт скрипта manifest
```

## Требования к файлу

| Параметр | Минимум | Рекомендуется |
|----------|---------|---------------|
| Формат | PNG-24 | PNG |
| Ширина | 128 px | 256 px |
| Высота | 80 px | 160 px |
| Размер файла | ≥ 8 KB | 20–80 KB |
| Фон | прозрачный или тёмный единый | как на adv-rp skins |

Файлы `< 8 KB` помечаются в UI как низкое качество (`~` на кнопке).

## Где искать картинки (вручную)

1. **MTA Wiki** — ищите крупное превью, не thumb 32×32.
2. **Рендеры GTA SA** — OpenGameArt, GTAMods (проверьте лицензию).
3. **Скриншот в игре** — F8 + обрезка до 256×160 в IrfanView / GIMP.
4. **Не использовать** старые `veh-*.jpg` с wiki (~3 KB) — только временный fallback.

## Установка

1. Сохраните PNG как `veh-{ID}.png` (ID 400–611).
2. Или положите в `overrides/veh-{ID}.png` для приоритетной замены.
3. Запустите проверку:

```powershell
powershell -ExecutionPolicy Bypass -File "c:\Program Files (x86)\Advance Games\moonloader\tools\vehicle_assets_manifest.ps1"
```

4. Перезагрузите MoonLoader / Report Desk.

## Обновление index

После добавления PNG обновите `vehicles_index.lua` вручную или перегенерируйте строки в manifest CSV.
