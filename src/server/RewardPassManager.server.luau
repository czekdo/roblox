local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RewardService = require(ServerScriptService:WaitForChild("RewardService"))

local RewardPassEvents = ReplicatedStorage:WaitForChild("RewardPassEvents")
local RequestRewardPassState = RewardPassEvents:WaitForChild("RequestRewardPassState")
local ClaimFreeReward = RewardPassEvents:WaitForChild("ClaimFreeReward")
local ClaimPremiumReward = RewardPassEvents:WaitForChild("ClaimPremiumReward")
local RewardPassResult = RewardPassEvents:WaitForChild("RewardPassResult")

-- One-time-ever rewards showcasing what Free vs VIP gets, side by side, to nudge players toward
-- the VIP Pass. The Royal Dragon itself is granted separately by MonetizationService the moment
-- VIP ownership is detected - it's listed here only as a showcase row, not a third claimable item.
local FREE_REWARD = { Type = "InventoryItem", ItemId = "EssenceBoost", Amount = 1, Text = "+1 Essence Boost Potion" }
local PREMIUM_REWARD = { Type = "InventoryItem", ItemId = "GrandElixir", Amount = 1, Text = "+1 Grand Elixir" }

local claimStore = nil
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("DragonIslandRewardPassClaimsV1")
	end)
	if success then
		claimStore = result
	else
		warn("[RewardPassManager] Claim DataStore unavailable:", result)
	end
end

local playerClaims = {}

local function loadClaims(player)
	local claims = { Free = false, Premium = false }
	if claimStore then
		local success, result = pcall(function()
			return claimStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			claims.Free = result.Free == true
			claims.Premium = result.Premium == true
		end
	end
	playerClaims[player] = claims
	return claims
end

RequestRewardPassState.OnServerInvoke = function(player)
	local claims = playerClaims[player] or loadClaims(player)
	return {
		freeClaimed = claims.Free,
		premiumClaimed = claims.Premium,
		ownsVip = player:GetAttribute("OwnsVIP") == true,
	}
end

-- Same idempotent DataStore-flag pattern as MonetizationService's VIP dragon grant: the claim is
-- persisted BEFORE returning success, so a client retry or repeated click can't double-grant.
local function tryClaim(player, tier, reward)
	local claims = playerClaims[player] or loadClaims(player)
	if claims[tier] then
		return false, "Already claimed"
	end
	if not claimStore then
		return false, "Try again later"
	end

	local granted = false
	local success, result = pcall(function()
		return claimStore:UpdateAsync(tostring(player.UserId), function(current)
			current = typeof(current) == "table" and current or {}
			if current[tier] then
				return current
			end
			local grantOk = pcall(function()
				RewardService.Grant(player, reward, { Source = "RewardPass" })
			end)
			if not grantOk then
				return current
			end
			current[tier] = true
			granted = true
			return current
		end)
	end)

	if not success then
		warn("[RewardPassManager] Failed to process claim for", player.Name, tier, result)
		return false, "Try again later"
	end
	if granted then
		claims[tier] = true
	end
	return granted, granted and "Claimed!" or "Already claimed"
end

ClaimFreeReward.OnServerEvent:Connect(function(player)
	local ok, message = tryClaim(player, "Free", FREE_REWARD)
	RewardPassResult:FireClient(player, { tier = "Free", success = ok, message = message })
end)

ClaimPremiumReward.OnServerEvent:Connect(function(player)
	if player:GetAttribute("OwnsVIP") ~= true then
		RewardPassResult:FireClient(player, { tier = "Premium", success = false, message = "Requires VIP Pass" })
		return
	end
	local ok, message = tryClaim(player, "Premium", PREMIUM_REWARD)
	RewardPassResult:FireClient(player, { tier = "Premium", success = ok, message = message })
end)

Players.PlayerRemoving:Connect(function(player)
	playerClaims[player] = nil
end)

print("[RewardPassManager] Reward pass ready")
