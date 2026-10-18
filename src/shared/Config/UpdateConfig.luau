-- UpdateConfig: edit this for each update. Players see a countdown before LaunchTime
-- and a "What's new" window after it (once per update).
return {
    Id = "update-1", -- change for every new update so the popup shows again
    Title = "UPDATE 1",
    -- Sunday 18 Oct 2026, 20:00 Danish time (18:00 UTC)
    LaunchTime = 1792346400,
    ShowCountdown = true,
    Items = {
        "🎨 Brand new UI: menus, buttons, money and hotbar",
        "📜 Quest tracker on screen",
        "🎁 Daily rewards button",
        "🌙 New night event banner",
        -- add more lines here (one per thing in the update)
    },
}
