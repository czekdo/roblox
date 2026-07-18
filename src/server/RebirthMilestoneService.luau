local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthState = require(ServerScriptService:WaitForChild("RebirthState"))

local RebirthMilestoneService = {}

local UNLOCK_FIELD_BY_TYPE = {
	Title = "unlockedTitles",
	Aura = "unlockedAuras",
	PortalEffect = "unlockedPortalEffects",
	Cosmetic = "unlockedCosmetics",
}

local ATTRIBUTE_BY_REWARD_TYPE = {
	Title = "RebirthEquippedTitle",
	Aura = "RebirthEquippedAura",
	PortalEffect = "RebirthEquippedPortalEffect",
	Cosmetic = "RebirthEquippedCosmetic",
}

local function setToList(setTable)
	local list = {}
	if typeof(setTable) ~= "table" then
		return list
	end
	for value in setTable do
		if setTable[value] then
			table.insert(list, value)
		end
	end
	table.sort(list)
	return list
end

local function getHighestUnlockedReward(data, rewardType)
	local fieldName = UNLOCK_FIELD_BY_TYPE[rewardType]
	if not fieldName or typeof(data[fieldName]) ~= "table" then
		return nil
	end

	local bestId = nil
	local bestCount = 0
	for _, milestone in RebirthConfig.Milestones do
		if milestone.RewardType == rewardType and milestone.RewardId and data[fieldName][milestone.RewardId] == true then
			local requiredCount = math.floor(tonumber(milestone.RebirthCount) or 0)
			if requiredCount >= bestCount then
				bestCount = requiredCount
				bestId = milestone.RewardId
			end
		end
	end
	return bestId
end

local function getMilestoneKey(milestone)
	return string.format("Rebirth_%d", milestone.RebirthCount)
end

local function grantMilestone(data, milestone)
	local fieldName = UNLOCK_FIELD_BY_TYPE[milestone.RewardType]
	if fieldName and typeof(data[fieldName]) == "table" and typeof(milestone.RewardId) == "string" then
		data[fieldName][milestone.RewardId] = true
	end
	data.claimedMilestones[getMilestoneKey(milestone)] = true
end

function RebirthMilestoneService.GrantPendingMilestones(player, rebirthCount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return {}
	end
	if not RebirthState.IsLoaded(player) then
		return {}
	end

	local numericCount = math.max(0, math.floor(tonumber(rebirthCount) or 0))
	local data = RebirthState.Get(player)
	local granted = {}

	for _, milestone in RebirthConfig.Milestones do
		local requiredCount = math.floor(tonumber(milestone.RebirthCount) or 0)
		if requiredCount > 0 and numericCount >= requiredCount then
			local key = getMilestoneKey(milestone)
			if data.claimedMilestones[key] ~= true then
				grantMilestone(data, milestone)
				table.insert(granted, {
					rebirthCount = requiredCount,
					rewardType = milestone.RewardType,
					rewardId = milestone.RewardId,
					displayName = milestone.DisplayName,
					description = milestone.Description,
				})
			end
		end
	end

	return granted
end

function RebirthMilestoneService.OnRebirthCompleted(player, newRebirthCount)
	local granted = RebirthMilestoneService.GrantPendingMilestones(player, newRebirthCount)
	RebirthMilestoneService.SyncPlayerAttributes(player)
	return granted
end

function RebirthMilestoneService.SyncPlayer(player)
	local granted = RebirthMilestoneService.GrantPendingMilestones(player, RebirthState.GetRebirthCount(player))
	RebirthMilestoneService.SyncPlayerAttributes(player)
	return granted
end

function RebirthMilestoneService.SyncPlayerAttributes(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if not RebirthState.IsLoaded(player) then
		return
	end

	local data = RebirthState.Get(player)
	for rewardType, attributeName in ATTRIBUTE_BY_REWARD_TYPE do
		local equippedId = getHighestUnlockedReward(data, rewardType)
		player:SetAttribute(attributeName, equippedId)
	end

	player:SetAttribute("RebirthUnlockedTitleCount", #setToList(data.unlockedTitles))
	player:SetAttribute("RebirthUnlockedAuraCount", #setToList(data.unlockedAuras))
	player:SetAttribute("RebirthUnlockedPortalEffectCount", #setToList(data.unlockedPortalEffects))
	player:SetAttribute("RebirthUnlockedCosmeticCount", #setToList(data.unlockedCosmetics))
end

function RebirthMilestoneService.BuildClientPayload(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return {}
	end
	if not RebirthState.IsLoaded(player) then
		return {}
	end

	local data = RebirthState.Get(player)
	local milestones = {}
	for _, milestone in RebirthConfig.Milestones do
		local fieldName = UNLOCK_FIELD_BY_TYPE[milestone.RewardType]
		local key = getMilestoneKey(milestone)
		local unlocked = fieldName
			and typeof(data[fieldName]) == "table"
			and data[fieldName][milestone.RewardId] == true
		table.insert(milestones, {
			rebirthCount = milestone.RebirthCount,
			rewardType = milestone.RewardType,
			rewardId = milestone.RewardId,
			displayName = milestone.DisplayName,
			description = milestone.Description,
			claimed = data.claimedMilestones[key] == true,
			unlocked = unlocked == true,
		})
	end

	return {
		milestones = milestones,
		equippedTitle = getHighestUnlockedReward(data, "Title"),
		equippedAura = getHighestUnlockedReward(data, "Aura"),
		equippedPortalEffect = getHighestUnlockedReward(data, "PortalEffect"),
		equippedCosmetic = getHighestUnlockedReward(data, "Cosmetic"),
	}
end

return RebirthMilestoneService
