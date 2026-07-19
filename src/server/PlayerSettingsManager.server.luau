local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local SettingsEvents = ReplicatedStorage:WaitForChild("SettingsEvents")
local SetPlayerSetting = SettingsEvents:WaitForChild("SetPlayerSetting")

local SETTINGS_DATASTORE = "DragonIslandSettingsV1"
local DEFAULTS = {
	MusicVolume = 1,
	SFXVolume = 1,
}

local settingsStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(SETTINGS_DATASTORE)
	end)
	if success then
		settingsStore = result
		dataStoreAvailable = true
	else
		warn("[PlayerSettingsManager] Settings DataStore unavailable; settings will not persist until publishing:", result)
	end
end

local playerData = {}

local function saveDataNow(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not settingsStore then
		return
	end
	local success, err = pcall(function()
		settingsStore:UpdateAsync(tostring(player.UserId), function()
			return data
		end)
	end)
	if not success then
		warn("[PlayerSettingsManager] Failed to save settings for", player.UserId, err)
	end
end

local function loadPlayer(player)
	local data = { MusicVolume = DEFAULTS.MusicVolume, SFXVolume = DEFAULTS.SFXVolume }
	if dataStoreAvailable and settingsStore then
		local success, result = pcall(function()
			return settingsStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			for key in DEFAULTS do
				local value = tonumber(result[key])
				if value then
					data[key] = math.clamp(value, 0, 1)
				end
			end
		elseif not success then
			warn("[PlayerSettingsManager] Failed to load settings for", player.UserId, result)
		end
	end
	playerData[player] = data
	for key, value in data do
		player:SetAttribute(key, value)
	end
end

SetPlayerSetting.OnServerEvent:Connect(function(player, settingName, value)
	if typeof(settingName) ~= "string" or DEFAULTS[settingName] == nil then
		return
	end
	value = tonumber(value)
	if not value then
		return
	end
	value = math.clamp(value, 0, 1)

	local data = playerData[player]
	if not data then
		return
	end
	data[settingName] = value
	player:SetAttribute(settingName, value)
	saveDataNow(player)
end)

Players.PlayerAdded:Connect(loadPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveDataNow(player)
	playerData[player] = nil
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveDataNow(player)
	end
end)

print("[PlayerSettingsManager] Player settings ready")
