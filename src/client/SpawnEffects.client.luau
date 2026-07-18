local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local FallRespawn = IslandEvents:WaitForChild("FallRespawn")
local IslandExpansionPurchased = IslandEvents:WaitForChild("IslandExpansionPurchased")

local DEFAULT_FOV = 70
local KICK_FOV = 90

local function playSpawnFOVKick()
	if not camera then
		return
	end

	camera.FieldOfView = KICK_FOV
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = DEFAULT_FOV }
	)
	tween:Play()
end

local function playFallBlur()
	local blur = Instance.new("BlurEffect")
	blur.Name = "FallBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local tweenIn = TweenService:Create(blur, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = 24,
	})
	tweenIn:Play()
	tweenIn.Completed:Wait()

	task.wait(0.25)

	local tweenOut = TweenService:Create(blur, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = 0,
	})
	tweenOut:Play()
	tweenOut.Completed:Wait()
	blur:Destroy()
end

local function playExpansionConstruction(area)
	if typeof(area) ~= "Instance" or not area:IsA("BasePart") then
		return
	end

	local finalSize = area.Size
	local finalCFrame = area.CFrame
	area.Transparency = 0.65
	area.Material = Enum.Material.Neon
	area.Color = Color3.fromRGB(115, 230, 255)
	area.Size = Vector3.new(finalSize.X, 0.2, finalSize.Z)
	area.CFrame = finalCFrame - Vector3.new(0, finalSize.Y * 0.5, 0)

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "ConstructionDust"
	dust.Color = ColorSequence.new(Color3.fromRGB(165, 235, 255), Color3.fromRGB(255, 255, 255))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.7, 1.2)
	dust.Rate = 26
	dust.Speed = NumberRange.new(3, 7)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.LightEmission = 0.35
	dust.Parent = area

	local riseTween = TweenService:Create(area, TweenInfo.new(2.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = finalSize,
		CFrame = finalCFrame,
		Transparency = 0.12,
	})
	riseTween:Play()
	riseTween.Completed:Wait()

	local settleTween = TweenService:Create(area, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0,
		Color = Color3.fromRGB(86, 170, 82),
	})
	settleTween:Play()
	dust.Rate = 0
	task.delay(1.2, function()
		if dust.Parent then
			dust:Destroy()
		end
		if area.Parent then
			area.Material = Enum.Material.Grass
		end
	end)
end

player.CharacterAdded:Connect(function()
	task.wait(0.15)
	playSpawnFOVKick()
end)

FallRespawn.OnClientEvent:Connect(playFallBlur)
IslandExpansionPurchased.OnClientEvent:Connect(function(area)
	task.spawn(playExpansionConstruction, area)
end)

if player.Character then
	task.defer(playSpawnFOVKick)
end
