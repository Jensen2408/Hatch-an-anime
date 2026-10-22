--[[ ServerScriptService.FeedbackService (Script)
Player feedback -> private Discord #feedback (via webhook relay, because Discord blocks Roblox servers).
Paste the Discord webhook link into ServerStorage.FeedbackConfig attribute "WebhookUrl" (never in a script / chat).
Needs Game Settings > Security > Allow HTTP Requests = ON.

Remote: ReplicatedStorage.SendFeedback (RemoteFunction, client: FeedbackClient). Created here if the place lacks it,
and ServerStorage.FeedbackConfig is optional, so the handler is always bound (the client never hangs on "...").
  InvokeServer(kind: "Bug" | "Idea" | "Other", text: string) -> ok: boolean, message: string (shown to the player)

Network authority: everything the client sends is untrusted. The server
  - type-checks kind / text and only accepts the three known kinds,
  - trims whitespace and truncates to 500 characters (the client limit is cosmetic), requires >= 5 characters,
  - rate-limits per player: one successful send per COOLDOWN_SECONDS (os.clock; cleared on PlayerRemoving and
    when the HTTP post fails, so a failed send can be retried at once),
  - filters the text with TextService (PublicChat context) before it leaves Roblox; a filter error rejects the send,
  - disables Discord mentions (allowed_mentions.parse = {}), so feedback text cannot ping anyone.
  There is no per-server cap (_perServer is an unused leftover).
Delivery: the relay URL first, then the plain Discord URL; every failure is warned with the HTTP error so the cause
(HTTP off, webhook deleted, relay down) shows in the server log.
]]

-- ===== 1. Services, config, constants =====
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local feedbackConfig = game.ServerStorage:FindFirstChild("FeedbackConfig")
local sendFeedbackRemote = game.ReplicatedStorage:FindFirstChild("SendFeedback")
if not sendFeedbackRemote then
    sendFeedbackRemote = Instance.new("RemoteFunction")
    sendFeedbackRemote.Name = "SendFeedback"
    sendFeedbackRemote.Parent = game.ReplicatedStorage
end
local KIND_EMBED_COLORS = { Bug = 15548997, Idea = 5793266, Other = 10070709 }
local lastSentAt, _perServer = {}, {}
local COOLDOWN_SECONDS = 60

-- ===== 2. Helpers =====
local function toRelayUrl(webhookUrl)
    -- discord.com/api/webhooks/ID/TOKEN -> webhook.lewisakura.moe/api/webhooks/ID/TOKEN
    return (
        webhookUrl
            :gsub("^https://discord%.com", "https://webhook.lewisakura.moe")
            :gsub("^https://discordapp%.com", "https://webhook.lewisakura.moe")
    )
end
local function getWebhookUrl()
    local webhookUrl = feedbackConfig and feedbackConfig:GetAttribute("WebhookUrl")
    if type(webhookUrl) == "string" then
        webhookUrl = webhookUrl:gsub("^%s+", ""):gsub("%s+$", "")
        if webhookUrl:find("/api/webhooks/") then
            return webhookUrl
        end
    end
    return nil
end
-- posts to the relay, then straight to Discord; returns ok, lastError
local function postToDiscord(webhookUrl, body)
    local lastError
    for _, url in { toRelayUrl(webhookUrl), webhookUrl } do
        local ok, err = pcall(HttpService.PostAsync, HttpService, url, body, Enum.HttpContentType.ApplicationJson)
        if ok then
            return true
        end
        lastError = err
        warn("[Feedback] post failed (" .. (url:match("^https?://([^/]+)") or "?") .. "):", err)
    end
    return false, lastError
end
if not getWebhookUrl() then
    warn("[Feedback] ServerStorage.FeedbackConfig attribute WebhookUrl is missing or empty: feedback can't be sent.")
end

-- ===== 3. Remote handler =====
sendFeedbackRemote.OnServerInvoke = function(player, kind, text)
    if type(text) ~= "string" or type(kind) ~= "string" or not KIND_EMBED_COLORS[kind] then
        return false, "Something went wrong."
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 500)
    if #text < 5 then
        return false, "Write a bit more first."
    end
    if os.clock() - (lastSentAt[player] or -1e9) < COOLDOWN_SECONDS then
        return false, "Thanks! You can send more in a minute."
    end
    local webhookUrl = getWebhookUrl()
    if not webhookUrl then
        return false, "Feedback isn't set up yet."
    end
    local filterOk, filteredText = pcall(function()
        return TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
            :GetNonChatStringForBroadcastAsync()
    end)
    if not filterOk then
        warn("[Feedback] text filter failed:", filteredText)
        return false, "Couldn't send. Try again."
    end
    -- the cooldown starts only once the text passed the filter (set before the yielding HTTP post)
    lastSentAt[player] = os.clock()
    local body = HttpService:JSONEncode({
        username = "Hatch an Anime Feedback",
        allowed_mentions = { parse = {} },
        embeds = {
            {
                title = kind == "Bug" and "🐞 Bug report" or kind == "Idea" and "💡 Idea" or "💬 Feedback",
                description = filteredText,
                color = KIND_EMBED_COLORS[kind],
                fields = {
                    {
                        name = "Player",
                        value = ("%s (@%s) · %d"):format(player.DisplayName, player.Name, player.UserId),
                        inline = true,
                    },
                    {
                        name = "Server",
                        value = (game.JobId ~= "" and game.JobId:sub(1, 8) or "Studio")
                            .. " · "
                            .. #Players:GetPlayers()
                            .. " players",
                        inline = true,
                    },
                },
                timestamp = DateTime.now():ToIsoDate(),
            },
        },
    })
    local sent, err = postToDiscord(webhookUrl, body)
    if not sent then
        warn("[Feedback] send failed:", err)
        lastSentAt[player] = nil
        return false, "Couldn't send. Try again later."
    end
    return true, "Sent! Thanks for helping us 💙"
end
Players.PlayerRemoving:Connect(function(player)
    lastSentAt[player] = nil
end)
