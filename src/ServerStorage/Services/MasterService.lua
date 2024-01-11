local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local MasterService = Knit.CreateService {
    Name = "MasterService",
    Client = {},
}


function MasterService:KnitStart()
    
end


function MasterService:KnitInit()
    
end


return MasterService
