local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

local GET_USER_DATA_ACTION : string = ConfigurationService:GetVariable("GET_USER_DATA_ACTION")
local REMOVE_USER_DATA_ACTION : string = ConfigurationService:GetVariable("REMOVE_USER_DATA_ACTION")
local DELETE_USER_DATA_ACTION : string = ConfigurationService:GetVariable("DELETE_USER_DATA_ACTION")
local REQUEST_USER_DATA_ACTION : string = ConfigurationService:GetVariable("REQUEST_USER_DATA_ACTION")

local DEFAULT_PLAYERS_COLLISION_GROUP_NAME: string = ConfigurationService:GetVariable("DEFAULT_PLAYERS_COLLISION_GROUP_NAME")
local DEFAULT_DATA_WAIT_YIELD_TIME: number = ConfigurationService:GetVariable("DEFAULT_DATA_WAIT_YIELD_TIME")
local RESET_DATA_COMMAND: string = ConfigurationService:GetVariable("RESET_DATA_COMMAND")

local GamePlayerService = Knit.CreateService {
    Name = "GamePlayerService",
    playerData = {},
	_defaultdataschema = {},
	Client = {
		playerDataUpdated = Signal.new(),
		playerDataLoaded = Signal.new(),
	},
    onPlayerDataUpdated = Signal.new(),
    onPlayerDataLoaded = Signal.new(),
}

function GamePlayerService:_playerAdded(player: Player)
	local playerKey: string = tostring(player.UserId)
	if
		self.playerData[playerKey]
		and self.playerData[playerKey]["data"]
	then
		local foundPlayerData: any = self.playerData[playerKey].data
		self.Client.playerDataLoaded:Fire({player}, foundPlayerData)
		self.onPlayerDataLoaded:Fire(player, foundPlayerData)
		return
	end
	
	self.playerData[playerKey] = nil
	
	datastoreService:addDatastoreRequest(GET_USER_DATA_ACTION, 10, {
		playerId = playerKey,
		callback = function()
			if not player or not player.Parent then
				return
			end
			
			local playerData: any = self.playerData[playerKey].data
			self.Client.playerDataLoaded:Fire({player}, playerData)
			self.onPlayerDataLoaded:Fire(player, playerData)
		end,
	})
end

function GamePlayerService:_playerRemoved(player: Player, playerCallback: RBXScriptSignal)
	local playerId: string = tostring(player.UserId)
	for userId: string in self.playerData do
		local foundPlayerInGame: Player = Players:GetPlayerByUserId(tonumber(userId))
		if not foundPlayerInGame or playerId and playerId == userId then
			datastoreService:addDatastoreRequest(REMOVE_USER_DATA_ACTION, playerCallback and 1000000 or 100, {
				playerId = userId,
				callback = function()
					print("[PlayersService] Saved PlayerData :", userId)
					if self.playerData[userId] then
						self.playerData[userId] = nil
					end
					if playerCallback then
						playerCallback()
					end
				end,
			})
		end
	end
end

function GamePlayerService:updateDataSchema(writeDataSchema)
	self:updateMissingData(self._defaultdataschema, writeDataSchema)
	for _, actualPlayerData : any in self.playerData do
		self:updateMissingData(actualPlayerData.data, self._defaultdataschema)
	end
end

function GamePlayerService:getPlayerDataByUserId(userId: number)
	if not tonumber(userId) then
		return
	end
	
	local requestedUserData: any
	datastoreService:addDatastoreRequest(REQUEST_USER_DATA_ACTION, 1, {
		userId = userId,
		callback = function(userData: any)
			requestedUserData = userData
		end,
	})
	
	repeat
		task.wait()
	until requestedUserData
	
	return requestedUserData
end

function GamePlayerService:getPlayerData(player: Player)
	local startTime: number = tick()
	local playerKey: string = tostring(player.UserId)
	
	local foundData: any = self.playerData[playerKey] and self.playerData[playerKey].data
	if not foundData then
		repeat
			task.wait()
			foundData = self.playerData[playerKey] and self.playerData[playerKey].data
		until foundData or tick() - startTime >= DEFAULT_DATA_WAIT_YIELD_TIME
	end
	
	return foundData
end

function GamePlayerService:updatePlayerData(player: Player, updateFunction: RBXScriptSignal)
	local newPlayerData: any = updateFunction(self:getPlayerData(player))
	if not newPlayerData then
		return warn("[PlayersService] Unable to update Player Data properly as updateFunction should return PlayerData!")
	end
	
	local playerKey: string = tostring(player.UserId)
	self.playerData[playerKey].data = newPlayerData
	self.Client.playerDataUpdated:Fire({player}, newPlayerData)
	self.onPlayerDataUpdated:Fire(player, newPlayerData)
	
	return newPlayerData
end

function GamePlayerService.Client:getPlayerData(player: Player)
	return self:getPlayerData(player)
end

function GamePlayerService:SetUp()
	local centralSystem : any = masterSystem:GetSystem("CentralSystem", "Core")
	
	local centralPlayersService: any = centralSystem:GetService("PlayersService")
	collisionGroupsService = centralSystem:GetManager("CollisionGroupsService")
	datastoreService = centralSystem:GetManager("DatastoreService")

	collisionGroupsService:addCollisionGroup(DEFAULT_PLAYERS_COLLISION_GROUP_NAME)

	local characterAddedSignal : any = masterSystem:GetSignal("CharacterAdded")
	characterAddedSignal:AddServerCallback(function(_, character: Model)
		task.wait(0.5)
		collisionGroupsService:setInstanceToCollisionGroup(character, DEFAULT_PLAYERS_COLLISION_GROUP_NAME)
	end)
	
	for _, character: Model in centralPlayersService:getAllCharacters() do
		collisionGroupsService:setInstanceToCollisionGroup(character, DEFAULT_PLAYERS_COLLISION_GROUP_NAME)
	end
	
	-- create DataStore Actions
	self:registerDatastoreActions(datastoreService)
	
	self:addCoreConnection(Players.PlayerRemoving:Connect(function(player : Player)
		self:_playerRemoved(player)
	end))
	
	self:addCoreConnection(Players.PlayerAdded:Connect(function(player : Player)
		self:_playerAdded(player)
	end))
	
	for _, player: Player in Players:GetPlayers() do
		self:_playerAdded(player)
	end
	
	game:BindToClose(function()
		local number = 0
		local totalNumber = #Players:GetPlayers()

		for _, player: Player in Players:GetPlayers() do
			self:_playerRemoved(player, function()
				number += 1
			end)
		end

		repeat
			task.wait()
		until totalNumber == number
	end)
end


function GamePlayerService:KnitStart()
    
end


function GamePlayerService:KnitInit()
    -- somehow integrade 	masterSystem:CreateManagerSaveDataKey(self, "playerData")??
    self:SetUp()
end


return GamePlayerService
