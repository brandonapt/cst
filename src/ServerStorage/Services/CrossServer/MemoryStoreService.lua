local ReplicatedStorage
local Knit = require(ReplicatedStorage.Packages.Knit)
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ConfigurationService = Knit.GetService("ConfigurationService")

local PLAYER_INCREMENT_MEMORYSTORE_LIMIT_PER_MINUTE: number = ConfigurationService:GetVariable("PLAYER_INCREMENT_MEMORYSTORE_LIMIT_PER_MINUTE")
local DEFAULT_MEMORYSTORE_EXPIRATION_TIME: number = ConfigurationService:GetVariable("DEFAULT_MEMORYSTORE_EXPIRATION_TIME")
local MIN_MEMORYSTORE_LIMIT_PER_MINUTE: number = ConfigurationService:GetVariable("MIN_MEMORYSTORE_LIMIT_PER_MINUTE")
local SERVICE_LOOP_DELAY_TIME: number = ConfigurationService:GetVariable("SERVICE_LOOP_DELAY_TIME")

local MemoryStoreService = Knit.CreateService {
    Name = "MemoryStoreService",
    Client = {},
}

MemoryStoreService.memoryStoreLimit = 0
MemoryStoreService.memoryStoreRequests = {
    minuteTimeStamp = -1, --> DateTime.now():ToUniversalTime().Minute
    persistent = {
        amount = 0,
        limitPerSecond = 1,
        ratio = 0.6,
    },
    queue = {
        amount = 0,
        limitPerSecond = 1,
        ratio = 0.4,
    },
}
MemoryStoreService._memoryStoreActions = {}
MemoryStoreService._persistentInstances = {}
MemoryStoreService._currentQueue = {}

function MemoryStoreService:KnitStart()
    
end


function MemoryStoreService:KnitInit()
    self.onPresistentInstanceDataUpdated = masterSystem:CreateSignal()
    self:SetUp()
end

function MemoryStoreService:SetUp()
	local centralSystem : any = masterSystem:GetSystem("CentralSystem", "Core")
	local dictionaryHelpers: any = centralSystem:GetLibrary("DictionaryHelpers")
	
	self:addCoreConnection(Players.PlayerAdded:Connect(function()
		self:_updateMemoryStoreLimit()
	end))
	
	self:addCoreConnection(Players.ChildRemoved:Connect(function()
		task.delay(0.2, function()
			self:_updateMemoryStoreLimit()
		end)
	end))
	
	self:_updateMemoryStoreLimit()
	
	task.spawn(function()
		while masterSystem.coreRunning do
			-- Reset Limits Amount if TimeStamp is different
			local currentMinuteTimestamp: number = DateTime.now():ToUniversalTime().Minute
			if self.memoryStoreRequests.minuteTimeStamp ~= currentMinuteTimestamp then
				self.memoryStoreRequests.minuteTimeStamp = currentMinuteTimestamp
				self.memoryStoreRequests.persistent.amount = 0
				self.memoryStoreRequests.queue.amount = 0
			end

			-- Presisent Instances Sorter
			task.spawn(function()
				local executableAmount: number = self:_getExecutableAmount("persistent")
				if executableAmount <= 0 or dictionaryHelpers.count(self._persistentInstances) <= 0 then
					return
				end

				local presistentQueue: any = {}
				for instanceKey: string, presistentInstance: any in self._persistentInstances do
					local updatedTimeDifference: number = tick() - presistentInstance.updatedTimeStamp
					table.insert(presistentQueue, {
						instanceKey = tostring(instanceKey),
						key = presistentInstance.key,
						priority = presistentInstance.priority() + (1/updatedTimeDifference),
					})
				end

				table.sort(presistentQueue, function(a, b)
					return a.priority < b.priority
				end)
				
				--print("MemoryStoreExecutable Amount :", dictionaryHelpers.count(self._persistentInstances), ",", presistentQueue)
				for _ = 1, executableAmount do
					self:_executePresistentRequest(presistentQueue)
				end
			end)

			-- Queue Instances Sorter
			task.spawn(function()
				local executableAmount: number = self:_getExecutableAmount("queue")
				if executableAmount <= 0 or #self._currentQueue <= 0 then
					return
				end

				local requestsQueue: any = {}
				for _, queueInfo: any in self._currentQueue do
					table.insert(requestsQueue, {
						uid = queueInfo.uid,
						timeStamp = queueInfo.priority * queueInfo.timeStamp,
					})
				end

				table.sort(requestsQueue, function(a, b)
					return a.timeStamp > b.timeStamp
				end)

				for _ = 1, executableAmount do
					self:_executeQueueRequest(requestsQueue)
				end
			end)

			task.wait(SERVICE_LOOP_DELAY_TIME)
		end
	end)
end

function MemoryStoreService:_updateMemoryStoreLimit()
	self.memoryStoreLimit = math.max(
		#Players:GetPlayers() * PLAYER_INCREMENT_MEMORYSTORE_LIMIT_PER_MINUTE,
		MIN_MEMORYSTORE_LIMIT_PER_MINUTE
	)
end

function MemoryStoreService:_getExecutableAmount(requestKey: string)
	local playersAmount: number = #Players:GetPlayers()
	local availableAmounts: number = self.memoryStoreRequests[requestKey].ratio * self.memoryStoreLimit
	availableAmounts -=  self.memoryStoreRequests[requestKey].amount
	
	return availableAmounts > 0 and math.clamp(
		availableAmounts,
		0,
		playersAmount * self.memoryStoreRequests[requestKey].limitPerSecond
	) or 0
end

function MemoryStoreService:_getPresistentInstance(instanceKey: string)
	return self._persistentInstances[instanceKey]
end

function MemoryStoreService:_getMemoryStoreAction(actionName: string)
	return self._memoryStoreActions[actionName]
end

function MemoryStoreService:_executePresistentRequest(requestQueue: any)
	if #requestQueue <= 0 then
		return
	end
	
	local currentRequestInfo: any = requestQueue[1]
	local currentRequest: any = table.clone(self._persistentInstances[currentRequestInfo.instanceKey])
	table.remove(requestQueue, 1)
	
	if not currentRequest then
		return warn("[MemoryStoreService] Unable to execute Presistent Request due to invalid Request :", requestQueue[1])
	end
	
	self._persistentInstances[currentRequestInfo.instanceKey].updatedTimeStamp = tick()
	
	local memoryStoreSortedMap: MemoryStoreSortedMap = currentRequest.instance
	local pickedRequestDataKey: string = currentRequest.details[1] and currentRequest.details[1].key
	local pickedExecuteDetails: any = {}
	local foundDetailData: boolean = false
	
	repeat
		foundDetailData = false
		
		for index: number, detailTable: any in currentRequest.details do
			if detailTable.key ~= pickedRequestDataKey then
				continue
			end
			table.insert(pickedExecuteDetails, detailTable)
			table.remove(currentRequest.details, index)
			foundDetailData = true
			break
		end
		
	until not foundDetailData
	--[[ --> Sometimes ExecuteDetails can be 0 but it can be request to get Data from PresistentInstance
	if #pickedExecuteDetails <= 0 then
		currentRequest.updatedCallback()
		return --warn("[MemoryStoreService] Unable to execute Presistent Request due to empty Execute Details :", currentRequest)
	end
	]]
	task.spawn(function()
		local newData: any
		local success: boolean, errorMessage: string = pcall(function()
			newData = memoryStoreSortedMap:UpdateAsync(pickedRequestDataKey, function(oldData: any)
				if not oldData then
					oldData = {}
				end
				
				for _, detailTable: any in pickedExecuteDetails do
					if typeof(detailTable) == "table" and detailTable.execute then
						detailTable.execute(oldData)
					end
				end

				for _, transformativeFunction: any in currentRequest.persistentDetails do
					transformativeFunction(oldData)
				end

				return oldData
			end, 60)
		end)
		
		if not success then
			warn(errorMessage)
		end
		
		currentRequest.updatedCallback()
		
		if not newData then
			return
		end
		
		self.onPresistentInstanceDataUpdated:Fire(currentRequestInfo.instanceKey, pickedRequestDataKey, newData, self._persistentInstances)
	end)
	
	self.memoryStoreRequests.persistent.amount += 1
end

function MemoryStoreService:_executeQueueRequest(requestQueue: any)
	if #requestQueue <= 0 then
		return
	end
	
	local currentRequest: any
	for tableIndex: number, queueInfo: any in self._currentQueue do
		if queueInfo.uid == requestQueue[1].uid then
			currentRequest = table.clone(queueInfo)
			table.remove(self._currentQueue, tableIndex)
			break
		end
	end
	table.remove(requestQueue, 1)
	
	if not currentRequest then
		return
	end
	
	local memoryStoreAction: any = self._memoryStoreActions[currentRequest.name]
	if memoryStoreAction then
		task.spawn(function()
			local isActionSkipped: boolean = memoryStoreAction.execute(currentRequest.details or {})
			if not isActionSkipped then
				self.memoryStoreRequests.queue.amount += 1
			end
			
			if currentRequest.callback then
				currentRequest.callback()
			end
		end)
	end
end

function MemoryStoreService:addMemoryStorePresistentInstance(instanceKey: string, instance: any, priorityFunction: any, updatedCallback: any)
	if not self._persistentInstances[instanceKey] then
		self._persistentInstances[instanceKey] = {
			key = instanceKey,
			instance = instance,
			updatedTimeStamp = 0,
			priority = priorityFunction or function()
				return 1
			end,
			updatedCallback = updatedCallback or function()

			end,
			persistentDetails = {},
			details = {},
		}
	end
	
	return {
		UploadDetail = function(_, uploadKey: string, updateFunction: any, checkFunction: any)
			if typeof(updateFunction) ~= "function" then
				return
			end
			
			--> CheckFunction allows to check & delete any overlapping details if found
			if checkFunction and typeof(checkFunction) == "function" then
				checkFunction(self:_getPresistentInstance(instanceKey).details)
			end
			
			table.insert(self:_getPresistentInstance(instanceKey).details, {
				key = uploadKey,
				execute = updateFunction,
			})
		end,
		SetPresistentDetails = function(_, newPresistentFunctions: any)
			self:_getPresistentInstance(instanceKey).persistentDetails = newPresistentFunctions
		end,
		Get = function()
			return self:_getPresistentInstance(instanceKey)
		end,
		Destroy = function()
			self:removeMemoryStorePresistentInstance(instanceKey)
		end,
	}
end

function MemoryStoreService:getMemoryStorePresistentInstance(instanceKey: string)
	return self:_getPresistentInstance(instanceKey)
end

function MemoryStoreService:removeMemoryStorePresistentInstance(instanceKey: string)
	if not self:_getPresistentInstance(instanceKey) then
		return
	end
	
	self._persistentInstances[instanceKey] = nil
end

function MemoryStoreService:registerMemoryStoreAction(actionName: string, executeFunction: any, mergeLogicFunction: any)
	if self._memoryStoreActions[actionName] or not executeFunction then
		return
	end

	local newMemoryStoreAction: any = {
		execute = function(...)
			executeFunction(...)
		end,
	}

	if typeof(mergeLogicFunction) == "function" then
		newMemoryStoreAction.merge = function(...)
			return mergeLogicFunction(...)
		end
	end

	self._memoryStoreActions[actionName] = newMemoryStoreAction

	return {
		Destroy = function()
			self._memoryStoreActions[actionName] = nil
		end,
	}
end

function MemoryStoreService:addMemoryStoreRequest(actionName: string, actionPriority: number, actionDetails: any, actionCallback: any)
	local foundMemoryStoreAction: any = self:_getMemoryStoreAction(actionName)
	if not foundMemoryStoreAction then
		return warn("[MemoryStoreService] Invalid Action Name! request ActionName :", actionName, ", service actions data :", self._memoryStoreActions, ".")
	end
	
	actionPriority = tonumber(actionPriority) ~= nil and actionPriority or 1
	
	local createNewRequest: boolean = false
	if foundMemoryStoreAction.merge then
		local returnArg: boolean, returnIndex: number = false, nil
		for requestIndex: number, requestInfo: any in self._currentQueue do
			if requestInfo.action == actionName then
				returnIndex = requestIndex
				returnArg, actionDetails = foundMemoryStoreAction.merge(requestInfo.details, actionDetails)
				break
			end
		end
		
		if returnArg then
			self._currentQueue[returnIndex].details = actionDetails
			createNewRequest = false
		end
	else
		createNewRequest = true
	end
	
	if not createNewRequest then
		return
	end
	
	local foundExistingRequest: boolean = nil
	for _, requestInfo: any in self._currentQueue do
		if requestInfo.action == actionName and requestInfo.details == actionDetails then
			foundExistingRequest = true
			break
		end
	end

	if foundExistingRequest then
		return warn("[MemoryStoreService] Repeated MemoryStore request found!", actionName, actionDetails)
	end
	
	table.insert(self._currentQueue, {
		name = actionName,
		uid = HttpService:GenerateGUID(false),
		details = actionDetails,
		priority = actionPriority,
		timeStamp = math.min(1, time()),
		callback = actionCallback,
	})
end

function MemoryStoreService:removeMemoryStoreRequest(actionName: string)
	--> This is rarely used at any moment...
	return nil
end

return MemoryStoreService
