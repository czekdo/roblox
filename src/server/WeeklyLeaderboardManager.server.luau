local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local WeeklyLeaderboardConfig = require(ReplicatedStorage:WaitForChild("WeeklyLeaderboardConfig"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

local LeaderboardEvents = ReplicatedStorage:WaitForChild("LeaderboardEvents")
-- Created here (not WaitForChild) if missing - see the matching comment in DragonTrainingManager
-- for why: a plain Studio Instance like this one can vanish if it's added mid-session and the
-- place isn't saved before a Studio restart, so the server guarantees its own existence instead.
local RequestWeeklyLeaderboard = LeaderboardEvents:FindFirstChild("RequestWeeklyLeaderboard")
if not RequestWeeklyLeaderboard then
	RequestWeeklyLeaderboard = Instance.new("RemoteFunction")
	RequestWeeklyLeaderboard.Name = "RequestWeeklyLeaderboard"
	RequestWeeklyLeaderboard.Parent = LeaderboardEvents
end

local dataStoreAvailable = false
local baselineStore, stateStore, namesStore
local boardStoreCache = {}

if game.GameId ~= 0 then
	local ok = pcall(function()
		baselineStore = DataStoreService:GetDataStore(WeeklyLeaderboardConfig.BaselineDataStoreName)
		stateStore = DataStoreService:GetDataStore(WeeklyLeaderboardConfig.StateDataStoreName)
		-- Same DataStore name LeaderboardService uses for display names - DataStores are keyed
		-- globally by name, so this reads/shares the same underlying data without needing a second
		-- copy of that bookkeeping.
		namesStore = DataStoreService:GetDataStore("DragonIslandLeaderboardNamesV1")
	end)
	dataStoreAvailable = ok
	if not ok then
		warn("[WeeklyLeaderboardManager] DataStore unavailable; weekly board disabled until published.")
	end
end

local function getBoardStore(weekId)
	local store = boardStoreCache[weekId]
	if not store then
		store = DataStoreService:GetOrderedDataStore(WeeklyLeaderboardConfig.BoardDataStorePrefix .. tostring(weekId))
		boardStoreCache[weekId] = store
	end
	return store
end

-- player -> { weekId = number, baseline = number (LifetimeEssence at the start of that week) }
local playerBaselines = {}

local function loadBaseline(player)
	local currentWeekId = WeeklyLeaderboardConfig.GetCurrentWeekId()
	local record = nil
	if dataStoreAvailable then
		local ok, result = pcall(function()
			return baselineStore:GetAsync(tostring(player.UserId))
		end)
		if ok and typeof(result) == "table" then
			record = result
		end
	end
	local lifetimeEssence = player:GetAttribute("LifetimeEssence") or 0
	if not record or record.weekId ~= currentWeekId then
		-- First time seen this week (new player, or a week boundary passed since they last played) -
		-- their weekly progress starts counting from right now.
		record = { weekId = currentWeekId, baseline = lifetimeEssence }
		if dataStoreAvailable then
			pcall(function()
				baselineStore:SetAsync(tostring(player.UserId), record)
			end)
		end
	end
	playerBaselines[player] = record
end

local function updateWeeklyEntry(player)
	if not dataStoreAvailable then
		return
	end
	local record = playerBaselines[player]
	if not record then
		return
	end
	local currentWeekId = WeeklyLeaderboardConfig.GetCurrentWeekId()
	if record.weekId ~= currentWeekId then
		-- Week rolled over while this player was online this whole time - reset their baseline now
		-- instead of waiting for their next join.
		record.weekId = currentWeekId
		record.baseline = player:GetAttribute("LifetimeEssence") or 0
		pcall(function()
			baselineStore:SetAsync(tostring(player.UserId), record)
		end)
	end
	local lifetimeEssence = player:GetAttribute("LifetimeEssence") or 0
	local delta = math.max(0, lifetimeEssence - record.baseline)
	local store = getBoardStore(currentWeekId)
	pcall(function()
		store:SetAsync(tostring(player.UserId), delta)
	end)
	if namesStore then
		pcall(function()
			namesStore:SetAsync(tostring(player.UserId), player.DisplayName)
		end)
	end
end

local function trackPlayer(player)
	task.wait(4) -- let KingdomProgressManager populate LifetimeEssence first
	loadBaseline(player)
	updateWeeklyEntry(player)
	while player.Parent do
		task.wait(WeeklyLeaderboardConfig.UpdateInterval)
		updateWeeklyEntry(player)
	end
end

Players.PlayerAdded:Connect(trackPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(trackPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	updateWeeklyEntry(player)
	playerBaselines[player] = nil
end)

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

local function distributeRewardsForWeek(weekId)
	local store = getBoardStore(weekId)
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, WeeklyLeaderboardConfig.TopN)
	end)
	if not ok then
		warn("[WeeklyLeaderboardManager] Failed to read week", weekId, "results:", pages)
		return
	end
	local page = pages:GetCurrentPage()
	local rewardedCount = 0
	for rank, item in ipairs(page) do
		local tier = WeeklyLeaderboardConfig.GetRewardForRank(rank)
		if tier then
			local userId = tonumber(item.key)
			local mailEntry = {
				Id = "weekly_" .. tostring(weekId) .. "_" .. tostring(userId),
				Title = "Weekly Leaderboard Reward - " .. tier.Label,
				Body = string.format(
					"You finished #%d on last week's Dragon Essence leaderboard with %d essence earned. Well flown!",
					rank,
					math.floor(item.value)
				),
				Rewards = {
					{ Type = "PremiumCurrency", Amount = tier.Gems, Text = "+" .. tostring(tier.Gems) .. " Gems" },
					{ Type = "DragonEssence", Amount = tier.Essence, Text = "+" .. tostring(tier.Essence) .. " Dragon Essence" },
				},
			}
			local granted = AdminBridge.call("Mail", "grant", userId, mailEntry)
			if granted then
				rewardedCount += 1
			end
		end
	end
	print("[WeeklyLeaderboardManager] Distributed rewards for week", weekId, "-", rewardedCount, "players")
end

-- Claims the transition to a new week exactly once across every running server, using UpdateAsync's
-- atomicity as a distributed lock: only the call that actually moves ProcessedWeekId forward
-- proceeds to hand out rewards for the week that just ended.
local function checkWeekRollover()
	if not dataStoreAvailable then
		return
	end
	local currentWeekId = WeeklyLeaderboardConfig.GetCurrentWeekId()
	local won = false
	local ok, err = pcall(function()
		stateStore:UpdateAsync("ProcessedWeekId", function(old)
			old = tonumber(old)
			if not old then
				-- First run ever: nothing to reward yet, just establish the baseline so the NEXT
				-- rollover (a real elapsed week) is the one that pays out.
				return currentWeekId
			end
			if old < currentWeekId then
				won = true
				return currentWeekId
			end
			return old
		end)
	end)
	if not ok then
		warn("[WeeklyLeaderboardManager] Failed to check week rollover:", err)
		return
	end
	if won then
		task.spawn(distributeRewardsForWeek, currentWeekId - 1)
	end
end

task.spawn(function()
	while true do
		checkWeekRollover()
		task.wait(300)
	end
end)

-- Same shared cache as LeaderboardService.RequestLeaderboard: the entries list is identical for
-- every player, so it's cached once here rather than re-running GetSortedAsync (an expensive
-- OrderedDataStore call) on every single invoke, no matter how many players spam this request.
-- Only "entries" is cached - myWeeklyEssence below is per-player and computed fresh every call
-- (cheap, just an attribute read, no DataStore hit).
local ENTRIES_CACHE_TTL = 15
local entriesCache = nil

local function getCachedEntries(currentWeekId)
	if entriesCache and entriesCache.weekId == currentWeekId and (os.clock() - entriesCache.cachedAt) < ENTRIES_CACHE_TTL then
		return entriesCache.entries
	end

	local entries = {}
	if dataStoreAvailable then
		local store = getBoardStore(currentWeekId)
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, WeeklyLeaderboardConfig.TopN)
		end)
		if ok then
			local page = pages:GetCurrentPage()
			for rank, item in ipairs(page) do
				local userId = tonumber(item.key)
				table.insert(entries, {
					UserId = userId,
					DisplayName = resolveDisplayName(userId),
					Value = item.value,
					Rank = rank,
				})
			end
		end
	end

	entriesCache = { entries = entries, weekId = currentWeekId, cachedAt = os.clock() }
	return entries
end

RequestWeeklyLeaderboard.OnServerInvoke = function(player)
	local currentWeekId = WeeklyLeaderboardConfig.GetCurrentWeekId()
	local entries = getCachedEntries(currentWeekId)

	local myRecord = playerBaselines[player]
	local myWeeklyEssence = 0
	if myRecord then
		myWeeklyEssence = math.max(0, (player:GetAttribute("LifetimeEssence") or 0) - myRecord.baseline)
	end

	return {
		entries = entries,
		secondsUntilReset = WeeklyLeaderboardConfig.GetSecondsUntilNextWeek(),
		myWeeklyEssence = myWeeklyEssence,
		rewardTiers = WeeklyLeaderboardConfig.RewardTiers,
	}
end

print("[WeeklyLeaderboardManager] Weekly leaderboard ready")
