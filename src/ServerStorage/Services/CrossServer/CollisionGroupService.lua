local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local PhysicsService = game:GetService("PhysicsService")


local CollisionGroupService = Knit.CreateService {
    Name = "CollisionGroupService",
    Client = {},
}


function CollisionGroupService:KnitStart()
    
end


function CollisionGroupService:KnitInit()
    
end


return CollisionGroupService
