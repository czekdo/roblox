local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))

local TutorialEvents = ReplicatedStorage:WaitForChild("TutorialEvents")
local GrantTutorialRewardEgg = TutorialEvents:WaitForChild("GrantTutorialRewardEgg")
local KingdomEvents = ReplicatedStorage:WaitForChild("KingdomEvents")
local GrantDecoration = KingdomEvents:WaitForChild("GrantDecoration")
local HarvestUIUpdate = ReplicatedStorage:WaitForChild("HarvestEvents"):WaitForChild("HarvestUIUpdate")

-- Reward shape: { Type = string, ...type-specific fields, Text = string? }
-- Supported types: DragonEssence, PremiumCurrency, Eggs, ExclusiveEgg, TemporaryBoost,
-- Title, EquipTitle, CosmeticBadge, EquipBadge, Decoration.
-- context = { Source = string, ApplyAscensionBonus = boolean?, NotifyUI = boolean? }

local RewardService = {}

-- Only these types carry a currency-like `Amount` that ascension reward bonuses scale.
local AMOUNT_SCALED_TYPES = {
	DragonEssence = true,
	PremiumCurrency = true,
	Eggs = true,
}

local handlers = {}

local function scaledAmount(player, reward, context)
	local amount = reward.Amount or 0
	if context.ApplyAscensionBonus and AMOUNT_SCALED_TYPES[reward.Type] then
		amount = AscensionBonusService.ApplyRewardMultiplier(player, amount, tostring(context.Source) .. "RewardBonus")
	end
	return amount
end

handlers.DragonEssence = function(player, reward, context)
	local amount = scaledAmount(player, reward, context)
	local essence = (player:GetAttribute("DragonEssence") or 0) + amount
	player:SetAttribute("DragonEssence", essence)
	if context.NotifyUI then
		HarvestUIUpdate:FireClient(player, essence)
	end
	return { Type = "DragonEssence", Amount = amount }
end

handlers.PremiumCurrency = function(player, reward, context)
	local amount = scaledAmount(player, reward, context)
	local gems = (player:GetAttribute("PremiumGems") or 0) + amount
	player:SetAttribute("PremiumGems", gems)
	return { Type = "PremiumCurrency", Amount = amount }
end

handlers.Eggs = function(player, reward, context)
	local amount = scaledAmount(player, reward, context)
	local questEggs = (player:GetAttribute("QuestEggs") or 0) + amount
	player:SetAttribute("QuestEggs", questEggs)
	return { Type = "Eggs", Amount = amount }
end

handlers.ExclusiveEgg = function(player, reward, _context)
	if typeof(reward.EggType) == "string" then
		GrantTutorialRewardEgg:Fire(player, reward.EggType)
	end
	return { Type = "ExclusiveEgg", EggType = reward.EggType }
end

handlers.TemporaryBoost = function(player, reward, _context)
	local expiresAt = os.time() + (reward.Duration or 0)
	local multiplier = reward.Multiplier or 1
	player:SetAttribute(reward.BoostId .. "Multiplier", multiplier)
	player:SetAttribute(reward.BoostId .. "ExpiresAt", expiresAt)
	return { Type = "TemporaryBoost", BoostId = reward.BoostId, Multiplier = multiplier, ExpiresAt = expiresAt }
end

handlers.Title = function(player, reward, _context)
	player:SetAttribute("UnlockedTitle_" .. reward.TitleId, true)
	return { Type = "Title", TitleId = reward.TitleId }
end

handlers.EquipTitle = function(player, reward, _context)
	player:SetAttribute("TutorialEquippedTitle", reward.TitleId)
	return { Type = "EquipTitle", TitleId = reward.TitleId }
end

handlers.CosmeticBadge = function(player, reward, _context)
	player:SetAttribute("UnlockedBadge_" .. reward.BadgeId, true)
	return { Type = "CosmeticBadge", BadgeId = reward.BadgeId }
end

handlers.EquipBadge = function(player, reward, _context)
	player:SetAttribute("TutorialBadge", reward.BadgeId)
	return { Type = "EquipBadge", BadgeId = reward.BadgeId }
end

handlers.Decoration = function(player, reward, _context)
	GrantDecoration:Fire(player, reward.DecorationId)
	return { Type = "Decoration", DecorationId = reward.DecorationId }
end

-- Extension point: RewardService.RegisterHandler("NewType", function(player, reward, context) ... end)
function RewardService.RegisterHandler(rewardType, handlerFn)
	handlers[rewardType] = handlerFn
end

-- Grants one reward table. Returns an AppliedReward summary the caller can use for its own
-- bookkeeping (e.g. syncing an in-memory mirror) or for building UI/log text, or nil if the
-- reward was malformed / had no registered handler.
function RewardService.Grant(player, reward, context)
	if typeof(reward) ~= "table" or typeof(reward.Type) ~= "string" then
		return nil
	end
	context = context or {}
	local handler = handlers[reward.Type]
	if not handler then
		warn("[RewardService] No handler registered for reward type", reward.Type)
		return nil
	end
	return handler(player, reward, context)
end

-- Grants a list of reward tables in order. Returns the list of AppliedReward summaries
-- (skipping any malformed entries).
function RewardService.GrantMany(player, rewards, context)
	local applied = {}
	if typeof(rewards) ~= "table" then
		return applied
	end
	for _, reward in rewards do
		local result = RewardService.Grant(player, reward, context)
		if result then
			table.insert(applied, result)
		end
	end
	return applied
end

return RewardService
