local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local InventoryItemConfig = require(ReplicatedStorage:WaitForChild("InventoryItemConfig"))
local WorkshopCraftConfig = require(ReplicatedStorage:WaitForChild("WorkshopCraftConfig"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))

local InventoryEvents = ReplicatedStorage:WaitForChild("InventoryEvents")
local RequestInventoryData = InventoryEvents:WaitForChild("RequestInventoryData")
local UseInventoryItem = InventoryEvents:WaitForChild("UseInventoryItem")
local InventoryStateUpdated = InventoryEvents:WaitForChild("InventoryStateUpdated")
local GrantInventoryItem = InventoryEvents:WaitForChild("GrantInventoryItem")
local SellInventoryItem = InventoryEvents:WaitForChild("SellInventoryItem")

-- Sell value is half of whatever recipe crafts this item (a fair "recover some investment" price,
-- consistent across every craftable item without hand-maintaining a second price list).
local function getItemSellValue(itemId)
	for _, recipe in WorkshopCraftConfig.Recipes do
		if recipe.Reward and recipe.Reward.Type == "InventoryItem" and recipe.Reward.ItemId == itemId then
			return math.floor((recipe.Cost or 0) * 0.5)
		end
	end
	return 0
end

local INVENTORY_DATASTORE = "DragonIslandInventoryV1"
local inventoryStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(INVENTORY_DATASTORE)
	end)
	if success then
		inventoryStore = result
		dataStoreAvailable = true
	else
		warn("[DragonInventoryManager] Inventory DataStore unavailable; items will not persist until publishing:", result)
	end
end

local playerData = {}
local saveQueued = {}

local function normalizeItems(raw)
	local items = {}
	if typeof(raw) == "table" then
		for itemId, count in raw do
			if InventoryItemConfig.GetItem(itemId) and tonumber(count) and tonumber(count) > 0 then
				items[itemId] = math.floor(tonumber(count))
			end
		end
	end
	return items
end

local function serializeForClient(player)
	local data = playerData[player]
	local items = {}
	if data then
		for itemId, count in data.Items do
			local itemDef = InventoryItemConfig.GetItem(itemId)
			if itemDef and count > 0 then
				table.insert(items, {
					itemId = itemId,
					displayName = itemDef.DisplayName,
					description = itemDef.Description,
					count = count,
				})
			end
		end
	end
	table.sort(items, function(a, b)
		return a.displayName < b.displayName
	end)
	return { items = items }
end

local function sendState(player, message)
	local payload = serializeForClient(player)
	payload.message = message
	InventoryStateUpdated:FireClient(player, payload)
end

local function saveDataNow(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not inventoryStore then
		return
	end
	local payload = {
		Items = data.Items,
		UpdatedAt = os.time(),
	}
	local success, err = pcall(function()
		inventoryStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
	if not success then
		warn("[DragonInventoryManager] Failed to save inventory for", player.UserId, err)
	end
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(8, function()
		saveQueued[player] = nil
		if player.Parent then
			saveDataNow(player)
		end
	end)
end

local function loadPlayerData(player)
	local data = { Items = {} }
	if dataStoreAvailable and inventoryStore then
		local success, result = pcall(function()
			return inventoryStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			data.Items = normalizeItems(result.Items)
		elseif not success then
			warn("[DragonInventoryManager] Failed to load inventory for", player.UserId, result)
		end
	end
	playerData[player] = data
	sendState(player)
end

local function addItem(player, itemId, amount)
	local data = playerData[player]
	local itemDef = InventoryItemConfig.GetItem(itemId)
	if not data or not itemDef then
		return
	end
	amount = math.floor(tonumber(amount) or 1)
	if amount < 1 then
		return
	end
	data.Items[itemId] = (data.Items[itemId] or 0) + amount
	sendState(player, "+" .. tostring(amount) .. " " .. itemDef.DisplayName)
	queueSave(player)
end

GrantInventoryItem.Event:Connect(function(player, itemId, amount)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(itemId) ~= "string" then
		return
	end
	addItem(player, itemId, amount)
end)

RequestInventoryData.OnServerInvoke = function(player)
	if not playerData[player] then
		loadPlayerData(player)
	end
	return serializeForClient(player)
end

UseInventoryItem.OnServerEvent:Connect(function(player, itemId)
	if not RateLimiter.check(player, "UseInventoryItem", 0.3) then
		return
	end
	itemId = tostring(itemId or "")
	local data = playerData[player]
	local itemDef = InventoryItemConfig.GetItem(itemId)
	if not data or not itemDef then
		return
	end

	local owned = data.Items[itemId] or 0
	if owned < 1 then
		sendState(player, "You don't have that item")
		return
	end

	data.Items[itemId] = owned - 1
	if data.Items[itemId] <= 0 then
		data.Items[itemId] = nil
	end

	RewardService.Grant(player, itemDef.Effect, { Source = "Inventory", ApplyAscensionBonus = false, NotifyUI = true })
	sendState(player, "Used " .. itemDef.DisplayName)
	queueSave(player)
end)

-- amount: how many to sell. Clamped to what's actually owned, so a stale client-side count can't
-- oversell.
SellInventoryItem.OnServerEvent:Connect(function(player, itemId, amount)
	if not RateLimiter.check(player, "SellInventoryItem", 0.3) then
		return
	end
	itemId = tostring(itemId or "")
	local data = playerData[player]
	local itemDef = InventoryItemConfig.GetItem(itemId)
	if not data or not itemDef then
		return
	end

	local owned = data.Items[itemId] or 0
	local sellCount = math.clamp(math.floor(tonumber(amount) or 0), 0, owned)
	if sellCount < 1 then
		sendState(player, "Nothing to sell")
		return
	end

	local sellValue = getItemSellValue(itemId) * sellCount
	data.Items[itemId] = owned - sellCount
	if data.Items[itemId] <= 0 then
		data.Items[itemId] = nil
	end

	if sellValue > 0 then
		RewardService.Grant(player, { Type = "DragonEssence", Amount = sellValue }, { Source = "SellShop" })
	end
	sendState(player, "Sold " .. sellCount .. "x " .. itemDef.DisplayName .. " for " .. sellValue .. " Essence")
	queueSave(player)
end)

Players.PlayerAdded:Connect(loadPlayerData)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayerData, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveDataNow(player)
	playerData[player] = nil
	saveQueued[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveDataNow(player)
	end
end)

print("[DragonInventoryManager] Dragon inventory ready")
