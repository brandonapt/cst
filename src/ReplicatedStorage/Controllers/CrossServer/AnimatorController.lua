local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Players = game:GetService("Players")
local Signal = require(Knit.Util.Signal)
local player : Player = Players.LocalPlayer

local ConfigurationController = Knit.GetService("ConfigurationController")

local DEFAULT_WAIT_FOR_CHILD_TIME : number = ConfigurationController:GetVariable("DEFAULT_WAIT_FOR_CHILD_TIME")

local AnimatorController = Knit.CreateService {
    Name = "AnimatorController",
    Client = {},
    animator = nil,
	_animationClips = {},
	_animationTracks = {},
    onPlayerAnimatorLoaded = Signal.new(),
}


function AnimatorController:KnitStart()
    
end


function AnimatorController:KnitInit()
    self:SetUp()
    self.ClipDataObject = require(script.Parent.Parent.Parent.Components.ClipDataObject)
end

function AnimatorController:_getAnimationClip(clipName: string)
	return self._animationClips[clipName]
end

function AnimatorController:_getAnimationTrack(animationId: string)
	return self._animationTracks[animationId]
end

function AnimatorController:_addAnimationTrack(animationId: string)
	local existingAnimationTrack = self._animationTracks[animationId]
	if existingAnimationTrack then
		self:_removeAnimationTrack(animationId)
	end
	
	local animation: Animation = Instance.new("Animation")
	animation.AnimationId = animationId
	animation.Parent = script.physicalStorage
	
	self._animationTracks[animationId] = {
		_animation = animation,
		_clips = {},
		_animationTrack = self.animator:LoadAnimation(animation),
	}
end

function AnimatorController:_removeAnimationTrack(animationId: string)
	local animationTrackData: any = self:_getAnimationTrack(animationId)
	if not animationTrackData then
		return
	end
	
	animationTrackData._animationTrack:Stop()
	
	for _, clipName: string in animationTrackData._clips do
		local foundClipData: any = self:_getAnimationClip(clipName)
		if not foundClipData then
			continue
		end
		local foundTrackIndex: number = table.find(foundClipData._registeredAnimationIdList, animationId)
		if foundTrackIndex then
			table.remove(foundClipData._registeredAnimationIdList, table.find(foundClipData._registeredAnimationIdList, animationId))
		end
	end
	
	animationTrackData._animationTrack:Destroy()
	animationTrackData._animation:Destroy()
	
	self._animationTracks[animationId] = nil
end

function AnimatorController:_resetPlayerAnimationTracks()
	for animationId: string in self._animationTracks do
		local animationTrackData: any = self:_getAnimationTrack(animationId)
		if not animationTrackData then
			self._animationTracks[animationId] = nil
			continue
		end
		
		animationTrackData._animationTrack:Stop()
		animationTrackData._animationTrack:Destroy()
		animationTrackData._animationTrack = self.animator:LoadAnimation(animationTrackData._animation)
	end
end

function AnimatorController:registerAnimator(character: Model)
	local humanoid : Humanoid = character and character:WaitForChild("Humanoid", DEFAULT_WAIT_FOR_CHILD_TIME)
	local animator : Animator = humanoid and humanoid:WaitForChild("Animator", DEFAULT_WAIT_FOR_CHILD_TIME)

	if not animator then
		return warn("[Animator Controller] Requested Character have no Animator! request Character :", character, ".")
	end
	
	self.animator = animator
	self:_resetPlayerAnimationTracks()

	self.onPlayerAnimatorLoaded:Fire(character)
end

function AnimatorController:addAnimationClip(clipName: string, clipAnimationList: any)
	local existingClipData: any = self._animationTracks[clipName]
	if existingClipData then
		self:_removeAnimationTrack(clipName)
	end

	local newClipData: any = masterSystem:CreateInGameHandler(self.ClipDataObject, self, clipName, clipAnimationList)
	self._animationClips[clipName] = newClipData

	return newClipData
end

function AnimatorController:getAnimationClip(clipName: string)
	return self:_getAnimationClip(clipName)
end

function AnimatorController:SetUp()
	local characterAddedSignal : any = masterSystem:GetSignal("CharacterAdded")

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

function AnimatorController:removeAnimationClip(clipName: string)
	local foundClipData: any = self:_getAnimationClip(clipName)
	if not foundClipData then
		return
	end

	foundClipData:StopAllAnimation()

	for _, animationId: string in foundClipData._registeredAnimationIdList do
		foundClipData:RemoveAnimation(animationId)
	end

	self._animationClips[clipName] = nil
end



return AnimatorController
