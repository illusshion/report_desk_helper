# Admin Report Desk — чеклист регрессии

Проверять после каждого этапа рефакторинга в игре (SAMP + MoonLoader 26).

## Панель (F7)

- [ ] F7 открывает/закрывает окно
- [ ] Крестик ImGui закрывает окно (close button)
- [ ] Список тредов, поиск, фильтры
- [ ] Отправка ответа, composer, быстрые кнопки
- [ ] Вкладки: Reports, Auto, Scenarios, Quick, Cheats, Skins, Vehicles, Settings
- [ ] Autosave настроек и тредов

## Спектейт (/sp)

- [ ] `/sp` + панель закрыта — свободная камера, мышь не залипает в CMODE_DISABLED
- [ ] `/sp` + F7 открыт — курсор UI, ввод в чат репорта
- [ ] «Следить» из треда
- [ ] Стрелки spectate HUD, `/st` stats
- [ ] Выход из /sp — камера и курсор в норме

## Ingest / автоответы

- [ ] Новый репорт появляется в списке
- [ ] Автоответы срабатывают по правилам
- [ ] После AFK не уходит «догон» старых репортов
- [ ] Admin actions в треде

## Читы / маркер

- [ ] GM/WH/airbreak, бинды при открытой/закрытой панели
- [ ] Marker wheel, TP, enter vehicle
- [ ] HUD overlays

## Каталоги

- [ ] Скины: превью, warmup, apply
- [ ] ТС: spawn, grid
- [ ] D3D device lost/reset — текстуры восстанавливаются

## Завершение

- [ ] `onScriptTerminate` — нет lockPlayer, курсор не залип
- [ ] Reload скрипта — нет двойных хуков `/sp`
- [ ] Конфиг `config/admin_report_desk.lua` и user config читаются
