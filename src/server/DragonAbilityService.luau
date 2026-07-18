local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonAbilityConfig = require(ReplicatedStorage:WaitForChild("DragonAbilityConfig"))
local DragonAbilityEffects = require(script.Parent:WaitForChild("DragonAbilityEffects"))

local Events = ReplicatedStorage:WaitForChild("HarvestEvents")
local DragonAbilityLevelUp = Events:WaitForChild("DragonAbilityLevelUp")

local DragonAbilityService = {}

local playerAbilities = {}

local function getSpeciesId(dragonType)
	if typeof(dragonType) ~= "string" or dragonType == "" then
		return nil
	end
	if DragonAbilityConfig.GetSpeciesConfig(dragonType) then
		return dragonType
	end
	return nil
end

local function ensurePlayerStore(player)
	if not playerAbilities[player] then
		playerAbilities[player] = {}
	end
	return playerAbilities[player]
end

local function getAbilityEntry(player, speciesId)
	local store = ensurePlayerStore(player)
	if not store[speciesId] then
		store[speciesId] = DragonAbilityConfig.CreateDefaultEntry()
	end
	return store[speciesId]
end

function DragonAbilityService.Load(player, rawAbilities)
	local store = {}
	if typeof(rawAbilities) == "table" then
		for speciesId, entry in rawAbilities do
			if typeof(speciesId) == "string" and DragonAbilityConfig.GetSpeciesConfig(speciesId) then
				store[speciesId] = DragonAbilityConfig.SanitizeEntry(entry)
			end
		end
	end
	playerAbilities[player] = store
end

function DragonAbilityService.Serialize(player)
	local store = playerAbilities[player]
	if not store then
		return {}
	end
	local serialized = {}
	for speciesId, entry in store do
		serialized[speciesId] = {
			AbilityLevel = entry.AbilityLevel,
			AbilityProgress = entry.AbilityProgress,
		}
	end
	return serialized
end

function DragonAbilityService.Clear(player)
	playerAbilities[player] = {}
end

function DragonAbilityService.Release(player)
	playerAbilities[player] = nil
end

function DragonAbilityService.GetAbilityPayload(player, speciesId)
	speciesId = getSpeciesId(speciesId)
	if not speciesId then
		return nil
	end

	local config = DragonAbilityConfig.GetSpeciesConfig(speciesId)
	local entry = getAbilityEntry(player, speciesId)
	local progressRequired = DragonAbilityConfig.GetProgressRequired(entry.AbilityLevel)
	local isMaxLevel = progressRequired == nil

	return {
		speciesId = speciesId,
		abilityName = config.AbilityName,
		description = config.Description,
		abilityLevel = entry.AbilityLevel,
		abilityProgress = isMaxLevel and 0 or entry.AbilityProgress,
		progressRequired = progressRequired,
		isMaxLevel = isMaxLevel,
		currentValueText = DragonAbilityConfig.FormatAbilityValue(speciesId, entry.AbilityLevel),
		nextValueText = isMaxLevel and nil or DragonAbilityConfig.FormatAbilityValue(speciesId, entry.AbilityLevel + 1),
	}
end

function DragonAbilityService.GetAllPayloads(player)
	local payloads = {}
	for _, speciesId in DragonAbilityConfig.GetAllSpeciesIds() do
		payloads[speciesId] = DragonAbilityService.GetAbilityPayload(player, speciesId)
	end
	return payloads
end

local function tryLevelUp(player, speciesId, entry)
	local leveled = false
	while true do
		local required = DragonAbilityConfig.GetProgressRequired(entry.AbilityLevel)
		if not required or entry.AbilityProgress < required then
			break
		end
		entry.AbilityProgress -= required
		entry.AbilityLevel = math.min(DragonAbilityConfig.GetMaxLevel(), entry.AbilityLevel + 1)
		leveled = true

		local config = DragonAbilityConfig.GetSpeciesConfig(speciesId)
		DragonAbilityLevelUp:FireClient(player, {
			speciesId = speciesId,
			abilityName = config and config.AbilityName or speciesId,
			abilityLevel = entry.AbilityLevel,
			currentValueText = DragonAbilityConfig.FormatAbilityValue(speciesId, entry.AbilityLevel),
		})

		if entry.AbilityLevel >= DragonAbilityConfig.GetMaxLevel() then
			entry.AbilityProgress = 0
			break
		end
	end
	return leveled
end

function DragonAbilityService.GrantMergeProgress(player, dragonType, evolutionLevel)
	local speciesId = getSpeciesId(dragonType)
	if not speciesId then
		return false
	end

	local entry = getAbilityEntry(player, speciesId)
	if entry.AbilityLevel >= DragonAbilityConfig.GetMaxLevel() then
		return false
	end

	local gain = DragonAbilityConfig.GetProgressPerMerge(evolutionLevel)
	entry.AbilityProgress += gain
	tryLevelUp(player, speciesId, entry)
	return true
end

function DragonAbilityService.ProcessHarvestHit(player, dragon, node, hitData)
	local speciesId = getSpeciesId(dragon.dragonType)
	if not speciesId then
		return {
			totalEssence = hitData.harvestAmount,
			totalNodeDamage = hitData.harvestAmount,
			vfxTags = {},
		}
	end

	local config = DragonAbilityConfig.GetSpeciesConfig(speciesId)
	local entry = getAbilityEntry(player, speciesId)
	local params = DragonAbilityConfig.GetLevelParams(speciesId, entry.AbilityLevel)
	if not config or not params then
		return {
			totalEssence = hitData.harvestAmount,
			totalNodeDamage = hitData.harvestAmount,
			vfxTags = {},
		}
	end

	local result = DragonAbilityEffects.ApplyHandler(
		config.HandlerId,
		player,
		dragon,
		node,
		hitData,
		params
	)

	local totalEssence = hitData.harvestAmount + math.max(0, result.bonusEssence or 0)
	if result.trackResonance or config.HandlerId == "CrystalMaster" then
		DragonAbilityEffects.RecordNodeEssence(node, dragon.id, totalEssence)
	end

	local vfxTags = {}
	if result.vfxTag then
		table.insert(vfxTags, result.vfxTag)
	end

	return {
		totalEssence = totalEssence,
		totalNodeDamage = hitData.harvestAmount,
		vfxTags = vfxTags,
	}
end

function DragonAbilityService.OnNodeDepleted(player, dragon, node)
	local speciesId = dragon and getSpeciesId(dragon.dragonType)
	local depletionResult = {}

	if speciesId and node then
		local config = DragonAbilityConfig.GetSpeciesConfig(speciesId)
		local entry = getAbilityEntry(player, speciesId)
		local params = DragonAbilityConfig.GetLevelParams(speciesId, entry.AbilityLevel)
		if config and params then
			depletionResult = DragonAbilityEffects.ResolveNodeDepletion(player, dragon, node, params, config.HandlerId)
		end
	end

	DragonAbilityEffects.ClearNodeState(node)

	return {
		bonusEssence = math.max(0, depletionResult.bonusEssence or 0),
		vfxTag = depletionResult.vfxTag,
	}
end

return DragonAbilityService
