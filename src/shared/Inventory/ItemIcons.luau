-- Item pictures for the Roblox backpack (2026-11-08). Made in Studio's icon booth (magenta key), see assets/icons.
-- ItemIcons.Egg[eggType] / ItemIcons.Character[characterId] -> image id; ItemIcons.ForTool(tool) picks one.
local ItemIcons = {}
ItemIcons.Egg = {
    Academy = "rbxassetid://130677287666656",
    Alien = "rbxassetid://120083420148182",
    Curse = "rbxassetid://131655204066384",
    Devil = "rbxassetid://113240283815383",
    God = "rbxassetid://90594569652925",
    Guild = "rbxassetid://83536764179291",
    Hero = "rbxassetid://86081732331130",
    Hunter = "rbxassetid://101989299721046",
    Magic = "rbxassetid://127982397386975",
    Mecha = "rbxassetid://123719951594590",
    Pirate = "rbxassetid://88474668014235",
    Power = "rbxassetid://119898764749126",
    Shinobi = "rbxassetid://112053617741362",
    Slayer = "rbxassetid://78133867264415",
    Soul = "rbxassetid://98382888703904",
    Sports = "rbxassetid://122454277737927",
    Titan = "rbxassetid://134999034814274",
}
ItemIcons.Character = {
    Asta = "rbxassetid://84672301638208",
    Asuka = "rbxassetid://107391060258805",
    Bakugo = "rbxassetid://88376991816943",
    Byakuya = "rbxassetid://89196365983765",
    CosmicOracle = "rbxassetid://112344489647089",
    Deku = "rbxassetid://112022939106509",
    Denji = "rbxassetid://112013159481506",
    Eren = "rbxassetid://90489229446231",
    Erza = "rbxassetid://91771509965884",
    Genos = "rbxassetid://130840971526146",
    Gojo = "rbxassetid://132650766045703",
    Goku = "rbxassetid://139296198206607",
    Gon = "rbxassetid://95660307022994",
    HinataCourt = "rbxassetid://115970769888929",
    HinataHyuga = "rbxassetid://113676934135121",
    Hisoka = "rbxassetid://114762424546931",
    Ichigo = "rbxassetid://88024089473142",
    Isagi = "rbxassetid://120508136329034",
    Itadori = "rbxassetid://119525786746376",
    Kakashi = "rbxassetid://101701889512182",
    Killua = "rbxassetid://118706696781269",
    Kuroko = "rbxassetid://74789935218991",
    Lelouch = "rbxassetid://73749763593346",
    Levi = "rbxassetid://138787416230082",
    Lucy = "rbxassetid://92292679233702",
    Luffy = "rbxassetid://100823522894607",
    Makima = "rbxassetid://123998405873542",
    Mikasa = "rbxassetid://128430108722843",
    Momo = "rbxassetid://75329482378278",
    MoonGoddess = "rbxassetid://116133617192520",
    Nami = "rbxassetid://87458326621366",
    Naruto = "rbxassetid://74751876820622",
    Natsu = "rbxassetid://98922960834701",
    Nezuko = "rbxassetid://123813053463521",
    Noelle = "rbxassetid://125559112689132",
    Okarun = "rbxassetid://107791255070563",
    Piccolo = "rbxassetid://112682428246357",
    PowerFiend = "rbxassetid://110851204578682",
    Rukia = "rbxassetid://87539622163837",
    Saitama = "rbxassetid://126504665073982",
    Sasuke = "rbxassetid://128739041316039",
    Shinji = "rbxassetid://75609566147201",
    Sukuna = "rbxassetid://136354061251107",
    SunGod = "rbxassetid://111311953290744",
    Tanjiro = "rbxassetid://100536814647854",
    Tatsumaki = "rbxassetid://124185589991819",
    Todoroki = "rbxassetid://80695186580143",
    TurboGranny = "rbxassetid://83494314389956",
    Vegeta = "rbxassetid://120419292253920",
    Yuno = "rbxassetid://78866825294421",
    Zenitsu = "rbxassetid://116076279383741",
    Zoro = "rbxassetid://91008637174760",
}

-- Grey copies of the same pictures (2026-11-08): the backpack tints them for mutations (gold, silver, diamond, lava,
-- rainbow), the same way the game colours mutated models. ItemIcons.Gray[picture id] -> grey picture id.
ItemIcons.Gray = {
    ["rbxassetid://84672301638208"] = "rbxassetid://124214122680132", -- Char_Asta
    ["rbxassetid://107391060258805"] = "rbxassetid://105778482415288", -- Char_Asuka
    ["rbxassetid://88376991816943"] = "rbxassetid://85174408659344", -- Char_Bakugo
    ["rbxassetid://89196365983765"] = "rbxassetid://108945648160529", -- Char_Byakuya
    ["rbxassetid://112344489647089"] = "rbxassetid://128599069850294", -- Char_CosmicOracle
    ["rbxassetid://112022939106509"] = "rbxassetid://122388761295973", -- Char_Deku
    ["rbxassetid://112013159481506"] = "rbxassetid://133367181063474", -- Char_Denji
    ["rbxassetid://90489229446231"] = "rbxassetid://102533441413744", -- Char_Eren
    ["rbxassetid://91771509965884"] = "rbxassetid://139142736218945", -- Char_Erza
    ["rbxassetid://130840971526146"] = "rbxassetid://139121823403789", -- Char_Genos
    ["rbxassetid://132650766045703"] = "rbxassetid://119776273398263", -- Char_Gojo
    ["rbxassetid://139296198206607"] = "rbxassetid://135561325069443", -- Char_Goku
    ["rbxassetid://95660307022994"] = "rbxassetid://115938258602761", -- Char_Gon
    ["rbxassetid://115970769888929"] = "rbxassetid://95889043907977", -- Char_HinataCourt
    ["rbxassetid://113676934135121"] = "rbxassetid://114660945704087", -- Char_HinataHyuga
    ["rbxassetid://114762424546931"] = "rbxassetid://114988054086693", -- Char_Hisoka
    ["rbxassetid://88024089473142"] = "rbxassetid://92294593011720", -- Char_Ichigo
    ["rbxassetid://120508136329034"] = "rbxassetid://86839885773401", -- Char_Isagi
    ["rbxassetid://119525786746376"] = "rbxassetid://90236331140991", -- Char_Itadori
    ["rbxassetid://101701889512182"] = "rbxassetid://108947885052393", -- Char_Kakashi
    ["rbxassetid://118706696781269"] = "rbxassetid://137342634020071", -- Char_Killua
    ["rbxassetid://74789935218991"] = "rbxassetid://129902913134467", -- Char_Kuroko
    ["rbxassetid://73749763593346"] = "rbxassetid://77494510680715", -- Char_Lelouch
    ["rbxassetid://138787416230082"] = "rbxassetid://127122447083157", -- Char_Levi
    ["rbxassetid://92292679233702"] = "rbxassetid://71118562982608", -- Char_Lucy
    ["rbxassetid://100823522894607"] = "rbxassetid://135591038311157", -- Char_Luffy
    ["rbxassetid://123998405873542"] = "rbxassetid://136180478913730", -- Char_Makima
    ["rbxassetid://128430108722843"] = "rbxassetid://106410147727997", -- Char_Mikasa
    ["rbxassetid://75329482378278"] = "rbxassetid://87062661259332", -- Char_Momo
    ["rbxassetid://116133617192520"] = "rbxassetid://118249012805547", -- Char_MoonGoddess
    ["rbxassetid://87458326621366"] = "rbxassetid://121201376865149", -- Char_Nami
    ["rbxassetid://74751876820622"] = "rbxassetid://82386397230460", -- Char_Naruto
    ["rbxassetid://98922960834701"] = "rbxassetid://81254496656274", -- Char_Natsu
    ["rbxassetid://123813053463521"] = "rbxassetid://94532303699069", -- Char_Nezuko
    ["rbxassetid://125559112689132"] = "rbxassetid://93077938590706", -- Char_Noelle
    ["rbxassetid://107791255070563"] = "rbxassetid://105430812257358", -- Char_Okarun
    ["rbxassetid://112682428246357"] = "rbxassetid://131797059855857", -- Char_Piccolo
    ["rbxassetid://110851204578682"] = "rbxassetid://96928225934074", -- Char_PowerFiend
    ["rbxassetid://87539622163837"] = "rbxassetid://117338853481041", -- Char_Rukia
    ["rbxassetid://126504665073982"] = "rbxassetid://134692301400580", -- Char_Saitama
    ["rbxassetid://128739041316039"] = "rbxassetid://127566909131453", -- Char_Sasuke
    ["rbxassetid://75609566147201"] = "rbxassetid://99820911096906", -- Char_Shinji
    ["rbxassetid://136354061251107"] = "rbxassetid://113117592558347", -- Char_Sukuna
    ["rbxassetid://111311953290744"] = "rbxassetid://118046367531498", -- Char_SunGod
    ["rbxassetid://100536814647854"] = "rbxassetid://127575284437086", -- Char_Tanjiro
    ["rbxassetid://124185589991819"] = "rbxassetid://125210145907215", -- Char_Tatsumaki
    ["rbxassetid://80695186580143"] = "rbxassetid://119827225390327", -- Char_Todoroki
    ["rbxassetid://83494314389956"] = "rbxassetid://125148746530813", -- Char_TurboGranny
    ["rbxassetid://120419292253920"] = "rbxassetid://80103083308142", -- Char_Vegeta
    ["rbxassetid://78866825294421"] = "rbxassetid://86078013823060", -- Char_Yuno
    ["rbxassetid://116076279383741"] = "rbxassetid://113212353611469", -- Char_Zenitsu
    ["rbxassetid://91008637174760"] = "rbxassetid://112662947599121", -- Char_Zoro
    ["rbxassetid://130677287666656"] = "rbxassetid://138479792919754", -- Egg_Academy
    ["rbxassetid://120083420148182"] = "rbxassetid://106449357627958", -- Egg_Alien
    ["rbxassetid://131655204066384"] = "rbxassetid://111848542592312", -- Egg_Curse
    ["rbxassetid://113240283815383"] = "rbxassetid://99830292150496", -- Egg_Devil
    ["rbxassetid://90594569652925"] = "rbxassetid://72522792578665", -- Egg_God
    ["rbxassetid://83536764179291"] = "rbxassetid://119263199962596", -- Egg_Guild
    ["rbxassetid://86081732331130"] = "rbxassetid://136644189388669", -- Egg_Hero
    ["rbxassetid://101989299721046"] = "rbxassetid://73941902241829", -- Egg_Hunter
    ["rbxassetid://127982397386975"] = "rbxassetid://92322264008916", -- Egg_Magic
    ["rbxassetid://123719951594590"] = "rbxassetid://132837094217707", -- Egg_Mecha
    ["rbxassetid://88474668014235"] = "rbxassetid://139627971550766", -- Egg_Pirate
    ["rbxassetid://119898764749126"] = "rbxassetid://123097019860377", -- Egg_Power
    ["rbxassetid://112053617741362"] = "rbxassetid://90981459796981", -- Egg_Shinobi
    ["rbxassetid://78133867264415"] = "rbxassetid://77784407314678", -- Egg_Slayer
    ["rbxassetid://98382888703904"] = "rbxassetid://73064779380300", -- Egg_Soul
    ["rbxassetid://122454277737927"] = "rbxassetid://78547816659898", -- Egg_Sports
    ["rbxassetid://134999034814274"] = "rbxassetid://78061771556366", -- Egg_Titan
}

function ItemIcons.ForTool(tool: Tool): string?
    local characterId = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    if characterId and ItemIcons.Character[characterId] then
        return ItemIcons.Character[characterId]
    end
    local eggType = tool:GetAttribute("EggType") or tool:GetAttribute("EggId")
    if eggType and ItemIcons.Egg[eggType] then
        return ItemIcons.Egg[eggType]
    end
    -- fall back on the tool's name: "Gold Hero Egg", "Diamond Naruto Character"
    local name = tool.Name
    local egg = name:match("(%w+) Egg$")
    if egg and ItemIcons.Egg[egg] then
        return ItemIcons.Egg[egg]
    end
    local character = name:match("(%w+) Character$")
    if character and ItemIcons.Character[character] then
        return ItemIcons.Character[character]
    end
    return nil
end

return ItemIcons
