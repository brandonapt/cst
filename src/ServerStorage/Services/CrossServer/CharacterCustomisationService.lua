local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local HttpService = game:GetService("HttpService")
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

-- Constants
local PLAYING_EMOTE_ATTRIBUTE: string = ConfigurationService:GetVariable("PLAYING_EMOTE_ATTRIBUTE")
local ACCESSORY_TYPES_CONSTANT: string = ConfigurationService:GetVariable("ACCESSORY_TYPES_CONSTANT")
local CUSTOM_EMOTE_PREFIX: string = ConfigurationService:GetVariable("CUSTOM_EMOTE_PREFIX")
local DEFAULT_HUMANOID_DESCRIPTION: HumanoidDescription = Instance.new("HumanoidDescription")
local HUMANOID_DESCRIPTION_SAVE_PROPERTIES: any = ConfigurationService:GetVariable("HUMANOID_DESCRIPTION_SAVE_PROPERTIES")

local ACCESSORY_TYPES: any = ConfigurationService:GetVariable("ACCESSORY_TYPES")

local SPECIAL_VALUES_DATA_FUNCTIONS: any = ConfigurationService:GetVariable("SPECIAL_VALUES_DATA_FUNCTIONS")

local LAYERED_ACCESSORY_WRITE_ORDER: any = ConfigurationService:GetVariable("LAYERED_ACCESSORY_WRITE_ORDER")

local BODY_COLOR_PROPERTIES: any = ConfigurationService:GetVariable("BODY_COLOR_PROPERTIES")

local CharacterCustomisationService = Knit.CreateService {
    Name = "CharacterCustomisationService",
    _crossServerOutfits = {},
	_inGameCustomEmotes = {},
	Client = {
		playerOutfitChanged = Signal.new(),
		outfitDataChanged = Signal.new(),
	},
    onplayerOutfitChanged = Signal.new(),
    onOutfitDataChanged = Signal.new(),
    onCrossServerOutfitDataUpdated = Signal.new(),
}


function CharacterCustomisationService:KnitStart()
    
end


function CharacterCustomisationService:KnitInit()
    self:SetUp()
end

function CharacterCustomisationService:SetUp()
	self.playersService = Knit.GetService("GamePlayerService")

	self.playersService:updateDataSchema({
		characterData = {
			_isPlayerData = 1,
			outfitId = 0, --> outfitId from player's own outfitsInventory
			overrideOutfit = 0, --> if this data exist as table, player will automatically override to that instead
			outfitsInventory = {}, --[[
				{
					[1] = {
						shirt = id, pants = id, accessories = {...}, bodyType = ..., ...
					},
				}
			]]
		},
	})
	
	local crossServerService: any = Knit.GetService("CrossServerService")
	self:addCoreConnection(self.onCrossServerOutfitDataUpdated:Connect(function(player: Player, hasOutfitData: boolean, outfitHumanoidDescription: HumanoidDescription)
		if not self._crossServerOutfits[player] then
			self._crossServerOutfits[player] = {
				hasOutfitData = 1,
				humanoidDescription = 1,
			}
		end
		
		self._crossServerOutfits[player].hasOutfitData = hasOutfitData
		self._crossServerOutfits[player].humanoidDescription = outfitHumanoidDescription
		
		if not hasOutfitData then
			crossServerService:updatePlayerOutfitData(player)
		else
			crossServerService:updatePlayerOutfitData(player, self:getCrossServerPlayerOutfitData(outfitHumanoidDescription))
		end
	end))
	
	task.spawn(function()
		for player: Player, outfitData: any in self._crossServerOutfits do
			if not outfitData.humanoidDescription:IsA("HumanoidDescription") then
				crossServerService:updatePlayerOutfitData(player)
			else
				crossServerService:updatePlayerOutfitData(player, self:getCrossServerPlayerOutfitData(outfitData.humanoidDescription))
			end
		end
	end)
end

function CharacterCustomisationService:translateCrossServerPlayerOutfitData(_, _, crossServerOutfitData: any, currentHumanoidDescription: HumanoidDescription)
	local newHumanoidDescription: HumanoidDescription = currentHumanoidDescription or Instance.new("HumanoidDescription")
	--> state 2 = Outfit Data is Turned Off
	if crossServerOutfitData[1] == 2 then
		return false
	end
	
	if #crossServerOutfitData[2] > 0 then
		for _, propertyStringValue: string in crossServerOutfitData[2] do
			local splitTable: any = string.split(propertyStringValue, "|")
			local propertyName: string = HUMANOID_DESCRIPTION_SAVE_PROPERTIES[tonumber(splitTable[1])]
			if not propertyName then
				continue
			end

			local propertyValue: any = splitTable[2]
			local searchPropertyName: string = propertyName
			if propertyName == "BodyColor" then
				searchPropertyName = "TorsoColor"
			end

			local actualValue: any
			if string.find(propertyValue, "_") then
				actualValue = SPECIAL_VALUES_DATA_FUNCTIONS[typeof(newHumanoidDescription[searchPropertyName])].decode(propertyValue)
			else
				actualValue = propertyValue
			end

			if propertyName == "BodyColor" then
				for _, bodyColorProperty: string in BODY_COLOR_PROPERTIES do
					newHumanoidDescription[bodyColorProperty] = actualValue
				end
				continue
			end

			newHumanoidDescription[propertyName] = actualValue
		end
	end

	if #crossServerOutfitData[3] > 0 then
		local accessories = {}
		for _, accessoryDataString: string in crossServerOutfitData[3] do
			local splitTable: any = string.split(accessoryDataString, "_")
			local isLayered: boolean = tonumber(splitTable[3]) == 1 and true or false
			local writeTable = {
				AccessoryType = ACCESSORY_TYPES[tonumber(splitTable[1])],
				AssetId = tonumber(splitTable[2]),
				IsLayered = isLayered,
			}
			
			if isLayered then
				writeTable.Order = tonumber(splitTable[4]) > 0 and tonumber(splitTable[4]) or 0
			end
			
			table.insert(accessories, writeTable)
		end

		newHumanoidDescription:SetAccessories(accessories, false)
	end

	return newHumanoidDescription
end

function CharacterCustomisationService:getCrossServerPlayerOutfitData(_, _, humanoidDescription: HumanoidDescription)
	if not humanoidDescription:IsA("HumanoidDescription") then
		warn("[CharacterCustomisationService] getCrossServerPlayerOutfitData only accept HumanoidDescription at the moment!")
		return
	end
	
	local newOutfitData: any = {
		[1] = 1, --> _type = "HumanoidDescription"
		[2] = {}, --> props
		[3] = {}, --> accessories
		--[[ --> Playing Emote is store in MemoryStore instead
		[4] = humanoidDescription:GetEmotes(), --> emotes
		[5] = humanoidDescription:GetEquippedEmotes(), --> equippedEmotes
		]]
	}

	-- SetUp Props
	for proprtyIndex: number, propertyName: string in HUMANOID_DESCRIPTION_SAVE_PROPERTIES do
		if propertyName == "BodyColor" then
			table.insert(newOutfitData[2], tostring(proprtyIndex).."|"..SPECIAL_VALUES_DATA_FUNCTIONS["Color3"].encode(
				humanoidDescription.TorsoColor
			))
			continue
		end

		local propValue: any = humanoidDescription[propertyName]
		if propValue and propValue == DEFAULT_HUMANOID_DESCRIPTION[propertyName] then
			continue
		end

		if typeof(propValue) == "string" or typeof(propValue) == "number" then
			table.insert(newOutfitData[2], tostring(proprtyIndex).."|"..tostring(propValue))

		elseif SPECIAL_VALUES_DATA_FUNCTIONS[typeof(propValue)] then
			table.insert(newOutfitData[2], tostring(proprtyIndex).."|"..SPECIAL_VALUES_DATA_FUNCTIONS[typeof(propValue)].encode(propValue))
		end
	end

	-- SetUp Accessories (LayeredClothing)
	for _, accessoryData: any in humanoidDescription:GetAccessories(true) do
		table.insert(newOutfitData[3], string.format("%s_%s_%s_%s", 
			tostring(table.find(ACCESSORY_TYPES, accessoryData.AccessoryType) or 1),
			tostring(accessoryData.AssetId),
			tostring(accessoryData.IsLayered and 1 or 0),
			tostring(table.find(LAYERED_ACCESSORY_WRITE_ORDER, accessoryData.AccessoryType) or 0)
		))
	end

	return newOutfitData
end

function CharacterCustomisationService:_signalPlayerOutfitChanged(...)
	self.Client.playerOutfitChanged:Fire(...)
	self.onplayerOutfitChanged:Fire(...)
end

function CharacterCustomisationService:_signalOutfitDataChanged(...)
	self.Client.outfitDataChanged:Fire(...)
	self.onOutfitDataChanged:Fire(...)
end
function CharacterCustomisationService:_generateOutfitDataFromHumanoidDescription(humanoidDescription: HumanoidDescription)
	local newOutfitData: any = {
		_type = "HumanoidDescription",
		emotes = HttpService:JSONEncode(humanoidDescription:GetEmotes()),
		equippedEmotes = HttpService:JSONEncode(humanoidDescription:GetEquippedEmotes()),
		accessories = {}, -- HttpService:JSONEncode(humanoidDescription:GetAccessories(false))
		props = {},
	}
	
	local layeredClothingAccessories = humanoidDescription:GetAccessories(false)
	for _, accessoryData in layeredClothingAccessories do
		accessoryData["AccessoryType"] = table.find(ACCESSORY_TYPES, accessoryData.AccessoryType)
	end
	newOutfitData.accessories = HttpService:JSONEncode(layeredClothingAccessories)

	for proprtyIndex: number, propertyName: string in HUMANOID_DESCRIPTION_SAVE_PROPERTIES do
		local propValue: any = humanoidDescription[propertyName]
		if propValue == DEFAULT_HUMANOID_DESCRIPTION[propertyName] then
			continue
		end

		if typeof(propValue) == "string" or typeof(propValue) == "number" then
			newOutfitData.props[tostring(proprtyIndex)] = propValue

		elseif SPECIAL_VALUES_DATA_FUNCTIONS[typeof(propValue)] then
			newOutfitData.props[tostring(proprtyIndex)] = {
				typeof(propValue),
				SPECIAL_VALUES_DATA_FUNCTIONS[typeof(propValue)].encode(propValue)
			}
		end
	end

	return newOutfitData
end

function CharacterCustomisationService:_getHumanoidDescriptionFromOutfitData(outfitData: any, setHumanoidDescription: HumanoidDescription)
	if not outfitData._type or outfitData._type ~= "HumanoidDescription" then
		return
	end
	
	if setHumanoidDescription then
		for _, propertyName: string in HUMANOID_DESCRIPTION_SAVE_PROPERTIES do
			setHumanoidDescription[propertyName] = DEFAULT_HUMANOID_DESCRIPTION[propertyName]
		end
		setHumanoidDescription:SetAccessories({}, false)
	end

	local newHumanoidDescription: HumanoidDescription = setHumanoidDescription or Instance.new("HumanoidDescription")
	if #outfitData.emotes > 2 then
		newHumanoidDescription:SetEmotes(HttpService:JSONDecode(outfitData.emotes))
	end
	if #outfitData.equippedEmotes > 2 then
		newHumanoidDescription:SetEquippedEmotes(HttpService:JSONDecode(outfitData.equippedEmotes))
	end
	if #outfitData.accessories > 2 then
		local layeredClothingAccessories = HttpService:JSONDecode(outfitData.accessories)
		for _, accessoryData in layeredClothingAccessories do
			accessoryData["AccessoryType"] = ConfigurationService:GetVariable("ACCESSORY_TYPES_CONSTANT"):GetEnumFromId(accessoryData.AccessoryType)
		end
		
		newHumanoidDescription:SetAccessories(layeredClothingAccessories, false)
	end

	for propertyIndex: string, propertyValue: any in outfitData.props do
		local propertyName: string = HUMANOID_DESCRIPTION_SAVE_PROPERTIES[tonumber(propertyIndex)]
		if not propertyName then
			continue
		end

		local actualValue: any
		if typeof(propertyValue) == "table" then
			actualValue = SPECIAL_VALUES_DATA_FUNCTIONS[propertyValue[1]].decode(propertyValue[2])
		else
			actualValue = propertyValue
		end

		pcall(function()
			newHumanoidDescription[propertyName] = actualValue
		end)
	end

	return newHumanoidDescription
end

function CharacterCustomisationService:getAccessoryTypeFromData(accessoryType: string)
	local enumItem: EnumItem = ACCESSORY_TYPES[tonumber(accessoryType)] or Enum.AccessoryType.Shirt
	return string.split(tostring(enumItem), ".")[3]
end

function CharacterCustomisationService:getHumanoidDescriptionOutfitDataName(dataIndex: string)
	return HUMANOID_DESCRIPTION_SAVE_PROPERTIES[tonumber(dataIndex)]
end

function CharacterCustomisationService:getHumanoidDescriptionOutfitDataIndex(dataType: string)
	local dataIndex: number = table.find(HUMANOID_DESCRIPTION_SAVE_PROPERTIES, dataType) or 0
	return tostring(dataIndex)
end

function CharacterCustomisationService:getPlayerOutfit(player: Player)
	local playerData: any = playersService:getPlayerData(player)
	return self:getCurrentOutfit(playerData)
end

function CharacterCustomisationService:getCurrentOutfit(data: any)
	local foundCharacterData: any = data.characterData
	if not foundCharacterData then
		return
	end
	
	local currentOutfitData: any = foundCharacterData.outfitsInventory[foundCharacterData.outfitId]
	if foundCharacterData.overrideOutfit ~= 0 then
		currentOutfitData = foundCharacterData.overrideOutfit
	end
	return currentOutfitData
end

function CharacterCustomisationService:getOutfitDataFromHumanoidDescription(humanoidDescription: HumanoidDescription)
	return self:_generateOutfitDataFromHumanoidDescription(humanoidDescription)
end

function CharacterCustomisationService:getHumanoidDescriptionFromOutfitData(outfitData: any, setHumanoidDescription: HumanoidDescription)
	return self:_getHumanoidDescriptionFromOutfitData(outfitData, setHumanoidDescription)
end

function CharacterCustomisationService:overridePlayerOutfit(player: Player, newOutfitData: any)
	newOutfitData = newOutfitData or 0
	
	playersService:updatePlayerData(player, function(playerData: any)
		playerData.characterData.overrideOutfit = newOutfitData
		return playerData
	end)
	
	self:_signalPlayerOutfitChanged(player)
end

function CharacterCustomisationService:changePlayerOutfit(player: Player, newOutfitId: number)
	newOutfitId = tonumber(newOutfitId)
	if not newOutfitId then
		return self:removePlayerOutfit(player)
	end
	
	local playerData: any = playersService:getPlayerData(player)
	local foundAvailableOutfit: any = playerData.characterData.outfitsInventory[newOutfitId]
	if not foundAvailableOutfit then
		return
	end
	
	playersService:updatePlayerData(player, function(playerData: any)
		playerData = self:changeOutfit(player, playerData, newOutfitId)
		return playerData
	end)
	
	self:_signalPlayerOutfitChanged(player)
end

function CharacterCustomisationService:removePlayerOutfit(player: Player)
	playersService:updatePlayerData(player, function(playerData: any)
		playerData.characterData.outfitId = 0
		return playerData
	end)
	
	self:_signalPlayerOutfitChanged(player)
end

function CharacterCustomisationService:addOutfit(player: Player, data: Data, newOutfitData: any)
	if typeof(newOutfitData) == "Instance" and newOutfitData:IsA("HumanoidDescription") then
		local writeOutfitData: any = self:_generateOutfitDataFromHumanoidDescription(newOutfitData)
		newOutfitData = writeOutfitData
	end
	
	if typeof(newOutfitData) ~= "table" then
		return data
	end
	
	if not data.characterData then
		self:registerCustomisationData(data)
	end

	table.insert(data.characterData.outfitsInventory, newOutfitData)
	self:_signalOutfitDataChanged(player, data)

	return data
end

function CharacterCustomisationService:changeOutfit(player: Player, data: any, newOutfitId: number)
	newOutfitId = tonumber(newOutfitId)
	if not data.characterData or not newOutfitId then
		return data
	end

	local foundAvailableOutfit: any = data.characterData.outfitsInventory[newOutfitId]
	if newOutfitId ~= 0 and not foundAvailableOutfit then
		return data
	end

	data.characterData.outfitId = newOutfitId
	self:_signalOutfitDataChanged(player, data)

	return data
end

function CharacterCustomisationService:updateOutfit(player: Player, data: any, requestOutfitId: number, newOutfitData: any)
	requestOutfitId = tonumber(requestOutfitId)
	if not data.characterData or not requestOutfitId then
		return data
	end

	local foundAvailableOutfit: any = data.characterData.outfitsInventory[requestOutfitId]
	if not foundAvailableOutfit then
		return data
	end
	
	if typeof(newOutfitData) == "Instance" and newOutfitData:IsA("HumanoidDescription") then
		local writeOutfitData: any = self:_generateOutfitDataFromHumanoidDescription(newOutfitData)
		newOutfitData = writeOutfitData
	end

	if typeof(newOutfitData) == "function" then
		newOutfitData = newOutfitData(foundAvailableOutfit)
	end

	if typeof(newOutfitData) ~= "table" then
		return data
	end

	data.characterData.outfitsInventory[requestOutfitId] = newOutfitData
	self:_signalOutfitDataChanged(player, data)

	return data
end

function CharacterCustomisationService:removeOutfit(player: Player, data: any, requestOutfitId: number)
	requestOutfitId = tonumber(requestOutfitId)
	if not data.characterData or not requestOutfitId then
		return data
	end
	
	local foundAvailableOutfit: any = data.characterData.outfitsInventory[requestOutfitId]
	if not foundAvailableOutfit then
		return data
	end
	
	if data.characterData.outfitId == requestOutfitId then
		data.characterData.outfitId = 0
	end
	table.remove(data.characterData.outfitsInventory, requestOutfitId)

	self:_signalOutfitDataChanged(player, data)

	return data
end

function CharacterCustomisationService:matchHumanoidDescription(originHumanoidDescription: HumanoidDescription, newHumanoidDescription: HumanoidDescription)
	for _, propertyName: string in HUMANOID_DESCRIPTION_SAVE_PROPERTIES do
		originHumanoidDescription[propertyName] = newHumanoidDescription[propertyName]
	end
	
	originHumanoidDescription:SetAccessories(newHumanoidDescription:GetAccessories(false), false)
	originHumanoidDescription:SetEmotes(newHumanoidDescription:GetEmotes())
	originHumanoidDescription:SetEquippedEmotes(newHumanoidDescription:GetEquippedEmotes())
end

function CharacterCustomisationService:registerCustomisationData(data: table)
	data.characterData = {
		outfitId = 0,
		outfitsInventory = {},
	}
end

-- [Emotes Methods] General Emote Methods for compatiblity on Custom In-Game & ROBLOX Emotes
function CharacterCustomisationService:playEmote(character: Model, emoteName: string)
	local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
	local humanoidDescription: HumanoidDescription = humanoid and humanoid:FindFirstChildOfClass("HumanoidDescription")
	if not humanoidDescription then
		return
	end
	
	if character:GetAttribute(PLAYING_EMOTE_ATTRIBUTE) then
		self:stopEmote(character)
		task.wait(0.05)
	end
	
	local isRobloxEmote: boolean = false
	for _, emoteData in humanoidDescription:GetEquippedEmotes() do
		if emoteData.Name == emoteName then
			isRobloxEmote = true
			break
		end
	end
	
	character:SetAttribute(PLAYING_EMOTE_ATTRIBUTE, emoteName)
	if isRobloxEmote then
		humanoid:PlayEmote(emoteName)
	else
		local foundCustomEmote: any = self._inGameCustomEmotes[string.format(CUSTOM_EMOTE_PREFIX, tostring(emoteName))]
		if foundCustomEmote then
			foundCustomEmote(true, character)
		end
	end
end

function CharacterCustomisationService:stopEmote(character: Model)
	local currentEmoteName: string = character:GetAttribute(PLAYING_EMOTE_ATTRIBUTE)
	if not currentEmoteName then
		return
	end
	
	local foundCustomEmote: any = self._inGameCustomEmotes[string.format(CUSTOM_EMOTE_PREFIX, tostring(currentEmoteName))]
	character:SetAttribute(PLAYING_EMOTE_ATTRIBUTE, nil)
	if foundCustomEmote then
		foundCustomEmote(false, character)
	else
		local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Jump = true
		end
	end
end

function CharacterCustomisationService:registerCustomEmote(registerName: string, customEmoteCallback: any)
	if typeof(customEmoteCallback) ~= "function" then
		return warn("[Character Customisation Service] Unable to register Custom Emote as callback is not a function?", customEmoteCallback)
	end
	
	self._inGameCustomEmotes[string.format(CUSTOM_EMOTE_PREFIX, tostring(registerName))] = customEmoteCallback
end



return CharacterCustomisationService
