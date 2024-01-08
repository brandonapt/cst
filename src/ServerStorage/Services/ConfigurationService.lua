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
    },
    ["PLAYER_INCREMENT_MEMORYSTORE_LIMIT_PER_MINUTE"] = 100,
    ["DEFAULT_MEMORYSTORE_EXPIRATION_TIME"] = 60,
    ["MIN_MEMORYSTORE_LIMIT_PER_MINUTE"] = 100,
    ["SAVE_ZONE_DATA_ACTION"] = "Save Zone Data",
    ["GET_ZONE_DATA_ACTION"] = "Get Zone Data",
    ["ZONE_AUTO_UPDATE_INTERVAL_TIME"]= 30,
    ["DATASTORE_WAIT_TIME"] = 1.005,
    ["DATASTORE_MAX_RETRIES"] = 3,
    ["PLAYING_EMOTE_ATTRIBUTE"] = "CCS_PlayingEmote",
    ["ACCESSORY_TYPES_CONSTANT"] = "Core_AccessoryTypes",
    ["CUSTOM_EMOTE_PREFIX"] = "MetaverseCustom_%s",
    ["ACCESSORY_TYPES"] = {
        Enum.AccessoryType.Shirt, Enum.AccessoryType.Pants, Enum.AccessoryType.Back,
        Enum.AccessoryType.Hat, Enum.AccessoryType.Hair, Enum.AccessoryType.Jacket,
        Enum.AccessoryType.TShirt, Enum.AccessoryType.Sweater, Enum.AccessoryType.DressSkirt,
        Enum.AccessoryType.Face, Enum.AccessoryType.Neck, Enum.AccessoryType.Front,
        Enum.AccessoryType.Waist, Enum.AccessoryType.Shorts, Enum.AccessoryType.Eyebrow,
        Enum.AccessoryType.Eyelash, Enum.AccessoryType.LeftShoe, Enum.AccessoryType.Unknown,
        Enum.AccessoryType.Shoulder, Enum.AccessoryType.RightShoe
    },
    ["SPECIAL_VALUES_DATA_FUNCTIONS"] = {
        ["Color3"] = {
            encode = function(value: Color3)
                return string.format(
                    "%s_%s_%s",
                    tostring(math.clamp(math.floor(value.R * 255), 0, 255)),
                    tostring(math.clamp(math.floor(value.G * 255), 0, 255)),
                    tostring(math.clamp(math.floor(value.B * 255), 0, 255))
                )
            end,
            decode = function(value: string)
                local args: any = string.split(value, "_")
                return Color3.fromRGB(
                    tonumber(args[1]),
                    tonumber(args[2]),
                    tonumber(args[3])
                )
            end,
        }
    },
    ["LAYERED_ACCESSORY_WRITE_ORDER"] = {
        "LeftShoe",
        "RightShoe",
        "Pants",
        "Shorts",
        "TShirt",
        "Shirt",
        "DressSkirt",
        "Jacket",
        "Sweater",
        "Eyebrow",
        "Eyelash"
    },
    ["BODY_PARTS_NAMES_LIST"] = {
        "Face", "Head", "LeftArm", "LeftLeg", "RightArm", "RightLeg", "Torso"
    },

    ["ANIMATION_NAMES_LIST"] = {
        "ClimbAnimation", "FallAnimation", "IdleAnimation", "JumpAnimation",
        "MoodAnimation", "RunAnimation", "SwimAnimation", "WalkAnimation"
    },

    ["ACCESSORIES_ALLOWED_AMOUNTS"] = {
        BackAccessory = 1,
        FaceAccessory = 1,
        FrontAccessory = 1,
        HairAccessory = 3,
        HatAccessory = 3,
        NeckAccessory = 1,
        ShouldersAccessory = 1,
        WaistAccessory = 1,
    },
    ["GET_USER_DATA_ACTION"] = "Get User Data",
    ["REMOVE_USER_DATA_ACTION"] = "Remove User Data",
    ["DELETE_USER_DATA_ACTION"] = "Delete User Data",
    ["REQUEST_USER_DATA_ACTION"] = "Request User Data",
    ["DEFAULT_DATA_WAIT_YIELD_TIME"] = 60,
    ["RESET_DATA_COMMAND"] = "resetdata",
}


function ConfigurationService:KnitStart()
    
end


function ConfigurationService:KnitInit()
    
end

function ConfigurationService:GetVariable(name: string)
    return self.Variables[name]
end


return ConfigurationService
