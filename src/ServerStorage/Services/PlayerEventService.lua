local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Players = game:GetService("Players")

local PlayerEventService = Knit.CreateService {
    Name = "PlayerEventService",
    Client = {},
}


function PlayerEventService:KnitStart()
    self.MasterService = Knit.GetService("MasterService")
end


function PlayerEventService:KnitInit()
    Players.PlayerAdded:Connect(function(player: Player)
        self.MasterService:PlayerAdded(player)

        player.CharacterAdded:Connect(function(character: Model)
            self.MasterService:CharacterAdded(player, character)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        self.MasterService:PlayerRemoving(player)
    end)
end


return PlayerEventService
