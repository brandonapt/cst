local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ConfigurationService = Knit.CreateService {
    Name = "ConfigurationService",
    Client = {},
}


local Variables = {
    ["CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED"] = true,
    ["CROSS_SERVER_OUTFITS_DATA_MAXIMUM_SIZE"] = 3999000, --> 3.99 MB for Outfits, 1KB for Server Registery
    ["CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE"] = 30000, --> 30 KB [Note] Change to lower number for experimental testing
    ["CROSS_SERVER_CORE_DATA_MAXIMUM_SIZE"] = 2000, --> 2 KB
    ["PLAYER_REMOVING_ATTRIBUTE"] = "Player_BeingRemoved",
    ["ENABLE_DEBUG_PRINT"] = false,
    ["MINIMUM_CROSS_SERVER_ZONE_SIZE"] = 64,
    ["RENDER_SIZE_DISTANCE_SIZE"] = 0.25,
    ["SERVICE_LOOP_DELAY_TIME"] = 0.33,
    ["NON_PLAYER_CHARACTER_DATA_INDEX"] = "c",
    ["CROSS_SERVER_UPLOAD_KEY"]  = "CrossServer_SortedMap",
    ["EMOTE_PREFIX"] = "e"
}


function ConfigurationService:KnitStart()
    
end


function ConfigurationService:KnitInit()
    
end

function ConfigurationService:GetVariable(name: string)
    return self.Variables[name]
end


return ConfigurationService
