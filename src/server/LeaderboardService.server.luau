local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local LeaderboardConfig = require(ReplicatedStorage:WaitForChild("LeaderboardConfig"))

local LeaderboardEvents = ReplicatedStorage:WaitForChild("LeaderboardEvents")
local RequestLeaderboard = LeaderboardEvents:WaitForChild("RequestLeaderboard")

local UPDATE_INTERVAL = 90
local TOP_N = 50

local dataStoreAvailable = false
local orderedStores = {}
local namesStore = nil

if game.GameId ~= 0 then
	local ok = pcall(function()
		for _, category in LeaderboardConfig.Categories do
			orderedStores[category.Key] = DataStoreService:GetOrderedDataStore("DragonIslandBoard_" .. category.Key)
		end
		namesStore = DataStoreService:GetDataStore("DragonIslandLeaderboardNamesV1")
	end)
	dataStoreAvailable = ok
	if not ok then
		warn("[LeaderboardService] OrderedDataStore unavailable; leaderboards will only show the current server until published.")
	end
end

local function updateEntry(player, category)
	if not dataStoreAvailable then
		return
	end
	local store = orderedStores[category.Key]
	if not store then
		return
	end
	local value = category.GetValue(player)
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), value)
	end)
	if not ok then
		warn("[LeaderboardService] Failed to update", category.Key, "for", player.UserId, err)
	end
end

local function updateAllCategories(player)
	for _, category in LeaderboardConfig.Categories do
		updateEntry(player, category)
	end
	if namesStore then
		pcall(function()
			namesStore:SetAsync(tostring(player.UserId), player.DisplayName)
		end)
	end
end

-- Ranks players currently on THIS server by live attribute value. Used whenever the OrderedDataStore
-- is unavailable (unpublished place) and as a reasonable degraded fallback if a live query ever fails.
local function buildLiveServerFallback(category)
	local entries = {}
	for _, player in Players:GetPlayers() do
		table.insert(entries, { UserId = player.UserId, DisplayName = player.DisplayName, Value = category.GetValue(player) })
	end
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)
	local top = {}
	for i = 1, math.min(#entries, TOP_N) do
		top[i] = entries[i]
	end
	return top
end

local function resolveDisplayName(userId)
	local existingPlayer = Players:GetPlayerByUserId(userId)
	if existingPlayer then
		return existingPlayer.DisplayName
	end
	if namesStore then
		local ok, name = pcall(function()
			return namesStore:GetAsync(tostring(userId))
		end)
		if ok and typeof(name) == "string" then
			return name
		end
	end
	return "Player" .. tostring(userId)
end

RequestLeaderboard.OnServerInvoke = function(_player, categoryKey)
	local category = LeaderboardConfig.GetCategory(categoryKey)
	if not category then
		return { entries = {} }
	end

	if not dataStoreAvailable then
		return { entries = buildLiveServerFallback(category), liveOnly = true }
	end

	local store = orderedStores[category.Key]
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_N)
	end)
	if not ok then
		warn("[LeaderboardService] GetSortedAsync failed for", category.Key, pages)
		return { entries = buildLiveServerFallback(category), liveOnly = true }
	end

	local page = pages:GetCurrentPage()
	local entries = {}
	for rank, item in page do
		local userId = tonumber(item.key)
		table.insert(entries, {
			UserId = userId,
			DisplayName = resolveDisplayName(userId),
			Value = item.value,
		})
	end
	return { entries = entries, liveOnly = false }
end

local function trackPlayer(player)
	task.wait(3) -- let other systems populate KingdomLevel/LifetimeEssence attributes first
	updateAllCategories(player)
	while player.Parent do
		task.wait(UPDATE_INTERVAL)
		updateAllCategories(player)
	end
end

Players.PlayerAdded:Connect(trackPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(trackPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	updateAllCategories(player)
end)

print("[LeaderboardService] Leaderboards ready")
