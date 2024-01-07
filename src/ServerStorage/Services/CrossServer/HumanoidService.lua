local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(Knit.Util.Signal)

local HumanoidService = Knit.CreateService {
    Name = "HumanoidService",
    Client = {
        onPlayerAnimationBlacklistUpdate = Signal.new(),
        onPlayerAnimationDataUpdate = Signal.new(),
    },
}

local ConfigurationService = Knit.GetService("ConfigurationService")

local DEFAULT_WAIT_FOR_CHILD_TIME: number = ConfigurationService:GetVariable("DEFAULT_WAIT_FOR_CHILD_TIME")

HumanoidService._playerHumanoidJumpData = {}
HumanoidService._playersAnimationData = {}
HumanoidService._playersCharacterConnections = {}

function HumanoidService:KnitStart()
    
end


function HumanoidService:KnitInit()
    self:SetUp()
end

function HumanoidService:_characterAdded(player: Player, character: Model)
	local foundPlayerConnections: any = self._playersCharacterConnections[player]
	if foundPlayerConnections then
		for _, rbxConnection: RBXScriptConnection in foundPlayerConnections do
			rbxConnection:Disconnect()
			rbxConnection = nil
		end
		self._playersCharacterConnections[player] = {}
	end
	
	if not self._playersCharacterConnections[player] then
		self._playersCharacterConnections[player] = {}
	end
	
	local humanoid: Humanoid = character:WaitForChild("Humanoid", DEFAULT_WAIT_FOR_CHILD_TIME)
	if not humanoid then
		return
	end
	
	local humanoidJumping: boolean, lastJump: number = false, 0
	table.insert(self._playersCharacterConnections[player], humanoid.Changed:Connect(function()
		if humanoid.Jump ~= humanoidJumping then
			humanoidJumping = humanoid.Jump
			
			if humanoidJumping and tick() - lastJump >= 0.1 then
				if not self._playerHumanoidJumpData[player] then
					self._playerHumanoidJumpData[player] = 0
				end
				
				lastJump = tick()
				self._playerHumanoidJumpData[player] += 1
			end
		end
	end))
end

function HumanoidService:getPlayerAnimationData(player: Player)
	return self._playersAnimationData[player] or ""
end

function HumanoidService:updatePlayerAnimationBlacklist(player: Player, blacklistTag: string, blacklist: table)
	if blacklist then
		for index: number, animationId: string in blacklist do
			blacklist[index] = string.match(animationId, "%d+")
		end
	end
	self.Client.onPlayerAnimationBlacklistUpdate:Fire(player, blacklistTag, blacklist)
end

function HumanoidService:getPlayerJumpData(player: Player)
	local returnAmount: number = self._playerHumanoidJumpData[player] or 0
	return returnAmount
end

function HumanoidService:resetPlayerJumpData(player: Player)
	if not self._playerHumanoidJumpData[player] then
		return
	end
	self._playerHumanoidJumpData[player] = 0
end

function HumanoidService:SetUp()
	local networkEnabled: boolean = true
	self.serviceEnabled = networkEnabled

	if not networkEnabled then
		return
	end
	
	self.Client.onPlayerAnimationDataUpdate:Connect(function(player: Player, playerAnimationData: any)
		if typeof(playerAnimationData) ~= "string" or #playerAnimationData > 30 then
			return warn("Unable to process Animations Data :", playerAnimationData)
		end
		self._playersAnimationData[player] = playerAnimationData
	end)
	
	local centralSystem : any = masterSystem:GetSystem("CentralSystem", "Core")
	local centralPlayersService: any = centralSystem:GetService("PlayersService")

	local characterAddedSignal : any = masterSystem:GetSignal("CharacterAdded")
	characterAddedSignal:AddServerCallback(function(player: Player, character: Model)
		self:_characterAdded(player, character)
	end)

	for player: Player, character: Model in centralPlayersService:getAllCharacters() do
		self:_characterAdded(player, character)
	end
end


function HumanoidService:ShutDown()
	for _, connections: any in self._playersCharacterConnections do
		for _, rbxConnection: RBXScriptConnection in connections do
			rbxConnection:Disconnect()
			rbxConnection = nil
		end
	end
end

return HumanoidService
