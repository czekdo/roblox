local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local EggOpeningConfig = require(script.Parent:WaitForChild("EggOpeningConfig"))

local EggOpeningEffects = {}

local function tween(instance, info, goals)
	local tweenObj = TweenService:Create(instance, info, goals)
	tweenObj:Play()
	return tweenObj
end

function EggOpeningEffects.PlaySound(soundName, volume, pitch)
	local sound = Instance.new("Sound")
	sound.Name = "EggOpeningSound"
	sound.SoundId = EggOpeningConfig.SoundIds[soundName] or EggOpeningConfig.SoundIds.EggReveal
	sound.Volume = volume or 0.55
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, math.max(2, sound.TimeLength + 0.35))
	return sound
end

function EggOpeningEffects.GetOrCreateAttachment(parentPart)
	local attachment = parentPart:FindFirstChild("EggOpeningAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	attachment = Instance.new("Attachment")
	attachment.Name = "EggOpeningAttachment"
	attachment.Parent = parentPart
	return attachment
end

function EggOpeningEffects.CreateGlowLight(parentPart, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = "EggOpeningLight"
	light.Color = color
	light.Brightness = brightness or 1.5
	light.Range = range or 12
	light.Parent = parentPart
	return light
end

local function createEmitter(attachment, config)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = config.Name
	emitter.Color = config.Color
	emitter.Size = config.Size
	emitter.Lifetime = config.Lifetime
	emitter.Rate = config.Rate or 0
	emitter.Speed = config.Speed
	emitter.SpreadAngle = config.SpreadAngle or Vector2.new(180, 180)
	emitter.LightEmission = config.LightEmission or 0.85
	emitter.LightInfluence = 0
	emitter.Transparency = config.Transparency or NumberSequence.new(0.1, 1)
	emitter.Drag = config.Drag or 1.5
	emitter.RotSpeed = config.RotSpeed or NumberRange.new(-40, 40)
	emitter.Parent = attachment
	return emitter
end

function EggOpeningEffects.AttachAmbientParticles(attachment, color, profile)
	local scale = profile.particleScale or 1
	local dust = createEmitter(attachment, {
		Name = "MagicDust",
		Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18 * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.7, 1.4),
		Rate = 10 * scale,
		Speed = NumberRange.new(0.4, 1.4),
		SpreadAngle = Vector2.new(120, 120),
	})

	local sparkles = createEmitter(attachment, {
		Name = "Sparkles",
		Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12 * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.35, 0.8),
		Rate = 6 * scale,
		Speed = NumberRange.new(0.8, 2.2),
		SpreadAngle = Vector2.new(90, 90),
	})

	return {
		dust = dust,
		sparkles = sparkles,
	}
end

function EggOpeningEffects.AttachBurstParticles(attachment, color, profile)
	local scale = profile.particleScale or 1
	local burst = createEmitter(attachment, {
		Name = "RevealBurst",
		Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255)),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1 * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.35, 1.0),
		Rate = 0,
		Speed = NumberRange.new(8, 18),
		SpreadAngle = Vector2.new(180, 180),
	})

	local smoke = createEmitter(attachment, {
		Name = "RevealSmoke",
		Color = ColorSequence.new(Color3.fromRGB(220, 220, 255), color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8 * scale),
			NumberSequenceKeypoint.new(1, 1.6 * scale),
		}),
		Lifetime = NumberRange.new(0.5, 1.1),
		Rate = 0,
		Speed = NumberRange.new(2, 6),
		Transparency = NumberSequence.new(0.35, 1),
		Drag = 2.5,
	})

	local rays = createEmitter(attachment, {
		Name = "LightRays",
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), color),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25 * scale),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.25, 0.6),
		Rate = 0,
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(35, 35),
	})

	return {
		burst = burst,
		smoke = smoke,
		rays = rays,
	}
end

function EggOpeningEffects.SetEmitterRate(emitters, multiplier)
	for _, emitter in emitters do
		if emitter:IsA("ParticleEmitter") then
			emitter.Rate = math.max(0, emitter.Rate * multiplier)
		elseif typeof(emitter) == "table" then
			EggOpeningEffects.SetEmitterRate(emitter, multiplier)
		end
	end
end

function EggOpeningEffects.EmitReveal(emitters, profile)
	local scale = profile.particleScale or 1
	if emitters.burst then
		emitters.burst:Emit(math.floor(28 * scale))
	end
	if emitters.smoke then
		emitters.smoke:Emit(math.floor(14 * scale))
	end
	if emitters.rays then
		emitters.rays:Emit(math.floor(20 * scale))
	end
end

function EggOpeningEffects.FadeLight(light, targetBrightness, duration)
	if not light then
		return
	end
	tween(light, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = targetBrightness,
	})
end

function EggOpeningEffects.FadeModelTransparency(model, targetTransparency, duration)
	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	for _, part in parts do
		tween(part, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = math.clamp(targetTransparency, 0, 1),
		})
	end
end

function EggOpeningEffects.SetModelScale(model, scale)
	local ok = pcall(function()
		model:ScaleTo(scale)
	end)
	if not ok and model.PrimaryPart then
		model:PivotTo(model:GetPivot())
	end
end

function EggOpeningEffects.Destroy(instance)
	if instance and instance.Parent then
		instance:Destroy()
	end
end

return EggOpeningEffects
