local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

local CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED: boolean = ConfigurationService:GetVariable("CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED")
local NON_PLAYER_CHARACTER_DATA_INDEX: string = ConfigurationService:GetVariable("NON_PLAYER_CHARACTER_DATA_INDEX")
local CROSS_SERVER_UPLOAD_KEY: string = ConfigurationService:GetVariable("CROSS_SERVER_UPLOAD_KEY")

local metaverseZoneSize: number

local ReplicationService = Knit.CreateService {
    Name = "ReplicationService",
    Client = {
        crossServerMapDataUpdated = Signal.new(),
    },
}

ReplicationService._playerSettings = {}
ReplicationService._currentPlayersZones = {} --> {[UserId] = true, ...} --> for quick identification below v
ReplicationService._crossServerZonesMapData = {}


function ReplicationService:KnitStart()
    
end


function ReplicationService:KnitInit()
    self:SetUp()
end

local function getNumberRange(givenNumber: number, nowNumber: number, maxNumber: number)
	maxNumber = tonumber(maxNumber) and maxNumber or 60
	
	return math.min(
		math.abs(givenNumber - nowNumber),
		math.abs(givenNumber - (maxNumber + nowNumber))
	)
end

local function verifyIfTimeNumberIsInRange(givenNumber: number, nowNumber: number, range: number, maxNumber: number)
	maxNumber = tonumber(maxNumber) and maxNumber or 60
	range = tonumber(range) and range or 5


	local high: number, low: number = nowNumber + range, nowNumber - range
	local isInRange: boolean = false
	if nowNumber < range or nowNumber + range > maxNumber then
		isInRange = givenNumber >= (maxNumber + low) or givenNumber <= high
	else
		isInRange = givenNumber >= low and givenNumber <= high
	end

	return isInRange
end

function ReplicationService:_playerAdded(player: Player)
	local userId: string = tostring(player.UserId)
	self._currentPlayersZones[userId] = {}
	self._playerSettings[player] = {
		setting = "Medium",
		charactersMaxAmount = 64,
		charactersRenderDistance = 512,
	}
end

function ReplicationService:_playerRemoved(player: Player)
	local userId: string = tostring(player.UserId)
	if self._currentPlayersZones[userId] then
		self._currentPlayersZones[userId] = nil
	end
	
	for checkUserId: string in self._currentPlayersZones do
		if Players:GetPlayerByUserId(tonumber(checkUserId)) then
			continue
		end
		self._currentPlayersZones[checkUserId] = nil
	end
end

function ReplicationService:_getPlayerSettings(player: Player)
	return self._playerSettings[player]
end

function ReplicationService:_getAllCharactersByRadius(metaversePosition: Vector3, searchRadius: Vector3, searchParameter: any)
	--> ?? For getting all characters in Position instead?
	local enquiryZones: any = zones_Coordinator.getBoundingZones(
		metaversePosition,
		Vector3.new(
			searchRadius,
			searchRadius,
			searchRadius
		),
		true,
		metaverseZoneSize
	)
	
	local characters: any = {}
	for _, zoneIndex: string in enquiryZones do
		local allMapsDataInZone: any = self._crossServerZonesMapData[zoneIndex]
		if not allMapsDataInZone then
			continue
		end
		
		for mapIndex: string, mapData: any in allMapsDataInZone do
			if not mapData[1] then
				continue
			end
			
			local letterStart: number? = string.find(zoneIndex, "|")
			local zoneCoordinate: string = letterStart and string.sub(zoneIndex, letterStart + 1) or zoneIndex
			local mapZoneCoordinate: Vector3 = zones_Coordinator.getVector3FromCoordinate(zoneCoordinate)
			local mapMetaversePosition: Vector3 = mapZoneCoordinate * metaverseZoneSize
			local relevantPositionToMap: Vector3 = metaversePosition - mapMetaversePosition
			for characterKey: string, characterData: any in mapData[1] do
				local characterRelativeCFrame: CFrame = zones_Coordinator.translateMetaverseCFrame(characterData[1])
				local characterDistanceFromCheckPosition: number = (characterRelativeCFrame.Position - relevantPositionToMap).Magnitude
				if
					characterDistanceFromCheckPosition > searchRadius
					or characters[characterKey]
				then
					continue
				end
				
				characters[characterKey] = {
					characterKey = characterKey,
					zoneIndex = zoneIndex,
					mapIndex = mapIndex,
					characterData = {
						-- worldCFrame = actual CFrame in Metaverse
						metaverseCFrame = mapMetaversePosition,
						mountId = characterData[3],
						message = characterData[4],
						humanoid = zones_Coordinator.translateMetaverseHumanoidStats(characterData[5]),
						animation = characterData[6],
						seat = characterData[7],
						metaData = characterData[8] or {},
					},
					relativeDistance = characterDistanceFromCheckPosition,
				}
			end
		end
	end
	
	return characters
end

function ReplicationService:_sortPlayerClientDisplayData(player: Player, searchZoneIndex: string)
	local playerMetaversePosition: Vector3 = zones_Coordinator.getPlayerMetaversePosition(player)
	local playerMetaverseZonePosition: Vector3 = zones_Coordinator.getPlayerMetaverseZonePosition(player)
	if not playerMetaversePosition then
		return
	end
	
	local playerUserKey: string = tostring(player.UserId)
	local playerZonesRegistery: any = self._currentPlayersZones[playerUserKey]
	if not playerZonesRegistery then
		self._currentPlayersZones[playerUserKey] = {}
	end
	
	local currentSecondTimeStamp: number = DateTime.now():ToUniversalTime().Second
	local currentMinteTimeStamp: number = DateTime.now():ToUniversalTime().Minute
	self._currentPlayersZones[playerUserKey][searchZoneIndex] = currentMinteTimeStamp
	
	for zoneIndex: string, minuteTimeStamp: number in self._currentPlayersZones[playerUserKey] do
		if verifyIfTimeNumberIsInRange(minuteTimeStamp, currentMinteTimeStamp, 1) then
			continue
		end
		self._currentPlayersZones[playerUserKey][zoneIndex] = nil
	end
	
	local allRelevantCharacters: any = {}
	local allReleveantCharactersRegistery: any = {}
	local allRelevantMapsData: any = {}
	for getZoneIndex: string in self._currentPlayersZones[playerUserKey] do
		local allMapsDataInZone: any = self._crossServerZonesMapData[getZoneIndex]
		if not allMapsDataInZone then
			continue
		end
		
		local getZoneCoordinate: Vector3 = zones_Coordinator.getVector3FromCoordinate(getZoneIndex)
		for mapIndex: string, mapData: any in allMapsDataInZone do
			allRelevantMapsData[mapIndex] = {
				data = mapData,
				mapIndex = mapIndex,
				zoneIndex = getZoneIndex,
				metaversePosition = getZoneCoordinate * metaverseZoneSize,
			}
		end
	end
	
	local playerSettings: any = self:_getPlayerSettings(player)
	local renderMaxDistance: number = playerSettings.charactersRenderDistance
	local renderMaxAmount: number = playerSettings.charactersMaxAmount
	
	for _, mapRelevantData: any in allRelevantMapsData do
		local relevantPositionToMap: Vector3 = playerMetaversePosition - mapRelevantData.metaversePosition
		local mapData: any = mapRelevantData.data
		for characterKey: string, characterData: any in mapData[1] do
			local characterRelativeCFrame: CFrame = zones_Coordinator.translateMetaverseCFrame(characterData[1])
			local characterDistanceFromPlayer: number = (characterRelativeCFrame.Position - relevantPositionToMap).Magnitude
			if characterDistanceFromPlayer > renderMaxDistance then print(201, characterRelativeCFrame.Position, relevantPositionToMap)
				continue
			end
			
			-- avoid duplicating Player Character in store-Data,
			-- but allow prewriting if existing data is found and secondTimeStamp range is closer.
			for _, inputtedCharacterData: any in allRelevantCharacters do
				if inputtedCharacterData.characterKey ~= characterKey then
					continue
				end
				local inputtedCharacterSecondTimeStamp: number = inputtedCharacterData.characterData.secondTimeStamp
				if 
					getNumberRange(inputtedCharacterSecondTimeStamp, currentSecondTimeStamp) >
					getNumberRange(characterData[2], currentSecondTimeStamp)
				then
					-- remove outdated replicated data
					self._crossServerZonesMapData[inputtedCharacterData.zoneIndex][inputtedCharacterData.mapIndex][characterKey] = nil
					print(223, "Removing outdated duplicate data", characterKey)
					-- replace to new data
					inputtedCharacterData.characterData = {
						-- worldCFrame = relativeCFrame in Workspace
						worldCFrame = characterRelativeCFrame + mapRelevantData.metaversePosition - playerMetaverseZonePosition,
						secondTimeStamp = characterData[2],
						mountId = characterData[3],
						message = characterData[4],
						humanoid = zones_Coordinator.translateMetaverseHumanoidStats(characterData[5]),
						animation = characterData[6],
						seat = characterData[7],
						metaData = characterData[8] or {},
						zoneIndex = mapRelevantData.zoneIndex,
					}
					inputtedCharacterData.mapIndex = mapRelevantData.mapIndex
					inputtedCharacterData.zoneIndex = mapRelevantData.zoneIndex
					inputtedCharacterData.relativeDistance = characterDistanceFromPlayer
					break
				end
			end
			
			if
				tonumber(characterKey)
				and allReleveantCharactersRegistery[characterKey] --> Check for closet info
			then print(209)
				continue
			end
			
			-- ignore current in-game players characters if ExperimentalMode is disabled
			if
				tonumber(characterKey)
				and Players:GetPlayerByUserId(tonumber(characterKey))
				and not CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED
			then
				continue
			end
			
			if tonumber(characterKey) then
				allReleveantCharactersRegistery[characterKey] = true
			end
			
			table.insert(allRelevantCharacters, {
				characterKey = characterKey,
				characterData = {
					-- worldCFrame = relativeCFrame in Workspace
					worldCFrame = characterRelativeCFrame + mapRelevantData.metaversePosition - playerMetaverseZonePosition,
					-->> Error here as worldCFrame does not seems to be accurate?
					secondTimeStamp = characterData[2],
					mountId = characterData[3],
					message = characterData[4],
					humanoid = zones_Coordinator.translateMetaverseHumanoidStats(characterData[5]),
					animation = characterData[6],
					seat = characterData[7],
					metaData = characterData[8] or {},
					zoneIndex = mapRelevantData.zoneIndex,
				},
				mapIndex = mapRelevantData.mapIndex,
				zoneIndex = mapRelevantData.zoneIndex,
				relativeDistance = characterDistanceFromPlayer,
			})
		end
	end
	
	if #allRelevantCharacters > renderMaxAmount then
		table.sort(allRelevantCharacters, function(a, b)
			return a.relativeDistance < b.relativeDistance
		end)
	end
	
	local newRenderCharacters: any = {}
	for index: number = 1, math.min(#allRelevantCharacters, renderMaxAmount) do
		local characterData: any = allRelevantCharacters[index].characterData
		local characterKey: string = allRelevantCharacters[index].characterKey
		table.insert(newRenderCharacters, {
			_type = string.sub(characterKey, 1, #NON_PLAYER_CHARACTER_DATA_INDEX) == NON_PLAYER_CHARACTER_DATA_INDEX and "NPC" or "Player",
			zoneIndex = allRelevantCharacters[index].zoneIndex,
			data = characterData,
			key = characterKey,
		})
	end
	
	--> Signal to ServerSide Handlers for ServerSide Handling mainly -> for customisable outfits or meta data handling
	--self.Client.crossServerMapDataUpdated:Fire(player, newRenderCharacters)
	self.onCrossServerMapDataUpdated:Fire(player, newRenderCharacters)
end

function ReplicationService:_updateZonesMapData(mapIndex: string, mapData: any)
	local letterStart: number? = string.find(mapIndex, "/") --> Search for indiviual divider
	local zoneIndex: string = letterStart and string.sub(mapIndex, 1, letterStart - 1) or mapIndex
	
	if not self._crossServerZonesMapData[zoneIndex] then
		self._crossServerZonesMapData[zoneIndex] = {}
	end
	
	local relevantPlayers: any = {}
	local mapCharactersData: any = mapData[1]
	if mapCharactersData then
		for characterKey: string in mapCharactersData do
			local foundPlayer: Player = tonumber(characterKey) and Players:GetPlayerByUserId(tonumber(characterKey))
			if not foundPlayer then
				continue
			end
			table.insert(relevantPlayers, foundPlayer)
		end
	end
	
	self._crossServerZonesMapData[zoneIndex][mapIndex] = mapData
	
	for _, player: Player in relevantPlayers do
		task.spawn(function()
			self:_sortPlayerClientDisplayData(player, zoneIndex)
		end)
	end
end

-- Client Methods
function ReplicationService.Client:setPlayerSetting(player: Player, requestSetting: string)
	-- TODO: IMPLEMENT
end

function ReplicationService.Client:getPlayerSetting(player: Player)
	return self:_getPlayerSettings(player)
end


function ReplicationService:SetUp()
	local networkEnabled: boolean = masterSystem:GetConstant("CrossServer_Enabled", 30)
	self.serviceEnabled = networkEnabled

	if not networkEnabled then
		return
	end
	
	local metaverseSystem: any = masterSystem:GetSystem("MetaverseSystem", "Core")
	local centralSystem: any = masterSystem:GetSystem("CentralSystem", "Core")
	
	local memoryStoreService: any = centralSystem:GetService("MemoryStoreService")
	zones_Coordinator = metaverseSystem:GetLibrary("Zones_Coordinator")
	
	metaverseZoneSize = zones_Coordinator:GetData("MetaverseZone", "Grid")
	
	self:addCoreConnection(Players.PlayerRemoving:Connect(function(player: Player)
		self:_playerRemoved(player)
	end))
	
	self:addCoreConnection(Players.PlayerAdded:Connect(function(player: Player)
		self:_playerAdded(player)
	end))
	
	for _, player: Player in Players:GetPlayers() do
		self:_playerAdded(player)
	end
	
	memoryStoreService.onPresistentInstanceDataUpdated:Connect(function(mapName: string, mapKey: string, mapData: Data, allInstances)
		if mapKey ~= CROSS_SERVER_UPLOAD_KEY then
			return
		end
		self:_updateZonesMapData(mapName, mapData)
	end)
end

return ReplicationService
