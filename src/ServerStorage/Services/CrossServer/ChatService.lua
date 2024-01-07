local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- game services
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local ConfigurationService = Knit.GetService("ConfigurationService")

local ChatService = Knit.CreateService {
    Name = "ChatService",
    Client = {},
}

ChatService._ignorePrefixes = { ConfigurationService:GetVariable("DEFAULT_EMOTE_COMMAND") }
ChatService._playersChatData = {}

local MAXIMUM_TIME_ALLOWED_FOR_DEFAULT_MESSAGE: string = ConfigurationService:GetVariable("MAXIMUM_TIME_ALLOWED_FOR_DEFAULT_MESSAGE")
local MAXIMUM_TIME_ALLOWED_FOR_LONG_MESSAGE: string = ConfigurationService:GetVariable("MAXIMUM_TIME_ALLOWED_FOR_LONG_MESSAGE")
local MAXIMUM_TEXT_LENGTH_FOR_PRESISTENT: number = ConfigurationService:GetVariable("MAXIMUM_TEXT_LENGTH_FOR_PRESISTENT")
local MAXIMUM_TEXT_LENGTH_ALLOWANCE: number = ConfigurationService:GetVariable("MAXIMUM_TEXT_LENGTH_ALLOWANCE")
local DEFAULT_EMOTE_COMMAND: string = ConfigurationService:GetVariable("DEFAULT_EMOTE_COMMAND")

function ChatService:KnitStart()
    
end


function ChatService:KnitInit()
    self:SetUp()
end

-- methods

function ChatService:_playerAdded(player: Player)
	self:addCoreConnection(player.Chatted:Connect(function(message: string)
		local ignoreMessage: string = false
		
		for _, ignorePrefix: string in self._ignorePrefixes do
			if string.sub(string.lower(message), 1, #ignorePrefix) == string.lower(ignorePrefix) then
				ignoreMessage = true
				break
			end
		end
		
		if ignoreMessage then
			return
		end
		
		message = string.sub(message, 1, math.min(MAXIMUM_TEXT_LENGTH_ALLOWANCE, #message))
		
		local success, result = pcall(function()
			return TextService:FilterStringAsync(message, player.UserId)
		end)

		if success then
			message = result:GetNonChatStringForBroadcastAsync()
		else
			message = string.rep("#", math.min(#message, 24))
		end
		
		self._playersChatData[player] = message
		
		if message and #message >= MAXIMUM_TEXT_LENGTH_FOR_PRESISTENT then
			task.delay(MAXIMUM_TIME_ALLOWED_FOR_LONG_MESSAGE, function()
				if self._playersChatData[player] == message then
					self._playersChatData[player] = nil
				end
			end)
		elseif message then
			task.delay(MAXIMUM_TIME_ALLOWED_FOR_DEFAULT_MESSAGE, function()
				if self._playersChatData[player] == message then
					self._playersChatData[player] = nil
				end
			end)
		end
	end))
end

function ChatService:getPlayerChatData(player: Player)
	return player and self._playersChatData[player] or ""
end

function ChatService:SetUp()
	local networkEnabled: boolean = true
	self.serviceEnabled = networkEnabled

	if not networkEnabled then
		return
	end
	
	self:addCoreConnection(Players.PlayerAdded:Connect(function(player: Player)
		self:_playerAdded(player)
	end))
	
	for _, player: Player in Players:GetPlayers() do
		self:_playerAdded(player)
	end
end

return ChatService
