local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local DragonInventoryConfig = require(ReplicatedStorage:WaitForChild("DragonInventoryConfig"))
local DragonPowerScore = require(ReplicatedStorage:WaitForChild("DragonPowerScore"))

local DragonInventoryService = {}

local deps = nil

function DragonInventoryService.Init(dependencies)
	deps = dependencies
end

local function requireDeps()
	assert(deps, "[DragonInventoryService] Init must be called first")
	return deps
end

local function sanitizeOwnedRecord(rawRecord, fallbackId)
	if typeof(rawRecord) ~= "table" then
		return nil
	end
	local dragonType = rawRecord.type or rawRecord.dragonType
	if typeof(dragonType) ~= "string" or dragonType == "" then
		return nil
	end
	return {
		id = math.max(1, math.floor(tonumber(rawRecord.id) or fallbackId or 1)),
		type = dragonType,
		dragonType = dragonType,
		rarity = rawRecord.rarity or "Common",
		level = math.max(1, math.floor(tonumber(rawRecord.level) or 1)),
		evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(rawRecord.evolutionLevel or rawRecord.evolution),
		isEquipped = rawRecord.isEquipped == true,
		isFavorite = rawRecord.isFavorite == true,
		isLocked = rawRecord.isLocked == true,
		acquiredAt = math.max(0, math.floor(tonumber(rawRecord.acquiredAt) or os.time())),
	}
end

function DragonInventoryService.EnsureStore(data)
	if typeof(data.ownedDragonById) ~= "table" then
		data.ownedDragonById = {}
	end
	if typeof(data.ownedDragonCount) ~= "number" then
		data.ownedDragonCount = 0
	end
	if typeof(data.nextOwnedDragonId) ~= "number" then
		data.nextOwnedDragonId = 1
	end
	return data
end

function DragonInventoryService.RebuildCount(data)
	data = DragonInventoryService.EnsureStore(data)
	local count = 0
	for _ in data.ownedDragonById do
		count += 1
	end
	data.ownedDragonCount = count
	return count
end

function DragonInventoryService.MigrateFromLegacy(data)
	data = DragonInventoryService.EnsureStore(data)
	if data.inventoryMigrated == true then
		return
	end

	local legacyDragons = data.savedDragons
	if typeof(legacyDragons) ~= "table" or #legacyDragons == 0 then
		data.inventoryMigrated = true
		return
	end

	if DragonInventoryService.RebuildCount(data) > 0 then
		data.inventoryMigrated = true
		return
	end

	local now = os.time()
	for index, saved in legacyDragons do
		local record = sanitizeOwnedRecord({
			type = saved.type,
			dragonType = saved.type,
			rarity = saved.rarity,
			level = saved.level,
			evolutionLevel = saved.evolutionLevel or saved.evolution,
			isEquipped = index <= (deps and deps.getPlayerDragonSlotLimit and 4 or 4),
			acquiredAt = now + index,
		}, data.nextOwnedDragonId)
		if record then
			data.ownedDragonById[record.id] = record
			data.nextOwnedDragonId = math.max(data.nextOwnedDragonId, record.id + 1)
		end
	end

	data.inventoryMigrated = true
	DragonInventoryService.RebuildCount(data)
end

function DragonInventoryService.LoadOwnedDragons(data, rawOwnedDragons, rawNextDragonId)
	data = DragonInventoryService.EnsureStore(data)
	data.ownedDragonById = {}
	data.nextOwnedDragonId = math.max(1, math.floor(tonumber(rawNextDragonId) or 1))

	if typeof(rawOwnedDragons) == "table" then
		for _, rawRecord in rawOwnedDragons do
			local record = sanitizeOwnedRecord(rawRecord)
			if record then
				data.ownedDragonById[record.id] = record
				data.nextOwnedDragonId = math.max(data.nextOwnedDragonId, record.id + 1)
			end
		end
	end

	DragonInventoryService.MigrateFromLegacy(data)
	DragonInventoryService.RebuildCount(data)
end

function DragonInventoryService.SerializeOwnedDragons(data)
	data = DragonInventoryService.EnsureStore(data)
	local serialized = {}
	for _, record in data.ownedDragonById do
		table.insert(serialized, {
			id = record.id,
			type = record.type,
			rarity = record.rarity,
			level = record.level,
			evolutionLevel = record.evolutionLevel,
			isEquipped = record.isEquipped == true,
			isFavorite = record.isFavorite == true,
			isLocked = record.isLocked == true,
			acquiredAt = record.acquiredAt,
		})
	end
	table.sort(serialized, function(a, b)
		return (a.id or 0) < (b.id or 0)
	end)
	return serialized, data.nextOwnedDragonId
end

function DragonInventoryService.GetOwnedRecord(data, dragonId)
	data = DragonInventoryService.EnsureStore(data)
	local numericId = tonumber(dragonId)
	if not numericId then
		return nil
	end
	return data.ownedDragonById[numericId]
end

function DragonInventoryService.GetDragonStorageModel(player)
	local island = WorkspaceLayout.GetPlayerIsland(player)
	if not island then
		return nil
	end
	local storage = island:FindFirstChild("DragonStorage")
	if storage and storage:IsA("Model") then
		return storage
	end
	return nil
end

function DragonInventoryService.GetStorageCapacity(player)
	local storage = DragonInventoryService.GetDragonStorageModel(player)
	if storage then
		local capacity = storage:GetAttribute("DragonStorageCapacity")
		if typeof(capacity) == "number" and capacity > 0 then
			return math.floor(capacity)
		end
		local level = storage:GetAttribute("BuildingLevel")
		if typeof(level) == "number" and level > 0 then
			return DragonInventoryConfig.GetStorageCapacity(level)
		end
	end
	return DragonInventoryConfig.DefaultStorageCapacity
end

function DragonInventoryService.GetOwnedCount(data)
	return DragonInventoryService.RebuildCount(data)
end

function DragonInventoryService.GetEquippedCount(data)
	local count = 0
	for _, record in data.ownedDragonById do
		if record.isEquipped then
			count += 1
		end
	end
	return count
end

function DragonInventoryService.GetStorageUsed(data)
	local equipped = DragonInventoryService.GetEquippedCount(data)
	return math.max(0, DragonInventoryService.GetOwnedCount(data) - equipped)
end

function DragonInventoryService.CanAddToStorage(player, data)
	data = DragonInventoryService.EnsureStore(data)
	return DragonInventoryService.GetOwnedCount(data) < DragonInventoryService.GetStorageCapacity(player)
end

function DragonInventoryService.AllocateId(data)
	data = DragonInventoryService.EnsureStore(data)
	local id = data.nextOwnedDragonId
	data.nextOwnedDragonId += 1
	return id
end

function DragonInventoryService.AddOwnedDragon(data, options)
	local d = requireDeps()
	data = DragonInventoryService.EnsureStore(data)
	local id = DragonInventoryService.AllocateId(data)
	local record = {
		id = id,
		type = options.dragonType or d.STARTER_DRAGON_TYPE,
		dragonType = options.dragonType or d.STARTER_DRAGON_TYPE,
		rarity = options.rarity or "Common",
		level = math.max(1, math.floor(tonumber(options.level) or 1)),
		evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(options.evolutionLevel),
		isEquipped = false,
		isFavorite = false,
		isLocked = false,
		acquiredAt = os.time(),
	}
	data.ownedDragonById[id] = record
	data.ownedDragonCount += 1
	return record
end

function DragonInventoryService.ComputePowerScore(player, record)
	local d = requireDeps()
	local dragonType = record.dragonType or record.type
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(record.evolutionLevel)
	local stats = d.getDragonStats(record.level, record.rarity, evolutionLevel, dragonType)
	local abilityPayload = d.DragonAbilityService.GetAbilityPayload(player, dragonType)
	return DragonPowerScore.Compute({
		level = record.level,
		evolutionLevel = evolutionLevel,
		rarity = record.rarity,
		abilityLevel = abilityPayload and abilityPayload.abilityLevel or 1,
		stats = stats,
	})
end

function DragonInventoryService.GetRuntimeDragon(data, ownedId)
	local d = requireDeps()
	for _, dragon in data.dragons do
		if dragon.ownedId == ownedId then
			return dragon
		end
	end
	return nil
end

function DragonInventoryService.SyncEquippedFlag(data, ownedId, isEquipped)
	local record = DragonInventoryService.GetOwnedRecord(data, ownedId)
	if record then
		record.isEquipped = isEquipped == true
	end
end

function DragonInventoryService.IsDragonBusy(runtimeDragon)
	if not runtimeDragon then
		return false
	end
	local state = string.lower(runtimeDragon.state or "idle")
	return state == "training" or state == "harvesting" or state == "moving"
end

function DragonInventoryService.EquipDragon(player, data, ownedId)
	local d = requireDeps()
	data = DragonInventoryService.EnsureStore(data)
	local record = DragonInventoryService.GetOwnedRecord(data, ownedId)
	if not record then
		return false, "Dragon not found"
	end
	if record.isEquipped then
		return false, "Dragon is already active"
	end
	if DragonInventoryService.GetEquippedCount(data) >= d.getPlayerDragonSlotLimit(player) then
		return false, "Active dragon slots are full"
	end

	record.isEquipped = true
	local position = d.getEquipSpawnPosition(player)
	local runtimeDragon = d.spawnOwnedDragon(player, data, record, position)
	if not runtimeDragon then
		record.isEquipped = false
		return false, "Could not spawn dragon"
	end

	d.autoAssignIdleDragons(player, data)
	return true, "Equipped " .. DragonEggConfig.GetDragonDisplayName(record.dragonType)
end

function DragonInventoryService.UnequipDragon(player, data, ownedId)
	local d = requireDeps()
	data = DragonInventoryService.EnsureStore(data)
	local record = DragonInventoryService.GetOwnedRecord(data, ownedId)
	if not record or not record.isEquipped then
		return false, "Dragon is not active"
	end

	local runtimeDragon = DragonInventoryService.GetRuntimeDragon(data, ownedId)
	if runtimeDragon and DragonInventoryService.IsDragonBusy(runtimeDragon) then
		return false, "Dragon is busy right now"
	end

	if runtimeDragon then
		d.despawnRuntimeDragon(data, runtimeDragon)
	end
	record.isEquipped = false
	return true, "Moved dragon to storage"
end

function DragonInventoryService.EquipBestDragons(player, data)
	local d = requireDeps()
	data = DragonInventoryService.EnsureStore(data)
	local slotLimit = d.getPlayerDragonSlotLimit(player)
	local candidates = {}

	for _, record in data.ownedDragonById do
		if not record.isFavorite then
			table.insert(candidates, {
				record = record,
				powerScore = DragonInventoryService.ComputePowerScore(player, record),
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.powerScore == b.powerScore then
			return (a.record.id or 0) > (b.record.id or 0)
		end
		return a.powerScore > b.powerScore
	end)

	local targetIds = {}
	for index = 1, math.min(slotLimit, #candidates) do
		targetIds[candidates[index].record.id] = true
	end

	-- Two separate passes, not one combined loop: pairs() over ownedDragonById (a plain dictionary)
	-- gives no ordering guarantee, so a single pass could visit an "equip this new best dragon" case
	-- before the "unequip this old weak one" case that's supposed to free its slot. EquipDragon
	-- rejects when slots are already full, so that ordering accident would silently skip the swap -
	-- this is why "Equip Best" only sometimes worked. Unequipping everything that needs to go first
	-- guarantees every slot picked for a new dragon is actually free by the time we try to equip it.
	local changed = 0
	for _, record in data.ownedDragonById do
		if record.isEquipped and not targetIds[record.id] and not record.isFavorite then
			local ok = DragonInventoryService.UnequipDragon(player, data, record.id)
			if ok then
				changed += 1
			end
		end
	end
	for _, record in data.ownedDragonById do
		if not record.isEquipped and targetIds[record.id] == true then
			local ok = DragonInventoryService.EquipDragon(player, data, record.id)
			if ok then
				changed += 1
			end
		end
	end

	if changed == 0 then
		return false, "Your strongest dragons are already active"
	end
	return true, "Equipped your strongest dragons"
end

function DragonInventoryService.SetFavorite(data, ownedId, isFavorite)
	data = DragonInventoryService.EnsureStore(data)
	local record = DragonInventoryService.GetOwnedRecord(data, ownedId)
	if not record then
		return false, "Dragon not found"
	end
	record.isFavorite = isFavorite == true
	return true, record.isFavorite and "Added to favorites" or "Removed from favorites"
end

function DragonInventoryService.SetLocked(data, ownedId, isLocked)
	data = DragonInventoryService.EnsureStore(data)
	local record = DragonInventoryService.GetOwnedRecord(data, ownedId)
	if not record then
		return false, "Dragon not found"
	end
	record.isLocked = isLocked == true
	return true, record.isLocked and "Dragon locked" or "Dragon unlocked"
end

function DragonInventoryService.BuildInventoryEntry(player, data, record, groupCounts)
	local d = requireDeps()
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(record.evolutionLevel)
	local stats = d.getDragonStats(record.level, record.rarity, evolutionLevel, record.dragonType)
	local nextStats = evolutionLevel < DragonEggConfig.GetEvolutionMaxLevel()
		and d.getDragonStats(record.level, record.rarity, evolutionLevel + 1, record.dragonType)
		or stats
	local mergeKey = table.concat({ record.dragonType, record.rarity or "Common", tostring(evolutionLevel) }, "|")
	local matchingCount = groupCounts and groupCounts[mergeKey] or 0
	local runtimeDragon = record.isEquipped and DragonInventoryService.GetRuntimeDragon(data, record.id) or nil
	local dragonState = runtimeDragon and (runtimeDragon.state or "idle") or "storage"
	local targetNodeName = runtimeDragon and runtimeDragon.targetNode and runtimeDragon.targetNode.Name or ""
	local ability = d.DragonAbilityService.GetAbilityPayload(player, record.dragonType)
	local powerScore = DragonInventoryService.ComputePowerScore(player, record)

	return {
		id = record.id,
		dragonType = record.dragonType,
		displayName = DragonEggConfig.GetDragonDisplayName(record.dragonType),
		rarity = record.rarity or "Common",
		level = math.max(1, record.level or 1),
		evolutionLevel = evolutionLevel,
		stars = DragonEggConfig.GetEvolutionStars(evolutionLevel),
		state = dragonState,
		isEquipped = record.isEquipped == true,
		isFavorite = record.isFavorite == true,
		isLocked = record.isLocked == true,
		isInStorage = record.isEquipped ~= true,
		acquiredAt = record.acquiredAt,
		powerScore = powerScore,
		assigned = dragonState == "harvesting" or dragonState == "moving" or targetNodeName ~= "",
		targetNodeName = targetNodeName,
		upgradeCost = d.getDragonUpgradeCost(record.level),
		mergeCost = DragonEggConfig.GetEvolutionMergeCost(evolutionLevel) or 0,
		matchingCount = matchingCount,
		mergeAvailable = record.isEquipped and matchingCount >= 3 and evolutionLevel < DragonEggConfig.GetEvolutionMaxLevel() and not record.isLocked,
		stats = stats,
		nextStats = nextStats,
		ability = ability,
	}
end

-- Sum of every owned dragon's power score (equipped + storage), mirrored onto the "DragonPower"
-- attribute below for the leaderboard (see LeaderboardConfig) to read. Recomputed here rather than
-- incrementally, since BuildInventoryPayload already walks every owned dragon for the roster UI and
-- is called after every roster-affecting action (hatch/merge/equip/unequip/upgrade/sell/load).
function DragonInventoryService.ComputeTotalPower(player, data)
	data = DragonInventoryService.EnsureStore(data)
	local total = 0
	for _, record in data.ownedDragonById do
		total += DragonInventoryService.ComputePowerScore(player, record)
	end
	return total
end

function DragonInventoryService.BuildInventoryPayload(player, data, message)
	local d = requireDeps()
	data = DragonInventoryService.EnsureStore(data)

	local groupCounts = {}
	for _, record in data.ownedDragonById do
		if record.isEquipped then
			local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(record.evolutionLevel)
			local mergeKey = table.concat({ record.dragonType, record.rarity or "Common", tostring(evolutionLevel) }, "|")
			groupCounts[mergeKey] = (groupCounts[mergeKey] or 0) + 1
		end
	end

	local inventory = {}
	local totalPower = 0
	for _, record in data.ownedDragonById do
		local entry = DragonInventoryService.BuildInventoryEntry(player, data, record, groupCounts)
		totalPower += entry.powerScore
		table.insert(inventory, entry)
	end
	player:SetAttribute("DragonPower", math.floor(totalPower))

	return {
		essence = data.essence,
		dragons = inventory,
		totalPower = totalPower,
		mergeStats = d.sanitizeMergeStats(data.mergeStats),
		maxEvolutionLevel = DragonEggConfig.GetEvolutionMaxLevel(),
		activeCount = DragonInventoryService.GetEquippedCount(data),
		activeMax = d.getPlayerDragonSlotLimit(player),
		storageCount = DragonInventoryService.GetOwnedCount(data),
		storageMax = DragonInventoryService.GetStorageCapacity(player),
		storageUsed = DragonInventoryService.GetStorageUsed(data),
		message = message,
	}
end

return DragonInventoryService
