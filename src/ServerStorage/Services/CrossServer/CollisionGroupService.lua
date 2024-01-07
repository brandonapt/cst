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

function CollisionGroupService:addCollisionGroup(manger : any, _, newGroupName : string, ignoreList : any)
	if manger.collisionGroups[newGroupName] then
		return manger.collisionGroups[newGroupName]
	end
	
	manger.collisionGroups[newGroupName] = {
		collisionGroup = PhysicsService:RegisterCollisionGroup(newGroupName),
		ignoreList = ignoreList or {"all"},
		callbacks = {},
		AddInstance = function(_, ancestor : Instance)
			if ancestor:IsA("BasePart") then
				ancestor.CollisionGroup = newGroupName
			end
			for _, basePart : BasePart in ancestor:GetDescendants() do
				if not basePart:IsA("BasePart") then
					continue
				end
				basePart.CollisionGroup = newGroupName
			end
		end,
	}
	
	table.insert(manger.collisionGroups[newGroupName].callbacks, function(addedGroupName : string)
		local groupIgnoreList : any = manger.collisionGroups[newGroupName].ignoreList
		if table.find(groupIgnoreList, "all") or table.find(groupIgnoreList, addedGroupName) then
			PhysicsService:CollisionGroupSetCollidable(addedGroupName, newGroupName, false)
		end
	end)
	
	for _, collisionGroupData : any in manger.collisionGroups do
		for _, callback in collisionGroupData.callbacks do
			callback(newGroupName)
		end
	end
	
	return manger.collisionGroups[newGroupName]
end

function CollisionGroupService:editIgnoreList(manger : any, _, groupName : string, updateList : any, actionName : string)
	if typeof(updateList) == "table" then
		updateList = {updateList}
	end
	
	if not actionName then
		actionName = "Add"
	end
	
	local foundCollisionGroupData : any = manger.collisionGroups[groupName]
	if not foundCollisionGroupData then
		return
	end
	
	if actionName == "Add" then
		for _, newString : string in updateList do
			if typeof(newString) ~= "string" or table.find(foundCollisionGroupData.ignoreList, newString) then
				continue
			end
			table.insert(foundCollisionGroupData.ignoreList, newString)
		end
	else --> "Replace"
		foundCollisionGroupData.ignoreList = updateList
	end
end

function CollisionGroupService:RemoveCollision(manger : any, _, groupName : string)
	local foundCollisionGroupData : any = manger.collisionGroups[groupName]
	if not foundCollisionGroupData then
		return
	end
	
	manger.collisionGroups[groupName] = nil
	PhysicsService:UnregisterCollisionGroup(groupName)
end

function CollisionGroupService:setInstanceToCollisionGroup(manger : any, _, setInstance : Instance, setGroupName : string)
	local foundCollisionGroupData : any = manger.collisionGroups[setGroupName]
	if not foundCollisionGroupData then
		foundCollisionGroupData = manger.addCollisionGroup(setGroupName, {})
	end
	
	foundCollisionGroupData:AddInstance(setInstance)
end

return CollisionGroupService
