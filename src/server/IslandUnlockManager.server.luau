local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local IslandPortalRegistry = require(ReplicatedStorage:WaitForChild("IslandPortalRegistry"))
local BiomeResourceRegistry = require(ReplicatedStorage:WaitForChild("BiomeResourceRegistry"))
local IslandTeleportService = require(ServerScriptService:WaitForChild("IslandTeleportService"))
local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local IslandUnlockState = IslandEvents:WaitForChild("IslandUnlockState")
local IslandUnlockFeedback = IslandEvents:WaitForChild("IslandUnlockFeedback")
local IslandUnlockRequest = IslandEvents:WaitForChild("IslandUnlockRequest")
local IslandTeleportRequest = IslandEvents:WaitForChild("IslandTeleportRequest")
local OpenWorldPortal = IslandEvents:WaitForChild("OpenWorldPortal")
local PortalTravel = IslandEvents:WaitForChild("PortalTravel")
local HarvestUIUpdate = ReplicatedStorage:WaitForChild("HarvestEvents"):WaitForChild("HarvestUIUpdate")
local AchievementEvents = ReplicatedStorage:WaitForChild("AchievementEvents")
local AchievementProgressSignal = AchievementEvents:WaitForChild("AchievementProgressSignal")

local DATASTORE_NAME = IslandUnlockConfig.DataStoreName
local ZONE_HUB = "Hub"
local TELEPORT_COOLDOWN = 2
local FADE_IN_TIME = 0.45
local FADE_HOLD_TIME = 0.15
local ISLAND_SPAWN_NAME = "IslandSpawn"
local DEFAULT_HIP_HEIGHT = 3

local ISLAND_SPAWN_LOCAL_OFFSETS = {
	Forest = { pos = Vector3.new(0, 17.6, -29.941), yaw = math.pi },
	Cold = { pos = Vector3.new(20, 35.382, -30.042), yaw = 2.5542 },
	Lava = { pos = Vector3.new(-20, 27.397, -30.04), yaw = -2.5542 },
	Storm = { pos = Vector3.new(0, 12.941, -29.969), yaw = math.pi },
	Shadow = { pos = Vector3.new(20, 53.392, -34.867), yaw = 2.6208 },
	Crystal = { pos = Vector3.new(-10, 17.31, -30.016), yaw = -2.82 },
	Celestial = { pos = Vector3.new(-20, 9.021, -29.986), yaw = -2.5534 },
}

local unlockStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if success then
		unlockStore = result
		dataStoreAvailable = true
	end
end

local playerUnlockData = {}
local saveQueued = {}
local islandModels = {}
local worldReady = false
local teleportCooldown = {}
local portalConnected = false

local function getData(player)
	if not playerUnlockData[player] then
		playerUnlockData[player] = {
			unlocked = {},
			loaded = false,
		}
	end
	return playerUnlockData[player]
end

local function isUnlocked(player, islandId)
	local data = getData(player)
	return data.unlocked[islandId] == true
end

BiomeResourceRegistry.IsIslandUnlockedForPlayer = isUnlocked

local function getPreviousIslandId(islandId)
	local index = IslandUnlockConfig.GetIslandIndex(islandId)
	if not index or index <= 1 then
		return nil
	end
	return IslandUnlockConfig.Islands[index - 1].Id
end

local function getDiscountedIslandCost(player, island)
	return AscensionBonusService.ApplyCostDiscount(player, island.Cost, "IslandCostReduction")
end

local function getTeleportTimings(player)
	local speedMultiplier = AscensionBonusService.GetPortalSpeedMultiplier(player)
	return {
		cooldown = math.max(0.5, TELEPORT_COOLDOWN * speedMultiplier),
		fadeIn = math.max(0.15, FADE_IN_TIME * speedMultiplier),
		hold = math.max(0.05, FADE_HOLD_TIME * speedMultiplier),
	}
end

local function canPurchase(player, islandId)
	local island = IslandUnlockConfig.GetIslandById(islandId)
	if not island then
		return false, "Unknown island"
	end
	if isUnlocked(player, islandId) then
		return false, "Already unlocked"
	end
	local previousId = getPreviousIslandId(islandId)
	if previousId and not isUnlocked(player, previousId) then
		return false, "Unlock the previous island first."
	end
	local discountedCost = getDiscountedIslandCost(player, island)
	local essence = player:GetAttribute("DragonEssence") or 0
	if essence < discountedCost then
		return false, "Not enough Dragon Essence."
	end
	return true
end

local function buildStatePayload(player)
	local data = getData(player)
	local unlockedList = {}
	for _, island in IslandUnlockConfig.Islands do
		if data.unlocked[island.Id] then
			table.insert(unlockedList, island.Id)
		end
	end
	return {
		unlocked = unlockedList,
		loaded = data.loaded,
	}
end

local function sendState(player)
	IslandUnlockState:FireClient(player, buildStatePayload(player))
end

local function sendFeedback(player, payload)
	IslandUnlockFeedback:FireClient(player, payload)
end

local function saveNow(player)
	local data = playerUnlockData[player]
	if not data or not data.loaded or not dataStoreAvailable or not unlockStore then
		return
	end
	local unlockedList = {}
	for _, island in IslandUnlockConfig.Islands do
		if data.unlocked[island.Id] then
			table.insert(unlockedList, island.Id)
		end
	end
	pcall(function()
		unlockStore:UpdateAsync(tostring(player.UserId), function()
			return {
				unlocked = unlockedList,
				updatedAt = os.time(),
			}
		end)
	end)
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(3, function()
		saveQueued[player] = nil
		if player.Parent then
			saveNow(player)
		end
	end)
end

-- Routes through AdminBridge's Harvest.adjustEssence (which updates DragonHarvestManager's private
-- essence ledger, not just the attribute) instead of a raw SetAttribute. A raw SetAttribute here would
-- get silently reverted by DragonHarvestManager's next harvest-tick UI sync, which unconditionally
-- mirrors its own ledger back onto the attribute - effectively refunding whatever this just spent.
local function changeEssence(player, delta)
	local essence = player:GetAttribute("DragonEssence") or 0
	if essence + delta < 0 then
		return false
	end
	local found, newEssence = AdminBridge.call("Harvest", "adjustEssence", player, delta)
	if not found then
		newEssence = essence + delta
		player:SetAttribute("DragonEssence", newEssence)
	end
	HarvestUIUpdate:FireClient(player, newEssence)
	return true
end

local function getCenterPosition()
	local mainIsland = WorkspaceLayout.GetMainIsland()
	if mainIsland then
		local cframe, _ = mainIsland:GetBoundingBox()
		return cframe.Position
	end
	return Vector3.new(0, 0, 0)
end

local function getHorizontalUnit(fromPosition, toPosition)
	local flat = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	if flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
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

local function getPortalInteractionAnchor(model)
	local interactionAnchor = model:FindFirstChild("InteractionAnchor")
	if not interactionAnchor then
		interactionAnchor = model:WaitForChild("InteractionAnchor", 10)
	end
	if interactionAnchor and interactionAnchor:IsA("BasePart") then
		return interactionAnchor
	end
	return getModelPromptPart(model)
end

local function configureIslandSpawn(spawn)
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Anchored = true
end

local function findIslandSpawn(islandModel)
	local spawn = islandModel:FindFirstChild(ISLAND_SPAWN_NAME)
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn
	end
	return nil
end

local function createIslandSpawnFromOffset(islandModel, islandId)
	local offsetData = ISLAND_SPAWN_LOCAL_OFFSETS[islandId]
	if not offsetData then
		return nil
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = ISLAND_SPAWN_NAME
	spawn.Size = Vector3.new(8, 1, 8)
	configureIslandSpawn(spawn)

	local localCFrame = CFrame.new(offsetData.pos) * CFrame.Angles(0, offsetData.yaw, 0)
	spawn.CFrame = islandModel:GetPivot():ToWorldSpace(localCFrame)
	spawn.Parent = islandModel
	return spawn
end

local function ensureIslandSpawn(islandModel, islandId)
	local spawn = findIslandSpawn(islandModel)
	if spawn then
		configureIslandSpawn(spawn)
		return spawn
	end

	return createIslandSpawnFromOffset(islandModel, islandId)
end

local function getSpawnCharacterCFrame(spawn)
	local hipOffset = spawn.Size.Y * 0.5 + DEFAULT_HIP_HEIGHT
	return spawn.CFrame * CFrame.new(0, hipOffset, 0)
end

local function findFallbackSpawnCFrame(islandModel)
	local centerPosition = getCenterPosition()
	local islandPivot = islandModel:GetPivot().Position
	local toCenter = getHorizontalUnit(islandPivot, centerPosition)
	local extents = islandModel:GetExtentsSize()
	local radius = math.max(extents.X, extents.Z) * 0.5

	local bestHit = nil
	local bestY = -math.huge

	for distFrac = 0.15, 0.45, 0.05 do
		for lateral = -20, 20, 10 do
			local lateralVec = Vector3.new(-toCenter.Z, 0, toCenter.X) * lateral
			local sampleXZ = islandPivot + toCenter * (radius * distFrac) + lateralVec
			local topY = islandPivot.Y + extents.Y * 0.5 + 30

			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Include
			rayParams.FilterDescendantsInstances = { islandModel }

			local result = workspace:Raycast(
				Vector3.new(sampleXZ.X, topY, sampleXZ.Z),
				Vector3.new(0, -extents.Y - 80, 0),
				rayParams
			)
			if result and result.Normal.Y > 0.5 and result.Position.Y > bestY then
				bestY = result.Position.Y
				bestHit = result
			end
		end
	end

	if bestHit then
		local spawnPos = bestHit.Position + Vector3.new(0, DEFAULT_HIP_HEIGHT, 0)
		return CFrame.lookAt(spawnPos, Vector3.new(islandPivot.X, spawnPos.Y, islandPivot.Z))
	end

	local fallbackPosition = islandPivot + toCenter * math.max(18, radius * 0.28) + Vector3.new(0, DEFAULT_HIP_HEIGHT + 6, 0)
	return CFrame.lookAt(fallbackPosition, islandPivot)
end

local function getIslandTeleportCFrame(islandModel, islandId)
	if IslandPortalRegistry.IsReady() then
		local registryCFrame = IslandPortalRegistry.GetIslandSpawnCFrame(islandId)
		if registryCFrame then
			return registryCFrame
		end
	end

	local spawn = ensureIslandSpawn(islandModel, islandId)
	if spawn then
		return getSpawnCharacterCFrame(spawn)
	end

	return findFallbackSpawnCFrame(islandModel)
end

local function removeLegacyWorldObjects()
	local shrineFolder = workspace:FindFirstChild(IslandUnlockConfig.ShrineFolderName)
	if shrineFolder then
		shrineFolder:Destroy()
	end
	local barrierFolder = workspace:FindFirstChild(IslandUnlockConfig.BarrierFolderName)
	if barrierFolder then
		barrierFolder:Destroy()
	end
end

local function waitForWorldLayout()
	local arranger = ServerScriptService:FindFirstChild("IslandArranger")
	if arranger and arranger:IsA("Script") then
		local start = os.clock()
		while arranger.Enabled and os.clock() - start < 30 do
			task.wait(0.1)
		end
	end

	local biomeFolder = workspace:WaitForChild(IslandUnlockConfig.FolderName, 30)
	if not biomeFolder then
		warn("[IslandUnlockManager] Missing biome folder:", IslandUnlockConfig.FolderName)
		return false
	end

	for _, island in IslandUnlockConfig.Islands do
		local model = biomeFolder:WaitForChild(island.ModelName, 30)
		if not model or not model:IsA("Model") then
			warn("[IslandUnlockManager] Missing island model:", island.ModelName)
			return false
		end
		getModelPromptPart(model)
		islandModels[island.Id] = model
		if not IslandPortalRegistry.IsReady() then
			ensureIslandSpawn(model, island.Id)
		end
	end

	IslandPortalRegistry.WaitUntilReady(5)

	return true
end

local function prepareWorld()
	if worldReady then
		return
	end
	if not waitForWorldLayout() then
		return
	end
	removeLegacyWorldObjects()
	worldReady = true
	print("[IslandUnlockManager] Biome islands ready for unlock progression")
end

local function performUnlock(player, islandId)
	local island = IslandUnlockConfig.GetIslandById(islandId)
	if not island then
		return
	end

	local canBuy, reason = canPurchase(player, islandId)
	if not canBuy then
		sendFeedback(player, {
			success = false,
			islandId = islandId,
			message = reason,
		})
		return
	end

	if not changeEssence(player, -getDiscountedIslandCost(player, island)) then
		sendFeedback(player, {
			success = false,
			islandId = islandId,
			message = "Not enough Dragon Essence.",
		})
		return
	end

	local data = getData(player)
	data.unlocked[islandId] = true
	queueSave(player)
	sendState(player)
	AchievementProgressSignal:Fire(player, "IslandUnlock", 1, {
		islandId = islandId,
		islandIndex = IslandUnlockConfig.GetIslandIndex(islandId),
	})

	local islandModel = islandModels[islandId]
	sendFeedback(player, {
		success = true,
		islandId = islandId,
		message = island.DisplayName .. " Unlocked!",
		effectPosition = islandModel and islandModel:GetPivot().Position or nil,
	})
end

local function teleportPlayerToIsland(player, islandId, force)
	if teleportCooldown[player] then
		return
	end

	local island = IslandUnlockConfig.GetIslandById(islandId)
	if not island then
		return
	end
	if not force and not isUnlocked(player, islandId) then
		sendFeedback(player, {
			success = false,
			islandId = islandId,
			message = "Unlock " .. island.DisplayName .. " first.",
		})
		return
	end

	local islandModel = islandModels[islandId]
	if not islandModel then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	local timings = getTeleportTimings(player)
	teleportCooldown[player] = true
	task.delay(timings.cooldown, function()
		teleportCooldown[player] = nil
	end)

	PortalTravel:FireClient(player, "fadeIn")
	task.wait(timings.fadeIn + timings.hold)

	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = getIslandTeleportCFrame(islandModel, islandId)
	player:SetAttribute("CurrentZone", "BiomeIsland")
	player:SetAttribute("CurrentIslandId", islandId)

	task.wait()
	PortalTravel:FireClient(player, "fadeOut")
end

local function teleportPlayerToHub(player)
	if teleportCooldown[player] then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	local timings = getTeleportTimings(player)
	teleportCooldown[player] = true
	task.delay(timings.cooldown, function()
		teleportCooldown[player] = nil
	end)

	PortalTravel:FireClient(player, "fadeIn")
	task.wait(timings.fadeIn + timings.hold)

	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = WorkspaceLayout.GetHubSpawnCFrame()
	player:SetAttribute("CurrentZone", ZONE_HUB)
	player:SetAttribute("CurrentIslandId", ZONE_HUB)

	task.wait()
	PortalTravel:FireClient(player, "fadeOut")
end

local function setupWorldPortal()
	if portalConnected then
		return
	end

	local portalModel = WorkspaceLayout.GetMainIslandPortal()
	if not portalModel then
		return
	end

	local promptPart = getPortalInteractionAnchor(portalModel)
	if not promptPart then
		warn("[IslandUnlockManager] MainIslandPortal has no usable part")
		return
	end

	local prompt = promptPart:FindFirstChild(IslandUnlockConfig.WorldPortalPromptName)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = IslandUnlockConfig.WorldPortalPromptName
		prompt.Parent = promptPart
	end

	local hubPrompt = promptPart:FindFirstChild("PortalPrompt")
	if hubPrompt then
		hubPrompt:Destroy()
	end

	prompt.ActionText = "Open World Map"
	prompt.ObjectText = "World Portal"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false

	prompt.Triggered:Connect(function(player)
		OpenWorldPortal:FireClient(player)
	end)

	portalConnected = true
end

local function isPointInsideModel(model, point)
	local cframe, size = model:GetBoundingBox()
	local localPoint = cframe:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= size.X * 0.5
		and math.abs(localPoint.Y) <= size.Y * 0.5 + 12
		and math.abs(localPoint.Z) <= size.Z * 0.5
end

local function enforceIslandAccess(player)
	if not worldReady then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	for _, island in IslandUnlockConfig.Islands do
		if isUnlocked(player, island.Id) then
			continue
		end
		local model = islandModels[island.Id]
		if model and isPointInsideModel(model, root.Position) then
			local centerPosition = getCenterPosition()
			local toCenter = getHorizontalUnit(model:GetPivot().Position, centerPosition)
			root.CFrame = CFrame.new(model:GetPivot().Position - toCenter * (math.max(model:GetExtentsSize().X, model:GetExtentsSize().Z) * 0.35 + 20) + Vector3.new(0, 6, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			sendFeedback(player, {
				success = false,
			islandId = island.Id,
			message = "Unlock " .. island.DisplayName .. " to enter.",
			})
			break
		end
	end
end

local function loadPlayer(player)
	local data = getData(player)
	if dataStoreAvailable and unlockStore then
		local success, result = pcall(function()
			return unlockStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" and typeof(result.unlocked) == "table" then
			for _, islandId in result.unlocked do
				if IslandUnlockConfig.GetIslandById(islandId) then
					data.unlocked[islandId] = true
				end
			end
		end
	end
	data.loaded = true

	local start = os.clock()
	while player.Parent and not worldReady and os.clock() - start < 20 do
		task.wait(0.2)
	end

	sendState(player)
end

prepareWorld()
task.defer(setupWorldPortal)

IslandTeleportService.Register({
	isUnlocked = isUnlocked,
	teleportToHub = teleportPlayerToHub,
	teleportToIsland = teleportPlayerToIsland,
})

workspace.ChildAdded:Connect(function(child)
	if child.Name == WorkspaceLayout.MainIslandPortalName then
		task.defer(setupWorldPortal)
	end
end)

IslandUnlockRequest.OnServerEvent:Connect(function(player, islandId)
	if not RateLimiter.check(player, "IslandUnlockRequest", 0.3) then
		return
	end
	if typeof(islandId) ~= "string" then
		return
	end
	if not IslandUnlockConfig.GetIslandById(islandId) then
		return
	end
	performUnlock(player, islandId)
end)

IslandTeleportRequest.OnServerEvent:Connect(function(player, islandId)
	if typeof(islandId) ~= "string" then
		return
	end
	if islandId == "Hub" then
		task.spawn(teleportPlayerToHub, player)
		return
	end
	if not IslandUnlockConfig.GetIslandById(islandId) then
		return
	end
	task.spawn(teleportPlayerToIsland, player, islandId)
end)

task.spawn(function()
	while true do
		task.wait(0.75)
		for _, player in Players:GetPlayers() do
			enforceIslandAccess(player)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayer(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveNow(player)
	playerUnlockData[player] = nil
	saveQueued[player] = nil
	teleportCooldown[player] = nil
end)

local function adminUnlockIsland(player, islandId)
	local island = IslandUnlockConfig.GetIslandById(islandId)
	if not island then
		return "Unknown island"
	end
	local data = getData(player)
	data.unlocked[islandId] = true
	queueSave(player)
	sendState(player)
	return island.DisplayName .. " unlocked"
end

local function adminUnlockAll(player)
	local data = getData(player)
	for _, island in IslandUnlockConfig.Islands do
		data.unlocked[island.Id] = true
	end
	queueSave(player)
	sendState(player)
	return "All islands unlocked"
end

local function adminTeleportIsland(player, islandId, force)
	if islandId == "Hub" then
		teleportPlayerToHub(player)
		return "Teleported to Hub"
	end
	local island = IslandUnlockConfig.GetIslandById(islandId)
	if not island then
		return "Unknown island"
	end
	if not force and not isUnlocked(player, islandId) then
		return "Island not unlocked"
	end
	task.spawn(teleportPlayerToIsland, player, islandId, true)
	return "Teleporting to " .. island.DisplayName
end

AdminBridge.register("Islands", {
	unlockIsland = adminUnlockIsland,
	unlockAll = adminUnlockAll,
	teleport = adminTeleportIsland,
	refreshState = function(player)
		sendState(player)
		return "Island state refreshed"
	end,
	save = function(player)
		saveNow(player)
		return "Island unlocks saved"
	end,
	wipe = function(player)
		local data = getData(player)
		data.unlocked = {}
		data.loaded = true
		queueSave(player)
		sendState(player)
		return "Island unlocks wiped"
	end,
})

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))

RebirthDomainBridge.Register("Islands", {
	getSnapshotPatch = function(player)
		local data = getData(player)
		local unlockedIslandIds = {}
		local highestIndex = 0
		local highestId = nil
		for _, island in IslandUnlockConfig.Islands do
			if data.unlocked[island.Id] then
				table.insert(unlockedIslandIds, island.Id)
				local index = IslandUnlockConfig.GetIslandIndex(island.Id) or 0
				if index > highestIndex then
					highestIndex = index
					highestId = island.Id
				end
			end
		end
		return {
			unlockedIslandIds = unlockedIslandIds,
			highestIslandIndex = highestIndex,
			highestIslandId = highestId,
			celestialUnlocked = highestIndex >= 7,
		}
	end,
	canReset = function(player)
		if teleportCooldown[player] then
			return { ok = false, reason = "Island teleport in progress." }
		end
		return { ok = true }
	end,
	resetRunState = function(player)
		local data = getData(player)
		data.unlocked = {}
		queueSave(player)
		sendState(player)
		player:SetAttribute("CurrentZone", ZONE_HUB)
		player:SetAttribute("CurrentIslandId", ZONE_HUB)
		return { success = true }
	end,
	restorePermanentState = function(_player)
		return { success = true }
	end,
})

print("[IslandUnlockManager] World portal unlock progression ready")