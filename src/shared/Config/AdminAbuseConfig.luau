-- ReplicatedStorage.AdminAbuseConfig  (ModuleScript, shared)
-- The three admin abuses. AdminAbuseService writes workspace attributes "Abuse<Kind>Multiplier" and "Abuse<Kind>EndsAt"
-- (server time) while one runs; both are nil otherwise. Art sources: assets/ui/abuse.
local AdminAbuseConfig = {}

AdminAbuseConfig.Order = { "Hatch", "Cash", "Legendary" } -- also the order of the potion row

AdminAbuseConfig.Kinds = {
    Hatch = {
        Name = "Hatch Speed",
        Min = 2,
        Max = 4,
        Potion = "rbxassetid://115930666466761", -- potion_hatch.png
        Rain = "rbxassetid://135502024624058", -- rain_egg.png
        Glow = Color3.fromRGB(110, 255, 150),
    },
    Cash = {
        Name = "Cash",
        Min = 2,
        Max = 4,
        Potion = "rbxassetid://81475014939582", -- potion_cash.png
        Rain = "rbxassetid://74648427411854", -- the coin of the Cash UI
        Glow = Color3.fromRGB(255, 205, 70),
    },
    Legendary = {
        Name = "Legendary Eggs",
        Min = 2,
        Max = 20, -- x20 = a Legendary every 36 s at the latest
        Potion = "rbxassetid://127158159753492", -- potion_legendary.png
        Rain = "rbxassetid://72879864270431", -- rain_legendary.png
        Glow = Color3.fromRGB(255, 110, 235),
    },
}

AdminAbuseConfig.MaxMinutes = 1440

return AdminAbuseConfig
