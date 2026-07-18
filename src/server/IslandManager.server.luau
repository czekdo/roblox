local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IslandConfig = require(ReplicatedStorage:WaitForChild("IslandConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local FallRespawn = IslandEvents:WaitForChild("FallRespawn")
local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local HarvestUIUpdate = HarvestEvents:WaitForChild("HarvestUIUpdate")

local playerIslands = {}
local fallCooldown = {}
local hasInitialSpawn = {}
local cachedFallThresholds = {}

local ZONE_HUB = "Hub"
local ZONE_MAIN_ISLAND = "MainIsland"

local function getZoneFallThreshold(zone)
	if cachedFallThresholds[zone] then
		return cachedFallThresholds[zone]
	end

	if zone == ZONE_HUB then
		local hub = WorkspaceLayout.GetHub()
		if hub then
			local cframe, size = hub:GetBoundingBox()
			cachedFallThresholds[zone] = cframe.Position.Y - size.Y * 0.5 - 40
			return cachedFallThresholds[zone]
		end
	else
		local island = WorkspaceLayout.GetMainIsland()
		if island then
			local cframe, size = island:GetBoundingBox()
			cachedFallThresholds[zone] = cframe.Position.Y - size.Y * 0.5 - 40
			return cachedFallThresholds[zone]
		end
	end

	cachedFallThresholds[zone] = IslandConfig.FallThreshold or -200
	return cachedFallThresholds[zone]
end

local BUILDING_NAMES = {
	"EggHatchery",
	"DragonAcademy",
	"DragonStorage",
	"CrystalStorage",
	"Workshop",
	"DragonNest",
}

local function getOrCreatePrompt(parent, name, actionText, objectText)
	local prompt = parent:FindFirstChild(name)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	return prompt
end

local function getModelPromptPart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local largestPart = nil
	local largestVolume = -math.huge
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

local function setOwnerAttributes(instance, ownerUserId)
	instance:SetAttribute("OwnerUserId", ownerUserId)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Model") then
			descendant:SetAttribute("OwnerUserId", ownerUserId)
		end
	end
end

local function preparePlacedBuilding(container, name, ownerUserId)
	local model = container:FindFirstChild(name)
	if not model or not model:IsA("Model") then
		return
	end
	setOwnerAttributes(model, ownerUserId)
	model:SetAttribute("BuildingId", name)
	model:SetAttribute("BuildingTypeId", name)
	model:SetAttribute("BuildingLevel", model:GetAttribute("BuildingLevel") or 1)
	local promptPart = getModelPromptPart(model)
	if not promptPart then
		return
	end
	if name == "EggHatchery" then
		getOrCreatePrompt(promptPart, "EggShopPrompt", "Open Egg Shop", "Egg Hatchery")
	elseif name == "DragonAcademy" then
		model:SetAttribute("MergeBuilding", true)
		promptPart:SetAttribute("MergeBuilding", true)
		getOrCreatePrompt(promptPart, "DragonMergePrompt", "Merge Dragons", "Dragon Academy")
	end
end

local function computeIslandAttributes(container)
	local islandModel = WorkspaceLayout.GetMainIsland()
	local boundsTarget = islandModel or container
	local cframe, size = boundsTarget:GetBoundingBox()
	container:SetAttribute("BaseIslandCenter", cframe.Position)
	container:SetAttribute("BaseIslandSize", Vector3.new(math.max(size.X, 1), math.max(size.Y, 1), math.max(size.Z, 1)))
	container:SetAttribute("BaseIslandTopY", cframe.Position.Y + size.Y * 0.5)
end

local function prepareHubCollision()
	local hub = WorkspaceLayout.GetHub()
	if not hub then
		warn("[IslandManager] Workspace/Hub is missing")
		return
	end

	for _, descendant in hub:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanQuery = true
			descendant.CanTouch = true
			if descendant:IsA("MeshPart") then
				pcall(function()
					descendant.CollisionFidelity = Enum.CollisionFidelity.Default
				end)
			end
		end
	end
end

local function prepareSpawnLocations()
	local hubSpawn = WorkspaceLayout.GetHubSpawn()
	local islandSpawn = WorkspaceLayout.GetMainIslandSpawn()

	if hubSpawn then
		hubSpawn.Enabled = false
		hubSpawn.Neutral = true
		hubSpawn.Duration = 0
		hubSpawn.CanCollide = false
	end

	if islandSpawn then
		islandSpawn.Enabled = false
		islandSpawn.Neutral = true
		islandSpawn.CanCollide = false
	end
end

local function prepareCrystalSpawnPoints()
	for _, point in WorkspaceLayout.GetCrystalSpawnPoints() do
		point.Anchored = true
		point.CanCollide = false
		point.CanQuery = true
		point.CanTouch = false
		point.Transparency = 1
		point:SetAttribute("CrystalSpawnPoint", true)
	end
end

prepareHubCollision()
prepareCrystalSpawnPoints()
prepareSpawnLocations()

local function setupMainIslandForPlayer(player)
	local container = WorkspaceLayout.GetMainIslandContainer()
	if not container then
		warn("[IslandManager] Workspace/islandMain is missing")
		return nil
	end

	container:SetAttribute("OwnerUserId", player.UserId)
	container:SetAttribute("SlotIndex", 0)
	computeIslandAttributes(container)
	for _, name in BUILDING_NAMES do
		preparePlacedBuilding(container, name, player.UserId)
	end
	prepareSpawnLocations()

	local hubSpawn = WorkspaceLayout.GetHubSpawn()
	if hubSpawn then
		player.RespawnLocation = hubSpawn
	end

	player:SetAttribute("CurrentZone", ZONE_HUB)

	playerIslands[player] = container
	HarvestUIUpdate:FireClient(player, player:GetAttribute("DragonEssence") or 0, nil, nil, nil)
	return container
end

local function teleportToHub(player)
	WorkspaceLayout.PlaceCharacterOnHub(player)
	player:SetAttribute("CurrentZone", ZONE_HUB)
end

local function teleportToIsland(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = WorkspaceLayout.GetIslandSpawnCFrame()
	player:SetAttribute("CurrentZone", ZONE_MAIN_ISLAND)
end

local function onCharacterAdded(player, character)
	character:WaitForChild("HumanoidRootPart")
	character:WaitForChild("Humanoid")
	if hasInitialSpawn[player] then
		return
	end
	hasInitialSpawn[player] = true
	task.defer(function()
		if WorkspaceLayout.PlaceCharacterOnHub(player) then
			player:SetAttribute("CurrentZone", ZONE_HUB)
		end
	end)
end

local function onPlayerAdded(player)
	setupMainIslandForPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	playerIslands[player] = nil
	fallCooldown[player] = nil
	hasInitialSpawn[player] = nil
end)

RunService.Heartbeat:Connect(function()
	for player in pairs(playerIslands) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local zone = player:GetAttribute("CurrentZone") or ZONE_MAIN_ISLAND
			if root.Position.Y < getZoneFallThreshold(zone) then
				if not fallCooldown[player] then
					fallCooldown[player] = true
					FallRespawn:FireClient(player)
					if zone == ZONE_HUB then
						teleportToHub(player)
					else
						teleportToIsland(player)
					end
					task.delay(1.5, function()
						fallCooldown[player] = nil
					end)
				end
			end
		end
	end
end)

print("[IslandManager] Hub + Main Island workspace adapter ready")
