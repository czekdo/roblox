local IslandUnlockConfig = {
	FolderName = "Another island ",
	ShrineFolderName = "IslandUnlockShrines",
	BarrierFolderName = "IslandUnlockBarriers",
	DataStoreName = "IslandUnlocksV1",
	WorldPortalPromptName = "WorldPortalPrompt",

	LockedColor = Color3.fromRGB(210, 70, 70),
	UnlockedColor = Color3.fromRGB(70, 200, 110),
	BarrierColor = Color3.fromRGB(255, 80, 90),

	Islands = {
		{
			Id = "Forest",
			ModelName = "wyspa forest",
			DisplayName = "Forest Island",
			ShortName = "Forest Island",
			Emoji = "🌿",
			Icon = "rbxassetid://122842695290895",
			Accent = Color3.fromRGB(72, 180, 95),
			Cost = 5000,
		},
		{
			Id = "Cold",
			ModelName = "wyspa cold",
			DisplayName = "Cold Island",
			ShortName = "Cold Island",
			Emoji = "❄",
			Icon = "rbxassetid://104293709713395",
			Accent = Color3.fromRGB(120, 190, 255),
			Cost = 20000,
		},
		{
			Id = "Lava",
			ModelName = "wyspa lawa",
			DisplayName = "Lava Island",
			ShortName = "Lava Island",
			Emoji = "🔥",
			Icon = "rbxassetid://73214946386499",
			Accent = Color3.fromRGB(255, 120, 55),
			Cost = 75000,
		},
		{
			Id = "Storm",
			ModelName = "wyspa storm",
			DisplayName = "Storm Island",
			ShortName = "Storm Island",
			Emoji = "⚡",
			Icon = "rbxassetid://72607541698873",
			Accent = Color3.fromRGB(170, 130, 255),
			Cost = 250000,
		},
		{
			Id = "Shadow",
			ModelName = "wyspa shadow",
			DisplayName = "Shadow Island",
			ShortName = "Shadow Island",
			Emoji = "🌑",
			Icon = "rbxassetid://126528254643859",
			Accent = Color3.fromRGB(120, 95, 170),
			Cost = 750000,
		},
		{
			Id = "Crystal",
			ModelName = "wyspa crystal",
			DisplayName = "Crystal Island",
			ShortName = "Crystal Island",
			Emoji = "💎",
			Icon = "rbxassetid://73150429062000",
			Accent = Color3.fromRGB(95, 210, 255),
			Cost = 2000000,
		},
		{
			Id = "Celestial",
			ModelName = "wyspa celestal",
			DisplayName = "Celestial Island",
			ShortName = "Celestial Island",
			Emoji = "✨",
			Icon = "rbxassetid://112684829478873",
			Accent = Color3.fromRGB(255, 220, 120),
			Cost = 10000000,
		},
	},
}

function IslandUnlockConfig.GetIslandById(islandId)
	for _, island in IslandUnlockConfig.Islands do
		if island.Id == islandId then
			return island
		end
	end
	return nil
end

function IslandUnlockConfig.GetIslandIndex(islandId)
	for index, island in IslandUnlockConfig.Islands do
		if island.Id == islandId then
			return index
		end
	end
	return nil
end

function IslandUnlockConfig.FormatCost(cost)
	local value = math.max(0, math.floor(tonumber(cost) or 0))
	local formatted = tostring(value)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

function IslandUnlockConfig.GetCardTitle(island)
	if not island then
		return "Island"
	end
	return string.format("%s %s", island.Emoji or "", island.ShortName or island.DisplayName)
end

return IslandUnlockConfig