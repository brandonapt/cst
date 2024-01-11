-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Constants
local SHARED_LOGICS_INDEX : string = "Shared"
local CLIENT_LOGICS_INDEX : string = "Client"
local SERVER_LOGICS_INDEX : string = "Server"

local OUTFIT_TIME_STAMP_ATTRIBUTE: string = "Millisecond_TimeStamp"
local DEAULT_RESPAWN_TIME: number = Players.RespawnTime

-- Variables


-- Local Functions
local function returnGetLogicIndexes()
	if RunService:IsServer() then
		return {SHARED_LOGICS_INDEX, SERVER_LOGICS_INDEX}
	else
		return {SHARED_LOGICS_INDEX, CLIENT_LOGICS_INDEX}
	end
end

-- Module
local CharacterReplicator = {}
CharacterReplicator.__index = CharacterReplicator

function CharacterReplicator.new(masterSystem: System, masterManager: Service, templateCharacter: Model, ...)
	local self = setmetatable({
		_minuteTimeStamp = DateTime.now():ToUniversalTime().Minute,
	}, CharacterReplicator)

	local centralSystem: System = masterSystem:GetSystem("CentralSystem", "Core")
	local packageHelpers: Library = centralSystem:GetLibrary("PackageHelpers")
	if not packageHelpers then print(36, centralSystem, packageHelpers) end
	
	self.masterSystem = masterSystem
	self.manager = masterManager
	self.characterId = templateCharacter.Name
	self.characterTemplate = templateCharacter
	self.initalized = false
	
	self.coreRunning = true
	self.coreConnections = {}
	
	self.model = templateCharacter:Clone()
	self.internalHandlers = {}
	
	local foundCopiedHandlers : Folder = self.model:FindFirstChild("Handlers")
	for _, getLogicIndex : string in returnGetLogicIndexes() do
		if script.DefaultPackages:FindFirstChild(getLogicIndex) then
			packageHelpers:loadPackages(
				{
					script.DefaultPackages[getLogicIndex],
					masterSystem.resources.Packages,
				},
				function(moduleScript: ModuleScript, ...)
					self:addInternalHandler("Core_%s", moduleScript, ...)
				end,
				...
			)
		end
		if foundCopiedHandlers and foundCopiedHandlers:FindFirstChild(getLogicIndex) then
			packageHelpers:loadPackages(
				{
					foundCopiedHandlers[getLogicIndex]
				},
				function(moduleScript: ModuleScript, ...)
					self:addInternalHandler("Extra_%s", moduleScript, ...)
				end,
				...
			)
		end
	end
	
	for _, registeredModuleScript: ModuleScript in masterManager._independentReplicators.players do
		self:addInternalHandler("Registered_%s", registeredModuleScript)
	end
	
	table.insert(self.coreConnections, templateCharacter:GetAttributeChangedSignal(OUTFIT_TIME_STAMP_ATTRIBUTE):Once(function() print(76, "OutfitChanged")
		self:destroy()
	end))

	if foundCopiedHandlers then
		foundCopiedHandlers:Destroy()
	end

	self:init()

	return self
end

-- Internal Functions
function CharacterReplicator:addConnection(rbxScriptConnection : RBXScriptConnection)
	table.insert(self.coreConnections, rbxScriptConnection)
end

function CharacterReplicator:addInternalHandler(registerPrefix : string, moduleScript : ModuleScript, ...)
	if self.internalHandlers[string.format(registerPrefix, moduleScript.Name)] then
		return warn("[CharacterReplicator] Unable to add Internal Handler,", registerPrefix, moduleScript)
	end
	self.internalHandlers[string.format(registerPrefix, moduleScript.Name)] = require(moduleScript).new(self, ...)
	
	local internalHandler: Handler = self.internalHandlers[string.format(registerPrefix, moduleScript.Name)]
	if self.initalized and internalHandler.init then
		internalHandler:init()
	end
end

-- Methods
function CharacterReplicator:init()
	for _, handler : Handler in self.internalHandlers do
		if handler.init then
			handler:init()
		end
	end

	self:addConnection(self.model.AncestryChanged:Connect(function(_, parent : Instance)
		if not parent then
			self:destroy()
		end
	end))
	
	self:addConnection(self.model.Destroying:Connect(function()
		self:destroy()
	end))
	
	local foundHumanoid: Humanoid = self.model:FindFirstChildOfClass("Humanoid")
	self:addConnection(foundHumanoid.Died:Connect(function()
		task.delay(DEAULT_RESPAWN_TIME, function()
			self.manager:respawnCharacter(self.characterId)
		end)
	end))
	
	self.initalized = true
end

function CharacterReplicator:destroy()
	if not self.coreRunning then
		return
	end
	
	for _, handler : Handler in self.internalHandlers do
		if handler.destroy then
			handler:destroy()
		end
	end

	self.coreRunning = false

	for _, rbxScriptConnection : RBXScriptConnection in self.coreConnections do
		rbxScriptConnection:Disconnect()
	end
	
	self.model:Destroy()
	self.manager._inGameCharacters[self.characterId] = nil
end

-- External Methods
function CharacterReplicator:Update(characterData: CharacterData)
	self._minuteTimeStamp = DateTime.now():ToUniversalTime().Minute
	
	for _, handler : Handler in self.internalHandlers do
		if handler.Update then
			task.spawn(function()
				handler:Update(characterData)
			end)
		end
	end
end

return CharacterReplicator