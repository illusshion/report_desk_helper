#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Apply scenario fixes from audit to user config files."""
from pathlib import Path

ROOT = Path(r"c:\Program Files (x86)\Advance Games\moonloader\config")
TARGETS = [ROOT / "admin_report_desk_user.default.lua", ROOT / "admin_report_desk_user.lua"]

HEADER = """-- Admin Report Desk user settings (UTF-8)
-- report-desk-user-config: utf-8
-- Scenarios. Auto-reply keywords are built-in; edit toggles/text in Report Desk settings.
return {
  strings = {
    gg_reply = "Хорошей игры на ARP Blue)",
    tech_reply = "Лучше обратитесь в технический раздел на форуме ARP",
    watch_notify = "see",
  },
  composer_quick_buttons = {
    {
      id = "gg",
      label = "GG",
      text = "Хорошей игры на ARP Blue)",
    },
    {
      id = "tech",
      label = "Техничка",
      text = "Лучше обратитесь в технический раздел на форуме ARP",
    },
  },
  quick_scenarios = {
"""

FOOTER = """  },
}
"""

SCENARIOS = [
    dict(
        label="GPS Тир",
        enabled=True, priority=40, skip_if_report_id=True,
        reply="Тир для прокачки скиллов стрельбы: /gps 7-2",
        keywords=["где+тир", "как+качать+скилл", "тир+gps", "скилл+тир", "прокачать+скилл", "качать+скилл",
                  "стрелковый+тир", "спец+тир", "навыки+стрельб", "стрельб+кача", "лучше+в+тире",
                  "навыки+оруж", "прокачивать+навыки+оруж", "владения+оруж"],
    ),
    dict(
        label="GPS Транспортная",
        enabled=True, priority=35, skip_if_report_id=True,
        reply="Транспортная компания (дальнобой): /gps 9",
        keywords=["транспортная+компания", "дальнобойщик", "работ+дальноб", "найти+работу+дальноб", "где+дальноб",
                  "gps+транспорт", "дальнобой+gps", "работа+дальнобой", "устроиться+транспорт",
                  "транспорт+компан+устро", "компан+устроиться", "далтнобойщик", "где+найти+работу+дальноб",
                  "что+гпс+9", "гпс+9"],
    ),
    dict(
        label="GPS Военкомат ЛВ",
        enabled=True, priority=25, skip_if_report_id=True,
        reply="Военкомат в Лас-Вентурас: /gps 1 7",
        keywords=["военкомат", "воинкомат", "военком", "военкомат+лв", "военкомат+гпс"],
    ),
    dict(
        label="Найти отель",
        enabled=True, priority=50, skip_if_report_id=True,
        reply="Список отелей и цены: /price",
        keywords=["где+отель", "как+найти+отель", "отель+gps", "найти+отель", "гостиница+где", "куда+заселиться",
                  "как+посмотреть+отель"],
        negative_keywords=["собес"],
    ),
    dict(
        label="Слёт номера отеля",
        enabled=False, priority=30, skip_if_report_id=True,
        reply="Список отелей и цены: /price",
        keywords=["слетают+номер", "слетают+отел", "во+сколько+отел", "слетают+номера", "слет+отел"],
    ),
    dict(
        label="Слить авто в гос",
        enabled=True, priority=35, skip_if_report_id=True,
        reply="Продать авто в гос: /home /hotel — в меню отеля",
        keywords=["слить+авто", "слить+машину", "слить+тачку", "слить+машин", "сдать+авто", "продать+гос",
                  "сдать+в+гос", "слить+в+гос", "продать+машину+гос", "слить+гос", "продать+государ",
                  "государству+продать", "тачку+в+гос", "машину+вгос"],
    ),
    dict(
        label="Найти свою машину",
        enabled=True, priority=42, skip_if_report_id=True,
        reply="Найти и заспавнить авто: /home /hotel (синяя метка у отеля)",
        keywords=["где+моя+машина", "найти+машину", "где+мой+авто", "найти+свою", "купил+машину+где", "машина+где",
                  "купил+машину+нет", "машины+нет", "машину+нет", "заспавнить+авто", "заспавнить+машин",
                  "спавн+машин", "заспанить+авто", "заспавнить+машину", "пропала+машин", "машина+пропала",
                  "потерял+машин", "пропал+авто", "где+стоит+машин", "cars+не+работ", "купленную+машину",
                  "как+найти+машину", "подогнать+машин", "машину+к+отелю"],
        negative_keywords=["ключ"],
    ),
    dict(
        label="Выселиться из отеля",
        enabled=True, priority=20, skip_if_report_id=True,
        reply="Выселиться: ресепшен отеля на 1 этаже",
        keywords=["выселиться", "выселится", "как+выйти+из+отеля", "покинуть+отель"],
    ),
    dict(
        label="Работа в мэрии",
        enabled=True, priority=44, skip_if_report_id=True,
        reply="Устроиться на работу в мэрии: /gps 1 2 (2 этаж, для граждан)",
        keywords=["работа+мэри", "устроиться+мэри", "работу+мэри", "устроиться+на+работу+мэри", "граждан+мэри",
                  "устроиться+на+работу", "работу+мерии", "мерии", "работа+мерии"],
    ),
    dict(
        label="Автобусник",
        enabled=True, priority=45, skip_if_report_id=True,
        reply="Устроиться автобусником: 2 этаж мэрии, /gps 1",
        keywords=["водитель+автобуса", "автобусник", "автобусником", "работ+автобус", "устроиться+автобус",
                  "работа+автобус", "где+автобусником", "водитель+автобус", "не+водитель+автобус",
                  "начать+автобус", "работать+автобус", "центр+занятости"],
    ),
    dict(
        label="Устроиться таксистом",
        enabled=True, priority=44, skip_if_report_id=True,
        reply="Устроиться таксистом: 2 этаж мэрии, /gps 1",
        keywords=["таксист+устроиться", "устроиться+таксист", "работа+таксист", "работать+таксист",
                  "где+работа+устроиться"],
        negative_keywords=["вызвать+такси", "позвать+такси"],
    ),
    dict(
        label="Вызвать такси",
        enabled=True, priority=48, skip_if_report_id=True,
        reply="Вызвать такси: /c 555",
        keywords=["вызвать+такси", "позвать+такси", "как+вызвать+такси", "такси+вызов", "заказать+такси"],
    ),
    dict(
        label="Анонсы /news",
        enabled=True, priority=40, skip_if_report_id=True,
        reply="Куда идут собеседования: /join /news",
        keywords=["собеседование", "собеседован", "собес", "список+собес", "список+собеседован",
                  "посмотреть+собес", "посмотреть+список+собес", "как+посмотреть+собес", "как+собес",
                  "когда+собес", "анонс+набор", "анонс+собес", "когда+набор", "/news", "куда+собес"],
    ),
    dict(
        label="Набор /join",
        enabled=True, priority=38, skip_if_report_id=True,
        reply="Набор в организацию: /join",
        keywords=["набор+в+орг", "набор+орга", "как+узнать+набор", "где+набор"],
        negative_keywords=["собес"],
    ),
    dict(
        label="Запустить двигатель",
        enabled=True, priority=45, skip_if_report_id=True,
        reply="Запустить/заглушить двигатель: /e или Ctrl",
        keywords=["запустить+двигатель", "завести+мотор", "команда+двигатель", "двигатель+команда", "как+завести",
                  "запуск+мотора", "завести+двигатель", "транспорт+завести", "завести+транспорт"],
    ),
    dict(
        label="Багажник",
        enabled=True, priority=30, skip_if_report_id=True,
        reply="Открыть/закрыть багажник: /b",
        keywords=["багажник", "как+открыть+багажник", "открыть+бак", "задний+бак"],
    ),
    dict(
        label="Ключи от авто /allow",
        enabled=True, priority=41, skip_if_report_id=True,
        reply="Передать ключи от машины: /allow [id]",
        keywords=["передать+ключ", "ключ+машин", "ключи+машин", "ключ+авто", "дать+ключ"],
    ),
    dict(
        label="Продать оружие",
        enabled=True, priority=30, skip_if_report_id=True,
        reply="Передать оружие: /sellgun [id] (только банды)",
        keywords=["передать+оружие", "продать+оружие", "sellgun", "как+передать+оружие"],
        negative_keywords=["лиценз"],
    ),
    dict(
        label="Купить оружие",
        enabled=True, priority=30, skip_if_report_id=True,
        reply="Оружейный магазин: /price",
        keywords=["где+купить+оружие", "купить+оружие", "оружейный+магазин", "оружие+где"],
        negative_keywords=["лиценз", "лиц+"],
    ),
    dict(
        label="Крафт оружия /makegun",
        enabled=True, priority=29, skip_if_report_id=True,
        reply="Крафт оружия: /makegun",
        keywords=["крафт+оруж", "крафт+ствол", "makegun", "ганы+крафт", "как+крафтить"],
    ),
    dict(
        label="Лицензия — где",
        enabled=True, priority=33, skip_if_report_id=True,
        reply="Лицензии на оружие: лицензеры в мэрии /gps 1, список: /liclist",
        keywords=["лицензия+оружие", "лиц+на+оружие", "как+получить+лицензию", "лицензия+где", "лиц+оружие",
                  "лиц+ган", "лиценз+ган", "ганы+лиценз", "получить+ган", "сделать+лиценз", "лицензии+оружие"],
    ),
    dict(
        label="Список лицензеров",
        enabled=True, priority=28, skip_if_report_id=True,
        reply="Список лицензеров: /liclist",
        keywords=["liclist", "список+лицензер", "кто+лицензер"],
    ),
    dict(
        label="Скиллы /skill",
        enabled=True, priority=35, skip_if_report_id=True,
        reply="Посмотреть навыки: /skill",
        keywords=["посмотреть+скиллы", "как+смотреть+скилл", "свои+навыки", "где+скилл", "/skill", "скилы", "скиллы"],
    ),
    dict(
        label="Сброс /reset",
        enabled=True, priority=31, skip_if_report_id=True,
        reply="Сброс анимации/предмета: /reset или нажмите Enter",
        keywords=["убрать+анимку", "отключить+анимацию", "анимация+убрать", "застрял+аним", "анимка", "/anim",
                  "застрял+в+аним", "логотип+спин", "убрать+логотип", "кейс+рук", "легендарный+кейс", "убрать+кейс"],
    ),
    dict(
        label="Спортзал /end",
        enabled=True, priority=31, skip_if_report_id=True,
        reply="Выйти из спортзала / снять форму: /reset /end",
        keywords=["спортзал", "снять+форму+спорт", "переодеть+спорт", "заниматься+зале", "перестать+заниматься",
                  "выйти+зал", "перестать+заниматься+зале"],
    ),
    dict(
        label="Инвентарь /i",
        enabled=True, priority=25, skip_if_report_id=True,
        reply="Открыть инвентарь / аксессуары: /i (редактировать — /i edit)",
        keywords=["инвентарь", "как+инвентарь", "как+открыть+инвентарь", "открыть+инвентарь", "где+инвентарь", "нет+инвентаря",
                  "аксессуар", "снять+аксессуар", "надпись+спин", "edit"],
        negative_keywords=["донат", "пополн"],
    ),
    dict(
        label="Чат организации /r /f",
        enabled=True, priority=30, skip_if_report_id=True,
        reply="Чат организации/фракции: /r /f",
        keywords=["чат+фракции", "чат+орги", "как+писать+в+фракцию", "чат+организа", "писать+организа",
                  "как+писать+организа"],
    ),
    dict(
        label="Нон-РП чат /fn",
        enabled=True, priority=29, skip_if_report_id=True,
        reply="Нон-РП чат фракции: /fn",
        keywords=["нрп+чат", "нон+рп+чат"],
    ),
    dict(
        label="Чат банды /rn",
        enabled=True, priority=28, skip_if_report_id=True,
        reply="Чат банды: /rn",
        keywords=["чат+банды"],
    ),
    dict(
        label="Семейный чат /fm",
        enabled=True, priority=27, skip_if_report_id=True,
        reply="Семейный чат: /fm",
        keywords=["семейный+чат", "чат+семь", "семья+чат"],
    ),
    dict(
        label="Список замов /zamlist",
        enabled=True, priority=25, skip_if_report_id=True,
        reply="Список заместителей: /zamlist",
        keywords=["список+замов", "zamlist", "замы+фракции", "кто+замы", "зам+список", "соединить+зам"],
    ),
    dict(
        label="Онлайн фракции /find",
        enabled=True, priority=25, skip_if_report_id=True,
        reply="Участники онлайн: /find (полный список: /showall)",
        keywords=["кто+в+сети+орги", "участники+онлайн", "онлайн+фракции", "члены+онлайн", "кто+в+сети+фракции",
                  "сколько+людей+организа"],
        negative_keywords=["бп", "battle", "батл"],
    ),
    dict(
        label="Полный список /showall",
        enabled=True, priority=24, skip_if_report_id=True,
        reply="Полный список фракции: /showall",
        keywords=["полный+список", "showall", "все+участники", "список+фракции"],
        negative_keywords=["бп", "battle", "батл"],
    ),
    dict(
        label="Звёзды розыска",
        enabled=True, priority=30, skip_if_report_id=True,
        reply="Снять звёзды: сдайтесь в полицейском участке",
        keywords=["снять+звезды", "убрать+звезды", "звезды+розыска", "как+снять+розыск", "розыск+как+снять",
                  "сбросить+розыск", "розыск+снять", "как+розыск+снять"],
    ),
    dict(
        label="Бензин/АЗС",
        enabled=True, priority=36, skip_if_report_id=True,
        reply="Канистра на АЗС; залить в бак: /getfuel на заправке",
        keywords=["нет+бензина", "кончился+бензин", "нет+топлива", "бензин+кончился", "азс+где", "канистр",
                  "купить+канистр", "где+азс", "купить+бензин", "купить+топлив", "не+могу+купить+топлив",
                  "getfuel", "заправить+машин", "топлив+машин", "купить+топлив+машин", "залить+бензин"],
        negative_keywords=["запрос+игрок", "контракт", "механик"],
    ),
    dict(
        label="Механик /c 090",
        enabled=True, priority=36, skip_if_report_id=True,
        reply="Вызвать механика: /c 090",
        keywords=["вызвать+механика", "механик+номер", "/c 090", "как+вызвать+механика", "эвакуатор", "010", "полом+машин"],
        negative_keywords=["квест+механик", "заклад", "участок", "квест"],
    ),
    dict(
        label="Ремкомплект /fix",
        enabled=True, priority=32, skip_if_report_id=True,
        reply="Использовать ремкомплект: /fix",
        keywords=["ремкомплект", "рем+комплект", "как+ремкомплект", "воспользоваться+рем", "repair+kit"],
    ),
    dict(
        label="Аренда транспорта",
        enabled=True, priority=34, skip_if_report_id=True,
        reply="Отменить аренду / убрать транспорт: /unrent или /x",
        keywords=["арендовал+скутер", "аренда+транспорт", "unrent", "на+крыше+заспавн", "арендован"],
    ),
    dict(
        label="Батл Пасс /bp",
        enabled=True, priority=25, skip_if_report_id=True,
        reply="Battle Pass: /bp",
        keywords=["батл+пасс", "battle+pass", "бп+команда", "как+смотреть+бп", "баттл+пасс", "battle+pass+где",
                  "забрать+наград", "награды+бп", "награды+bp", "где+награды+бп"],
        negative_keywords=["квест", "ключ", "машин", "отель", "организа", "find", "showall", "allow", "передать",
                           "голод", "members", "narco", "нарко", "drugs", "бургер"],
    ),
    dict(
        label="Прогресс БП /tasks",
        enabled=True, priority=24, skip_if_report_id=True,
        reply="Прогресс заданий Battle Pass: /tasks",
        keywords=["прогресс+бп", "задания+бп", "задания+bp", "квест+бп", "награды+бп"],
        negative_keywords=["телефон", "голод", "силы", "квест+телефон", "какие+квест"],
    ),
    dict(
        label="Advance Credits — help",
        enabled=True, priority=20, skip_if_report_id=True,
        reply="Advance Credits: /creditshelp",
        keywords=["адванс+кредиты", "advance+credits", "creditshelp", "кредиты+как+использовать", "адванс+кредит",
                  "меню+кредит", "адванс+credits"],
        negative_keywords=["взять+кредит", "банк+кредит", "кредит+банк", "ипотек"],
    ),
    dict(
        label="Баланс кредитов /st",
        enabled=True, priority=19, skip_if_report_id=True,
        reply="Баланс кредитов: /st",
        keywords=["баланс+кредит", "сколько+кредит", "кредит+баланс"],
    ),
    dict(
        label="Магазины /price",
        enabled=True, priority=26, skip_if_report_id=True,
        reply="Список магазинов и цен: /price",
        keywords=["где+купить", "где+найти+магазин", "магазин+мебел", "автосалон", "пиротехник", "салют", "24+7", "24/7",
                  "магазин+игрушек"],
        negative_keywords=["оружие", "телефон", "отель", "лиценз", "инфернус"],
    ),
    dict(
        label="Отмычка",
        enabled=True, priority=27, skip_if_report_id=True,
        reply="Отмычка: /price — магазин игрушек",
        keywords=["отмычк", "взлом+машин", "купить+отмыч"],
    ),
    dict(
        label="Продать SIM /sellsim",
        enabled=True, priority=28, skip_if_report_id=True,
        reply="Продать SIM-карту: /sellsim (в салоне связи)",
        keywords=["продать+сим", "sellsim", "симк+прод", "симку+чел"],
    ),
    dict(
        label="Адвокат /adlist",
        enabled=True, priority=33, skip_if_report_id=True,
        reply="Список адвокатов: /adlist",
        keywords=["вызвать+адвокат", "адвокат+номер", "adlist", "список+адвокат", "как+адвокат", "визвать+адвокат"],
    ),
    dict(
        label="Выпустить из тюрьмы /free",
        enabled=True, priority=32, skip_if_report_id=True,
        reply="Выпустить игрока (адвокат): /free [id]",
        keywords=["выпустить+тюрьм", "выпустить+адвокат", "free+id", "из+тюрьмы+адвокат"],
    ),
    dict(
        label="Спавн точка /setspawn",
        enabled=True, priority=20, skip_if_report_id=True,
        reply="Сменить место спавна: /setspawn",
        keywords=["место+спавна", "setspawn", "сменить+спавн", "поменять+спавн", "спавн+орга", "изменить+спавн",
                  "точка+спавна", "выбрать+место+спауна", "как+выбрать+спавн"],
    ),
    dict(
        label="Подать объявление /ad",
        enabled=True, priority=20, skip_if_report_id=True,
        reply="Подать объявление: /ad [текст]",
        keywords=["как+подать+объявление", "подать+объявление", "/ad", "объявление+команда", "объявление", "обьявление",
                  "инфернус+купить", "купить+инфернус"],
    ),
    dict(
        label="Позвонить /c",
        enabled=True, priority=22, skip_if_report_id=True,
        reply="Позвонить: /c [номер]",
        keywords=["как+позвонить", "позвонить+игроку", "как+звонить", "говорить+телефон", "номер+телефон"],
        negative_keywords=["такси", "555"],
    ),
    dict(
        label="Купить телефон",
        enabled=True, priority=21, skip_if_report_id=True,
        reply="Телефон — в магазине 24/7 (/price)",
        keywords=["купить+телефон", "телефон+где", "где+телефон", "нет+телефона"],
        negative_keywords=["квест+телефон"],
    ),
    dict(
        label="Микрофон (войс)",
        enabled=True, priority=20, skip_if_report_id=True,
        reply="Голосовой чат / микрофон: F2",
        keywords=["включить+микрофон", "войс+чат", "микрофон+как", "f2+микро", "voice+chat", "не+работает+микро",
                  "войсом+пользов", "голосовой+чат", "как+говорить+войс"],
    ),
    dict(
        label="Варн инфо /warninfo",
        enabled=True, priority=15, skip_if_report_id=True,
        reply="Информация о предупреждениях: /warninfo",
        keywords=["сколько+варнов", "мои+варны", "warninfo", "варн+инфо", "срок+варна"],
    ),
    dict(
        label="Лицензии /lic",
        enabled=True, priority=20, skip_if_report_id=True,
        reply="Показать свои лицензии: /lic",
        keywords=["показать+лицензии", "мои+лицензии", "/lic", "лицензии+команда", "как+показать+лиц"],
        negative_keywords=["купить+оруж", "получить+лиценз"],
    ),
    dict(
        label="Квест трамвай",
        enabled=True, priority=25, skip_if_report_id=True,
        reply="Квест с трамваем: НПС у депо /gps 5, проедьте 1 круг",
        keywords=["квест+трамвай", "трамвай+квест", "квест+трамвае", "как+сделать+трамвай", "трамвайный+квест"],
    ),
    dict(
        label="Загрузить металл /buym",
        enabled=True, priority=26, skip_if_report_id=True,
        reply="Загрузить металл: /buym на чекпоинте шахты",
        keywords=["загрузить+металл", "металл+в+грузовик", "как+загрузить+руду", "buym", "металл+куда"],
    ),
    dict(
        label="GPS Шахта",
        enabled=True, priority=24, skip_if_report_id=True,
        reply="Шахта: /gps 5",
        keywords=["шахта+квест", "где+шахта", "шахта+где", "шахта+gps"],
    ),
    dict(
        label="Макс. скорость",
        enabled=True, priority=18, skip_if_report_id=True,
        reply="Поднять лимит скорости (макс.): /price 22",
        keywords=["максималка+85", "лимит+скорост", "макс+скорост", "ограничен+85", "скорост+85"],
    ),
    dict(
        label="Донат /donate",
        enabled=True, priority=22, skip_if_report_id=True,
        reply="Донат: пополнить и использовать — /donate (меню доната: /mn 12)",
        keywords=["донат+команда", "пополнить+донат", "донат+баланс", "где+донат", "/donate", "как+задонатить",
                  "как+использовать+донат", "пополнил+руб", "как+тратить+донат", "не+могу+донат"],
    ),
    dict(
        label="Покинуть фракцию /leave",
        enabled=True, priority=15, skip_if_report_id=True,
        reply="Покинуть организацию: /leave",
        keywords=["выйти+из+орги", "уйти+из+фракции", "выйти+организа", "/leave", "как+уйти+из+банды", "выйти+гос"],
    ),
    dict(
        label="Режим таксиста",
        enabled=True, priority=43, skip_if_report_id=True,
        reply="Принять клиента: 2 — режим таксиста (авто, договорная и т.д.)",
        keywords=["принять+клиента+такси", "клиент+такси", "режим+таксист"],
    ),
    dict(
        label="Автовокзал",
        enabled=True, priority=28, skip_if_report_id=True,
        reply="Стоянка автобусов: на автовокзале",
        keywords=["стоянка+автобус", "автовокзал", "где+автобус+стоян"],
    ),
    dict(
        label="Директор завода",
        enabled=True, priority=22, skip_if_report_id=True,
        reply="Директор завода: внутри завода, -1 этаж",
        keywords=["директор+завод", "где+директор+завод"],
    ),
    dict(
        label="Полноэкранный режим",
        enabled=True, priority=10, skip_if_report_id=True,
        reply="Полноэкранный / оконный режим: Alt + Enter",
        keywords=["полноэкранный", "полный+экран", "оконный+режим", "alt+enter", "как+сделать+полный+экран"],
    ),
    dict(
        label="GPS / метки",
        enabled=True, priority=23, skip_if_report_id=True,
        reply="GPS и метки: /gps (убрать лишнюю метку — через меню GPS)",
        keywords=["убрать+метку", "бесполезн+метк", "метк+gps", "как+gps", "ближайший+24"],
    ),
]


def lua_quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fmt_list(items: list[str]) -> str:
    if not items:
        return "{}"
    inner = ", ".join(lua_quote(x) for x in items)
    return "{" + inner + "}"


def fmt_scenario(sc: dict) -> str:
    lines = [
        "    {",
        f"      label = {lua_quote(sc['label'])},",
        f"      enabled = {'true' if sc.get('enabled', True) else 'false'},",
        "      match = \"contains\",",
        f"      priority = {sc.get('priority', 0)},",
        f"      skip_if_report_id = {'true' if sc.get('skip_if_report_id', True) else 'false'},",
        "      action = \"reply\",",
        f"      reply = {lua_quote(sc['reply'])},",
        f"      keywords = {fmt_list(sc.get('keywords', []))},",
    ]
    if sc.get("negative_keywords"):
        lines.append("      negative_keywords = " + fmt_list(sc["negative_keywords"]) + ",")
    lines.append("    },")
    return "\n".join(lines)


def main():
    body = "\n".join(fmt_scenario(sc) for sc in SCENARIOS)
    content = HEADER + body + "\n" + FOOTER
    for path in TARGETS:
        path.write_text(content, encoding="utf-8")
        print(f"Wrote {path} ({len(SCENARIOS)} scenarios)")


if __name__ == "__main__":
    main()
