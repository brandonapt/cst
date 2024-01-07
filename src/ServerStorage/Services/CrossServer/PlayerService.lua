local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PlayerService = Knit.CreateService {
    Name = "PlayerService",
    Client = {},
    charactersList = {},
	playerList = {},
	_signals = {},
}


function PlayerService:KnitStart()
    
end


function PlayerService:KnitInit()
    
end


return PlayerService
