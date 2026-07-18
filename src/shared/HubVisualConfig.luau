local HubVisualConfig = {}

HubVisualConfig.HubCenter = Vector3.new(1000, -44, -56)

HubVisualConfig.LOD = {
	FullDistance = 90,
	ReducedDistance = 160,
	DisabledDistance = 220,
}

HubVisualConfig.Colors = {
	Gold = Color3.fromRGB(218, 175, 70),
	GoldBright = Color3.fromRGB(255, 220, 140),
	Crystal = Color3.fromRGB(90, 200, 220),
	CrystalDeep = Color3.fromRGB(55, 140, 175),
	Magic = Color3.fromRGB(120, 60, 160),
	Warm = Color3.fromRGB(255, 170, 90),
	Portal = Color3.fromRGB(120, 220, 255),
}

HubVisualConfig.PromptHeight = 3

HubVisualConfig.Buildings = {
	QuestHall = {
		ModelName = "QuestHall",
		InteractionPosition = Vector3.new(1051.3, -41.84, -117.5),
		Prompt = { ActionText = "Quests", ObjectText = "Quest Hall" },
		IndicatorKind = "Quest",
	},
	DailyRewardsShrine = {
		ModelName = "DailyRewardsShrine",
		InteractionPosition = Vector3.new(942.7, -41.94, -118.4),
		Prompt = { ActionText = "Claim", ObjectText = "Daily Rewards" },
		IndicatorKind = "Reward",
	},
	TradingPlaza = {
		ModelName = "TradingPlaza",
		InteractionPosition = Vector3.new(941.0, -42.23, 5.7),
		Prompt = { ActionText = "Trade", ObjectText = "Trading Plaza" },
	},
	LeaderboardMonument = {
		ModelName = "LeaderboardMonument",
		InteractionPosition = Vector3.new(1051.8, -42.07, 5.5),
		Prompt = { ActionText = "View", ObjectText = "Leaderboards" },
	},
}

HubVisualConfig.PortalInteractionAnchors = {
	HubPortal = Vector3.new(997.6, -47.4, -122.5),
	MainIslandPortal = Vector3.new(5.4, -14.2, -91.1),
}

HubVisualConfig.PortalModelNames = {
	"HubPortal",
	"MainIslandPortal",
}

HubVisualConfig.Icons = {
	Exclamation = "rbxassetid://99848348794456",
	Gift = "rbxassetid://122416766679510",
}

return HubVisualConfig
