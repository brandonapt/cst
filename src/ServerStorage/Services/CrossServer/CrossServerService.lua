local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Roblox Services
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Knit Services
local ConfigurationService = Knit.GetService("ConfigurationService")

-- Configuration Variables
local CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED: boolean = ConfigurationService:GetVariable("CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED")
local CROSS_SERVER_OUTFITS_DATA_MAXIMUM_SIZE: number = ConfigurationService:GetVariable("CROSS_SERVER_OUTFITS_DATA_MAXIMUM_SIZE") --> 3.99 MB for Outfits, 1KB for Server Registery
local CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE: number = ConfigurationService:GetVariable("CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE") --> 30 KB [Note] Change to lower number for experimental testing
local CROSS_SERVER_CORE_DATA_MAXIMUM_SIZE: number = ConfigurationService:GetVariable("CROSS_SERVER_CORE_DATA_MAXIMUM_SIZE") --> 2 KB
local PLAYER_REMOVING_ATTRIBUTE: string = ConfigurationService:GetVariable("PLAYER_REMOVING_ATTRIBUTE")
local ENABLE_DEBUG_PRINT: boolean = ConfigurationService:GetVariable("ENABLE_DEBUG_PRINT")
local MINIMUM_CROSS_SERVER_ZONE_SIZE: number = ConfigurationService:GetVariable("MINIMUM_CROSS_SERVER_ZONE_SIZE")
local RENDER_SIZE_DISTANCE_SIZE: number = ConfigurationService:GetVariable("RENDER_SIZE_DISTANCE_SIZE")
local SERVICE_LOOP_DELAY_TIME: number = ConfigurationService:GetVariable("SERVICE_LOOP_DELAY_TIME")
local NON_PLAYER_CHARACTER_DATA_INDEX: string = ConfigurationService:GetVariable("NON_PLAYER_CHARACTER_DATA_INDEX")
local CROSS_SERVER_UPLOAD_KEY: string = ConfigurationService:GetVariable("CROSS_SERVER_UPLOAD_KEY")
local EMOTE_PREFIX: string = ConfigurationService:GetVariable("EMOTE_PREFIX")

-- Variables (unknown)
local memoryStoreService
local dimensionsService
local zoneDataService

local zones_Coordinator

local metaverseZoneSize

local CrossServerService = Knit.CreateService {
    Name = "CrossServerService",
    Client = {},
}

-- more unknown variables
CrossServerService._playersOutfitData = {}
CrossServerService._playersEmoteData = {}
CrossServerService._playersMetaData = {} --> CrossServer CustomData on MemorySortedMap
CrossServerService._playersEnteredZones = {}
CrossServerService._metaverseCharacters = {} --> Server maintained Characters
CrossServerService._memorySortedMaps = {}
CrossServerService._registeredZonesData = {}

-- Utility Functions

-- Checks if givenNumber is within range of nowNumber, considering a maximum limit maxNumber.
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

-- Counts and returns the number of elements (children) in a given Lua table (dictionary).
local function getDictionaryChildrenAmount(dictionary: table)
	local childrenAmount: number = 0
	for _, _ in dictionary do
		childrenAmount += 1
	end
	return childrenAmount
end

-- Calculates and returns the size of a given data table by encoding it to JSON and getting the length of the resulting string.
local function getDataSize(data: any)
	if typeof(data) ~= "table" then
		return 0
	end
	
	local dataSize: number = 0
	pcall(function()
		dataSize = #HttpService:JSONEncode(data)
	end)
	
	return dataSize
end

-- This function recursively checks and updates data sizes in a nested data structure, resetting outdated entries and ensuring total size doesn't exceed a maximum limit.
local function checkThroughZoneIntervalsData(checkData: any, minuteTimeStamp: number, upperData: any, upperIndex: any)
	if typeof(checkData[1]) == "table" then
		-- check on datasize on all tables
		--> ignore any datasize check if the value[1] == "table" too, since the data inside that dataTable may be above 30 KB inside
		local totalDataSize: number = 0
		for _, innerData in checkData do
			if typeof(innerData[1]) == "table" then
				totalDataSize += CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE
			else
				if not verifyIfTimeNumberIsInRange(innerData[2], minuteTimeStamp) then
					innerData[1] = 0 --> Outdated, is it no longer being used?
					innerData[2] = minuteTimeStamp
				end
				totalDataSize += innerData[1]
			end
		end

		if totalDataSize < CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE then
			upperData[upperIndex] = {totalDataSize, minuteTimeStamp}
		else
			--> loop through inner data to check
			for index, innerData in checkData do
				checkThroughZoneIntervalsData(innerData, minuteTimeStamp,checkData, index)
			end
		end

	else
		if not verifyIfTimeNumberIsInRange(checkData[2], minuteTimeStamp) then
			upperData[upperIndex] = {0, minuteTimeStamp} --> Outdated, is it no longer being used?
		end
	end
end

-- Converts a Vector3 into a grid index using a specific formula: 1 + X + 4Y + 2Z.
local function decodeVector3ToInnerGridIndex(innerZone: Vector3)
	return 1 + (innerZone.X * 1) + (innerZone.Y * 4) + (innerZone.Z * 2)
end

-- This function recursively calculates and updates write intervals for a 3D grid, considering the read position, radius, and minimum radius, and stores the results in a provided table.
local function getWriteIntervals(
	writeIntervals: any, readPosition: Vector3,
	readRadius: Vector3, minRadius: Vector3,
	writeIndex: string, intervalData: any, cornerCentre: Vector3, zoneMetaversePosition: Vector3
)
	if not cornerCentre then
		cornerCentre = (-Vector3.new(readRadius, readRadius, readRadius)/2) + Vector3.new(1, 1, 1)
	end

	if typeof(intervalData[1]) == "table" then
		readRadius /= 2

		local cornerCentreZone: Vector3 = zones_Coordinator.getBoundingZones(
			cornerCentre + (Vector3.new(readRadius, readRadius, readRadius)/2),
			Vector3.zero,
			false,
			readRadius
		)[1]

		local touchingInnerZones: any = zones_Coordinator.getBoundingZones(
			readPosition + (Vector3.new(readRadius, readRadius, readRadius)/2),
			--Vector3.zero,
			Vector3.new(minRadius, minRadius, minRadius),
			false,
			readRadius
		)
		
		for _, innerZone: Vector3 in touchingInnerZones do
			innerZone -= cornerCentreZone
			
			if
				innerZone.X < 0 or innerZone.X > 1
				or innerZone.Y < 0 or innerZone.Y > 1
				or innerZone.Z < 0 or innerZone.Z > 1
			then
				continue
			end
			
			local readIndex: number = decodeVector3ToInnerGridIndex(innerZone)
			local foundInnerData: any = intervalData[readIndex] or {0, 0}
			local newWriteIndex: string = writeIndex.."/"..tostring(readIndex)
			if typeof(foundInnerData[1]) == "table" then
				getWriteIntervals(
					writeIntervals, readPosition,
					readRadius, minRadius, newWriteIndex,
					foundInnerData, cornerCentre + (innerZone * Vector3.new(readRadius, readRadius, readRadius)),
					zoneMetaversePosition
				)
			elseif not writeIntervals[newWriteIndex] then
				writeIntervals[newWriteIndex] = zoneMetaversePosition
			end
		end

	elseif not writeIntervals[writeIndex] then
		writeIntervals[writeIndex] = zoneMetaversePosition
	end
end


-- Knit Functions


function CrossServerService:KnitStart()

end


function CrossServerService:KnitInit()
	self:SetUp()
end


-- Methods

-- This function calculates memory map intervals for a player's position in the metaverse, considering the player's dimension and render radius, and returns the intervals and the player's orientation.
function CrossServerService:_getMemoryMapIntervalsFromPosition(requestPlayer: any)
	--> Pure Zones Grabbing = {_metaversePosition = Vector3}
	--> Character = {Character = Model, _metaversePosition = Vector3, _dimensionTag = string}
	--> Translate zoneData[2] into read-able virtual map on current MemorySortedMaps where they should belong
	local playerMetaversePosition: Vector3 = typeof(requestPlayer) == "table" and requestPlayer._metaversePosition
		or zones_Coordinator.getPlayerMetaversePosition(requestPlayer)
	if not playerMetaversePosition then
		return {}, nil
	end

	local writeIntervals: any = {}
	local currentRenderRadius: number = metaverseZoneSize * RENDER_SIZE_DISTANCE_SIZE
	local metaverseZoneIndexes: any = zones_Coordinator.getBoundingZones(
		playerMetaversePosition,
		Vector3.new(
			currentRenderRadius,
			currentRenderRadius,
			currentRenderRadius
		),
		true,
		metaverseZoneSize
	)
	
	local dimensionTag: string = typeof(requestPlayer) == "table" and requestPlayer._dimensionTag
		or dimensionsService:getPlayerDimension(requestPlayer, "")
	for _, metaverseZoneIndex: string in metaverseZoneIndexes do
		-- set Dimensional Tag ahead
		metaverseZoneIndex = dimensionTag..metaverseZoneIndex
		
		local foundZoneData: any = self:_getZoneData(metaverseZoneIndex)
		local intervalsData: any = foundZoneData[2] or {0, 0}
		
		local metaverseZonePosition: Vector3 = zones_Coordinator.getVector3FromCoordinate(metaverseZoneIndex) * metaverseZoneSize
		local relativePosition: Vector3 = playerMetaversePosition - metaverseZonePosition
		local currentRadius: number = 1024
		
		getWriteIntervals(
			writeIntervals, relativePosition,
			currentRadius, typeof(requestPlayer) == "table" and 0 or MINIMUM_CROSS_SERVER_ZONE_SIZE,
			metaverseZoneIndex,
			intervalsData, nil,
			metaverseZonePosition
		)
	end
	
	local rootPart: BasePart = requestPlayer.Character and requestPlayer.Character.PrimaryPart
	return writeIntervals, rootPart and CFrame.new(playerMetaversePosition) * CFrame.fromOrientation(rootPart.CFrame:ToOrientation())
end

-- This function retrieves zone data for a given zone index, updates and cleans the data if necessary, and requests to renew the zone data if it's not already registered.
function CrossServerService:_getZoneData(zoneIndex: string)
	if not self._registeredZonesData[zoneIndex] then
		self._registeredZonesData[zoneIndex] = zoneDataService:setZoneDataPresistentFunctions(zoneIndex, {
			function(oldZoneData: any)
				if not oldZoneData then
					oldZoneData = {}
				end
				
				-- remove any outdated Players OutfitData
				local currentMinuteTimestamp: number = DateTime.now():ToUniversalTime().Minute
				local playersOutfitData: any = oldZoneData[1] or {}
				for playerId: string, playerOutfitData: any in playersOutfitData do
					if verifyIfTimeNumberIsInRange(playerOutfitData[2], currentMinuteTimestamp) then
						continue
					end
					playersOutfitData[playerId] = nil
				end --> Is using Dictionary ok?
				
				-- update any existing Metaverse Zone IntervalData
				--> Determine by known variables in self._memorySortedMaps,
				--[[
					oldZoneData[2] = {
						[1] = {29500, 60}, --> 512
						[2] = {
							[1] = {75, 11}, --> 256
							[2] = {
								[1] = {75, 11}, --> 128, andThen 64
								[2] = {49, 22},
								[3] = {178, 34}, --> [1] value is DataSize
								[4] = {150, 2},
								[5] = {30, 43},
								[6] = {64, 52},
								[7] = {23, 52},
								[8] = {68, 52}, --> if [2] Minute TimeStamp is outdated, set [1] value to 0 and new Minute TimeStamp
							},
							[3] = {4, 34},
							[4] = {150, 2},
							[5] = {30, 43},
							[6] = {64, 52},
							[7] = {23, 52},
							[8] = {68, 52},
						},
						... -> [8]
					} --> This template above, Data Amount is 152 Bytes.
				]]
				
				-- remove any outdated Metaverse Zone IntervalData, or if all combined DataSize is below 30 KB
				-- [Note] Debuging, currently this function seems buggy and somehow resetted the zone data??
				local intervalData: any = oldZoneData[2] or {0, currentMinuteTimestamp}
				checkThroughZoneIntervalsData(intervalData, currentMinuteTimestamp, oldZoneData, 2)
				
				-- delete any unknown weird data?
				for index: number in oldZoneData do
					if not tonumber(index) or tonumber(index) <= 0 or tonumber(index) > 2 then
						oldZoneData[index] = nil
					end
				end
				
			end,
		})
	end
	
	zoneDataService:requestToRenewZoneData(zoneIndex)
	
	return self._registeredZonesData[zoneIndex]
end


-- This function generates a new interval data table, initializing each entry with the maximum allowed character data size and the current timestamp.
function CrossServerService:_getNewIntervalData(currentMinuteTimestamp: number)
	return {
		[1] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp}, [2] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp},
		[3] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp}, [4] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp},
		[5] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp}, [6] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp},
		[7] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp}, [8] = {CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE, currentMinuteTimestamp}
	}
end

-- This function updates the zone data with new write data and updates the players' outfit data. If the inner indexes are provided, it updates the nested interval data; otherwise, it updates the top-level interval data.
function CrossServerService:_updateZoneData(oldZoneData: any, oldZoneIndex: string, innerIndexes: any, newWriteData: any)
	--[[
		ZoneData = {
			[1] = {...}, -> Players Outfit Data
			[2] = {...}, -> Metaverse Zone Intervals Data
		}
	]]
	local currentMinuteTimestamp: number = DateTime.now():ToUniversalTime().Minute
	local zoneCharactersData: any = oldZoneData[1]
	local zoneIntervalData: any = oldZoneData[2]
	if not zoneCharactersData then
		oldZoneData[1] = {}
	end
	if not zoneIntervalData then
		oldZoneData[2] = {}
	end

	-- Update ZoneDate from newWriteData
	if innerIndexes then
		local writeData: any = oldZoneData[2]
		local upperData: any = oldZoneData
		local upperIndex: any = 2
		for index: number = 1, #innerIndexes - 1 do 
			local innerIndex: number = tonumber(innerIndexes[index])
			if typeof(writeData[1]) == "number" or not writeData[innerIndex] then
				upperData[upperIndex] = self:_getNewIntervalData(currentMinuteTimestamp)
				writeData = upperData[upperIndex]
			end
			writeData = writeData[innerIndex]

			upperData = upperData[upperIndex]
			upperIndex = innerIndex
		end

		local writeIndex: number = tonumber(innerIndexes[#innerIndexes])
		if typeof(writeData[writeIndex]) == "number" or not writeData[writeIndex] then
			upperData[upperIndex] = self:_getNewIntervalData(currentMinuteTimestamp)
			writeData = upperData[upperIndex]
		end

		writeData[tonumber(innerIndexes[#innerIndexes])] = newWriteData
	else
		oldZoneData[2] = newWriteData
	end
	
	-- Update PlayersOutfitData
	for characterKey: string in oldZoneData[1] do
		local grabUserId: number = tonumber(characterKey)
		local foundPlayerInGame: Player = grabUserId and Players:GetPlayerByUserId(grabUserId)
		if not foundPlayerInGame then
			continue
		end
		if self._playersOutfitData[foundPlayerInGame] then
			oldZoneData[1][characterKey] = {
				[1] = self._playersOutfitData[foundPlayerInGame],
				[2] = currentMinuteTimestamp,
			}
		else
			oldZoneData[1][characterKey] = nil
		end
	end
end

-- This function retrieves or creates a memory sorted map instance, updates its timestamp, and sets up its persistent details, including cleaning up outdated character data and updating zone data based on the size of the character data.
function CrossServerService:_getMemorySortedMap(memorySortedMapIndex: string)
	local foundMemoryStorePresistentInstance = self._memorySortedMaps[memorySortedMapIndex]
	if foundMemoryStorePresistentInstance then
		foundMemoryStorePresistentInstance._relevantTimestamp = DateTime.now():ToUniversalTime().Minute
		return foundMemoryStorePresistentInstance
	end
	
	self._memorySortedMaps[memorySortedMapIndex] = memoryStoreService:addMemoryStorePresistentInstance(
		memorySortedMapIndex,
		MemoryStoreService:GetSortedMap(memorySortedMapIndex),
		function()
			local presistentMap: any = self:_getMemorySortedMap(memorySortedMapIndex)
			if not presistentMap then
				return 1
			end
			
			local sortedMapPlayerList: any = presistentMap and presistentMap._playerList or {}
			local updatedTimeDiff: number = tick() - presistentMap._updateTimestamp
			return 1/updatedTimeDiff
		end,
		function()
			local presistentMap: any = self:_getMemorySortedMap(memorySortedMapIndex)
			if presistentMap then
				presistentMap._updateTimestamp = tick()
				presistentMap._relevantTimestamp = DateTime.now():ToUniversalTime().Minute
			end
		end
	)
	
	foundMemoryStorePresistentInstance = self._memorySortedMaps[memorySortedMapIndex]
	foundMemoryStorePresistentInstance:SetPresistentDetails({
		function(oldMemorySortedMapData: any) --> [1] = Characters (30 KB), [2] = Server-Server (2 KB)
			if not oldMemorySortedMapData[1] then
				return
			end

			local currentSecondTimeStamp: number = DateTime.now():ToUniversalTime().Second
			for characterKey: string, characterData: any in oldMemorySortedMapData[1] do
				if verifyIfTimeNumberIsInRange(characterData[2] or 0, currentSecondTimeStamp, 10) then
					continue
				end
				oldMemorySortedMapData[1][characterKey] = nil
			end
			
			-- if Characters Data Section is above 30 KB, request for new zones writing?
			local letterStart = string.find(memorySortedMapIndex, "/")
			local memoryMapZoneIndex: string = letterStart and string.sub(memorySortedMapIndex, 1, letterStart - 1) or memorySortedMapIndex
			local innerIndexes: any = letterStart and string.split(string.sub(memorySortedMapIndex, letterStart + 1), "/")
			
			--> [Debug] Debug here as the zoneData writin seems all wrong
			local currentCharactersDataSize: number = getDataSize(oldMemorySortedMapData[1])
			if currentCharactersDataSize > CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE then
				-- set up new indiviual inner zones
				zoneDataService:updateZoneData(memoryMapZoneIndex, function(oldZoneData: any)
					local currentMinuteTimestamp: number = DateTime.now():ToUniversalTime().Minute
					local newWriteData: any = self:_getNewIntervalData(currentMinuteTimestamp)
					self:_updateZoneData(
						oldZoneData,
						memoryMapZoneIndex,
						innerIndexes,
						newWriteData
					)
				end, true)
			else
				--> update on current children amount and latest Minute Timestamp to prevent date erase
				zoneDataService:updateZoneData(memoryMapZoneIndex, function(oldZoneData: any)
					local currentMinuteTimestamp: number = DateTime.now():ToUniversalTime().Minute
					local newWriteData: any = {currentCharactersDataSize, currentMinuteTimestamp}
					self:_updateZoneData(
						oldZoneData,
						memoryMapZoneIndex,
						innerIndexes,
						newWriteData
					)
				end, true)
			end

		end,
	})
	
	foundMemoryStorePresistentInstance._playerList = {}
	foundMemoryStorePresistentInstance._updateTimestamp = 0
	foundMemoryStorePresistentInstance._relevantTimestamp = DateTime.now():ToUniversalTime().Minute
	
	return foundMemoryStorePresistentInstance
end

-- This function handles the removal of a player. It removes the player from the network, clears the player's outfit data, and checks for any invalid entries in the outfit data. If a game closing callback is provided, it will be called after the player is removed from the network.
function CrossServerService:_playerRemoved(player: Player, gameClosingCallback: any)
	local playerCharacterKey: string = tostring(player.UserId)
	player:SetAttribute(PLAYER_REMOVING_ATTRIBUTE, true)

	local playerEnteredZones: any = self._playersEnteredZones[player] or {}
	for _, memorySortedMapZoneIndex: string in playerEnteredZones do
		memoryStoreService:addMemoryStoreRequest(
			"Remove Player From Network",
			gameClosingCallback and 1000000 or 10,
			{
				userId = playerCharacterKey,
				mapKey = CROSS_SERVER_UPLOAD_KEY,
				mapName = memorySortedMapZoneIndex,
			},
			gameClosingCallback
		)
	end
	
	if gameClosingCallback then
		gameClosingCallback()
		return
	end

	if self._playersOutfitData[player] then
		self._playersOutfitData[player] = nil
	end

	for checkPlayer: Player in self._playersOutfitData do
		if not checkPlayer or not checkPlayer.Parent then
			self._playersOutfitData[checkPlayer] = nil
		end
	end
end

-- This function updates the outfit data for a given player. It is called when a player changes their outfit.
function CrossServerService:updatePlayerOutfitData(player: Player, outfitData: any)
	-- This method is call when player has changed their Outfit to a new one
	self._playersOutfitData[player] = outfitData
end

-- This function updates the emote data for a given player. It is called when a player changes their emote. The emote name is prefixed with a predefined prefix before being stored.
function CrossServerService:updatePlayerEmoteData(player: Player, emoteName: string)
	if tostring(emoteName) then
		emoteName = EMOTE_PREFIX..emoteName
	end
	self._playersEmoteData[player] = emoteName
end

-- This function creates a metaverse character with a unique ID, model, and other details provided in the characterDetails parameter. It also provides methods to update the character's metadata, get its position (CFrame), update its ID, and destroy it. If the character model is invalid or the character ID is not provided, it will warn and return early. If no function is provided to get the character's CFrame, it will default to the primary part's CFrame of the character model. The created character is stored in the _metaverseCharacters table and returned.
function CrossServerService:createMetaverseCharacter(characterDetails: any, getMetaverseCFrameFunction: FunctionalTest)
	local characterUID: string = HttpService:GenerateGUID(false)
	local characterModel: Model = characterDetails.Model
	if not characterModel or typeof(characterModel) ~= "Instance" or characterModel and not characterModel.PrimaryPart then
		return warn("[Cross Server Service] Unable to create Metaverse Character as characterDetails invalid,", characterDetails)
	end
	
	if not characterDetails.characterId then
		return warn("[Cross Server Service] Unable to create Metaverse Character as characterId is empty.")
	end
	
	local characterGetCFrame: any = getMetaverseCFrameFunction or function()
		return characterModel.PrimaryPart.CFrame
	end
	
	self._metaverseCharacters[characterUID] = {
		id = "",
		uid = characterUID,
		character = characterModel,
		characterId = characterDetails.characterId,
		dimensionTag = characterDetails._dimension or (RunService:IsStudio() and "Studio|" or "Global|"),
		metaData = {},
		
		UpdateMetaData = function(_, updateFunction: any)
			updateFunction(self._metaverseCharacters[characterUID].metaData)
		end,
		GetMetaverseCFrame = characterGetCFrame,
		UpdateId = function(_, newAssignedId: string)
			self._metaverseCharacters[characterUID].id = newAssignedId
		end,
		Destroy = function()
			characterModel:Destroy()
			self._metaverseCharacters[characterUID] = nil
		end,
	}

	print("[DEBUG CSS] Created character")
	
	return self._metaverseCharacters[characterUID]
end

-- This function retrieves a metaverse character by its UID. If the UID is an instance, it will search for a character with a matching character model. If the UID is a string, it will first try to find a character with a matching UID, and if none is found, it will then try to find a character with a matching ID. It returns the found metaverse character, or nil if no matching character is found.
function CrossServerService:getMetaverseCharacter(uid: string)
	local foundMetaverseCharacter: any
	if typeof(uid) == "Instance" then
		for characterUID: string, characterData: any in self._metaverseCharacters do
			if characterData.character ~= uid then
				continue
			end
			foundMetaverseCharacter = self._metaverseCharacters[characterUID]
			break
		end
		
	elseif typeof(uid) == "string" then
		foundMetaverseCharacter = self._metaverseCharacters[uid]
		
		--> allow usage of uid as id as well
		if not foundMetaverseCharacter then
			for characterUID: string, characterData: any in self._metaverseCharacters do
				if characterData.id ~= uid then
					continue
				end
				foundMetaverseCharacter = self._metaverseCharacters[characterUID]
				break
			end
		end
	end
	
	return foundMetaverseCharacter
end

-- This function updates the metadata for a given player. It calls the provided updateFunction with the player's current metadata and sets the player's metadata to the returned value. If the returned value is nil or its size is less than or equal to 2, it sets the player's metadata to nil.
function CrossServerService:updatePlayerMetaData(player: Player, updateFunction: any)
	local updatedData: any = updateFunction(self._playersMetaData[player])
	if not updatedData then
		warn("[CrossServerService] Unable to update player meta-data as updateFunction return nil.")
	end
	
	if getDataSize(updatedData) <= 2 then
		updatedData = nil
	end
	
	self._playersMetaData[player] = updatedData
end

function CrossServerService:SetUp()
	local networkEnabled: boolean = masterSystem:GetConstant("CrossServer_Enabled", 30)
	self.serviceEnabled = networkEnabled print(547, networkEnabled)

	if not networkEnabled then
		return
	end
	
	local metaverseSystem: any = masterSystem:GetSystem("MetaverseSystem", "Core")
	local centralSystem: any = masterSystem:GetSystem("CentralSystem", "Core")
	
	local centralPlayersService: any = centralSystem:GetService("PlayersService")
	local humanoidService: any = masterSystem:GetService("HumanoidService")
	local chatsService: any = Knit.GetService("ChatService")
	
	memoryStoreService = centralSystem:GetService("MemoryStoreService")
	zoneDataService = metaverseSystem:GetService("ZoneDataService")
	dimensionsService = centralSystem:GetService("DimensionsService")
	
	zones_Coordinator = metaverseSystem:GetLibrary("Zones_Coordinator")
	
	metaverseZoneSize = zones_Coordinator:GetData("MetaverseZone", "Grid")
	
	zoneDataService.onZoneDataUpdated:Connect(function(zoneIndex: string, zoneData: any)
		-- Ignore any unregistered Zones, these may be fired by other Services
		if not self._registeredZonesData[zoneIndex] then
			return
		end
		self._registeredZonesData[zoneIndex] = zoneData
	end)
	
	memoryStoreService:registerMemoryStoreAction(
		"Remove Player From Network",
		function(requestInfo: any)
			local metaverseCharacterSortedMap: MemoryStoreSortedMap = MemoryStoreService:GetSortedMap(requestInfo.mapName)
			metaverseCharacterSortedMap:UpdateAsync(requestInfo.mapKey, function(oldMemorySortedMapData: any)
				if not oldMemorySortedMapData[1] then
					return oldMemorySortedMapData
				end
				
				if oldMemorySortedMapData[1][requestInfo.userId] then
					oldMemorySortedMapData[1][requestInfo.userId] = nil
				end
				
				return oldMemorySortedMapData
			end, 60)
		end
	)
	
	self:addCoreConnection(Players.PlayerRemoving:Connect(function(player: Player)
		self:_playerRemoved(player)
	end))
	
	game:BindToClose(function()
		if not masterSystem.coreRunning then
			return
		end
		
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
	
	-- Automatic MemorySortedMap Cleaner
	task.spawn(function()
		while masterSystem.coreRunning do
			local currentMinuteTimestamp: number = DateTime.now():ToUniversalTime().Minute
			for memoryMapIndex: string, presisentMemoryMap: any in self._memorySortedMaps do
				if verifyIfTimeNumberIsInRange(presisentMemoryMap._relevantTimestamp, currentMinuteTimestamp, 2) then
					continue
				end
				print("[Cross Server Service] Deleting outdated Memory Map, mapIndex :", memoryMapIndex)
				presisentMemoryMap:Destroy()
				self._memorySortedMaps[memoryMapIndex] = nil
			end
			
			task.wait(20)
		end
	end)
	
	-- Main Loop
	task.spawn(function()
		while masterSystem.coreRunning do
			local currentZoneMaps: any = {}
			for player: Player, playerCharacter: Model in centralPlayersService:getAllCharacters() do
				local playerTouchingZones: any, playerMetaverseCFrame: CFrame = self:_getMemoryMapIntervalsFromPosition(player)
				if
					not playerMetaverseCFrame
					or player:GetAttribute(PLAYER_REMOVING_ATTRIBUTE)
					or not playerCharacter
				then
					continue
				end

				local playerEnteredZones: any = {}
				for memorySortedMapZoneIndex: string, mapZoneIndexMetaversePosition: Vector3 in playerTouchingZones do
					if not currentZoneMaps[memorySortedMapZoneIndex] then
						currentZoneMaps[memorySortedMapZoneIndex] = {}
					end

					table.insert(currentZoneMaps[memorySortedMapZoneIndex], {
						player = player,
						character = playerCharacter,
						humanoid = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid"),
						relativeCFrame = playerMetaverseCFrame - mapZoneIndexMetaversePosition,
					})

					table.insert(playerEnteredZones, memorySortedMapZoneIndex)
				end
				self._playersEnteredZones[player] = playerEnteredZones
			end

			--> loop through presistent NPCs list create by Server?
			for _, characterDetails: any in self._metaverseCharacters do
				local characterMetaverseCFrame: CFrame = characterDetails:GetMetaverseCFrame()
				local characterTouchingZones: any, characterMetaverseCFrame: CFrame = self:_getMemoryMapIntervalsFromPosition({
					Character = characterDetails.character,
					_metaversePosition = characterMetaverseCFrame.Position,
					_dimensionTag = characterDetails.dimensionTag
				})

				for memorySortedMapZoneIndex: string, mapZoneIndexMetaversePosition: Vector3 in characterTouchingZones do
					--> ignore any requests into zones that players aren't in, to prevent overhaul on data requests
					if not currentZoneMaps[memorySortedMapZoneIndex] and not CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED then
						continue
					end

					if CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED and not currentZoneMaps[memorySortedMapZoneIndex] then
						currentZoneMaps[memorySortedMapZoneIndex] = {}
					end

					table.insert(currentZoneMaps[memorySortedMapZoneIndex], {
						uid = characterDetails.uid,
						id = characterDetails.id,
						character = characterDetails.character,
						humanoid = characterDetails.character:FindFirstChildOfClass("Humanoid"),
						relativeCFrame = characterMetaverseCFrame - mapZoneIndexMetaversePosition,
						metaData = characterDetails.metaData or {},
					})
				end
			end
			-- [Debug] Currently, player seems to be in all the zone but this is to be test as player is at Position V3.zero
			-- print(748, currentZoneMaps)
			
			for memoryMapIndex: string, presisentMemoryMap: any in self._memorySortedMaps do
				if currentZoneMaps[memoryMapIndex] then
					continue
				end
				warn("[CrossServer Service] Removing an empty MemoryMap Presistent Instance :", memoryMapIndex)
				presisentMemoryMap:Destroy()
				self._memorySortedMaps[memoryMapIndex] = nil
			end

			for memorySortedMapIndex: string, allCharactersInMap: any in currentZoneMaps do
				local memoryStorePresistentMap: any = self:_getMemorySortedMap(memorySortedMapIndex)
				local newUploadDetails = {}

				local letterStart = string.find(memorySortedMapIndex, "/")
				local memoryMapZoneIndex: string = letterStart and string.sub(memorySortedMapIndex, 1, letterStart - 1) or memorySortedMapIndex

				for _, characterDetail: any in allCharactersInMap do
					local inGamePlayer: Player = characterDetail.player
					local writeData = {
						[1] = zones_Coordinator.getMetaverseCFrame(characterDetail.relativeCFrame), -- Vector3 Position + Rotation
						[2] = 59, --DateTime.now():ToUniversalTime().Second, -- Time 0 - 59
						[3] = 0, -- Mount 0 - 99 ID
						[4] = chatsService:getPlayerChatData(inGamePlayer), -- Chat "" to "..." 256 characters --> Abandonable Data?
						[5] = characterDetail.humanoid and zones_Coordinator.getMetaverseHumanoidStats(
							characterDetail.humanoid,
							inGamePlayer and humanoidService:getPlayerJumpData(inGamePlayer)
						) or "", -- Humanoid Data
						[6] = inGamePlayer
							and (
								self._playersEmoteData[inGamePlayer]
								or humanoidService:getPlayerAnimationData(inGamePlayer)
							) or "", -- Animation Data
						[7] = "", -- Seat/Hook Data -> Used for Metaverse Transports
						[8] =  inGamePlayer and self._playersMetaData[inGamePlayer] or characterDetail.metaData or {}, -- Custom Data
					} --> [WiP] This should only be less than 100 Bytes?
					if ENABLE_DEBUG_PRINT then
						print("[Cross Server Data Update]", characterDetail.character, "data -", getDataSize(writeData), "bytes.")
					end

					local writeId: string = characterDetail.uid or inGamePlayer and tostring(inGamePlayer.UserId)
					if characterDetail.id and characterDetail.id ~= "" then
						writeId = characterDetail.id

					elseif characterDetail.id and characterDetail.id == "" then
						writeData[9] = function(newAssignedId: string)
							--> callback to signal that this character is assigned a new ID?
							local foundMetaverseCharacter: any = self:getMetaverseCharacter(characterDetail.uid)
							if foundMetaverseCharacter then
								foundMetaverseCharacter:UpdateId(newAssignedId)
							end
						end
					end

					newUploadDetails[writeId] = writeData
				end

				memoryStorePresistentMap:UploadDetail(
					CROSS_SERVER_UPLOAD_KEY,
					function(oldMemorySortedMapData: any) --> [1] = Characters (30 KB), [2] = Server-Server (2 KB)
						if not oldMemorySortedMapData[1] then
							oldMemorySortedMapData[1] = {}
						end

						local currentSecondTimeStamp: number = DateTime.now():ToUniversalTime().Second
						for characterKey: string, newCharacterData: any in newUploadDetails do
							-- update playerdata[2] second TimeStamp to current Second
							newCharacterData[2] = currentSecondTimeStamp

							-- assign approiate Character UID for NPCs
							if newCharacterData[9] then
								local newAssignCharacterId: string = NON_PLAYER_CHARACTER_DATA_INDEX..string.format("%04d", math.random(1, 9999))
								repeat
									if oldMemorySortedMapData[1][newAssignCharacterId] then
										newAssignCharacterId = NON_PLAYER_CHARACTER_DATA_INDEX..string.format("%04d", math.random(1, 9999))
									end
								until not oldMemorySortedMapData[1][newAssignCharacterId]

								newCharacterData[9](newAssignCharacterId)
								characterKey = newAssignCharacterId
							end

							if newCharacterData[9] then
								table.remove(newCharacterData, 9)
							end

							if not oldMemorySortedMapData[1][characterKey] then
								oldMemorySortedMapData[1][characterKey] = {}
							end

							-- update player HumanoidStats
							if tonumber(characterKey) then
								local foundPlayerInGame: Player = Players:GetPlayerByUserId(tonumber(characterKey))
								humanoidService:resetPlayerJumpData(foundPlayerInGame)
								
								-- update player OutfitData into CrossServer ZoneData
								if self._playersOutfitData[foundPlayerInGame] then
									zoneDataService:setPlayerOutfitData(memoryMapZoneIndex, tonumber(characterKey), self._playersOutfitData[foundPlayerInGame])
								end
							end

							oldMemorySortedMapData[1][characterKey] = newCharacterData
						end
					end,
					function(currentPresistentDetails: any)
						local loopHasRemovedItem: boolean = false
						repeat
							loopHasRemovedItem = false
							for detailIndex: number, presisentDetail: any in currentPresistentDetails do
								if presisentDetail.key == CROSS_SERVER_UPLOAD_KEY then
									table.remove(currentPresistentDetails, detailIndex)
									loopHasRemovedItem = true
									break
								end
							end
						until loopHasRemovedItem == false
					end
				)

			end

			task.wait(SERVICE_LOOP_DELAY_TIME)
		end
	end)
end

return CrossServerService
