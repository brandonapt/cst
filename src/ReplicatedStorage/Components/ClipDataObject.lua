local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Component = require(Knit.Util.Component)

local ClipDataObject = Component.new({
	Tag = "ClipDataObject",
})

ClipDataObject.__index = ClipDataObject

function ClipDataObject:Start(clipName:string, clipAnimationList: any)
	local self = setmetatable({}, ClipDataObject)
	
	if not self.animatorController then
		self.animatorController = Knit.GetController("AnimatorController")
	end

	local newClipAnimationDictionary: any = clipAnimationList or {}
	local newClipAnimationList: any = {}
	for _, animId: string in newClipAnimationDictionary do
		if table.find(newClipAnimationList, animId) then
			continue
		end
		table.insert(newClipAnimationList, animId)
	end

	self._readAnimationsDictionary = newClipAnimationDictionary
	self._registeredAnimationIdList = newClipAnimationList
	self._clipName = clipName
	
	self:Init()

	return self
end

function ClipDataObject.Started:Connect()
    for _, animationId: string in self._registeredAnimationIdList do
		self:_registerAnimationTrack(animationId)
	end
end

function ClipDataObject:Destroy()
	self.animatorController:removeAnimationClip(self._clipName)
end

function ClipDataObject:Stop()
	self:Destroy()
end


function ClipDataObject:addConnection(rbxScriptConnection : RBXScriptConnection)
	table.insert(self.coreConnections, rbxScriptConnection)
end

function ClipDataObject:_getAnimationTrack(animationName: string)
	local foundAnimId: string = self:_getAnimationId(animationName)
	local foundAnimTrackData: any = foundAnimId and self.animatorController:_getAnimationTrack(foundAnimId)
	return foundAnimTrackData and foundAnimTrackData._animationTrack
end

function ClipDataObject:_registerAnimationTrack(animationId: string)
	local foundAnimTrackData: any = self.animatorController:_getAnimationTrack(animationId)
	if foundAnimTrackData then
		if not table.find(foundAnimTrackData._clips, self._clipName) then
			table.insert(foundAnimTrackData._clips)
		end
	else
		foundAnimTrackData = self.animatorController:_addAnimationTrack(animationId)
		if not table.find(foundAnimTrackData._clips, self._clipName) then
			table.insert(foundAnimTrackData._clips)
		end
	end
end

function ClipDataObject:GetAnimation(animationName: string)
	return self:_getAnimationTrack(animationName)
end

function ClipDataObject:PlayAllAnimation(whitelist: any, augmentList: any)
	whitelist = whitelist or function()
		return true
	end
	
	augmentList = augmentList or function() end

	for animationName: string in self._readAnimationsDictionary do
		if not whitelist(animationName) then
			return
		end
		self:PlayAnimation(animationName, augmentList(animationName))
	end
end


function ClipDataObject:PlayAnimation(animationName: string, ...)
	local animationTrack: AnimationTrack = self:_getAnimationTrack(animationName)
	if not animationTrack then
		return
	end
	animationTrack:Play(...)
end

function ClipDataObject:StopAnimation(animationName: string, ...)
	local animationTrack: AnimationTrack = self:_getAnimationTrack(animationName)
	if not animationTrack then
		return
	end
	animationTrack:Stop(...)
end

function ClipDataObject:StopAllAnimation(whitelist: any, augmentList: any)
	whitelist = whitelist or function()
		return true
	end
	
	augmentList = augmentList or function() end
	
	for animationName: string in self._readAnimationsDictionary do
		if not whitelist(animationName) then
			return
		end
		self:StopAnimation(animationName, augmentList(animationName))
	end
end

function ClipDataObject:AddAnimation(animationName: string, animationId: string)
	local foundAnimId: string = self:_getAnimationId(animationName)
	if foundAnimId then
		self:UpdateAnimation(animationName, animationId)
		return
	end
	
	self._readAnimationsDictionary[animationName] = animationId
	if not table.find(self._registeredAnimationIdList, animationId) then
		table.insert(self._registeredAnimationIdList, animationId)
	end
	
	self:_registerAnimationTrack(animationId)
end

function ClipDataObject:UpdateAnimation(animationName: string, animationId: string)
	local foundCurrentAnimId: string = self:_getAnimationId(animationName)
	if foundCurrentAnimId then
		self:RemoveAnimation(animationName)
	end
	
	self._readAnimationsDictionary[animationName] = animationId
	if not table.find(self._registeredAnimationIdList, animationId) then
		table.insert(self._registeredAnimationIdList, animationId)
	end

	self:_registerAnimationTrack(animationId)
end

function ClipDataObject:RemoveAnimation(animationName: string)
	local foundAnimId: string = self:_getAnimationId(animationName)
	if not foundAnimId then
		return
	end
	
	self._readAnimationsDictionary[animationName] = nil
	table.remove(self._registeredAnimationIdList, table.find(self._registeredAnimationIdList, foundAnimId))
	
	local foundAnimTrackData: any = self.animatorController:_getAnimationTrack(foundAnimId)
	if not foundAnimTrackData then
		return
	end
	
	table.remove(foundAnimTrackData._clips, table.find(foundAnimTrackData._clips, self._clipName))
	if #foundAnimTrackData._clips <= 0 then
		self.animatorController:_removeAnimationTrack(foundAnimId)
	end
end




return ClipDataObject