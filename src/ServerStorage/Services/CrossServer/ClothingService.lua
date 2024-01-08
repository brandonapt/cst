local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

local DEFAULT_PLAYERS_COLLISION_GROUP_NAME: string = ConfigurationService:GetVariable("DEFAULT_PLAYERS_COLLISION_GROUP_NAME")
local ACCESSORY_TYPES_CONSTANT: string = ConfigurationService:GetVariable("ACCESSORY_TYPES_CONSTANT")
local BODY_PARTS_NAMES_LIST: any = ConfigurationService:GetVariable("BODY_PARTS_NAMES_LIST")
local ANIMATION_NAMES_LIST: any = ConfigurationService:GetVariable("ANIMATION_NAMES_LIST")
local ACCESSORIES_ALLOWED_AMOUNTS: any = ConfigurationService:GetVariable("ACCESSORIES_ALLOWED_AMOUNTS")
local LAYERED_ACCESSORY_WRITE_ORDER: any = ConfigurationService:GetVariable("LAYERED_ACCESSORY_WRITE_ORDER")

local clothingDataSchema: any = {
	inventory = {
		clothings = {},
		animations = {},
		bodyParts = {},
		emotes = {
			rbx = {},
			custom = {},
		},
	}
}

local ClothingService = Knit.CreateService {
    Name = "ClothingService",
    Client = {
        playerOutfitChanged = Signal.new(),
    },
}

function ClothingService:_addAccessoryToInventory(playerData: any, categoryName: string, assetId: number?)
	local accessoryCategoryId: string = masterSystem:GetConstant(ACCESSORY_TYPES_CONSTANT):GetIdFromName(categoryName)
	if accessoryCategoryId == 0 or not assetId or tonumber(assetId) <= 0 then
		return warn("[ClothingService] Unable to add accessory to inventory due to invalid arguments :", categoryName, assetId)
	end
	
	accessoryCategoryId = tostring(accessoryCategoryId)
	
	if not playerData.inventory.clothings[accessoryCategoryId] then
		playerData.inventory.clothings[accessoryCategoryId] = {}
	end

	if not playerData.inventory.clothings[accessoryCategoryId][tostring(assetId)] then
		playerData.inventory.clothings[accessoryCategoryId][tostring(assetId)] = {
			name = MarketplaceService:GetProductInfo(tonumber(assetId), Enum.InfoType.Asset).Name,
			amount = 1,
		}
	end
end

function ClothingService:_doesOwnAccessory(playerData: any, categoryName: string, assetId: number?)
	local accessoryCategoryId: string = masterSystem:GetConstant(ACCESSORY_TYPES_CONSTANT):GetIdFromName(categoryName)
	accessoryCategoryId = tostring(accessoryCategoryId)

	local foundCategoryData = playerData.inventory.clothings[accessoryCategoryId]
	return foundCategoryData and foundCategoryData[tostring(assetId)] ~= nil
end

function ClothingService:_addMissingItems(playerData: any, newOutfitData: any)
	-- saves accessories into player inventory
	if newOutfitData.accessories and #newOutfitData.accessories >= 2 then
		local layeredClothings: any = HttpService:JSONDecode(newOutfitData.accessories)
		for _, accessoryDetail: any in layeredClothings do
			self:_addAccessoryToInventory(
				playerData,
				characterCustomisationService:getAccessoryTypeFromData(accessoryDetail.AccessoryType),
				accessoryDetail.AssetId
			)
		end
	end
	
	for propName: string, propValue: string in newOutfitData.props do
		propName = characterCustomisationService:getHumanoidDescriptionOutfitDataName(propName)
		if propName == "AccessoryBlob" or not string.find(propName, "Accessory") then
			continue
		end
		
		for _, assetId: string in string.split(propValue, ",") do
			self:_addAccessoryToInventory(playerData, string.sub(propName, 1, string.find(propName, "Accessory") - 1), assetId)
		end
	end
	
	local tShirtId: number = newOutfitData.props["30"]
	local shirtId: number, pantsId: number = newOutfitData.props["32"], newOutfitData.props["31"]
	if tShirtId then
		self:_addAccessoryToInventory(playerData, "Classic TShirt", tShirtId)
	end
	if shirtId then
		self:_addAccessoryToInventory(playerData, "Classic Shirt", shirtId)
	end
	if pantsId then
		self:_addAccessoryToInventory(playerData, "Classic Pants", pantsId)
	end
	
	-- saves emotes into player inventory
	if newOutfitData.emotes and #newOutfitData.emotes >= 2 then
		local rbxDefaultEmotes: any = HttpService:JSONDecode(newOutfitData.emotes)
		for emoteName: string, emoteAssetList: any in rbxDefaultEmotes do
			if playerData.inventory.emotes.rbx[emoteName] then
				return
			end
			playerData.inventory.emotes.rbx[emoteName] = emoteAssetList
		end
	end
	
	if newOutfitData.customEmotes then
		for emoteName: string, _ in newOutfitData.customEmotes do
			if playerData.inventory.emotes.custom[emoteName] then
				return
			end
			playerData.inventory.emotes.custom[emoteName] = {
				--> ?
			}
		end
	end
	
	-- saves animations into player inventory
	for propName: string, propValue: string in newOutfitData.props do
		propName = characterCustomisationService:getHumanoidDescriptionOutfitDataName(propName)
		if not string.find(propName, "Animation") then
			continue
		end
		
		if not playerData.inventory.animations[propName] then
			playerData.inventory.animations[propName] = {}
		end
		
		if not playerData.inventory.animations[propName][tostring(propValue)] then
			playerData.inventory.animations[propName][tostring(propValue)] = {
				name = MarketplaceService:GetProductInfo(tonumber(propValue), Enum.InfoType.Asset).Name,
				amount = 1,
			}
		end
	end
	
	-- saves bodyparts into player inventory
	for _, bodyPartPropertyName: string in BODY_PARTS_NAMES_LIST do
		local propName: string = characterCustomisationService:getHumanoidDescriptionOutfitDataIndex(bodyPartPropertyName)
		if not newOutfitData.props[propName] then
			continue
		end
		
		local assetId: number = newOutfitData.props[propName]
		if not playerData.inventory.bodyParts[bodyPartPropertyName] then
			playerData.inventory.bodyParts[bodyPartPropertyName] = {}
		end

		if not playerData.inventory.bodyParts[bodyPartPropertyName][tostring(assetId)] then
			playerData.inventory.bodyParts[bodyPartPropertyName][tostring(assetId)] = {
				name = MarketplaceService:GetProductInfo(tonumber(assetId), Enum.InfoType.Asset).Name,
				amount = 1,
			}
		end
	end
end

function ClothingService:_updatePlayerOutfitFolder(player: Player, playerData: any)
	local playerOutfitFolder: Folder = masterSystem.resources.PlayerOutfits:FindFirstChild(tostring(player.UserId))
	if not playerOutfitFolder then
		return
	end
	
	local humanoidDescription: HumanoidDescription = playerOutfitFolder:FindFirstChildOfClass("HumanoidDescription")
	local foundOutfitData: any = characterCustomisationService:getCurrentOutfit(playerData)
	if foundOutfitData then
		characterCustomisationService:getHumanoidDescriptionFromOutfitData(foundOutfitData, humanoidDescription)
	else
		local playerAvatarHumanoidDescription: HumanoidDescription = Players:GetHumanoidDescriptionFromUserId(math.max(
			player.UserId,
			1
		))
		characterCustomisationService:matchHumanoidDescription(humanoidDescription, playerAvatarHumanoidDescription)
		playerAvatarHumanoidDescription:Destroy()
	end
	
	playerOutfitFolder.DisplayModel.Humanoid:ApplyDescriptionReset(humanoidDescription)
	
	-- reset animations folder
	playerOutfitFolder.Animations:Destroy()
	local animationsFolder: Folder = script.Example_PlayerOutfit.Animations:Clone()
	animationsFolder.Parent = playerOutfitFolder
	
	for _, propertyName: string in ANIMATION_NAMES_LIST do
		if tonumber(humanoidDescription[propertyName]) == 0 then
			continue
		end
		
		local assetModel: Model = InsertService:LoadAsset(humanoidDescription[propertyName])
		local assetFolder: Folder = assetModel:FindFirstChildOfClass("Folder")
		for _, animTag: StringValue in assetFolder:GetChildren() do
			if playerOutfitFolder.Animations:FindFirstChild(animTag.Name) then
				playerOutfitFolder.Animations[animTag.Name]:Destroy()
			end
			animTag:Clone().Parent = playerOutfitFolder.Animations
		end
		
		assetModel:Destroy()
	end
	
	self:_updatePlayerOutfit(player, humanoidDescription)
	
	characterCustomisationService.onCrossServerOutfitDataUpdated:Fire(player, foundOutfitData ~= nil, humanoidDescription)
	self.Client.playerOutfitChanged:Fire(player)
end

function ClothingService:_updatePlayerOutfit(player: Player, outfitHumanoidDescription: HumanoidDescription)
	if not outfitHumanoidDescription then
		local playerOutfitFolder: Folder = masterSystem.resources.PlayerOutfits:FindFirstChild(tostring(player.UserId))
		outfitHumanoidDescription = playerOutfitFolder and playerOutfitFolder:FindFirstChildOfClass("HumanoidDescription")
	end
	
	if not outfitHumanoidDescription then
		return
	end
	
	local playerCharacter: Model = player.Character
	local playerHumanoid: Humanoid = playerCharacter and playerCharacter:WaitForChild("Humanoid", 5)
	if not playerHumanoid then
		return
	end
	
	pcall(function()
		playerHumanoid:ApplyDescriptionReset(outfitHumanoidDescription)
	end)
	collisionGroupsService:setInstanceToCollisionGroup(playerCharacter, DEFAULT_PLAYERS_COLLISION_GROUP_NAME)
end

function ClothingService:_playerAdded(player: Player)
	local playerOutfitFolder: Folder = masterSystem.resources.PlayerOutfits:FindFirstChild(tostring(player.UserId))
	if playerOutfitFolder then
		return
	end
	
	playerOutfitFolder = script.Example_PlayerOutfit:Clone()
	playerOutfitFolder.Name = tostring(player.UserId)
	playerOutfitFolder.Parent = masterSystem.resources.PlayerOutfits
	
	self:_updatePlayerOutfitFolder(player, gamePlayersSerivce:getPlayerData(player))
	self:addCoreConnection(player.CharacterAdded:Connect(function()
		task.wait(0.05)
		self:_updatePlayerOutfit(player)
	end))
	
	self:_updatePlayerOutfit(player)
end

function ClothingService:_playerRemoved(player: Player)
	local playerOutfitFolder: Folder = masterSystem.resources.PlayerOutfits:FindFirstChild(tostring(player.UserId))
	if playerOutfitFolder then
		playerOutfitFolder:Destroy()
	end
end

function ClothingService:addAccessoryToInventory(player: Player, categoryName: string, assetId: number?)
	gamePlayersSerivce:updatePlayerData(player, function(playerData: any)
		self:_addAccessoryToInventory(playerData, categoryName, assetId)
		return playerData
	end)
end

function ClothingService:playerOwnsAccessory(player: Player, ...)
	return self:_doesOwnAccessory(gamePlayersSerivce:getPlayerData(player), ...)
end

function ClothingService.Client:purchaseOutfit(player: Player)
	local getUserId: number = player.UserId >= 1 and player.UserId or 3514794
	local setOutfitData: any = characterCustomisationService:getOutfitDataFromHumanoidDescription(
		Players:GetHumanoidDescriptionFromUserId(getUserId)
	)
	
	gamePlayersSerivce:updatePlayerData(player, function(playerData: any)
		if #playerData.characterData.outfitsInventory >= 5 then
			return playerData
		end
		
		self:_addMissingItems(playerData, setOutfitData)
		characterCustomisationService:addOutfit(player, playerData, setOutfitData)
		return playerData
	end)
end

function ClothingService.Client:changeOutfit(player: Player, outfitId: number)
	gamePlayersSerivce:updatePlayerData(player, function(playerData: any)
		if outfitId ~= 0 and not playerData.characterData.outfitsInventory[outfitId] then
			return playerData
		end

		characterCustomisationService:changeOutfit(player, playerData, outfitId)
		return playerData
	end)
end

function ClothingService.Client:editOutfit(player: Player, outfitId: number, writeCategory: string?, writeData: any?)
	local writeFunction: any, checkFunction: any
	--[[
		writeData = {
			itemName = itemId/Name, --> itemValue for BodyColors & BodyScales
			equip = true/false,
			propName = -> specificier,
		}
	]]
	--[[
		TotalAccessories Amount = 10,
		LayeredAccessories = 5,
		
		HatAccessories = 3,
		HairAccessories = 1,
		
		FaceAccessory = 1,
		FrontAccessory = 1,
		HairAccessory = 3,
		HatAccessory = 3,
		NeckAccessory = 1,
		ShoudlersAccessory = 1,
		WaistAccessory = 1,
	]]
	if writeCategory == "Accessories" then
		checkFunction = function(playerData: any)
			if not writeData.equip then
				return true
			end
			
			local foundClothing: boolean = false
			for _, categoryItems: any in playerData.inventory.clothings do
				if categoryItems[writeData.itemName] then
					foundClothing = true
					break
				end
			end
			return foundClothing
		end
		writeFunction = function(outfitData: any)
			--> equip can be true or false for equip or unequip
			local assignPropertyName: string = characterCustomisationService:getHumanoidDescriptionOutfitDataIndex(writeData.propName)
			local currentAccessoriesIds: string = outfitData.props[assignPropertyName] or ""
			if writeData.equip then
				local writeMaxAmount: number = ACCESSORIES_ALLOWED_AMOUNTS[writeData.propName] or 1
				local newWriteData: string = currentAccessoriesIds ~= "" and currentAccessoriesIds..","..writeData.itemName or writeData.itemName
				local newWriteDataTable: table = string.split(newWriteData, ",")
				if #newWriteDataTable > writeMaxAmount then
					table.remove(newWriteDataTable, 1)
				end
				outfitData.props[assignPropertyName] = table.concat(newWriteDataTable, ",")
			else
				local newWriteDataTable: table = string.split(currentAccessoriesIds, ",")
				table.remove(newWriteDataTable, table.find(newWriteDataTable, writeData.itemName))
				if #newWriteDataTable <= 0 then
					outfitData.props[assignPropertyName] = nil
				else
					outfitData.props[assignPropertyName] = table.concat(newWriteDataTable, ",")
				end
			end
		end
		
	elseif writeCategory == "Layered Clothings" then
		checkFunction = function(playerData: any)
			if not writeData.equip then
				return true
			end

			local foundClothing: boolean = false
			for _, categoryItems: any in playerData.inventory.clothings do
				if categoryItems[writeData.itemName] then
					foundClothing = true
					break
				end
			end
			return foundClothing
		end
		writeFunction = function(outfitData: any)
			--> Order is based off AccessoryType logic
			local encodedAccessoryType: number = masterSystem:GetConstant(ACCESSORY_TYPES_CONSTANT):GetIdFromName(writeData.propName)
			local writeOrder: number = table.find(LAYERED_ACCESSORY_WRITE_ORDER, writeData.propName) or 1
			writeOrder -= 1
			
			local layeredClothings = HttpService:JSONDecode(outfitData.accessories)
			if writeData.equip then
				if #layeredClothings >= 5 then
					for _ = 1, #layeredClothings - 4 do
						table.remove(layeredClothings, 1)
					end
				end
				
				table.insert(layeredClothings, {
					AccessoryType = encodedAccessoryType,
					AssetId = tonumber(writeData.itemName),
					IsLayered = true,
					Order = writeOrder
				})
			else
				for index: number, accessoryData in layeredClothings do
					if accessoryData.AssetId == tonumber(writeData.itemName) then
						table.remove(layeredClothings, index)
						break
					end
				end
			end
			
			outfitData.accessories = HttpService:JSONEncode(layeredClothings)
		end
		
	elseif writeCategory == "Animations" or writeCategory == "Body Parts" or writeCategory == "Clothes" then
		checkFunction = function(playerData: any)
			if not writeData.equip then
				return true
			end

			local foundClothing: boolean = false
			local checkInventory = playerData.inventory.clothings
			if writeCategory == "Body Parts" then
				checkInventory = playerData.inventory.bodyParts
				
			elseif writeCategory == "Animations" then
				checkInventory = playerData.inventory.animations
			end
			for _, categoryItems: any in checkInventory do
				if categoryItems[writeData.itemName] then
					foundClothing = true
					break
				end
			end
			return foundClothing
		end
		writeFunction = function(outfitData: any)
			--> equip can be true or false for equip or unequip
			local assignPropertyName: string = characterCustomisationService:getHumanoidDescriptionOutfitDataIndex(writeData.propName)
			if writeData.equip then
				outfitData.props[assignPropertyName] = tonumber(writeData.itemName)
			elseif writeData.propName ~= "Shirt" and writeData.propName ~= "Pants" then
				outfitData.props[assignPropertyName] = nil
			end
		end
		
	elseif writeCategory == "Emotes" then
		local isCustomEmote: boolean = false
		checkFunction = function(playerData: any)
			if not writeData.equip then
				return true
			end

			local foundItem: boolean = false
			if playerData.inventory.emotes.rbx[writeData.itemName] then
				foundItem = true
			elseif playerData.inventory.emotes.custom[writeData.itemName] then
				isCustomEmote = true
				foundItem = true
			end
			
			return foundItem
		end
		writeFunction = function(outfitData: any, playerData: any)
			local replaceSlot: number = writeData.replaceSlot
			local equippedEmotes = HttpService:JSONDecode(outfitData.equippedEmotes)
			local usedSlots: any = {}
			if not replaceSlot then
				for index: number, emoteData in equippedEmotes do
					table.insert(usedSlots, emoteData.Slot)
				end
				for index: number, emoteData in outfitData.customEmotes do
					table.insert(usedSlots, emoteData.Slot)
				end
				
				for checkNumber: number = 1, 8 do
					if not table.find(usedSlots, checkNumber) then
						replaceSlot = checkNumber
						break
					end
				end
				
				if not replaceSlot then
					replaceSlot = math.random(1, 8)
				end
			end
			
			for index: number, emoteData in equippedEmotes do
				if emoteData.Slot == replaceSlot then
					table.remove(equippedEmotes, index)
				end
			end
			for index: number, emoteData in outfitData.customEmotes do
				if emoteData.Slot == replaceSlot then
					table.remove(equippedEmotes, index)
				end
			end
			
			if isCustomEmote then
				if writeData.equip then
					table.insert(outfitData.customEmotes, {
						Name = tostring(writeData.itemName),
						Slot = replaceSlot,
					})
				else
					for index: number, emoteData in outfitData.customEmotes do
						if emoteData.Name == tostring(writeData.itemName) then
							table.remove(equippedEmotes, index)
							break
						end
					end
				end
				
				return
			end
			
			if writeData.equip then
				if #equippedEmotes >= 8 then
					for _ = 1, #equippedEmotes - 7 do
						table.remove(equippedEmotes, 1)
					end
				end

				table.insert(equippedEmotes, {
					Name = tostring(writeData.itemName),
					Slot = replaceSlot,
				})
			else
				for index: number, emoteData in equippedEmotes do
					if emoteData.Name == tostring(writeData.itemName) then
						table.remove(equippedEmotes, index)
						break
					end
				end
			end
			
			-- update on emotes as well, -> inventory in humanodDescription for emotes
			local emotes = HttpService:JSONDecode(outfitData.emotes)
			local existingEquippedEmotes = {}
			for _, emoteData in equippedEmotes do
				existingEquippedEmotes[emoteData.Name] = true
				if not emotes[emoteData.Name] then
					emotes[emoteData.Name] = playerData.inventory.emotes.rbx[emoteData.Name]
				end
			end
			
			for emoteName: string, _ in emotes do
				if existingEquippedEmotes[emoteName] then
					continue
				end
				emotes[emoteName] = nil
			end
			
			outfitData.emotes = HttpService:JSONEncode(emotes)
			outfitData.equippedEmotes = HttpService:JSONEncode(equippedEmotes)
		end
		
	elseif writeCategory == "Body Colors" then
		local writeColor3: Color3 = writeData.itemValue
		local writeTable: any = {
			"HeadColor", "LeftArmColor", "LeftLegColor", "RightArmColor", "RightLegColor", "TorsoColor"
		}
		checkFunction = function()
			return true
		end
		writeFunction = function(outfitData: any)
			for _, writeValue: string in writeTable do
				local assignPropertyName: string = characterCustomisationService:getHumanoidDescriptionOutfitDataIndex(writeValue)
				outfitData.props[assignPropertyName] = writeColor3
			end
		end
		
	elseif writeCategory == "Body Scales" then
		checkFunction = function()
			return true
		end
		writeFunction = function(outfitData: any)
			local assignPropertyName: string = characterCustomisationService:getHumanoidDescriptionOutfitDataIndex(writeData.propName)
			outfitData.props[assignPropertyName] = writeData.itemValue
		end
	end
	
	if not writeFunction or not checkFunction then
		return
	end
	
	gamePlayersSerivce:updatePlayerData(player, function(playerData: any)
		if not checkFunction(playerData) then
			return playerData
		end
		
		characterCustomisationService:updateOutfit(player, playerData, outfitId, function(outfitData: any)
			writeFunction(outfitData, playerData)
			return outfitData
		end)
		return playerData
	end)
end

function ClothingService:Enable()
	gamePlayersSerivce:updateDataSchema(clothingDataSchema)

	self:addCoreConnection(characterCustomisationService.onOutfitDataChanged:Connect(function(player: Player, playerData: PlayerData)
		self:_updatePlayerOutfitFolder(player, playerData)
	end))

	self:addCoreConnection(Players.PlayerRemoving:Connect(function(player : Player)
		self:_playerRemoved(player)
	end))

	self:addCoreConnection(Players.PlayerAdded:Connect(function(player : Player)
		self:_playerAdded(player)
	end))

	for _, player: Player in Players:GetPlayers() do
		self:_playerAdded(player)
	end
end


function ClothingService:KnitStart()
    
end


function ClothingService:KnitInit()
    self:Enable()
end


return ClothingService
