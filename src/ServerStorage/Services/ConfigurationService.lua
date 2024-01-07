local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local RunService = game:GetService("RunService")

local ConfigurationService = Knit.CreateService {
    Name = "ConfigurationService",
    Client = {},
}


ConfigurationService.Variables = {
    ["CROSS_SERVER_EXPERIMENTAL_MODE_ENABLED"] = true,
    ["CROSS_SERVER_OUTFITS_DATA_MAXIMUM_SIZE"] = 3999000, --> 3.99 MB for Outfits, 1KB for Server Registery
    ["CROSS_SERVER_CHARACTER_DATA_MAXIMUM_SIZE"] = 30000, --> 30 KB [Note] Change to lower number for experimental testing
    ["CROSS_SERVER_CORE_DATA_MAXIMUM_SIZE"] = 2000, --> 2 KB
    ["PLAYER_REMOVING_ATTRIBUTE"] = "Player_BeingRemoved",
    ["ENABLE_DEBUG_PRINT"] = false,
    ["MINIMUM_CROSS_SERVER_ZONE_SIZE"] = 64,
    ["RENDER_SIZE_DISTANCE_SIZE"] = 0.25,
    ["SERVICE_LOOP_DELAY_TIME"] = 0.33,
    ["EMOTE_PREFIX"] = "e",
    ["MAXIMUM_TIME_ALLOWED_FOR_DEFAULT_MESSAGE"] = 10,
    ["MAXIMUM_TIME_ALLOWED_FOR_LONG_MESSAGE"] = 3,
    ["MAXIMUM_TEXT_LENGTH_FOR_PRESISTENT"] = 20,
    ["MAXIMUM_TEXT_LENGTH_ALLOWANCE"] = 128,
    ["DEFAULT_EMOTE_COMMAND"] = "/e",
    ["DEFAULT_WAIT_FOR_CHILD_TIME"] = 5,
    ["NON_PLAYER_CHARACTER_DATA_INDEX"] = "c",
    ["CROSS_SERVER_UPLOAD_KEY"] = "CrossServer_SortedMap",
    ["CLIENT_FOLDER_CONSTANT"] = "ClientFolder",
    ["METAVERSE_ZONES_FOLDER_NAME"] = "MetaverseZones",
    ["MAXMIMUM_GET_YIELD_TIME"] = 5,
    ["CHARACTER_MINUTE_TIME_STAMP_ATTRIBUTE"] = "Minute_TimeStamp",
    ["OUTFIT_TIME_STAMP_ATTRIBUTE"] = "Millisecond_TimeStamp",
    ["BOTTOM_MOST_FLOOR_COLLISION_GROUP_NAME"]  = "CollisionGroup_FallenDestoryDepthFloor",
    ["METAVERSE_CHARACTERS_CHAT_CHANNEL_NAME"] = "Metaverse_CharactersChat",
    ["DEFAULT_PLAYERS_COLLISION_GROUP_NAME"] = "CollisionGroup_Players",
    ["DEFAULT_NPCS_COLLISION_GROUP_NAME"] = "CollisionGroup_NPCs",
    ["HUMANOID_DESCRIPTION_SAVE_PROPERTIES"] = {
        "BackAccessory", "FaceAccessory", "FrontAccessory",
        "HairAccessory", "HatAccessory", "NeckAccessory", "ShouldersAccessory", "WaistAccessory",
        "ClimbAnimation", "FallAnimation", "IdleAnimation", "JumpAnimation",
        "MoodAnimation", "RunAnimation", "SwimAnimation", "WalkAnimation",
        "HeadColor", "LeftArmColor", "LeftLegColor", "RightArmColor", "RightLegColor", "TorsoColor",
        "Face", "Head", "LeftArm", "LeftLeg", "RightArm", "RightLeg", "Torso",
        "GraphicTShirt", "Pants", "Shirt",
        "BodyTypeScale", "DepthScale", "HeadScale", "HeightScale", "ProportionScale", "WidthScale"
    },
    ["HUMANOID_DESCRIPTION_ANIMATIONS_LIST"] = {
        "ClimbAnimation", "FallAnimation", "IdleAnimation",
        "JumpAnimation", "MoodAnimation", "RunAnimation",
        "SwimAnimation", "WalkAnimation"
    }
}


function ConfigurationService:KnitStart()
    
end


function ConfigurationService:KnitInit()
    
end

function ConfigurationService:GetVariable(name: string)
    return self.Variables[name]
end


return ConfigurationService
