local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local DailyWheelConfig = require(ReplicatedStorage:WaitForChild("DailyWheelConfig"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))

local WheelEvents = ReplicatedStorage:WaitForChild("WheelEvents")
local RequestWheelState = WheelEvents:WaitForChild("RequestWheelState")
local RequestSpin = WheelEvents:WaitForChild("RequestSpin")
local WheelSpinResult = WheelEvents:WaitForChild("WheelSpinResult")
local QuestProgressSignal = ReplicatedStorage:WaitForChild("QuestEvents"):WaitForChild("QuestProgressSignal")

local WHEEL_DATASTORE = "DragonIslandDailyWheelV1"
local SECONDS_PER_DAY = 86400

local wheelStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(WHEEL_DATASTORE)
	end)
	if success then
		wheelStore = result
		dataStoreAvailable = true
	else
		warn("[DailyWheelManager] Wheel DataStore unavailable; spins will not persist until publishing:", result)
	end
end

local playerData = {}

local function getDayKey()
	return os.date("!%Y-%m-%d")
end

-- Seconds until the next UTC midnight, for the client's cooldown countdown.
local function getNextResetAt()
	local now = os.time()
	local nowTable = os.date("!*t", now)
	local elapsedToday = nowTable.hour * 3600 + nowTable.min * 60 + nowTable.sec
	return now + (SECONDS_PER_DAY - elapsedToday)
end

local function saveDataNow(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not wheelStore then
		return
	end
	local success, err = pcall(function()
		wheelStore:UpdateAsync(tostring(player.UserId), function()
			return data
		end)
	end)
	if not success then
		warn("[DailyWheelManager] Failed to save wheel data for", player.UserId, err)
	end
end

local function loadPlayer(player)
	local data = { LastSpinDayKey = nil, ExtraSpinDayKey = nil, ExtraSpinsUsedToday = 0 }
	if dataStoreAvailable and wheelStore then
		local success, result = pcall(function()
			return wheelStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			if typeof(result.LastSpinDayKey) == "string" then
				data.LastSpinDayKey = result.LastSpinDayKey
			end
			if typeof(result.ExtraSpinDayKey) == "string" then
				data.ExtraSpinDayKey = result.ExtraSpinDayKey
			end
			if typeof(result.ExtraSpinsUsedToday) == "number" then
				data.ExtraSpinsUsedToday = result.ExtraSpinsUsedToday
			end
		elseif not success then
			warn("[DailyWheelManager] Failed to load wheel data for", player.UserId, result)
		end
	end
	playerData[player] = data
end

local function canSpin(player)
	local data = playerData[player]
	return data ~= nil and data.LastSpinDayKey ~= getDayKey()
end

local function getExtraSpinsUsedToday(data)
	if data.ExtraSpinDayKey ~= getDayKey() then
		return 0
	end
	return data.ExtraSpinsUsedToday or 0
end

RequestWheelState.OnServerInvoke = function(player)
	if not playerData[player] then
		loadPlayer(player)
	end
	local data = playerData[player]
	return {
		canSpin = canSpin(player),
		nextResetAt = getNextResetAt(),
		extraSpinCost = DailyWheelConfig.ExtraSpin.Cost,
		extraSpinsRemaining = DailyWheelConfig.ExtraSpin.MaxPerDay - getExtraSpinsUsedToday(data),
	}
end

RequestSpin.OnServerEvent:Connect(function(player, wantsPaidSpin)
	if not RateLimiter.check(player, "RequestSpin", 0.5) then
		return
	end
	local data = playerData[player]
	if not data then
		return
	end

	local isPaidSpin = false
	if not canSpin(player) then
		if not wantsPaidSpin then
			WheelSpinResult:FireClient(player, {
				success = false,
				message = "Already spun today. Come back tomorrow!",
				nextResetAt = getNextResetAt(),
			})
			return
		end

		local usedToday = getExtraSpinsUsedToday(data)
		if usedToday >= DailyWheelConfig.ExtraSpin.MaxPerDay then
			WheelSpinResult:FireClient(player, { success = false, message = "No more extra spins today." })
			return
		end
		local cost = DailyWheelConfig.ExtraSpin.Cost
		local gems = player:GetAttribute("PremiumGems") or 0
		if gems < cost then
			WheelSpinResult:FireClient(player, { success = false, message = "Not enough Gems." })
			return
		end
		player:SetAttribute("PremiumGems", gems - cost)
		data.ExtraSpinDayKey = getDayKey()
		data.ExtraSpinsUsedToday = usedToday + 1
		isPaidSpin = true
	end

	local segment, index = DailyWheelConfig.RollSegment()
	local applied = RewardService.Grant(player, segment.Reward, { Source = "DailyWheel" })

	if not isPaidSpin then
		data.LastSpinDayKey = getDayKey()
	end
	saveDataNow(player)
	QuestProgressSignal:Fire(player, "SpinDailyWheel", 1)

	WheelSpinResult:FireClient(player, {
		success = true,
		segmentId = segment.Id,
		segmentIndex = index,
		message = segment.Reward.Text or segment.DisplayName,
		applied = applied,
		nextResetAt = getNextResetAt(),
		extraSpinsRemaining = DailyWheelConfig.ExtraSpin.MaxPerDay - getExtraSpinsUsedToday(data),
	})
end)

local function setupWheelPrompt()
	local wheel = workspace:FindFirstChild("Wheel")
	if not wheel then
		warn("[DailyWheelManager] Workspace.Wheel not found; the Daily Wheel prompt will not be created.")
		return
	end
	local part = wheel:FindFirstChildWhichIsA("BasePart", true)
	if not part then
		warn("[DailyWheelManager] Workspace.Wheel has no BasePart; the Daily Wheel prompt will not be created.")
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DailyWheelPrompt"
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Daily Wheel"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

setupWheelPrompt()

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

print("[DailyWheelManager] Daily wheel ready")
