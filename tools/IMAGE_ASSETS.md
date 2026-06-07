# Report Desk — ассеты превью

## Формат

- **Скины и ТС:** PNG (JPG для ТС — fallback, помечается как низкое качество).
- DDS не используется в рантайме.

## В игре

- [`report_desk_tex_pipeline.lua`](../lib/report_desk_tex_pipeline.lua) — чтение PNG в фоне, upload в GPU по бюджету.
- Загрузка только видимых ячеек + выбранный ID на активной вкладке.
- LRU-кэш: 72 скина / 48 ТС.

## Папки

| Каталог | Путь |
|---------|------|
| Скины | `res\report_desk_skins\skin-{id}.png` |
| ТС | `res\report_desk_vehicles\veh-{id}.png` |
| Overrides ТС | `res\report_desk_vehicles\overrides\` |

## Оптимизация (офлайн, по желанию)

Сожми PNG у себя (oxipng, pngquant, ImageMagick) и положи обратно в `res\`.
Рекомендуемый размер: 128–256 px по длинной стороне.

```powershell
# опционально
.\tools\optimize_skins.ps1
```

Оригиналы для ручного сжатия — копия на рабочем столе: `ReportDesk_Assets_Originals`.
