-- ReplicatedStorage.FeedbackMenu.FeedbackComponent  (ModuleScript, client)
-- Draws the Feedback window from the MenuArt art into a pixel-sized panel Frame: the window background (header,
-- Close X, text box, note strip, SEND button), BUG / IDEA / OTHER tab pieces, the text box, a character counter
-- and the note / status line. Sending goes through the onSend callback (FeedbackClient owns the remote).
--
--   local view = FeedbackComponent.new(panel, {
--       onClose = function() ... end,
--       onSend = function(kind, text) return ok, message end,   -- may yield
--   })
--   view:Reset()     -- clears the status line (on open)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudUI = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudUI"))
local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))
local Config = require(script.Parent:WaitForChild("FeedbackConfig"))

local Colors = MenuArt.Colors
local Layout = Config.Layout
local CENTER = Enum.TextXAlignment.Center
local RED = Color3.fromRGB(255, 96, 96)
local Z = 10 -- above the StudCanvas frame itself (StudTheme.ZIndex 8)

local FeedbackComponent = {}
FeedbackComponent.__index = FeedbackComponent

-- BUG / IDEA / OTHER: the selected tab orange, the others purple
function FeedbackComponent:_refreshTabs()
    for i, kind in Config.Kinds do
        local selected = self.kind == kind.Key
        self.tabs[i].on.Visible = selected
        self.tabs[i].off.Visible = not selected
    end
end

-- Shows a send result in place of the note for a few seconds
function FeedbackComponent:_status(message, color)
    self.statusId += 1
    local statusId = self.statusId
    self.note.Text = message
    self.note.TextColor3 = color
    task.delay(Layout.StatusSeconds, function()
        if self.statusId == statusId then
            self:Reset()
        end
    end)
end

function FeedbackComponent:Reset()
    self.statusId += 1
    self.note.Text = Layout.Note
    self.note.TextColor3 = Colors.Muted
end

function FeedbackComponent.new(panel, callbacks)
    local self =
        setmetatable({ kind = Config.Kinds[1].Key, statusId = 0, sending = false, tabs = {} }, FeedbackComponent)
    local canvas = StudUI.newCanvas(panel, panel)
    self.canvas = canvas
    MenuArt.background(canvas, "Feedback", nil, Z)
    MenuArt.hitBox(canvas, "Close", Layout.CloseRect, callbacks.onClose, Z + 4)
    MenuArt.label(canvas, "Intro", Layout.Intro, Layout.IntroRect, Layout.IntroSize, Colors.White, Z + 1)
    MenuArt.label(canvas, "Prompt", Layout.Prompt, Layout.PromptRect, Layout.PromptSize, Colors.Muted, Z + 1, {
        stroke = 2,
    })

    for i, kind in Config.Kinds do
        local r = Layout.TabRects[i]
        self.tabs[i] = {
            on = MenuArt.piece(canvas, "KindOn_" .. kind.Key, "FbTabOn", r, Z + 1),
            off = MenuArt.piece(canvas, "KindOff_" .. kind.Key, "FbTabOff", r, Z + 1),
        }
        MenuArt.label(
            canvas,
            "KindText_" .. kind.Key,
            kind.Label,
            { r[1] + 10, r[2] + 8, r[3] - 20, r[4] - 18 },
            Layout.TabTextSize,
            Colors.White,
            Z + 2,
            {
                alignX = CENTER,
            }
        )
        MenuArt.hitBox(canvas, "Kind_" .. kind.Key, r, function()
            self.kind = kind.Key
            self:_refreshTabs()
        end, Z + 3)
    end
    self:_refreshTabs()

    local inputRect, inset = Layout.InputRect, Layout.InputInset
    local box = MenuArt.new("TextBox", "Message", canvas, Z + 2)
    MenuArt.rect(
        box,
        { inputRect[1] + inset, inputRect[2] + inset - 4, inputRect[3] - inset * 2, inputRect[4] - inset * 2 + 4 }
    )
    box.FontFace = MenuArt.Font
    box.TextSize = Layout.InputTextSize
    box.TextColor3 = Colors.White
    box.PlaceholderText = Layout.Placeholder
    box.PlaceholderColor3 = Colors.Muted
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.TextWrapped = true
    box.MultiLine = true
    box.ClearTextOnFocus = false
    box.Text = ""
    local counter = MenuArt.label(canvas, "Counter", "", Layout.CounterRect, Layout.CounterSize, Colors.Muted, Z + 1, {
        stroke = 2,
    })
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if #box.Text > Config.MaxLength then
            box.Text = string.sub(box.Text, 1, Config.MaxLength)
            return
        end
        counter.Text = #box.Text .. " / " .. Config.MaxLength .. " characters"
    end)
    counter.Text = "0 / " .. Config.MaxLength .. " characters"
    self.note = MenuArt.label(canvas, "Note", Layout.Note, Layout.NoteRect, Layout.NoteSize, Colors.Muted, Z + 1, {
        stroke = 2,
    })

    local s = Layout.SendRect
    local sendLabel = MenuArt.label(
        canvas,
        "SendText",
        "SEND",
        { s[1] + 10, s[2] + 6, s[3] - 20, s[4] - 14 },
        Layout.SendSize,
        Colors.White,
        Z + 2,
        {
            alignX = CENTER,
        }
    )
    MenuArt.hitBox(canvas, "Send", s, function()
        if self.sending then
            return
        end
        self.sending = true
        sendLabel.Text = "..."
        local ok, message = callbacks.onSend(self.kind, box.Text)
        self.sending = false
        sendLabel.Text = "SEND"
        if ok then
            box.Text = ""
        end
        self:_status(message or (ok and "Thanks!" or "Couldn't send. Try again."), ok and Colors.Green or RED)
    end, Z + 3)
    return self
end

return FeedbackComponent
