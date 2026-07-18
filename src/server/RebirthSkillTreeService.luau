local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthState = require(ServerScriptService:WaitForChild("RebirthState"))
local AscensionShardService = require(ServerScriptService:WaitForChild("AscensionShardService"))
local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))

local RebirthSkillTreeService = {}

local function isPlayerLocked(player)
	local orchestrator = _G.RebirthOrchestrator
	return orchestrator and orchestrator.IsLocked and orchestrator.IsLocked(player)
end

local function prerequisitesMet(player, node)
	for _, prerequisiteId in node.Prerequisites or {} do
		if RebirthState.GetSkillTreeRank(player, prerequisiteId) <= 0 then
			return false, prerequisiteId
		end
	end
	return true
end

local function buildNodePurchaseState(player, nodeId)
	local node = RebirthConfig.GetSkillTreeNode(nodeId)
	if not node then
		return nil
	end

	local currentRank = RebirthState.GetSkillTreeRank(player, nodeId)
	local maxRank = node.MaxRank or 1
	local nextCost = RebirthConfig.GetNodeCost(nodeId, currentRank)
	local prereqOk, missingPrereq = prerequisitesMet(player, node)

	return {
		id = node.Id,
		currentRank = currentRank,
		maxRank = maxRank,
		nextCost = nextCost,
		prerequisitesMet = prereqOk,
		missingPrerequisite = missingPrereq,
		canPurchase = prereqOk and currentRank < maxRank and nextCost ~= nil and AscensionShardService.CanAfford(player, nextCost),
		atMaxRank = currentRank >= maxRank,
	}
end

function RebirthSkillTreeService.GetPurchasePreview(player, nodeId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return { ok = false, message = "Invalid player." }
	end
	if not RebirthState.IsLoaded(player) then
		return { ok = false, message = "Rebirth data not loaded." }
	end
	if typeof(nodeId) ~= "string" then
		return { ok = false, message = "Invalid skill node." }
	end

	local node = RebirthConfig.GetSkillTreeNode(nodeId)
	if not node then
		return { ok = false, message = "Unknown skill node." }
	end

	return {
		ok = true,
		node = buildNodePurchaseState(player, nodeId),
		ascensionShards = AscensionShardService.GetBalance(player),
	}
end

function RebirthSkillTreeService.Purchase(player, nodeId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return { success = false, message = "Invalid player." }
	end
	if not RebirthState.IsLoaded(player) then
		return { success = false, message = "Rebirth data not loaded." }
	end
	if isPlayerLocked(player) then
		return { success = false, message = "Cannot purchase skills during Rebirth." }
	end
	if typeof(nodeId) ~= "string" then
		return { success = false, message = "Invalid skill node." }
	end

	local node = RebirthConfig.GetSkillTreeNode(nodeId)
	if not node then
		return { success = false, message = "Unknown skill node." }
	end
	if node.Disabled == true then
		return { success = false, message = "This skill is not available yet." }
	end

	local currentRank = RebirthState.GetSkillTreeRank(player, nodeId)
	if currentRank >= (node.MaxRank or 1) then
		return { success = false, message = "This skill is already maxed." }
	end

	local prereqOk, missingPrereq = prerequisitesMet(player, node)
	if not prereqOk then
		local missingNode = RebirthConfig.GetSkillTreeNode(missingPrereq)
		local label = missingNode and missingNode.DisplayName or missingPrereq
		return { success = false, message = string.format("Unlock %s first.", label) }
	end

	local cost = RebirthConfig.GetNodeCost(nodeId, currentRank)
	if not cost then
		return { success = false, message = "This skill cannot be upgraded further." }
	end

	local spendResult = AscensionShardService.TrySpend(player, cost, "SkillTree", {
		nodeId = nodeId,
		previousRank = currentRank,
		nextRank = currentRank + 1,
	})
	if not spendResult.success then
		return {
			success = false,
			message = spendResult.message or "Not enough Ascension Shards.",
			balance = spendResult.balance,
		}
	end

	local data = RebirthState.Get(player)
	data.skillTreeNodes[nodeId] = currentRank + 1
	AscensionBonusService.RefreshPlayer(player)

	return {
			success = true,
			message = string.format("Purchased %s (Rank %d).", node.DisplayName, currentRank + 1),
			nodeId = nodeId,
			previousRank = currentRank,
			newRank = currentRank + 1,
			cost = cost,
			balance = spendResult.balance,
			node = buildNodePurchaseState(player, nodeId),
			bonuses = AscensionBonusService.BuildClientPayload(player),
	}
end

return RebirthSkillTreeService
