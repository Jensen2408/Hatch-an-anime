-- ReplicatedStorage.FeedbackMenu.FeedbackConfig  (ModuleScript, client)
-- Every number for the Feedback window (FeedbackComponent). The art is ReplicatedStorage.MenuArt (the window
-- background from assets/ui/menus3, tab pieces); rects are measured on it, in pixels of the StudTheme canvas
-- (1160 x 730) the window is drawn on.
local FeedbackConfig = {}

FeedbackConfig.Kinds = {
    { Key = "Bug", Label = "🐞 BUG" },
    { Key = "Idea", Label = "💡 IDEA" },
    { Key = "Other", Label = "💬 OTHER" },
}

FeedbackConfig.MaxLength = 500 -- the server re-checks and trims (FeedbackService)

-- Rect = { x, y, w, h } in canvas pixels
FeedbackConfig.Layout = {
    CloseRect = { 1074, 15, 66, 62 }, -- the drawn X
    IntroRect = { 60, 104, 1040, 50 },
    IntroSize = 40,
    Intro = "Help us make Hatch an Anime better",
    PromptRect = { 60, 164, 1040, 32 },
    PromptSize = 26,
    Prompt = "Choose a category",
    TabRects = { { 60, 231, 318, 58 }, { 406, 231, 330, 58 }, { 765, 231, 330, 58 } },
    TabTextSize = 28,
    InputRect = { 56, 310, 1048, 241 }, -- the drawn text box
    InputInset = 18,
    InputTextSize = 26,
    Placeholder = "Tell us what happened...",
    CounterRect = { 60, 562, 700, 30 },
    CounterSize = 24,
    NoteRect = { 78, 642, 586, 46 }, -- inside the drawn note strip
    NoteSize = 22,
    Note = "Please do not include personal information.",
    SendRect = { 704, 638, 406, 58 }, -- the drawn green button
    SendSize = 32,
    StatusSeconds = 3,
}

return FeedbackConfig
