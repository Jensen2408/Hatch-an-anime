-- ReplicatedStorage.UpcomingConfig  (ModuleScript, shared)
-- Everything that is "coming soon": updates and events. StarterPlayerScripts.UpcomingTeaser shows a countdown
-- card for the next item (click it for the full list) and, after an update's time has passed, a "What's new"
-- window once per update Id.
--
-- Times are Unix seconds (UTC). Danish time in November is UTC+1, so 20:00 Danish = 19:00 UTC.
-- To add one more: copy a block, give it a new Id. Items are shown in time order. Past events disappear;
-- past updates stay for the "What's new" window until you remove them.
return {
    ShowCard = false, -- the old top-right countdown card; the in-world Workspace.UpdateBoard replaced it
    GroupId = 251149752, -- community for the JOIN GROUP buttons
    Items = {
        {
            Id = "update-2", -- change for every new update so the "What's new" window shows again
            Kind = "update", -- "update" or "event"
            Title = "NEW EVENTS??",
            Subtitle = "Something is brewing…",
            Time = 1793991600, -- Friday 6 Nov 2026, 20:00 Danish time
            EventId = "2048853151433491089", -- Creator Hub event: the board's NOTIFY ME opens its popup (live game only)
            BoardImage = "rbxassetid://136851747175534", -- game thumbnail (logo + bridge), as on the Creator Hub event list
            Image = "rbxassetid://136851747175534", -- game thumbnail
            Color = "purple", -- red | blue | tide | green | gold | pink | purple
            -- filled in when the update goes live (one line per thing); shown in the "What's new" window
            WhatsNew = {},
        },
        {
            Id = "event-qqq",
            Kind = "event",
            Title = "???",
            Subtitle = "New things. That's all we're saying.",
            Time = 1794164400, -- Sunday 8 Nov 2026, 20:00 Danish time
            EventId = "5789811172813439632",
            BoardImage = "rbxassetid://120301417685985", -- Sunday ??? picture (wide)
            Image = "rbxassetid://120649551930679", -- Sunday ??? picture (square crop of assets\updates\qqq_event_1920x1080.png)
            Color = "gold",
        },
    },
}
