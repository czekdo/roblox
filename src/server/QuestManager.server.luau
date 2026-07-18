local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestUpdate = QuestEvents:WaitForChild("QuestUpdate")
local ClaimQuest = QuestEvents:WaitForChild("ClaimQuest")
local QuestProgressSignal = QuestEvents:WaitForChild("QuestProgressSignal")
local TutorialEvents = ReplicatedStorage:WaitForChild("TutorialEvents")
local TutorialProgressSignal = TutorialEvents:WaitForChild("TutorialProgressSignal")
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))

local dragonsFolder = workspace:WaitForChild("DragonWorkers")

local QUEST_DATASTORE = "DailyQuestProgressV1"
local questStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local storeSuccess, storeResult = pcall(function()
		return DataStoreService:GetDataStore(QUEST_DATASTORE)
	end)
	if storeSuccess then
		questStore = storeResult
		dataStoreAvailable = true
	else
		warn("[QuestManager] Quest DataStore unavailable; quest progress will not persist until publishing:", storeResult)
	end
end

local QUEST_DEFINITIONS = {
	{
		Id = "CollectEssence",
		Title = "Collect Dragon Essence",
		Description = "Collect 250 Dragon Essence.",
		Target = 250,
		Reward = { Type = "DragonEssence", Amount = 100, Text = "+100 Dragon Essence" },
	},
	{
		Id = "HatchDragons",
		Title = "Hatch Dragons",
		Description = "Hatch 1 dragon.",
		Target = 1,
		Reward = { Type = "Eggs", Amount = 1, Text = "+1 Quest Egg" },
	},
	{
		Id = "UpgradeDragons",
		Title = "Upgrade Dragons",
		Description = "Upgrade 1 dragon.",
		Target = 1,
		Reward = { Type = "TemporaryBoost", BoostId = "QuestEssenceBoost", Multiplier = 1.25, Duration = 600, Text = "25% Essence Boost (10m)" },
	},
	{
		Id = "UnlockIslandExpansions",
		Title = "Unlock Island Expansions",
		Description = "Unlock 1 island expansion.",
		Target = 1,
		Reward = { Type = "DragonEssence", Amount = 500, Text = "+500 Dragon Essence" },
	},
	{
		Id = "TrainDragons",
		Title = "Train Dragons",
		Description = "Complete 1 dragon training session.",
		Target = 1,
		Reward = { Type = "DragonEssence", Amount = 200, Text = "+200 Dragon Essence" },
	},
	{
		Id = "MergeDragons",
		Title = "Merge Dragons",
		Description = "Merge dragons once at the Academy.",
		Target = 1,
		Reward = { Type = "Eggs", Amount = 1, Text = "+1 Quest Egg" },
	},
	{
		Id = "VisitHub",
		Title = "Visit the Hub",
		Description = "Travel to the Global Hub once.",
		Target = 1,
		Reward = { Type = "DragonEssence", Amount = 150, Text = "+150 Dragon Essence" },
	},
}

local questById = {}
for _, quest in QUEST_DEFINITIONS do
	questById[quest.Id] = quest
end

local playerQuestData = {}
local lastEssenceByPlayer = {}
local dragonLevels = {}
local saveQueued = {}

local function getDayKey()
	return os.date("!%Y-%m-%d")
end

local function createDefaultProgress()
	local progress = {}
	for _, quest in QUEST_DEFINITIONS do
		progress[quest.Id] = {
			Progress = 0,
			Claimed = false,
		}
	end
	return progress
end

local function normalizeProgress(progress)
	local normalized = createDefaultProgress()
	if typeof(progress) == "table" then
		for questId, questProgress in progress do
			if normalized[questId] and typeof(questProgress) == "table" then
				normalized[questId].Progress = math.max(0, tonumber(questProgress.Progress) or 0)
				normalized[questId].Claimed = questProgress.Claimed == true
			end
		end
	end
	return normalized
end

local function serializeForClient(data)
	local quests = {}
	for _, quest in QUEST_DEFINITIONS do
		local progress = data.Progress[quest.Id]
		table.insert(quests, {
			Id = quest.Id,
			Title = quest.Title,
			Description = quest.Description,
			Target = quest.Target,
			Progress = math.min(progress.Progress, quest.Target),
			Claimed = progress.Claimed,
			RewardText = quest.Reward.Text,
			ReadyToClaim = progress.Progress >= quest.Target and not progress.Claimed,
		})
	end
	return {
		DayKey = data.DayKey,
		Quests = quests,
		QuestEggs = data.QuestEggs or 0,
		ActiveBoosts = data.ActiveBoosts or {},
	}
end

local function sendQuestUpdate(player)
	local data = playerQuestData[player]
	if data then
		QuestUpdate:FireClient(player, serializeForClient(data))
	end
end

local function saveQuestDataNow(player)
	local data = playerQuestData[player]
	if not data or not dataStoreAvailable or not questStore then
		return
	end

	local payload = {
		DayKey = data.DayKey,
		Progress = data.Progress,
		QuestEggs = data.QuestEggs or 0,
		ActiveBoosts = data.ActiveBoosts or {},
		UpdatedAt = os.time(),
	}

	local success, err = pcall(function()
		questStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
	if not success then
		warn("[QuestManager] Failed to save quest data for", player.UserId, err)
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
			saveQuestDataNow(player)
		end
	end)
end

local function incrementQuest(player, questId, amount)
	local data = playerQuestData[player]
	local quest = questById[questId]
	if not data or not quest then
		return
	end

	local progress = data.Progress[questId]
	if not progress or progress.Claimed then
		return
	end

	local oldProgress = progress.Progress
	progress.Progress = math.min(quest.Target, progress.Progress + math.max(0, amount or 0))
	if progress.Progress ~= oldProgress then
		sendQuestUpdate(player)
		queueSave(player)
	end
end

local function applyReward(player, quest)
	local data = playerQuestData[player]
	if not data then
		return
	end

	local applied = RewardService.Grant(player, quest.Reward, { Source = "Quest", ApplyAscensionBonus = true })
	if not applied then
		return
	end

	-- Quest keeps its own in-memory/persisted mirrors (QuestEggs, ActiveBoosts) alongside the
	-- attributes RewardService writes, so sync them from what was actually applied.
	if applied.Type == "Eggs" then
		data.QuestEggs = player:GetAttribute("QuestEggs") or 0
	elseif applied.Type == "TemporaryBoost" then
		data.ActiveBoosts[applied.BoostId] = {
			Multiplier = applied.Multiplier,
			ExpiresAt = applied.ExpiresAt,
		}
	end
end

local function loadQuestData(player)
	local dayKey = getDayKey()
	local data = {
		DayKey = dayKey,
		Progress = createDefaultProgress(),
		QuestEggs = 0,
		ActiveBoosts = {},
		ReadyAt = os.clock() + 7,
	}

	if dataStoreAvailable and questStore then
		local success, result = pcall(function()
			return questStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" and result.DayKey == dayKey then
			data.Progress = normalizeProgress(result.Progress)
			data.QuestEggs = math.max(0, tonumber(result.QuestEggs) or 0)
			data.ActiveBoosts = typeof(result.ActiveBoosts) == "table" and result.ActiveBoosts or {}
		elseif not success then
			warn("[QuestManager] Failed to load quest data for", player.UserId, result)
		end
	end

	for boostId, boost in data.ActiveBoosts do
		if typeof(boost) == "table" and tonumber(boost.ExpiresAt) and boost.ExpiresAt > os.time() then
			player:SetAttribute(boostId .. "Multiplier", tonumber(boost.Multiplier) or 1)
			player:SetAttribute(boostId .. "ExpiresAt", boost.ExpiresAt)
		else
			data.ActiveBoosts[boostId] = nil
		end
	end

	player:SetAttribute("QuestEggs", data.QuestEggs)
	playerQuestData[player] = data
	lastEssenceByPlayer[player] = player:GetAttribute("DragonEssence") or 0
	sendQuestUpdate(player)
end

local function isTrackingReady(player)
	local data = playerQuestData[player]
	return data and os.clock() >= data.ReadyAt
end

local function trackDragon(dragon)
	if not dragon:IsA("Model") then
		return
	end

	local ownerUserId = dragon:GetAttribute("OwnerUserId")
	local player = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
	if player and isTrackingReady(player) then
		incrementQuest(player, "HatchDragons", 1)
	end

	dragonLevels[dragon] = dragon:GetAttribute("DragonLevel") or 1
	dragon:GetAttributeChangedSignal("DragonLevel"):Connect(function()
		local newLevel = dragon:GetAttribute("DragonLevel") or 1
		local oldLevel = dragonLevels[dragon] or newLevel
		dragonLevels[dragon] = newLevel
		local currentOwnerUserId = dragon:GetAttribute("OwnerUserId")
		local currentPlayer = currentOwnerUserId and Players:GetPlayerByUserId(currentOwnerUserId)
		if currentPlayer and isTrackingReady(currentPlayer) and newLevel > oldLevel then
			incrementQuest(currentPlayer, "UpgradeDragons", newLevel - oldLevel)
		end
	end)
end

local function trackExpansionArea(area)
	if not area:IsA("BasePart") then
		return
	end

	area:GetAttributeChangedSignal("Unlocked"):Connect(function()
		if area:GetAttribute("Unlocked") ~= true then
			return
		end
		local island = area:FindFirstAncestorWhichIsA("Model")
		local ownerUserId = island and island:GetAttribute("OwnerUserId")
		local player = ownerUserId and Players:GetPlayerByUserId(ownerUserId)
		if player and isTrackingReady(player) then
			incrementQuest(player, "UnlockIslandExpansions", 1)
		end
	end)
end

local function trackIsland(island)
	for _, descendant in island:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("ExpansionId") then
			trackExpansionArea(descendant)
		end
	end
	island.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant:GetAttribute("ExpansionId") then
			trackExpansionArea(descendant)
		end
	end)
end

ClaimQuest.OnServerEvent:Connect(function(player, questId)
	local data = playerQuestData[player]
	local quest = questById[questId]
	if not data or not quest then
		return
	end

	local progress = data.Progress[questId]
	if not progress or progress.Claimed or progress.Progress < quest.Target then
		return
	end

	progress.Claimed = true
	applyReward(player, quest)
	TutorialProgressSignal:Fire(player, "CompleteFirstQuest")
	sendQuestUpdate(player)
	saveQuestDataNow(player)
end)

QuestProgressSignal.Event:Connect(function(player, questId, amount)
	if typeof(player) == "Instance" and player:IsA("Player") and typeof(questId) == "string" then
		incrementQuest(player, questId, amount or 1)
	end
end)

Players.PlayerAdded:Connect(function(player)
	loadQuestData(player)
	player:GetAttributeChangedSignal("DragonEssence"):Connect(function()
		local currentEssence = player:GetAttribute("DragonEssence") or 0
		local lastEssence = lastEssenceByPlayer[player] or currentEssence
		if isTrackingReady(player) and currentEssence > lastEssence then
			incrementQuest(player, "CollectEssence", currentEssence - lastEssence)
		end
		lastEssenceByPlayer[player] = currentEssence
	end)
end)

for _, player in Players:GetPlayers() do
	task.spawn(function()
		loadQuestData(player)
	end)
end

for _, dragon in dragonsFolder:GetChildren() do
	trackDragon(dragon)
end

dragonsFolder.ChildAdded:Connect(trackDragon)
dragonsFolder.ChildRemoved:Connect(function(dragon)
	dragonLevels[dragon] = nil
end)

local mainIsland = WorkspaceLayout.GetMainIslandContainer()
if mainIsland then
	trackIsland(mainIsland)
else
	warn("[QuestManager] Workspace/islandMain is missing")
end

Players.PlayerRemoving:Connect(function(player)
	saveQuestDataNow(player)
	playerQuestData[player] = nil
	lastEssenceByPlayer[player] = nil
	saveQueued[player] = nil
end)

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

AdminBridge.register("Quests", {
	completeAll = function(player)
		local data = playerQuestData[player]
		if not data then
			return "Quest data not loaded"
		end
		for _, quest in QUEST_DEFINITIONS do
			local progress = data.Progress[quest.Id]
			if progress then
				progress.Progress = quest.Target
			end
		end
		sendQuestUpdate(player)
		queueSave(player)
		return "All quests marked complete"
	end,
	refreshState = function(player)
		sendQuestUpdate(player)
		return "Quest UI refreshed"
	end,
	save = function(player)
		saveQuestDataNow(player)
		return "Quest progress saved"
	end,
	wipe = function(player)
		local data = {
			DayKey = getDayKey(),
			Progress = createDefaultProgress(),
			QuestEggs = 0,
			ActiveBoosts = {},
			ReadyAt = 0,
		}
		playerQuestData[player] = data
		player:SetAttribute("QuestEggs", 0)
		sendQuestUpdate(player)
		saveQuestDataNow(player)
		return "Quest progress wiped"
	end,
})

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveQuestDataNow(player)
	end
end)