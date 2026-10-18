-- Gold [VIP] prefix in chat for players with the VIP attribute (set by ShopService)
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local src = message.TextSource
	local p = src and Players:GetPlayerByUserId(src.UserId)
	if p and p:GetAttribute("VIP") then
		props.PrefixText = '<font color="#F2BE55">[VIP]</font> <font color="#FFD978">' .. message.PrefixText .. '</font>'
	end
	return props
end
