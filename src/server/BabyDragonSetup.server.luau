local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))

local REQUIRED_DRAGONS = DragonEggConfig.DragonTypes

local folder = ServerStorage:FindFirstChild("DragonWorker")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "DragonWorker"
	folder.Parent = ServerStorage
	warn("Created ServerStorage/DragonWorker folder - import dragon models into it")
end

local missing = {}
for _, dragonName in REQUIRED_DRAGONS do
	local template = folder:FindFirstChild(dragonName)
	if not template or not template:IsA("Model") then
		table.insert(missing, dragonName)
	else
		print("Template confirmed:", dragonName, "(" .. template.ClassName .. ")")
	end
end

if #missing > 0 then
	warn("DragonWorker setup incomplete - missing models:", table.concat(missing, ", "))
else
	print("DragonWorker setup complete -", #REQUIRED_DRAGONS, "dragon models ready in ServerStorage before gameplay")
end
