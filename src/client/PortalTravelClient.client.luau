local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local PortalTravel = IslandEvents:WaitForChild("PortalTravel")

local FADE_IN_TIME = 0.45
local FADE_OUT_TIME = 0.55
local DISPLAY_ORDER = 10000

local screenGui
local overlay
local isFaded = false

local function ensureOverlay()
	if screenGui and screenGui.Parent then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PortalTravelFade"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = DISPLAY_ORDER
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = true
	screenGui:SetAttribute("BypassTutorialLockout", true)
	screenGui.Parent = playerGui

	screenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if isFaded and not screenGui.Enabled then
			screenGui.Enabled = true
		end
	end)

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Position = UDim2.fromScale(0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 1
	overlay.Parent = screenGui

	local label = Instance.new("TextLabel")
	label.Name = "TravelLabel"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(280, 40)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = "Traveling..."
	label.TextColor3 = Color3.fromRGB(210, 230, 245)
	label.TextSize = 22
	label.TextTransparency = 1
	label.ZIndex = 2
	label.Parent = overlay
end

local function tweenOverlay(targetTransparency, duration, labelTransparency)
	ensureOverlay()

	local label = overlay:FindFirstChild("TravelLabel")
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local overlayTween = TweenService:Create(overlay, tweenInfo, { BackgroundTransparency = targetTransparency })
	overlayTween:Play()
	if label then
		TweenService:Create(label, tweenInfo, { TextTransparency = labelTransparency }):Play()
	end
	overlayTween.Completed:Wait()
end

local function playFadeIn()
	ensureOverlay()
	if isFaded then
		return
	end
	isFaded = true
	overlay.Visible = true
	tweenOverlay(0, FADE_IN_TIME, 0)
end

local function playArrivalBurst()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local portalEffect = player:GetAttribute("RebirthEquippedPortalEffect")
	local isStarfall = portalEffect == "StarfallPortal"

	local sound = Instance.new("Sound")
	sound.SoundId = isStarfall and "rbxassetid://12221990" or "rbxassetid://12221967"
	sound.Volume = 0.55
	sound.Parent = root
	sound:Play()
	task.delay(2, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)

	local burst = Instance.new("ParticleEmitter")
	burst.Name = "PortalArrivalBurst"
	burst.Texture = "rbxassetid://243660364"
	if isStarfall then
		burst.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 120)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 220, 255)),
		})
		burst.Lifetime = NumberRange.new(0.7, 1.3)
		burst.Speed = NumberRange.new(10, 20)
	else
		burst.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 240, 180))
		burst.Lifetime = NumberRange.new(0.5, 1)
		burst.Speed = NumberRange.new(8, 16)
	end
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isStarfall and 1.6 or 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 0.9
	burst.Parent = root
	burst:Emit(isStarfall and 42 or 28)
	task.delay(1.5, function()
		if burst.Parent then
			burst:Destroy()
		end
	end)
end

local function playFadeOut()
	ensureOverlay()
	if not isFaded then
		return
	end
	tweenOverlay(1, FADE_OUT_TIME, 1)
	overlay.Visible = false
	isFaded = false
	playArrivalBurst()
end

PortalTravel.OnClientEvent:Connect(function(phase)
	if phase == "fadeIn" then
		playFadeIn()
	elseif phase == "fadeOut" then
		playFadeOut()
	end
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered == player and prompt.Name == "PortalPrompt" then
		task.spawn(playFadeIn)
	end
end)
