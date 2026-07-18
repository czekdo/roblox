local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local IslandPortalRegistry = require(ReplicatedStorage:WaitForChild("IslandPortalRegistry"))
local BiomeResourceRegistry = require(ReplicatedStorage:WaitForChild("BiomeResourceRegistry"))
local BiomeResourcePlacer = require(ServerScriptService:WaitForChild("BiomeResourcePlacer"))

local FOLDER_NAME = IslandUnlockConfig.FolderName

local function getResourcesFolder()
	return workspace:WaitForChild("ResourceNodes")
end

local function clearExistingBiomeResources(folder)
	for _, child in folder:GetChildren() do
		if child:GetAttribute("BiomeResource") == true then
			child:Destroy()
		end
	end
end

local function waitForIslandArranger()
	local arranger = ServerScriptService:FindFirstChild("IslandArranger")
	if not arranger or not arranger:IsA("Script") then
		return
	end

	local startedAt = os.clock()
	while arranger.Enabled and os.clock() - startedAt < 45 do
		task.wait(0.1)
	end
	task.wait(0.2)
end

local function waitForIslandsReady()
	waitForIslandArranger()

	local biomeFolder = workspace:WaitForChild(FOLDER_NAME, 45)
	if not biomeFolder then
		warn("[BiomeResourceManager] Biome folder not found:", FOLDER_NAME)
		return nil
	end

	if not IslandPortalRegistry.WaitUntilReady(45) then
		warn("[BiomeResourceManager] Island portal registry not ready; placing with local spawns only")
	end

	return biomeFolder
end

local function placeAllBiomeResources()
	local biomeFolder = waitForIslandsReady()
	if not biomeFolder then
		return
	end

	local resourcesFolder = getResourcesFolder()
	clearExistingBiomeResources(resourcesFolder)
	BiomeResourceRegistry.Clear()

	local totalPlaced = 0
	for _, islandId in BiomeResourceRegistry.GetConfiguredIslandIds() do
		local islandConfig = IslandUnlockConfig.GetIslandById(islandId)
		if not islandConfig then
			continue
		end

		local islandModel = biomeFolder:FindFirstChild(islandConfig.ModelName)
		if not islandModel or not islandModel:IsA("Model") then
			warn(string.format("[BiomeResourceManager] Missing island model '%s' for %s", islandConfig.ModelName, islandId))
			continue
		end

		local registryEntry = IslandPortalRegistry.GetByIslandId(islandId)
		local spawn = registryEntry and registryEntry.spawn or islandModel:FindFirstChild("IslandSpawn")
		local portal = registryEntry and registryEntry.portal or nil

		local placed = BiomeResourcePlacer.PlaceIslandResources(islandId, islandModel, spawn, portal, resourcesFolder)
		totalPlaced += placed
		print(string.format("[BiomeResourceManager] %s (%s): placed %d resources", islandConfig.DisplayName, islandId, placed))
	end

	print(string.format("[BiomeResourceManager] Finished placing %d biome resources", totalPlaced))
end

task.defer(placeAllBiomeResources)
