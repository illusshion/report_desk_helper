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
      id = "faq.gameplay.drugs",
      add_any = {
        { all = {"курить", "сигар"} },
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
        { all = {"как", "чинить"} },
        { token = "починит" },
        { all = {"почините", "пж"} },
        { all = {"купить", "ремкомп"} },
        { all = {"где", "ремкомп"} },
        { all = {"где", "купить", "ремкомп"} },
        { all = {"машину", "починить"} },
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
        { all = {"активн", "собес"} },
        { all = {"собеседован", "смотр"} },
        { all = {"где", "собес"} },
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
        { all = {"найти", "банк"} },
        { all = {"где", "банк"} },
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
  },
}
