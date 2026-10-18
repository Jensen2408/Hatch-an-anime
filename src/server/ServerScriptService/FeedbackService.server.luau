-- Player feedback -> private Discord #feedback (via webhook relay, because Discord blocks Roblox servers).
-- Paste the Discord webhook link into ServerStorage.FeedbackConfig attribute "WebhookUrl" (never in a script / chat).
-- Needs Game Settings > Security > Allow HTTP Requests = ON.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local TextService=game:GetService("TextService")
local cfg=game.ServerStorage:WaitForChild("FeedbackConfig")
local remote=game.ReplicatedStorage:WaitForChild("SendFeedback")
local KINDS={Bug=15548997,Idea=5793266,Other=10070709}
local last,perServer={},{}
local COOLDOWN=60
local function relay(url)
	-- discord.com/api/webhooks/ID/TOKEN -> webhook.lewisakura.moe/api/webhooks/ID/TOKEN
	return (url:gsub("^https://discord%.com","https://webhook.lewisakura.moe"):gsub("^https://discordapp%.com","https://webhook.lewisakura.moe"))
end
remote.OnServerInvoke=function(p,kind,text)
	if type(text)~="string" or type(kind)~="string" or not KINDS[kind] then return false,"Something went wrong." end
	text=text:gsub("^%s+",""):gsub("%s+$",""):sub(1,500)
	if #text<5 then return false,"Write a bit more first." end
	if os.clock()-(last[p] or -1e9)<COOLDOWN then return false,"Thanks! You can send more in a minute." end
	local url=cfg:GetAttribute("WebhookUrl")
	if type(url)~="string" or not url:find("/api/webhooks/") then return false,"Feedback isn't set up yet." end
	local ok,filtered=pcall(function() return TextService:FilterStringAsync(text,p.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync() end)
	if not ok then return false,"Couldn't send. Try again." end
	last[p]=os.clock()
	local body=Http:JSONEncode({username="Hatch an Anime Feedback",allowed_mentions={parse={}},embeds={{
		title=kind=="Bug" and "🐞 Bug report" or kind=="Idea" and "💡 Idea" or "💬 Feedback",
		description=filtered,color=KINDS[kind],
		fields={{name="Player",value=("%s (@%s) · %d"):format(p.DisplayName,p.Name,p.UserId),inline=true},
			{name="Server",value=(game.JobId~="" and game.JobId:sub(1,8) or "Studio").." · "..#Players:GetPlayers().." players",inline=true}},
		timestamp=DateTime.now():ToIsoDate()}}})
	local sent,err=pcall(function() Http:PostAsync(relay(url),body,Enum.HttpContentType.ApplicationJson) end)
	if not sent then warn("[Feedback] send failed:",err) last[p]=nil return false,"Couldn't send. Try again later." end
	return true,"Sent! Thanks for helping us 💙"
end
Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
