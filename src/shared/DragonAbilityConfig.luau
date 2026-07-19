local DragonAbilityConfig = {}

DragonAbilityConfig.MaxLevel = 5

-- Progress granted per merge, keyed by pre-merge star tier (evolutionLevel).
DragonAbilityConfig.ProgressPerMerge = {
	[0] = 1,
	[1] = 2,
	[2] = 3,
	[3] = 4,
	[4] = 5,
}

-- Total progress needed to reach the next ability level.
DragonAbilityConfig.ProgressRequired = {
	[1] = 2,
	[2] = 4,
	[3] = 7,
	[4] = 11,
}

--[[
	Each species defines one passive ability. Gameplay reads HandlerId + Levels only.
	Adding a new dragon = one new entry here.
]]
DragonAbilityConfig.Species = {
	FireDragon = {
		AbilityName = "Inferno",
		Description = "Critical harvests grant bonus essence.",
		HandlerId = "Inferno",
		Levels = {
			{ CritBonusPercent = 0.08 },
			{ CritBonusPercent = 0.10 },
			{ CritBonusPercent = 0.12 },
			{ CritBonusPercent = 0.14 },
			{ CritBonusPercent = 0.16 },
		},
	},
	StormDragon = {
		AbilityName = "Chain Lightning",
		Description = "Every few hits, lightning echoes and pays bonus essence.",
		HandlerId = "ChainLightning",
		Levels = {
			{ HitsPerChain = 5, ChainEssencePercent = 0.30 },
			{ HitsPerChain = 5, ChainEssencePercent = 0.35 },
			{ HitsPerChain = 4, ChainEssencePercent = 0.38 },
			{ HitsPerChain = 4, ChainEssencePercent = 0.42 },
			{ HitsPerChain = 3, ChainEssencePercent = 0.33 },
		},
	},
	VoidDragon = {
		AbilityName = "Void Rift",
		Description = "Each harvest has a chance to tear open a rift for bonus essence.",
		HandlerId = "VoidRift",
		Levels = {
			{ ProcChance = 0.05, RiftPercent = 0.55 },
			{ ProcChance = 0.06, RiftPercent = 0.62 },
			{ ProcChance = 0.07, RiftPercent = 0.70 },
			{ ProcChance = 0.08, RiftPercent = 0.78 },
			{ ProcChance = 0.09, RiftPercent = 0.95 },
		},
	},
	CelestialDragon = {
		AbilityName = "Starfall Blessing",
		Description = "Each harvest has a chance to call down a star for a big essence bonus.",
		HandlerId = "Starfall",
		Levels = {
			{ ProcChance = 0.04, StarfallPercent = 0.70 },
			{ ProcChance = 0.05, StarfallPercent = 0.80 },
			{ ProcChance = 0.06, StarfallPercent = 0.90 },
			{ ProcChance = 0.07, StarfallPercent = 1.05 },
			{ ProcChance = 0.08, StarfallPercent = 1.25 },
		},
	},
	ForestDragon = {
		AbilityName = "Nature's Blessing",
		Description = "Each harvest has a chance to bloom bonus essence.",
		HandlerId = "NaturesBlessing",
		Levels = {
			{ ProcChance = 0.06, BloomPercent = 0.55 },
			{ ProcChance = 0.07, BloomPercent = 0.60 },
			{ ProcChance = 0.08, BloomPercent = 0.68 },
			{ ProcChance = 0.09, BloomPercent = 0.75 },
			{ ProcChance = 0.10, BloomPercent = 0.90 },
		},
	},
	CrystalDragon = {
		AbilityName = "Crystal Master",
		Description = "Shattering a crystal releases stored resonance as bonus essence.",
		HandlerId = "CrystalMaster",
		Levels = {
			{ ResonancePercent = 0.05 },
			{ ResonancePercent = 0.06 },
			{ ResonancePercent = 0.07 },
			{ ResonancePercent = 0.08 },
			{ ResonancePercent = 0.10 },
		},
	},
	IceDragon = {
		AbilityName = "Frozen Touch",
		Description = "Each hit on the same crystal builds Brittle for bonus essence.",
		HandlerId = "FrozenTouch",
		Levels = {
			{ MaxStacks = 3, EssencePerStack = 0.03 },
			{ MaxStacks = 3, EssencePerStack = 0.035 },
			{ MaxStacks = 4, EssencePerStack = 0.035 },
			{ MaxStacks = 4, EssencePerStack = 0.04 },
			{ MaxStacks = 5, EssencePerStack = 0.04 },
		},
	},
	PoisonDragon = {
		AbilityName = "Corrosion",
		Description = "Poisoned crystals grant bonus essence on every hit.",
		HandlerId = "Corrosion",
		Levels = {
			{ PoisonEssencePercent = 0.06 },
			{ PoisonEssencePercent = 0.07 },
			{ PoisonEssencePercent = 0.08 },
			{ PoisonEssencePercent = 0.09 },
			{ PoisonEssencePercent = 0.10 },
		},
	},
	LavaDragon = {
		AbilityName = "Molten Core",
		Description = "Heat builds with every harvest for bonus essence.",
		HandlerId = "MoltenCore",
		Levels = {
			{ MaxHeat = 3, HeatEssencePercent = 0.025 },
			{ MaxHeat = 3, HeatEssencePercent = 0.028 },
			{ MaxHeat = 4, HeatEssencePercent = 0.028 },
			{ MaxHeat = 4, HeatEssencePercent = 0.030 },
			{ MaxHeat = 5, HeatEssencePercent = 0.022 },
		},
	},
	CoralOceanDragon = {
		AbilityName = "Ocean Blessing",
		Description = "The tide rises each harvest and surges bonus essence at full tide.",
		HandlerId = "OceanBlessing",
		Levels = {
			{ TideRisePerHit = 20, SurgeEssencePercent = 0.35 },
			{ TideRisePerHit = 22, SurgeEssencePercent = 0.37 },
			{ TideRisePerHit = 24, SurgeEssencePercent = 0.38 },
			{ TideRisePerHit = 24, SurgeEssencePercent = 0.40 },
			{ TideRisePerHit = 25, SurgeEssencePercent = 0.40 },
		},
	},
}

local function clampLevel(level)
	return math.clamp(math.floor(tonumber(level) or 1), 1, DragonAbilityConfig.MaxLevel)
end

function DragonAbilityConfig.GetSpeciesConfig(speciesId)
	if typeof(speciesId) ~= "string" then
		return nil
	end
	return DragonAbilityConfig.Species[speciesId]
end

function DragonAbilityConfig.GetAllSpeciesIds()
	local ids = {}
	for speciesId in DragonAbilityConfig.Species do
		table.insert(ids, speciesId)
	end
	table.sort(ids)
	return ids
end

function DragonAbilityConfig.GetMaxLevel()
	return DragonAbilityConfig.MaxLevel
end

function DragonAbilityConfig.GetProgressPerMerge(evolutionLevel)
	local tier = math.max(0, math.floor(tonumber(evolutionLevel) or 0))
	return DragonAbilityConfig.ProgressPerMerge[tier] or 1
end

function DragonAbilityConfig.GetProgressRequired(abilityLevel)
	local level = math.floor(tonumber(abilityLevel) or 1)
	if level >= DragonAbilityConfig.MaxLevel then
		return nil
	end
	return DragonAbilityConfig.ProgressRequired[level] or 2
end

function DragonAbilityConfig.GetLevelParams(speciesId, abilityLevel)
	local config = DragonAbilityConfig.GetSpeciesConfig(speciesId)
	if not config or typeof(config.Levels) ~= "table" then
		return nil
	end
	local level = clampLevel(abilityLevel)
	return config.Levels[level] or config.Levels[1]
end

function DragonAbilityConfig.CreateDefaultEntry()
	return {
		AbilityLevel = 1,
		AbilityProgress = 0,
	}
end

function DragonAbilityConfig.SanitizeEntry(rawEntry)
	local entry = DragonAbilityConfig.CreateDefaultEntry()
	if typeof(rawEntry) ~= "table" then
		return entry
	end
	entry.AbilityLevel = math.clamp(math.floor(tonumber(rawEntry.AbilityLevel) or 1), 1, DragonAbilityConfig.MaxLevel)
	local required = DragonAbilityConfig.GetProgressRequired(entry.AbilityLevel)
	if required then
		entry.AbilityProgress = math.clamp(math.floor(tonumber(rawEntry.AbilityProgress) or 0), 0, required - 1)
	else
		entry.AbilityProgress = 0
	end
	return entry
end

local function formatPercent(value)
	return string.format("%.0f%%", (tonumber(value) or 0) * 100)
end

function DragonAbilityConfig.FormatAbilityValue(speciesId, abilityLevel)
	local config = DragonAbilityConfig.GetSpeciesConfig(speciesId)
	local params = DragonAbilityConfig.GetLevelParams(speciesId, abilityLevel)
	if not config or not params then
		return "—"
	end

	local handlerId = config.HandlerId
	if handlerId == "Inferno" then
		return "+" .. formatPercent(params.CritBonusPercent) .. " crit essence"
	elseif handlerId == "ChainLightning" then
		return "Every " .. tostring(params.HitsPerChain) .. " hits: +" .. formatPercent(params.ChainEssencePercent) .. " essence"
	elseif handlerId == "NaturesBlessing" then
		return formatPercent(params.ProcChance) .. " bloom for +" .. formatPercent(params.BloomPercent) .. " essence"
	elseif handlerId == "CrystalMaster" then
		return "+" .. formatPercent(params.ResonancePercent) .. " resonance on shatter"
	elseif handlerId == "FrozenTouch" then
		return "+" .. formatPercent(params.EssencePerStack) .. " essence per brittle stack"
	elseif handlerId == "Corrosion" then
		return "+" .. formatPercent(params.PoisonEssencePercent) .. " essence on poisoned hits"
	elseif handlerId == "MoltenCore" then
		return "Up to +" .. formatPercent((params.MaxHeat or 1) * (params.HeatEssencePercent or 0)) .. " heat essence"
	elseif handlerId == "OceanBlessing" then
		return "Full tide surge: +" .. formatPercent(params.SurgeEssencePercent) .. " essence"
	elseif handlerId == "VoidRift" then
		return formatPercent(params.ProcChance) .. " chance for +" .. formatPercent(params.RiftPercent) .. " essence"
	elseif handlerId == "Starfall" then
		return formatPercent(params.ProcChance) .. " chance for +" .. formatPercent(params.StarfallPercent) .. " essence"
	end
	return config.AbilityName
end

return DragonAbilityConfig
