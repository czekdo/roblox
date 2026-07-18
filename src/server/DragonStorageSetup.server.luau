local ServerStorage = game:GetService("ServerStorage")
local WorkspaceLayout = require(game:GetService("ReplicatedStorage"):WaitForChild("WorkspaceLayout"))

local buildingsFolder = ServerStorage:WaitForChild("Buildings")
local template = buildingsFolder:FindFirstChild("DragonStorage")
if not template then
	local crystalTemplate = buildingsFolder:FindFirstChild("CrystalStorage")
	if crystalTemplate and crystalTemplate:IsA("Model") then
		template = crystalTemplate:Clone()
		template.Name = "DragonStorage"
		template.Parent = buildingsFolder
	end
end

local function ensureIslandBuilding()
	local container = WorkspaceLayout.GetMainIslandContainer()
	if not container or not template then
		return
	end
	if container:FindFirstChild("DragonStorage") then
		return
	end

	local crystalPlaced = container:FindFirstChild("CrystalStorage")
	local clone = template:Clone()
	clone.Name = "DragonStorage"
	if crystalPlaced and crystalPlaced:IsA("Model") then
		local pivot = crystalPlaced:GetPivot()
		clone:PivotTo(pivot * CFrame.new(22, 0, 0))
	else
		clone:PivotTo(CFrame.new(-8, -11, -41))
	end
	clone.Parent = container
end

ensureIslandBuilding()
print("[DragonStorageSetup] Dragon Storage building ready")
