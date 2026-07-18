local AchievementConfig = {}

AchievementConfig.DataStoreName = "AchievementProgressV1"
AchievementConfig.SaveDelay = 6
AchievementConfig.PlayTimeTick = 60

AchievementConfig.Categories = {
	{ Id = "Dragons", Name = "Dragons", Emoji = "🐉", IconKey = "Dragon" },
	{ Id = "Eggs", Name = "Eggs", Emoji = "🥚", IconKey = "Egg" },
	{ Id = "Exploration", Name = "Exploration", Emoji = "🏝", IconKey = "House" },
	{ Id = "Kingdom", Name = "Kingdom", Emoji = "🏰", IconKey = "Crown" },
	{ Id = "Training", Name = "Training", Emoji = "⭐", IconKey = "Book" },
	{ Id = "Merge", Name = "Merge", Emoji = "✨", IconKey = "Merge" },
	{ Id = "Collection", Name = "Collection", Emoji = "📖", IconKey = "Book" },
	{ Id = "Resources", Name = "Resources", Emoji = "💰", IconKey = "Crystal" },
	{ Id = "Miscellaneous", Name = "Miscellaneous", Emoji = "🎯", IconKey = "Trophy" },
}

local function essenceReward(amount, text)
	return { Type = "DragonEssence", Amount = amount, Text = text or ("+" .. tostring(amount) .. " Dragon Essence") }
end

local function gemReward(amount, text)
	return { Type = "PremiumCurrency", Amount = amount, Text = text or ("+" .. tostring(amount) .. " Gems") }
end

local function eggReward(eggType, text)
	return { Type = "ExclusiveEgg", EggType = eggType, Text = text or ("+1 " .. eggType .. " Egg") }
end

local function titleReward(titleId, displayName)
	return { Type = "Title", TitleId = titleId, Text = "Title: " .. displayName }
end

local function badgeReward(badgeId, displayName)
	return { Type = "CosmeticBadge", BadgeId = badgeId, Text = "Badge: " .. displayName }
end

AchievementConfig.Achievements = {
	-- Dragons
	{ Id = "Hatch10", Category = "Dragons", Title = "Dragon Breeder", Description = "Hatch 10 Dragons", Stat = "HatchCount", Target = 10, IconKey = "Dragon", Reward = essenceReward(250) },
	{ Id = "Hatch50", Category = "Dragons", Title = "Dragon Keeper", Description = "Hatch 50 Dragons", Stat = "HatchCount", Target = 50, IconKey = "Dragon", Reward = essenceReward(750) },
	{ Id = "Hatch100", Category = "Dragons", Title = "Dragon Collector", Description = "Hatch 100 Dragons", Stat = "HatchCount", Target = 100, IconKey = "Dragon", Reward = essenceReward(1500) },
	{ Id = "Hatch500", Category = "Dragons", Title = "Dragon Master", Description = "Hatch 500 Dragons", Stat = "HatchCount", Target = 500, IconKey = "Dragon", Reward = gemReward(25, "+25 Gems") },
	{ Id = "Hatch1000", Category = "Dragons", Title = "Dragon Legend", Description = "Hatch 1000 Dragons", Stat = "HatchCount", Target = 1000, IconKey = "Dragon", Reward = gemReward(100, "+100 Gems") },

	-- Eggs
	{ Id = "FirstEgg", Category = "Eggs", Title = "First Crack", Description = "Open your first Egg", Stat = "EggsOpened", Target = 1, IconKey = "Egg", Reward = essenceReward(100) },
	{ Id = "AllEggTypes", Category = "Eggs", Title = "Egg Connoisseur", Description = "Open every Egg type", Stat = "AllEggTypes", Target = 1, IconKey = "Egg", Reward = eggReward("Forest", "+1 Forest Egg") },
	{ Id = "HatchLegendary", Category = "Eggs", Title = "Legendary Hatcher", Description = "Hatch a Legendary Dragon", Stat = "HatchLegendary", Target = 1, IconKey = "Star", Reward = essenceReward(2000) },
	{ Id = "HatchMythic", Category = "Eggs", Title = "Mythic Hatcher", Description = "Hatch a Mythic Dragon", Stat = "HatchMythic", Target = 1, IconKey = "Star", Reward = gemReward(50, "+50 Gems") },

	-- Exploration
	{ Id = "UnlockIsland2", Category = "Exploration", Title = "Cold Explorer", Description = "Unlock Island 2", Stat = "IslandIndex", Target = 2, IconKey = "House", Reward = essenceReward(1000) },
	{ Id = "UnlockIsland5", Category = "Exploration", Title = "Shadow Voyager", Description = "Unlock Island 5", Stat = "IslandIndex", Target = 5, IconKey = "House", Reward = essenceReward(5000) },
	{ Id = "UnlockAllIslands", Category = "Exploration", Title = "World Traveler", Description = "Unlock every Island", Stat = "AllIslands", Target = 1, IconKey = "House", Reward = gemReward(75, "+75 Gems") },

	-- Kingdom
	{ Id = "UpgradeOneBuilding", Category = "Kingdom", Title = "Builder", Description = "Upgrade one building", Stat = "BuildingUpgrades", Target = 1, IconKey = "Upgrade", Reward = essenceReward(300) },
	{ Id = "AllBuildingsLevel5", Category = "Kingdom", Title = "Master Builder", Description = "Upgrade every building to Level 5", Stat = "AllBuildingsLevel5", Target = 1, IconKey = "Upgrade", Reward = gemReward(40, "+40 Gems") },
	{ Id = "KingdomLevel10", Category = "Kingdom", Title = "Rising Kingdom", Description = "Upgrade your Kingdom to Level 10", Stat = "KingdomLevel", Target = 10, IconKey = "Crown", Reward = titleReward("RisingRuler", "Rising Ruler") },

	-- Training
	{ Id = "DragonLevel10", Category = "Training", Title = "Apprentice Trainer", Description = "Reach Dragon Level 10", Stat = "MaxDragonLevel", Target = 10, IconKey = "Book", Reward = essenceReward(500) },
	{ Id = "DragonLevel25", Category = "Training", Title = "Expert Trainer", Description = "Reach Dragon Level 25", Stat = "MaxDragonLevel", Target = 25, IconKey = "Book", Reward = essenceReward(1500) },
	{ Id = "DragonLevel50", Category = "Training", Title = "Master Trainer", Description = "Reach Dragon Level 50", Stat = "MaxDragonLevel", Target = 50, IconKey = "Book", Reward = gemReward(60, "+60 Gems") },

	-- Merge
	{ Id = "Merge10", Category = "Merge", Title = "Fusion Novice", Description = "Merge 10 Dragons", Stat = "MergeCount", Target = 10, IconKey = "Merge", Reward = essenceReward(600) },
	{ Id = "Merge50", Category = "Merge", Title = "Fusion Expert", Description = "Merge 50 Dragons", Stat = "MergeCount", Target = 50, IconKey = "Merge", Reward = essenceReward(2500) },
	{ Id = "Reach5Stars", Category = "Merge", Title = "Five Star Power", Description = "Reach 5 Stars", Stat = "MaxEvolution", Target = 5, IconKey = "Star", Reward = badgeReward("FiveStar", "Five Star") },
	{ Id = "ReachMaxStars", Category = "Merge", Title = "Max Evolution", Description = "Reach Max Stars", Stat = "MaxEvolution", Target = 5, IconKey = "Star", Reward = gemReward(80, "+80 Gems") },

	-- Collection
	{ Id = "Discover10Species", Category = "Collection", Title = "Naturalist", Description = "Discover 10 Dragon Species", Stat = "SpeciesDiscovered", Target = 10, IconKey = "Book", Reward = essenceReward(800) },
	{ Id = "Discover25Species", Category = "Collection", Title = "Dragon Scholar", Description = "Discover 25 Species", Stat = "SpeciesDiscovered", Target = 25, IconKey = "Book", Reward = essenceReward(3000) },
	{ Id = "CompleteCodex", Category = "Collection", Title = "Codex Master", Description = "Complete the Codex", Stat = "CompleteCodex", Target = 1, IconKey = "Book", Reward = titleReward("CodexMaster", "Codex Master") },

	-- Resources
	{ Id = "Essence10K", Category = "Resources", Title = "Essence Gatherer", Description = "Collect 10,000 Dragon Essence", Stat = "LifetimeEssence", Target = 10000, IconKey = "Crystal", Reward = essenceReward(500) },
	{ Id = "Essence100K", Category = "Resources", Title = "Essence Hoarder", Description = "Collect 100,000 Dragon Essence", Stat = "LifetimeEssence", Target = 100000, IconKey = "Crystal", Reward = essenceReward(2500) },
	{ Id = "Essence1M", Category = "Resources", Title = "Essence Tycoon", Description = "Collect 1,000,000 Dragon Essence", Stat = "LifetimeEssence", Target = 1000000, IconKey = "Crystal", Reward = gemReward(120, "+120 Gems") },

	-- Miscellaneous
	{ Id = "Play1Hour", Category = "Miscellaneous", Title = "Settled In", Description = "Play for 1 hour", Stat = "PlayTimeSeconds", Target = 3600, IconKey = "Trophy", Reward = essenceReward(400) },
	{ Id = "Play10Hours", Category = "Miscellaneous", Title = "Dedicated Keeper", Description = "Play for 10 hours", Stat = "PlayTimeSeconds", Target = 36000, IconKey = "Trophy", Reward = gemReward(30, "+30 Gems") },
	{ Id = "Play50Hours", Category = "Miscellaneous", Title = "Island Veteran", Description = "Play for 50 hours", Stat = "PlayTimeSeconds", Target = 180000, IconKey = "Trophy", Reward = badgeReward("Veteran", "Island Veteran") },
	{ Id = "Login7Days", Category = "Miscellaneous", Title = "Weekly Visitor", Description = "Login 7 Days", Stat = "LoginDays", Target = 7, IconKey = "Gift", Reward = eggReward("Ice", "+1 Ice Egg") },
	{ Id = "Login30Days", Category = "Miscellaneous", Title = "Loyal Guardian", Description = "Login 30 Days", Stat = "LoginDays", Target = 30, IconKey = "Gift", Reward = gemReward(150, "+150 Gems") },
}

local achievementById = {}
local achievementsByCategory = {}

for _, achievement in AchievementConfig.Achievements do
	achievementById[achievement.Id] = achievement
	achievementsByCategory[achievement.Category] = achievementsByCategory[achievement.Category] or {}
	table.insert(achievementsByCategory[achievement.Category], achievement)
end

function AchievementConfig.GetAchievement(id)
	return achievementById[id]
end

function AchievementConfig.GetAchievementsForCategory(categoryId)
	return achievementsByCategory[categoryId] or {}
end

function AchievementConfig.GetCategory(categoryId)
	for _, category in AchievementConfig.Categories do
		if category.Id == categoryId then
			return category
		end
	end
	return nil
end

function AchievementConfig.GetRewardText(reward)
	if typeof(reward) ~= "table" then
		return ""
	end
	return reward.Text or ""
end

return AchievementConfig
