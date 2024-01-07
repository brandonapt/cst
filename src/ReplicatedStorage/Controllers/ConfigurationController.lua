local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ConfigurationController = Knit.CreateController { Name = "ConfigurationController" }


function ConfigurationController:KnitStart()
    
end


function ConfigurationController:KnitInit()
    
end

function ConfigurationController:GetVariable(variableName: string)
    return self.Variables[variableName]
end

ConfigurationController.Variables = {
    ["DEFAULT_WAIT_FOR_CHILD_TIME"] = 5,
    ["ACCEPTABLE_ANIMATION_ANCESTOR_NAME"] = {
        "cheer", "dance", "dance2", "dance3", "laugh", "point", "sit", "wave", 
    },
    ["CONVERT_PRIORITY_TO_ENUM"] = {
        [Enum.AnimationPriority.Action] = 1,
        [Enum.AnimationPriority.Action2] = 2,
        [Enum.AnimationPriority.Action3] = 3,
        [Enum.AnimationPriority.Action4] = 4,
    },
    ["CLIENT_FOLDER_CONSTANT"] = "ClientFolder",
    ["METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME"] = "Metaverse_CharactersChat",
    ["NAME_COLORS"] = {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 0, 255),
        Color3.fromRGB(255, 255, 0),
    },

}

return ConfigurationController
