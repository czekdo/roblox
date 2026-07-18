local RebirthRunSnapshot = {}

local snapshotProviders = {}

function RebirthRunSnapshot.RegisterProvider(providerId, providerFn)
	if typeof(providerId) ~= "string" or typeof(providerFn) ~= "function" then
		return false
	end
	snapshotProviders[providerId] = providerFn
	return true
end

function RebirthRunSnapshot.UnregisterProvider(providerId)
	snapshotProviders[providerId] = nil
end

local function createEmptySnapshot()
	return {
		rebirthCount = 0,
		highestIslandIndex = 0,
		highestIslandId = nil,
		unlockedIslandIds = {},
		kingdomLevel = 1,
		buildingLevels = {},
		minBuildingLevel = 1,
		maxBuildingLevel = 1,
		avgBuildingLevel = 1,
		buildingsAtOrAbove = {},
		lifetimeEssence = 0,
		currentEssence = 0,
		lifetimeHatches = 0,
		maxEvolutionStars = 0,
		celestialUnlocked = false,
		hasPendingTransactions = false,
	}
end

local function countBuildingsAtOrAbove(buildingLevels, threshold)
	local count = 0
	for _, level in buildingLevels do
		if (tonumber(level) or 1) >= threshold then
			count += 1
		end
	end
	return count
end

local function computeBuildingStats(buildingLevels)
	local minLevel = math.huge
	local maxLevel = 1
	local total = 0
	local count = 0

	for _, level in buildingLevels do
		local numeric = math.max(1, math.floor(tonumber(level) or 1))
		minLevel = math.min(minLevel, numeric)
		maxLevel = math.max(maxLevel, numeric)
		total += numeric
		count += 1
	end

	if count == 0 then
		return 1, 1, 1
	end

	return minLevel, maxLevel, total / count
end

local function mergeSnapshot(base, patch)
	if typeof(patch) ~= "table" then
		return
	end

	for key, value in patch do
		if key == "buildingLevels" and typeof(value) == "table" then
			base.buildingLevels = table.clone(value)
		elseif key == "unlockedIslandIds" and typeof(value) == "table" then
			base.unlockedIslandIds = table.clone(value)
		elseif key == "buildingsAtOrAbove" and typeof(value) == "table" then
			base.buildingsAtOrAbove = table.clone(value)
		else
			base[key] = value
		end
	end
end

function RebirthRunSnapshot.Build(player, rebirthCount)
	local snapshot = createEmptySnapshot()
	snapshot.rebirthCount = math.max(0, math.floor(tonumber(rebirthCount) or 0))

	if typeof(player) == "Instance" and player:IsA("Player") then
		snapshot.kingdomLevel = math.max(1, math.floor(tonumber(player:GetAttribute("KingdomLevel")) or 1))
		snapshot.lifetimeEssence = math.max(0, math.floor(tonumber(player:GetAttribute("LifetimeEssence")) or 0))
		snapshot.currentEssence = math.max(0, math.floor(tonumber(player:GetAttribute("DragonEssence")) or 0))
		snapshot.lifetimeHatches = math.max(0, math.floor(tonumber(player:GetAttribute("LifetimeHatches")) or 0))
		snapshot.maxEvolutionStars = math.max(0, math.floor(tonumber(player:GetAttribute("MaxEvolutionStars")) or 0))
	end

	for _, provider in snapshotProviders do
		local success, patch = pcall(provider, player)
		if success then
			mergeSnapshot(snapshot, patch)
		else
			warn("[RebirthRunSnapshot] Provider failed:", patch)
		end
	end

	return RebirthRunSnapshot.Finalize(snapshot)
end

function RebirthRunSnapshot.Finalize(snapshot)
	if typeof(snapshot) ~= "table" then
		return snapshot
	end

	local minLevel, maxLevel, avgLevel = computeBuildingStats(snapshot.buildingLevels)
	snapshot.minBuildingLevel = minLevel
	snapshot.maxBuildingLevel = maxLevel
	snapshot.avgBuildingLevel = avgLevel

	if snapshot.highestIslandIndex <= 0 and typeof(snapshot.highestIslandId) == "string" then
		local RebirthConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("RebirthConfig"))
		snapshot.highestIslandIndex = RebirthConfig.GetIslandIndex(snapshot.highestIslandId)
	end

	if snapshot.highestIslandIndex <= 0 and typeof(snapshot.unlockedIslandIds) == "table" then
		local RebirthConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("RebirthConfig"))
		for _, islandId in snapshot.unlockedIslandIds do
			local index = RebirthConfig.GetIslandIndex(islandId)
			if index and index > snapshot.highestIslandIndex then
				snapshot.highestIslandIndex = index
				snapshot.highestIslandId = islandId
			end
		end
	end

	snapshot.celestialUnlocked = snapshot.celestialUnlocked == true or snapshot.highestIslandIndex >= 7

	local thresholds = { 8, 15, 18, 20, 22 }
	for _, threshold in thresholds do
		snapshot.buildingsAtOrAbove[tostring(threshold)] = countBuildingsAtOrAbove(snapshot.buildingLevels, threshold)
	end

	return snapshot
end

return RebirthRunSnapshot
