local AdminConfig = {
	-- Add your Roblox UserId here (required when game.CreatorId is 0 in Studio).
	-- Example: ExtraAdminUserIds = { 123456789 },
	ExtraAdminUserIds = {
		10196651969,
	},
	ToggleKey = Enum.KeyCode.RightShift,
	DefaultEssenceAmount = 1000,
	DefaultResourceAmount = 1,
	ResourceTypes = {
		{ Id = "CrystalResource", DisplayName = "Crystal Resource", Icon = "rbxassetid://73150429062000" },
		{ Id = "EmeraldCrystal", DisplayName = "Emerald Crystal", Icon = "rbxassetid://75581768563141" },
		{ Id = "RubyCrystal", DisplayName = "Ruby Crystal", Icon = "rbxassetid://127726919558379" },
		{ Id = "SapphireCrystal", DisplayName = "Sapphire Crystal", Icon = "rbxassetid://78918235954057" },
	},
	TabOrder = { "Player", "Resources", "Eggs", "Dragons", "World", "Buildings", "Progress", "Save", "Debug" },
}

local allowedIds = {}

local function rebuildAllowedIds()
	table.clear(allowedIds)
	if game.CreatorId and game.CreatorId > 0 then
		allowedIds[game.CreatorId] = true
	end
	for _, userId in AdminConfig.ExtraAdminUserIds do
		local numericId = tonumber(userId)
		if numericId and numericId > 0 then
			allowedIds[numericId] = true
		end
	end
end

rebuildAllowedIds()

function AdminConfig.IsAdmin(player)
	if not player or not player:IsA("Player") then
		return false
	end
	return allowedIds[player.UserId] == true
end

function AdminConfig.GetToggleKey()
	return AdminConfig.ToggleKey or Enum.KeyCode.RightShift
end

return AdminConfig
