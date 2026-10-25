-- ReplicatedStorage.FeedbackMenu.FeedbackConfig  (ModuleScript, client)
-- Every number for the Feedback window (FeedbackComponent). Layout values come from the Figma frame
-- "05 Feedback" (Hatch an Anime • Screens & Components), measured from the Panel's top-left corner, in Figma
-- pixels, on the StudTheme canvas (1160x730). Colors, fonts and the kit pieces: StudKit.
--
-- Tidied overlaps: the note line (y 650..685) and the SEND button (y 640..696) now share one centre line;
-- the status of a send replaces the note while it shows.
local FeedbackConfig = {}

FeedbackConfig.Title = "FEEDBACK" -- Header/blue

FeedbackConfig.Kinds = {
    { Key = "Bug", Label = "🐞 BUG" },
    { Key = "Idea", Label = "💡 IDEA" },
    { Key = "Other", Label = "💬 OTHER" },
}

FeedbackConfig.MaxLength = 500 -- the server re-checks and trims (FeedbackService)

-- Rect = { x, y, w, h } in canvas pixels
FeedbackConfig.Layout = {
    IntroRect = { 46, 120, 1068, 50 },
    IntroSize = 38,
    Intro = "Help us make Hatch an Anime better",
    PromptRect = { 46, 190, 1068, 32 },
    PromptSize = 24,
    Prompt = "Choose a category",
    Tabs = { Y = 234, Height = 58, Xs = { 46, 400, 754 }, Width = 338 },
    InputRect = { 46, 324, 1068, 226 },
    InputTextSize = 26,
    Placeholder = "Tell us what happened...",
    CounterRect = { 46, 573, 1068, 32 },
    CounterSize = 22,
    NoteRect = { 46, 650, 640, 36 },
    NoteSize = 22,
    Note = "Please do not include personal information.",
    SendRect = { 710, 640, 404, 56 },
    StatusSeconds = 3,
}

return FeedbackConfig
