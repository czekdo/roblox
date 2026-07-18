local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthState = require(script.Parent:WaitForChild("RebirthState"))
local RebirthScoreCalculator = require(script.Parent:WaitForChild("RebirthScoreCalculator"))

local AscensionShardService = {}

local saveCallback = nil
local stateUpdateCallback = nil

local VALID_SOURCES = {
	Rebirth = true,
	Admin = true,
	Milestone = true,
	Refund = true,
	Debug = true,
}

local VALID_SPEND_REASONS = {
	SkillTree = true,
	Admin = true,
	Refund = true,
}

function AscensionShardService.SetCallbacks(options)
	if typeof(options) ~= "table" then
		return
	end
	if typeof(options.onSave) == "function" then
		saveCallback = options.onSave
	end
	if typeof(options.onStateUpdated) == "function" then
		stateUpdateCallback = options.onStateUpdated
	end
end

local function notifyChanged(player, changeType, metadata)
	if stateUpdateCallback then
		stateUpdateCallback(player, changeType, metadata)
	end
	if saveCallback then
		saveCallback(player)
	end
end

function AscensionShardService.GetBalance(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return 0
	end
	return RebirthState.GetAscensionShards(player)
end

function AscensionShardService.CanAfford(player, amount)
	local numericAmount = math.max(0, math.floor(tonumber(amount) or 0))
	if numericAmount <= 0 then
		return true
	end
	return AscensionShardService.GetBalance(player) >= numericAmount
end

function AscensionShardService.CalculateReward(snapshot)
	return RebirthScoreCalculator.Calculate(snapshot)
end

function AscensionShardService.Grant(player, amount, source, metadata)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return {
			success = false,
			message = "Invalid player.",
		}
	end
	if not RebirthState.IsLoaded(player) then
		return {
			success = false,
			message = "Rebirth data not loaded.",
		}
	end

	local numericAmount = math.max(0, math.floor(tonumber(amount) or 0))
	if numericAmount <= 0 then
		return {
			success = false,
			message = "Grant amount must be positive.",
			balance = AscensionShardService.GetBalance(player),
		}
	end

	local grantSource = typeof(source) == "string" and source or "Debug"
	if not VALID_SOURCES[grantSource] then
		grantSource = "Debug"
	end

	local data = RebirthState.Get(player)
	local previousBalance = data.ascensionShards or 0
	data.ascensionShards = previousBalance + numericAmount

	local stats = data.lifetimeStats
	stats.TotalShardsEarned = math.max(0, math.floor(tonumber(stats.TotalShardsEarned) or 0)) + numericAmount

	if grantSource == "Rebirth" then
		local runShards = math.max(0, math.floor(tonumber(metadata and metadata.runShards) or numericAmount))
		stats.BestRunShards = math.max(stats.BestRunShards or 0, runShards)
	end

	RebirthState.SyncPlayerAttributes(player)
	notifyChanged(player, "Grant", {
		source = grantSource,
		amount = numericAmount,
		previousBalance = previousBalance,
		newBalance = data.ascensionShards,
		metadata = metadata,
	})

	return {
		success = true,
		message = string.format("Granted %d %s.", numericAmount, RebirthConfig.Currency.DisplayName),
		amountGranted = numericAmount,
		previousBalance = previousBalance,
		balance = data.ascensionShards,
		source = grantSource,
	}
end

function AscensionShardService.TrySpend(player, amount, reason, metadata)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return {
			success = false,
			message = "Invalid player.",
		}
	end
	if not RebirthState.IsLoaded(player) then
		return {
			success = false,
			message = "Rebirth data not loaded.",
		}
	end

	local numericAmount = math.max(0, math.floor(tonumber(amount) or 0))
	if numericAmount <= 0 then
		return {
			success = false,
			message = "Spend amount must be positive.",
			balance = AscensionShardService.GetBalance(player),
		}
	end

	local spendReason = typeof(reason) == "string" and reason or "Admin"
	if not VALID_SPEND_REASONS[spendReason] then
		return {
			success = false,
			message = "Invalid spend reason.",
			balance = AscensionShardService.GetBalance(player),
		}
	end

	local data = RebirthState.Get(player)
	local previousBalance = data.ascensionShards or 0
	if previousBalance < numericAmount then
		return {
			success = false,
			message = string.format("Need %d %s.", numericAmount, RebirthConfig.Currency.DisplayName),
			balance = previousBalance,
			deficit = numericAmount - previousBalance,
		}
	end

	data.ascensionShards = previousBalance - numericAmount
	RebirthState.SyncPlayerAttributes(player)
	notifyChanged(player, "Spend", {
		reason = spendReason,
		amount = numericAmount,
		previousBalance = previousBalance,
		newBalance = data.ascensionShards,
		metadata = metadata,
	})

	return {
		success = true,
		message = string.format("Spent %d %s.", numericAmount, RebirthConfig.Currency.DisplayName),
		amountSpent = numericAmount,
		previousBalance = previousBalance,
		balance = data.ascensionShards,
		reason = spendReason,
	}
end

function AscensionShardService.SetBalance(player, amount, source)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return {
			success = false,
			message = "Invalid player.",
		}
	end
	if not RebirthState.IsLoaded(player) then
		return {
			success = false,
			message = "Rebirth data not loaded.",
		}
	end

	local targetBalance = math.max(0, math.floor(tonumber(amount) or 0))
	local data = RebirthState.Get(player)
	local previousBalance = data.ascensionShards or 0
	local delta = targetBalance - previousBalance

	if delta > 0 then
		return AscensionShardService.Grant(player, delta, source or "Admin", {
			setBalance = true,
			targetBalance = targetBalance,
		})
	elseif delta < 0 then
		return AscensionShardService.TrySpend(player, -delta, "Admin", {
			setBalance = true,
			targetBalance = targetBalance,
		})
	end

	return {
		success = true,
		message = "Balance unchanged.",
		balance = previousBalance,
	}
end

function AscensionShardService.BuildPreviewPayload(player, validation, score, snapshot)
	local currentShards = AscensionShardService.GetBalance(player)
	local projectedShards = math.max(0, math.floor(tonumber(validation and validation.projectedShards) or 0))
	local eligible = validation and validation.eligible == true

	return {
		loaded = true,
		eligible = eligible,
		reason = validation and validation.reason or nil,
		reasons = validation and validation.reasons or {},
		minimumGateMet = validation and validation.minimumGateMet == true,
		recommendedGateMet = validation and validation.recommendedGateMet == true,
		nextRebirthNumber = validation and validation.nextRebirthNumber or 1,
		currentShards = currentShards,
		projectedShards = projectedShards,
		projectedTotalShards = currentShards + (eligible and projectedShards or 0),
		currency = RebirthConfig.Currency,
		scoreBreakdown = validation and validation.scoreBreakdown or score.breakdown,
		gateTier = validation and validation.gateTier or score.gateTier,
		requirements = validation and validation.requirements or {},
		runSnapshot = {
			highestIslandIndex = snapshot.highestIslandIndex,
			highestIslandId = snapshot.highestIslandId,
			kingdomLevel = snapshot.kingdomLevel,
			lifetimeEssence = snapshot.lifetimeEssence,
			currentEssence = snapshot.currentEssence,
			celestialUnlocked = snapshot.celestialUnlocked,
			avgBuildingLevel = snapshot.avgBuildingLevel,
			maxBuildingLevel = snapshot.maxBuildingLevel,
			lifetimeHatches = snapshot.lifetimeHatches,
			maxEvolutionStars = snapshot.maxEvolutionStars,
		},
	}
end

return AscensionShardService
