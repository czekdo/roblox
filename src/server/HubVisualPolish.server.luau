local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubVisualConfig = require(ReplicatedStorage:WaitForChild("HubVisualConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))

local COLORS = HubVisualConfig.Colors
local HUB_CENTER = HubVisualConfig.HubCenter
local PROMPT_HEIGHT = HubVisualConfig.PromptHeight or 3

local polishFolder
local ambienceFolder

local function tagEffect(instance)
	instance:SetAttribute("HubPolishEffect", true)
	CollectionService:AddTag(instance, "HubPolishEffect")
end

local function makeAnchor(parent, name, cframe, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size or Vector3.new(1, 1, 1)
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function getGroundRaycastFilter()
	local include = {}
	local hub = WorkspaceLayout.GetHub()
	if hub then
		table.insert(include, hub)
	end
	for _, modelName in { "QuestHall", "DailyRewardsShrine", "TradingPlaza", "LeaderboardMonument" } do
		local model = workspace:FindFirstChild(modelName)
		if model then
			table.insert(include, model)
		end
	end
	return include
end

local function raycastGround(position)
	local include = getGroundRaycastFilter()
	if #include == 0 then
		return position
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = include

	local origin = position + Vector3.new(0, 24, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -120, 0), rayParams)
	if result then
		return result.Position
	end
	return position
end

local function raycastHubSurface(position)
	return raycastGround(position)
end

local function getBuildingAnchors(model)
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local flatCenter = Vector3.new(pivot.Position.X, pivot.Position.Y, pivot.Position.Z)
	local toHub = Vector3.new(HUB_CENTER.X, flatCenter.Y, HUB_CENTER.Z) - flatCenter
	if toHub.Magnitude < 0.1 then
		toHub = Vector3.new(0, 0, -1)
	else
		toHub = Vector3.new(toHub.X, 0, toHub.Z).Unit
	end

	local entrance = flatCenter + toHub * math.max(4, size.Z * 0.22)
	entrance = raycastHubSurface(entrance) + Vector3.new(0, 1.2, 0)
	local top = flatCenter + Vector3.new(0, math.max(8, size.Y * 0.45), 0)
	local faceCFrame = CFrame.lookAt(entrance, Vector3.new(HUB_CENTER.X, entrance.Y, HUB_CENTER.Z))

	return {
		Entrance = entrance,
		Top = top,
		Face = faceCFrame,
		ToHub = toHub,
		Size = size,
	}
end

local function addSparkles(parent, rate, colorSequence)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = "rbxassetid://243660364"
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2.2)
	emitter.Speed = NumberRange.new(0.4, 1.6)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.LightEmission = 0.85
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Color = colorSequence or ColorSequence.new(COLORS.GoldBright, COLORS.Crystal)
	emitter.Parent = parent
	tagEffect(emitter)
	return emitter
end

local function addPointLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Parent = parent
	tagEffect(light)
	return light
end

local function addSpotLight(parent, color, brightness, range, faceCFrame)
	local light = Instance.new("SpotLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Angle = 40
	light.Face = Enum.NormalId.Front
	light.Parent = parent
	if faceCFrame then
		parent.CFrame = faceCFrame
	end
	tagEffect(light)
	return light
end

local function addAmbientSound(parent, soundId, volume, maxDistance)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMaxDistance = maxDistance or 55
	sound.RollOffMinDistance = 8
	sound.Parent = parent
	sound:Play()
	tagEffect(sound)
	return sound
end

local function addProximityPrompt(anchor, promptConfig)
	if anchor:FindFirstChild("HubPolishPrompt") then
		return anchor:FindFirstChild("HubPolishPrompt")
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPolishPrompt"
	prompt.ActionText = promptConfig.ActionText
	prompt.ObjectText = promptConfig.ObjectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return prompt
end

local function getInteractionRaycastFilter()
	local include = {}
	local hub = WorkspaceLayout.GetHub()
	if hub then
		table.insert(include, hub)
	end
	for _, modelName in { "QuestHall", "DailyRewardsShrine", "TradingPlaza", "LeaderboardMonument" } do
		local model = workspace:FindFirstChild(modelName)
		if model then
			table.insert(include, model)
		end
	end
	return include
end

local function snapAnchorToGround(position)
	local include = getInteractionRaycastFilter()
	if #include == 0 then
		return position
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = include

	local origin = position + Vector3.new(0, 24, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -120, 0), rayParams)
	if result and result.Normal.Y > 0.7 then
		return Vector3.new(position.X, result.Position.Y + PROMPT_HEIGHT, position.Z)
	end
	return position
end

local function validateInteractionAnchor(anchor, model)
	local pos = anchor.Position
	local issues = {}

	local include = getInteractionRaycastFilter()
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = include
	local groundResult = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), rayParams)
	local groundY = groundResult and groundResult.Position.Y or (pos.Y - PROMPT_HEIGHT)

	if pos.Y - groundY > PROMPT_HEIGHT + 2 then
		table.insert(issues, "too_high_above_ground")
	end
	if pos.Y < groundY - 0.5 then
		table.insert(issues, "below_ground")
	end

	local pivot = model:GetPivot().Position
	local _, size = model:GetBoundingBox()
	local roofY = pivot.Y + size.Y * 0.4
	if pos.Y > roofY then
		table.insert(issues, "above_roof")
	end

	local flatCenter = Vector3.new(pivot.X, pos.Y, pivot.Z)
	local toHub = Vector3.new(HUB_CENTER.X - flatCenter.X, 0, HUB_CENTER.Z - flatCenter.Z)
	if toHub.Magnitude > 0.1 then
		toHub = toHub.Unit
		local toAnchor = Vector3.new(pos.X - flatCenter.X, 0, pos.Z - flatCenter.Z)
		if toAnchor.Magnitude > 0.5 and toAnchor.Unit:Dot(toHub) < 0.2 then
			table.insert(issues, "behind_building")
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { model }
	local overlapping = workspace:GetPartBoundsInRadius(pos, 1.2, overlapParams)
	for _, part in overlapping do
		if part:IsA("BasePart") and part ~= anchor and not part:IsDescendantOf(anchor) then
			local localPos = part.CFrame:PointToObjectSpace(pos)
			local halfSize = part.Size * 0.5
			if math.abs(localPos.X) < halfSize.X * 0.85
				and math.abs(localPos.Y) < halfSize.Y * 0.85
				and math.abs(localPos.Z) < halfSize.Z * 0.85 then
				table.insert(issues, "inside_geometry")
				break
			end
		end
	end

	if #issues > 0 then
		local fixed = snapAnchorToGround(pos)
		anchor.CFrame = CFrame.new(fixed)
		warn("[HubVisualPolish] InteractionAnchor adjusted for", model.Name, "(" .. table.concat(issues, ", ") .. ")")
	end

	return #issues == 0
end

local function createInteractionAnchor(model, config)
	local existing = model:FindFirstChild("InteractionAnchor")
	if existing then
		existing:Destroy()
	end

	local anchorPosition = config.InteractionPosition
	if not anchorPosition then
		warn("[HubVisualPolish] Missing InteractionPosition for", model.Name)
		return nil
	end

	local anchor = Instance.new("Part")
	anchor.Name = "InteractionAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(anchorPosition)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = model

	validateInteractionAnchor(anchor, model)
	addProximityPrompt(anchor, config.Prompt)
	return anchor
end

local function createPortalInteractionAnchor(portalModel, position)
	local existing = portalModel:FindFirstChild("InteractionAnchor")
	if existing then
		existing:Destroy()
	end

	local anchor = Instance.new("Part")
	anchor.Name = "InteractionAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = portalModel

	return anchor
end

local function addRotatingBeam(parent, cframe, color)
	local beamPart = makeAnchor(parent, "LightBeam", cframe, Vector3.new(0.2, 0.2, 0.2))
	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, 0, 0)
	attachment0.Parent = beamPart
	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, 10, 0)
	attachment1.Parent = beamPart

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Color = ColorSequence.new(color or COLORS.GoldBright)
	beam.LightEmission = 0.9
	beam.LightInfluence = 0.2
	beam.Transparency = NumberSequence.new(0.35)
	beam.Width0 = 0.35
	beam.Width1 = 0.05
	beam.FaceCamera = true
	beam.Parent = beamPart
	tagEffect(beam)

	task.spawn(function()
		while beamPart.Parent do
			beamPart.CFrame = cframe * CFrame.Angles(0, math.rad((os.clock() * 45) % 360), 0)
			RunService.Heartbeat:Wait()
		end
	end)

	return beamPart
end

local function polishQuestHall(_model, effectsFolder, anchors)
	local entrance = makeAnchor(effectsFolder, "Entrance", anchors.Face + Vector3.new(0, 2.5, 0), Vector3.new(3, 5, 1))
	addPointLight(entrance, COLORS.Warm, 0.9, 14)
	addSparkles(entrance, 3, ColorSequence.new(COLORS.Magic, COLORS.GoldBright))
	addAmbientSound(entrance, "rbxassetid://12222030", 0.08, 38)
end

local function polishDailyRewards(_model, effectsFolder, anchors)
	local shrine = makeAnchor(effectsFolder, "ShrineCore", CFrame.new(anchors.Top), Vector3.new(1, 1, 1))
	shrine:SetAttribute("ShrineCore", true)
	addPointLight(shrine, COLORS.GoldBright, 1.1, 16)
	addSparkles(shrine, 5, ColorSequence.new(COLORS.GoldBright, COLORS.Crystal))
	addRotatingBeam(effectsFolder, CFrame.new(anchors.Top + Vector3.new(0, 0.5, 0)), COLORS.GoldBright)

	local altar = makeAnchor(effectsFolder, "AltarEffects", anchors.Face + Vector3.new(0, 2, 0), Vector3.new(3, 3, 3))
	addAmbientSound(altar, "rbxassetid://12222030", 0.09, 36)
end

local function polishTradingPlaza(_model, effectsFolder, anchors)
	local stall = makeAnchor(effectsFolder, "MarketEffects", CFrame.new(anchors.Entrance + Vector3.new(0, 2, 0)), Vector3.new(4, 4, 4))
	addAmbientSound(stall, "rbxassetid://12222216", 0.1, 42)
end

local function polishLeaderboard(_model, effectsFolder, anchors)
	local podium = makeAnchor(effectsFolder, "MonumentTop", CFrame.new(anchors.Top), Vector3.new(1, 1, 1))
	addPointLight(podium, COLORS.GoldBright, 0.9, 18)
	addSparkles(podium, 3, ColorSequence.new(COLORS.GoldBright, COLORS.Gold))

	local spotPart = makeAnchor(effectsFolder, "Spotlight", anchors.Face * CFrame.new(0, 8, 6) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(1, 1, 1))
	addSpotLight(spotPart, COLORS.GoldBright, 1.4, 24)
end

local function polishBuilding(buildingKey, config, polisher)
	local model = workspace:FindFirstChild(config.ModelName)
	if not model or not model:IsA("Model") then
		warn("[HubVisualPolish] Missing building:", config.ModelName)
		return
	end

	createInteractionAnchor(model, config)

	local existing = model:FindFirstChild("VisualPolish")
	if existing then
		existing:Destroy()
	end

	local effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "VisualPolish"
	effectsFolder.Parent = model

	local anchors = getBuildingAnchors(model)
	polisher(model, effectsFolder, anchors)

	if config.IndicatorKind then
		local indicatorAnchor = makeAnchor(effectsFolder, "IndicatorAnchor", CFrame.new(anchors.Top + Vector3.new(0, 4, 0)), Vector3.new(1, 1, 1))
		indicatorAnchor:SetAttribute("IndicatorKind", config.IndicatorKind)
		indicatorAnchor:SetAttribute("BuildingKey", buildingKey)
	end
end

local function addPortalSwirl(portalModel)
	local pivot = portalModel:GetPivot()
	local _, size = portalModel:GetBoundingBox()

	local core = makeAnchor(portalModel, "PortalCore", pivot, Vector3.new(math.max(4, size.X * 0.35), math.max(6, size.Y * 0.5), 0.6))
	core.Material = Enum.Material.Neon
	core.Color = COLORS.Portal
	core.Transparency = 0.45
	tagEffect(core)

	addPointLight(core, COLORS.Portal, 1.8, 22)
	addSparkles(core, 12, ColorSequence.new(COLORS.Portal, COLORS.GoldBright))

	local hum = addAmbientSound(core, "rbxassetid://12222216", 0.18, 36)
	hum.Name = "PortalHum"

	local baseTransparency = 0.45
	task.spawn(function()
		while core.Parent do
			local t = os.clock()
			core.Transparency = baseTransparency + math.sin(t * 2.4) * 0.12
			core.CFrame = pivot * CFrame.Angles(0, math.rad((t * 60) % 360), 0)
			RunService.Heartbeat:Wait()
		end
	end)

	local rim = makeAnchor(portalModel, "PortalRim", pivot * CFrame.new(0, 0, 0.2), Vector3.new(math.max(5, size.X * 0.42), math.max(7, size.Y * 0.55), 0.15))
	rim.Material = Enum.Material.Neon
	rim.Color = COLORS.CrystalDeep
	rim.Transparency = 0.65
	tagEffect(rim)
end

local function polishAllPortals()
	local portalAnchors = HubVisualConfig.PortalInteractionAnchors or {}

	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and (child.Name == "HubPortal" or child.Name == "MainIslandPortal" or child.Name:match("^HubPortal%d+$")) then
			if child:FindFirstChild("PortalCore") then
				child.PortalCore:Destroy()
			end
			if child:FindFirstChild("PortalRim") then
				child.PortalRim:Destroy()
			end

			local anchorPosition = portalAnchors[child.Name]
			if anchorPosition then
				createPortalInteractionAnchor(child, anchorPosition)
			end

			addPortalSwirl(child)
		end
	end
end

local function createHubAmbience()
	local hub = WorkspaceLayout.GetHub()
	if not hub then
		return
	end

	local hubPivot = hub:GetPivot().Position
	local center = Vector3.new(hubPivot.X, hubPivot.Y + 30, hubPivot.Z)

	local windAnchor = makeAnchor(ambienceFolder, "WindZone", CFrame.new(center), Vector3.new(100, 30, 100))
	local wind = Instance.new("ParticleEmitter")
	wind.Name = "WindMotes"
	wind.Texture = "rbxassetid://243660364"
	wind.Rate = 3
	wind.Lifetime = NumberRange.new(4, 6)
	wind.Speed = NumberRange.new(1.5, 3)
	wind.SpreadAngle = Vector2.new(180, 20)
	wind.EmissionDirection = Enum.NormalId.Top
	wind.Color = ColorSequence.new(Color3.fromRGB(220, 230, 245))
	wind.Transparency = NumberSequence.new(0.7)
	wind.Size = NumberSequence.new(0.12)
	wind.LightEmission = 0.15
	wind.Parent = windAnchor
	tagEffect(wind)

	local fireflyAnchor = makeAnchor(ambienceFolder, "FireflyZone", CFrame.new(center + Vector3.new(0, 4, 0)), Vector3.new(100, 16, 100))
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Fireflies"
	fireflies.Texture = "rbxassetid://243660364"
	fireflies.Rate = 0
	fireflies.Lifetime = NumberRange.new(2, 3.5)
	fireflies.Speed = NumberRange.new(0.4, 1)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Color = ColorSequence.new(COLORS.GoldBright)
	fireflies.LightEmission = 0.9
	fireflies.Size = NumberSequence.new(0.14)
	fireflies.Parent = fireflyAnchor
	tagEffect(fireflies)
	fireflies:SetAttribute("NightOnly", true)

	if not Lighting:FindFirstChild("HubBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "HubBloom"
		bloom.Intensity = 0.25
		bloom.Size = 16
		bloom.Threshold = 1.2
		bloom.Parent = Lighting
	end
end

local function setup()
	local existing = workspace:FindFirstChild("HubVisualPolish")
	if existing then
		existing:Destroy()
	end

	polishFolder = Instance.new("Folder")
	polishFolder.Name = "HubVisualPolish"
	polishFolder.Parent = workspace

	ambienceFolder = Instance.new("Folder")
	ambienceFolder.Name = "HubAmbience"
	ambienceFolder.Parent = polishFolder

	polishBuilding("QuestHall", HubVisualConfig.Buildings.QuestHall, polishQuestHall)
	polishBuilding("DailyRewardsShrine", HubVisualConfig.Buildings.DailyRewardsShrine, polishDailyRewards)
	polishBuilding("TradingPlaza", HubVisualConfig.Buildings.TradingPlaza, polishTradingPlaza)
	polishBuilding("LeaderboardMonument", HubVisualConfig.Buildings.LeaderboardMonument, polishLeaderboard)

	polishAllPortals()
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") and (child.Name == "HubPortal" or child.Name == "MainIslandPortal" or child.Name:match("^HubPortal%d+$")) then
			task.defer(function()
				if not child:FindFirstChild("PortalCore") then
					addPortalSwirl(child)
				end
			end)
		end
	end)

	createHubAmbience()
end

setup()
print("[HubVisualPolish] Hub atmosphere ready")
