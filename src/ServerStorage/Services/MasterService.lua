local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(Knit.Util.Signal)

local MasterService = Knit.CreateService {
    Name = "MasterService",
    Client = {},
    PlayerAdded = Signal.new(),
    CharacterAdded = Signal.new(),
    PlayerRemoving = Signal.new(),
}


function MasterService:KnitStart()
    
end


function MasterService:KnitInit()
    
end

function MasterService:PlayerAdded(player: Player)
    self.playerAdded:Fire(player)
end

function MasterService:CharacterAdded(player: Player, character: Model)
    self.characterAdded:Fire(player, character)
end

function MasterService:PlayerRemoving(player: Player)
    self.playerRemoving:Fire(player)
end

function MasterService:GetSignal(name: string)
    return self[name]
end

function MasterService.Client:GetSignal(name: string)
    return self.Server:GetSignal(name)
end

return MasterService
