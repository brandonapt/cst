local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Players = game:GetService("Players")

local PlayerService = Knit.CreateService {
    Name = "PlayerService",
    Client = {
        CharacterDied = Signal.new(),
        CharacterAdded = Signal.new(),
        CharacterRemoved = Signal.new(),
    },
    charactersList = {},
	playerList = {},
	_signals = {},
}


function PlayerService:KnitStart()
    
end


function PlayerService:KnitInit()
    self:SetUp()
end

function PlayerService:_characterAdded(player: Player, character: Model)
	self.charactersList[player] = character
	
	local foundHumanoid: Humanoid = character:WaitForChild("Humanoid", 5)
	if foundHumanoid then
		table.insert(self.playerList[player], foundHumanoid.Died:Connect(function()
            self.Client.CharacterDied:Fire(player)
		end))
	end
	
	table.insert(self.playerList[player], character.Destroying:Connect(function()
		self.Client.CharacterRemoved:Fire(player)
	end))
	
	table.insert(self.playerList[player], character.AncestryChanged:Connect(function(_, parent: Instance)
		if parent then
			return
		end
		self.Client.CharacterRemoved:Fire(player)
	end))
	
    self.Client.CharacterAdded:Fire(player)
end

function PlayerService:_playerAdded(player: Player)
	self.playerList[player] = {}
	table.insert(self.playerList[player], player.CharacterAdded:Connect(function(character: Model)
		self:_characterAdded(player, character)
	end))
	
	if player.Character then
		self:_characterAdded(player, player.Character)
	end
end

function PlayerService:_playerRemoved(player: Player)
	if self.playerList[player] then
		for _, rbxConnection: RBXScriptConnection in self.playerList[player] do
			pcall(function()
				rbxConnection:Disconnect()
			end)
		end
	end
	
	self.charactersList[player] = nil
	self.playerList[player] = nil
end

function PlayerService:getAllCharacters()
	return self.charactersList
end

function PlayerService.Client:getAllCharacters()
	return self.charactersList
end

function PlayerService:SetUp()
	self._signals.CharacterRemoved = masterSystem:GetSignal("CharacterRemoved")
	self._signals.CharacterAdded = masterSystem:GetSignal("CharacterAdded")
	self._signals.CharacterDied = masterSystem:GetSignal("CharacterDied")
	
	self:addCoreConnection(Players.PlayerRemoving:Connect(function(player: Player)
		self:_playerRemoved(player)
	end))
	
	self:addCoreConnection(Players.ChildRemoved:Connect(function()
		task.delay(0.2, function()
			for player: Player in self.playerList do
				if not player.Parent then
					self:_playerRemoved(player)
				end
			end
		end)
	end))
	
	self:addCoreConnection(Players.PlayerAdded:Connect(function(player: Player)
		self:_playerAdded(player)
	end))
	
	for _, player: Player in Players:GetPlayers() do
		self:_playerAdded(player)
	end
end

return PlayerService
