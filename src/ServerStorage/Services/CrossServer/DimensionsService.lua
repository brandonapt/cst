local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local RunService = game:GetService("RunService")

local DimensionsService = Knit.CreateService {
    Name = "DimensionsService",
    Client = {},
}


function DimensionsService:KnitStart()
    
end


function DimensionsService:KnitInit()
    
end

function DimensionsService:getPlayerDimension(player: Player, getTag: string)
	local dimensionTag: string = RunService:IsStudio() and "Studio" or "Global"
	return getTag and dimensionTag.."|"..tostring(getTag) or dimensionTag
end

return DimensionsService
