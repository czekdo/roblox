local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")

local HarvestConfig = require(ReplicatedStorage:WaitForChild("HarvestConfig"))
local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local DragonTrainingConfig = require(ReplicatedStorage:WaitForChild("DragonTrainingConfig"))
local DragonRosterBridge = require(script.Parent:WaitForChild("DragonRosterBridge"))
local DragonInventoryService = require(script.Parent:WaitForChild("DragonInventoryService"))
local BiomeResourceRegistry = require(ReplicatedStorage:WaitForChild("BiomeResourceRegistry"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local BiomeResourcePlacer = require(ServerScriptService:WaitForChild("BiomeResourcePlacer"))
local DragonAIController = require(ServerScriptService:WaitForChild("DragonAIController"))
local DragonAbilityService = require(ServerScriptService:WaitForChild("DragonAbilityService"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))
local Events = ReplicatedStorage:WaitForChild("HarvestEvents")
local TargetNode = Events:WaitForChild("TargetNode")
local BuyDragonEgg = Events:WaitForChild("BuyDragonEgg")
local HarvestHit = Events:WaitForChild("HarvestHit")
local NodeDepleted = Events:WaitForChild("NodeDepleted")
local HarvestUIUpdate = Events:WaitForChild("HarvestUIUpdate")
local EggHatched = Events:WaitForChild("EggHatched")
local EggHatchStart = Events:WaitForChild("EggHatchStart")
local EggHatchComplete = Events:WaitForChild("EggHatchComplete")
local UpgradeDragon = Events:WaitForChild("UpgradeDragon")
local EggShopUpdate = Events:WaitForChild("EggShopUpdate")
local RequestDragonMergeData = Events:WaitForChild("RequestDragonMergeData")
local MergeDragons = Events:WaitForChild("MergeDragons")
local DragonMergeUpdate = Events:WaitForChild("DragonMergeUpdate")
local EquipDragon = Events:WaitForChild("EquipDragon")
local UnequipDragon = Events:WaitForChild("UnequipDragon")
local EquipBestDragons = Events:WaitForChild("EquipBestDragons")
local SetDragonFavorite = Events:WaitForChild("SetDragonFavorite")
local SetDragonLocked = Events:WaitForChild("SetDragonLocked")
local DragonStorageFull = Events:WaitForChild("DragonStorageFull")
local TutorialEvents = ReplicatedStorage:WaitForChild("TutorialEvents")
local TutorialProgressSignal = TutorialEvents:WaitForChild("TutorialProgressSignal")
local GrantTutorialRewardEgg = TutorialEvents:WaitForChild("GrantTutorialRewardEgg")
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestProgressSignal = QuestEvents:WaitForChild("QuestProgressSignal")
local AchievementEvents = ReplicatedStorage:WaitForChild("AchievementEvents")
local AchievementProgressSignal = AchievementEvents:WaitForChild("AchievementProgressSignal")

local dragonModelsFolder = ServerStorage:WaitForChild("DragonWorker")
local DragonEggFactory = require(ServerStorage:WaitForChild("DragonEggFactory"))
local resourcesTemplatesFolder = ServerStorage:WaitForChild("Resources")
local nodeTemplate = resourcesTemplatesFolder:WaitForChild("CrystalResource")
local dragonsFolder = workspace:WaitForChild("DragonWorkers")
local eggsFolder = workspace:WaitForChild("DragonEggs")
local nodesFolder = workspace:WaitForChild("ResourceNodes")

local STARTER_DRAGON_TYPE = "ForestDragon"
local DRAGON_LEVEL_DATASTORE = "DragonWorkerLevelsV1"
local EGG_PROGRESS_DATASTORE = "DragonEggProgressV1"

local dragonLevelStore = nil
local eggProgressStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local storeSuccess, storeResult = pcall(function()
		return DataStoreService:GetDataStore(DRAGON_LEVEL_DATASTORE)
	end)
	if storeSuccess then
		dragonLevelStore = storeResult
		dataStoreAvailable = true
	else
		warn("[DragonHarvestManager] Dragon level DataStore unavailable; levels will persist only after publishing:", storeResult)
	end

	local eggStoreSuccess, eggStoreResult = pcall(function()
		return DataStoreService:GetDataStore(EGG_PROGRESS_DATASTORE)
	end)
	if eggStoreSuccess then
		eggProgressStore = eggStoreResult
	else
		warn("[DragonHarvestManager] Egg progress DataStore unavailable; egg stats will persist only after publishing:", eggStoreResult)
	end
end

local playerData = {}
local nextDragonId = 0
local pendingHatches = {}
local autoAssignIdleDragons

local function getPlayerData(player)
	if not playerData[player] then
		playerData[player] = {
			essence = player:GetAttribute("DragonEssence") or 0,
			dragons = {},
			eggs = {},
			nodes = {},
			autoAssignTimer = 0,
			island = nil,
			savedDragons = {},
			nextSavedDragonIndex = 1,
			eggStats = {
				OwnedEggs = {},
				Purchases = {},
				Hatched = {},
				TotalPurchases = 0,
				TotalHatched = 0,
			},
			mergeStats = {
				MergeCount = 0,
				HighestEvolution = 0,
				ByDragonType = {},
			},
			eggStatsLoaded = false,
			loaded = false,
			inventoryMigrated = false,
			ownedDragonById = {},
			ownedDragonCount = 0,
			nextOwnedDragonId = 1,
			currentIslandId = nil,
			islandCheckTimer = 0,
			nodeCache = {},
		}
	end
	return playerData[player]
end

local nestSlotConnections = {}

local function getDragonNestModel(player)
	local data = getPlayerData(player)
	local island = data.island or WorkspaceLayout.GetPlayerIsland(player)
	if not island then
		return nil
	end
	local nest = island:FindFirstChild("DragonNest")
	if nest and nest:IsA("Model") then
		return nest
	end
	return nil
end

local function getPlayerDragonSlotLimit(player)
	local nest = getDragonNestModel(player)
	local baseSlots = 1
	if nest then
		local slots = nest:GetAttribute("ActiveDragonSlots")
		if typeof(slots) == "number" and slots > 0 then
			baseSlots = math.floor(slots)
		else
			local level = nest:GetAttribute("BuildingLevel")
			if typeof(level) == "number" and level > 0 then
				local perLevel = BuildingConfig.Upgrade.DragonNest.DragonSlotsPerLevel or 2
				baseSlots = math.floor(level * perLevel)
			end
		end
	else
		baseSlots = math.max(1, BuildingConfig.Upgrade.DragonNest.DragonSlotsPerLevel or 2)
	end
	return baseSlots + AscensionBonusService.GetFlatBonus(player, "ActiveDragonSlots")
end

local function isTutorialStep(player, stepNumber)
	if player:GetAttribute("TutorialCompleted") == true then
		return false
	end
	return (player:GetAttribute("TutorialStep") or 999) == stepNumber
end

local function getDragonSpawnBasePosition(island)
	local spawn = island:FindFirstChild("SpawnLocation", true)
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn.Position + Vector3.new(3, 0, 3)
	end
	if island and island:IsA("Model") then
		local cf, _ = island:GetBoundingBox()
		return cf.Position + Vector3.new(0, 2, 5)
	end
	return WorkspaceLayout.GetIslandSpawnCFrame().Position
end

local function getDragonUpgradeCost(level)
	level = math.max(1, math.floor(tonumber(level) or 1))
	return math.floor(HarvestConfig.DragonUpgradeBaseCost * (HarvestConfig.DragonUpgradeCostGrowth ^ (level - 1)))
end

local function getRarityStats(rarity)
	local rarityStats = HarvestConfig.DragonRarityStats or {}
	return rarityStats[rarity] or rarityStats.Common or {
		Harvest = 1,
		Flight = 1,
		Carry = 1,
		CriticalChance = HarvestConfig.DragonBaseCriticalChance or 0.03,
		Luck = HarvestConfig.DragonBaseLuck or 1,
	}
end

local function getDragonStats(level, rarity, evolutionLevel, dragonType)
	level = math.max(1, math.floor(tonumber(level) or 1))
	local safeEvolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(evolutionLevel)
	local evolutionStats = DragonEggConfig.GetEvolutionStatMultipliers(safeEvolutionLevel)
	local levelBonus = level - 1
	local rarityStats = getRarityStats(rarity or "Common")
	-- Species multiplier: dragons from later islands (and secret pulls) are inherently stronger,
	-- on top of rarity/level/star bonuses. See DragonEggConfig.SpeciesPowerMultiplier.
	local speciesMultiplier = DragonEggConfig.GetSpeciesPowerMultiplier(dragonType)
	local harvestMultiplier = (rarityStats.Harvest or 1) * (1 + levelBonus * HarvestConfig.DragonHarvestSpeedBonusPerLevel) * evolutionStats.HarvestSpeed * speciesMultiplier
	local flightSpeed = HarvestConfig.DragonMoveSpeed * (rarityStats.Flight or 1) * (1 + levelBonus * HarvestConfig.DragonMoveSpeedBonusPerLevel) * evolutionStats.FlightSpeed * speciesMultiplier
	local carryCapacity = math.max(1, math.floor(HarvestConfig.EssencePerHit * (rarityStats.Carry or 1) * (1 + levelBonus * HarvestConfig.DragonCarryCapacityBonusPerLevel) * evolutionStats.CarryCapacity * speciesMultiplier + 0.5))
	local luck = (rarityStats.Luck or HarvestConfig.DragonBaseLuck or 1) * (1 + levelBonus * HarvestConfig.DragonLuckBonusPerLevel) * evolutionStats.Luck
	local criticalChance = math.clamp((rarityStats.CriticalChance or HarvestConfig.DragonBaseCriticalChance or 0.03) + levelBonus * HarvestConfig.DragonCriticalChanceBonusPerLevel + evolutionStats.CriticalHarvestChance + (luck - 1) * 0.015, 0, 0.9)

	return {
		HarvestSpeed = harvestMultiplier,
		HarvestRate = math.max(HarvestConfig.DragonMinHarvestRate, HarvestConfig.HarvestRate / harvestMultiplier),
		FlightSpeed = flightSpeed,
		CarryCapacity = carryCapacity,
		CriticalHarvestChance = criticalChance,
		Luck = luck,
		XpGainMultiplier = evolutionStats.XpGain,
		CriticalMultiplier = HarvestConfig.DragonCriticalMultiplier or 2,
	}
end

local function getDragonMoveSpeed(level, rarity, evolutionLevel, dragonType)
	return getDragonStats(level, rarity, evolutionLevel, dragonType).FlightSpeed
end

local function getDragonHarvestRate(level, rarity, evolutionLevel, dragonType)
	return getDragonStats(level, rarity, evolutionLevel, dragonType).HarvestRate
end

-- Single source of truth for the rarity-tier glow baseline, shared by applyRarityEffects (initial
-- spawn) and applyEvolutionVisuals (every level-up/merge afterward) so the two never disagree and
-- a level-up can't quietly wipe out the glow a high-rarity dragon was spawned with.
local function getRarityGlowBase(rarity)
	if rarity == "Legendary" or rarity == "Mythic" or rarity == "Ancient" then
		return 3.5, 14
	elseif rarity == "Epic" then
		return 2.0, 10
	end
	return 0.3, 5
end

local function applyEvolutionVisuals(dragon)
	local model = dragon.model
	local root = dragon.root or (model and model:FindFirstChild("DragonRoot"))
	if not model or not root then
		return
	end
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(dragon.evolutionLevel)
	local rarityInfo = DragonEggConfig.GetRarityInfo(dragon.rarity or "Common")
	local visualMultipliers = DragonEggConfig.GetEvolutionVisualMultipliers(evolutionLevel)
	local stars = DragonEggConfig.GetEvolutionStars(evolutionLevel)
	local baseScale = model:GetAttribute("BaseDragonScale") or model:GetAttribute("DragonScale")
	if typeof(baseScale) == "number" then
		model:SetAttribute("BaseDragonScale", baseScale)
		model:ScaleTo(baseScale * visualMultipliers.Scale)
	end
	model:SetAttribute("EvolutionStars", stars)

	local glow = root:FindFirstChild("EvolutionGlow") or root:FindFirstChild("RarityGlow")
	if not glow then
		glow = Instance.new("PointLight")
		glow.Name = "EvolutionGlow"
		glow.Shadows = false
		glow.Parent = root
	end
	if glow:IsA("PointLight") then
		glow.Color = rarityInfo.Color
		-- Base brightness/range comes from rarity (see getRarityGlowBase - the same baseline
		-- applyRarityEffects sets at spawn), so a level-up or merge doesn't wipe out the "this is
		-- a good pull" glow a high-rarity dragon already had; evolution stars add on top of it.
		local rarityBrightness, rarityRange = getRarityGlowBase(dragon.rarity or "Common")
		glow.Brightness = rarityBrightness + evolutionLevel * 0.45 * visualMultipliers.GlowBrightness
		glow.Range = rarityRange + evolutionLevel * 2 * visualMultipliers.GlowRange
	end

	local aura = root:FindFirstChild("EvolutionAura")
	if evolutionLevel > 0 then
		if not aura then
			aura = Instance.new("ParticleEmitter")
			aura.Name = "EvolutionAura"
			aura.Color = ColorSequence.new(rarityInfo.Color)
			aura.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18),
				NumberSequenceKeypoint.new(1, 0),
			})
			aura.Lifetime = NumberRange.new(0.7, 1.4)
			aura.Speed = NumberRange.new(0.5, 1.6)
			aura.SpreadAngle = Vector2.new(180, 180)
			aura.LightEmission = 0.85
			aura.LightInfluence = 0
			aura.Parent = root
		end
		aura.Rate = math.floor((6 + evolutionLevel * 4) * visualMultipliers.ParticleRate)
	else
		if aura then
			aura.Enabled = false
		end
	end

	local trail = root:FindFirstChild("EvolutionTrail")
	if evolutionLevel > 1 then
		local front = root:FindFirstChild("EvolutionTrailFront")
		if not front then
			front = Instance.new("Attachment")
			front.Name = "EvolutionTrailFront"
			front.Position = Vector3.new(0, 0, -root.Size.Z * 0.4)
			front.Parent = root
		end
		local back = root:FindFirstChild("EvolutionTrailBack")
		if not back then
			back = Instance.new("Attachment")
			back.Name = "EvolutionTrailBack"
			back.Position = Vector3.new(0, 0, root.Size.Z * 0.5)
			back.Parent = root
		end
		if not trail then
			trail = Instance.new("Trail")
			trail.Name = "EvolutionTrail"
			trail.Attachment0 = front
			trail.Attachment1 = back
			trail.LightEmission = 0.8
			trail.Parent = root
		end
		trail.Color = ColorSequence.new(rarityInfo.Color)
		trail.Lifetime = 0.35 + evolutionLevel * 0.08
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, (0.25 + evolutionLevel * 0.08) * visualMultipliers.TrailWidth),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Enabled = true
	elseif trail then
		trail.Enabled = false
	end
end

local function applyDragonLevelAttributes(dragon)
	local level = math.max(1, dragon.level or 1)
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(dragon.evolutionLevel)
	local stats = getDragonStats(level, dragon.rarity, evolutionLevel, dragon.dragonType)
	local mergeCost = DragonEggConfig.GetEvolutionMergeCost(evolutionLevel)
	local stars = DragonEggConfig.GetEvolutionStars(evolutionLevel)
	dragon.model:SetAttribute("DragonLevel", level)
	dragon.model:SetAttribute("DragonEvolution", evolutionLevel)
	dragon.model:SetAttribute("EvolutionLevel", evolutionLevel)
	dragon.model:SetAttribute("EvolutionStars", stars)
	dragon.model:SetAttribute("MergeCost", mergeCost or 0)
	dragon.model:SetAttribute("UpgradeCost", getDragonUpgradeCost(level))
	dragon.model:SetAttribute("MoveSpeed", stats.FlightSpeed)
	dragon.model:SetAttribute("HarvestRate", stats.HarvestRate)
	dragon.model:SetAttribute("HarvestSpeed", stats.HarvestSpeed)
	dragon.model:SetAttribute("FlightSpeed", stats.FlightSpeed)
	dragon.model:SetAttribute("CarryCapacity", stats.CarryCapacity)
	dragon.model:SetAttribute("CriticalHarvestChance", stats.CriticalHarvestChance)
	dragon.model:SetAttribute("Luck", stats.Luck)
	dragon.model:SetAttribute("XpGainMultiplier", stats.XpGainMultiplier)
	dragon.model:SetAttribute("CriticalMultiplier", stats.CriticalMultiplier)

	local levelLabel = dragon.model:FindFirstChild("LevelLabel", true)
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = "Lv. " .. tostring(level) .. (stars ~= "" and " " .. stars or "")
	end
	applyEvolutionVisuals(dragon)
end

local function serializeDragon(dragon)
	return {
		type = dragon.dragonType or STARTER_DRAGON_TYPE,
		rarity = dragon.rarity or "Common",
		level = math.max(1, dragon.level or 1),
		evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(dragon.evolutionLevel),
	}
end

local function serializePlayerDragons(data)
	DragonInventoryService.EnsureStore(data)
	local savedDragons = {}
	for _, record in data.ownedDragonById do
		table.insert(savedDragons, {
			type = record.type or record.dragonType,
			rarity = record.rarity,
			level = record.level,
			evolutionLevel = record.evolutionLevel,
		})
	end
	return savedDragons
end

local function sanitizeMergeStats(rawStats)
	local stats = {
		MergeCount = 0,
		HighestEvolution = 0,
		ByDragonType = {},
	}
	if typeof(rawStats) ~= "table" then
		return stats
	end
	stats.MergeCount = math.max(0, math.floor(tonumber(rawStats.MergeCount) or 0))
	stats.HighestEvolution = DragonEggConfig.SanitizeEvolutionLevel(rawStats.HighestEvolution)
	if typeof(rawStats.ByDragonType) == "table" then
		for dragonType, count in rawStats.ByDragonType do
			if typeof(dragonType) == "string" then
				stats.ByDragonType[dragonType] = math.max(0, math.floor(tonumber(count) or 0))
			end
		end
	end
	return stats
end

local function loadDragonLevels(player)
	local data = getPlayerData(player)
	if not dataStoreAvailable or not dragonLevelStore then
		data.mergeStats = sanitizeMergeStats(data.mergeStats)
		DragonAbilityService.Load(player, nil)
		DragonInventoryService.MigrateFromLegacy(data)
		data.loaded = true
		return
	end

	local success, result = pcall(function()
		return dragonLevelStore:GetAsync(tostring(player.UserId))
	end)
	if success and typeof(result) == "table" then
		data.savedDragons = result.dragons or {}
		DragonInventoryService.LoadOwnedDragons(data, result.ownedDragons, result.nextOwnedDragonId)
		data.mergeStats = sanitizeMergeStats(result.mergeStats)
		DragonAbilityService.Load(player, result.dragonAbilities)
	elseif not success then
		warn("[DragonHarvestManager] Failed to load dragon levels for", player.UserId, result)
		data.mergeStats = sanitizeMergeStats(data.mergeStats)
	else
		data.mergeStats = sanitizeMergeStats(data.mergeStats)
	end
	data.loaded = true
	if not (success and typeof(result) == "table" and result.dragonAbilities) then
		DragonAbilityService.Load(player, nil)
	end
end

local function saveDragonLevels(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not dragonLevelStore then
		return
	end

	local savedDragons = serializePlayerDragons(data)
	local ownedDragons, nextOwnedDragonId = DragonInventoryService.SerializeOwnedDragons(data)
	local mergeStats = sanitizeMergeStats(data.mergeStats)
	local key = tostring(player.UserId)
	local success, err = pcall(function()
		dragonLevelStore:UpdateAsync(key, function()
			return {
				dragons = savedDragons,
				ownedDragons = ownedDragons,
				nextOwnedDragonId = nextOwnedDragonId,
				mergeStats = mergeStats,
				dragonAbilities = DragonAbilityService.Serialize(player),
				updatedAt = os.time(),
			}
		end)
	end)
	if not success then
		warn("[DragonHarvestManager] Failed to save dragon levels for", player.UserId, err)
	end
end

local function sanitizeEggStats(rawStats)
	local stats = {
		OwnedEggs = {},
		Purchases = {},
		Hatched = {},
		TotalPurchases = 0,
		TotalHatched = 0,
	}
	if typeof(rawStats) ~= "table" then
		return stats
	end
	for _, eggType in DragonEggConfig.GetRewardEggOrder() do
		stats.OwnedEggs[eggType] = math.max(0, math.floor(tonumber(rawStats.OwnedEggs and rawStats.OwnedEggs[eggType]) or 0))
		stats.Purchases[eggType] = math.max(0, math.floor(tonumber(rawStats.Purchases and rawStats.Purchases[eggType]) or 0))
		stats.Hatched[eggType] = math.max(0, math.floor(tonumber(rawStats.Hatched and rawStats.Hatched[eggType]) or 0))
	end
	stats.TotalPurchases = math.max(0, math.floor(tonumber(rawStats.TotalPurchases) or 0))
	stats.TotalHatched = math.max(0, math.floor(tonumber(rawStats.TotalHatched) or 0))
	return stats
end

local function loadEggProgress(player)
	local data = getPlayerData(player)
	if not dataStoreAvailable or not eggProgressStore then
		data.eggStats = sanitizeEggStats(data.eggStats)
		data.eggStatsLoaded = true
		return
	end

	local success, result = pcall(function()
		return eggProgressStore:GetAsync(tostring(player.UserId))
	end)
	if success and typeof(result) == "table" then
		data.eggStats = sanitizeEggStats(result)
	elseif not success then
		warn("[DragonHarvestManager] Failed to load egg progress for", player.UserId, result)
		data.eggStats = sanitizeEggStats(data.eggStats)
	end
	data.eggStatsLoaded = true
end

local function saveEggProgress(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not eggProgressStore then
		return
	end

	local eggStats = sanitizeEggStats(data.eggStats)
	local key = tostring(player.UserId)
	local success, err = pcall(function()
		eggProgressStore:UpdateAsync(key, function()
			return {
				OwnedEggs = eggStats.OwnedEggs,
				Purchases = eggStats.Purchases,
				Hatched = eggStats.Hatched,
				TotalPurchases = eggStats.TotalPurchases,
				TotalHatched = eggStats.TotalHatched,
				updatedAt = os.time(),
			}
		end)
	end)
	if not success then
		warn("[DragonHarvestManager] Failed to save egg progress for", player.UserId, err)
	end
end

local function getSavedDragonSpawnOptions(data, fallbackOptions)
	local saved = data.savedDragons[data.nextSavedDragonIndex]
	data.nextSavedDragonIndex += 1
	if typeof(saved) == "table" then
		return {
			dragonType = saved.type or fallbackOptions.dragonType or STARTER_DRAGON_TYPE,
			rarity = saved.rarity or fallbackOptions.rarity or "Common",
			level = math.max(1, math.floor(tonumber(saved.level) or 1)),
			evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(saved.evolutionLevel or saved.evolution or fallbackOptions.evolutionLevel or 0),
		}
	end
	return fallbackOptions
end

local function getPendingEggCounts(data)
	local counts = {}
	for _, eggType in DragonEggConfig.GetRewardEggOrder() do
		counts[eggType] = 0
	end
	for _, eggRecord in data.eggs do
		local eggType = eggRecord.eggType or "Common"
		counts[eggType] = (counts[eggType] or 0) + 1
	end
	return counts
end

local function sendEggShopUpdate(player, message)
	local data = getPlayerData(player)
	EggShopUpdate:FireClient(player, {
		essence = data.essence,
		ownedEggs = getPendingEggCounts(data),
		eggStats = sanitizeEggStats(data.eggStats),
		message = message,
	})
end

local function sendUIUpdate(player)
	local data = getPlayerData(player)
	player:SetAttribute("DragonEssence", data.essence)
	local activeWorkers = 0
	for _, dragon in data.dragons do
		if dragon.state ~= "idle" then
			activeWorkers += 1
		end
	end
	local activeCount = DragonInventoryService.GetEquippedCount(data)
	local storageCount = DragonInventoryService.GetOwnedCount(data)
	local storageMax = DragonInventoryService.GetStorageCapacity(player)
	HarvestUIUpdate:FireClient(
		player,
		data.essence,
		activeCount,
		activeWorkers,
		getPlayerDragonSlotLimit(player),
		storageCount,
		storageMax
	)
	sendEggShopUpdate(player)
end

local function getDragonMergePayload(player, message)
	local data = getPlayerData(player)
	return DragonInventoryService.BuildInventoryPayload(player, data, message)
end

local function sendDragonMergeUpdate(player, message, result)
	local payload = getDragonMergePayload(player, message)
	payload.result = result
	DragonMergeUpdate:FireClient(player, payload)
end

local function getIslandCenter(island)
	if island and island:IsA("Model") then
		local cf, _ = island:GetBoundingBox()
		return cf.Position
	end
	local mainIsland = WorkspaceLayout.GetMainIsland()
	if mainIsland then
		local cf, _ = mainIsland:GetBoundingBox()
		return cf.Position
	end
	if island and island:GetAttribute("BaseIslandCenter") then
		return island:GetAttribute("BaseIslandCenter")
	end
	return WorkspaceLayout.GetIslandSpawnCFrame().Position
end

local function getDragonModelTemplate(dragonType)
	print("Spawning:", dragonType)

	local model = dragonModelsFolder:FindFirstChild(dragonType)
	if not model or not model:IsA("Model") then
		warn("Missing dragon model in ServerStorage/DragonWorker:", dragonType)
		model = dragonModelsFolder:FindFirstChild(STARTER_DRAGON_TYPE)
	end

	if model then
		print("Using model:", model.Name)
	end

	return model
end

local function getDragonBody(clone)
	return clone:FindFirstChildWhichIsA("MeshPart", true)
		or clone:FindFirstChild("Body", true)
		or clone:FindFirstChildWhichIsA("BasePart", true)
end

local function createRarityLight(body, rarityInfo, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = "RarityGlow"
	light.Color = rarityInfo.Color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = body
	return light
end

local function createRarityAttachment(body, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = body
	return attachment
end

local function createRarityParticle(body, name, rarityInfo, effectScale, rate, lifetime, size)
	local particle = Instance.new("ParticleEmitter")
	particle.Name = name
	particle.Color = ColorSequence.new(rarityInfo.Color)
	particle.Size = size
	particle.Lifetime = lifetime
	particle.Rate = rate
	particle.Speed = NumberRange.new(0.5 * effectScale, 2 * effectScale)
	particle.SpreadAngle = Vector2.new(80, 80)
	particle.LightEmission = 0.7
	particle.LightInfluence = 0
	particle.Enabled = true
	particle.Parent = body
	return particle
end

local function applyRarityEffects(clone, rarity, scaleFactor)
	local rarityInfo = DragonEggConfig.GetRarityInfo(rarity)
	local body = getDragonBody(clone)
	if not body then
		return
	end

	local effectScale = scaleFactor / HarvestConfig.BaseDragonScale
	local bodySize = body.Size
	local rarityBrightness, rarityRange = getRarityGlowBase(rarity)
	createRarityLight(body, rarityInfo, rarityBrightness, rarityRange * effectScale)

	if rarity == "Rare" then
		createRarityParticle(
			body,
			"RarityMist",
			rarityInfo,
			effectScale,
			6,
			NumberRange.new(0.8, 1.2),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6 * effectScale),
				NumberSequenceKeypoint.new(1, 1.3 * effectScale),
			})
		)
	end

	if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" or rarity == "Ancient" then
		local trailFront = createRarityAttachment(body, "RarityTrailFront", Vector3.new(0, 0, -bodySize.Z * 0.35))
		local trailBack = createRarityAttachment(body, "RarityTrailBack", Vector3.new(0, 0, bodySize.Z * 0.45))
		local trail = Instance.new("Trail")
		trail.Name = "RarityTrail"
		trail.Attachment0 = trailFront
		trail.Attachment1 = trailBack
		trail.Color = ColorSequence.new(rarityInfo.Color)
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Lifetime = 0.55
		trail.MinLength = 0.2
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9 * effectScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.LightEmission = 0.75
		trail.Enabled = true
		trail.Parent = body
	end

	if rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" or rarity == "Ancient" then
		local aura = createRarityParticle(
			body,
			"RarityAura",
			rarityInfo,
			effectScale,
			10,
			NumberRange.new(0.8, 1.3),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.0 * effectScale),
				NumberSequenceKeypoint.new(1, 2.2 * effectScale),
			})
		)
		aura.Speed = NumberRange.new(0.2 * effectScale, 0.8 * effectScale)
		aura.SpreadAngle = Vector2.new(180, 180)
	end

	if rarity == "Legendary" or rarity == "Mythic" or rarity == "Ancient" then
		local sparkles = createRarityParticle(
			body,
			"RaritySparkles",
			rarityInfo,
			effectScale,
			18,
			NumberRange.new(0.4, 0.8),
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35 * effectScale),
				NumberSequenceKeypoint.new(0.5, 0.55 * effectScale),
				NumberSequenceKeypoint.new(1, 0),
			})
		)
		sparkles.Speed = NumberRange.new(1.5 * effectScale, 3.5 * effectScale)
		sparkles.Rotation = NumberRange.new(0, 360)
		sparkles.RotSpeed = NumberRange.new(-120, 120)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
	end
end

local function ensureDragonHealthBar(clone, body, rarity)
	local rarityInfo = DragonEggConfig.GetRarityInfo(rarity or "Common")
	local _, boundsSize = clone:GetBoundingBox()
	local headOffset = boundsSize.Y * 0.5 + 0.4 * HarvestConfig.DragonScaleMultiplier

	local billboard = body:FindFirstChild("DragonHealthBar")
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "DragonHealthBar"
		billboard.Size = UDim2.fromOffset(92, 42)
		billboard.AlwaysOnTop = true
		billboard.Parent = body

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Name = "RarityLabel"
		rarityLabel.Size = UDim2.new(1, 0, 0, 12)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.Text = "Common"
		rarityLabel.TextScaled = true
		rarityLabel.TextStrokeTransparency = 0.4
		rarityLabel.Parent = billboard

		local levelLabel = Instance.new("TextLabel")
		levelLabel.Name = "LevelLabel"
		levelLabel.Size = UDim2.new(1, 0, 0, 16)
		levelLabel.Position = UDim2.fromOffset(0, 12)
		levelLabel.BackgroundTransparency = 1
		levelLabel.Font = Enum.Font.GothamBold
		levelLabel.Text = "Lv. 1"
		levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		levelLabel.TextScaled = true
		levelLabel.TextStrokeTransparency = 0.35
		levelLabel.Parent = billboard

		local back = Instance.new("Frame")
		back.Name = "HealthBack"
		back.Size = UDim2.new(1, 0, 0, 10)
		back.Position = UDim2.new(0, 0, 0, 30)
		back.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		back.BorderSizePixel = 0
		back.Parent = billboard

		local backCorner = Instance.new("UICorner")
		backCorner.CornerRadius = UDim.new(0, 3)
		backCorner.Parent = back

		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.Parent = back

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 3)
		fillCorner.Parent = fill
	end

	billboard.StudsOffset = Vector3.new(0, headOffset, 0)

	local rarityLabel = billboard:FindFirstChild("RarityLabel")
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = rarity or "Common"
		rarityLabel.TextColor3 = rarityInfo.Color
	end

	local fill = billboard:FindFirstChild("Fill", true)
	if fill then
		fill.BackgroundColor3 = rarityInfo.Color
	end
end

local function prepareDragonModel(clone, rarity)
	local rarityInfo = DragonEggConfig.GetRarityInfo(rarity or "Common")
	local scaleFactor = HarvestConfig.BaseDragonScale * (0.9 + math.random() * 0.2) * (1 + rarityInfo.ScaleBonus)
	clone:ScaleTo(scaleFactor)

	local body = getDragonBody(clone)
	if not body then
		warn("No body part found on dragon model:", clone.Name)
		return nil
	end

	body.Name = "DragonRoot"
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	clone.PrimaryPart = body

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= body then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = descendant
			weld.Parent = body
		end
	end

	applyRarityEffects(clone, rarity, scaleFactor)
	ensureDragonHealthBar(clone, body, rarity)
	clone:SetAttribute("DragonScale", scaleFactor)
	return body
end

local function getEquipSpawnPosition(player)
	local data = getPlayerData(player)
	local island = data.island or WorkspaceLayout.GetPlayerIsland(player)
	if island then
		return getDragonSpawnBasePosition(island)
	end
	return WorkspaceLayout.GetIslandSpawnCFrame().Position
end

local function despawnRuntimeDragon(data, dragon)
	if not dragon then
		return
	end
	if dragon.model and dragon.model.Parent then
		dragon.model:Destroy()
	end
	for index = #data.dragons, 1, -1 do
		if data.dragons[index] == dragon then
			table.remove(data.dragons, index)
			break
		end
	end
	DragonAIController.AssignFormationIndices(data)
end

local function spawnOwnedDragon(player, data, ownedRecord, position)
	if not ownedRecord then
		return nil
	end
	if #data.dragons >= getPlayerDragonSlotLimit(player) then
		return nil
	end

	nextDragonId += 1
	local runtimeId = nextDragonId
	local dragonType = ownedRecord.dragonType or ownedRecord.type or STARTER_DRAGON_TYPE
	local rarity = ownedRecord.rarity or "Common"
	local level = math.max(1, math.floor(tonumber(ownedRecord.level) or 1))
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(ownedRecord.evolutionLevel)
	local template = getDragonModelTemplate(dragonType)
	if not template then
		return nil
	end

	local clone = template:Clone()
	clone.Name = dragonType .. "_" .. player.Name .. "_Dragon_" .. runtimeId
	clone:SetAttribute("OwnerUserId", player.UserId)
	clone:SetAttribute("DragonId", runtimeId)
	clone:SetAttribute("OwnedDragonId", ownedRecord.id)
	clone:SetAttribute("DragonType", dragonType)
	clone:SetAttribute("DragonRarity", rarity)
	clone:SetAttribute("DragonEvolution", evolutionLevel)
	clone:SetAttribute("EvolutionLevel", evolutionLevel)
	clone:SetAttribute("DragonState", "idle")

	local root = prepareDragonModel(clone, rarity)
	if not root then
		clone:Destroy()
		return nil
	end
	root.CFrame = CFrame.new(position)
	clone.Parent = dragonsFolder

	local dragon = {
		id = runtimeId,
		ownedId = ownedRecord.id,
		model = clone,
		root = root,
		position = position,
		state = "idle",
		targetNode = nil,
		harvestTimer = 0,
		dragonType = dragonType,
		rarity = rarity,
		level = level,
		evolutionLevel = evolutionLevel,
		formationIndex = #data.dragons + 1,
		stuckTimer = 0,
		lastMoveCheckPos = position,
	}

	clone:SetAttribute("ServerPosition", position)
	applyDragonLevelAttributes(dragon)
	table.insert(data.dragons, dragon)
	DragonAIController.AssignFormationIndices(data)
	return dragon
end

local function setupNode(node, ownerUserId, maxHealth)
	node:SetAttribute("OwnerUserId", ownerUserId)
	node:SetAttribute("MaxHealth", maxHealth)
	node:SetAttribute("Health", maxHealth)
	node:SetAttribute("Depleted", false)

	if node:IsA("BasePart") then
		node.Anchored = true
		node.CanCollide = true
	end
	for _, part in node:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
		end
	end
end

local function revealResourceNode(node)
	local parts = {}
	if node:IsA("BasePart") then
		table.insert(parts, node)
	end
	for _, descendant in node:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	for _, part in parts do
		local finalSize = part.Size
		part:SetAttribute("ExpansionNodeFinalSize", finalSize)
		part.Transparency = 1
		part.Size = finalSize * 0.15
		part.CanCollide = false
	end

	task.delay(2.35, function()
		for _, part in parts do
			if part.Parent then
				local finalSize = part:GetAttribute("ExpansionNodeFinalSize")
				if typeof(finalSize) == "Vector3" then
					part.CanCollide = true
					local tween = TweenService:Create(part, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = finalSize,
						Transparency = 0,
					})
					tween:Play()
				else
					part.Transparency = 0
					part.CanCollide = true
				end
			end
		end
	end)
end

local function getNodeHalfHeight(node)
	if node:IsA("Model") then
		local _, size = node:GetBoundingBox()
		return size.Y * 0.5
	elseif node:IsA("BasePart") then
		return node.Size.Y * 0.5
	end
	return 1.2
end

local function getCrystalSpawnCFrame(spawnPoint, node)
	local upOffset = spawnPoint.Size.Y * 0.5 + getNodeHalfHeight(node) + (HarvestConfig.CrystalSpawnYOffset or 1.25)
	local position = spawnPoint.Position + Vector3.new(0, upOffset, 0)
	local yaw = math.random() * math.pi * 2
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

local function prepareCrystalNode(node)
	local scale = HarvestConfig.CrystalScale or 3.35
	if node:IsA("Model") and scale ~= 1 then
		node:ScaleTo(scale)
	end
	node:SetAttribute("CrystalScale", scale)
end

local function spawnResourceNodeAt(player, spawnPoint, name)
	local data = getPlayerData(player)
	if not spawnPoint or not spawnPoint.Parent then
		return nil
	end
	if spawnPoint:GetAttribute("OccupiedCrystal") then
		return nil
	end

	local node = nodeTemplate:Clone()
	node.Name = name
	prepareCrystalNode(node)
	setupNode(node, player.UserId, HarvestConfig.NodeMaxHealth)
	node:SetAttribute("SpawnPointName", spawnPoint.Name)
	node:PivotTo(getCrystalSpawnCFrame(spawnPoint, node))
	node.Parent = nodesFolder
	spawnPoint:SetAttribute("OccupiedCrystal", node.Name)
	table.insert(data.nodes, node)
	return node
end

local function clearExistingPlayerNodes(player, data)
	for _, node in data.nodes do
		if node and node.Parent then
			local spawnName = node:GetAttribute("SpawnPointName")
			local spawnPoint = spawnName and workspace:FindFirstChild(spawnName)
			if spawnPoint then
				spawnPoint:SetAttribute("OccupiedCrystal", nil)
			end
			node:Destroy()
		end
	end
	table.clear(data.nodes)

	for _, node in nodesFolder:GetChildren() do
		if node:GetAttribute("OwnerUserId") == player.UserId then
			local spawnName = node:GetAttribute("SpawnPointName")
			local spawnPoint = spawnName and workspace:FindFirstChild(spawnName)
			if spawnPoint then
				spawnPoint:SetAttribute("OccupiedCrystal", nil)
			end
			node:Destroy()
		end
	end
end

local function spawnResourceNodes(player)
	local data = getPlayerData(player)
	clearExistingPlayerNodes(player, data)
	for _, spawnPoint in WorkspaceLayout.GetCrystalSpawnPoints() do
		spawnResourceNodeAt(player, spawnPoint, player.Name .. "_Crystal_" .. spawnPoint.Name)
	end
	autoAssignIdleDragons(player, data)
end

local function countPendingWorkers(data)
	return #data.dragons + #data.eggs
end

local function removeEggRecord(data, eggRecord)
	for index, egg in data.eggs do
		if egg == eggRecord then
			table.remove(data.eggs, index)
			return
		end
	end
end

local function createDragon(player, position, options)
	options = options or {}
	local data = getPlayerData(player)
	if #data.dragons >= getPlayerDragonSlotLimit(player) then
		return nil
	end

	nextDragonId += 1
	local dragonId = nextDragonId

	local dragonType = options.dragonType or STARTER_DRAGON_TYPE
	local rarity = options.rarity or "Common"
	local level = math.max(1, math.floor(tonumber(options.level) or 1))
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(options.evolutionLevel)
	local template = getDragonModelTemplate(dragonType)
	if not template then
		return nil
	end

	local clone = template:Clone()
	clone.Name = dragonType .. "_" .. player.Name .. "_Dragon_" .. dragonId
	clone:SetAttribute("OwnerUserId", player.UserId)
	clone:SetAttribute("DragonId", dragonId)
	clone:SetAttribute("DragonType", dragonType)
	clone:SetAttribute("DragonRarity", rarity)
	clone:SetAttribute("DragonEvolution", evolutionLevel)
	clone:SetAttribute("EvolutionLevel", evolutionLevel)
	clone:SetAttribute("DragonState", "idle")

	local root = prepareDragonModel(clone, rarity)
	if not root then
		clone:Destroy()
		return nil
	end
	root.CFrame = CFrame.new(position)
	clone.Parent = dragonsFolder

	local dragon = {
		id = dragonId,
		model = clone,
		root = root,
		position = position,
		state = "idle",
		targetNode = nil,
		harvestTimer = 0,
		dragonType = dragonType,
		rarity = rarity,
		level = level,
		evolutionLevel = evolutionLevel,
		formationIndex = #data.dragons + 1,
		stuckTimer = 0,
		lastMoveCheckPos = position,
	}

	clone:SetAttribute("ServerPosition", position)
	applyDragonLevelAttributes(dragon)
	table.insert(data.dragons, dragon)
	DragonAIController.AssignFormationIndices(data)
	return dragon
end

local function ensureDragonSlotsFilled(player)
	local data = getPlayerData(player)
	if not data.island then
		return
	end
	autoAssignIdleDragons(player, data)
	sendUIUpdate(player)
end

local function watchDragonNestSlots(player)
	local nest = getDragonNestModel(player)
	if not nest then
		return
	end

	local connection = nestSlotConnections[player]
	if connection then
		connection:Disconnect()
	end

	local lastSlots = getPlayerDragonSlotLimit(player)
	nestSlotConnections[player] = nest:GetAttributeChangedSignal("ActiveDragonSlots"):Connect(function()
		local newSlots = getPlayerDragonSlotLimit(player)
		if newSlots > lastSlots then
			ensureDragonSlotsFilled(player)
		end
		lastSlots = newSlots
	end)
end

local function rollHatchResults(eggRecord)
	local eggType = eggRecord.eggType or "Common"
	local rolledDragonType = DragonEggConfig.RollDragonType(eggType)
	if not rolledDragonType then
		return nil
	end

	local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
	return {
		eggType = eggType,
		rolledDragonType = rolledDragonType,
		dragonModelName = DragonEggConfig.GetDragonModelName(rolledDragonType),
		rarity = eggInfo.GuaranteedRarity or AscensionBonusService.RollHatchRarity(player),
		eggInfo = eggInfo,
	}
end

local function finalizeHatch(player, eggRecord, rollResults)
	if eggRecord.hatchId then
		pendingHatches[eggRecord.hatchId] = nil
	end

	local data = getPlayerData(player)
	if not player.Parent then
		return
	end

	removeEggRecord(data, eggRecord)

	local position = eggRecord.position
	if eggRecord.model and eggRecord.model.Parent then
		position = eggRecord.model:GetPivot().Position
		eggRecord.model:Destroy()
	end

	if not rollResults then
		sendUIUpdate(player)
		return
	end

	if not DragonInventoryService.CanAddToStorage(player, data) and not isTutorialStep(player, 3) then
		DragonStorageFull:FireClient(player, {
			storageCount = DragonInventoryService.GetOwnedCount(data),
			storageMax = DragonInventoryService.GetStorageCapacity(player),
		})
		sendUIUpdate(player)
		return
	end

	local ownedRecord = DragonInventoryService.AddOwnedDragon(data, {
		dragonType = rollResults.dragonModelName,
		rarity = rollResults.rarity,
		level = 1,
		evolutionLevel = 0,
	})

	local eggType = rollResults.eggType
	local stats = sanitizeEggStats(data.eggStats)
	stats.OwnedEggs[eggType] = math.max(0, (stats.OwnedEggs[eggType] or 0) - 1)
	stats.Hatched[eggType] = (stats.Hatched[eggType] or 0) + 1
	stats.TotalHatched += 1
	data.eggStats = stats
	saveDragonLevels(player)
	saveEggProgress(player)
	TutorialProgressSignal:Fire(player, "HatchFirstDragon")
	AchievementProgressSignal:Fire(player, "HatchDragon", 1, {
		eggType = eggType,
		rarity = rollResults.rarity,
		dragonType = rollResults.rolledDragonType,
		dragonModelName = rollResults.dragonModelName,
	})
	EggHatched:FireClient(player, rollResults.rarity, rollResults.rolledDragonType, nil, eggType, ownedRecord.id)
	sendUIUpdate(player)
	sendDragonMergeUpdate(player, "Hatched " .. DragonEggConfig.GetDragonDisplayName(rollResults.rolledDragonType) .. " into storage")
end

local function beginHatchSequence(player, eggRecord)
	if not player.Parent or not eggRecord.model or not eggRecord.model.Parent then
		removeEggRecord(getPlayerData(player), eggRecord)
		return
	end

	local rollResults = rollHatchResults(eggRecord)
	if not rollResults then
		removeEggRecord(getPlayerData(player), eggRecord)
		if eggRecord.model and eggRecord.model.Parent then
			eggRecord.model:Destroy()
		end
		sendUIUpdate(player)
		return
	end

	local hatchId = player.UserId .. "_" .. tostring(math.floor(workspace:GetServerTimeNow() * 1000))
	eggRecord.hatchId = hatchId
	eggRecord.model:SetAttribute("Hatching", true)

	local EggOpeningConfig = require(ReplicatedStorage:WaitForChild("EggOpening"):WaitForChild("EggOpeningConfig"))
	local EggModelRegistry = require(ReplicatedStorage:WaitForChild("EggOpening"):WaitForChild("EggModelRegistry"))
	local profile = EggOpeningConfig.GetProfile(rollResults.rarity)
	local eggInfo = rollResults.eggInfo
	local modelFolder = eggRecord.model:GetAttribute("ModelFolder")
		or EggModelRegistry.ResolveFolderName(rollResults.eggType)

	pendingHatches[hatchId] = {
		player = player,
		eggRecord = eggRecord,
		rollResults = rollResults,
	}

	EggHatchStart:FireClient(player, {
		hatchId = hatchId,
		eggType = rollResults.eggType,
		eggDisplayName = eggInfo.DisplayName,
		rarity = rollResults.rarity,
		dragonType = rollResults.rolledDragonType,
		dragonDisplayName = DragonEggConfig.GetDragonDisplayName(rollResults.rolledDragonType),
		eggColor = eggInfo.EggColor,
		spotColor = eggInfo.SpotColor,
		glowColor = eggInfo.GlowColor,
		modelFolder = modelFolder,
		worldPosition = eggRecord.model:GetPivot().Position,
	})

	task.delay(math.max(18, EggOpeningConfig.GetEstimatedDuration(profile) + 2), function()
		if pendingHatches[hatchId] then
			finalizeHatch(player, eggRecord, rollResults)
		end
	end)
end

local function createEgg(player, position, eggType, options)
	eggType = DragonEggConfig.IsValidEggType(eggType) and eggType or "Common"
	options = typeof(options) == "table" and options or {}
	local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
	local data = getPlayerData(player)
	if eggInfo.RewardOnly and not options.rewardGranted then
		sendEggShopUpdate(player, eggInfo.DisplayName .. " is earned from rewards")
		return
	end
	if eggInfo.Reserved or not eggInfo.Dragons or #eggInfo.Dragons == 0 then
		sendEggShopUpdate(player, eggInfo.DisplayName .. " is reserved for future dragons")
		return
	end
	if eggInfo.RequiresIsland and not options.rewardGranted then
		local unlockChecker = BiomeResourceRegistry.IsIslandUnlockedForPlayer
		if typeof(unlockChecker) == "function" and not unlockChecker(player, eggInfo.RequiresIsland) then
			local island = IslandUnlockConfig.GetIslandById(eggInfo.RequiresIsland)
			sendEggShopUpdate(player, "Unlock " .. (island and island.DisplayName or eggInfo.RequiresIsland) .. " first")
			return
		end
	end
	if not options.rewardGranted and data.essence < eggInfo.Cost then
		sendEggShopUpdate(player, "Need " .. tostring(eggInfo.Cost) .. " Dragon Essence")
		return
	end
	if #data.eggs >= 1 then
		sendEggShopUpdate(player, "Finish hatching your current egg first")
		return
	end
	if not DragonInventoryService.CanAddToStorage(player, data) and not isTutorialStep(player, 2) then
		DragonStorageFull:FireClient(player, {
			storageCount = DragonInventoryService.GetOwnedCount(data),
			storageMax = DragonInventoryService.GetStorageCapacity(player),
		})
		sendEggShopUpdate(player, "Dragon Storage is full")
		return
	end

	if not options.rewardGranted then
		data.essence -= eggInfo.Cost
	end
	local stats = sanitizeEggStats(data.eggStats)
	stats.OwnedEggs[eggType] = (stats.OwnedEggs[eggType] or 0) + 1
	stats.Purchases[eggType] = (stats.Purchases[eggType] or 0) + 1
	stats.TotalPurchases += 1
	data.eggStats = stats
	if not options.rewardGranted then
		TutorialProgressSignal:Fire(player, "BuyFirstEgg")
	end
	AchievementProgressSignal:Fire(player, "OpenEgg", 1, { eggType = eggType })

	local eggModel = DragonEggFactory.Create(eggType, eggInfo)
	if not eggModel then
		if not options.rewardGranted then
			data.essence += eggInfo.Cost
		end
		stats.OwnedEggs[eggType] = math.max(0, (stats.OwnedEggs[eggType] or 0) - 1)
		stats.Purchases[eggType] = math.max(0, (stats.Purchases[eggType] or 0) - 1)
		stats.TotalPurchases = math.max(0, stats.TotalPurchases - 1)
		data.eggStats = stats
		sendEggShopUpdate(player, "Could not spawn egg model")
		return
	end
	eggModel.Name = player.Name .. "_" .. eggType .. "Egg_" .. tostring(math.floor(workspace:GetServerTimeNow() * 1000))
	eggModel:SetAttribute("OwnerUserId", player.UserId)
	eggModel:SetAttribute("EggType", eggType)
	eggModel:SetAttribute("EggDisplayName", eggInfo.DisplayName)
	eggModel:SetAttribute("HatchDuration", DragonEggConfig.HatchTime)
	eggModel:SetAttribute("HatchReadyAt", workspace:GetServerTimeNow() + DragonEggConfig.HatchTime)
	eggModel:PivotTo(CFrame.new(position))
	eggModel.Parent = eggsFolder

	local eggRecord = {
		model = eggModel,
		position = position,
		eggType = eggType,
	}
	table.insert(data.eggs, eggRecord)
	saveEggProgress(player)
	sendUIUpdate(player)
	sendEggShopUpdate(player, "Purchased " .. eggInfo.DisplayName)

	task.delay(DragonEggConfig.HatchTime, function()
		if not eggRecord.model or not eggRecord.model.Parent then
			removeEggRecord(data, eggRecord)
			return
		end
		beginHatchSequence(player, eggRecord)
	end)
end

local function spawnPlayerDragons(player, island)
	local data = getPlayerData(player)
	DragonInventoryService.EnsureStore(data)
	DragonInventoryService.MigrateFromLegacy(data)

	local basePosition = getDragonSpawnBasePosition(island)
	local equippedCount = 0
	local slotLimit = getPlayerDragonSlotLimit(player)

	if DragonInventoryService.GetOwnedCount(data) == 0 then
		local starterRecord = DragonInventoryService.AddOwnedDragon(data, {
			dragonType = STARTER_DRAGON_TYPE,
			rarity = "Common",
			level = 1,
			evolutionLevel = 0,
		})
		starterRecord.isEquipped = true
		spawnOwnedDragon(player, data, starterRecord, basePosition)
		saveDragonLevels(player)
		return
	end

	local equippedRecords = {}
	for _, record in data.ownedDragonById do
		if record.isEquipped then
			table.insert(equippedRecords, record)
		end
	end
	table.sort(equippedRecords, function(a, b)
		return (a.id or 0) < (b.id or 0)
	end)

	for index, record in equippedRecords do
		if index > slotLimit then
			record.isEquipped = false
			continue
		end
		local angle = (index - 1) * math.pi * 2 / math.max(1, slotLimit)
		local offset = Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
		if spawnOwnedDragon(player, data, record, basePosition + offset) then
			equippedCount += 1
		else
			record.isEquipped = false
		end
	end

	if equippedCount == 0 then
		local bestRecord
		local bestScore = -math.huge
		for _, record in data.ownedDragonById do
			local score = DragonInventoryService.ComputePowerScore(player, record)
			if score > bestScore then
				bestScore = score
				bestRecord = record
			end
		end
		if bestRecord then
			bestRecord.isEquipped = true
			spawnOwnedDragon(player, data, bestRecord, basePosition)
		end
	end
end

local function setupPlayerIsland(island)
	local ownerUserId = island:GetAttribute("OwnerUserId")
	if not ownerUserId then
		return false
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return false
	end

	local data = getPlayerData(player)
	if data.island then
		return true
	end

	local waitStartedAt = os.clock()
	while (not data.loaded or not data.eggStatsLoaded) and os.clock() - waitStartedAt < 10 do
		task.wait(0.1)
	end

	data.island = island
	data.currentIslandId = DragonAIController.GetPlayerIslandId(player)
	player:SetAttribute("CurrentIslandId", data.currentIslandId)
	DragonAIController.AssignFormationIndices(data)
	spawnResourceNodes(player)
	spawnPlayerDragons(player, island)
	watchDragonNestSlots(player)
	sendUIUpdate(player)
	return true
end

local function getNodePosition(node)
	local cf, _ = node:GetBoundingBox()
	return cf.Position
end

local function isAvailableNode(player, node)
	if not node or not node.Parent or node:GetAttribute("Depleted") then
		return false
	end
	if (node:GetAttribute("Health") or 0) <= 0 then
		return false
	end
	if BiomeResourceRegistry.IsBiomeNode(node) then
		return BiomeResourceRegistry.CanPlayerHarvest(player, node)
	end
	return node:GetAttribute("OwnerUserId") == player.UserId
end

local function isNodeAlreadyAssigned(data, node)
	for _, dragon in data.dragons do
		if dragon.targetNode == node and dragon.state ~= "idle" then
			return true
		end
	end
	return false
end

local function findClosestAvailableNode(player, data, dragon)
	return DragonAIController.FindClosestAvailableNode(player, data, dragon)
end

local function setDragonIdle(dragon)
	dragon.state = "idle"
	dragon.targetNode = nil
	dragon.harvestTimer = 0
	dragon.model:SetAttribute("DragonState", "idle")
	dragon.model:SetAttribute("TargetNodeName", "")
	dragon.model:SetAttribute("TargetLookPosition", nil)
	dragon.model:SetAttribute("TrainingAtAcademy", false)
end

local function setDragonTraining(dragon, anchorPosition)
	setDragonIdle(dragon)
	dragon.state = "training"
	dragon.model:SetAttribute("DragonState", "training")
	dragon.model:SetAttribute("TrainingAtAcademy", true)
	if typeof(anchorPosition) == "Vector3" then
		local offset = Vector3.new((dragon.id % 3 - 1) * 2.5, 0, math.floor(dragon.id / 3) * 2.5)
		dragon.position = anchorPosition + offset + Vector3.new(0, 2, 0)
		dragon.model:SetAttribute("ServerPosition", dragon.position)
		if dragon.root then
			dragon.root.CFrame = CFrame.new(dragon.position)
		end
	end
	for _, descendant in dragon.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = math.max(descendant.Transparency, 0.15)
		end
	end
end

local function releaseDragonFromTraining(dragon)
	for _, descendant in dragon.model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("OriginalTrainingTransparency") ~= nil then
			descendant.Transparency = descendant:GetAttribute("OriginalTrainingTransparency")
		elseif descendant:IsA("BasePart") and descendant.Transparency < 1 then
			descendant.Transparency = math.max(0, descendant.Transparency - 0.15)
		end
	end
	setDragonIdle(dragon)
end

local function assignSpecificDragonToNode(player, dragon, node)
	if not isAvailableNode(player, node) then
		return false
	end

	local data = getPlayerData(player)
	local islandId = data.currentIslandId or DragonAIController.GetPlayerIslandId(player)
	if not DragonAIController.IsHarvestIsland(islandId)
		or not DragonAIController.IsNodeOnIsland(player, node, islandId) then
		return false
	end

	dragon.state = "moving"
	dragon.targetNode = node
	dragon.harvestTimer = 0
	dragon.model:SetAttribute("DragonState", "moving")
	dragon.model:SetAttribute("TargetNodeName", node.Name)
	dragon.model:SetAttribute("TargetLookPosition", getNodePosition(node))
	return true
end

autoAssignIdleDragons = function(player, data)
	local assignedAny = false
	for _, dragon in data.dragons do
		if dragon.state == "idle" and dragon.model and dragon.model.Parent then
			local node = findClosestAvailableNode(player, data, dragon)
			if node and assignSpecificDragonToNode(player, dragon, node) then
				assignedAny = true
			end
		end
	end

	if assignedAny then
		sendUIUpdate(player)
	end
end

local function assignDragonToNode(player, node)
	local data = getPlayerData(player)

	if not isAvailableNode(player, node) then
		return
	end

	local closestDragon = nil
	local closestDistance = math.huge
	for _, dragon in data.dragons do
		if dragon.state == "idle" then
			local distance = (getNodePosition(node) - dragon.position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestDragon = dragon
			end
		end
	end

	if not closestDragon then
		return
	end

	if assignSpecificDragonToNode(player, closestDragon, node) then
		sendUIUpdate(player)
	end
end

local function respawnBiomeNode(spawnId)
	local record = BiomeResourceRegistry.GetSpawnRecord(spawnId)
	if not record then
		return
	end

	task.delay(HarvestConfig.NodeRespawnTime, function()
		if BiomeResourceRegistry.GetNode(spawnId) then
			return
		end
		BiomeResourcePlacer.SpawnFromRecord(record, nodesFolder)
		for activePlayer, activeData in pairs(playerData) do
			if activePlayer.Parent then
				DragonAIController.InvalidateNodeCache(activeData)
				autoAssignIdleDragons(activePlayer, activeData)
			end
		end
	end)
end

local function depleteNode(player, node)
	local health = node:GetAttribute("Health") or 0
	if health > 0 then
		return
	end

	if BiomeResourceRegistry.IsBiomeNode(node) then
		local spawnId = node:GetAttribute("SpawnId")
		DragonAIController.InvalidateNodeCache(getPlayerData(player))
		node:SetAttribute("Depleted", true)
		BiomeResourceRegistry.RegisterNode(nil, spawnId)
		NodeDepleted:FireClient(player, node)
		node:Destroy()
		if typeof(spawnId) == "string" then
			respawnBiomeNode(spawnId)
		end
		return
	end

	local data = getPlayerData(player)
	DragonAIController.InvalidateNodeCache(data)
	for index = #data.nodes, 1, -1 do
		if data.nodes[index] == node then
			table.remove(data.nodes, index)
			break
		end
	end

	node:SetAttribute("Depleted", true)
	local spawnName = node:GetAttribute("SpawnPointName")
	local spawnPoint = spawnName and workspace:FindFirstChild(spawnName)
	if spawnPoint then
		spawnPoint:SetAttribute("OccupiedCrystal", nil)
	end

	NodeDepleted:FireClient(player, node)
	node:Destroy()

	task.delay(HarvestConfig.NodeRespawnTime, function()
		local owner = Players:GetPlayerByUserId(player.UserId)
		local data = owner and playerData[owner]
		if not owner or not data then
			return
		end
		local freeSpawnPoint = spawnPoint
		if not freeSpawnPoint or not freeSpawnPoint.Parent or freeSpawnPoint:GetAttribute("OccupiedCrystal") then
			for _, point in WorkspaceLayout.GetCrystalSpawnPoints() do
				if not point:GetAttribute("OccupiedCrystal") then
					freeSpawnPoint = point
					break
				end
			end
		end
		if freeSpawnPoint and not freeSpawnPoint:GetAttribute("OccupiedCrystal") then
			local newNode = spawnResourceNodeAt(owner, freeSpawnPoint, owner.Name .. "_Crystal_" .. freeSpawnPoint.Name)
			if newNode then
				autoAssignIdleDragons(owner, data)
			end
		end
	end)
end

local function getActiveBoostMultiplier(player, boostId)
	local expiresAt = player:GetAttribute(boostId .. "ExpiresAt")
	if typeof(expiresAt) == "number" and expiresAt > os.time() then
		return math.max(1, tonumber(player:GetAttribute(boostId .. "Multiplier")) or 1)
	end
	return 1
end

local function performHarvestHit(player, dragon, node)
	local stats = getDragonStats(dragon.level, dragon.rarity, dragon.evolutionLevel, dragon.dragonType)
	local baseAmount = stats.CarryCapacity
	local isCritical = math.random() < stats.CriticalHarvestChance
	local harvestAmount = isCritical and math.floor(baseAmount * stats.CriticalMultiplier + 0.5) or baseAmount
	local essenceBoost = getActiveBoostMultiplier(player, "QuestEssenceBoost")
		* getActiveBoostMultiplier(player, "CraftEssenceBoost")
		* getActiveBoostMultiplier(player, "TutorialEssenceBoost")
	local harvestBonus = 1 + AscensionBonusService.GetBonus(player, "HarvestMultiplier")
	local islandId = node:GetAttribute("IslandId")
	local islandMultiplier = islandId and IslandUnlockConfig.GetEssenceMultiplier(islandId) or 1
	harvestAmount = math.max(1, math.floor(harvestAmount * essenceBoost * harvestBonus * islandMultiplier + 0.5))

	local abilityResult = DragonAbilityService.ProcessHarvestHit(player, dragon, node, {
		harvestAmount = harvestAmount,
		baseAmount = baseAmount,
		isCritical = isCritical,
		stats = stats,
	})

	local totalEssence = abilityResult.totalEssence
	local totalNodeDamage = abilityResult.totalNodeDamage
	local currentHealth = node:GetAttribute("Health") or HarvestConfig.NodeMaxHealth
	local health = math.max(0, currentHealth - totalNodeDamage)
	node:SetAttribute("Health", health)

	local data = getPlayerData(player)
	data.essence += totalEssence
	TutorialProgressSignal:Fire(player, "CollectDragonEssence")
	TutorialProgressSignal:Fire(player, "HarvestWithDragon")

	local primaryVfx = abilityResult.vfxTags and abilityResult.vfxTags[1]
	HarvestHit:FireClient(player, dragon.model, node, totalEssence, isCritical, primaryVfx)
	sendUIUpdate(player)

	if health <= 0 then
		local depletionResult = DragonAbilityService.OnNodeDepleted(player, dragon, node)
		if depletionResult.bonusEssence > 0 then
			data.essence += depletionResult.bonusEssence
			HarvestHit:FireClient(player, dragon.model, node, depletionResult.bonusEssence, false, depletionResult.vfxTag)
			sendUIUpdate(player)
		end
		local depletedNode = node
		setDragonIdle(dragon)
		depleteNode(player, depletedNode)
		autoAssignIdleDragons(player, data)
	end
end

local function updateDragon(player, dragon, dt)
	if dragon.state == "training" then
		return
	end

	local data = getPlayerData(player)

	if dragon.state == "moving" or dragon.state == "harvesting" then
		DragonAIController.UpdateDragonMovement(player, data, dragon, dt)
		if not DragonAIController.ValidateActiveHarvest(player, data, dragon) then
			setDragonIdle(dragon)
			autoAssignIdleDragons(player, data)
			return
		end
	end

	if dragon.state == "idle" then
		DragonAIController.UpdateIdleDragon(player, data, dragon, dt)
		return
	end
	if dragon.state == "moving" and dragon.targetNode then
		local node = dragon.targetNode
		if not isAvailableNode(player, node) then
			setDragonIdle(dragon)
			autoAssignIdleDragons(player, getPlayerData(player))
			return
		end

		local targetPos = getNodePosition(node)
		local offset = targetPos - dragon.position
		local distance = offset.Magnitude

		if distance <= HarvestConfig.HarvestDistance then
			if distance > 0.01 then
				dragon.position = targetPos - offset.Unit * math.min(HarvestConfig.HarvestStandoff, distance)
			end
			dragon.model:SetAttribute("ServerPosition", dragon.position)
			dragon.state = "harvesting"
			dragon.harvestTimer = 0
			dragon.model:SetAttribute("DragonState", "harvesting")
			dragon.model:SetAttribute("TargetLookPosition", targetPos)
			local lookAt = CFrame.lookAt(dragon.position, Vector3.new(targetPos.X, dragon.position.Y, targetPos.Z))
			dragon.model:SetAttribute("LookDirection", lookAt.LookVector)
		else
			local step = math.min(getDragonMoveSpeed(dragon.level, dragon.rarity, dragon.evolutionLevel, dragon.dragonType) * dt, distance)
			if distance > 0.01 then
				dragon.position += offset.Unit * step
			end
			dragon.model:SetAttribute("ServerPosition", dragon.position)
			dragon.model:SetAttribute("TargetLookPosition", targetPos)
			local lookAt = CFrame.lookAt(dragon.position, Vector3.new(targetPos.X, dragon.position.Y, targetPos.Z))
			dragon.model:SetAttribute("LookDirection", lookAt.LookVector)
		end
	elseif dragon.state == "harvesting" and dragon.targetNode then
		local node = dragon.targetNode
		if not isAvailableNode(player, node) then
			setDragonIdle(dragon)
			autoAssignIdleDragons(player, getPlayerData(player))
			return
		end

		dragon.harvestTimer += dt
		local targetPos = getNodePosition(node)
		dragon.model:SetAttribute("TargetLookPosition", targetPos)
		local lookAt = CFrame.lookAt(dragon.position, Vector3.new(targetPos.X, dragon.position.Y, targetPos.Z))
		dragon.model:SetAttribute("LookDirection", lookAt.LookVector)
		local harvestSpeedBoost = getActiveBoostMultiplier(player, "CraftHarvestBoost")
			* getActiveBoostMultiplier(player, "DailyWheelHarvestBoost")
		if dragon.harvestTimer >= getDragonHarvestRate(dragon.level, dragon.rarity, dragon.evolutionLevel, dragon.dragonType) / harvestSpeedBoost then
			dragon.harvestTimer = 0
			performHarvestHit(player, dragon, node)
			if dragon.state == "harvesting" and (node:GetAttribute("Health") or 0) > 0 then
				-- continue harvesting same node
			elseif dragon.state ~= "harvesting" then
				sendUIUpdate(player)
			end
		end
	end
end

local function findRuntimeDragonByOwnedId(data, ownedDragonId)
	local numericId = tonumber(ownedDragonId)
	if not numericId then
		return nil, nil
	end
	for index, dragon in data.dragons do
		if dragon.ownedId == numericId then
			return dragon, index
		end
	end
	return nil, nil
end

local function findDragonById(data, dragonId)
	local numericId = tonumber(dragonId)
	if not numericId then
		return nil, nil
	end
	for index, dragon in data.dragons do
		if dragon.id == numericId then
			return dragon, index
		end
	end
	return nil, nil
end

local function validateMergeSelection(player, dragonIds)
	if typeof(dragonIds) ~= "table" or #dragonIds ~= 3 then
		return false, "Select exactly 3 dragons", nil
	end
	local data = getPlayerData(player)
	local selected = {}
	local usedIds = {}
	for _, dragonId in dragonIds do
		local dragon, index = findRuntimeDragonByOwnedId(data, dragonId)
		if not dragon then
			dragon, index = findDragonById(data, dragonId)
		end
		if not dragon or not dragon.model or not dragon.model.Parent then
			return false, "One selected dragon is unavailable", nil
		end
		local ownedRecord = dragon.ownedId and DragonInventoryService.GetOwnedRecord(data, dragon.ownedId)
		if ownedRecord and ownedRecord.isLocked then
			return false, "Locked dragons cannot be merged", nil
		end
		if usedIds[dragon.id] then
			return false, "Select 3 different dragons", nil
		end
		usedIds[dragon.id] = true
		table.insert(selected, { dragon = dragon, index = index })
	end

	local first = selected[1].dragon
	local dragonType = first.dragonType or STARTER_DRAGON_TYPE
	local rarity = first.rarity or "Common"
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(first.evolutionLevel)
	if evolutionLevel >= DragonEggConfig.GetEvolutionMaxLevel() then
		return false, "Dragon is already at max evolution", nil
	end
	for _, item in selected do
		local dragon = item.dragon
		if (dragon.dragonType or STARTER_DRAGON_TYPE) ~= dragonType then
			return false, "Dragons must be the same type", nil
		end
		if (dragon.rarity or "Common") ~= rarity then
			return false, "Dragons must have the same rarity", nil
		end
		if DragonEggConfig.SanitizeEvolutionLevel(dragon.evolutionLevel) ~= evolutionLevel then
			return false, "Dragons must have the same evolution", nil
		end
	end

	local cost = DragonEggConfig.GetEvolutionMergeCost(evolutionLevel)
	if not cost then
		return false, "No merge cost configured", nil
	end
	if data.essence < cost then
		return false, "Need " .. tostring(cost) .. " Dragon Essence", nil
	end

	return true, "Ready", {
		data = data,
		selected = selected,
		dragonType = dragonType,
		rarity = rarity,
		evolutionLevel = evolutionLevel,
		level = math.max(1, first.level or 1),
		cost = cost,
		position = first.position,
	}
end

local function mergeDragons(player, dragonIds)
	local valid, message, context = validateMergeSelection(player, dragonIds)
	if not valid then
		sendDragonMergeUpdate(player, message, { success = false })
		return
	end

	local data = context.data
	local mergePosition = context.position
	data.essence -= context.cost

	table.sort(context.selected, function(a, b)
		return a.index > b.index
	end)
	for _, item in context.selected do
		local dragon = item.dragon
		if dragon.ownedId then
			data.ownedDragonById[dragon.ownedId] = nil
			data.ownedDragonCount = math.max(0, data.ownedDragonCount - 1)
		end
		if dragon.model and dragon.model.Parent then
			mergePosition = mergePosition or dragon.model:GetPivot().Position
			dragon.model:Destroy()
		end
		table.remove(data.dragons, item.index)
	end

	local mergedRecord = DragonInventoryService.AddOwnedDragon(data, {
		dragonType = context.dragonType,
		rarity = context.rarity,
		level = context.level,
		evolutionLevel = context.evolutionLevel + 1,
	})
	mergedRecord.isEquipped = true
	local newDragon = spawnOwnedDragon(player, data, mergedRecord, mergePosition or (data.island and getIslandCenter(data.island) + Vector3.new(0, 2, 0)) or Vector3.new(0, 5, 0))
	DragonAIController.AssignFormationIndices(data)

	local stats = sanitizeMergeStats(data.mergeStats)
	stats.MergeCount += 1
	stats.HighestEvolution = math.max(stats.HighestEvolution, context.evolutionLevel + 1)
	stats.ByDragonType[context.dragonType] = (stats.ByDragonType[context.dragonType] or 0) + 1
	data.mergeStats = stats

	DragonAbilityService.GrantMergeProgress(player, context.dragonType, context.evolutionLevel)

	QuestProgressSignal:Fire(player, "MergeDragons", 1)
	AchievementProgressSignal:Fire(player, "MergeDragon", 1, { evolutionLevel = context.evolutionLevel + 1 })

	saveDragonLevels(player)
	sendUIUpdate(player)
	sendDragonMergeUpdate(player, "Merged into " .. DragonEggConfig.GetDragonDisplayName(context.dragonType) .. " " .. DragonEggConfig.GetEvolutionStars(context.evolutionLevel + 1), {
		success = newDragon ~= nil,
		dragonId = newDragon and newDragon.id or nil,
		dragonType = context.dragonType,
		rarity = context.rarity,
		evolutionLevel = context.evolutionLevel + 1,
		position = mergePosition,
	})
end

RequestDragonMergeData.OnServerInvoke = function(player)
	return getDragonMergePayload(player)
end

MergeDragons.OnServerEvent:Connect(function(player, dragonIds)
	if not RateLimiter.check(player, "MergeDragons", 0.3) then
		return
	end
	mergeDragons(player, dragonIds)
end)

EquipDragon.OnServerEvent:Connect(function(player, ownedDragonId)
	local data = getPlayerData(player)
	local ok, message = DragonInventoryService.EquipDragon(player, data, ownedDragonId)
	saveDragonLevels(player)
	sendUIUpdate(player)
	sendDragonMergeUpdate(player, message)
end)

UnequipDragon.OnServerEvent:Connect(function(player, ownedDragonId)
	local data = getPlayerData(player)
	local ok, message = DragonInventoryService.UnequipDragon(player, data, ownedDragonId)
	saveDragonLevels(player)
	sendUIUpdate(player)
	sendDragonMergeUpdate(player, message)
end)

EquipBestDragons.OnServerEvent:Connect(function(player)
	local data = getPlayerData(player)
	local ok, message = DragonInventoryService.EquipBestDragons(player, data)
	saveDragonLevels(player)
	sendUIUpdate(player)
	sendDragonMergeUpdate(player, message)
end)

SetDragonFavorite.OnServerEvent:Connect(function(player, ownedDragonId, isFavorite)
	local data = getPlayerData(player)
	local ok, message = DragonInventoryService.SetFavorite(data, ownedDragonId, isFavorite)
	saveDragonLevels(player)
	sendDragonMergeUpdate(player, message)
end)

SetDragonLocked.OnServerEvent:Connect(function(player, ownedDragonId, isLocked)
	local data = getPlayerData(player)
	local ok, message = DragonInventoryService.SetLocked(data, ownedDragonId, isLocked)
	saveDragonLevels(player)
	sendDragonMergeUpdate(player, message)
end)

TargetNode.OnServerEvent:Connect(function(player, node)
	if typeof(node) ~= "Instance" or not node:IsDescendantOf(nodesFolder) then
		return
	end
	assignDragonToNode(player, node)
end)

local function getEggSpawnPosition(player)
	local data = getPlayerData(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		return rootPart.Position + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
	elseif data.island then
		return getIslandCenter(data.island) + Vector3.new(0, 2, 0)
	end
	return nil
end

BuyDragonEgg.OnServerEvent:Connect(function(player, eggType)
	if not RateLimiter.check(player, "BuyDragonEgg", 0.3) then
		return
	end
	eggType = DragonEggConfig.IsValidEggType(eggType) and eggType or "Common"
	local position = getEggSpawnPosition(player)
	if not position then
		return
	end

	createEgg(player, position, eggType)
end)

EggHatchComplete.OnServerEvent:Connect(function(player, hatchId)
	if not RateLimiter.check(player, "EggHatchComplete", 0.3) then
		return
	end
	if typeof(hatchId) ~= "string" then
		return
	end
	local pending = pendingHatches[hatchId]
	if not pending or pending.player ~= player then
		return
	end
	finalizeHatch(player, pending.eggRecord, pending.rollResults)
end)

GrantTutorialRewardEgg.Event:Connect(function(player, eggType)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local position = getEggSpawnPosition(player)
	if not position then
		return
	end
	createEgg(player, position, eggType, { rewardGranted = true })
end)

UpgradeDragon.OnServerEvent:Connect(function(player, dragonModel)
	if not RateLimiter.check(player, "UpgradeDragon", 0.3) then
		return
	end
	if typeof(dragonModel) ~= "Instance" or not dragonModel:IsDescendantOf(dragonsFolder) then
		return
	end
	if dragonModel:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end

	local data = getPlayerData(player)
	local selectedDragon
	for _, dragon in data.dragons do
		if dragon.model == dragonModel then
			selectedDragon = dragon
			break
		end
	end
	if not selectedDragon then
		return
	end

	local level = math.max(1, selectedDragon.level or 1)
	local maxLevel = DragonTrainingConfig.MaxDragonLevel or 50
	if level >= maxLevel then
		UpgradeDragon:FireClient(player, false, dragonModel, level, math.huge, data.essence)
		return
	end
	local cost = getDragonUpgradeCost(level)
	if data.essence < cost then
		UpgradeDragon:FireClient(player, false, dragonModel, level, cost, data.essence)
		return
	end

	data.essence -= cost
	selectedDragon.level = level + 1
	if selectedDragon.ownedId then
		local ownedRecord = DragonInventoryService.GetOwnedRecord(data, selectedDragon.ownedId)
		if ownedRecord then
			ownedRecord.level = selectedDragon.level
		end
	end
	applyDragonLevelAttributes(selectedDragon)
	sendUIUpdate(player)
	player:SetAttribute("DragonPower", math.floor(DragonInventoryService.ComputeTotalPower(player, data)))
	saveDragonLevels(player)
	AchievementProgressSignal:Fire(player, "DragonLevelUp", 0, { level = selectedDragon.level })
	UpgradeDragon:FireClient(player, true, dragonModel, selectedDragon.level, getDragonUpgradeCost(selectedDragon.level), data.essence)
end)

local function setupPlayerOnMainIsland(player)
	local waitStartedAt = os.clock()
	while player.Parent and os.clock() - waitStartedAt < 12 do
		local island = WorkspaceLayout.GetPlayerIsland(player)
		if island and setupPlayerIsland(island) then
			return
		end
		task.wait(0.2)
	end
	warn("[DragonHarvestManager] Main Island was not ready for", player.Name)
end

DragonInventoryService.Init({
	STARTER_DRAGON_TYPE = STARTER_DRAGON_TYPE,
	getPlayerDragonSlotLimit = getPlayerDragonSlotLimit,
	getDragonStats = getDragonStats,
	getDragonUpgradeCost = getDragonUpgradeCost,
	sanitizeMergeStats = sanitizeMergeStats,
	DragonAbilityService = DragonAbilityService,
	getEquipSpawnPosition = getEquipSpawnPosition,
	spawnOwnedDragon = spawnOwnedDragon,
	despawnRuntimeDragon = despawnRuntimeDragon,
	autoAssignIdleDragons = autoAssignIdleDragons,
})

Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("DragonEssence"):Connect(function()
		local data = playerData[player]
		if data then
			data.essence = player:GetAttribute("DragonEssence") or data.essence
		end
	end)
	player:GetAttributeChangedSignal("CurrentIslandId"):Connect(function()
		local data = playerData[player]
		if not data then
			return
		end
		local newIslandId = DragonAIController.GetPlayerIslandId(player)
		if newIslandId ~= data.currentIslandId then
			DragonAIController.HandleIslandChanged(player, data, data.currentIslandId, newIslandId)
		end
	end)
	task.spawn(loadDragonLevels, player)
	task.spawn(loadEggProgress, player)
	task.spawn(setupPlayerOnMainIsland, player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadDragonLevels, player)
	task.spawn(loadEggProgress, player)
	task.spawn(setupPlayerOnMainIsland, player)
end

DragonAIController.Init({
	nodesFolder = nodesFolder,
	HarvestConfig = HarvestConfig,
	getNodePosition = getNodePosition,
	isAvailableNode = isAvailableNode,
	isNodeAlreadyAssigned = isNodeAlreadyAssigned,
	setDragonIdle = setDragonIdle,
	autoAssignIdleDragons = autoAssignIdleDragons,
	getDragonMoveSpeed = getDragonMoveSpeed,
})

nodesFolder.ChildAdded:Connect(function()
	for activePlayer, activeData in pairs(playerData) do
		if activePlayer.Parent then
			DragonAIController.InvalidateNodeCache(activeData)
			activeData.autoAssignTimer = HarvestConfig.AutoAssignInterval
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for player, data in pairs(playerData) do
		if player.Parent then
			DragonAIController.UpdatePlayerIsland(player, data, dt)

			data.autoAssignTimer = (data.autoAssignTimer or 0) + dt
			if data.autoAssignTimer >= HarvestConfig.AutoAssignInterval then
				data.autoAssignTimer = 0
				autoAssignIdleDragons(player, data)
			end

			for _, dragon in data.dragons do
				updateDragon(player, dragon, dt)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local data = playerData[player]
	if not data then
		return
	end

	saveDragonLevels(player)
	saveEggProgress(player)

	local nestConnection = nestSlotConnections[player]
	if nestConnection then
		nestConnection:Disconnect()
		nestSlotConnections[player] = nil
	end

	for _, dragon in data.dragons do
		if dragon.model and dragon.model.Parent then
			dragon.model:Destroy()
		end
	end

	for _, egg in data.eggs do
		if egg.model and egg.model.Parent then
			egg.model:Destroy()
		end
	end

	for _, node in data.nodes do
		if node and node.Parent then
			node:Destroy()
		end
	end

	playerData[player] = nil
	DragonAbilityService.Release(player)
end)

DragonRosterBridge.register({
	getRoster = function(player)
		local data = getPlayerData(player)
		local roster = {}
		for _, record in data.ownedDragonById do
			local runtimeDragon = DragonInventoryService.GetRuntimeDragon(data, record.id)
			local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(record.evolutionLevel)
			table.insert(roster, {
				id = record.id,
				dragonType = record.dragonType or record.type or STARTER_DRAGON_TYPE,
				displayName = DragonEggConfig.GetDragonDisplayName(record.dragonType or record.type or STARTER_DRAGON_TYPE),
				rarity = record.rarity or "Common",
				level = math.max(1, record.level or 1),
				evolutionLevel = evolutionLevel,
				stars = DragonEggConfig.GetEvolutionStars(evolutionLevel),
				state = runtimeDragon and (runtimeDragon.state or "idle") or "storage",
				isEquipped = record.isEquipped == true,
			})
		end
		return roster
	end,
	getAcademyMultipliers = function(player)
		local island = WorkspaceLayout.GetPlayerIsland(player)
		local academy = island and island:FindFirstChild("DragonAcademy")
		local trainingMultiplier = 1
		local xpMultiplier = 1
		local buildingLevel = 1
		if academy then
			trainingMultiplier = academy:GetAttribute("TrainingTimeMultiplier") or 1
			xpMultiplier = academy:GetAttribute("XpGainMultiplier") or 1
			buildingLevel = academy:GetAttribute("BuildingLevel") or 1
		end
		trainingMultiplier *= AscensionBonusService.GetTrainingSpeedMultiplier(player)
		return {
			TrainingTimeMultiplier = trainingMultiplier,
			XpGainMultiplier = xpMultiplier,
			BuildingLevel = buildingLevel,
		}
	end,
	getAcademyPosition = function(player)
		local island = WorkspaceLayout.GetPlayerIsland(player)
		local academy = island and island:FindFirstChild("DragonAcademy")
		if academy and academy:IsA("Model") then
			return academy:GetPivot().Position
		end
		return nil
	end,
	setDragonTraining = function(player, dragonId, isTraining, anchorPosition)
		local data = getPlayerData(player)
		local dragon = select(1, findRuntimeDragonByOwnedId(data, dragonId))
		if not dragon then
			dragon = select(1, findDragonById(data, dragonId))
		end
		if not dragon or not dragon.model or not dragon.model.Parent then
			return false
		end
		if isTraining then
			setDragonTraining(dragon, anchorPosition)
		else
			releaseDragonFromTraining(dragon)
			autoAssignIdleDragons(player, data)
		end
		sendUIUpdate(player)
		return true
	end,
	applyTrainingRewards = function(player, dragonId, levelReward, essenceReward)
		local data = getPlayerData(player)
		local ownedRecord = DragonInventoryService.GetOwnedRecord(data, dragonId)
		local dragon = select(1, findRuntimeDragonByOwnedId(data, dragonId))
		if not dragon then
			dragon = select(1, findDragonById(data, dragonId))
		end
		if not dragon and not ownedRecord then
			return false
		end
		local maxLevel = DragonTrainingConfig.MaxDragonLevel or 50
		local levelsToAdd = math.max(1, math.floor(tonumber(levelReward) or 1))
		local newLevel
		if dragon then
			dragon.level = math.min(maxLevel, math.max(1, (dragon.level or 1) + levelsToAdd))
			newLevel = dragon.level
			applyDragonLevelAttributes(dragon)
		end
		if ownedRecord then
			ownedRecord.level = math.min(maxLevel, math.max(1, (ownedRecord.level or 1) + levelsToAdd))
			newLevel = ownedRecord.level
		elseif dragon then
			ownedRecord = dragon.ownedId and DragonInventoryService.GetOwnedRecord(data, dragon.ownedId)
			if ownedRecord then
				ownedRecord.level = dragon.level
			end
		end
		data.essence += math.max(0, math.floor(tonumber(essenceReward) or 0))
		if newLevel then
			AchievementProgressSignal:Fire(player, "DragonLevelUp", 0, { level = newLevel })
		end
		saveDragonLevels(player)
		sendUIUpdate(player)
		return true
	end,
	isDragonBusy = function(player, dragonId)
		local data = getPlayerData(player)
		local dragon = select(1, findRuntimeDragonByOwnedId(data, dragonId))
		if not dragon then
			dragon = select(1, findDragonById(data, dragonId))
		end
		if not dragon then
			return true
		end
		return dragon.state == "training"
	end,
})

local function getMaxEvolutionLevelFromData(data)
	local maxEvolutionLevel = 0
	local mergeStats = sanitizeMergeStats(data.mergeStats)
	maxEvolutionLevel = math.max(maxEvolutionLevel, mergeStats.HighestEvolution or 0)
	for _, record in data.ownedDragonById do
		maxEvolutionLevel = math.max(maxEvolutionLevel, DragonEggConfig.SanitizeEvolutionLevel(record.evolutionLevel))
	end
	return maxEvolutionLevel
end

local function clearPendingHatchesForPlayer(player)
	for hatchId, pending in pairs(pendingHatches) do
		if pending.player == player then
			pendingHatches[hatchId] = nil
			if pending.eggRecord and pending.eggRecord.model and pending.eggRecord.model.Parent then
				pending.eggRecord.model:Destroy()
			end
		end
	end
end

local function isDragonBusyForRebirth(dragon)
	local state = string.lower(dragon.state or "idle")
	return state == "harvesting" or state == "moving" or state == "training"
end

local function resetHarvestRunState(player)
	local data = getPlayerData(player)
	clearPendingHatchesForPlayer(player)
	for _, egg in data.eggs do
		if egg.model and egg.model.Parent then
			egg.model:Destroy()
		end
	end
	data.eggs = {}
	for index = #data.dragons, 1, -1 do
		local dragon = data.dragons[index]
		if dragon.model and dragon.model.Parent then
			dragon.model:Destroy()
		end
		table.remove(data.dragons, index)
	end
	clearExistingPlayerNodes(player, data)
	data.essence = 0
	if data.island then
		spawnResourceNodes(player)
	end
	player:SetAttribute("DragonEssence", 0)
	local eggStats = sanitizeEggStats(data.eggStats)
	player:SetAttribute("LifetimeHatches", math.max(0, math.floor(tonumber(eggStats.TotalHatched) or 0)))
	player:SetAttribute("MaxEvolutionStars", getMaxEvolutionLevelFromData(data))
	saveDragonLevels(player)
	saveEggProgress(player)
	sendUIUpdate(player)
	sendDragonMergeUpdate(player, "Run progress reset after Rebirth")
	return true
end

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))

RebirthDomainBridge.Register("Dragon", {
	getSnapshotPatch = function(player)
		local data = getPlayerData(player)
		local eggStats = sanitizeEggStats(data.eggStats)
		local lifetimeHatches = math.max(0, math.floor(tonumber(eggStats.TotalHatched) or 0))
		local maxEvolutionLevel = getMaxEvolutionLevelFromData(data)
		player:SetAttribute("LifetimeHatches", lifetimeHatches)
		player:SetAttribute("MaxEvolutionStars", maxEvolutionLevel)
		return {
			lifetimeHatches = lifetimeHatches,
			maxEvolutionStars = maxEvolutionLevel,
			currentEssence = math.max(0, math.floor(tonumber(data.essence) or 0)),
		}
	end,
	canReset = function(player)
		for _, pending in pendingHatches do
			if pending.player == player then
				return { ok = false, reason = "An egg is hatching." }
			end
		end
		local data = getPlayerData(player)
		if #data.eggs > 0 then
			return { ok = false, reason = "Finish hatching your current egg first." }
		end
		for _, dragon in data.dragons do
			if isDragonBusyForRebirth(dragon) then
				return { ok = false, reason = "Wait for your dragons to finish working." }
			end
		end
		return { ok = true }
	end,
	resetRunState = function(player)
		return { success = resetHarvestRunState(player) }
	end,
	restorePermanentState = function(player)
		local data = getPlayerData(player)
		if data.island then
			spawnPlayerDragons(player, data.island)
			sendUIUpdate(player)
		end
		return { success = true }
	end,
})

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

local function getAdminSpawnPosition(player)
	local data = getPlayerData(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		return rootPart.Position + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
	end
	if data.island then
		return getIslandCenter(data.island) + Vector3.new(0, 2, 0)
	end
	return WorkspaceLayout.GetIslandSpawnCFrame().Position
end

local function spawnAdminResourceNodes(player, resourceId, amount)
	local template = resourcesTemplatesFolder:FindFirstChild(resourceId)
	if not template then
		return "Unknown resource: " .. tostring(resourceId)
	end
	local data = getPlayerData(player)
	local origin = getAdminSpawnPosition(player)
	local spawned = 0
	for index = 1, math.clamp(math.floor(tonumber(amount) or 1), 1, 12) do
		local node = template:Clone()
		node.Name = player.Name .. "_Admin_" .. resourceId .. "_" .. tostring(index)
		if resourceId == "CrystalResource" then
			prepareCrystalNode(node)
		end
		setupNode(node, player.UserId, HarvestConfig.NodeMaxHealth)
		local angle = (index - 1) * (math.pi * 2 / math.max(1, amount))
		local offset = Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
		if node:IsA("Model") then
			node:PivotTo(CFrame.new(origin + offset))
		elseif node:IsA("BasePart") then
			node.CFrame = CFrame.new(origin + offset)
		end
		node.Parent = nodesFolder
		table.insert(data.nodes, node)
		spawned += 1
	end
	autoAssignIdleDragons(player, data)
	sendUIUpdate(player)
	return "Spawned " .. spawned .. " " .. resourceId .. " node(s)"
end

AdminBridge.register("Harvest", {
	-- The DragonEssence attribute is a MIRROR of this script's private data.essence (see
	-- sendUIUpdate, which overwrites the attribute from data.essence on every harvest tick/UI
	-- refresh). Any code that sets the attribute directly - RewardService's DragonEssence handler,
	-- TradingService's currency swap - risks having that change silently wiped by the next tick.
	-- This is the one safe way for outside systems to adjust essence: it updates data.essence
	-- (the real source of truth) and the attribute together.
	adjustEssence = function(player, delta)
		local data = getPlayerData(player)
		data.essence = math.max(0, data.essence + (tonumber(delta) or 0))
		player:SetAttribute("DragonEssence", data.essence)
		sendUIUpdate(player)
		return data.essence
	end,
	giveEgg = function(player, eggType)
		local position = getEggSpawnPosition(player) or getAdminSpawnPosition(player)
		createEgg(player, position, eggType, { rewardGranted = true })
		return "Granted " .. tostring(eggType) .. " egg"
	end,
	giveDragon = function(player, payload)
		payload = typeof(payload) == "table" and payload or {}
		local data = getPlayerData(player)
		local record = DragonInventoryService.AddOwnedDragon(data, {
			dragonType = payload.dragonType or STARTER_DRAGON_TYPE,
			rarity = payload.rarity or "Common",
			level = math.max(1, math.floor(tonumber(payload.level) or 1)),
			evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(payload.evolutionLevel),
		})
		if DragonInventoryService.GetEquippedCount(data) < getPlayerDragonSlotLimit(player) then
			record.isEquipped = true
			spawnOwnedDragon(player, data, record, getAdminSpawnPosition(player))
		end
		saveDragonLevels(player)
		sendUIUpdate(player)
		return "Granted " .. (record.dragonType or "dragon")
	end,
	spawnTestDragon = function(player, payload)
		payload = typeof(payload) == "table" and payload or {}
		local position = getAdminSpawnPosition(player)
		local dragon = createDragon(player, position, {
			dragonType = payload.dragonType or "ForestDragon",
			rarity = payload.rarity or "Rare",
			level = 5,
			evolutionLevel = 1,
		})
		if not dragon then
			return "Could not spawn test dragon"
		end
		saveDragonLevels(player)
		sendUIUpdate(player)
		return "Spawned test " .. (dragon.dragonType or "dragon")
	end,
	spawnResourceNodes = function(player, resourceId, amount)
		return spawnAdminResourceNodes(player, resourceId, amount)
	end,
	respawnCrystalNodes = function(player, count)
		spawnResourceNodes(player)
		return "Crystal nodes refreshed"
	end,
	removeDragon = function(player, payload)
		payload = typeof(payload) == "table" and payload or {}
		local data = getPlayerData(player)
		local targetType = payload.dragonType
		local targetRarity = payload.rarity
		for index = #data.dragons, 1, -1 do
			local dragon = data.dragons[index]
			local typeMatch = not targetType
				or dragon.dragonType == targetType
				or DragonEggConfig.GetDragonModelName(targetType) == dragon.dragonType
			local rarityMatch = not targetRarity or dragon.rarity == targetRarity
			if typeMatch and rarityMatch then
				if dragon.model and dragon.model.Parent then
					dragon.model:Destroy()
				end
				table.remove(data.dragons, index)
				saveDragonLevels(player)
				sendUIUpdate(player)
				return "Removed " .. (dragon.dragonType or "dragon")
			end
		end
		return "No matching dragon found"
	end,
	removeAllDragons = function(player)
		local data = getPlayerData(player)
		local removed = #data.dragons
		for index = #data.dragons, 1, -1 do
			local dragon = data.dragons[index]
			if dragon.model and dragon.model.Parent then
				dragon.model:Destroy()
			end
			table.remove(data.dragons, index)
		end
		saveDragonLevels(player)
		sendUIUpdate(player)
		return "Removed " .. removed .. " dragon(s)"
	end,
	refreshUI = function(player)
		sendUIUpdate(player)
		sendDragonMergeUpdate(player)
		return "Harvest UI refreshed"
	end,
	save = function(player)
		saveDragonLevels(player)
		saveEggProgress(player)
		return "Harvest data saved"
	end,
	wipe = function(player)
		local data = getPlayerData(player)
		for _, dragon in data.dragons do
			if dragon.model and dragon.model.Parent then
				dragon.model:Destroy()
			end
		end
		for _, egg in data.eggs do
			if egg.model and egg.model.Parent then
				egg.model:Destroy()
			end
		end
		clearExistingPlayerNodes(player, data)
		data.dragons = {}
		data.eggs = {}
		data.nodes = {}
		data.savedDragons = {}
		data.nextSavedDragonIndex = 1
		data.eggStats = sanitizeEggStats(nil)
		data.mergeStats = sanitizeMergeStats(nil)
		DragonAbilityService.Clear(player)
		data.essence = 0
		sendUIUpdate(player)
		return "Harvest runtime wiped"
	end,
})

-- Cross-player dragon transfer support for TradingService.server.luau. Scoped to STORAGE dragons
-- only (isEquipped ~= true): those exist purely as records in ownedDragonById with no live Model,
-- so a transfer is just removing the record from one player's table and creating an equivalent one
-- (via AddOwnedDragon, which preserves exact stats) in the other's - no Workspace/Model handling,
-- no despawn logic needed. Equipped dragons are intentionally not tradeable in this first version.
AdminBridge.register("Trading", {
	listStorageDragons = function(player)
		local data = getPlayerData(player)
		local list = {}
		for _, record in data.ownedDragonById do
			if not record.isEquipped then
				table.insert(list, {
					id = record.id,
					dragonType = record.dragonType,
					displayName = DragonEggConfig.GetDragonDisplayName(record.dragonType),
					rarity = record.rarity,
					level = record.level,
					evolutionLevel = record.evolutionLevel,
				})
			end
		end
		table.sort(list, function(a, b)
			return a.id < b.id
		end)
		return list
	end,
	canReceiveDragonCount = function(player, count)
		local data = getPlayerData(player)
		local capacity = DragonInventoryService.GetStorageCapacity(player)
		local current = DragonInventoryService.GetOwnedCount(data)
		return current + (tonumber(count) or 1) <= capacity
	end,
	getStorageDragonSnapshot = function(player, dragonId)
		local data = getPlayerData(player)
		local record = DragonInventoryService.GetOwnedRecord(data, dragonId)
		if not record or record.isEquipped then
			return nil
		end
		return {
			dragonType = record.dragonType,
			displayName = DragonEggConfig.GetDragonDisplayName(record.dragonType),
			rarity = record.rarity,
			level = record.level,
			evolutionLevel = record.evolutionLevel,
		}
	end,
	removeStorageDragon = function(player, dragonId)
		local data = getPlayerData(player)
		local record = DragonInventoryService.GetOwnedRecord(data, dragonId)
		if not record or record.isEquipped then
			return false
		end
		data.ownedDragonById[record.id] = nil
		data.ownedDragonCount = math.max(0, (data.ownedDragonCount or 1) - 1)
		saveDragonLevels(player)
		sendUIUpdate(player)
		player:SetAttribute("DragonPower", math.floor(DragonInventoryService.ComputeTotalPower(player, data)))
		return true
	end,
	grantStorageDragon = function(player, snapshot)
		snapshot = typeof(snapshot) == "table" and snapshot or {}
		local data = getPlayerData(player)
		DragonInventoryService.AddOwnedDragon(data, {
			dragonType = snapshot.dragonType,
			rarity = snapshot.rarity,
			level = snapshot.level,
			evolutionLevel = snapshot.evolutionLevel,
		})
		saveDragonLevels(player)
		sendUIUpdate(player)
		player:SetAttribute("DragonPower", math.floor(DragonInventoryService.ComputeTotalPower(player, data)))
		return true
	end,
})
