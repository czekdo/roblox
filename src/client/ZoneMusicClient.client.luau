local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local ZONE_HUB = "Hub"
local ZONE_MAIN_ISLAND = "MainIsland"
local FADE_TIME = 1.4

local TRACKS = {
	[ZONE_HUB] = {
		SoundId = "rbxassetid://1839766217",
		Volume = 0.22,
	},
	[ZONE_MAIN_ISLAND] = {
		SoundId = "rbxassetid://1841647093",
		Volume = 0.28,
	},
}

local musicFolder = Instance.new("Folder")
musicFolder.Name = "ZoneMusic"
musicFolder.Parent = SoundService

local activeSound
local activeZone

local function getOrCreateSound(zone)
	local track = TRACKS[zone]
	if not track then
		return nil
	end

	local sound = musicFolder:FindFirstChild(zone)
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = zone
		sound.SoundId = track.SoundId
		sound.Looped = true
		sound.Volume = 0
		sound.RollOffMaxDistance = 0
		sound.Parent = musicFolder
	end
	return sound
end

local function getMusicVolumeMultiplier()
	return player:GetAttribute("MusicVolume") or 1
end

local function fadeSound(sound, targetVolume)
	if not sound then
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Volume = targetVolume,
	})
	tween:Play()
end

local function playZoneMusic(zone)
	if zone == activeZone then
		return
	end
	activeZone = zone

	local nextSound = getOrCreateSound(zone)
	if not nextSound then
		return
	end

	if activeSound and activeSound ~= nextSound then
		fadeSound(activeSound, 0)
		task.delay(FADE_TIME, function()
			if activeSound and activeSound.Volume <= 0.01 then
				activeSound:Stop()
			end
		end)
	end

	activeSound = nextSound
	if not activeSound.IsPlaying then
		activeSound:Play()
	end
	fadeSound(activeSound, TRACKS[zone].Volume * getMusicVolumeMultiplier())
end

local function onZoneChanged()
	local zone = player:GetAttribute("CurrentZone") or ZONE_MAIN_ISLAND
	playZoneMusic(zone)
end

player:GetAttributeChangedSignal("CurrentZone"):Connect(onZoneChanged)
task.defer(onZoneChanged)

-- Live-adjusts the currently playing track when the player drags the Music Volume
-- slider, instead of only picking up the new multiplier on the next zone change.
player:GetAttributeChangedSignal("MusicVolume"):Connect(function()
	if activeSound and activeZone and TRACKS[activeZone] then
		activeSound.Volume = TRACKS[activeZone].Volume * getMusicVolumeMultiplier()
	end
end)
