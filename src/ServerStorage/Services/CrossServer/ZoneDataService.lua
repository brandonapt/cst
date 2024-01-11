local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local DataStoreService = game:GetService("DataStoreService")
local Signal = require(Knit.Util.Signal)

local ConfigurationService = Knit.GetService("ConfigurationService")

local SAVE_ZONE_DATA_ACTION: string = ConfigurationService:GetVariable("SAVE_ZONE_DATA_ACTION")
local GET_ZONE_DATA_ACTION: string = ConfigurationService:GetVariable("GET_ZONE_DATA_ACTION")

local ZONE_AUTO_UPDATE_INTERVAL_TIME: number = ConfigurationService:GetVariable("ZONE_AUTO_UPDATE_INTERVAL_TIME")

local zonesDatabase: any = DataStoreService:GetDataStore("Metaverse_ZonesDatabase")

local ZoneDataService = Knit.CreateService {
    Name = "ZoneDataService",
    Client = {},
    _renewDataQueue = {},
	_getDataQueue = {},
	_zonesData = {},
	_requestDatastoreQueue = {},
    onZoneDataUpdated = Signal.new(),
}


function ZoneDataService:KnitStart()
    
end


function ZoneDataService:KnitInit()
    self.datastoreService = Knit.GetService("DatastoreService")
    masterSystem:CreateManagerSaveDataKey(self, "_zonesData")
    self:SetUp()
end

function ZoneDataService:SetUp()
	self.datastoreService:registerDatastoreAction(GET_ZONE_DATA_ACTION, function(requestInfo: any)
		local zoneKey: string = tostring(requestInfo.zoneKey)
		if not zoneKey then
			return true
		end
		
		local zoneData: any = self.datastoreService:grabData(zonesDatabase, zoneKey)
		if not self._zonesData[zoneKey] then
			self._zonesData[zoneKey] = {}
		end
		
		self._zonesData[zoneKey].data = zoneData or {}
		self._zonesData[zoneKey].timeStamp = DateTime.now().UnixTimestamp
		
		self._getDataQueue[zoneKey] = nil
		
		if self._renewDataQueue[zoneKey] then
			self._renewDataQueue[zoneKey] = nil
		end
		
		if requestInfo.callback then
			requestInfo.callback(zoneData)
		end
		
		self:_signalZoneDataUpdated(zoneKey, self._zonesData[zoneKey].data)
	end)
	
	self.datastoreService:registerDatastoreAction(SAVE_ZONE_DATA_ACTION, function(requestInfo: any)
		local zoneKey: string = tostring(requestInfo.zoneKey)
		if not zoneKey then
			return true
		end

		local updateFunctions: any = requestInfo.updateFunctions
		local zoneData: any = self.datastoreService:updateData(zonesDatabase, zoneKey, function(oldData: any)
			if not oldData then
				oldData = {}
			end
			
			for _, updateFunction in updateFunctions do
				if typeof(updateFunction) ~= "function" then
					continue
				end
				updateFunction(oldData)
			end
			
			local foundPresistentFunctions: any = self._zonesData[zoneKey] and self._zonesData[zoneKey].presistentFunctions
			if foundPresistentFunctions then
				for _, updateFunction in foundPresistentFunctions do
					if typeof(updateFunction) ~= "function" then
						continue
					end
					updateFunction(oldData)
				end
			end
			
			return oldData
		end)
		
		if not self._zonesData[zoneKey] then
			self._zonesData[zoneKey] = {}
		end
		
		self._zonesData[zoneKey].data = zoneData or {}
		self._zonesData[zoneKey].timeStamp = DateTime.now().UnixTimestamp + math.random(0, ZONE_AUTO_UPDATE_INTERVAL_TIME)
		
		if self._renewDataQueue[zoneKey] then
			self._renewDataQueue[zoneKey] = nil
		end
		
		if requestInfo.callback then
			requestInfo.callback()
		end
		
		self:_signalZoneDataUpdated(zoneKey, self._zonesData[zoneKey].data)
		
	end, function(existingRequestInfo, newRequestInfo)
		if existingRequestInfo.zoneKey ~= newRequestInfo.zoneKey then
			return
		end

		for _, updateFunction in newRequestInfo.updateFunctions do
			table.insert(existingRequestInfo, updateFunction)
		end

		return true, existingRequestInfo
	end)
end

function ZoneDataService:_signalZoneDataUpdated(zoneIndex: string, zoneData: any)
	self.onZoneDataUpdated:Fire(zoneIndex, zoneData)
end

function ZoneDataService:getZoneData(zoneIndex: string, yieldUntilResultFound: boolean)
	if not self.serviceEnabled then
		return
	end
	
	if not self.datastoreService then
		repeat
			task.wait()
		until self.datastoreService
	end
	
	local foundZoneDetails: any = self._zonesData[zoneIndex]
	if not foundZoneDetails and not self._getDataQueue[zoneIndex] then
		self._getDataQueue[zoneIndex] = true
		self.datastoreService:addDatastoreRequest(GET_ZONE_DATA_ACTION, 20, {
			zoneKey = zoneIndex,
		})
		
		if yieldUntilResultFound then
			repeat
				task.wait()
			until self._zonesData[zoneIndex]
			foundZoneDetails = self._zonesData[zoneIndex]
		end
	end
	
	if foundZoneDetails and DateTime.now().UnixTimestamp - foundZoneDetails.timeStamp >= ZONE_AUTO_UPDATE_INTERVAL_TIME then
		self.datastoreService:addDatastoreRequest(SAVE_ZONE_DATA_ACTION, 5, {
			zoneKey = zoneIndex,
			updateFunctions = {},
		})
	end
	
	return foundZoneDetails and foundZoneDetails.data
end

function ZoneDataService:setZoneDataPresistentFunctions(zoneIndex: string, newPresistentFunctions: any)
	self:getZoneData(zoneIndex, true)
	self._zonesData[zoneIndex].presistentFunctions = newPresistentFunctions
	return self:getZoneData(zoneIndex)
end

--> Method is used for outfit data setting by CrossServerService
function ZoneDataService:getPlayerOutfitData(zoneIndex: string, requestId: number)
	local foundZoneData: any = self:getZoneData(zoneIndex)
	return foundZoneData and foundZoneData[1] and foundZoneData[1][tostring(requestId)] and foundZoneData[1][tostring(requestId)][1]
end

function ZoneDataService:setPlayerOutfitData(zoneIndex: string, userId: number, outfitData: any)
	self:updateZoneData(zoneIndex, function(oldZoneData: any)
		if not oldZoneData[1] then
			oldZoneData[1] = {}
		end
		oldZoneData[1][tostring(userId)] = {
			[1] = outfitData,
			[2] = DateTime.now():ToUniversalTime().Minute,
		}
	end, true)
end

function ZoneDataService:requestToRenewZoneData(zoneIndex: string)
	local foundZoneDetails: any = self._zonesData[zoneIndex]
	if
		not foundZoneDetails
		or foundZoneDetails and DateTime.now().UnixTimestamp - foundZoneDetails.timeStamp < ZONE_AUTO_UPDATE_INTERVAL_TIME
		or self._renewDataQueue[zoneIndex]
	then
		return
	end
	
	self._renewDataQueue[zoneIndex] = true
	
	self.datastoreService:addDatastoreRequest(SAVE_ZONE_DATA_ACTION, 1, {
		zoneKey = zoneIndex,
		updateFunctions = self._requestDatastoreQueue[zoneIndex] or { function() end },
	})
end

--> Method is used for directly saving any new values that should be saved
function ZoneDataService:updateZoneData(zoneIndex: string, transformativeFunction: any, updateDataWithFunction: boolean)
	if not self.serviceEnabled then
		return
	end
	
	if updateDataWithFunction then
		transformativeFunction(self._zonesData[zoneIndex].data)
		self:_signalZoneDataUpdated(zoneIndex, self._zonesData[zoneIndex].data)
	end
	
	if not self._requestDatastoreQueue[zoneIndex] then
		self._requestDatastoreQueue[zoneIndex] = {}
	end
	
	table.insert(self._requestDatastoreQueue[zoneIndex], transformativeFunction)
	
	self:requestToRenewZoneData(zoneIndex)
end

return ZoneDataService
