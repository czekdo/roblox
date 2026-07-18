local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local DragonAbilityConfig = require(ReplicatedStorage:WaitForChild("DragonAbilityConfig"))
local DragonAbilityLevelUp = ReplicatedStorage:WaitForChild("HarvestEvents"):WaitForChild("DragonAbilityLevelUp")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local levelUpGui
local activeTween

local function playLevelUpSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9125402735"
	sound.Volume = 0.55
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function spawnBurstParticles(parent, color)
	for index = 1, 10 do
		local particle = Instance.new("Frame")
		particle.Name = "Burst" .. index
		particle.Size = UDim2.fromOffset(8, 8)
		particle.Position = UDim2.fromScale(0.5, 0.5)
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.BackgroundColor3 = color
		particle.BorderSizePixel = 0
		particle.ZIndex = 80
		particle.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle

		local angle = (index / 10) * math.pi * 2
		local distance = math.random(40, 90)
		local target = UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance - 20)
		TweenService:Create(particle, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, target.X.Offset, 0.5, target.Y.Offset),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(4, 4),
		}):Play()
		task.delay(0.7, function()
			if particle.Parent then
				particle:Destroy()
			end
		end)
	end
end

local function ensureGui()
	if levelUpGui then
		return
	end

	levelUpGui = Instance.new("ScreenGui")
	levelUpGui.Name = "DragonAbilityLevelUpUI"
	levelUpGui.ResetOnSpawn = false
	levelUpGui.IgnoreGuiInset = true
	levelUpGui.DisplayOrder = 60
	levelUpGui.Enabled = true
	levelUpGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	levelUpGui.Parent = playerGui
end

local function showLevelUp(payload)
	if typeof(payload) ~= "table" then
		return
	end

	ensureGui()
	for _, child in levelUpGui:GetChildren() do
		child:Destroy()
	end

	local color = Theme.Colors.Crystal
	local speciesConfig = DragonAbilityConfig.GetSpeciesConfig(payload.speciesId)
	if speciesConfig and speciesConfig.HandlerId == "Inferno" then
		color = Color3.fromRGB(255, 120, 70)
	elseif speciesConfig and speciesConfig.HandlerId == "NaturesBlessing" then
		color = Color3.fromRGB(90, 210, 120)
	elseif speciesConfig and speciesConfig.HandlerId == "FrozenTouch" then
		color = Color3.fromRGB(120, 220, 255)
	end

	local card = Theme.createFrame({
		Name = "LevelUpCard", Parent = levelUpGui,
		Size = UDim2.fromOffset(360, 150), Position = UDim2.new(0.5, 0, 0.22, 0),
		AnchorPoint = Vector2.new(0.5, 0), Bg = Theme.Colors.StoneDark, Corner = Theme.Corner.Large, ZIndex = 70,
	})
	Theme.stroke(card, color, 2.5, 0.2)

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromOffset(42, 42)
	icon.Position = UDim2.fromOffset(16, 16)
	icon.BackgroundTransparency = 1
	icon.Image = Theme.Icons.Star
	icon.ImageColor3 = color
	icon.ZIndex = 71
	icon.Parent = card

	Theme.createText({
		Name = "Title", Parent = card, Text = "ABILITY LEVEL UP!",
		Size = UDim2.new(1, -70, 0, 22), Position = UDim2.fromOffset(64, 14),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = color, ZIndex = 71,
	})

	Theme.createText({
		Name = "AbilityName", Parent = card, Text = tostring(payload.abilityName or "Ability"),
		Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(16, 44),
		TextSize = 22, Font = Theme.Fonts.Title, Color = Theme.Colors.Text, ZIndex = 71,
	})

	Theme.createText({
		Name = "LevelLabel", Parent = card, Text = "Level " .. tostring(payload.abilityLevel or 1),
		Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(16, 76),
		TextSize = 16, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldDark, ZIndex = 71,
	})

	Theme.createText({
		Name = "ValueLabel", Parent = card, Text = tostring(payload.currentValueText or ""),
		Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(16, 104),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 71,
	})

	spawnBurstParticles(card, color)
	playLevelUpSound()

	card.Position = UDim2.new(0.5, 0, 0.16, 0)
	card.BackgroundTransparency = 1
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.22, 0),
		BackgroundTransparency = 0,
	})
	activeTween:Play()

	task.delay(3.2, function()
		if card.Parent then
			local fade = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.16, 0),
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Connect(function()
				if card.Parent then
					card:Destroy()
				end
			end)
		end
	end)

	if _G.DragonIslandNotify then
		_G.DragonIslandNotify(payload.abilityName .. " reached Level " .. tostring(payload.abilityLevel), color)
	end
end

DragonAbilityLevelUp.OnClientEvent:Connect(showLevelUp)
