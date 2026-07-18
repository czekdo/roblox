local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local IslandUnlockState = IslandEvents:WaitForChild("IslandUnlockState")
local IslandUnlockFeedback = IslandEvents:WaitForChild("IslandUnlockFeedback")

local player = Players.LocalPlayer
local unlockedSet = {}

local function formatNotify(message, color)
	if _G.DragonIslandNotify then
		_G.DragonIslandNotify(message, color)
	else
		warn("[IslandUnlockClient]", message)
	end
end

local function applyUnlockState(payload)
	unlockedSet = {}
	if typeof(payload) ~= "table" or typeof(payload.unlocked) ~= "table" then
		return
	end
	for _, islandId in payload.unlocked do
		unlockedSet[islandId] = true
	end
end

local function playUnlockEffects(position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local attachPart = root or character and character:FindFirstChildWhichIsA("BasePart")
	if not attachPart then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://12221967"
	sound.Volume = 0.65
	sound.Parent = attachPart
	sound:Play()
	task.delay(2, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "IslandUnlockBurst"
	burst.Texture = "rbxassetid://243660364"
	burst.Color = ColorSequence.new(IslandUnlockConfig.UnlockedColor, Theme.Colors.GoldBright)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 0.95
	burst.Parent = attachPart
	burst:Emit(36)
	task.delay(1.5, function()
		if burst.Parent then
			burst:Destroy()
		end
	end)

	if typeof(position) == "Vector3" then
		local beam = Instance.new("Part")
		beam.Name = "UnlockPulse"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.Material = Enum.Material.Neon
		beam.Color = IslandUnlockConfig.UnlockedColor
		beam.Size = Vector3.new(1, 1, 1)
		beam.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
		beam.Transparency = 0.2
		beam.Parent = workspace
		TweenService:Create(beam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(14, 14, 14),
			Transparency = 1,
		}):Play()
		task.delay(0.9, function()
			if beam.Parent then
				beam:Destroy()
			end
		end)
	end
end

IslandUnlockState.OnClientEvent:Connect(function(payload)
	applyUnlockState(payload)
end)

IslandUnlockFeedback.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local message = payload.message
	if typeof(message) == "string" and message ~= "" then
		local color = payload.success and Theme.Colors.Success or Theme.Colors.Danger
		formatNotify(message, color)
	end

	if payload.success and typeof(payload.islandId) == "string" then
		unlockedSet[payload.islandId] = true
		playUnlockEffects(payload.effectPosition or payload.shrinePosition)
	end
end)

print("[IslandUnlockClient] Island unlock feedback ready")