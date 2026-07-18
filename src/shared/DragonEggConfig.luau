local DragonEggConfig = {}

DragonEggConfig.HatchTime = 6
DragonEggConfig.IconAssetId = "rbxassetid://113316632422703"

DragonEggConfig.Rarities = {
	{ Name = "Common", Weight = 60, ScaleBonus = 0, Color = Color3.fromRGB(190, 190, 190) },
	{ Name = "Rare", Weight = 25, ScaleBonus = 0.06, Color = Color3.fromRGB(70, 140, 255) },
	{ Name = "Epic", Weight = 10, ScaleBonus = 0.12, Color = Color3.fromRGB(170, 70, 255) },
	{ Name = "Legendary", Weight = 4, ScaleBonus = 0.18, Color = Color3.fromRGB(255, 190, 50) },
	{ Name = "Mythic", Weight = 0.9, ScaleBonus = 0.25, Color = Color3.fromRGB(255, 80, 200) },
	{ Name = "Ancient", Weight = 0.1, ScaleBonus = 0.35, Color = Color3.fromRGB(255, 60, 40) },
}

DragonEggConfig.EggTypes = {
	Common = {
		Id = "Common",
		DisplayName = "Common Egg",
		Cost = 50,
		Description = "A starter egg that can hatch young dragons in classic colors.",
		RarityColor = Color3.fromRGB(190, 190, 190),
		EggColor = Color3.fromRGB(245, 235, 210),
		SpotColor = Color3.fromRGB(180, 210, 255),
		GlowColor = Color3.fromRGB(255, 240, 180),
		Icon = DragonEggConfig.IconAssetId,
		Dragons = {
			{ Name = "BabyGreenDragon", DisplayName = "Baby Green Dragon", ModelName = "ForestDragon", Weight = 1 },
			{ Name = "BabyRedDragon", DisplayName = "Baby Red Dragon", ModelName = "FireDragon", Weight = 1 },
			{ Name = "BabyBlueDragon", DisplayName = "Baby Blue Dragon", ModelName = "IceDragon", Weight = 1 },
		},
	},
	Rare = {
		Id = "Rare",
		DisplayName = "Rare Egg",
		Cost = 0,
		Description = "A tutorial reward egg that always hatches a Rare dragon.",
		RarityColor = Color3.fromRGB(70, 140, 255),
		EggColor = Color3.fromRGB(90, 140, 255),
		SpotColor = Color3.fromRGB(210, 235, 255),
		GlowColor = Color3.fromRGB(95, 180, 255),
		Icon = DragonEggConfig.IconAssetId,
		GuaranteedRarity = "Rare",
		RewardOnly = true,
		Dragons = {
			{ Name = "BabyGreenDragon", DisplayName = "Baby Green Dragon", ModelName = "ForestDragon", Weight = 1 },
			{ Name = "BabyRedDragon", DisplayName = "Baby Red Dragon", ModelName = "FireDragon", Weight = 1 },
			{ Name = "BabyBlueDragon", DisplayName = "Baby Blue Dragon", ModelName = "IceDragon", Weight = 1 },
		},
	},
	Forest = {
		Id = "Forest",
		DisplayName = "Forest Egg",
		Cost = 300,
		Description = "A moss-covered egg that always hatches a Forest Dragon.",
		RarityColor = Color3.fromRGB(90, 210, 120),
		EggColor = Color3.fromRGB(92, 150, 86),
		SpotColor = Color3.fromRGB(177, 255, 151),
		GlowColor = Color3.fromRGB(90, 255, 130),
		Icon = "rbxassetid://122842695290895",
		Dragons = {
			{ Name = "ForestDragon", DisplayName = "Forest Dragon", ModelName = "ForestDragon", Weight = 1 },
		},
	},
	Ice = {
		Id = "Ice",
		DisplayName = "Ice Egg",
		Cost = 1000,
		Description = "A frozen egg that always hatches an Ice Dragon.",
		RarityColor = Color3.fromRGB(120, 220, 255),
		EggColor = Color3.fromRGB(175, 235, 255),
		SpotColor = Color3.fromRGB(235, 255, 255),
		GlowColor = Color3.fromRGB(110, 235, 255),
		Icon = "rbxassetid://104293709713395",
		Dragons = {
			{ Name = "IceDragon", DisplayName = "Ice Dragon", ModelName = "IceDragon", Weight = 1 },
		},
	},
	Fire = {
		Id = "Fire",
		DisplayName = "Fire Egg",
		ModelFolder = "Lava",
		Cost = 5000,
		Description = "A blazing egg that always hatches a Fire Dragon.",
		RarityColor = Color3.fromRGB(255, 110, 70),
		EggColor = Color3.fromRGB(170, 55, 38),
		SpotColor = Color3.fromRGB(255, 185, 75),
		GlowColor = Color3.fromRGB(255, 95, 35),
		Icon = "rbxassetid://73214946386499",
		Dragons = {
			{ Name = "FireDragon", DisplayName = "Fire Dragon", ModelName = "FireDragon", Weight = 1 },
		},
	},
	Crystal = {
		Id = "Crystal",
		DisplayName = "Crystal Egg",
		ModelFolder = "crysal",
		Cost = 15000,
		Description = "A radiant crystal egg that always hatches a Crystal Dragon.",
		RarityColor = Color3.fromRGB(190, 120, 255),
		EggColor = Color3.fromRGB(125, 78, 190),
		SpotColor = Color3.fromRGB(230, 190, 255),
		GlowColor = Color3.fromRGB(210, 120, 255),
		Icon = "rbxassetid://73150429062000",
		Dragons = {
			{ Name = "CrystalDragon", DisplayName = "Crystal Dragon", ModelName = "CrystalDragon", Weight = 1 },
		},
	},
	Ancient = {
		Id = "Ancient",
		DisplayName = "Ancient Egg",
		Cost = 50000,
		Description = "A mysterious ancient egg reserved for future dragons.",
		RarityColor = Color3.fromRGB(255, 205, 105),
		EggColor = Color3.fromRGB(78, 54, 42),
		SpotColor = Color3.fromRGB(255, 214, 105),
		GlowColor = Color3.fromRGB(255, 180, 55),
		Icon = "rbxassetid://78843852703854",
		Dragons = {},
		Reserved = true,
	},
}

DragonEggConfig.EggOrder = { "Common", "Forest", "Ice", "Fire", "Crystal", "Ancient" }
DragonEggConfig.RewardEggOrder = { "Common", "Rare", "Forest", "Ice", "Fire", "Crystal", "Ancient" }

DragonEggConfig.EggCost = DragonEggConfig.EggTypes.Common.Cost
DragonEggConfig.DragonTypes = {
	"ForestDragon",
	"FireDragon",
	"CrystalDragon",
	"IceDragon",
}

DragonEggConfig.Evolution = {
	MaxLevel = 5,
	MergeCosts = {
		[1] = 500,
		[2] = 1500,
		[3] = 5000,
		[4] = 15000,
		[5] = 50000,
	},
	StatBonusPerLevel = {
		HarvestSpeed = 0.2,
		FlightSpeed = 0.16,
		CarryCapacity = 0.18,
		CriticalHarvestChance = 0.018,
		Luck = 0.14,
		XpGain = 0.15,
	},
	VisualBonusPerLevel = {
		Scale = 0.08,
		GlowBrightness = 0.35,
		GlowRange = 1.5,
		ParticleRate = 4,
		TrailWidth = 0.12,
	},
}

local rarityTotalWeight = 0
for _, rarity in DragonEggConfig.Rarities do
	rarityTotalWeight += rarity.Weight
end

function DragonEggConfig.GetEggTypeInfo(eggType)
	return DragonEggConfig.EggTypes[eggType] or DragonEggConfig.EggTypes.Common
end

function DragonEggConfig.IsValidEggType(eggType)
	return typeof(eggType) == "string" and DragonEggConfig.EggTypes[eggType] ~= nil
end

function DragonEggConfig.GetEggOrder()
	return DragonEggConfig.EggOrder
end

function DragonEggConfig.GetRewardEggOrder()
	return DragonEggConfig.RewardEggOrder or DragonEggConfig.EggOrder
end

function DragonEggConfig.GetRarityInfo(rarityName)
	for _, rarity in DragonEggConfig.Rarities do
		if rarity.Name == rarityName then
			return rarity
		end
	end
	return DragonEggConfig.Rarities[1]
end

function DragonEggConfig.GetRarityDropChances()
	local chances = {}
	for _, rarity in DragonEggConfig.Rarities do
		table.insert(chances, {
			Name = rarity.Name,
			Chance = rarityTotalWeight > 0 and (rarity.Weight / rarityTotalWeight) * 100 or 0,
			Color = rarity.Color,
		})
	end
	return chances
end

function DragonEggConfig.GetDragonEntry(dragonType)
	for _, eggType in DragonEggConfig.EggOrder do
		local eggInfo = DragonEggConfig.EggTypes[eggType]
		for _, dragon in eggInfo.Dragons do
			if dragon.Name == dragonType then
				return dragon
			end
		end
	end
	return nil
end

function DragonEggConfig.GetDragonDisplayName(dragonType)
	local entry = DragonEggConfig.GetDragonEntry(dragonType)
	return entry and entry.DisplayName or dragonType
end

function DragonEggConfig.GetDragonModelName(dragonType)
	local entry = DragonEggConfig.GetDragonEntry(dragonType)
	return entry and (entry.ModelName or entry.Name) or dragonType
end

function DragonEggConfig.GetEvolutionMaxLevel()
	return math.max(0, math.floor(tonumber(DragonEggConfig.Evolution.MaxLevel) or 0))
end

function DragonEggConfig.SanitizeEvolutionLevel(evolutionLevel)
	local maxLevel = DragonEggConfig.GetEvolutionMaxLevel()
	return math.clamp(math.floor(tonumber(evolutionLevel) or 0), 0, maxLevel)
end

function DragonEggConfig.GetEvolutionStars(evolutionLevel)
	local safeLevel = DragonEggConfig.SanitizeEvolutionLevel(evolutionLevel)
	return string.rep("★", safeLevel)
end

function DragonEggConfig.GetEvolutionMergeCost(currentEvolutionLevel)
	local nextLevel = DragonEggConfig.SanitizeEvolutionLevel(currentEvolutionLevel) + 1
	if nextLevel > DragonEggConfig.GetEvolutionMaxLevel() then
		return nil
	end
	local costs = DragonEggConfig.Evolution.MergeCosts or {}
	local configuredCost = costs[nextLevel]
	if typeof(configuredCost) == "number" then
		return configuredCost
	end
	return math.floor(500 * (3 ^ math.max(0, nextLevel - 1)))
end

function DragonEggConfig.GetEvolutionStatMultipliers(evolutionLevel)
	local safeLevel = DragonEggConfig.SanitizeEvolutionLevel(evolutionLevel)
	local bonuses = DragonEggConfig.Evolution.StatBonusPerLevel or {}
	return {
		HarvestSpeed = 1 + safeLevel * (bonuses.HarvestSpeed or 0),
		FlightSpeed = 1 + safeLevel * (bonuses.FlightSpeed or 0),
		CarryCapacity = 1 + safeLevel * (bonuses.CarryCapacity or 0),
		CriticalHarvestChance = safeLevel * (bonuses.CriticalHarvestChance or 0),
		Luck = 1 + safeLevel * (bonuses.Luck or 0),
		XpGain = 1 + safeLevel * (bonuses.XpGain or 0),
	}
end

function DragonEggConfig.GetEvolutionVisualMultipliers(evolutionLevel)
	local safeLevel = DragonEggConfig.SanitizeEvolutionLevel(evolutionLevel)
	local bonuses = DragonEggConfig.Evolution.VisualBonusPerLevel or {}
	return {
		Scale = 1 + safeLevel * (bonuses.Scale or 0),
		GlowBrightness = 1 + safeLevel * (bonuses.GlowBrightness or 0),
		GlowRange = 1 + safeLevel * (bonuses.GlowRange or 0),
		ParticleRate = 1 + safeLevel * (bonuses.ParticleRate or 0),
		TrailWidth = 1 + safeLevel * (bonuses.TrailWidth or 0),
	}
end

function DragonEggConfig.RollRarity()
	local roll = math.random() * rarityTotalWeight
	local cumulative = 0
	for _, rarity in DragonEggConfig.Rarities do
		cumulative += rarity.Weight
		if roll <= cumulative then
			return rarity.Name
		end
	end
	return DragonEggConfig.Rarities[1].Name
end

function DragonEggConfig.RollDragonType(eggType)
	local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
	if not eggInfo.Dragons or #eggInfo.Dragons == 0 then
		return nil
	end

	local totalWeight = 0
	for _, dragon in eggInfo.Dragons do
		totalWeight += dragon.Weight or 1
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, dragon in eggInfo.Dragons do
		cumulative += dragon.Weight or 1
		if roll <= cumulative then
			return dragon.Name
		end
	end

	return eggInfo.Dragons[1].Name
end

return DragonEggConfig