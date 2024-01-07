local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local TextChatService = game:GetService("TextChatService")
local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

local CHARACTER_MINUTE_TIME_STAMP_ATTRIBUTE: string = ConfigurationService:GetVariable("CHARACTER_MINUTE_TIME_STAMP_ATTRIBUTE")
local OUTFIT_TIME_STAMP_ATTRIBUTE: string = ConfigurationService:GetVariable("OUTFIT_TIME_STAMP_ATTRIBUTE")
local CLIENT_FOLDER_CONSTANT : string = ConfigurationService:GetVariable("CLIENT_FOLDER_CONSTANT")
local BOTTOM_MOST_FLOOR_COLLISION_GROUP_NAME: string = ConfigurationService:GetVariable("BOTTOM_MOST_FLOOR_COLLISION_GROUP_NAME")
local METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME: string = ConfigurationService:GetVariable("METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME")
local DEFAULT_PLAYERS_COLLISION_GROUP_NAME: string = ConfigurationService:GetVariable("DEFAULT_PLAYERS_COLLISION_GROUP_NAME")
local DEFAULT_NPCS_COLLISION_GROUP_NAME: string = ConfigurationService:GetVariable("DEFAULT_NPCS_COLLISION_GROUP_NAME")
local DEFAULT_HUMANOID_DESCRIPTION: HumanoidDescription = Instance.new("HumanoidDescription")
local HUMANOID_DESCRIPTION_SAVE_PROPERTIES: any = ConfigurationService:GetVariable("HUMANOID_DESCRIPTION_SAVE_PROPERTIES")
local HUMANOID_DESCRIPTION_ANIMATIONS_LIST: any = ConfigurationService:GetVariable("HUMANOID_DESCRIPTION_ANIMATIONS_LIST")

local MetaverseCharacterService = Knit.CreateService {
    Name = "MetaverseCharacterService",
    Client = {
        playerRenderCharactersDataUpdated = Signal.new(),
        npcRenderCharactersDateUpdated = Signal.new(),
    },
}

MetaverseCharacterService._serviceToggled = false
MetaverseCharacterService._updatedPlayersOutfit = {}
MetaverseCharacterService._characterCreationQueue = {}


function MetaverseCharacterService:KnitStart()
    
end


function MetaverseCharacterService:KnitInit()
    if not TextChatService:FindFirstChild(METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME) then
		local newTextChatChannel: TextChannel = Instance.new("TextChannel")
		newTextChatChannel.Name = METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME
		newTextChatChannel.Parent = TextChatService
	end

    self:SetUp()
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

function MetaverseCharacterService:_updateNpcCharacter()
	-- TODO
end

function MetaverseCharacterService:_updatePlayerCharacterAnimations(character: Model, outfitTimestamp: number)
	local characterHumanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
	local humanoidDescription: HumanoidDescription = characterHumanoid:FindFirstChildOfClass("HumanoidDescription")
	if not humanoidDescription then
		return
	end
	
	for _, foundAnimationsFolder: Folder in character:GetChildren() do
		if foundAnimationsFolder:IsA("Folder") and foundAnimationsFolder.Name == "Animations" then
			foundAnimationsFolder:Destroy()
		end
	end
	
	local animationsFolder: Folder = script.Animations:Clone()
	for _, searchProperty: string in HUMANOID_DESCRIPTION_ANIMATIONS_LIST do
		local assetId: number = humanoidDescription[searchProperty]
		if assetId == 0 then
			continue
		end

		local loadedAsset: Model = InsertService:LoadAsset(assetId)
		for _, instance: any in loadedAsset:FindFirstChildOfClass("Folder"):GetChildren() do
			local foundInstance: any = animationsFolder:FindFirstChild(instance.Name)
			if foundInstance then
				foundInstance:Destroy()
			end

			instance.Parent = animationsFolder
		end

		loadedAsset:Destroy()
	end
	animationsFolder.Parent = character
	
	if outfitTimestamp and character:GetAttribute(OUTFIT_TIME_STAMP_ATTRIBUTE) ~= outfitTimestamp then
		animationsFolder:Destroy()
	end
end

function MetaverseCharacterService:SetUp()
	local networkEnabled: boolean = true
	self.serviceEnabled = networkEnabled

	if not networkEnabled then
		return
	end
	
	local gameSystem: any = masterSystem:GetSystem("GameSystem", "Default_Game")
	local centralSystem : any = masterSystem:GetSystem("CentralSystem", "Core")
	local metaverseSystem:any = masterSystem:GetSystem("MetaverseSystem", "Core")
	
	local replicationService: any = masterSystem:GetService("ReplicationService")
	characterCustomisationService = gameSystem:GetService("CharacterCustomisationService")
	collisionGroupsService = centralSystem:GetManager("CollisionGroupsService")
	zoneDataService = metaverseSystem:GetService("ZoneDataService")
	
	self:_createAntiFallenPartsDestroyDepthForNPCs()
	
	replicationService.onCrossServerMapDataUpdated:Connect(function(player: Player, newRenderCharacters: any)
		if not self._serviceToggled then
			return
		end
		
		--> create and move any existing ServerSide NPCs??
		--> But that would means a lot of ServerSide NPCs can appear as well, making server lagging on Physics if NPCs number manages above 200?
		--> This is better for things such as Humanoid and Hitting a NPC though
		
		local playerCharacters: any = {}
		for _, renderCharacterData: any in newRenderCharacters do
			if renderCharacterData._type == "NPC" then
				self:_updateNpcCharacter(renderCharacterData)
				continue
			end
			
			if renderCharacterData._type == "Player" then
				task.spawn(function()
					self:_updatePlayerCharacter(tonumber(renderCharacterData.key), renderCharacterData.zoneIndex)
				end)
				playerCharacters[renderCharacterData.key] = renderCharacterData.data
			end
		end
		
		self:_removeOutdatedCharacter() --> Debug here as somehow characters do not get updated?
		self.Client.playerRenderCharactersDataUpdated:Fire({player}, playerCharacters)
	end)
end

function MetaverseCharacterService:_createPlayerCharacter(userId: number)
	local getUserId: number = math.max(userId, 1)
	local humanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserId(getUserId)
	local newCharacter: Model = Players:CreateHumanoidModelFromDescription(
		humanoidDescription,
		Enum.HumanoidRigType.R15
	)
	
	for _, scriptInstance : Instance in newCharacter:GetDescendants() do
		if scriptInstance:IsA("LocalScript") or scriptInstance:IsA("Script") or scriptInstance:IsA("ModuleScript") then
			scriptInstance:Destroy()
		end
	end
	
	newCharacter.Name = tostring(userId)
	newCharacter.Humanoid.DisplayName = Players:GetNameFromUserIdAsync(getUserId) or "Unkown User"
	collisionGroupsService:setInstanceToCollisionGroup(newCharacter, DEFAULT_NPCS_COLLISION_GROUP_NAME)
	
	return newCharacter
end

function MetaverseCharacterService:_updatePlayerCharacter(userId: number, userZoneIndex: string)
	local foundCharacter: Model = masterSystem.resources.Characters:FindFirstChild(tostring(userId))
	local characterConfigs: Configuration = foundCharacter and foundCharacter:FindFirstChildOfClass("Configuration")
	local characterOutfitDescription: HumanoidDescription = characterConfigs and characterConfigs:FindFirstChildOfClass("HumanoidDescription")
	local currentMinute: number = DateTime.now():ToUniversalTime().Minute
	
	if not foundCharacter then
		if self._characterCreationQueue[tostring(userId)] then
			return
		end
		
		self._characterCreationQueue[tostring(userId)] = true
		
		pcall(function()
			foundCharacter = self:_createPlayerCharacter(userId)
		end)
		if not foundCharacter then
			self._characterCreationQueue[tostring(userId)] = nil
			return
		end
		
		characterConfigs = Instance.new("Configuration", foundCharacter)
		characterOutfitDescription = Instance.new("HumanoidDescription", characterConfigs)
		
		foundCharacter:SetAttribute(CHARACTER_MINUTE_TIME_STAMP_ATTRIBUTE, currentMinute)
		self:_updatePlayerCharacterAnimations(foundCharacter)
		
		foundCharacter.Parent = masterSystem.resources.Characters
		
		self._characterCreationQueue[tostring(userId)] = nil
	end
	
	if not foundCharacter then
		return
	end
	
	local foundCharacterOutfit: any = zoneDataService:getPlayerOutfitData(userZoneIndex, userId)
	if foundCharacterOutfit and self._updatedPlayersOutfit[tostring(userId)] ~= HttpService:JSONEncode(foundCharacterOutfit) then
		-- reset humanoid to default before applying properties
		for _, property: string in HUMANOID_DESCRIPTION_SAVE_PROPERTIES do
			characterOutfitDescription[property] = DEFAULT_HUMANOID_DESCRIPTION[property]
		end
		characterOutfitDescription:SetAccessories({}, true)
		
		-- get customisationService to apply properties
		local isEquipped: boolean = characterCustomisationService:translateCrossServerPlayerOutfitData(foundCharacterOutfit, characterOutfitDescription)
		if not isEquipped then
			local userHumanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserId(userId)
			for _, property: string in HUMANOID_DESCRIPTION_SAVE_PROPERTIES do
				characterOutfitDescription[property] = userHumanoidDescription[property]
			end
			userHumanoidDescription:Destroy()
		end
		
		self._updatedPlayersOutfit[tostring(userId)] = HttpService:JSONEncode(foundCharacterOutfit)
		
		local humanoid: Humanoid = foundCharacter.Humanoid
		humanoid:ApplyDescriptionReset(characterOutfitDescription)
		collisionGroupsService:setInstanceToCollisionGroup(foundCharacter, DEFAULT_NPCS_COLLISION_GROUP_NAME)
		
		local timeStamp: number = DateTime.now():ToUniversalTime().Millisecond
		foundCharacter:SetAttribute(OUTFIT_TIME_STAMP_ATTRIBUTE, timeStamp)
		self:_updatePlayerCharacterAnimations(foundCharacter, timeStamp)
		
	elseif foundCharacterOutfit == nil and self._updatedPlayersOutfit[tostring(userId)] then
		local playerAvatarHumanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserId(math.max(
			userId,
			1
		))
		characterCustomisationService:matchHumanoidDescription(characterOutfitDescription, playerAvatarHumanoidDescription)
		playerAvatarHumanoidDescription:Destroy()
		
		local humanoid: Humanoid = foundCharacter.Humanoid
		humanoid:ApplyDescriptionReset(characterOutfitDescription)
		collisionGroupsService:setInstanceToCollisionGroup(foundCharacter, DEFAULT_NPCS_COLLISION_GROUP_NAME)
		
		local timeStamp: number = DateTime.now():ToUniversalTime().Millisecond
		foundCharacter:SetAttribute(OUTFIT_TIME_STAMP_ATTRIBUTE, timeStamp)
		self:_updatePlayerCharacterAnimations(foundCharacter, timeStamp)

		self._updatedPlayersOutfit[tostring(userId)] = nil
	end
	
	foundCharacter:SetAttribute(CHARACTER_MINUTE_TIME_STAMP_ATTRIBUTE, currentMinute)
end

function MetaverseCharacterService:_removeOutdatedCharacter()
	local currentMinute: number = DateTime.now():ToUniversalTime().Minute
	for _, playerCharacter: Model in masterSystem.resources.Characters:GetChildren() do
		local updatedMinute: number = playerCharacter:GetAttribute(CHARACTER_MINUTE_TIME_STAMP_ATTRIBUTE) or 0
		if verifyIfTimeNumberIsInRange(updatedMinute, currentMinute, 2) then
			continue
		end
		playerCharacter:Destroy()
	end
end

function MetaverseCharacterService:_createAntiFallenPartsDestroyDepthForNPCs()
	local floor: BasePart = script:WaitForChild("FallenDestoryFloor")
	local floorsFolder: Folder = Instance.new("Folder")
	floorsFolder.Name = "NPCs_BottomMost_Floor"
	masterSystem:CreateInGameInstance(floorsFolder)
	
	collisionGroupsService:addCollisionGroup(BOTTOM_MOST_FLOOR_COLLISION_GROUP_NAME, {
		DEFAULT_PLAYERS_COLLISION_GROUP_NAME
	})
	collisionGroupsService:setInstanceToCollisionGroup(floor, BOTTOM_MOST_FLOOR_COLLISION_GROUP_NAME)
	
	local newFloor: BasePart = floor:Clone()
	newFloor.Position = Vector3.new(0, workspace.FallenPartsDestroyHeight + 16, 0)
	newFloor.Parent = floorsFolder
	
	floorsFolder.Parent = masterSystem:GetConstant(CLIENT_FOLDER_CONSTANT)
end

function MetaverseCharacterService:createAntiFallenPartsDestroyDepthForNPCs(floorPosition: Vector3, floorSize: Vector3)
	local floorTemplate: BasePart = script:WaitForChild("FallenDestoryFloor")
	local floorsFolder: Folder = masterSystem:GetConstant(CLIENT_FOLDER_CONSTANT):WaitForChild("NPCs_BottomMost_Floor")
	
	floorPosition = Vector3.new(floorPosition.X, workspace.FallenPartsDestroyHeight - 16, floorPosition.Z)
	floorsFolder:ClearAllChildren()
	
	for x: number = floorPosition.X - (floorSize.X/2), floorPosition.X + (floorSize.X/2), 2048 do
		for z: number = floorPosition.Z - (floorSize.Z/2), floorPosition.Z + (floorSize.Z/2), 2048 do
			local newFloor: BasePart = floorTemplate:Clone()
			newFloor.Position = Vector3.new(x, floorPosition.Y, z)
			newFloor.Parent = floorsFolder
		end
	end
end


return MetaverseCharacterService
