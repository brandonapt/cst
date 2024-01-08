local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataStoreService = game:GetService("DataStoreService")
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

local DATASTORE_WAIT_TIME : number = ConfigurationService:GetVariable("DATASTORE_WAIT_TIME")
local DATASTORE_MAX_RETRIES : number = ConfigurationService:GetVariable("DATASTORE_MAX_RETRIES")

local DatastoreService = Knit.CreateService {
    Name = "DatastoreService",
    Client = {},
    datastore_Queue = {},
	datastore_Actions = {},
	datastore_RequestSignal = Signal.new(),
}


function DatastoreService:KnitStart()
    
end


function DatastoreService:KnitInit()
    self:SetUp()
end

function DatastoreService:addDatastoreRequest(actionName : string, actionPriority : number, actionDetails : any)
	local foundDatastoreAction: any = self.datastore_Actions[actionName]
	if not actionName or not foundDatastoreAction then
		local prefix : string = "[Datastore Manager] Invalid Action Name! request ActionName :"
		return warn(prefix, actionName, ", datastore_Actions :", self.datastore_Actions, ".")
	end

	if not actionPriority then
		actionPriority = 1
	end
	
	if foundDatastoreAction.merge then
		local createNewRequest: boolean = true
		local replaceRequestIndex: number, replaceRequestDetails: any
		for requestIndex: number, requestInfo: any in self.datastore_Queue do
			if requestInfo.name == actionName then
				local returnArg, returnDetails = foundDatastoreAction.merge(requestInfo.details, actionDetails)
				if returnArg == true and replaceRequestDetails then
					createNewRequest = false
					replaceRequestIndex = requestIndex
					replaceRequestDetails = returnDetails
				end
			end
		end
		
		if createNewRequest then
			table.insert(self.datastore_Queue, {
				name = actionName,
				priority = actionPriority,
				timeStamp = time(),
				details = actionDetails,
			})
		elseif self.datastore_Queue[replaceRequestIndex] then
			self.datastore_Queue[replaceRequestIndex].details = replaceRequestDetails
		end
	else
		local foundRequest : any = nil
		for requestIndex, requestInfo in self.datastore_Queue do
			if requestInfo.name == actionName and requestInfo.details == actionDetails then
				foundRequest = true
				break
			end
		end

		if foundRequest then
			return warn("[Datastore Manger] Repeated Datastore Request found!", foundRequest, actionName, actionDetails)
		end

		table.insert(self.datastore_Queue, {
			name = actionName,
			priority = actionPriority,
			timeStamp = time(),
			details = actionDetails,
		})
	end
end

function DatastoreService:SetUp()
	local queue_SkippedRequest = false
	task.spawn(function()
			task.wait(queue_SkippedRequest and 0 or DATASTORE_WAIT_TIME)

			if queue_SkippedRequest then
				queue_SkippedRequest = false
			end

			local current_DatastoreRequest : table = nil
			local current_DatastoreRequestIndex : number = 0
			local current_RequestStamp : number = 0

			for requestIndex, requestInfo in self.datastore_Queue do
				local currentStamp = requestInfo.priority * requestInfo.timeStamp
				if currentStamp > current_RequestStamp then
					current_DatastoreRequest = requestInfo
					current_RequestStamp = currentStamp
					current_DatastoreRequestIndex = requestIndex
				end
			end

			if current_DatastoreRequest then
				local current_DatastoreAction : any = self.datastore_Actions[current_DatastoreRequest.name]
				local requestSkipped = current_DatastoreAction.execute(current_DatastoreRequest.details)

				if requestSkipped then
					queue_SkippedRequest = true
				end

				table.remove(self.datastore_Queue, current_DatastoreRequestIndex)
			end
	end)
end

function DatastoreService:grabData(_, _, requestDatabase : any, requestKey :string)
	local currentRetry = 0
	local customDataTree = {}
	
	if game.PlaceId == 0 then
		return customDataTree
	end

	local success, errorMessage = pcall(function()
		customDataTree = requestDatabase:GetAsync(requestKey)
	end)

	repeat
		if not success then
			currentRetry += 1

			warn("[Datastore Manager] Error occured! errorMessage :", errorMessage)

			task.wait(DATASTORE_WAIT_TIME)

			local success, errorMessage = pcall(function()
				customDataTree = requestDatabase:GetAsync(requestKey)
			end)
		end
	until success == true or currentRetry > DATASTORE_MAX_RETRIES

	return customDataTree
	
end

function DatastoreService:grabOrderDataStore(_, _, requestDatabase, ascending, pagesize, minValue, maxValue)
	local currentRetry = 0
	local DataStorePages
	
	if game.PlaceId == 0 then
		return {}
	end

	local success, errorMessage = pcall(function()
		DataStorePages = requestDatabase:GetSortedAsync(ascending, pagesize, minValue, maxValue)
	end)

	repeat
		if not success then
			currentRetry += 1

			warn("[Datastore Manager] Error occured! errorMessage :", errorMessage)

			task.wait(DATASTORE_WAIT_TIME)

			local success, errorMessage = pcall(function()
				DataStorePages = requestDatabase:GetSortedAsync(ascending, pagesize, minValue, maxValue)
			end)
		end
	until success == true or currentRetry > DATASTORE_MAX_RETRIES

	return DataStorePages
end

function DatastoreService:registerDatastoreAction(_, actionName: string, executeFunction: any, mergeLogicFunction: any)
    if manager.datastore_Actions[actionName] or not executeFunction then
        return
    end
        
    local newDatastoreAction: any = {
        execute = function(...)
            executeFunction(...)
        end,
    }
        
    if typeof(mergeLogicFunction) == "function" then
        newDatastoreAction.merge = function(...)
            return mergeLogicFunction(...)
        end
    end
        
    manager.datastore_Actions[actionName] = newDatastoreAction
end

function DatastoreService:removeData(_, _, requestDatabase, requestKey)
	local currentRetry = 0
	
	if game.PlaceId == 0 then
		return
	end

	local success, errorMessage = pcall(function()
		requestDatabase:RemoveAsync(requestKey)
	end)

	repeat
		if not success then
			currentRetry += 1

			warn("[Datastore Manager] Error occured! errorMessage :", errorMessage)

			task.wait(DATASTORE_WAIT_TIME)

			local success, errorMessage = pcall(function()
				requestDatabase:RemoveAsync(requestKey)
			end)
		end
	until success == true or currentRetry > DATASTORE_MAX_RETRIES
end

function DatastoreService:updateData(_, _, requestDatabase, requestKey, requestFunction)
	local currentRetry = 0
	local customDataTree = {}
	
	if game.PlaceId == 0 then
		return customDataTree
	end

	local success, errorMessage = pcall(function()
		customDataTree = requestDatabase:UpdateAsync(requestKey, requestFunction)
	end)

	repeat
		if not success then
			currentRetry += 1

			warn("[Datastore Manager] Error occured! errorMessage :", errorMessage)

			task.wait(2 * DATASTORE_WAIT_TIME)

			local success, errorMessage = pcall(function()
				customDataTree = requestDatabase:UpdateAsync(requestKey, requestFunction)
			end)
		end
	until success == true or currentRetry > DATASTORE_MAX_RETRIES

	return customDataTree
end

function DatastoreService:uploadData(_, _, requestDatabase, requestKey, requestValue)
	local currentRetry = 0
	
	if game.PlaceId == 0 then
		return
	end

	local success, errorMessage = pcall(function()
		requestDatabase:SetAsync(requestKey, requestValue)
	end)

	repeat
		if not success then
			currentRetry += 1

			warn("[Datastore Manager] Error occured! errorMessage :", errorMessage)

			task.wait(DATASTORE_WAIT_TIME)

			local success, errorMessage = pcall(function()
				requestDatabase:SetAsync(requestKey, requestValue)
			end)
		end
	until success == true or currentRetry > DATASTORE_MAX_RETRIES
end

return DatastoreService
