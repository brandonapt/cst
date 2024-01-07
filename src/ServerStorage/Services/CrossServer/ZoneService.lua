local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ConfigurationService = Knit.GetService("ConfigurationService")
local CLIENT_FOLDER_CONSTANT : string = ConfigurationService:GetVariable("CLIENT_FOLDER_CONSTANT")

local METAVERSE_ZONES_FOLDER_NAME: string = ConfigurationService:GetVariable("METAVERSE_ZONES_FOLDER_NAME")
local MAXMIMUM_GET_YIELD_TIME: number = ConfigurationService:GetVariable("MAXMIMUM_GET_YIELD_TIME")

local ZoneService = Knit.CreateService {
    Name = "ZoneService",
    Client = {},
}

function ZoneService:KnitStart()
    
end


function ZoneService:KnitInit()
    
end

function ZoneService:getZoneFolder(zoneIndex: string)
	-- IMPLEMENT
end

function ZoneService.Client:getZoneFolder(zoneIndex: string)
	return self:getZoneFolder(zoneIndex)
end

return ZoneService
