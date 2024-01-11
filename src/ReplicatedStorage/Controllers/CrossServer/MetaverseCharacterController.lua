local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local ConfigurationController = Knit.GetService("ConfigurationController")

local CLIENT_FOLDER_CONSTANT : string = ConfigurationController:GetVariable("CLIENT_FOLDER_CONSTANT")

local METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME: string = ConfigurationController:GetVariable("METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME")
local NAME_COLORS: any = ConfigurationController:GetVariable("NAME_COLORS")

local MetaverseCharacterController = Knit.CreateController { Name = "MetaverseCharacterController" }

MetaverseCharacterController._independentReplicators = {
    players = {},
    npcs = {},
}
MetaverseCharacterController._inGameCharacters = {}
MetaverseCharacterController._inGameNPCs = {}

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

function MetaverseCharacterController:_getCharacter(characterId: string, characterData: any)
	local foundCharacterHandler: any = self._inGameCharacters[characterId]
	if not foundCharacterHandler then
		local foundBaseCharacter: Model = masterSystem.resources.Characters:FindFirstChild(characterId)
		if not foundBaseCharacter then
			return
		end
		
		self._inGameCharacters[characterId] = masterSystem:CreateInGameHandler(
			CharacterReplicator,
			masterSystem,
			self,
			foundBaseCharacter,
			metaverseCharactersFolder, --> [WiP Note] This needs to be store in actual proper ZoneIndex folder instead!
			characterData.worldCFrame
		)
		
		foundCharacterHandler = self._inGameCharacters[characterId]
		foundCharacterHandler._updatedTimestamp = DateTime.now():ToUniversalTime().Second
	end
	
	return foundCharacterHandler
end

function MetaverseCharacterController:_upateCharacter(characterId: string, characterData: any)
	local foundCharacterHandler: any = self:_getCharacter(characterId, characterData)
	if not foundCharacterHandler then
		return
	end
	
	foundCharacterHandler._updatedTimestamp = DateTime.now():ToUniversalTime().Second
	
	task.spawn(function()
		foundCharacterHandler:Update(characterData)
	end)
end

function MetaverseCharacterController:_removeOutdatedCharacters()
	local currentSecond: number = DateTime.now():ToUniversalTime().Second
	for _, characterHandler: any in self._inGameCharacters do
		if characterHandler._updatedTimestamp == currentSecond then
			continue
		end
		characterHandler:destroy()
	end
end

function MetaverseCharacterController:respawnCharacter(characterId: string)
	local foundCharacter: any = self:_getCharacter(characterId)
	if foundCharacter then
		foundCharacter:destroy()
	end
end

function MetaverseCharacterController:addCharacterMasterHandler(characterType: string, moduleScript: ModuleScript, ...)
	if not self._independentReplicators[characterType] then
		characterType = "players"
	end
	
	self._independentReplicators[characterType][moduleScript.Name] = moduleScript
	
	for _, characterHandler: any in characterType == "players" and self._inGameCharacters or self._inGameNPCs do
		characterHandler:addInternalHandler("Registered_%s", moduleScript, ...)
	end
end

function MetaverseCharacterController:SetUp()
	self.masterSystem = Knit.GetService("MasterService")
	local metaverseCharactersService: any = Knit.GetService("MetaverseCharactersService")
	
	self.CharacterReplicator = require(masterSystem.resources.Handlers.CharacterReplicator)
	
	local clientFolder: Folder = masterSystem:GetConstant(CLIENT_FOLDER_CONSTANT)
	for _, otherFolder: Folder in clientFolder:GetChildren() do
		if otherFolder.Name == "Metaverse_PlayersCharacters" and otherFolder:IsA("Folder") then
			otherFolder:Destroy()
		end
	end
	
	self.metaverseCharactersFolder = Instance.new("Folder", clientFolder)
	self.metaverseCharactersFolder.Name = "Metaverse_PlayersCharacters"
	
	metaverseCharactersService.playerRenderCharactersDataUpdated:Connect(function(renderCharacters: any)
		for characterKey: string, characterData: any in renderCharacters do
			self:_upateCharacter(characterKey, characterData)
		end
		self:_removeOutdatedCharacters()
	end)
	
	metaverseCharactersService.npcRenderCharactersDateUpdated:Connect(function(renderNpcCharacters: any)
		for npcKey: string, npcData: any in renderNpcCharacters do
			
		end
	end)
	
	TextChatService.OnIncomingMessage = function(textChatMessage: TextChatMessage)
		local properties: TextChatMessageProperties = Instance.new("TextChatMessageProperties") 
		
		local metaData: any = textChatMessage.Metadata
		if metaData and typeof(metaData) == "string" and #metaData >= 4 then
			pcall(function()
				metaData = HttpService:JSONDecode(metaData)
			end)
		end
		
		local userId: number = metaData.cid and tonumber(metaData.cid)
		if userId and metaData.displayName then
			textChatMessage.PrefixText = string.format("%s:", metaData.displayName)
			local index: number = (userId % #NAME_COLORS) + 1
			properties.PrefixText = string.format("<font color='#%s'>%s</font>", NAME_COLORS[index]:ToHex(), textChatMessage.PrefixText)
		end
		
		return properties
	end
end

function MetaverseCharacterController:KnitStart()
    
end


function MetaverseCharacterController:KnitInit()
    self:SetUp()
end


return MetaverseCharacterController

