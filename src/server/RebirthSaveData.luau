local RebirthSaveData = {}

RebirthSaveData.CURRENT_VERSION = 1

function RebirthSaveData.CreateDefault()
	return {
		version = RebirthSaveData.CURRENT_VERSION,
		rebirthCount = 0,
		ascensionShards = 0,
		skillTreeNodes = {},
		lifetimeStats = {
			HighestIslandIndex = 0,
			HighestKingdomLevel = 1,
			TotalShardsEarned = 0,
			TotalRebirths = 0,
			BestRunShards = 0,
			CelestialClears = 0,
			LastRebirthAt = 0,
		},
		claimedMilestones = {},
		unlockedAuras = {},
		unlockedPortalEffects = {},
		unlockedCosmetics = {},
		unlockedTitles = {},
		loaded = false,
	}
end

local function normalizeSetTable(raw, target)
	if typeof(raw) ~= "table" then
		return
	end
	for key, value in raw do
		if typeof(key) == "string" and value == true then
			target[key] = true
		elseif typeof(value) == "string" then
			target[value] = true
		end
	end
end

local function normalizeRankTable(raw, target)
	if typeof(raw) ~= "table" then
		return
	end
	for nodeId, rank in raw do
		if typeof(nodeId) == "string" then
			local numericRank = math.max(0, math.floor(tonumber(rank) or 0))
			if numericRank > 0 then
				target[nodeId] = numericRank
			end
		end
	end
end

function RebirthSaveData.Normalize(raw)
	local data = RebirthSaveData.CreateDefault()
	if typeof(raw) ~= "table" then
		return data
	end

	data.version = math.max(1, math.floor(tonumber(raw.version) or RebirthSaveData.CURRENT_VERSION))
	data.rebirthCount = math.max(0, math.floor(tonumber(raw.rebirthCount) or 0))
	data.ascensionShards = math.max(0, math.floor(tonumber(raw.ascensionShards) or 0))

	normalizeRankTable(raw.skillTreeNodes, data.skillTreeNodes)

	if typeof(raw.lifetimeStats) == "table" then
		local stats = raw.lifetimeStats
		data.lifetimeStats.HighestIslandIndex = math.max(0, math.floor(tonumber(stats.HighestIslandIndex) or 0))
		data.lifetimeStats.HighestKingdomLevel = math.max(1, math.floor(tonumber(stats.HighestKingdomLevel) or 1))
		data.lifetimeStats.TotalShardsEarned = math.max(0, math.floor(tonumber(stats.TotalShardsEarned) or 0))
		data.lifetimeStats.TotalRebirths = math.max(0, math.floor(tonumber(stats.TotalRebirths) or data.rebirthCount))
		data.lifetimeStats.BestRunShards = math.max(0, math.floor(tonumber(stats.BestRunShards) or 0))
		data.lifetimeStats.CelestialClears = math.max(0, math.floor(tonumber(stats.CelestialClears) or 0))
		data.lifetimeStats.LastRebirthAt = math.max(0, math.floor(tonumber(stats.LastRebirthAt) or 0))
	end

	normalizeSetTable(raw.claimedMilestones, data.claimedMilestones)
	normalizeSetTable(raw.unlockedAuras, data.unlockedAuras)
	normalizeSetTable(raw.unlockedPortalEffects, data.unlockedPortalEffects)
	normalizeSetTable(raw.unlockedCosmetics, data.unlockedCosmetics)
	normalizeSetTable(raw.unlockedTitles, data.unlockedTitles)

	if typeof(raw.claimedMilestones) == "table" then
		for _, milestoneId in raw.claimedMilestones do
			if typeof(milestoneId) == "string" then
				data.claimedMilestones[milestoneId] = true
			end
		end
	end

	return data
end

local function setToList(setTable)
	local list = {}
	for value in setTable do
		if setTable[value] then
			table.insert(list, value)
		end
	end
	table.sort(list)
	return list
end

function RebirthSaveData.Serialize(data)
	if typeof(data) ~= "table" then
		return nil
	end

	return {
		version = data.version or RebirthSaveData.CURRENT_VERSION,
		rebirthCount = math.max(0, math.floor(tonumber(data.rebirthCount) or 0)),
		ascensionShards = math.max(0, math.floor(tonumber(data.ascensionShards) or 0)),
		skillTreeNodes = table.clone(data.skillTreeNodes or {}),
		lifetimeStats = {
			HighestIslandIndex = math.max(0, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.HighestIslandIndex) or 0)),
			HighestKingdomLevel = math.max(1, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.HighestKingdomLevel) or 1)),
			TotalShardsEarned = math.max(0, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.TotalShardsEarned) or 0)),
			TotalRebirths = math.max(0, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.TotalRebirths) or 0)),
			BestRunShards = math.max(0, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.BestRunShards) or 0)),
			CelestialClears = math.max(0, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.CelestialClears) or 0)),
			LastRebirthAt = math.max(0, math.floor(tonumber(data.lifetimeStats and data.lifetimeStats.LastRebirthAt) or 0)),
		},
		claimedMilestones = setToList(data.claimedMilestones or {}),
		unlockedAuras = setToList(data.unlockedAuras or {}),
		unlockedPortalEffects = setToList(data.unlockedPortalEffects or {}),
		unlockedCosmetics = setToList(data.unlockedCosmetics or {}),
		unlockedTitles = setToList(data.unlockedTitles or {}),
		updatedAt = os.time(),
	}
end

return RebirthSaveData
