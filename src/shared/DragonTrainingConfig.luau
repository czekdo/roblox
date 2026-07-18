local RunService = game:GetService("RunService")

local DragonTrainingConfig = {
	MaxConcurrentSessions = 3,
	MaxDragonLevel = 50,
	MaxDragonsPerSession = 1,
	StudioDurationMultiplier = 0.03,
	StudioMaxDuration = 8,
	ProgramOrder = { "Quick", "Standard", "Intensive" },
	Programs = {
		Quick = {
			Id = "Quick",
			DisplayName = "Quick Drill",
			Description = "Short warm-up session. Good for a fast level bump.",
			BaseDuration = 300,
			LevelReward = 1,
			EssenceReward = 25,
			EssenceCost = 0,
			Color = Color3.fromRGB(95, 185, 120),
		},
		Standard = {
			Id = "Standard",
			DisplayName = "Standard Course",
			Description = "Balanced academy training with solid rewards.",
			BaseDuration = 600,
			LevelReward = 2,
			EssenceReward = 60,
			EssenceCost = 50,
			Color = Color3.fromRGB(110, 165, 255),
		},
		Intensive = {
			Id = "Intensive",
			DisplayName = "Intensive Training",
			Description = "Long elite course with the biggest level gains.",
			BaseDuration = 900,
			LevelReward = 3,
			EssenceReward = 150,
			EssenceCost = 120,
			Color = Color3.fromRGB(210, 130, 255),
		},
	},
}

function DragonTrainingConfig.GetProgram(programId)
	return DragonTrainingConfig.Programs[programId]
end

function DragonTrainingConfig.GetEffectiveDuration(baseDuration, trainingTimeMultiplier)
	local duration = math.max(15, math.floor((tonumber(baseDuration) or 300) * (tonumber(trainingTimeMultiplier) or 1)))
	if RunService:IsStudio() then
		duration = math.max(6, math.floor(duration * DragonTrainingConfig.StudioDurationMultiplier))
		duration = math.min(DragonTrainingConfig.StudioMaxDuration or 8, duration)
	end
	return duration
end

return DragonTrainingConfig