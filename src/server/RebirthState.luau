local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthSaveData = require(script.Parent:WaitForChild("RebirthSaveData"))

local RebirthState = {}

local playerStates = {}

function RebirthState.Get(player)
	if not playerStates[player] then
		playerStates[player] = RebirthSaveData.CreateDefault()
	end
	return playerStates[player]
end

function RebirthState.Set(player, data)
	if typeof(data) ~= "table" then
		return
	end
	playerStates[player] = data
end

function RebirthState.Clear(player)
	playerStates[player] = nil
end

function RebirthState.IsLoaded(player)
	local data = playerStates[player]
	return data ~= nil and data.loaded == true
end

function RebirthState.MarkLoaded(player)
	local data = RebirthState.Get(player)
	data.loaded = true
end

function RebirthState.GetRebirthCount(player)
	return RebirthState.Get(player).rebirthCount or 0
end

function RebirthState.GetAscensionShards(player)
	return RebirthState.Get(player).ascensionShards or 0
end

function RebirthState.GetSkillTreeRank(player, nodeId)
	local data = RebirthState.Get(player)
	return math.max(0, math.floor(tonumber(data.skillTreeNodes[nodeId]) or 0))
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

local function buildSkillTreePayload(data)
	local nodes = {}
	for _, node in RebirthConfig.SkillTreeNodes do
		local currentRank = math.max(0, math.floor(tonumber(data.skillTreeNodes[node.Id]) or 0))
		table.insert(nodes, {
			Id = node.Id,
			Branch = node.Branch,
			DisplayName = node.DisplayName,
			Description = node.Description,
			MaxRank = node.MaxRank,
			CurrentRank = currentRank,
			NextCost = RebirthConfig.GetNodeCost(node.Id, currentRank),
			EffectType = node.EffectType,
			EffectPerRank = node.EffectPerRank,
			Prerequisites = node.Prerequisites,
			Disabled = node.Disabled == true,
		})
	end
	return nodes
end

function RebirthState.BuildClientPayload(player, preview)
	local data = RebirthState.Get(player)
	local rebirthCount = data.rebirthCount or 0
	local nextRebirth = RebirthConfig.GetNextRebirthNumber(rebirthCount)
	local gateTier = RebirthConfig.GetGateTier(rebirthCount)

	return {
		loaded = data.loaded == true,
		rebirthCount = rebirthCount,
		nextRebirthNumber = nextRebirth,
		ascensionShards = data.ascensionShards or 0,
		currency = RebirthConfig.Currency,
		totalShardsEarned = data.lifetimeStats and data.lifetimeStats.TotalShardsEarned or 0,
		bestRunShards = data.lifetimeStats and data.lifetimeStats.BestRunShards or 0,
		skillTreeBranches = RebirthConfig.SkillTreeBranches,
		skillTreeNodes = buildSkillTreePayload(data),
		lifetimeStats = table.clone(data.lifetimeStats or {}),
		claimedMilestones = setToList(data.claimedMilestones or {}),
		unlockedAuras = setToList(data.unlockedAuras or {}),
		unlockedPortalEffects = setToList(data.unlockedPortalEffects or {}),
		unlockedCosmetics = setToList(data.unlockedCosmetics or {}),
		unlockedTitles = setToList(data.unlockedTitles or {}),
		ascensionBonuses = (function()
			local ok, AscensionBonusService = pcall(function()
				return require(game:GetService("ServerScriptService"):WaitForChild("AscensionBonusService"))
			end)
			if ok then
				return AscensionBonusService.BuildClientPayload(player)
			end
			return {}
		end)(),
		milestoneRewards = (function()
			local ok, RebirthMilestoneService = pcall(function()
				return require(game:GetService("ServerScriptService"):WaitForChild("RebirthMilestoneService"))
			end)
			if ok then
				return RebirthMilestoneService.BuildClientPayload(player)
			end
			return {}
		end)(),
		gateTier = gateTier,
		minimumIslandIndex = RebirthConfig.GetMinimumIslandIndex(rebirthCount),
		preview = preview,
	}
end

function RebirthState.SyncPlayerAttributes(player)
	local data = RebirthState.Get(player)
	player:SetAttribute("RebirthCount", data.rebirthCount or 0)
	player:SetAttribute("AscensionShards", data.ascensionShards or 0)
	player:SetAttribute("LifetimeHighestIslandIndex", data.lifetimeStats.HighestIslandIndex or 0)
	player:SetAttribute("LifetimeHighestKingdomLevel", data.lifetimeStats.HighestKingdomLevel or 1)
end

function RebirthState.UpdateLifetimePeaks(player, snapshot)
	if typeof(snapshot) ~= "table" then
		return
	end
	local data = RebirthState.Get(player)
	local stats = data.lifetimeStats
	stats.HighestIslandIndex = math.max(stats.HighestIslandIndex or 0, math.floor(tonumber(snapshot.highestIslandIndex) or 0))
	stats.HighestKingdomLevel = math.max(stats.HighestKingdomLevel or 1, math.floor(tonumber(snapshot.kingdomLevel) or 1))
	if snapshot.celestialUnlocked == true then
		stats.CelestialClears = math.max(stats.CelestialClears or 0, 1)
	end
end

function RebirthState.CreatePermanentBackup(player)
	local data = RebirthState.Get(player)
	return {
		rebirthCount = data.rebirthCount or 0,
		ascensionShards = data.ascensionShards or 0,
		lifetimeStats = table.clone(data.lifetimeStats or {}),
		claimedMilestones = table.clone(data.claimedMilestones or {}),
		unlockedAuras = table.clone(data.unlockedAuras or {}),
		unlockedPortalEffects = table.clone(data.unlockedPortalEffects or {}),
		unlockedCosmetics = table.clone(data.unlockedCosmetics or {}),
		unlockedTitles = table.clone(data.unlockedTitles or {}),
	}
end

function RebirthState.RestorePermanentBackup(player, backup)
	if typeof(backup) ~= "table" then
		return
	end
	local data = RebirthState.Get(player)
	data.rebirthCount = math.max(0, math.floor(tonumber(backup.rebirthCount) or 0))
	data.ascensionShards = math.max(0, math.floor(tonumber(backup.ascensionShards) or 0))
	if typeof(backup.lifetimeStats) == "table" then
		data.lifetimeStats = table.clone(backup.lifetimeStats)
	end
	if typeof(backup.claimedMilestones) == "table" then
		data.claimedMilestones = table.clone(backup.claimedMilestones)
	end
	if typeof(backup.unlockedAuras) == "table" then
		data.unlockedAuras = table.clone(backup.unlockedAuras)
	end
	if typeof(backup.unlockedPortalEffects) == "table" then
		data.unlockedPortalEffects = table.clone(backup.unlockedPortalEffects)
	end
	if typeof(backup.unlockedCosmetics) == "table" then
		data.unlockedCosmetics = table.clone(backup.unlockedCosmetics)
	end
	if typeof(backup.unlockedTitles) == "table" then
		data.unlockedTitles = table.clone(backup.unlockedTitles)
	end
end

function RebirthState.ApplyRebirthCompletion(player, snapshot, metadata)
	if typeof(snapshot) ~= "table" then
		return
	end

	local data = RebirthState.Get(player)
	local previousCount = data.rebirthCount or 0
	data.rebirthCount = previousCount + 1

	RebirthState.UpdateLifetimePeaks(player, snapshot)

	local stats = data.lifetimeStats
	stats.TotalRebirths = math.max(stats.TotalRebirths or 0, data.rebirthCount)
	stats.LastRebirthAt = os.time()

	if typeof(metadata) == "table" then
		local runShards = math.max(0, math.floor(tonumber(metadata.shardsGranted) or 0))
		if runShards > 0 then
			stats.BestRunShards = math.max(stats.BestRunShards or 0, runShards)
		end
	end
end

return RebirthState
