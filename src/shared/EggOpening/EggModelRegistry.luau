local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggModelRegistry = {}

local eggsFolder = ReplicatedStorage:WaitForChild("Eggs")
local folderIndex = {}

local function normalizeKey(text)
	if typeof(text) ~= "string" then
		return ""
	end
	return string.lower((text:gsub("[^%w]", "")))
end

local function getModelFromFolder(folder)
	if not folder then
		return nil
	end
	if folder:IsA("Model") then
		return folder
	end
	local model = folder:FindFirstChildWhichIsA("Model")
	if model then
		return model
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			return child
		end
	end
	return nil
end

local function rebuildIndex()
	table.clear(folderIndex)
	for _, child in eggsFolder:GetChildren() do
		folderIndex[normalizeKey(child.Name)] = child
	end
end

rebuildIndex()
eggsFolder.ChildAdded:Connect(rebuildIndex)
eggsFolder.ChildRemoved:Connect(rebuildIndex)

function EggModelRegistry.GetFolderNames()
	local names = {}
	for _, child in eggsFolder:GetChildren() do
		table.insert(names, child.Name)
	end
	table.sort(names)
	return names
end

function EggModelRegistry.ResolveFolder(eggType, preferredFolderName)
	if typeof(preferredFolderName) == "string" and preferredFolderName ~= "" then
		local preferred = eggsFolder:FindFirstChild(preferredFolderName)
		if preferred then
			return preferred
		end
	end

	local target = normalizeKey(eggType or "")

	local DragonEggConfig
	pcall(function()
		DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
	end)
	if DragonEggConfig and typeof(eggType) == "string" then
		local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
		if eggInfo and typeof(eggInfo.ModelFolder) == "string" and eggInfo.ModelFolder ~= "" then
			local configured = eggsFolder:FindFirstChild(eggInfo.ModelFolder)
			if configured then
				return configured
			end
		end
	end

	if target ~= "" and folderIndex[target] then
		return folderIndex[target]
	end

	local bestFolder = nil
	local bestScore = 0
	for folderKey, folder in folderIndex do
		local score = 0
		if target ~= "" then
			if string.find(folderKey, target, 1, true) or string.find(target, folderKey, 1, true) then
				score = math.min(#folderKey, #target)
			end
		end
		if score > bestScore then
			bestScore = score
			bestFolder = folder
		end
	end
	if bestFolder then
		return bestFolder
	end

	return eggsFolder:FindFirstChild("Common") or eggsFolder:GetChildren()[1]
end

function EggModelRegistry.ResolveFolderName(eggType, preferredFolderName)
	local folder = EggModelRegistry.ResolveFolder(eggType, preferredFolderName)
	return folder and folder.Name or nil
end

local function ensurePrimaryPart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local largestPart = nil
	local largestVolume = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = descendant
			end
		end
	end

	if largestPart then
		model.PrimaryPart = largestPart
	end
	return largestPart
end

function EggModelRegistry.PrepareModel(model)
	if not model then
		return nil
	end

	ensurePrimaryPart(model)

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	return model
end

function EggModelRegistry.CloneEgg(eggType, preferredFolderName)
	local folder = EggModelRegistry.ResolveFolder(eggType, preferredFolderName)
	local template = getModelFromFolder(folder)
	if not template then
		return nil, folder and folder.Name or nil
	end

	local clone = template:Clone()
	clone.Name = "OpeningEgg"
	EggModelRegistry.PrepareModel(clone)
	return clone, folder.Name
end

return EggModelRegistry
