local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local DragonInventoryConfig = require(ReplicatedStorage:WaitForChild("DragonInventoryConfig"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local BuildingEvents = ReplicatedStorage:WaitForChild("BuildingEvents")
local RequestBuildingData = BuildingEvents:WaitForChild("RequestBuildingData")
local UpgradeBuilding = BuildingEvents:WaitForChild("UpgradeBuilding")
local UnlockBuilding = BuildingEvents:WaitForChild("UnlockBuilding")
local BuildingStateUpdated = BuildingEvents:WaitForChild("BuildingStateUpdated")
local TutorialEvents = ReplicatedStorage:WaitForChild("TutorialEvents")
local TutorialProgressSignal = TutorialEvents:WaitForChild("TutorialProgressSignal")
local AchievementEvents = ReplicatedStorage:WaitForChild("AchievementEvents")
local AchievementProgressSignal = AchievementEvents:WaitForChild("AchievementProgressSignal")
local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))

local BUILDING_DATASTORE = "FixedBuildingProgressV1"
local FIXED_BUILDINGS = {
	"EggHatchery",
	"DragonNest",
	"DragonStorage",
	"DragonAcademy",
	"CrystalStorage",
	"Workshop",
}
local DEFAULT_UNLOCKED = {
	EggHatchery = true,
	DragonNest = true,
	DragonStorage = true,
	DragonAcademy = true,
	CrystalStorage = true,
	Workshop = true,
}

local playerBuildingData = {}
local saveQueued = {}
local buildingStore = nil
local dataStoreAvailable = false

if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(BUILDING_DATASTORE)
	end)
	if success then
		buildingStore = result
		dataStoreAvailable = true
	else
		warn("[BuildingUpgradeManager] Building DataStore unavailable; building progress will persist only after publishing:", result)
	end
end

local function isFixedBuilding(typeId)
	return table.find(FIXED_BUILDINGS, typeId) ~= nil and BuildingConfig.Buildings[typeId] ~= nil
end

local function sanitizeLevel(level)
	local maxLevel = BuildingConfig.Upgrade.MaxLevel or 25
	local numberLevel = math.floor(tonumber(level) or 1)
	return math.clamp(numberLevel, 1, maxLevel)
end

local function getData(player)
	local data = playerBuildingData[player]
	if not data then
		data = { levels = {}, unlocked = {}, loaded = false }
		for _, typeId in FIXED_BUILDINGS do
			data.levels[typeId] = 1
			data.unlocked[typeId] = DEFAULT_UNLOCKED[typeId] == true
		end
		playerBuildingData[player] = data
	end
	return data
end

local function getUnlockCost(typeId)
	local definition = BuildingConfig.Buildings[typeId]
	return definition and (definition.UnlockCost or 0) or 0
end

local function getUpgradeCost(typeId, level)
	local upgradeConfig = BuildingConfig.Upgrade
	local baseCost = upgradeConfig.BaseCost or 150
	local growth = upgradeConfig.CostGrowth or 1.65
	local typeOffset = table.find(BuildingConfig.BuildingOrder, typeId) or 1
	return math.floor(baseCost * (1 + (typeOffset - 1) * 0.2) * (growth ^ math.max(0, level - 1)))
end

local function getBuildingEffects(typeId, level)
	local upgradeConfig = BuildingConfig.Upgrade
	local effects = {}
	local safeLevel = sanitizeLevel(level)
	if typeId == "DragonNest" then
		effects.ActiveDragonSlots = safeLevel * (upgradeConfig.DragonNest.DragonSlotsPerLevel or 2)
	elseif typeId == "CrystalStorage" then
		effects.DragonEssenceStorageCapacity = (upgradeConfig.CrystalStorage.BaseCapacity or 1000) + ((safeLevel - 1) * (upgradeConfig.CrystalStorage.CapacityPerLevel or 500))
	elseif typeId == "DragonStorage" then
		effects.DragonStorageCapacity = DragonInventoryConfig.GetStorageCapacity(safeLevel)
	elseif typeId == "DragonAcademy" then
		local reduction = math.min(upgradeConfig.DragonAcademy.MaxTrainingTimeReduction or 0.65, (safeLevel - 1) * (upgradeConfig.DragonAcademy.TrainingTimeReductionPerLevel or 0.03))
		effects.TrainingTimeMultiplier = math.max(0.1, 1 - reduction)
		effects.XpGainMultiplier = 1 + ((safeLevel - 1) * (upgradeConfig.DragonAcademy.XpGainBonusPerLevel or 0.1))
	elseif typeId == "Workshop" then
		effects.CraftingRecipeTier = 1 + math.floor((safeLevel - 1) / (upgradeConfig.Workshop.RecipeTierPerLevels or 3))
	end
	return effects
end

local function getPlayerIsland(player)
	return WorkspaceLayout.GetPlayerIsland(player)
end

local function getFixedBuildingModel(player, typeId)
	local island = getPlayerIsland(player)
	if not island then
		return nil
	end
	local model = island:FindFirstChild(typeId)
	if model and model:IsA("Model") then
		return model
	end
	return nil
end

local function getPromptPart(model)
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

local function ensurePrompt(parent, name, actionText, objectText, enabled)
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
	prompt.Enabled = enabled == true
end

local function setAttributesOnInstance(instance, player, typeId, level, unlocked)
	instance:SetAttribute("OwnerUserId", player.UserId)
	instance:SetAttribute("BuildingId", typeId)
	instance:SetAttribute("BuildingTypeId", typeId)
	instance:SetAttribute("BuildingLevel", level)
	instance:SetAttribute("BuildingUnlocked", unlocked)
	instance:SetAttribute("BuildingUnlockCost", getUnlockCost(typeId))
	instance:SetAttribute("BuildingUpgradeCost", getUpgradeCost(typeId, level))
	for effectName, effectValue in getBuildingEffects(typeId, level) do
		instance:SetAttribute(effectName, effectValue)
	end
end

local function applyBuildingVisualState(model, unlocked)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = true
			if unlocked then
				descendant.Transparency = descendant:GetAttribute("OriginalTransparency") or descendant.Transparency
			else
				if descendant:GetAttribute("OriginalTransparency") == nil then
					descendant:SetAttribute("OriginalTransparency", descendant.Transparency)
				end
				descendant.Transparency = math.max(descendant.Transparency, 0.45)
			end
		end
	end
end

local function applyBuildingState(player, typeId)
	local model = getFixedBuildingModel(player, typeId)
	if not model then
		return
	end
	local data = getData(player)
	local level = sanitizeLevel(data.levels[typeId] or 1)
	local unlocked = data.unlocked[typeId] == true
	data.levels[typeId] = level
	setAttributesOnInstance(model, player, typeId, level, unlocked)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Model") or descendant:IsA("BasePart") then
			setAttributesOnInstance(descendant, player, typeId, level, unlocked)
		end
	end
	applyBuildingVisualState(model, unlocked)
	local promptPart = getPromptPart(model)
	if promptPart then
		if typeId == "EggHatchery" then
			ensurePrompt(promptPart, "EggShopPrompt", "Open Egg Shop", "Egg Hatchery", unlocked)
		elseif typeId == "DragonAcademy" then
			model:SetAttribute("MergeBuilding", true)
			promptPart:SetAttribute("MergeBuilding", true)
			ensurePrompt(promptPart, "DragonMergePrompt", "Merge Dragons", "Dragon Academy", unlocked)
			ensurePrompt(promptPart, "DragonTrainingPrompt", "Train Dragons", "Dragon Academy", unlocked)
		elseif typeId == "Workshop" then
			ensurePrompt(promptPart, "WorkshopCraftPrompt", "Craft Items", "Workshop", unlocked)
		end
	end
end

local function applyAllBuildingStates(player)
	for _, typeId in FIXED_BUILDINGS do
		applyBuildingState(player, typeId)
	end
end

local function getSerializableBuildings(player)
	local data = getData(player)
	local buildings = {}
	for _, typeId in FIXED_BUILDINGS do
		local model = getFixedBuildingModel(player, typeId)
		local definition = BuildingConfig.Buildings[typeId]
		if model and definition then
			local pivot = model:GetPivot().Position
			local level = sanitizeLevel(data.levels[typeId] or 1)
			local unlocked = data.unlocked[typeId] == true
			table.insert(buildings, {
				id = typeId,
				typeId = typeId,
				displayName = definition.DisplayName,
				x = pivot.X,
				z = pivot.Z,
				level = level,
				unlocked = unlocked,
				unlockCost = getUnlockCost(typeId),
				upgradeCost = getUpgradeCost(typeId, level),
				effects = getBuildingEffects(typeId, level),
			})
		end
	end
	return buildings
end

local function sendState(player, message)
	BuildingStateUpdated:FireClient(player, {
		buildings = getSerializableBuildings(player),
		message = message,
	})
end

local function saveNow(player)
	local data = playerBuildingData[player]
	if not data or not data.loaded or not dataStoreAvailable or not buildingStore then
		return
	end
	local payload = {
		levels = data.levels,
		unlocked = data.unlocked,
		updatedAt = os.time(),
	}
	local success, err = pcall(function()
		buildingStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
	if not success then
		warn("[BuildingUpgradeManager] Failed to save building progress for", player.UserId, err)
	end
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(2, function()
		saveQueued[player] = nil
		if player.Parent then
			saveNow(player)
		end
	end)
end

local function loadPlayerBuildings(player)
	local data = getData(player)
	for _, typeId in FIXED_BUILDINGS do
		data.levels[typeId] = 1
		data.unlocked[typeId] = DEFAULT_UNLOCKED[typeId] == true
	end
	if dataStoreAvailable and buildingStore then
		local success, result = pcall(function()
			return buildingStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			if typeof(result.levels) == "table" then
				for typeId, level in result.levels do
					if isFixedBuilding(typeId) then
						data.levels[typeId] = sanitizeLevel(level)
					end
				end
			end
			if typeof(result.unlocked) == "table" then
				for typeId, unlocked in result.unlocked do
					if isFixedBuilding(typeId) then
						data.unlocked[typeId] = unlocked == true
					end
				end
			end
		elseif not success then
			warn("[BuildingUpgradeManager] Failed to load building progress for", player.UserId, result)
		end
	end
	data.loaded = true
	local startTime = os.clock()
	while player.Parent and os.clock() - startTime < 10 and not getPlayerIsland(player) do
		task.wait(0.2)
	end
	if player.Parent then
		applyAllBuildingStates(player)
		if data.unlocked.DragonNest then
			task.defer(function()
				if player.Parent then
					TutorialProgressSignal:Fire(player, "PlaceDragonNest")
				end
			end)
		end
		sendState(player)
	end
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
	local found = AdminBridge.call("Harvest", "adjustEssence", player, delta)
	if not found then
		player:SetAttribute("DragonEssence", essence + delta)
	end
	return true
end

RequestBuildingData.OnServerInvoke = function(player)
	local data = getData(player)
	if data.loaded then
		applyAllBuildingStates(player)
	end
	return {
		loaded = data.loaded,
		buildings = getSerializableBuildings(player),
		buildingOrder = FIXED_BUILDINGS,
	}
end

UnlockBuilding.OnServerEvent:Connect(function(player, buildingId)
	if not RateLimiter.check(player, "UnlockBuilding", 0.3) then
		return
	end
	local typeId = tostring(buildingId)
	if not isFixedBuilding(typeId) or not getFixedBuildingModel(player, typeId) then
		sendState(player, "Building not found")
		return
	end
	local data = getData(player)
	if not data.loaded then
		return
	end
	if data.unlocked[typeId] then
		sendState(player, "Already unlocked")
		return
	end
	local cost = AscensionBonusService.ApplyCostDiscount(player, getUnlockCost(typeId), "BuildingCostReduction")
	if not changeEssence(player, -cost) then
		sendState(player, "Need " .. cost .. " Dragon Essence")
		return
	end
	data.unlocked[typeId] = true
	data.levels[typeId] = math.max(1, sanitizeLevel(data.levels[typeId] or 1))
	applyBuildingState(player, typeId)
	if typeId == "DragonNest" then
		TutorialProgressSignal:Fire(player, "PlaceDragonNest")
	end
	queueSave(player)
	sendState(player, "Unlocked " .. (BuildingConfig.Buildings[typeId].DisplayName or typeId))
end)

UpgradeBuilding.OnServerEvent:Connect(function(player, buildingId)
	if not RateLimiter.check(player, "UpgradeBuilding", 0.3) then
		return
	end
	local typeId = tostring(buildingId)
	if not isFixedBuilding(typeId) or not getFixedBuildingModel(player, typeId) then
		sendState(player, "Building not found")
		return
	end
	local data = getData(player)
	if not data.loaded then
		return
	end
	if not data.unlocked[typeId] then
		sendState(player, "Unlock this building first")
		return
	end
	local level = sanitizeLevel(data.levels[typeId] or 1)
	local maxLevel = BuildingConfig.Upgrade.MaxLevel or 25
	if level >= maxLevel then
		sendState(player, "Building is max level")
		return
	end
	local cost = AscensionBonusService.ApplyCostDiscount(player, getUpgradeCost(typeId, level), "BuildingCostReduction")
	if not changeEssence(player, -cost) then
		sendState(player, "Need " .. cost .. " Dragon Essence")
		return
	end
	data.levels[typeId] = level + 1
	applyBuildingState(player, typeId)
	if typeId == "DragonNest" then
		TutorialProgressSignal:Fire(player, "PlaceDragonNest")
		TutorialProgressSignal:Fire(player, "UpgradeDragonNest")
	elseif typeId == "CrystalStorage" then
		TutorialProgressSignal:Fire(player, "UpgradeCrystalStorage")
	elseif typeId == "DragonStorage" then
		TutorialProgressSignal:Fire(player, "UpgradeDragonStorage")
	end
	queueSave(player)
	AchievementProgressSignal:Fire(player, "BuildingUpgrade", 1, { buildingId = typeId, level = data.levels[typeId] })
	sendState(player, "Upgraded to Level " .. data.levels[typeId])
end)

Players.PlayerAdded:Connect(loadPlayerBuildings)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayerBuildings, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveNow(player)
	playerBuildingData[player] = nil
	saveQueued[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(BuildingConfig.SaveInterval)
		for _, player in Players:GetPlayers() do
			saveNow(player)
		end
	end
end)

AdminBridge.register("Buildings", {
	setLevel = function(player, buildingId, level)
		local typeId = tostring(buildingId)
		if not isFixedBuilding(typeId) then
			return "Unknown building"
		end
		local data = getData(player)
		data.unlocked[typeId] = true
		data.levels[typeId] = sanitizeLevel(level)
		applyBuildingState(player, typeId)
		queueSave(player)
		sendState(player, "Set " .. typeId .. " to level " .. data.levels[typeId])
		return (BuildingConfig.Buildings[typeId].DisplayName or typeId) .. " set to level " .. data.levels[typeId]
	end,
	refreshState = function(player)
		sendState(player)
		return "Building UI refreshed"
	end,
	save = function(player)
		saveNow(player)
		return "Building progress saved"
	end,
	wipe = function(player)
		local data = getData(player)
		for _, typeId in FIXED_BUILDINGS do
			data.levels[typeId] = 1
			data.unlocked[typeId] = DEFAULT_UNLOCKED[typeId] == true
		end
		applyAllBuildingStates(player)
		queueSave(player)
		sendState(player, "Buildings reset")
		return "Building progress wiped"
	end,
})

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))
local RebirthState = require(ServerScriptService:WaitForChild("RebirthState"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))

local function getBuildingResetFloor(player)
	local floorRank = RebirthState.GetSkillTreeRank(player, "Kingdom_StorageLegacy")
	local node = RebirthConfig.GetSkillTreeNode("Kingdom_StorageLegacy")
	local perRank = node and node.EffectPerRank or 1
	return 1 + math.max(0, floorRank) * perRank
end

RebirthDomainBridge.Register("Buildings", {
	getSnapshotPatch = function(player)
		local data = getData(player)
		local buildingLevels = {}
		for _, typeId in FIXED_BUILDINGS do
			buildingLevels[typeId] = sanitizeLevel(data.levels[typeId] or 1)
		end
		return { buildingLevels = buildingLevels }
	end,
	canReset = function()
		return { ok = true }
	end,
	resetRunState = function(player)
		local data = getData(player)
		for _, typeId in FIXED_BUILDINGS do
			data.levels[typeId] = 1
			data.unlocked[typeId] = DEFAULT_UNLOCKED[typeId] == true
		end
		applyAllBuildingStates(player)
		queueSave(player)
		sendState(player)
		return { success = true }
	end,
	restorePermanentState = function(player)
		local floorLevel = math.floor(getBuildingResetFloor(player))
		if floorLevel <= 1 then
			return { success = true }
		end
		local data = getData(player)
		local changed = false
		for _, typeId in FIXED_BUILDINGS do
			if data.unlocked[typeId] then
				local currentLevel = sanitizeLevel(data.levels[typeId] or 1)
				if currentLevel < floorLevel then
					data.levels[typeId] = floorLevel
					changed = true
				end
			end
		end
		if changed then
			applyAllBuildingStates(player)
			queueSave(player)
			sendState(player)
		end
		return { success = true }
	end,
})

print("[BuildingUpgradeManager] Fixed building upgrade system ready")