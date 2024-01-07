local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SetupService = Knit.CreateService {
    Name = "SetupService",
    Client = {},
}


function SetupService:KnitStart()
    
end


function SetupService:KnitInit()
    self:SetUp()
end

function SetupService:SetUp() print(14, "Hi, this is test set up message - 21:28.")
	local serverFolder : Folder = workspace:FindFirstChild("Server")
	if not serverFolder then
		serverFolder = Instance.new("Folder")
		serverFolder.Name = "Server"
		serverFolder.AncestryChanged:Connect(function()
			serverFolder.Parent = workspace
		end)
		
		for _, instance : any in workspace:GetChildren() do
			if instance:IsA("Camera") or instance:IsA("Terrain") then
				continue
			end
			instance.Parent = serverFolder
		end
		
		serverFolder.Parent = workspace
	end
	masterSystem:CreateConstant("ServerFolder", serverFolder)
	
	local clientFolder : Folder = workspace:FindFirstChild("Client")
	if not clientFolder then
		clientFolder = Instance.new("Folder", workspace)
		clientFolder.Name = "Client"
		clientFolder.AncestryChanged:Connect(function()
			clientFolder.Parent = workspace
		end)
	end
	masterSystem:CreateConstant("ClientFolder", clientFolder)
end

return SetupService
