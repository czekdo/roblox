local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local AchievementConfig = require(ReplicatedStorage:WaitForChild("AchievementConfig"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local DragonAbilityConfig = require(ReplicatedStorage:WaitForChild("DragonAbilityConfig"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local RewardService = require(ServerScriptService:WaitForChild("RewardService"))

local AchievementEvents = ReplicatedStorage:WaitForChild("AchievementEvents")
local AchievementUpdate = AchievementEvents:WaitForChild("AchievementUpdate")
local ClaimAchievement = AchievementEvents:WaitForChild("ClaimAchievement")
local AchievementCompleted = AchievementEvents:WaitForChild("AchievementCompleted")
local AchievementProgressSignal = AchievementEvents:WaitForChild("AchievementProgressSignal")
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestProgressSignal = QuestEvents:WaitForChild("QuestProgressSignal")

local DATASTORE_NAME = AchievementConfig.DataStoreName
local PURCHASABLE_EGG_TYPES = { "Common", "Forest", "Ice", "Fire", "Crystal" }
local FIXED_BUILDINGS = { "EggHatchery", "DragonNest", "DragonStorage", "DragonAcademy", "CrystalStorage", "Workshop" }

local achievementStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if success then
		achievementStore = result
		dataStoreAvailable = true
	end
end

local playerData = {}
local saveQueued = {}
local sessionJoinAt = {}

local function getDayKey()
	return os.date("!%Y-%m-%d")
end

local function createDefaultData()
	return {
		version = 1,
		stats = {
			HatchCount = 0,
			EggsOpened = 0,
			MergeCount = 0,
			TrainingCount = 0,
			BuildingUpgrades = 0,
			MaxDragonLevel = 1,
			MaxEvolution = 0,
			KingdomLevel = 1,
			LifetimeEssence = 0,
			PlayTimeSeconds = 0,
			LoginDays = 0,
			IslandsUnlocked = 0,
			MaxIslandIndex = 0,
			SpeciesDiscovered = 0,
		},
		sets = {
			EggTypes = {},
			Islands = {},
			Species = {},
			Rarities = {},
		},
		completed = {},
		claimed = {},
		unlockedTitles = {},
		unlockedBadges = {},
		lastLoginDay = nil,
		loaded = false,
	}
end

local function getData(player)
	if not playerData[player] then
		playerData[player] = createDefaultData()
	end
	return playerData[player]
end

local function setInSet(setTable, value)
	if typeof(value) ~= "string" or value == "" then
		return false
	end
	if setTable[value] then
		return false
	end
	setTable[value] = true
	return true
end

local function countSet(setTable)
	local count = 0
	for _ in setTable do
		count += 1
	end
	return count
end

local function setToList(setTable)
	local list = {}
	for value in setTable do
		if setTable[value] then
			table.insert(list, value)
		end
	end
	table.sort(list)
	return list
end

local function getSpeciesTotal()
	return #DragonAbilityConfig.GetAllSpeciesIds()
end

local function getIslandTotal()
	return #IslandUnlockConfig.Islands
end

local function getProgressValue(player, data, achievement)
	local stat = achievement.Stat
	local stats = data.stats
	if stat == "HatchCount" then
		return stats.HatchCount or 0
	elseif stat == "EggsOpened" then
		return stats.EggsOpened or 0
	elseif stat == "AllEggTypes" then
		return countSet(data.sets.EggTypes) >= #PURCHASABLE_EGG_TYPES and 1 or 0
	elseif stat == "HatchLegendary" then
		return data.sets.Rarities.Legendary and 1 or 0
	elseif stat == "HatchMythic" then
		return data.sets.Rarities.Mythic and 1 or 0
	elseif stat == "IslandIndex" then
		return stats.MaxIslandIndex or 0
	elseif stat == "AllIslands" then
		return countSet(data.sets.Islands) >= getIslandTotal() and 1 or 0
	elseif stat == "BuildingUpgrades" then
		return stats.BuildingUpgrades or 0
	elseif stat == "AllBuildingsLevel5" then
		local island = WorkspaceLayout.GetPlayerIsland(player)
		if not island then
			return 0
		end
		for _, typeId in FIXED_BUILDINGS do
			local model = island:FindFirstChild(typeId)
			local level = model and model:GetAttribute("BuildingLevel") or 1
			if (level or 1) < 5 then
				return 0
			end
		end
		return 1
	elseif stat == "KingdomLevel" then
		return stats.KingdomLevel or 1
	elseif stat == "MaxDragonLevel" then
		return stats.MaxDragonLevel or 1
	elseif stat == "MergeCount" then
		return stats.MergeCount or 0
	elseif stat == "MaxEvolution" then
		return stats.MaxEvolution or 0
	elseif stat == "SpeciesDiscovered" then
		return stats.SpeciesDiscovered or 0
	elseif stat == "CompleteCodex" then
		return countSet(data.sets.Species) >= getSpeciesTotal() and 1 or 0
	elseif stat == "LifetimeEssence" then
		return stats.LifetimeEssence or 0
	elseif stat == "PlayTimeSeconds" then
		return stats.PlayTimeSeconds or 0
	elseif stat == "LoginDays" then
		return stats.LoginDays or 0
	end
	return 0
end

local function isAchievementComplete(player, data, achievement)
	if data.completed[achievement.Id] then
		return true
	end
	local progress = getProgressValue(player, data, achievement)
	return progress >= (achievement.Target or 1)
end

local function buildAchievementPayload(player, data)
	local achievements = {}
	for _, achievement in AchievementConfig.Achievements do
		local progress = getProgressValue(player, data, achievement)
		local target = achievement.Target or 1
		local completed = data.completed[achievement.Id] == true or progress >= target
		local claimed = data.claimed[achievement.Id] == true
		if completed and not data.completed[achievement.Id] then
			data.completed[achievement.Id] = true
		end
		table.insert(achievements, {
			Id = achievement.Id,
			Category = achievement.Category,
			Title = achievement.Title,
			Description = achievement.Description,
			Target = target,
			Progress = math.min(progress, target),
			IconKey = achievement.IconKey,
			Hidden = achievement.Hidden == true,
			Completed = completed,
			Claimed = claimed,
			ReadyToClaim = completed and not claimed,
			RewardText = AchievementConfig.GetRewardText(achievement.Reward),
		})
	end
	return {
		achievements = achievements,
		categories = AchievementConfig.Categories,
		unlockedTitles = setToList(data.unlockedTitles),
		unlockedBadges = setToList(data.unlockedBadges),
	}
end

local function sendUpdate(player)
	local data = getData(player)
	AchievementUpdate:FireClient(player, buildAchievementPayload(player, data))
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(AchievementConfig.SaveDelay, function()
		saveQueued[player] = nil
		if player.Parent then
			local data = playerData[player]
			if data and data.loaded and dataStoreAvailable and achievementStore then
				local payload = {
					version = data.version,
					stats = data.stats,
					sets = {
						EggTypes = setToList(data.sets.EggTypes),
						Islands = setToList(data.sets.Islands),
						Species = setToList(data.sets.Species),
						Rarities = setToList(data.sets.Rarities),
					},
					completed = data.completed,
					claimed = data.claimed,
					unlockedTitles = setToList(data.unlockedTitles),
					unlockedBadges = setToList(data.unlockedBadges),
					lastLoginDay = data.lastLoginDay,
					updatedAt = os.time(),
				}
				pcall(function()
					achievementStore:UpdateAsync(tostring(player.UserId), function()
						return payload
					end)
				end)
			end
		end
	end)
end

local function saveNow(player)
	local data = playerData[player]
	if not data or not data.loaded or not dataStoreAvailable or not achievementStore then
		return
	end
	local payload = {
		version = data.version,
		stats = data.stats,
		sets = {
			EggTypes = setToList(data.sets.EggTypes),
			Islands = setToList(data.sets.Islands),
			Species = setToList(data.sets.Species),
			Rarities = setToList(data.sets.Rarities),
		},
		completed = data.completed,
		claimed = data.claimed,
		unlockedTitles = setToList(data.unlockedTitles),
		unlockedBadges = setToList(data.unlockedBadges),
		lastLoginDay = data.lastLoginDay,
		updatedAt = os.time(),
	}
	pcall(function()
		achievementStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
end

local function normalizeLoadedData(raw)
	local data = createDefaultData()
	if typeof(raw) ~= "table" then
		return data
	end
	if typeof(raw.stats) == "table" then
		for key, value in raw.stats do
			if data.stats[key] ~= nil then
				data.stats[key] = math.max(0, tonumber(value) or data.stats[key])
			end
		end
	end
	if typeof(raw.sets) == "table" then
		for _, eggType in typeof(raw.sets.EggTypes) == "table" and raw.sets.EggTypes or {} do
			setInSet(data.sets.EggTypes, eggType)
		end
		for _, islandId in typeof(raw.sets.Islands) == "table" and raw.sets.Islands or {} do
			setInSet(data.sets.Islands, islandId)
		end
		for _, speciesId in typeof(raw.sets.Species) == "table" and raw.sets.Species or {} do
			setInSet(data.sets.Species, speciesId)
		end
		for _, rarity in typeof(raw.sets.Rarities) == "table" and raw.sets.Rarities or {} do
			setInSet(data.sets.Rarities, rarity)
			data.sets.Rarities[rarity] = true
		end
	end
	if typeof(raw.completed) == "table" then
		data.completed = raw.completed
	end
	if typeof(raw.claimed) == "table" then
		data.claimed = raw.claimed
	end
	if typeof(raw.unlockedTitles) == "table" then
		for _, titleId in raw.unlockedTitles do
			data.unlockedTitles[titleId] = true
		end
	end
	if typeof(raw.unlockedBadges) == "table" then
		for _, badgeId in raw.unlockedBadges do
			data.unlockedBadges[badgeId] = true
		end
	end
	data.lastLoginDay = raw.lastLoginDay
	data.stats.SpeciesDiscovered = countSet(data.sets.Species)
	data.stats.IslandsUnlocked = countSet(data.sets.Islands)
	return data
end

local function applyReward(player, reward)
	local applied = RewardService.Grant(player, reward, { Source = "Achievement", NotifyUI = true })
	if not applied then
		return
	end

	-- Achievements additionally mirror unlocks into their own persisted data table.
	if applied.Type == "Title" then
		getData(player).unlockedTitles[applied.TitleId] = true
	elseif applied.Type == "CosmeticBadge" then
		getData(player).unlockedBadges[applied.BadgeId] = true
	end
end

local function notifyCompleted(player, achievement)
	AchievementCompleted:FireClient(player, {
		Id = achievement.Id,
		Title = achievement.Title,
		Description = achievement.Description,
		RewardText = AchievementConfig.GetRewardText(achievement.Reward),
	})
end

local function checkCompletions(player)
	local data = getData(player)
	local changed = false
	for _, achievement in AchievementConfig.Achievements do
		if not data.completed[achievement.Id] and isAchievementComplete(player, data, achievement) then
			data.completed[achievement.Id] = true
			notifyCompleted(player, achievement)
			changed = true
		end
	end
	if changed then
		sendUpdate(player)
		queueSave(player)
	end
end

local function recordLoginDay(player)
	local data = getData(player)
	local today = getDayKey()
	if data.lastLoginDay ~= today then
		data.lastLoginDay = today
		data.stats.LoginDays = (data.stats.LoginDays or 0) + 1
		checkCompletions(player)
	end
end

local function handleOpenEgg(player, eggType)
	local data = getData(player)
	data.stats.EggsOpened = (data.stats.EggsOpened or 0) + 1
	if typeof(eggType) == "string" then
		setInSet(data.sets.EggTypes, eggType)
	end
	checkCompletions(player)
end

local function handleHatchDragon(player, metadata)
	local data = getData(player)
	data.stats.HatchCount = (data.stats.HatchCount or 0) + 1
	if typeof(metadata) == "table" then
		if typeof(metadata.eggType) == "string" then
			setInSet(data.sets.EggTypes, metadata.eggType)
		end
		if typeof(metadata.rarity) == "string" then
			data.sets.Rarities[metadata.rarity] = true
		end
		local speciesId = metadata.dragonModelName or metadata.dragonType
		if typeof(speciesId) == "string" then
			speciesId = DragonEggConfig.GetDragonModelName(speciesId)
			if setInSet(data.sets.Species, speciesId) then
				data.stats.SpeciesDiscovered = countSet(data.sets.Species)
			end
		end
	end
	checkCompletions(player)
end

local function handleMergeDragon(player, metadata)
	local data = getData(player)
	data.stats.MergeCount = (data.stats.MergeCount or 0) + 1
	local evolution = typeof(metadata) == "table" and tonumber(metadata.evolutionLevel) or nil
	if evolution then
		data.stats.MaxEvolution = math.max(data.stats.MaxEvolution or 0, evolution)
	end
	checkCompletions(player)
end

local function handleDragonLevel(player, level)
	local data = getData(player)
	local numericLevel = math.max(1, math.floor(tonumber(level) or 1))
	if numericLevel > (data.stats.MaxDragonLevel or 1) then
		data.stats.MaxDragonLevel = numericLevel
		checkCompletions(player)
	end
end

local function handleBuildingUpgrade(player, metadata)
	local data = getData(player)
	data.stats.BuildingUpgrades = (data.stats.BuildingUpgrades or 0) + 1
	checkCompletions(player)
end

local function handleIslandUnlock(player, metadata)
	local data = getData(player)
	local islandId = typeof(metadata) == "table" and metadata.islandId or nil
	if typeof(islandId) == "string" and setInSet(data.sets.Islands, islandId) then
		data.stats.IslandsUnlocked = countSet(data.sets.Islands)
	end
	local islandIndex = typeof(metadata) == "table" and tonumber(metadata.islandIndex) or nil
	if islandIndex then
		data.stats.MaxIslandIndex = math.max(data.stats.MaxIslandIndex or 0, islandIndex)
	end
	checkCompletions(player)
end

local function handleTrainingComplete(player)
	local data = getData(player)
	data.stats.TrainingCount = (data.stats.TrainingCount or 0) + 1
	checkCompletions(player)
end

local function handleLifetimeEssence(player, amount)
	local data = getData(player)
	local numeric = math.max(0, math.floor(tonumber(amount) or 0))
	if numeric > (data.stats.LifetimeEssence or 0) then
		data.stats.LifetimeEssence = numeric
		checkCompletions(player)
	end
end

local function handleKingdomLevel(player, level)
	local data = getData(player)
	local numeric = math.max(1, math.floor(tonumber(level) or 1))
	if numeric > (data.stats.KingdomLevel or 1) then
		data.stats.KingdomLevel = numeric
		checkCompletions(player)
	end
end

local function onProgressSignal(player, eventType, amount, metadata)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or typeof(eventType) ~= "string" then
		return
	end
	local data = getData(player)
	if not data.loaded then
		return
	end
	if eventType == "OpenEgg" then
		handleOpenEgg(player, metadata and metadata.eggType)
	elseif eventType == "HatchDragon" then
		handleHatchDragon(player, metadata)
	elseif eventType == "MergeDragon" then
		handleMergeDragon(player, metadata)
	elseif eventType == "DragonLevelUp" then
		handleDragonLevel(player, metadata and metadata.level)
	elseif eventType == "BuildingUpgrade" then
		handleBuildingUpgrade(player, metadata)
	elseif eventType == "IslandUnlock" then
		handleIslandUnlock(player, metadata)
	elseif eventType == "TrainingComplete" then
		handleTrainingComplete(player)
	elseif eventType == "LifetimeEssence" then
		handleLifetimeEssence(player, amount)
	elseif eventType == "KingdomLevel" then
		handleKingdomLevel(player, amount)
	end
	queueSave(player)
end

local function backfillFromWorld(player)
	local data = getData(player)
	handleKingdomLevel(player, player:GetAttribute("KingdomLevel") or 1)
	handleLifetimeEssence(player, player:GetAttribute("LifetimeEssence") or 0)
	local island = WorkspaceLayout.GetPlayerIsland(player)
	if island then
		for _, typeId in FIXED_BUILDINGS do
			local model = island:FindFirstChild(typeId)
			if model then
				local level = model:GetAttribute("BuildingLevel") or 1
				if level > 1 then
					data.stats.BuildingUpgrades = math.max(data.stats.BuildingUpgrades or 0, level - 1)
				end
			end
		end
	end
	checkCompletions(player)
end

local function loadPlayer(player)
	local data = getData(player)
	if dataStoreAvailable and achievementStore then
		local success, result = pcall(function()
			return achievementStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			data = normalizeLoadedData(result)
			playerData[player] = data
		end
	end
	data.loaded = true
	sessionJoinAt[player] = os.clock()
	recordLoginDay(player)
	task.defer(function()
		if player.Parent then
			backfillFromWorld(player)
			sendUpdate(player)
		end
	end)
end

AchievementProgressSignal.Event:Connect(onProgressSignal)

QuestProgressSignal.Event:Connect(function(player, questId, amount)
	if questId == "MergeDragons" then
		onProgressSignal(player, "MergeDragon", amount or 1, nil)
	elseif questId == "TrainDragons" then
		onProgressSignal(player, "TrainingComplete", amount or 1, nil)
	end
end)

ClaimAchievement.OnServerEvent:Connect(function(player, achievementId)
	local achievement = AchievementConfig.GetAchievement(tostring(achievementId or ""))
	local data = getData(player)
	if not achievement or not data.loaded then
		return
	end
	if not data.completed[achievement.Id] and not isAchievementComplete(player, data, achievement) then
		return
	end
	data.completed[achievement.Id] = true
	if data.claimed[achievement.Id] then
		return
	end
	data.claimed[achievement.Id] = true
	applyReward(player, achievement.Reward)
	saveNow(player)
	sendUpdate(player)
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayer(player)
	player:GetAttributeChangedSignal("KingdomLevel"):Connect(function()
		handleKingdomLevel(player, player:GetAttribute("KingdomLevel"))
		queueSave(player)
	end)
	player:GetAttributeChangedSignal("LifetimeEssence"):Connect(function()
		handleLifetimeEssence(player, player:GetAttribute("LifetimeEssence"))
		queueSave(player)
	end)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	local data = playerData[player]
	if data and sessionJoinAt[player] then
		local elapsed = math.max(0, math.floor(os.clock() - sessionJoinAt[player]))
		data.stats.PlayTimeSeconds = (data.stats.PlayTimeSeconds or 0) + elapsed
		checkCompletions(player)
	end
	saveNow(player)
	playerData[player] = nil
	saveQueued[player] = nil
	sessionJoinAt[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(AchievementConfig.PlayTimeTick)
		for _, player in Players:GetPlayers() do
			local data = playerData[player]
			if data and data.loaded then
				data.stats.PlayTimeSeconds = (data.stats.PlayTimeSeconds or 0) + AchievementConfig.PlayTimeTick
				checkCompletions(player)
				queueSave(player)
			end
		end
	end
end)

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

AdminBridge.register("Achievements", {
	refreshState = function(player)
		sendUpdate(player)
		return "Achievement UI refreshed"
	end,
	save = function(player)
		saveNow(player)
		return "Achievement progress saved"
	end,
	completeAll = function(player)
		local data = getData(player)
		for _, achievement in AchievementConfig.Achievements do
			data.completed[achievement.Id] = true
		end
		sendUpdate(player)
		queueSave(player)
		return "All achievements marked complete"
	end,
	wipe = function(player)
		playerData[player] = createDefaultData()
		playerData[player].loaded = true
		sendUpdate(player)
		saveNow(player)
		return "Achievement progress wiped"
	end,
})

print("[AchievementManager] Achievement system ready")
