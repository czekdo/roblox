local TutorialData = {}

TutorialData.VERSION = 2
TutorialData.DATASTORE_NAME = "DragonIslandTutorialV2"
TutorialData.LEGACY_DATASTORE_NAME = "DragonIslandTutorialV1"

TutorialData.COMPLETION_REWARD = {
	DragonEssence = 500,
	PremiumGems = 100,
	EggType = "Rare",
	BoostSeconds = 1800,
	Title = "Island Guide",
	Badge = "Beginner",
}

TutorialData.Steps = {
	{
		Id = "Welcome",
		Title = "Welcome, Dragon Keeper",
		Description = "Dragon Island Kingdom is yours to grow. This guided tour will teach every core system in a few minutes.",
		ActionHint = "Tap Continue when you are ready to begin.",
		Kind = "info",
		Reward = { DragonEssence = 25 },
	},
	{
		Id = "CollectDragonEssence",
		Title = "Collect Dragon Essence",
		Description = "Dragon Essence powers eggs, upgrades, and kingdom growth. Harvest it from crystal nodes on your island.",
		ActionHint = "Tap a glowing crystal node and let your dragon gather essence.",
		Kind = "action",
		Reward = { DragonEssence = 50 },
	},
	{
		Id = "BuyFirstEgg",
		Title = "Buy Your First Egg",
		Description = "Eggs hatch into dragons with unique abilities. Start with a Common Egg from the Egg Shop.",
		ActionHint = "Open Egg Shop, then purchase a Common Egg.",
		Kind = "action",
		Target = { nav = "EggShopToggle", panel = "CommonEggCard", button = "PurchaseButton" },
		Reward = { DragonEssence = 75 },
	},
	{
		Id = "HatchFirstDragon",
		Title = "Hatch Your First Dragon",
		Description = "Place your egg near the hatchery and wait for it to crack open into a dragon companion.",
		ActionHint = "Stay near your egg until the hatch cinematic completes.",
		Kind = "action",
		Reward = { DragonEssence = 100 },
	},
	{
		Id = "EquipFirstDragon",
		Title = "Equip a Dragon",
		Description = "Equipped dragons follow you and can harvest resources. Only equipped dragons enter combat and training.",
		ActionHint = "Open Dragons, select a dragon, then tap Equip.",
		Kind = "action",
		Target = { nav = "DragonsToggle", button = "EquipButton" },
		Reward = { DragonEssence = 75 },
	},
	{
		Id = "HarvestWithDragon",
		Title = "Harvest Resources",
		Description = "Send equipped dragons to resource nodes for bonus materials and essence.",
		ActionHint = "Tap a resource node on your island to start harvesting.",
		Kind = "action",
		Reward = { DragonEssence = 100 },
	},
	{
		Id = "TrainFirstDragon",
		Title = "Train a Dragon",
		Description = "The Dragon Academy levels dragons while you keep playing. Training boosts power permanently.",
		ActionHint = "Open Academy, pick a dragon and program, then start training.",
		Kind = "action",
		Target = { nav = "DragonTrainingToggle", button = "StartTrainingButton" },
		Reward = { DragonEssence = 125 },
	},
	{
		Id = "MergeDragons",
		Title = "Merge Dragons",
		Description = "Combine three identical dragons to evolve them, gain stars, and strengthen abilities.",
		ActionHint = "Open Merge, select three matching dragons, then tap Merge Dragons.",
		Kind = "action",
		Target = { nav = "DragonMergeToggle", button = "MergeButton" },
		Reward = { DragonEssence = 150 },
	},
	{
		Id = "UpgradeKingdom",
		Title = "Upgrade the Kingdom",
		Description = "Buildings multiply your progress. Unlock and upgrade structures to expand storage, training, and hatching.",
		ActionHint = "Open Buildings, select a structure, then upgrade it once.",
		Kind = "action",
		Target = { nav = "BuildingsToggle", button = "ActionButton" },
		Reward = { DragonEssence = 150, PremiumGems = 15 },
	},
	{
		Id = "UnlockSecondIsland",
		Title = "Unlock a New Island",
		Description = "Biome islands unlock rare resources and new adventures. Forest Island is your first expansion.",
		ActionHint = "Travel to Forest Island's shrine and pay the unlock cost.",
		Kind = "action",
		Reward = { DragonEssence = 200, PremiumGems = 25 },
	},
	{
		Id = "ExplainDailyQuests",
		Title = "Daily Quests",
		Description = "Complete rotating quests for essence, gems, and bonus eggs. Quests refresh every day.",
		ActionHint = "Open Quests to preview today's objectives and rewards.",
		Kind = "info",
		Target = { nav = "DailyQuestsToggle" },
		Reward = { DragonEssence = 50 },
	},
	{
		Id = "ExplainCodex",
		Title = "Dragon Codex",
		Description = "The Codex tracks every species you discover, their abilities, and your collection mastery.",
		ActionHint = "Open Dragons, then switch to the Codex tab.",
		Kind = "info",
		Target = { nav = "DragonsToggle", button = "CodexTab" },
		Reward = { DragonEssence = 50 },
	},
	{
		Id = "IntroduceAscensionGate",
		Title = "Ascension Gate",
		Description = "When your kingdom is mighty enough, the Ascension Gate offers rebirth — permanent bonuses at the cost of a reset. Explore it anytime; ascension is never required.",
		ActionHint = "Open Ascension to preview requirements and rewards.",
		Kind = "info",
		Target = { nav = "RebirthToggle" },
		Reward = { DragonEssence = 75, PremiumGems = 20 },
	},
}

local stepIndexById = {}
for index, step in TutorialData.Steps do
	stepIndexById[step.Id] = index
end
TutorialData.StepIndexById = stepIndexById
TutorialData.StepCount = #TutorialData.Steps

function TutorialData.GetStep(index)
	return TutorialData.Steps[index]
end

function TutorialData.GetStepById(stepId)
	local index = stepIndexById[stepId]
	if index then
		return TutorialData.Steps[index], index
	end
	return nil
end

function TutorialData.IsInfoStep(stepId)
	local step = TutorialData.GetStepById(stepId)
	return step and step.Kind == "info"
end

function TutorialData.CopyStepsForClient()
	local result = {}
	for index, step in TutorialData.Steps do
		result[index] = {
			Id = step.Id,
			Title = step.Title,
			Description = step.Description,
			ActionHint = step.ActionHint,
			Kind = step.Kind,
			Reward = step.Reward,
		}
	end
	return result
end

function TutorialData.FormatReward(reward)
	if typeof(reward) ~= "table" then
		return ""
	end
	local parts = {}
	if reward.DragonEssence then
		table.insert(parts, "+" .. tostring(reward.DragonEssence) .. " Essence")
	end
	if reward.PremiumGems then
		table.insert(parts, "+" .. tostring(reward.PremiumGems) .. " Gems")
	end
	if reward.EggType then
		table.insert(parts, "+1 " .. reward.EggType .. " Egg")
	end
	if reward.BoostSeconds then
		table.insert(parts, "Starter Boost")
	end
	if reward.Title then
		table.insert(parts, "Title: " .. reward.Title)
	end
	if reward.Badge then
		table.insert(parts, reward.Badge .. " Badge")
	end
	return table.concat(parts, "  •  ")
end

return TutorialData
