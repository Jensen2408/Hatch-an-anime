-- ReplicatedStorage.FeedbackMenu.FeedbackComponent  (ModuleScript, client)
-- Draws the Feedback window (Figma "05 Feedback") into a pixel-sized panel Frame with the StudKit pieces:
-- header with Close, BUG / IDEA / OTHER tabs, text box with a character counter, SEND and a note / status line.
-- Sending goes through the onSend callback (FeedbackClient owns the remote).
--
--   local view = FeedbackComponent.new(panel, {
--       onClose = function() ... end,
--       onSend = function(kind, text) return ok, message end,   -- may yield
--   })
--   view:Reset()     -- clears the status line (on open)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = ReplicatedStorage:WaitForChild("StudKit")
local StudUI = require(Kit:WaitForChild("StudUI"))
local Theme = require(Kit:WaitForChild("StudTheme"))
local Config = require(script.Parent:WaitForChild("FeedbackConfig"))

local Colors = Theme.Colors
local Layout = Config.Layout
local label = StudUI.label

local FeedbackComponent = {}
FeedbackComponent.__index = FeedbackComponent

-- BUG / IDEA / OTHER (Tab/Selected + Tab/Default); rebuilt on every pick
function FeedbackComponent:_buildTabs()
    if self.tabRow then
        self.tabRow:Destroy()
    end
    local row = Instance.new("Frame")
    row.Name = "Kinds"
    row.BackgroundTransparency = 1
    row.Size = UDim2.fromScale(1, 1)
    row.ZIndex = self.z - 1
    row:SetAttribute("NoSkin", true)
    row.Parent = self.canvas
    self.tabRow = row
    local tabs = Layout.Tabs
    for i, kind in Config.Kinds do
        StudUI.tab(
            row,
            "Kind_" .. kind.Key,
            { tabs.Xs[i], tabs.Y, tabs.Width, tabs.Height },
            kind.Label,
            self.kind == kind.Key,
            function()
                self.kind = kind.Key
                self:_buildTabs()
            end,
            self.z
        )
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
    local self = setmetatable({ kind = Config.Kinds[1].Key, statusId = 0, sending = false }, FeedbackComponent)
    self.canvas = StudUI.newCanvas(panel, panel)
    local z = StudUI.shell(self.canvas, Colors.Blue, Config.Title, callbacks.onClose)
    self.z = z
    label(self.canvas, "Intro", Layout.Intro, Layout.IntroRect, Layout.IntroSize, Colors.White, {
        display = true,
        zIndex = z,
    })
    label(self.canvas, "Prompt", Layout.Prompt, Layout.PromptRect, Layout.PromptSize, Colors.Muted, { zIndex = z })
    self:_buildTabs()

    local box = StudUI.input(self.canvas, "Message", Layout.InputRect, {
        placeholder = Layout.Placeholder,
        textSize = Layout.InputTextSize,
        multiLine = true,
        maxLength = Config.MaxLength,
        zIndex = z,
    })
    local counter = label(self.canvas, "Counter", "", Layout.CounterRect, Layout.CounterSize, Colors.Muted, {
        zIndex = z,
    })
    local function updateCounter()
        counter.Text = #box.Text .. " / " .. Config.MaxLength .. " characters"
    end
    box:GetPropertyChangedSignal("Text"):Connect(updateCounter)
    updateCounter()
    self.note = label(self.canvas, "Note", Layout.Note, Layout.NoteRect, Layout.NoteSize, Colors.Muted, { zIndex = z })

    local _, sendLabel
    _, sendLabel = StudUI.button(self.canvas, "Send", Layout.SendRect, Colors.Green, "SEND", {
        zIndex = z,
        onActivate = function()
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
            self:_status(
                message or (ok and "Thanks!" or "Couldn't send. Try again."),
                ok and Colors.Green or Colors.Red
            )
        end,
    })
    return self
end

return FeedbackComponent
