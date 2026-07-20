local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))

local SellEvents = ReplicatedStorage:WaitForChild("SellEvents")
local RequestSellableDragons = SellEvents:WaitForChild("RequestSellableDragons")
local SellDragons = SellEvents:WaitForChild("SellDragons")
local SellResult = SellEvents:WaitForChild("SellResult")

local MAX_SELL_BATCH = 200

RequestSellableDragons.OnServerInvoke = function(player)
	local found, list = AdminBridge.call("Trading", "listStorageDragons", player)
	if not found or typeof(list) ~= "table" then
		return {}
	end
	local result = {}
	for _, d in list do
		table.insert(result, {
			id = d.id,
			dragonType = d.dragonType,
			displayName = d.displayName,
			rarity = d.rarity,
			level = d.level,
			evolutionLevel = d.evolutionLevel,
			sellValue = DragonEggConfig.GetDragonSellValue(d.rarity, d.level, d.evolutionLevel, d.dragonType),
		})
	end
	return result
end

-- dragonIds: array of storage dragon ids (client picks which ones via its own filter UI; the
-- server re-validates each against the player's actual current storage list below, so a stale or
-- forged id list can't sell dragons that don't exist or aren't this player's).
SellDragons.OnServerEvent:Connect(function(player, dragonIds)
	if not RateLimiter.check(player, "SellDragons", 0.5) then
		return
	end
	if typeof(dragonIds) ~= "table" then
		return
	end
	local found, ownedList = AdminBridge.call("Trading", "listStorageDragons", player)
	if not found or typeof(ownedList) ~= "table" then
		return
	end
	local ownedById = {}
	for _, d in ownedList do
		ownedById[d.id] = d
	end

	local totalValue = 0
	local soldCount = 0
	local seen = {}
	for _, id in dragonIds do
		local numId = tonumber(id)
		if numId and not seen[numId] and soldCount < MAX_SELL_BATCH then
			local record = ownedById[numId]
			if record then
				seen[numId] = true
				local value = DragonEggConfig.GetDragonSellValue(record.rarity, record.level, record.evolutionLevel, record.dragonType)
				local removeFound, removed = AdminBridge.call("Trading", "removeStorageDragon", player, numId)
				if removeFound and removed then
					totalValue += value
					soldCount += 1
				end
			end
		end
	end

	if soldCount > 0 then
		AdminBridge.call("Harvest", "adjustEssence", player, totalValue)
	end

	SellResult:FireClient(player, {
		success = soldCount > 0,
		count = soldCount,
		totalValue = totalValue,
		message = soldCount > 0
			and ("Sold " .. soldCount .. " dragon(s) for " .. totalValue .. " Essence")
			or "Nothing sold - selection may be out of date.",
	})
end)

print("[SellShopManager] Sell shop ready")
