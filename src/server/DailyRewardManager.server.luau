local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyRewardConfig = require(ReplicatedStorage:WaitForChild("DailyRewardConfig"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))

local DailyRewardEvents = ReplicatedStorage:WaitForChild("DailyRewardEvents")
local RequestDailyRewardState = DailyRewardEvents:WaitForChild("RequestDailyRewardState")
local ClaimDailyReward = DailyRewardEvents:WaitForChild("ClaimDailyReward")
local DailyRewardResult = DailyRewardEvents:WaitForChild("DailyRewardResult")
local QuestProgressSignal = ReplicatedStorage:WaitForChild("QuestEvents"):WaitForChild("QuestProgressSignal")

local DAILY_REWARD_DATASTORE = "DragonIslandDailyRewardV1"
local SECONDS_PER_DAY = 86400

local rewardStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DAILY_REWARD_DATASTORE)
	end)
	if success then
		rewardStore = result
		dataStoreAvailable = true
	else
		warn("[DailyRewardManager] DataStore unavailable; streaks will not persist until publishing:", result)
	end
end

local playerData = {}

local function getDayKey(atTime)
	return os.date("!%Y-%m-%d", atTime or os.time())
end

local function getNextResetAt()
	local now = os.time()
	local nowTable = os.date("!*t", now)
	local elapsedToday = nowTable.hour * 3600 + nowTable.min * 60 + nowTable.sec
	return now + (SECONDS_PER_DAY - elapsedToday)
end

local function saveDataNow(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not rewardStore then
		return
	end
	local success, err = pcall(function()
		rewardStore:UpdateAsync(tostring(player.UserId), function()
			return data
		end)
	end)
	if not success then
		warn("[DailyRewardManager] Failed to save streak for", player.UserId, err)
	end
end

local function loadPlayer(player)
	local data = { LastClaimDayKey = nil, Streak = 0 }
	if dataStoreAvailable and rewardStore then
		local success, result = pcall(function()
			return rewardStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			data.LastClaimDayKey = typeof(result.LastClaimDayKey) == "string" and result.LastClaimDayKey or nil
			data.Streak = typeof(result.Streak) == "number" and result.Streak or 0
		elseif not success then
			warn("[DailyRewardManager] Failed to load streak for", player.UserId, result)
		end
	end
	playerData[player] = data
end

-- The streak day that applies to "today": if already claimed today, that's the committed streak;
-- if not claimed yet, this is what claiming today WOULD become (continuing or resetting).
local function computeTodayStreak(data)
	local today = getDayKey()
	local yesterday = getDayKey(os.time() - SECONDS_PER_DAY)
	if data.LastClaimDayKey == today then
		return data.Streak
	elseif data.LastClaimDayKey == yesterday then
		return data.Streak + 1
	else
		return 1
	end
end

RequestDailyRewardState.OnServerInvoke = function(player)
	if not playerData[player] then
		loadPlayer(player)
	end
	local data = playerData[player]
	local today = getDayKey()
	return {
		canClaim = data.LastClaimDayKey ~= today,
		streak = computeTodayStreak(data),
		nextResetAt = getNextResetAt(),
	}
end

ClaimDailyReward.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then
		return
	end
	local today = getDayKey()
	if data.LastClaimDayKey == today then
		DailyRewardResult:FireClient(player, {
			success = false,
			message = "Already claimed today. Come back tomorrow!",
			nextResetAt = getNextResetAt(),
		})
		return
	end

	local newStreak = computeTodayStreak(data)
	local entry = DailyRewardConfig.GetEntryForStreak(newStreak)
	local applied = RewardService.Grant(player, entry.Reward, { Source = "DailyReward" })

	data.Streak = newStreak
	data.LastClaimDayKey = today
	saveDataNow(player)
	QuestProgressSignal:Fire(player, "ClaimDailyReward", 1)

	DailyRewardResult:FireClient(player, {
		success = true,
		streak = newStreak,
		message = entry.Reward.Text,
		applied = applied,
		nextResetAt = getNextResetAt(),
	})
end)

Players.PlayerAdded:Connect(loadPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveDataNow(player)
	playerData[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveDataNow(player)
	end
end)

print("[DailyRewardManager] Daily reward streak ready")
