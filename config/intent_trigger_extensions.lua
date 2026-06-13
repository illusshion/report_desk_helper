--[[ Extra phrase triggers merged at load (config/intent_trigger_extensions.lua).
    Edit and /reload — no separate bake step.
]]
return {
  version = 1,
  patches = {
    {
      id = "faq.communication.c",
      add_any = {
        { all = {"открыть", "телефон"} },
        { all = {"достать", "телефон"} },
        { all = {"телефон", "набрать"} },
        { all = {"через", "телефон"} },
        { all = {"позвонить", "телефон"} },
      },
      add_exclusions = {
        { all = {"механик"} },
        { all = {"заправ"} },
        { all = {"090"} },
        { all = {"эвакуатор"} },
      },
    },
    {
      id = "faq.communication.c_090",
      add_any = {
        { all = {"вызвать", "заправ"} },
        { all = {"заправщик"} },
        { all = {"заправ", "авто"} },
        { all = {"заправ", "автобус"} },
        { all = {"механик", "заправ"} },
        { all = {"позвонить", "механик", "заправ"} },
        { all = {"нету", "азс"} },
        { all = {"бензин", "дать"} },
        { all = {"заправить", "пожалуйста"} },
        { all = {"заправить", "автобус", "механик"} },
        { all = {"можно", "заправить", "автобус"} },
        { all = {"механику", "заправку"} },
      },
    },
    {
      id = "faq.communication.c_555",
      add_any = {
        { all = {"вызвать", "такси"} },
        { all = {"заказать", "такси"} },
      },
    },
    {
      id = "faq.communication.2",
      add_any = {
        { all = {"отремонтировать", "машин"} },
        { all = {"поезд", "не", "едет"} },
      },
    },
    {
      id = "faq.communication.car",
      add_any = {
        { all = {"припарковать", "машин"} },
        { all = {"припарковать", "тач"} },
      },
    },
    {
      id = "faq.economy.mn_1",
      add_any = {
        { all = {"баланс", "адванс"} },
        { all = {"посмотреть", "адванс", "кредит"} },
        { all = {"mn", "команда"} },
        { token = "/mn" },
      },
    },
    {
      id = "faq.gameplay.ad",
      add_any = {
        { all = {"написать", "объявлен"} },
        { all = {"написать", "обявлен"} },
        { all = {"объявлен", "новост"} },
        { all = {"узнать", "номер", "игрок"} },
        { all = {"найти", "номер", "человек"} },
        { all = {"мой", "номер", "телефон"} },
        { all = {"узнать", "номер", "телефон"} },
        { all = {"купить", "акс", "гитар"} },
        { all = {"купить", "аксессуар"} },
      },
    },
    {
      id = "faq.gameplay.b",
      add_any = {
        { all = {"багажник", "личн"} },
        { all = {"система", "багажник"} },
      },
    },
    {
      id = "faq.gameplay.creditshelp",
      add_any = {
        { all = {"использовать", "адванс", "коин"} },
        { all = {"advance", "credit", "без", "донат"} },
        { all = {"тратить", "адванс", "коин"} },
      },
    },
    {
      id = "faq.gameplay.end",
      add_any = {
        { all = {"переодеть", "квест", "сил"} },
        { all = {"снять", "форму", "спортзал"} },
      },
    },
    {
      id = "faq.gameplay.find",
      add_any = {
        { token = "мемберс" },
        { all = {"чекать", "мемб"} },
        { all = {"смотреть", "мемб"} },
        { all = {"мембру", "ввс"} },
        { all = {"сотрудник", "сети"} },
        { all = {"кто", "сети", "сотрудник"} },
      },
    },
    {
      id = "faq.gameplay.fix",
      add_any = {
        { all = {"как", "чинить", "машин"} },
        { all = {"как", "чинить", "авто"} },
        { all = {"почините", "пж"} },
        { all = {"машину", "починить"} },
        { all = {"воспользоваться", "ремкомплект"} },
        { all = {"использовать", "ремкомплект"} },
      },
      add_exclusions = {
        { all = {"купить", "ремкомп"} },
        { all = {"где", "ремкомп"} },
        { all = {"где", "купить", "ремкомп"} },
      },
    },
    {
      id = "faq.gameplay.fn",
      add_any = {
        { all = {"нон", "рп", "орг"} },
        { all = {"фракк", "оос"} },
        { all = {"писать", "фракк"} },
      },
    },
    {
      id = "faq.gameplay.rn",
      add_any = {
        { all = {"нрп", "чат", "фрак"} },
        { all = {"красится", "нрп"} },
        { all = {"соо", "нрп"} },
      },
    },
    {
      id = "faq.gameplay.fm",
      add_any = {
        { all = {"голосов", "семь"} },
        { all = {"семь", "голосов"} },
        { all = {"говорить", "семь"} },
      },
    },
    {
      id = "faq.gameplay.gps_5_1",
      add_any = {
        { all = {"рейсов", "трамва"} },
        { all = {"трамва", "квест"} },
      },
    },
    {
      id = "faq.gameplay.h",
      add_any = {
        { all = {"звонок", "отмен"} },
        { all = {"скинуть", "разговор"} },
        { all = {"завершить", "звонок"} },
      },
    },
    {
      id = "faq.gameplay.home_hotel",
      add_any = {
        { all = {"найти", "свое", "авто"} },
        { all = {"найти", "свою", "машин"} },
        { all = {"где", "моя", "машин"} },
        { all = {"где", "находится", "автомобил"} },
        { all = {"чекнуть", "машин"} },
      },
    },
    {
      id = "faq.gameplay.i",
      add_any = {
        { all = {"переодеться", "граждан"} },
        { all = {"переодеть", "арми"} },
        { all = {"скин", "фракц"} },
        { all = {"поменять", "скин"} },
        { all = {"одежд", "арми"} },
        { all = {"выйти", "баз", "арми"} },
      },
    },
    {
      id = "faq.gameplay.join",
      add_any = {
        { all = {"куда", "набор"} },
        { all = {"набор", "идет"} },
        { all = {"посмотреть", "набор"} },
      },
    },
    {
      id = "faq.gameplay.leaders",
      add_any = {
        { all = {"кто", "президент"} },
        { all = {"выборы", "прошл"} },
        { all = {"лидер", "снял"} },
        { all = {"свободн", "лидер"} },
      },
      add_exclusions = {
        { all = {"зам"} },
        { all = {"заместител"} },
      },
    },
    {
      id = "faq.gameplay.leave",
      add_any = {
        { all = {"уволиться", "госк"} },
        { all = {"уволиться", "псэ"} },
        { all = {"уволиться", "орг"} },
        { all = {"выйти", "орги"} },
        { all = {"ливнуть", "орг"} },
        { all = {"ливнуть", "фам"} },
        { all = {"команда", "увол"} },
        { all = {"как", "выйти", "орг"} },
      },
    },
    {
      id = "faq.gameplay.liclist",
      add_any = {
        { all = {"лиц", "ган"} },
        { all = {"лиценз", "оруж"} },
        { all = {"купить", "лиц", "оруж"} },
        { all = {"получить", "лиц", "оруж"} },
        { all = {"лиц", "оруж", "получ"} },
      },
    },
    {
      id = "faq.gameplay.makegun",
      add_any = {
        { all = {"скрафтить", "оруж"} },
        { all = {"сделать", "оруж"} },
        { all = {"скрафтить", "дигл"} },
        { all = {"оруж", "патрон"} },
        { all = {"метал", "ствол"} },
        { all = {"метала", "ствол"} },
        { all = {"матер", "ствол"} },
        { all = {"зделать", "оружее"} },
        { all = {"зделать", "ствол"} },
      },
    },
    {
      id = "faq.gameplay.mn_2",
      add_any = {
        { all = {"задания", "нович"} },
        { all = {"квест", "нович"} },
        { all = {"начальн", "задан"} },
        { all = {"квест", "exp"} },
      },
    },
    {
      id = "faq.gameplay.tasks",
      add_any = {
        { all = {"ежедневн", "квест", "смотр"} },
        { all = {"какиквест"} },
        { all = {"квест", "смотреть"} },
        { all = {"ежедневн", "задан", "смотр"} },
        { all = {"найти", "ежедневн"} },
      },
    },
    {
      id = "faq.gameplay.price_22",
      add_any = {
        { all = {"купить", "диск"} },
        { all = {"тюнинг", "авто"} },
        { all = {"максимальн", "скорост", "авто"} },
        { all = {"спойлер", "авто"} },
        { all = {"тюнинг", "ателье"} },
        { all = {"где", "тюнинг"} },
        { all = {"найти", "тюнинг"} },
        { all = {"покраска", "машин"} },
        { all = {"цвет", "мото"} },
        { all = {"записался", "тюнинг"} },
      },
    },
    {
      id = "faq.gameplay.reset",
      add_any = {
        { all = {"убрать", "ящик"} },
        { all = {"убрать", "книж"} },
        { all = {"убрать", "чемодан"} },
        { all = {"убрать", "кейс"} },
        { all = {"бросить", "короб"} },
        { all = {"семен", "сзади"} },
      },
    },
    {
      id = "faq.gameplay.skill",
      add_any = {
        { all = {"скил", "дигл"} },
        { all = {"скил", "оруж", "провер"} },
        { all = {"смотреть", "навык", "ган"} },
        { all = {"очки", "сил"} },
        { token = "/skill" },
        { all = {"чекнуть", "скилл", "оруж"} },
        { all = {"скилл", "оруж"} },
        { all = {"посмотреть", "скилл", "оруж"} },
      },
      add_exclusions = {
        { all = {"качать"} },
        { all = {"прокач"} },
        { all = {"где", "качать"} },
      },
    },
    {
      id = "faq.gameplay.zamlist",
      add_any = {
        { all = {"прсмотреть", "зам"} },
        { all = {"посмотреть", "зам"} },
        { all = {"список", "замов"} },
        { all = {"заместител"} },
        { all = {"помимо", "лидер", "зам"} },
        { all = {"зам", "организа"} },
      },
    },
    {
      id = "faq.gameplay.2_gps_1",
      add_any = {
        { all = {"где", "мэри"} },
        { all = {"где", "мерии"} },
        { all = {"найти", "мэри"} },
        { all = {"найти", "мерии"} },
        { all = {"работа", "такси", "где"} },
        { all = {"работать", "такси"} },
        { all = {"найти", "таксопарк"} },
      },
    },
    {
      id = "faq.gameplay.getfuel",
      add_any = {
        { all = {"купить", "бензин", "механик"} },
        { all = {"топлив", "автомеханик"} },
      },
    },
    {
      id = "faq.gameplay.setspawn",
      add_any = {
        { all = {"жить", "участк"} },
      },
    },
    {
      id = "faq.gameplay.showall",
      add_any = {
        { all = {"список", "игрок", "фракц"} },
        { all = {"все", "игрок", "фракц"} },
      },
    },
    {
      id = "faq.gameplay.sellm",
      add_exclusions = {
        { all = {"продать", "авто"} },
        { all = {"продать", "машин"} },
        { all = {"продать", "участок"} },
      },
    },
    {
      id = "faq.navigation.gps",
      add_any = {
        { all = {"ближайший", "7"} },
      },
    },
    {
      id = "faq.navigation.price",
      add_any = {
        { all = {"собес", "отель"} },
        { all = {"отель", "или", "магазин"} },
      },
    },
    {
      id = "faq.gameplay.price_22",
      add_any = {
        { all = {"ограничение", "85"} },
        { all = {"85", "км"} },
      },
    },
    {
      id = "faq.communication.c_090",
      add_any = {
        { all = {"заправить", "автобус", "механик"} },
        { all = {"механику", "заправку"} },
        { all = {"можно", "заправить", "автобус"} },
        { all = {"позвонить", "механик", "заправ"} },
      },
    },
    {
      id = "faq.gameplay.rent_x",
      add_any = {
        { all = {"аренда", "скутера"} },
      },
    },
    {
      id = "faq.gameplay.bp",
      add_any = {
        { all = {"bp", "команда"} },
      },
    },
    {
      id = "faq.gameplay.i",
      add_any = {
        { token = "/i" },
        { all = {"команда", "инвентар"} },
      },
    },
    {
      id = "faq.gameplay.lrec",
      add_any = {
        { all = {"lrec", "команда"} },
      },
    },
    {
      id = "faq.gameplay.newspaper",
      add_any = {
        { all = {"деть", "газеты"} },
      },
    },
    {
      id = "faq.gameplay.f2_f9",
      add_any = {
        { all = {"f2", "f9", "войс"} },
        { all = {"юзать", "микро"} },
        { all = {"микро", "включить"} },
        { all = {"микро", "вкл"} },
        { all = {"как", "юзать", "микро"} },
      },
    },
    {
      id = "faq.gameplay.lic",
      add_any = {
        { all = {"лицензия", "показать"} },
      },
    },
    {
      id = "faq.gameplay.unrent",
      add_any = {
        { all = {"аренда", "машины", "работе"} },
      },
    },
    {
      id = "faq.navigation.gps",
      add_any = {
        { all = {"найти", "дом", "номер"} },
        { all = {"дом", "номер"} },
        { all = {"нефтевышк"} },
        { all = {"квест", "завод", "ехать"} },
      },
      add_exclusions = {
        { all = {"скил", "оруж"} },
        { all = {"навык", "оруж"} },
      },
    },
    {
      id = "faq.navigation.gps_7-2",
      add_any = {
        { all = {"качать", "навык", "оруж"} },
        { all = {"продвинут", "навык", "оруж"} },
        { all = {"качать", "скил", "оруж"} },
      },
      add_exclusions = {
        { all = {"провер", "скил"} },
        { all = {"смотреть", "скил"} },
      },
    },
    {
      id = "faq.navigation.gps_1",
      add_any = {
        { all = {"купить", "мотоцикл"} },
        { all = {"мотоцикл", "где"} },
      },
    },
    {
      id = "faq.navigation.gps_5_2",
      add_any = {
        { all = {"ехать", "топлив"} },
        { all = {"куда", "топлив"} },
      },
    },
    {
      id = "faq.navigation.gps_9",
      add_any = {
        { all = {"стать", "дальноб"} },
        { all = {"работа", "фур"} },
        { all = {"дальноб", "работ"} },
      },
    },
    {
      id = "faq.navigation.price",
      add_any = {
        { all = {"найти", "район"} },
        { all = {"номер", "дом", "иск"} },
        { all = {"парикмах"} },
        { all = {"кондитер"} },
        { all = {"купить", "акси"} },
        { all = {"отель", "найти"} },
      },
    },
    {
      id = "faq.gameplay.unrent",
      add_any = {
        { all = {"отменить", "аренд"} },
        { all = {"вернуть", "скутер"} },
        { all = {"сдать", "аренд"} },
        { token = "unrent" },
      },
    },
    {
      id = "faq.gameplay.n6",
      add_any = {
        { all = {"продать", "авто", "гос"} },
        { all = {"продать", "машин", "гос"} },
        { all = {"сдать", "тачку", "гос"} },
        { all = {"сдавать", "машину", "госс"} },
        { all = {"продать", "тс", "гос"} },
        { all = {"слить", "тс", "гос"} },
        { all = {"командой", "продать", "тс", "гос"} },
        { all = {"продать", "тачку", "гос"} },
        { all = {"как", "продать", "авто", "гос"} },
        { all = {"как", "продать", "машин", "гос"} },
      },
    },
    {
      id = "faq.navigation.gps_9",
      add_any = {
        { all = {"найти", "транспортную", "компанию"} },
      },
    },
    {
      id = "faq.navigation.gps_7-2",
      add_any = {
        { all = {"gps", "тир", "поставить"} },
      },
      add_exclusions = {
        { all = {"убрать", "метк"} },
      },
    },
    {
      id = "faq.navigation.gps_1",
      add_any = {
        { token = "авторынок" },
      },
    },
    {
      id = "faq.gameplay.gps_8",
      add_any = {
        { all = {"свободные", "дома"} },
      },
    },
    {
      id = "faq.gameplay.00_03",
      add_any = {
        { all = {"когда", "слетает", "отель"} },
      },
    },
    {
      id = "faq.gameplay.e_ctrl",
      add_any = {
        { all = {"не", "заводится", "авто"} },
        { all = {"включить", "двигатель"} },
      },
    },
    {
      id = "faq.gameplay.b",
      add_any = {
        { all = {"положить", "вещи", "машину"} },
      },
    },
    {
      id = "faq.gameplay.allow",
      add_any = {
        { all = {"доступ", "авто", "другу"} },
      },
    },
    {
      id = "faq.communication.car",
      add_any = {
        { all = {"команда", "парковк"} },
        { all = {"поставить", "тачку", "парков"} },
      },
      add_exclusions = {
        { all = {"где", "машина"} },
      },
    },
    {
      id = "faq.gameplay.unrent",
      add_any = {
        { all = {"арендовать", "транспорт", "работ"} },
        { all = {"снять", "аренду", "транспорт"} },
      },
    },
    {
      id = "faq.gameplay.rent_x",
      add_any = {
        { all = {"аренда", "скутера", "команда"} },
      },
    },
    {
      id = "faq.gameplay.getfuel",
      add_any = {
        { token = "заправиться" },
        { all = {"залить", "топлив"} },
      },
    },
    {
      id = "faq.communication.c_090",
      add_any = {
        { all = {"заправить", "автобус", "механик"} },
        { all = {"механику", "заправк"} },
      },
    },
    {
      id = "faq.gameplay.fuel",
      add_any = {
        { token = "fuel" },
        { all = {"где", "все", "азс"} },
      },
      add_exclusions = {
        { all = {"заправиться"} },
      },
    },
    {
      id = "faq.communication.2_gps_1",
      add_any = {
        { all = {"работа", "такси", "где"} },
        { all = {"работать", "такси"} },
      },
    },
    {
      id = "faq.communication.2",
      add_any = {
        { all = {"клиент", "сел", "заказ"} },
      },
    },
    {
      id = "faq.gameplay.h",
      add_any = {
        { all = {"завершить", "разговор", "телефон"} },
      },
    },
    {
      id = "faq.gameplay.n62",
      add_any = {
        { all = {"парковка", "автобус"} },
      },
    },
    {
      id = "faq.gameplay.join",
      add_any = {
        { all = {"вступить", "фракцию"} },
        { token = "join" },
      },
    },
    {
      id = "faq.gameplay.r_f",
      add_any = {
        { all = {"команда", "r", "f"} },
        { all = {"фракционный", "чат"} },
      },
    },
    {
      id = "faq.gameplay.r_f",
      add_any = {
        { all = {"команда", "r", "f"} },
      },
      add_exclusions = {
        { all = {"нон", "рп"} },
        { all = {"non", "rp"} },
        { all = {"oos"} },
      },
    },
    {
      id = "faq.gameplay.fn",
      add_any = {
        { all = {"писать", "нон", "рп", "организа"} },
        { all = {"oos", "чат", "фрак"} },
      },
    },
    {
      id = "faq.gameplay.fm",
      add_any = {
        { all = {"голос", "семьи"} },
      },
    },
    {
      id = "faq.gameplay.find",
      add_any = {
        { token = "find" },
        { all = {"сети", "работе"} },
      },
    },
    {
      id = "faq.gameplay.price",
      add_any = {
        { all = {"price", "оружие"} },
      },
    },
    {
      id = "faq.gameplay.sellgun",
      add_any = {
        { all = {"продать", "оружие"} },
      },
    },
    {
      id = "faq.gameplay.price_2",
      add_any = {
        { all = {"отмычка", "price"} },
      },
    },
    {
      id = "faq.economy.mn_1",
      add_any = {
        { all = {"mn", "команда"} },
        { token = "/mn" },
      },
    },
    {
      id = "faq.gameplay.donate",
      add_any = {
        { token = "donate" },
      },
    },
    {
      id = "faq.gameplay.sellm",
      add_any = {
        { token = "sellm" },
        { all = {"сдавать", "руду"} },
      },
    },
    {
      id = "faq.gameplay.bp",
      add_any = {
        { token = "bp" },
      },
    },
    {
      id = "faq.gameplay.tasks",
      add_any = {
        { all = {"tasks", "прогресс"} },
        { all = {"бп", "задания", "не", "выполняются"} },
      },
    },
    {
      id = "faq.gameplay.season",
      add_any = {
        { all = {"season", "рейтинг"} },
      },
    },
    {
      id = "faq.gameplay.end",
      add_any = {
        { all = {"закончить", "тренировку", "спортзал"} },
        { all = {"переодеться", "квест", "сил"} },
      },
    },
    {
      id = "faq.gameplay.newspaper",
      add_any = {
        { all = {"газеты", "работы"} },
      },
    },
    {
      id = "faq.gameplay.skill",
      add_any = {
        { token = "skill" },
      },
    },
    {
      id = "faq.gameplay.reset",
      add_any = {
        { token = "reset" },
        { all = {"сбросить", "настройки"} },
      },
    },
    {
      id = "faq.gameplay.n34",
      add_any = {
        { all = {"звёзды", "гта"} },
      },
    },
    {
      id = "faq.gameplay.setspawn",
      add_any = {
        { all = {"поставить", "точку", "спавна"} },
      },
    },
    {
      id = "faq.gameplay.free_id",
      add_any = {
        { all = {"free", "id"} },
      },
    },
    {
      id = "faq.gameplay.lrec",
      add_any = {
        { token = "lrec" },
      },
    },
    {
      id = "faq.gameplay.badge",
      add_any = {
        { all = {"показать", "семью", "голов"} },
        { all = {"семью", "над", "головой"} },
      },
    },
    {
      id = "faq.gameplay.mn_2",
      add_any = {
        { all = {"новичок", "начать"} },
      },
      add_exclusions = {
        { all = {"трамвай"} },
      },
    },
    {
      id = "faq.gameplay.gps_5_1",
      add_exclusions = {
        { all = {"новичок"} },
      },
    },
    {
      id = "faq.navigation.gps_5",
      add_any = {
        { all = {"металл", "набрать"} },
      },
      add_exclusions = {
        { all = {"сдать", "металл"} },
        { all = {"куда", "сдать"} },
      },
    },
    {
      id = "faq.gameplay.buym",
      add_exclusions = {
        { all = {"куда", "сдать"} },
      },
    },
    {
      id = "faq.gameplay.leave",
      add_any = {
        { all = {"уйти", "работы", "псе"} },
      },
    },
    {
      id = "faq.gameplay.drugs",
      add_exclusions = {
        { all = {"курить", "сигар"} },
        { all = {"почему", "нарко"} },
        { all = {"после", "нарко"} },
      },
    },
-- [[ review_sync — intent_corpus_sync_review.py ]]
    {
      id = "faq.communication.sms_1001",
      add_any = {
        { all = {"писать", "смс", "игрокам"} },
        { all = {"написать", "смс"} },
      },
    },
    {
      id = "faq.economy.price",
      add_exclusions = {
        { all = {"ремкомплект"} },
        { all = {"рем", "комплект"} },
        { all = {"взять", "ремкомплект"} },
      },
    },
    {
      id = "faq.gameplay.adlist",
      add_any = {
        { all = {"вызвать", "адвоката"} },
      },
    },
    {
      id = "faq.gameplay.buym",
      add_any = {
        { all = {"закупить", "металл", "для", "доставки"} },
        { all = {"загрузить", "метал"} },
      },
    },
    {
      id = "faq.gameplay.creditshelp",
      add_any = {
        { all = {"получить", "adv", "credit"} },
      },
    },
    {
      id = "faq.gameplay.donate",
      add_any = {
        { all = {"пополнил", "рублей", "могу", "конвентировать"} },
      },
    },
    {
      id = "faq.gameplay.find",
      add_any = {
        { all = {"посмотреть", "сколько", "людей", "орге"} },
      },
    },
    {
      id = "faq.gameplay.gps_5_1",
      add_any = {
        { all = {"сколько", "трамвае", "для", "квеста"} },
      },
    },
    {
      id = "faq.gameplay.home_hotel",
      add_exclusions = {
        { all = {"продать", "машину", "госс"} },
        { all = {"продать", "машин", "гос"} },
        { all = {"слить", "машину", "гос"} },
        { all = {"слить", "авто", "гос"} },
        { all = {"слива", "машин", "гос"} },
        { all = {"команд", "слив", "гос"} },
      },
    },
    {
      id = "faq.gameplay.n6",
      add_any = {
        { all = {"госс", "слить", "авто"} },
        { all = {"продать", "машину", "госс"} },
        { all = {"продать", "машин", "гос"} },
        { all = {"команд", "слив", "машин"} },
        { all = {"команд", "слив", "гос"} },
        { all = {"слив", "машин", "гос"} },
        { all = {"слива", "машины", "гос"} },
      },
    },
    {
      id = "faq.gameplay.i",
      add_exclusions = {
        { all = {"инвентар", "скин"} },
        { all = {"расширить", "инвентар"} },
        { all = {"аксс", "надев"} },
        { all = {"расширить", "инвентарь"} },
      },
    },
    {
      id = "faq.gameplay.leaders",
      add_any = {
        { all = {"узнать", "лидер", "сети", "или"} },
      },
    },
    {
      id = "faq.gameplay.lic",
      add_any = {
        { all = {"посмотреть", "свои", "лицензии"} },
      },
    },
    {
      id = "faq.gameplay.makegun",
      add_any = {
        { all = {"ган", "скрафтить"} },
      },
    },
    {
      id = "faq.gameplay.mask_reset",
      add_any = {
        { all = {"сбросить", "маску"} },
        { all = {"снять", "маску"} },
      },
    },
    {
      id = "faq.gameplay.org_level_3",
      add_any = {
        { all = {"какого", "лвл", "банду"} },
      },
    },
    {
      id = "faq.gameplay.phone_lookup",
      add_any = {
        { all = {"узнать", "нооомер", "игрока", "айди"} },
        { all = {"узнать", "номер", "телефона"} },
      },
    },
    {
      id = "faq.gameplay.price",
      add_exclusions = {
        { all = {"стоимость", "лиценз"} },
        { all = {"цена", "лиценз"} },
        { all = {"сколько", "лиценз"} },
        { all = {"получить", "лицензию"} },
        { all = {"купить", "нибудь"} },
      },
    },
    {
      id = "faq.gameplay.price_22",
      add_any = {
        { all = {"найти", "тюнинг", "ателье"} },
      },
    },
    {
      id = "faq.gameplay.rent_x",
      add_any = {
        { all = {"подогнать", "арендованную", "машину"} },
      },
    },
    {
      id = "faq.gameplay.reset",
      add_any = {
        { all = {"продали", "ящик", "семечек", "снять"} },
      },
    },
    {
      id = "faq.gameplay.rn",
      add_exclusions = {
        { all = {"семейн", "чат"} },
        { token = "/fn" },
        { all = {"писать", "чат"} },
      },
    },
    {
      id = "faq.gameplay.skill",
      add_exclusions = {
        { all = {"ability"} },
        { token = "/ability" },
        { all = {"есть", "команда"} },
      },
    },
    {
      id = "faq.gameplay.tasks",
      add_any = {
        { all = {"открыть", "ежедневное", "задание"} },
      },
    },
    {
      id = "faq.gameplay.zamlist",
      add_any = {
        { all = {"какая", "там", "команда", "посмотреть"} },
      },
    },
    {
      id = "faq.navigation.gps_7-2",
      add_exclusions = {
        { all = {"навык", "оруж"} },
        { all = {"прокач", "навык"} },
        { all = {"продвинут", "навык"} },
        { all = {"прокачать", "продвинутые"} },
      },
    },
-- [[ corpus_review_autogen patches ]]
    {
      id = "faq.communication.c",
      add_any = {
        { all = {"звонить"} },
      },
    },
    {
      id = "faq.communication.c_555",
      add_any = {
        { all = {"вызвать", "таки"} },
      },
    },
    {
      id = "faq.communication.car",
      add_exclusions = {
        { all = {"поставить", "обвесы", "машину"} },
      },
    },
    {
      id = "faq.gameplay.buym",
      add_any = {
        { all = {"загрузить", "метал", "фургон", "шахте"} },
      },
    },
    {
      id = "faq.gameplay.creditshelp",
      add_any = {
        { all = {"адванс", "коины", "нужны"} },
        { all = {"куда", "тратить", "адв", "кредиты"} },
        { all = {"получать", "advance", "credits"} },
      },
    },
    {
      id = "faq.gameplay.drugs",
      add_any = {
        { all = {"принять", "накотики"} },
      },
    },
    {
      id = "faq.gameplay.end",
      add_any = {
        { all = {"пререодеться", "спорт", "одежды", "дефолт"} },
      },
    },
    {
      id = "faq.gameplay.find",
      add_any = {
        { all = {"посмотреть", "сколько", "людей", "орге"} },
      },
    },
    {
      id = "faq.gameplay.fix",
      add_any = {
        { all = {"использовать", "рем", "комплект", "благодарю"} },
        { all = {"использвать", "ремку"} },
      },
    },
    {
      id = "faq.gameplay.fm",
      add_any = {
        { all = {"писать", "фам", "чат"} },
        { all = {"чат", "семьи"} },
        { all = {"команда", "чата", "семьи"} },
      },
    },
    {
      id = "faq.gameplay.h",
      add_any = {
        { all = {"закончить", "розговор"} },
      },
    },
    {
      id = "faq.gameplay.leave",
      add_any = {
        { all = {"уволиться", "лидаков", "замов", "сети"} },
      },
    },
    {
      id = "faq.gameplay.makegun",
      add_any = {
        { all = {"зделать", "ган"} },
        { all = {"крафтить", "дигл"} },
        { all = {"создать", "оружее", "материалов"} },
        { all = {"метал", "ствол"} },
        { all = {"матер", "ствол"} },
      },
    },
    {
      id = "faq.gameplay.price_22",
      add_any = {
        { all = {"поставить", "обвесы", "машину"} },
      },
    },
    {
      id = "faq.gameplay.rent_x",
      add_any = {
        { all = {"взять", "оренду", "скутер", "каманду"} },
        { all = {"мопед", "аренду", "взять"} },
      },
    },
    {
      id = "faq.gameplay.time",
      add_any = {
        { all = {"узнать", "мут", "кончится"} },
      },
    },
    {
      id = "faq.gameplay.w",
      add_any = {
        { all = {"сказать", "шопотом"} },
      },
    },
    {
      id = "faq.navigation.gps_1",
      add_any = {
        { all = {"джпс", "найти", "автосалоны"} },
      },
    },
    {
      id = "faq.communication.sms_1001",
      add_any = {
        { all = {"отправить", "смс"} },
      },
    },
    {
      id = "faq.gameplay.rn",
      add_any = {
        { all = {"писать", "нрп", "чат", "рации"} },
      },
    },
    {
      id = "faq.gameplay.r_f",
      add_exclusions = {
        { all = {"писать", "нрп", "чат"} },
      },
    },
    {
      id = "faq.gameplay.lrec",
      add_any = {
        { all = {"сделать", "реконект"} },
      },
    },
    {
      id = "faq.gameplay.price",
      add_exclusions = {
        { all = {"взять", "оружие"} },
      },
    },
    {
      id = "faq.navigation.price",
      add_exclusions = {
        { all = {"оплатить", "отель"} },
        { all = {"собес"} },
        { all = {"собеседован"} },
      },
    },
    {
      id = "faq.gameplay.phone_number",
      add_exclusions = {
        { all = {"узнать", "номер", "человека"} },
      },
    },
    {
      id = "faq.navigation.gps",
      add_exclusions = {
        { all = {"найти", "дом", "номеру"} },
      },
    },
    {
      id = "faq.gameplay.newspaper",
      add_exclusions = {
        { all = {"газету", "продать"} },
      },
    },
    {
      id = "faq.communication.c_090",
      add_exclusions = {
        { all = {"авто", "механике", "заправить"} },
      },
    },
    {
      id = "faq.gameplay.fix",
      add_exclusions = {
        { all = {"чела", "починить", "механик"} },
      },
    },
    {
      id = "faq.economy.price",
      add_any = {
        { all = {"купить", "ремкомплект"} },
        { all = {"купить", "ремкомп"} },
        { all = {"где", "ремкомплект"} },
        { all = {"где", "купить", "ремкомплект"} },
        { all = {"ремкомплект", "гдекупить"} },
      },
    },
    {
      id = "faq.gameplay.bank_gps",
      add_any = {
        { all = {"найти", "банк"} },
        { all = {"где", "банк"} },
      },
    },
    {
      id = "faq.gameplay.join",
      add_exclusions = {
        { all = {"собес"} },
        { all = {"собеседован"} },
      },
    },
    {
      id = "faq.gameplay.liclist",
      add_any = {
        { token = "liclist" },
        { all = {"список", "лицензер"} },
        { all = {"кто", "лицензер"} },
        { all = {"где", "лицензии", "получ"} },
        { all = {"лицензии", "получают"} },
        { all = {"купить", "лицензию", "оружие"} },
        { all = {"где", "купить", "лицензию"} },
        { all = {"кому", "идти", "лиценз"} },
      },
    },
    {
      id = "faq.gameplay.rn",
      add_any = {
        { all = {"рация", "банды"} },
        { all = {"писать", "рация"} },
        { all = {"рацию", "банды"} },
      },
    },
    {
      id = "faq.gameplay.fn",
      add_any = {
        { all = {"нон", "рп", "чат", "рации"} },
        { all = {"писать", "нон", "рп", "чат", "рации"} },
      },
    },
    {
      id = "faq.gameplay.n",
      add_exclusions = {
        { all = {"раци"} },
        { all = {"нон", "рп"} },
      },
    },
    {
      id = "faq.gameplay.h",
      add_any = {
        { all = {"отменить", "звонок"} },
      },
    },
    {
      id = "faq.gameplay.warn_reason",
      add_any = {
        { all = {"историю", "наказан"} },
        { all = {"посмотреть", "наказан"} },
        { all = {"история", "наказан"} },
      },
    },
    {
      id = "faq.navigation.gps_7-2",
      add_exclusions = {
        { all = {"чекнуть", "скилл"} },
        { all = {"посмотреть", "скилл"} },
        { all = {"скилл", "оруж"} },
      },
    },

  },
  new_intents = {
    {
      id = "faq.gameplay.n",
      context = "faq",
      category = "gameplay",
      label = "Non-RP чат /n",
      enabled = true,
      action = { type = "reply", text = "/n" },
      triggers = {
        any = {
          { all = {"писать", "нон", "рп"} },
          { all = {"non", "rp", "чат"} },
        },
      },
    },
    {
      id = "faq.gameplay.rent_x",
      context = "faq",
      category = "gameplay",
      label = "Аренда /x",
      enabled = true,
      action = { type = "reply", text = "/x" },
      triggers = {
        any = {
          { all = {"арендовать", "скутер"} },
          { all = {"аренд", "скутер"} },
          { token = "rentcar" },
        },
      },
    },
    {
      id = "faq.gameplay.sellskin",
      context = "faq",
      category = "gameplay",
      label = "Продать скин /sellskin",
      enabled = true,
      action = { type = "reply", text = "/sellskin" },
      triggers = {
        any = {
          { all = {"продать", "скин"} },
          { all = {"sellskin"} },
        },
      },
    },
    {
      id = "faq.gameplay.badge",
      context = "faq",
      category = "gameplay",
      label = "Семья над головой /badge",
      enabled = true,
      action = { type = "reply", text = "/badge" },
      triggers = {
        any = {
          { all = {"семья", "над", "голов"} },
          { all = {"badge", "семь"} },
        },
      },
    },
    {
      id = "faq.gameplay.time",
      context = "faq",
      category = "gameplay",
      label = "Время наказания /time",
      enabled = true,
      action = { type = "reply", text = "/time" },
      triggers = {
        any = {
          { all = {"сколько", "сидеть"} },
          { all = {"сколько", "осталось", "сидеть"} },
        },
      },
    },
    {
      id = "faq.communication.sms_1001",
      context = "faq",
      category = "communication",
      label = "Радио LS /sms 1001",
      enabled = true,
      action = { type = "reply", text = "/sms 1001" },
      triggers = {
        any = {
          { all = {"писать", "радио", "лс"} },
          { all = {"радио", "лс"} },
        },
      },
    },
    {
      id = "faq.gameplay.lrec",
      context = "faq",
      category = "gameplay",
      label = "Релог /lrec",
      enabled = true,
      action = { type = "reply", text = "/lrec 0" },
      triggers = {
        any = {
          { all = {"релог"} },
          { token = "relog" },
        },
      },
    },
    {
      id = "faq.gameplay.donate_missing",
      context = "faq",
      category = "gameplay",
      label = "Не пришёл донат",
      enabled = true,
      action = { type = "reply", text = "Напишите в технический раздел на форуме ARP" },
      triggers = {
        any = {
          { all = {"не", "пришел", "донат"} },
          { all = {"не", "пришёл", "донат"} },
          { all = {"донат", "не", "приш"} },
        },
      },
    },
    {
      id = "faq.gameplay.newspaper",
      context = "faq",
      category = "gameplay",
      label = "Продать газету",
      enabled = true,
      action = { type = "reply", text = "продайте через инвентарь или NPC газетчик" },
      triggers = {
        any = {
          { all = {"продать", "газет"} },
        },
      },
    },
    {
      id = "faq.gameplay.eat_quest",
      context = "faq",
      category = "gameplay",
      label = "Квест «поесть»",
      enabled = true,
      action = { type = "reply", text = "съешьте еду полностью из инвентаря (/i), иногда нужно выйти из интерьера" },
      triggers = {
        any = {
          { all = {"кушаю", "еду", "задание"} },
          { all = {"квест", "поесть"} },
          { all = {"задание", "покушать"} },
          { all = {"еду", "квест", "не"} },
          { all = {"кушаю", "еду", "квест"} },
        },
      },
    },
    {
      id = "faq.gameplay.phone_number",
      context = "faq",
      category = "communication",
      label = "Номер телефона",
      enabled = true,
      action = { type = "reply", text = "свой номер: /number; чужой — через объявление /ad или спросите в RP" },
      triggers = {
        any = {
          { all = {"узнать", "номер", "телефон"} },
          { all = {"мой", "номер", "телефон"} },
          { all = {"номер", "телефона", "игрок"} },
          { all = {"как", "узнать", "номер"} },
        },
      },
      exclusions = {
        { all = {"купить", "телефон"} },
        { all = {"позвонить"} },
      },
    },
-- [[ corpus_review_autogen new_intents ]]
    {
      id = "faq.gameplay.mask_reset",
      context = "faq",
      category = "gameplay",
      label = "Как сбросить маску?",
      enabled = true,
      action = { type = "reply", text = "/end /reset" },
      triggers = {
        any = {
          { all = {"сбросить", "маску"} },
        },
      },
    },
    {
      id = "faq.gameplay.leave_hint",
      context = "faq",
      category = "gameplay",
      label = "как покинуть организацию",
      enabled = true,
      action = { type = "reply", text = "/leave или попросите в /f /r уволить вас" },
      triggers = {
        any = {
          { all = {"покинуть", "организацию"} },
          { all = {"уволиться", "фракции"} },
          { all = {"уволиться"} },
        },
      },
      exclusions = {
        { all = {"лидаков"} },
        { all = {"замов"} },
      },
    },
    {
      id = "faq.gameplay.races_schedule",
      context = "faq",
      category = "gameplay",
      label = "как часто проводят гонки?",
      enabled = true,
      action = { type = "reply", text = "Каждые 3 часа" },
      triggers = {
        any = {
          { all = {"часто", "проводят", "гонки"} },
        },
      },
    },
    {
      id = "faq.gameplay.warn_reason",
      context = "faq",
      category = "gameplay",
      label = "за что варн дали ?",
      enabled = true,
      action = { type = "reply", text = "/warninfo /log" },
      triggers = {
        any = {
          { all = {"варн", "дали"} },
        },
      },
    },
    {
      id = "faq.gameplay.weapon_buy_hint",
      context = "faq",
      category = "gameplay",
      label = "где взять оружие",
      enabled = true,
      action = { type = "reply", text = "/price - Оружейные магазины (нужна лицензия на оружие). Или купите у бандитов в гетто" },
      triggers = {
        any = {
          { all = {"взять", "оружие"} },
        },
      },
    },
    {
      id = "faq.gameplay.chat_font",
      context = "faq",
      category = "gameplay",
      label = "Размер текста чата",
      enabled = true,
      action = { type = "reply", text = "/pagesize /fontsize" },
      triggers = {
        any = {
          { all = {"увеличить", "текст", "чата"} },
          { all = {"pagesize", "fontsize"} },
        },
      },
    },
    {
      id = "faq.gameplay.regst",
      context = "faq",
      category = "gameplay",
      label = "как посмотреть ники которые зарегались на меня?",
      enabled = true,
      action = { type = "reply", text = "/regst" },
      triggers = {
        any = {
          { all = {"посмотреть", "ники", "которые", "зарегались"} },
        },
      },
    },
    {
      id = "faq.gameplay.divorce",
      context = "faq",
      category = "gameplay",
      label = "как развестись щас в церкви",
      enabled = true,
      action = { type = "reply", text = "/divorce" },
      triggers = {
        any = {
          { all = {"развестись", "церкви"} },
        },
      },
    },
    {
      id = "faq.gameplay.restart_time",
      context = "faq",
      category = "gameplay",
      label = "Во сколько рестарт сервера?",
      enabled = true,
      action = { type = "reply", text = "Примерно в 5:02" },
      triggers = {
        any = {
          { all = {"сколько", "рестарт", "сервера"} },
        },
      },
    },
    {
      id = "faq.gameplay.sellmycar",
      context = "faq",
      category = "gameplay",
      label = "Где продать машину игроку?",
      enabled = true,
      action = { type = "reply", text = "/sellmycar" },
      triggers = {
        any = {
          { all = {"продать", "машину", "игроку"} },
          { all = {"человеку", "транспорт", "продатиь"} },
          { all = {"продать", "тс"} },
          { all = {"продать", "транспорт", "игрок"} },
          { all = {"команда", "продать", "тс"} },
          { all = {"какой", "командой", "продать", "тс"} },
        },
      },
      exclusions = {
        { all = {"гос"} },
      },
    },
    {
      id = "faq.gameplay.factory_tank",
      context = "faq",
      category = "gameplay",
      label = "Где цистерну взять чтобы квест выполнить на заводе",
      enabled = true,
      action = { type = "reply", text = "Цистерна рядом с местом, где фуру брали" },
      triggers = {
        any = {
          { all = {"цистерну", "взять", "квест", "выполнить"} },
        },
      },
    },
    {
      id = "faq.gameplay.timestamp",
      context = "faq",
      category = "gameplay",
      label = "Как сделать в чате время",
      enabled = true,
      action = { type = "reply", text = "/timestamp" },
      triggers = {
        any = {
          { all = {"сделать", "чате", "время"} },
        },
      },
    },
    {
      id = "faq.gameplay.weapon_no_holster",
      context = "faq",
      category = "gameplay",
      label = "как убрать оружие в инвантарь",
      enabled = true,
      action = { type = "reply", text = "Никак" },
      triggers = {
        any = {
          { all = {"убрать", "оружие", "инвантарь"} },
        },
      },
    },
    {
      id = "faq.gameplay.hotel_reset_midnight",
      context = "faq",
      category = "gameplay",
      label = "Во сколько отели слетают?",
      enabled = true,
      action = { type = "reply", text = "В полночь" },
      triggers = {
        any = {
          { all = {"сколько", "отели", "слетают"} },
        },
      },
    },
    {
      id = "faq.gameplay.leave_family",
      context = "faq",
      category = "gameplay",
      label = "как выйти с фамы",
      enabled = true,
      action = { type = "reply", text = "/family - Покинуть семью" },
      triggers = {
        any = {
          { all = {"выйти", "фамы"} },
        },
      },
    },
    {
      id = "faq.gameplay.voice_key_f9",
      context = "faq",
      category = "gameplay",
      label = "нельзя никак другую клавишу поставить на микрофон",
      enabled = true,
      action = { type = "reply", text = "F9 - настройки микрофона" },
      triggers = {
        any = {
          { all = {"нельзя", "никак", "другую", "клавишу"} },
          { all = {"изменить", "кнопку", "голосового", "чата"} },
        },
      },
    },
    {
      id = "faq.gameplay.org_level_3",
      context = "faq",
      category = "gameplay",
      label = "с какого уровня в оргу вступать?",
      enabled = true,
      action = { type = "reply", text = "С 3 уровня" },
      triggers = {
        any = {
          { all = {"какого", "уровня", "оргу", "вступать"} },
        },
      },
    },
    {
      id = "faq.gameplay.wanted_stars",
      context = "faq",
      category = "gameplay",
      label = "как снять звезду",
      enabled = true,
      action = { type = "reply", text = "Сдаться в полицейском участке или ждать. 1 звезда спадает за 2 пейдея" },
      triggers = {
        any = {
          { all = {"снять", "звезду"} },
        },
      },
    },
    {
      id = "faq.gameplay.hotel_pay_npc",
      context = "faq",
      category = "gameplay",
      label = "где оплатить отель",
      enabled = true,
      action = { type = "reply", text = "На первом этаже у НПС" },
      triggers = {
        any = {
          { all = {"оплатить", "отель"} },
        },
      },
    },
    {
      id = "faq.gameplay.faction_roster",
      context = "faq",
      category = "gameplay",
      label = "как посмотреть список учасником организации?",
      enabled = true,
      action = { type = "reply", text = "/find /showall" },
      triggers = {
        any = {
          { all = {"посмотреть", "список", "учасником", "организации"} },
          { all = {"посмотреь", "состав", "фракции"} },
        },
      },
    },
    {
      id = "faq.gameplay.armoff",
      context = "faq",
      category = "gameplay",
      label = "как снять броню",
      enabled = true,
      action = { type = "reply", text = "/armoff" },
      triggers = {
        any = {
          { all = {"снять", "броню"} },
          { all = {"снять", "броник"} },
        },
      },
    },
    {
      id = "faq.gameplay.gym_ls",
      context = "faq",
      category = "gameplay",
      label = "где в лс спорт зал ?",
      enabled = true,
      action = { type = "reply", text = "/price" },
      triggers = {
        any = {
          { all = {"спорт", "зал"} },
        },
      },
    },
    {
      id = "faq.gameplay.phone_lookup",
      context = "faq",
      category = "gameplay",
      label = "Как узнать номер человека?",
      enabled = true,
      action = { type = "reply", text = "/id - если игрок не скрыл номер, он будет там. Либо /ad Ищу человека.." },
      triggers = {
        any = {
          { all = {"узнать", "номер", "человека"} },
        },
      },
    },
    {
      id = "faq.gameplay.shop_247",
      context = "faq",
      category = "gameplay",
      label = "как найти 24/7",
      enabled = true,
      action = { type = "reply", text = "/price" },
      triggers = {
        any = {
          { all = {"найти", "24"} },
          { all = {"24", "на", "7"} },
          { all = {"гпс", "24"} },
        },
      },
    },
    {
      id = "faq.gameplay.newspaper_sale",
      context = "faq",
      category = "gameplay",
      label = "а как газету продать",
      enabled = true,
      action = { type = "reply", text = "/sale" },
      triggers = {
        any = {
          { all = {"газету", "продать"} },
        },
      },
    },
    {
      id = "faq.gameplay.leaders_zam_hint",
      context = "faq",
      category = "gameplay",
      label = "как посмотреть есть ли лидеры или замы организации",
      enabled = true,
      action = { type = "reply", text = "/leaders /zamlist" },
      triggers = {
        any = {
          { all = {"посмотреть", "есть", "лидеры", "замы"} },
        },
      },
    },
    {
      id = "faq.gameplay.bank_gps",
      context = "faq",
      category = "gameplay",
      label = "как найти банк по gps",
      enabled = true,
      action = { type = "reply", text = "/gps - Банки или /price" },
      triggers = {
        any = {
          { all = {"найти", "банк", "gps"} },
        },
      },
    },
    {
      id = "faq.gameplay.wbook",
      context = "faq",
      category = "gameplay",
      label = "трудовую книжку как смотреть",
      enabled = true,
      action = { type = "reply", text = "/wbook" },
      triggers = {
        any = {
          { all = {"трудовую", "книжку", "смотреть"} },
        },
      },
    },
    {
      id = "faq.gameplay.newspaper_team",
      context = "faq",
      category = "gameplay",
      label = "как посмотреть скок я уже газет продал",
      enabled = true,
      action = { type = "reply", text = "/team" },
      triggers = {
        any = {
          { all = {"посмотреть", "скок", "газет", "продал"} },
        },
      },
    },
    {
      id = "faq.gameplay.radio",
      context = "faq",
      category = "gameplay",
      label = "как включить радио станции?",
      enabled = true,
      action = { type = "reply", text = "/radio /play" },
      triggers = {
        any = {
          { all = {"включить", "радио", "станции"} },
        },
      },
    },
    {
      id = "faq.gameplay.buy_axe",
      context = "faq",
      category = "gameplay",
      label = "где купить аксі",
      enabled = true,
      action = { type = "reply", text = "/gps 1 - рынок или /price - салоны красоты" },
      triggers = {
        any = {
          { all = {"купить", "акс"} },
        },
      },
    },
    {
      id = "faq.gameplay.headmove",
      context = "faq",
      category = "gameplay",
      label = "как сделать чтоб голова не поворачивалась",
      enabled = true,
      action = { type = "reply", text = "/headmove" },
      triggers = {
        any = {
          { all = {"сделать", "чтоб", "голова", "поворачивалась"} },
        },
      },
    },
    {
      id = "faq.gameplay.live_roommate",
      context = "faq",
      category = "gameplay",
      label = "как в дом подселить?",
      enabled = true,
      action = { type = "reply", text = "/live" },
      triggers = {
        any = {
          { all = {"дом", "подселить"} },
        },
      },
    },
    {
      id = "faq.gameplay.robcar",
      context = "faq",
      category = "gameplay",
      label = "какая команда чтобы ограбить машину",
      enabled = true,
      action = { type = "reply", text = "/robcar" },
      triggers = {
        any = {
          { all = {"команда", "ограбить", "машину"} },
        },
      },
    },
    {
      id = "faq.gameplay.house_by_number",
      context = "faq",
      category = "gameplay",
      label = "как найти дом по номеру?",
      enabled = true,
      action = { type = "reply", text = "В риелторском агентстве. /gps 8-11-44" },
      triggers = {
        any = {
          { all = {"найти", "дом", "номеру"} },
        },
      },
    },
    {
      id = "faq.gameplay.shooting_range",
      context = "faq",
      category = "gameplay",
      label = "Где прокачать стрельбу?",
      enabled = true,
      action = { type = "reply", text = "В тире - /gps 7-2" },
      triggers = {
        any = {
          { all = {"прокачать", "стрельбу"} },
        },
      },
    },
    {
      id = "faq.gameplay.mechanic_fill",
      context = "faq",
      category = "gameplay",
      label = "как на авто механике заправить человека?",
      enabled = true,
      action = { type = "reply", text = "/fill - заправить, /repair - починить" },
      triggers = {
        any = {
          { all = {"авто", "механике", "заправить", "человека"} },
          { all = {"чела", "починить", "механик"} },
        },
      },
    },
    {
      id = "faq.navigation.gps_used_market",
      context = "faq",
      category = "navigation",
      label = "GPS б/у рынок",
      enabled = true,
      action = { type = "reply", text = "/gps — б/у рынок" },
      triggers = {
        any = {
          { all = {"бу", "рынок"} },
          { all = {"где", "бу"} },
          { all = {"бу", "авто", "где"} },
          { all = {"найти", "бу", "рынок"} },
        },
      },
    },
    {
      id = "faq.gameplay.mechanic_job",
      context = "faq",
      category = "gameplay",
      label = "Работа автомехаником",
      enabled = true,
      action = { type = "reply", text = "Устройтесь через /gps 1 (мэрия), нужен 2 уровень" },
      triggers = {
        any = {
          { all = {"работ", "автомеханик"} },
          { all = {"устроиться", "автомеханик"} },
          { all = {"как", "механик", "работ"} },
          { all = {"тачка", "автомеханик"} },
        },
      },
    },
    {
      id = "faq.gameplay.friend",
      context = "faq",
      category = "gameplay",
      label = "Контакты /friend",
      enabled = true,
      action = { type = "reply", text = "/friend [номер]" },
      triggers = {
        any = {
          { all = {"добавить", "контакт"} },
          { token = "friend" },
          { all = {"список", "контакт"} },
        },
      },
    },
    {
      id = "faq.gameplay.gym_timing",
      context = "faq",
      category = "gameplay",
      label = "Тайминг в спортзале",
      enabled = true,
      action = { type = "reply", text = "Подойдите к тренажёру в спортзале (/price), нажмите Enter в нужный момент" },
      triggers = {
        any = {
          { all = {"накачать", "сил"} },
          { all = {"тайминг", "спортзал"} },
          { all = {"единиц", "спортзал"} },
          { all = {"сколько", "качалк"} },
          { all = {"тайминг", "спортзал"} },
        },
      },
    },
  },
}
