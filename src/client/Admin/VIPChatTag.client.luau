--[[ StarterPlayerScripts.VIPChatTag  (LocalScript)
Gold [VIP] prefix in chat for players with the VIP attribute (set by ShopService).
Note: it assigns TextChatService.OnIncomingMessage, so any other script assigning that callback replaces this one.
]]
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
TextChatService.OnIncomingMessage = function(message)
    local properties = Instance.new("TextChatMessageProperties")
    local textSource = message.TextSource
    local sender = textSource and Players:GetPlayerByUserId(textSource.UserId)
    if sender and sender:GetAttribute("VIP") then
        properties.PrefixText = '<font color="#F2BE55">[VIP]</font> <font color="#FFD978">'
            .. message.PrefixText
            .. "</font>"
    end
    return properties
end
