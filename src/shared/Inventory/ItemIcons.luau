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
