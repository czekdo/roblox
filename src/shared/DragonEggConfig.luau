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
			{ Name = "ForestDragon", DisplayName = "Forest Dragon", ModelName = "ForestDragon", Weight = 1 },
			{ Name = "FireDragon", DisplayName = "Fire Dragon", ModelName = "FireDragon", Weight = 1 },
			{ Name = "IceDragon", DisplayName = "Ice Dragon", ModelName = "IceDragon", Weight = 1 },
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
			{ Name = "ForestDragon", DisplayName = "Forest Dragon", ModelName = "ForestDragon", Weight = 1 },
			{ Name = "FireDragon", DisplayName = "Fire Dragon", ModelName = "FireDragon", Weight = 1 },
			{ Name = "IceDragon", DisplayName = "Ice Dragon", ModelName = "IceDragon", Weight = 1 },
		},
	},
	Forest = {
		Id = "Forest",
		DisplayName = "Forest Egg",
		Cost = 300,
		RequiresIsland = "Forest",
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
		RequiresIsland = "Cold",
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
		Description = "A blazing egg that always hatches a Fire Dragon. Not tied to any island - available as soon as you can afford it.",
		RarityColor = Color3.fromRGB(255, 110, 70),
		EggColor = Color3.fromRGB(170, 55, 38),
		SpotColor = Color3.fromRGB(255, 185, 75),
		GlowColor = Color3.fromRGB(255, 95, 35),
		Icon = "rbxassetid://73214946386499",
		Dragons = {
			{ Name = "FireDragon", DisplayName = "Fire Dragon", ModelName = "FireDragon", Weight = 1 },
		},
	},
	Lava = {
		Id = "Lava",
		DisplayName = "Lava Egg",
		Cost = 5000,
		RequiresIsland = "Lava",
		Description = "A molten egg that always hatches a Lava Dragon.",
		RarityColor = Color3.fromRGB(255, 90, 40),
		EggColor = Color3.fromRGB(120, 35, 20),
		SpotColor = Color3.fromRGB(255, 140, 40),
		GlowColor = Color3.fromRGB(255, 70, 20),
		Icon = "rbxassetid://73214946386499",
		Dragons = {
			{ Name = "LavaDragon", DisplayName = "Lava Dragon", ModelName = "LavaDragon", Weight = 1 },
		},
	},
	Storm = {
		Id = "Storm",
		DisplayName = "Storm Egg",
		Cost = 15000,
		RequiresIsland = "Storm",
		Description = "A crackling egg that always hatches a Storm Dragon.",
		RarityColor = Color3.fromRGB(170, 130, 255),
		EggColor = Color3.fromRGB(90, 70, 150),
		SpotColor = Color3.fromRGB(200, 180, 255),
		GlowColor = Color3.fromRGB(150, 120, 255),
		Icon = "rbxassetid://72607541698873",
		Dragons = {
			{ Name = "StormDragon", DisplayName = "Storm Dragon", ModelName = "StormDragon", Weight = 1 },
		},
	},
	Shadow = {
		Id = "Shadow",
		DisplayName = "Shadow Egg",
		Cost = 45000,
		RequiresIsland = "Shadow",
		Description = "A murky egg that always hatches a Void Dragon.",
		RarityColor = Color3.fromRGB(120, 95, 170),
		EggColor = Color3.fromRGB(50, 40, 65),
		SpotColor = Color3.fromRGB(150, 120, 200),
		GlowColor = Color3.fromRGB(130, 90, 200),
		Icon = "rbxassetid://126528254643859",
		Dragons = {
			{ Name = "VoidDragon", DisplayName = "Void Dragon", ModelName = "VoidDragon", Weight = 1 },
		},
	},
	Crystal = {
		Id = "Crystal",
		DisplayName = "Crystal Egg",
		ModelFolder = "crysal",
		Cost = 120000,
		RequiresIsland = "Crystal",
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
	Celestial = {
		Id = "Celestial",
		DisplayName = "Celestial Egg",
		Cost = 600000,
		RequiresIsland = "Celestial",
		Description = "A radiant, star-flecked egg that always hatches a Celestial Dragon.",
		RarityColor = Color3.fromRGB(255, 220, 120),
		EggColor = Color3.fromRGB(200, 170, 90),
		SpotColor = Color3.fromRGB(255, 245, 210),
		GlowColor = Color3.fromRGB(255, 235, 150),
		Icon = "rbxassetid://112684829478873",
		Dragons = {
			{ Name = "CelestialDragon", DisplayName = "Celestial Dragon", ModelName = "CelestialDragon", Weight = 1 },
		},
	},
	Gem = {
		Id = "Gem",
		DisplayName = "Gem Egg",
		GemCost = 25,
		Description = "Bought with Gems, not Essence. Hatches any known dragon species - including ones from islands you haven't unlocked yet - with better odds at a Secret Dragon.",
		RarityColor = Color3.fromRGB(255, 120, 220),
		EggColor = Color3.fromRGB(200, 90, 220),
		SpotColor = Color3.fromRGB(255, 200, 250),
		GlowColor = Color3.fromRGB(255, 130, 230),
		Icon = "rbxassetid://78918235954057",
		Dragons = {
			{ Name = "ForestDragon", DisplayName = "Forest Dragon", ModelName = "ForestDragon", Weight = 1 },
			{ Name = "IceDragon", DisplayName = "Ice Dragon", ModelName = "IceDragon", Weight = 1 },
			{ Name = "FireDragon", DisplayName = "Fire Dragon", ModelName = "FireDragon", Weight = 1 },
			{ Name = "LavaDragon", DisplayName = "Lava Dragon", ModelName = "LavaDragon", Weight = 1 },
			{ Name = "StormDragon", DisplayName = "Storm Dragon", ModelName = "StormDragon", Weight = 1 },
			{ Name = "VoidDragon", DisplayName = "Void Dragon", ModelName = "VoidDragon", Weight = 1 },
			{ Name = "CrystalDragon", DisplayName = "Crystal Dragon", ModelName = "CrystalDragon", Weight = 1 },
			{ Name = "CelestialDragon", DisplayName = "Celestial Dragon", ModelName = "CelestialDragon", Weight = 1 },
		},
	},
	Featured = {
		Id = "Featured",
		DisplayName = "Featured Egg",
		Cost = 2000,
		Description = "Limited-time weekly egg with massively boosted odds for a Secret Dragon. Returns to normal odds elsewhere once the week's window closes.",
		RarityColor = Color3.fromRGB(255, 150, 60),
		EggColor = Color3.fromRGB(255, 150, 60),
		SpotColor = Color3.fromRGB(255, 210, 130),
		GlowColor = Color3.fromRGB(255, 170, 70),
		Icon = "rbxassetid://78843852703854",
		IsFeatured = true,
		Dragons = {
			{ Name = "ForestDragon", DisplayName = "Forest Dragon", ModelName = "ForestDragon", Weight = 1 },
			{ Name = "FireDragon", DisplayName = "Fire Dragon", ModelName = "FireDragon", Weight = 1 },
			{ Name = "IceDragon", DisplayName = "Ice Dragon", ModelName = "IceDragon", Weight = 1 },
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

-- Every purchasable egg (not Rare - tutorial-only, kept predictable; not Ancient - reserved) has a
-- tiny, uniform chance of hatching one of these secret dragons instead of its normal species pool.
-- Weight is computed relative to each egg's own normal-dragon weight total, so the resulting percent
-- chance is the same (~SECRET_DRAGON_CHANCE) on every egg regardless of how many normal species it has.
local SECRET_DRAGON_CHANCE = 0.005
local SECRET_DRAGON_EGGS = { "Common", "Forest", "Ice", "Fire", "Lava", "Storm", "Shadow", "Crystal", "Celestial" }
local SECRET_DRAGONS = {
	{ Name = "PoisonDragon", DisplayName = "Poison Dragon", ModelName = "PoisonDragon" },
	{ Name = "CoralOceanDragon", DisplayName = "Coral Ocean Dragon", ModelName = "CoralOceanDragon" },
}

for _, eggId in SECRET_DRAGON_EGGS do
	local eggInfo = DragonEggConfig.EggTypes[eggId]
	local normalWeight = 0
	for _, dragon in eggInfo.Dragons do
		normalWeight += dragon.Weight or 1
	end
	local secretWeight = normalWeight * SECRET_DRAGON_CHANCE
	for _, secret in SECRET_DRAGONS do
		table.insert(eggInfo.Dragons, {
			Name = secret.Name,
			DisplayName = secret.DisplayName,
			ModelName = secret.ModelName,
			Weight = secretWeight,
		})
	end
end

-- The Gem Egg gets a boosted (not just the uniform SECRET_DRAGON_CHANCE) shot at a Secret Dragon,
-- since it's bought with Gems rather than earned/ground-out Essence - a premium egg should feel
-- like better luck, not just more convenient species access.
local GEM_EGG_SECRET_CHANCE = 0.02
do
	local eggInfo = DragonEggConfig.EggTypes.Gem
	local normalWeight = 0
	for _, dragon in eggInfo.Dragons do
		normalWeight += dragon.Weight or 1
	end
	local secretWeight = normalWeight * GEM_EGG_SECRET_CHANCE
	for _, secret in SECRET_DRAGONS do
		table.insert(eggInfo.Dragons, {
			Name = secret.Name,
			DisplayName = secret.DisplayName,
			ModelName = secret.ModelName,
			Weight = secretWeight,
		})
	end
end

-- The Featured Egg is the star of the weekly rotation - a much bigger shot at a Secret Dragon than
-- even the Gem Egg gets, since it's only purchasable during its active window (see
-- IsFeaturedEggActive below), not something farmable every day.
local FEATURED_EGG_SECRET_CHANCE = 0.08
do
	local eggInfo = DragonEggConfig.EggTypes.Featured
	local normalWeight = 0
	for _, dragon in eggInfo.Dragons do
		normalWeight += dragon.Weight or 1
	end
	local secretWeight = normalWeight * FEATURED_EGG_SECRET_CHANCE
	for _, secret in SECRET_DRAGONS do
		table.insert(eggInfo.Dragons, {
			Name = secret.Name,
			DisplayName = secret.DisplayName,
			ModelName = secret.ModelName,
			Weight = secretWeight,
		})
	end
end

-- Featured Egg availability window: active for the first FEATURED_ACTIVE_DAYS of every 7-day
-- cycle (the same week boundary the weekly leaderboard uses), then hidden for the rest of the
-- week so it actually feels limited-time rather than a permanent shop fixture. No admin scheduling
-- needed - it's purely a function of the current time, so it rotates forever on its own.
local WEEK_SECONDS = 7 * 24 * 60 * 60
local FEATURED_ACTIVE_DAYS = 5
local FEATURED_ACTIVE_SECONDS = FEATURED_ACTIVE_DAYS * 24 * 60 * 60

local function getWeekProgressSeconds()
	return os.time() % WEEK_SECONDS
end

function DragonEggConfig.IsFeaturedEggActive()
	return getWeekProgressSeconds() < FEATURED_ACTIVE_SECONDS
end

-- Seconds remaining in the current state (closes soon if active, opens soon if not).
function DragonEggConfig.GetFeaturedEggCountdown()
	local progress = getWeekProgressSeconds()
	if progress < FEATURED_ACTIVE_SECONDS then
		return FEATURED_ACTIVE_SECONDS - progress
	end
	return WEEK_SECONDS - progress
end

-- Base combat/harvest power multiplier per species, applied in getDragonStats on top of rarity,
-- level, and evolution (star) bonuses. Escalates with island unlock order, so a dragon from a
-- later island is inherently stronger than one from an earlier island at the same level/rarity/
-- stars. FireDragon is not island-gated (see Fire egg above) so it sits at the same baseline as
-- the first island's dragon. Secret dragons (see SECRET_DRAGON_EGGS above) are deliberately far
-- above even the best island dragon, since pulling one is a ~0.5% event.
DragonEggConfig.SpeciesPowerMultiplier = {
	ForestDragon = 1.0,
	FireDragon = 1.0,
	IceDragon = 1.15,
	LavaDragon = 1.3,
	StormDragon = 1.5,
	VoidDragon = 1.7,
	CrystalDragon = 2.0,
	CelestialDragon = 2.5,
	PoisonDragon = 5.0,
	CoralOceanDragon = 5.0,
	-- VIP Pass exclusive - deliberately below Celestial (2.5) and well below the secret dragons
	-- (5.0), so it's a nice paid shortcut/cosmetic flex, not the strongest dragon in the game.
	VipDragon = 2.2,
}

function DragonEggConfig.GetSpeciesPowerMultiplier(dragonType)
	return DragonEggConfig.SpeciesPowerMultiplier[dragonType] or 1
end

-- Sell Shop base value per rarity tier (before level/evolution/species multipliers). Escalates
-- roughly in step with how hard each rarity is to pull, so selling a lucky pull is meaningfully
-- rewarding without ever being a better deal than actually using the dragon.
DragonEggConfig.SellValueByRarity = {
	Common = 50,
	Rare = 200,
	Epic = 800,
	Legendary = 3000,
	Mythic = 10000,
	Ancient = 30000,
}

-- Sell value formula, reusing the same level/star/species multipliers getDragonStats uses, so a
-- stronger dragon always sells for more - selling never outpaces the value of keeping and using it.
function DragonEggConfig.GetDragonSellValue(rarity, level, evolutionLevel, dragonType)
	local base = DragonEggConfig.SellValueByRarity[rarity or "Common"] or DragonEggConfig.SellValueByRarity.Common
	local safeLevel = math.max(1, math.floor(tonumber(level) or 1))
	local safeEvolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(evolutionLevel)
	local levelMultiplier = 1 + (safeLevel - 1) * 0.15
	local evolutionMultiplier = 1 + safeEvolutionLevel * 0.5
	local speciesMultiplier = DragonEggConfig.GetSpeciesPowerMultiplier(dragonType)
	return math.floor(base * levelMultiplier * evolutionMultiplier * speciesMultiplier + 0.5)
end

-- Order matches island unlock progression (Forest, Cold, Lava, Storm, Shadow, Crystal, Celestial),
-- with Fire (not island-gated) placed right after the first two, and Ancient (reserved) last.
DragonEggConfig.EggOrder = { "Common", "Featured", "Forest", "Ice", "Fire", "Lava", "Storm", "Shadow", "Crystal", "Celestial", "Gem", "Ancient" }
DragonEggConfig.RewardEggOrder = { "Common", "Rare", "Forest", "Ice", "Fire", "Lava", "Storm", "Shadow", "Crystal", "Celestial", "Ancient" }

DragonEggConfig.EggCost = DragonEggConfig.EggTypes.Common.Cost
DragonEggConfig.DragonTypes = {
	"ForestDragon",
	"IceDragon",
	"FireDragon",
	"LavaDragon",
	"StormDragon",
	"VoidDragon",
	"CrystalDragon",
	"CelestialDragon",
	"PoisonDragon",
	"CoralOceanDragon",
	"VipDragon",
}

-- Same per-species artwork used for the egg-hatch reveal card, shared here so the Dragon Roster
-- (list rows + detail panel) can show a species-accurate icon instead of one generic dragon icon
-- on every entry regardless of type.
DragonEggConfig.SpeciesIcons = {
	ForestDragon = "rbxassetid://114447555397002",
	IceDragon = "rbxassetid://79175381980147",
	FireDragon = "rbxassetid://130942758121470",
	LavaDragon = "rbxassetid://113492446505113",
	StormDragon = "rbxassetid://108007135510335",
	VoidDragon = "rbxassetid://106499302625266",
	CrystalDragon = "rbxassetid://110920243474682",
	CelestialDragon = "rbxassetid://137631014879654",
	PoisonDragon = "rbxassetid://81777420880303",
	CoralOceanDragon = "rbxassetid://140189536944717",
	VipDragon = "rbxassetid://117149685970656",
}

function DragonEggConfig.GetSpeciesIcon(dragonType)
	return DragonEggConfig.SpeciesIcons[dragonType]
end

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

-- 0 (Common) through 5 (Ancient) - how far up the rarity list this tier sits. Used to scale
-- cosmetic polish (glow/sparkle) so higher rarities visibly stand out even before any merging.
function DragonEggConfig.GetRarityTier(rarityName)
	for index, rarity in DragonEggConfig.Rarities do
		if rarity.Name == rarityName then
			return index - 1
		end
	end
	return 0
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

-- Display names for dragons not obtained through any egg (so GetDragonEntry below has nothing to
-- find) - currently just the VIP Pass exclusive.
local SPECIAL_DRAGON_DISPLAY_NAMES = {
	VipDragon = "Royal Dragon",
}

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
	return (entry and entry.DisplayName) or SPECIAL_DRAGON_DISPLAY_NAMES[dragonType] or dragonType
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