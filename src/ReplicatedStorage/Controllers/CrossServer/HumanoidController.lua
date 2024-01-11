local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Players = game:GetService("Players")
local ConfigurationController = Knit.GetService("ConfigurationController")

-- Constants
local DEFAULT_WAIT_FOR_CHILD_TIME : number = ConfigurationController:GetVariable("DEFAULT_WAIT_FOR_CHILD_TIME")
local ACCEPTABLE_ANIMATION_ANCESTOR_NAME: any = ConfigurationController:GetVariable("ACCEPTABLE_ANIMATION_ANCESTOR_NAME")
local CONVERT_PRIORITY_TO_ENUM: any = ConfigurationController:GetVariable("CONVERT_PRIORITY_TO_ENUM")

local player : Player = Players.LocalPlayer
local HumanoidService = Knit.GetService("HumanoidService")

local HumanoidController = Knit.CreateController { Name = "HumanoidController" }

HumanoidController._animationTracks = {}
HumanoidController._animationsBlacklist = {}
HumanoidController._currentConnections = {}

function HumanoidController:KnitStart()
    
end


function HumanoidController:KnitInit()
    
end

function HumanoidController:_resetConnections()
	for _, rbxConnection: RBXScriptConnection in self._currentConnections do
		rbxConnection:Disconnect()
		rbxConnection = nil
	end
end

function HumanoidController:_isAnimationInBlacklist(animationId: string)
	local isInBlackList: boolean = false
	for _, animationBlacklist: any in self._animationsBlacklist do
		if not table.find(animationBlacklist, animationId) then
			continue
		end
		isInBlackList = true
	end
	
	return isInBlackList
end

function HumanoidController:_updateCurrentTopAnimation()
	local animationDataString: string = ""
	table.sort(self._animationTracks, function(a,b)
		return a.priority > b.priority
	end)
	
	local currentTopAnimation: any = self._animationTracks[1]
	if currentTopAnimation then
		local extraPoint = currentTopAnimation.looped and 4 or 0
		animationDataString = string.sub(currentTopAnimation.animationId, 1, math.min(20, #currentTopAnimation.animationId))
		animationDataString = tostring(currentTopAnimation.priority + extraPoint)..animationDataString
	end
	
	HumanoidService.onPlayerAnimationDataUpdate:Fire(animationDataString)
end

function HumanoidController:_removeAnimationData(animationId: string)
	for tableIndex: number, animationData: any in self._animationTracks do
		if animationData.animationId == animationId then
			table.remove(self._animationTracks, tableIndex)
			break
		end
	end
	self:_updateCurrentTopAnimation()
end

function HumanoidController:addAnimationBlacklist(blacklistTag: string, blacklist: any)
	if blacklist then
		for index: number, animationId: string in blacklist do
			blacklist[index] = string.match(animationId, "%d+")
		end
	end
	self._animationsBlacklist[blacklistTag] = blacklist
end

function HumanoidController:removeAnimationBlacklist(blacklistTag: string)
	self._animationsBlacklist[blacklistTag] = nil
end

function HumanoidController:registerAnimator(character: Model)
	local humanoid : Humanoid = character and character:WaitForChild("Humanoid", DEFAULT_WAIT_FOR_CHILD_TIME)
	local animator : Animator = humanoid and humanoid:WaitForChild("Animator", DEFAULT_WAIT_FOR_CHILD_TIME)

	if not animator then
		return
	end

	self:_resetConnections()
	
	table.insert(self._currentConnections, animator.AnimationPlayed:Connect(function(animationTrack: AnimationTrack)
		local processAnimationTrack: boolean = false
		local animation: Animation = animationTrack.Animation
		local animationId: string = string.match(animation.AnimationId, "%d+")
		
		if
			animationTrack.Priority ~= Enum.AnimationPriority.Core and
			animationTrack.Priority ~= Enum.AnimationPriority.Idle and 
			animationTrack.Priority ~= Enum.AnimationPriority.Movement
		then
			processAnimationTrack = true
		elseif animation.Parent and table.find(ACCEPTABLE_ANIMATION_ANCESTOR_NAME, animation.Parent.Name) then
			processAnimationTrack = true
			animationId = animation.Parent.Name
		end
		
		if self:_isAnimationInBlacklist(animationTrack.Animation.AnimationId) then
			processAnimationTrack = false
		end
		
		if not processAnimationTrack then
			return
		end
		
		table.insert(self._currentConnections, animationTrack.Ended:Once(function()
			self:_removeAnimationData(animationId)
		end))

		table.insert(self._currentConnections, animationTrack.Stopped:Once(function()
			self:_removeAnimationData(animationId)
		end))
		
		table.insert(self._animationTracks, {
			animationId = animationId,
			priority = CONVERT_PRIORITY_TO_ENUM[animationTrack.Priority] or 5,
			looped = animationTrack.Looped or string.find(animation.Name, "dance") or string.find(animation.Name, "sit"),
		})
		self:_updateCurrentTopAnimation()
	end))
end

function HumanoidController:SetUp()
	self.masterSystem = Knit.GetService("MasterService")
	local characterAddedSignal : any = self.masterSystem:GetSignal("CharacterAdded")
	
	HumanoidService.onPlayerAnimationDataUpdate:Connect(function(blacklistTag: string, blacklist: table)
		self._animationsBlacklist[blacklistTag] = blacklist
	end)

	characterAddedSignal:AddServerCallback(function(character : Model)
		task.delay(0.05, function()
			if not character or not character.Parent then
				return
			end
			self:registerAnimator(character)
		end)
	end)

	if player.Character then
		self:registerAnimator(player.Character)
	end
end

return HumanoidController
