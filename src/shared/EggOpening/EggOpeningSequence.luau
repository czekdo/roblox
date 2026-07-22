local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EggModelRegistry = require(script.Parent:WaitForChild("EggModelRegistry"))
local EggOpeningConfig = require(script.Parent:WaitForChild("EggOpeningConfig"))
local EggOpeningEffects = require(script.Parent:WaitForChild("EggOpeningEffects"))
local EggOpeningCamera = require(script.Parent:WaitForChild("EggOpeningCamera"))

local EggOpeningSequence = {}

-- The egg model settles at its own natural authored scale during the cinematic, which reads as
-- tiny on screen. This multiplies every scale value in the spawn/reveal phases below, so the egg
-- (and everything computed relative to it, like the reveal-phase scaleUp) is uniformly bigger
-- without changing the animation's shape/timing.
local EGG_DISPLAY_SCALE_BOOST = 1.8

local function tween(instance, info, goals)
	local tweenObj = TweenService:Create(instance, info, goals)
	tweenObj:Play()
	return tweenObj
end

local function waitFor(duration, controller)
	local elapsed = 0
	while elapsed < duration do
		if controller and controller:IsSkipped() then
			return true
		end
		elapsed += RunService.RenderStepped:Wait()
	end
	return controller and controller:IsSkipped() or false
end

local function hideWorldEgg(player, worldPosition)
	local eggsFolder = Workspace:FindFirstChild("DragonEggs")
	if not eggsFolder then
		return nil
	end

	local closestEgg = nil
	local closestDistance = 8
	for _, egg in eggsFolder:GetChildren() do
		if egg:GetAttribute("OwnerUserId") == player.UserId and egg:GetAttribute("Hatching") == true then
			local pos = egg:GetPivot().Position
			local distance = (pos - worldPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestEgg = egg
			end
		end
	end

	if closestEgg then
		for _, descendant in closestEgg:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 1
			elseif descendant:IsA("BillboardGui") then
				descendant.Enabled = false
			end
		end
	end

	return closestEgg
end

local function animatePivot(model, targetCFrame, duration, style, direction)
	local startCFrame = model:GetPivot()
	local alpha = Instance.new("NumberValue")
	alpha.Value = 0
	local connection
	connection = alpha.Changed:Connect(function(value)
		model:PivotTo(startCFrame:Lerp(targetCFrame, value))
	end)
	local tweenObj = tween(alpha, TweenInfo.new(duration, style or Enum.EasingStyle.Sine, direction or Enum.EasingDirection.InOut), {
		Value = 1,
	})
	tweenObj.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
end

local function runFloating(model, baseCFrame, duration, controller)
	local elapsed = 0
	local floatHeight = 1.4
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if controller and controller:IsSkipped() then
			return
		end
		elapsed += dt
		local bob = math.sin(elapsed * 1.8) * 0.22
		local sway = math.sin(elapsed * 0.9) * 0.08
		local spin = elapsed * 0.35
		model:PivotTo(baseCFrame * CFrame.new(sway, floatHeight + bob, 0) * CFrame.Angles(0, spin, 0))
	end)

	waitFor(duration, controller)
	connection:Disconnect()
end

local function runCuriosity(model, baseCFrame, duration, controller)
	local sequence = {
		{ tilt = math.rad(-12), hold = 0.35 },
		{ tilt = math.rad(12), hold = 0.35 },
		{ tilt = 0, hold = 0.25 },
		{ tilt = math.rad(-10), hold = 0.3 },
		{ tilt = math.rad(10), hold = 0.3 },
		{ tilt = 0, hold = 0.25 },
	}

	for _, step in sequence do
		if controller and controller:IsSkipped() then
			break
		end
		animatePivot(model, baseCFrame * CFrame.Angles(0, 0, step.tilt), 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		EggOpeningEffects.PlaySound("EggMove", 0.35, 1)
		waitFor(step.hold, controller)
	end

	waitFor(math.max(0, duration - 2.2), controller)
end

local function runBuildUp(model, baseCFrame, light, emitters, profile, duration, controller)
	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if controller and controller:IsSkipped() then
			return
		end
		elapsed += dt
		local progress = math.clamp(elapsed / duration, 0, 1)
		local shake = (0.03 + progress * 0.14) * profile.intensity
		local wobble = math.sin(elapsed * (8 + progress * 10)) * math.rad(4 + progress * 10)
		local offset = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake * 0.5, (math.random() - 0.5) * shake)
		model:PivotTo(baseCFrame * CFrame.new(offset) * CFrame.Angles(wobble, elapsed * 0.8, wobble * 0.5))
		if light then
			light.Brightness = 1.2 + progress * 2.8 * profile.glow
		end
		if emitters.dust then
			emitters.dust.Rate = 8 + progress * 18 * profile.particleScale
		end
		if emitters.sparkles then
			emitters.sparkles.Rate = 4 + progress * 12 * profile.particleScale
		end
	end)

	EggOpeningEffects.PlaySound("EggShake", 0.25, profile.soundPitch)
	waitFor(duration, controller)
	connection:Disconnect()
end

local function runCharge(model, baseCFrame, light, emitters, cameraController, profile, duration, controller)
	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if controller and controller:IsSkipped() then
			return
		end
		elapsed += dt
		local progress = math.clamp(elapsed / duration, 0, 1)
		local shake = (0.08 + progress * 0.22) * profile.intensity
		local bounce = math.abs(math.sin(elapsed * 18)) * 0.12
		local spin = elapsed * (2.5 + progress * 4)
		local offset = Vector3.new((math.random() - 0.5) * shake, bounce, (math.random() - 0.5) * shake)
		model:PivotTo(baseCFrame * CFrame.new(offset) * CFrame.Angles(0, spin, math.sin(elapsed * 14) * 0.12))
		if light then
			light.Brightness = 3.5 + math.sin(elapsed * 20) * 1.2 * profile.glow
		end
		if emitters.dust then
			emitters.dust.Rate = 24 * profile.particleScale
		end
		if emitters.sparkles then
			emitters.sparkles.Rate = 18 * profile.particleScale
		end
	end)

	cameraController:SetZoomStrength(1)
	cameraController:Shake(0.12 * profile.intensity, duration)
	EggOpeningEffects.PlaySound("EggCharge", 0.55, profile.soundPitch + 0.08)
	waitFor(duration, controller)
	connection:Disconnect()
end

local function runReveal(model, baseCFrame, light, burstEmitters, flashFrame, glowColor, profile, duration, controller)
	EggOpeningEffects.PlaySound("EggReveal", 0.75, profile.soundPitch + 0.1)

	if flashFrame then
		flashFrame.BackgroundColor3 = glowColor:Lerp(Color3.fromRGB(255, 255, 255), 0.55)
		flashFrame.BackgroundTransparency = 0.15
		tween(flashFrame, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
	end

	if light then
		light.Brightness = 8 * profile.glow
		EggOpeningEffects.FadeLight(light, 0, 0.8)
	end

	EggOpeningEffects.EmitReveal(burstEmitters, profile)

	local startScale = 1
	pcall(function()
		startScale = model:GetScale()
	end)

	local scaleUp = startScale * (1.2 + 0.15 * profile.intensity)
	pcall(function()
		model:ScaleTo(scaleUp)
	end)

	EggOpeningEffects.FadeModelTransparency(model, 1, 0.35)
	waitFor(0.18, controller)

	pcall(function()
		model:ScaleTo(startScale * 0.2)
	end)
	waitFor(math.max(0.2, duration - 0.35), controller)
end

function EggOpeningSequence.Play(context)
	local payload = context.payload
	local player = context.player
	local camera = context.camera
	local controller = context.controller
	local ui = context.ui

	local rarity = payload.rarity or "Common"
	local profile = EggOpeningConfig.GetProfile(rarity)
	local glowColor = payload.glowColor or Color3.fromRGB(255, 240, 180)
	local worldPosition = payload.worldPosition or Vector3.new()

	hideWorldEgg(player, worldPosition)

	local spawnCFrame = EggOpeningConfig.GetSpawnCFrame(worldPosition)
	local focusPosition = spawnCFrame.Position

	local eggModel = EggModelRegistry.CloneEgg(payload.eggType, payload.modelFolder)
	if not eggModel then
		warn("[EggOpeningSequence] Missing egg model for", payload.eggType)
		return false
	end

	local stageFolder = Workspace:FindFirstChild("EggOpeningStage")
	if not stageFolder then
		stageFolder = Instance.new("Folder")
		stageFolder.Name = "EggOpeningStage"
		stageFolder.Parent = Workspace
	end

	eggModel.Parent = stageFolder
	eggModel:PivotTo(spawnCFrame)

	local primaryPart = eggModel.PrimaryPart or eggModel:FindFirstChildWhichIsA("BasePart", true)
	if not primaryPart then
		eggModel:Destroy()
		return false
	end

	local light = EggOpeningEffects.CreateGlowLight(primaryPart, glowColor, 0.5, 10)
	local attachment = EggOpeningEffects.GetOrCreateAttachment(primaryPart)
	local ambientEmitters = EggOpeningEffects.AttachAmbientParticles(attachment, glowColor, profile)
	local burstEmitters = EggOpeningEffects.AttachBurstParticles(attachment, glowColor, profile)

	local cameraController = EggOpeningCamera.new(camera)
	cameraController:Begin(focusPosition, profile)

	local baseCFrame = spawnCFrame
	local skipped = false

	-- Phase 1: Spawn
	EggOpeningEffects.FadeModelTransparency(eggModel, 0.85, 0)
	pcall(function()
		eggModel:ScaleTo(0.8 * EGG_DISPLAY_SCALE_BOOST)
	end)
	EggOpeningEffects.PlaySound("EggAppear", 0.45, profile.soundPitch)
	EggOpeningEffects.FadeModelTransparency(eggModel, 0, 0.55)
	pcall(function()
		tween(eggModel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {})
	end)

	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = 0.8 * EGG_DISPLAY_SCALE_BOOST
	local scaleConnection
	scaleConnection = scaleValue.Changed:Connect(function(value)
		pcall(function()
			eggModel:ScaleTo(value)
		end)
	end)
	tween(scaleValue, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1.05 * EGG_DISPLAY_SCALE_BOOST })
	tween(scaleValue, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 * EGG_DISPLAY_SCALE_BOOST })
	if ambientEmitters.dust then
		ambientEmitters.dust:Emit(math.floor(8 * profile.particleScale))
	end
	skipped = waitFor(EggOpeningConfig.GetPhaseDuration("Spawn", profile), controller)
	scaleConnection:Disconnect()
	scaleValue:Destroy()

	-- Phase 2: Floating
	EggOpeningEffects.PlaySound("EggFloat", 0.22, profile.soundPitch)
	runFloating(eggModel, baseCFrame, EggOpeningConfig.GetPhaseDuration("Float", profile), controller)

	-- Phase 3: Curiosity
	runCuriosity(eggModel, eggModel:GetPivot(), EggOpeningConfig.GetPhaseDuration("Curiosity", profile), controller)

	-- Phase 4: Build-up
	runBuildUp(eggModel, eggModel:GetPivot(), light, ambientEmitters, profile, EggOpeningConfig.GetPhaseDuration("BuildUp", profile), controller)

	-- Phase 5: Charge
	runCharge(eggModel, eggModel:GetPivot(), light, ambientEmitters, cameraController, profile, EggOpeningConfig.GetPhaseDuration("Charge", profile), controller)

	-- Phase 6: Reveal
	runReveal(eggModel, eggModel:GetPivot(), light, burstEmitters, ui and ui.flashFrame, glowColor, profile, EggOpeningConfig.GetPhaseDuration("Reveal", profile), controller)

	-- Phase 7: Reward
	if ui and ui.showReward then
		ui.showReward(payload, profile, controller)
		waitFor(profile.rewardHold or EggOpeningConfig.GetPhaseDuration("Reward", profile), controller)
	end

	cameraController:End()
	eggModel:Destroy()

	return true
end

return EggOpeningSequence
