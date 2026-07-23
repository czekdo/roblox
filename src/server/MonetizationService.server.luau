local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MonetizationConfig = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

-- ============================================================
-- Developer products (Gems packs, etc.) — ProcessReceipt
-- ============================================================
-- Idempotent-grant pattern per Roblox's official ProcessReceipt guidance: a purchase is only
-- granted once, recorded in a DataStore keyed by PurchaseId, so retried/duplicate receipts don't
-- double-grant. See https://create.roblox.com/docs/reference/engine/classes/MarketplaceService.

local purchaseHistoryStore = nil
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("DragonIslandPurchaseHistoryV1")
	end)
	if success then
		purchaseHistoryStore = result
	else
		warn("[MonetizationService] Purchase history DataStore unavailable:", result)
	end
end

local function grantDeveloperProduct(receiptInfo, player)
	local product = MonetizationConfig.GetProductById(receiptInfo.ProductId)
	if not product then
		warn("[MonetizationService] No product configured for ProductId", receiptInfo.ProductId)
		return false
	end
	local applied = RewardService.Grant(player, product.Reward, { Source = "Purchase" })
	return applied ~= nil
end

local function processReceipt(receiptInfo)
	if not purchaseHistoryStore then
		-- No DataStore (unpublished place) - can't record idempotently, so refuse to auto-grant
		-- to avoid double-granting; real purchases only happen on published places anyway.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local success, result = pcall(function()
		return purchaseHistoryStore:UpdateAsync(receiptInfo.PurchaseId, function(isGranted)
			if isGranted then
				return true
			end

			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if not player then
				return nil
			end

			local grantOk, grantResult = pcall(grantDeveloperProduct, receiptInfo, player)
			if not grantOk then
				warn("[MonetizationService] Grant handler errored for", player.Name, grantResult)
				return nil
			end
			if grantResult ~= true then
				return nil
			end

			return true
		end)
	end)

	if not success then
		warn("[MonetizationService] Failed to process receipt due to DataStore error:", result)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if result == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.ProcessReceipt = processReceipt

-- ============================================================
-- VIP Pass exclusive dragon — granted once, ever, per player.
-- ============================================================
-- Same idempotent-grant pattern as processReceipt above, but keyed by UserId instead of
-- PurchaseId (a GamePass is a single permanent ownership flag, not a repeatable receipt). Tracked
-- in its own DataStore rather than "grant if not currently in storage/roster", so selling the
-- dragon doesn't let a VIP owner farm infinite essence by selling and rejoining.

local vipDragonGrantStore = nil
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore("DragonIslandVipDragonGrantV1")
	end)
	if success then
		vipDragonGrantStore = result
	else
		warn("[MonetizationService] VIP dragon grant DataStore unavailable:", result)
	end
end

local function grantVipDragonOnce(player)
	if not player:GetAttribute("OwnsVIP") or not vipDragonGrantStore then
		return
	end
	local success, result = pcall(function()
		return vipDragonGrantStore:UpdateAsync(tostring(player.UserId), function(isGranted)
			if isGranted then
				return true
			end
			local grantOk = pcall(function()
				AdminBridge.call("Trading", "grantStorageDragon", player, {
					dragonType = "VipDragon",
					rarity = "Epic",
					level = 1,
					evolutionLevel = 0,
				})
			end)
			if not grantOk then
				return nil
			end
			return true
		end)
	end)
	if not success then
		warn("[MonetizationService] Failed to process VIP dragon grant for", player.Name, result)
	end
end

-- ============================================================
-- Game passes — ownership cached as a player attribute so other
-- systems can read it cheaply (player:GetAttribute(pass.AttributeName)).
-- ============================================================

local function refreshGamePassOwnership(player)
	for _, pass in MonetizationConfig.GamePasses do
		if pass.Id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok then
				player:SetAttribute(pass.AttributeName, owns)
				if pass.Key == "VIP" and owns then
					grantVipDragonOnce(player)
				end
			else
				warn("[MonetizationService] Failed to check GamePass ownership for", player.Name, pass.Key, owns)
			end
		end
	end
end

Players.PlayerAdded:Connect(refreshGamePassOwnership)
for _, player in Players:GetPlayers() do
	task.spawn(refreshGamePassOwnership, player)
end

-- Update the attribute immediately after a successful in-game GamePass purchase, so perks apply
-- without requiring a rejoin.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then
		return
	end
	for _, pass in MonetizationConfig.GamePasses do
		if pass.Id == gamePassId then
			player:SetAttribute(pass.AttributeName, true)
			if pass.Key == "VIP" then
				grantVipDragonOnce(player)
			end
			break
		end
	end
end)

AdminBridge.register("Monetization", {
	grantVip = function(player)
		player:SetAttribute("OwnsVIP", true)
		grantVipDragonOnce(player)
		return "VIP granted"
	end,
})

-- Checked dynamically (not just printed once and forgotten) so this warns again if a future
-- GamePass/DeveloperProduct ever gets added with its Id left at the 0 placeholder.
local function hasPlaceholderIds()
	for _, pass in MonetizationConfig.GamePasses do
		if not pass.Id or pass.Id == 0 then
			return true
		end
	end
	for _, product in MonetizationConfig.DeveloperProducts do
		if not product.Id or product.Id == 0 then
			return true
		end
	end
	return false
end

if hasPlaceholderIds() then
	warn("[MonetizationService] Some GamePass/DeveloperProduct IDs are still placeholders (0) - fill them in in MonetizationConfig.luau before publishing.")
else
	print("[MonetizationService] Monetization ready")
end
