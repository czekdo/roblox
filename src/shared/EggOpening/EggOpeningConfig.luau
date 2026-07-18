local EggOpeningConfig = {}

EggOpeningConfig.PlatformName = "EggOpeningPlatform"
EggOpeningConfig.TotalFallbackDuration = 16

EggOpeningConfig.Phases = {
	Spawn = 1.15,
	Float = 2.4,
	Curiosity = 2.6,
	BuildUp = 3.2,
	Charge = 1.6,
	Reveal = 1.1,
	Reward = 2.4,
}

EggOpeningConfig.RarityProfiles = {
	Common = { intensity = 1.0, particleScale = 1.0, soundPitch = 1.0, zoomStrength = 0.82, rewardHold = 1.8, glow = 1.0 },
	Rare = { intensity = 1.12, particleScale = 1.15, soundPitch = 1.05, zoomStrength = 0.88, rewardHold = 2.0, glow = 1.15 },
	Epic = { intensity = 1.25, particleScale = 1.3, soundPitch = 1.1, zoomStrength = 0.93, rewardHold = 2.3, glow = 1.3 },
	Legendary = { intensity = 1.45, particleScale = 1.55, soundPitch = 1.18, zoomStrength = 1.0, rewardHold = 2.8, glow = 1.55 },
	Mythic = { intensity = 1.62, particleScale = 1.75, soundPitch = 1.25, zoomStrength = 1.05, rewardHold = 3.2, glow = 1.75 },
	Ancient = { intensity = 1.8, particleScale = 2.0, soundPitch = 1.32, zoomStrength = 1.1, rewardHold = 3.8, glow = 2.0 },
}

EggOpeningConfig.SoundIds = {
	EggAppear = "rbxassetid://12222216",
	EggFloat = "rbxassetid://12222216",
	EggMove = "rbxassetid://12222216",
	EggShake = "rbxassetid://12222216",
	EggCharge = "rbxassetid://12222216",
	EggReveal = "rbxassetid://12222216",
	RewardAppear = "rbxassetid://12222216",
	RareReward = "rbxassetid://12222216",
	LegendaryReward = "rbxassetid://12222216",
}

function EggOpeningConfig.GetProfile(rarity)
	return EggOpeningConfig.RarityProfiles[rarity] or EggOpeningConfig.RarityProfiles.Common
end

function EggOpeningConfig.GetPhaseDuration(phaseName, profile)
	local base = EggOpeningConfig.Phases[phaseName] or 1
	local intensity = profile and profile.intensity or 1
	if phaseName == "BuildUp" or phaseName == "Charge" then
		return base * (0.9 + intensity * 0.12)
	end
	return base
end

function EggOpeningConfig.GetEstimatedDuration(profile)
	local total = 0
	for phaseName in EggOpeningConfig.Phases do
		total += EggOpeningConfig.GetPhaseDuration(phaseName, profile)
	end
	return total + (profile and profile.rewardHold or 1.8)
end

function EggOpeningConfig.FindOpeningPlatform(fallbackPosition)
	local platform = workspace:FindFirstChild(EggOpeningConfig.PlatformName, true)
	if platform and platform:IsA("BasePart") then
		return platform
	end
	return nil, fallbackPosition
end

function EggOpeningConfig.GetSpawnCFrame(fallbackPosition)
	local platform = EggOpeningConfig.FindOpeningPlatform(fallbackPosition)
	if platform then
		return platform.CFrame * CFrame.new(0, platform.Size.Y * 0.5 + 1.4, 0)
	end
	return CFrame.new(fallbackPosition + Vector3.new(0, 2, 0))
end

return EggOpeningConfig
