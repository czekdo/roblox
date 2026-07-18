local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))

local HUB_CENTER = Vector3.new(1000, -44, -56)

local COLORS = {
	Stone = Color3.fromRGB(163, 162, 165),
	StoneDark = Color3.fromRGB(118, 112, 108),
	Gold = Color3.fromRGB(218, 175, 70),
	Crystal = Color3.fromRGB(90, 200, 220),
	CrystalDeep = Color3.fromRGB(55, 140, 175),
	Wood = Color3.fromRGB(139, 90, 55),
	WoodDark = Color3.fromRGB(95, 58, 32),
	Banner = Color3.fromRGB(52, 128, 118),
	BannerAccent = Color3.fromRGB(120, 60, 160),
	Roof = Color3.fromRGB(88, 72, 62),
	Glow = Color3.fromRGB(255, 220, 140),
}

local SPOT_NAMES = {
	Leaderboards = "HubSpot1",
	TradingPlaza = "HubSpot2",
	DailyRewards = "HubSpot3",
	QuestHall = "HubSpot4",
}

local function getHubSurfaceCFrame(spotPart: BasePart): CFrame
	local hub = WorkspaceLayout.GetHub()
	local sample = spotPart.Position

	if hub then
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = { hub }

		local origin = sample + Vector3.new(0, 16, 0)
		local result = workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
		if result then
			sample = result.Position
		end
	end

	local flatCenter = Vector3.new(sample.X, sample.Y, sample.Z)
	local lookTarget = Vector3.new(HUB_CENTER.X, flatCenter.Y, HUB_CENTER.Z)
	return CFrame.lookAt(flatCenter, lookTarget)
end

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, opts)
	opts = opts or {}

	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = opts.canCollide ~= false
	part.CastShadow = true

	if opts.transparency then
		part.Transparency = opts.transparency
	end

	part.Parent = parent
	return part
end

local function addSign(parent: Instance, text: string)
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(10, 3.5, 0.4)
	sign.Anchored = true
	sign.CanCollide = false
	sign.Color = COLORS.WoodDark
	sign.Material = Enum.Material.Wood
	sign.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(24, 20, 32)
	label.TextColor3 = COLORS.Glow
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Gold
	stroke.Thickness = 2
	stroke.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return sign
end

local function addPrompt(anchor: BasePart, actionText: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return prompt
end

local function addCrystal(parent: Instance, name: string, cframe: CFrame, size: Vector3)
	local crystal = makePart(parent, name, size, cframe, COLORS.Crystal, Enum.Material.Neon, {
		canCollide = false,
	})

	local light = Instance.new("PointLight")
	light.Color = COLORS.Crystal
	light.Brightness = 1.2
	light.Range = 10
	light.Parent = crystal

	return crystal
end

local function buildLeaderboards(root: Model, baseCFrame: CFrame)
	local platform = makePart(root, "Platform", Vector3.new(18, 1, 18), baseCFrame * CFrame.new(0, 0.5, 0), COLORS.StoneDark, Enum.Material.Cobblestone)

	makePart(root, "GoldRing", Vector3.new(16.5, 0.35, 16.5), baseCFrame * CFrame.new(0, 1.05, 0), COLORS.Gold, Enum.Material.Metal)

	makePart(root, "Pillar", Vector3.new(3.2, 11, 3.2), baseCFrame * CFrame.new(0, 6.5, 0), COLORS.Stone, Enum.Material.Slate)

	makePart(root, "Cap", Vector3.new(4.8, 1.2, 4.8), baseCFrame * CFrame.new(0, 12.4, 0), COLORS.Gold, Enum.Material.Metal)

	addCrystal(root, "TopCrystal", baseCFrame * CFrame.new(0, 13.6, 0), Vector3.new(2.2, 3.6, 2.2))

	for index = 1, 3 do
		local angle = math.rad((index - 2) * 55)
		local offset = CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -6.8)
		local tablet = makePart(root, "Tablet" .. index, Vector3.new(4.2, 5.6, 0.5), baseCFrame * offset * CFrame.new(0, 4.2, 0), COLORS.StoneDark, Enum.Material.Slate, { canCollide = false })
		tablet.Color = Color3.fromRGB(78, 74, 82)

		makePart(root, "RankPlate" .. index, Vector3.new(3.4, 0.8, 0.2), tablet.CFrame * CFrame.new(0, 1.8, -0.35), COLORS.Gold, Enum.Material.Metal, { canCollide = false })

		makePart(root, "Slot" .. index, Vector3.new(3, 2.4, 0.15), tablet.CFrame * CFrame.new(0, 0.2, -0.35), COLORS.CrystalDeep, Enum.Material.Glass, {
			canCollide = false,
			transparency = 0.25,
		})
	end

	local sign = addSign(root, "Leaderboards")
	sign.CFrame = baseCFrame * CFrame.new(0, 3.2, -9.6)

	addPrompt(platform, "View", "Leaderboards")
end

local function buildTradingPlaza(root: Model, baseCFrame: CFrame)
	local floor = makePart(root, "Floor", Vector3.new(20, 0.6, 20), baseCFrame * CFrame.new(0, 0.3, 0), COLORS.StoneDark, Enum.Material.Cobblestone)

	local postOffsets = {
		Vector3.new(-7.5, 0, -7.5),
		Vector3.new(7.5, 0, -7.5),
		Vector3.new(-7.5, 0, 7.5),
		Vector3.new(7.5, 0, 7.5),
	}

	for index, offset in postOffsets do
		makePart(root, "Post" .. index, Vector3.new(0.9, 7.2, 0.9), baseCFrame * CFrame.new(offset + Vector3.new(0, 3.9, 0)), COLORS.Wood, Enum.Material.Wood)
	end

	makePart(root, "Canopy", Vector3.new(17.5, 0.5, 17.5), baseCFrame * CFrame.new(0, 7.8, 0), COLORS.Banner, Enum.Material.Fabric, { canCollide = false })

	makePart(root, "CanopyTrim", Vector3.new(18.2, 0.25, 18.2), baseCFrame * CFrame.new(0, 7.45, 0), COLORS.Gold, Enum.Material.Metal, { canCollide = false })

	local counter = makePart(root, "Counter", Vector3.new(10, 1.2, 3.2), baseCFrame * CFrame.new(0, 1.2, 1.2), COLORS.WoodDark, Enum.Material.Wood)

	makePart(root, "CounterTop", Vector3.new(10.4, 0.25, 3.6), counter.CFrame * CFrame.new(0, 0.72, 0), COLORS.Wood, Enum.Material.WoodPlanks)

	makePart(root, "Chest", Vector3.new(2.4, 1.6, 1.8), baseCFrame * CFrame.new(2.8, 1.4, -2.2), COLORS.WoodDark, Enum.Material.Wood)
	makePart(root, "ChestLid", Vector3.new(2.5, 0.5, 1.9), baseCFrame * CFrame.new(2.8, 2.35, -2.2), COLORS.Gold, Enum.Material.Metal)

	makePart(root, "Crate", Vector3.new(2, 1.4, 2), baseCFrame * CFrame.new(-3.2, 1.1, -2.6), COLORS.Wood, Enum.Material.WoodPlanks)

	makePart(root, "BannerLeft", Vector3.new(0.2, 4.5, 2.8), baseCFrame * CFrame.new(-8.8, 4.8, 0), COLORS.BannerAccent, Enum.Material.Fabric, { canCollide = false })
	makePart(root, "BannerRight", Vector3.new(0.2, 4.5, 2.8), baseCFrame * CFrame.new(8.8, 4.8, 0), COLORS.BannerAccent, Enum.Material.Fabric, { canCollide = false })

	local sign = addSign(root, "Trading Plaza")
	sign.CFrame = baseCFrame * CFrame.new(0, 4.2, -10.2)

	addPrompt(counter, "Trade", "Trading Plaza")
end

local function buildDailyRewards(root: Model, baseCFrame: CFrame)
	makePart(root, "Step1", Vector3.new(14, 0.5, 10), baseCFrame * CFrame.new(0, 0.25, 1.2), COLORS.StoneDark, Enum.Material.Cobblestone)
	makePart(root, "Step2", Vector3.new(11, 0.5, 7.5), baseCFrame * CFrame.new(0, 0.75, -0.8), COLORS.Stone, Enum.Material.Slate)

	local altar = makePart(root, "Altar", Vector3.new(8, 1.4, 5), baseCFrame * CFrame.new(0, 1.7, -2.8), COLORS.StoneDark, Enum.Material.Marble)

	makePart(root, "AltarTrim", Vector3.new(8.6, 0.3, 5.6), altar.CFrame * CFrame.new(0, 0.85, 0), COLORS.Gold, Enum.Material.Metal, { canCollide = false })

	local bowl = makePart(root, "RewardBowl", Vector3.new(3.2, 1.2, 3.2), altar.CFrame * CFrame.new(0, 1.2, 0.2), COLORS.Gold, Enum.Material.Metal)
	bowl.Shape = Enum.PartType.Cylinder
	bowl.CFrame = bowl.CFrame * CFrame.Angles(0, 0, math.rad(90))

	addCrystal(root, "RewardCrystal", altar.CFrame * CFrame.new(0, 2.5, 0.2), Vector3.new(1.6, 2.8, 1.6))

	makePart(root, "ArchLeft", Vector3.new(1.2, 8, 1.2), baseCFrame * CFrame.new(-4.2, 4.4, -5.8), COLORS.Stone, Enum.Material.Slate)
	makePart(root, "ArchRight", Vector3.new(1.2, 8, 1.2), baseCFrame * CFrame.new(4.2, 4.4, -5.8), COLORS.Stone, Enum.Material.Slate)
	makePart(root, "ArchTop", Vector3.new(9.8, 1.2, 1.4), baseCFrame * CFrame.new(0, 8.5, -5.8), COLORS.Gold, Enum.Material.Metal, { canCollide = false })

	makePart(root, "GiftBox", Vector3.new(2.2, 2.2, 2.2), altar.CFrame * CFrame.new(-2.2, 1.5, 0), COLORS.Banner, Enum.Material.SmoothPlastic)
	makePart(root, "GiftRibbon", Vector3.new(2.4, 0.35, 0.5), altar.CFrame * CFrame.new(-2.2, 2.1, 0), COLORS.Gold, Enum.Material.Metal, { canCollide = false })

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "RewardSparkles"
	sparkles.Texture = "rbxassetid://243660364"
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.LightEmission = 0.8
	sparkles.Color = ColorSequence.new(COLORS.Glow, COLORS.Crystal)
	sparkles.Parent = bowl

	local sign = addSign(root, "Daily Rewards")
	sign.CFrame = baseCFrame * CFrame.new(0, 4.5, 4.8)

	addPrompt(altar, "Claim", "Daily Rewards")
end

local function buildQuestHall(root: Model, baseCFrame: CFrame)
	makePart(root, "Floor", Vector3.new(22, 0.6, 20), baseCFrame * CFrame.new(0, 0.3, 0), COLORS.StoneDark, Enum.Material.Cobblestone)

	local towerOffsets = {
		{ Vector3.new(-8, 0, -8), 9 },
		{ Vector3.new(8, 0, -8), 7.5 },
		{ Vector3.new(-8, 0, 8), 7.5 },
		{ Vector3.new(8, 0, 8), 9 },
	}

	for index, entry in towerOffsets do
		local offset, height = entry[1], entry[2]
		makePart(root, "Tower" .. index, Vector3.new(2.4, height, 2.4), baseCFrame * CFrame.new(offset + Vector3.new(0, height * 0.5, 0)), COLORS.Stone, Enum.Material.Slate)
		makePart(root, "TowerCap" .. index, Vector3.new(3.2, 0.8, 3.2), baseCFrame * CFrame.new(offset + Vector3.new(0, height + 0.4, 0)), COLORS.Gold, Enum.Material.Metal, { canCollide = false })
	end

	makePart(root, "Roof", Vector3.new(18, 0.6, 16), baseCFrame * CFrame.new(0, 9.8, 0), COLORS.Roof, Enum.Material.Slate, { canCollide = false })
	makePart(root, "RoofPeak", Vector3.new(12, 0.5, 10), baseCFrame * CFrame.new(0, 10.5, 0), COLORS.Roof, Enum.Material.Slate, { canCollide = false })

	makePart(root, "Banner", Vector3.new(0.2, 5, 3.5), baseCFrame * CFrame.new(0, 6.5, -9.4), COLORS.BannerAccent, Enum.Material.Fabric, { canCollide = false })

	local board = makePart(root, "QuestBoard", Vector3.new(7.5, 5.5, 0.6), baseCFrame * CFrame.new(0, 4.2, -6.2), COLORS.WoodDark, Enum.Material.Wood)

	for row = 1, 3 do
		makePart(root, "QuestScroll" .. row, Vector3.new(5.8, 1.1, 0.15), board.CFrame * CFrame.new(0, 2.2 - row * 1.3, -0.35), COLORS.Glow, Enum.Material.SmoothPlastic, { canCollide = false })
	end

	makePart(root, "GuideBase", Vector3.new(3.5, 0.5, 3.5), baseCFrame * CFrame.new(4.5, 0.85, 2.5), COLORS.StoneDark, Enum.Material.Cobblestone)
	makePart(root, "GuideBody", Vector3.new(2.2, 3.2, 1.4), baseCFrame * CFrame.new(4.5, 2.6, 2.5), COLORS.Banner, Enum.Material.Fabric, { canCollide = false })

	local npcHead = makePart(root, "GuideHead", Vector3.new(1.5, 1.5, 1.5), baseCFrame * CFrame.new(4.5, 4.6, 2.5), COLORS.Stone, Enum.Material.Marble, { canCollide = false })
	npcHead.Shape = Enum.PartType.Ball

	makePart(root, "GuideStaff", Vector3.new(0.35, 5.5, 0.35), baseCFrame * CFrame.new(5.8, 3.5, 2.5), COLORS.WoodDark, Enum.Material.Wood, { canCollide = false })
	addCrystal(root, "GuideCrystal", baseCFrame * CFrame.new(5.8, 6.4, 2.5), Vector3.new(0.9, 1.4, 0.9))

	local sign = addSign(root, "Quest Hall")
	sign.CFrame = baseCFrame * CFrame.new(0, 5.5, 9.8)

	addPrompt(board, "Quests", "Quest Hall")
end

local function hideSpotMarker(spotPart: BasePart)
	spotPart.Anchored = true
	spotPart.Transparency = 1
	spotPart.CanCollide = false
	spotPart.CanQuery = false
	spotPart.CanTouch = false
end

local function buildFeature(name: string, spotName: string, builder)
	local spot = workspace:FindFirstChild(spotName)
	if not spot or not spot:IsA("BasePart") then
		warn("[HubFeatureBuilder] Missing spot marker:", spotName)
		return
	end

	local model = Instance.new("Model")
	model.Name = name

	local baseCFrame = getHubSurfaceCFrame(spot)
	builder(model, baseCFrame)

	model:PivotTo(baseCFrame)
	model.Parent = workspace:FindFirstChild("HubFeatures") or workspace

	hideSpotMarker(spot)
end

local function buildAll()
	local existing = workspace:FindFirstChild("HubFeatures")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "HubFeatures"
	folder.Parent = workspace

	buildFeature("Leaderboards", SPOT_NAMES.Leaderboards, buildLeaderboards)
	buildFeature("TradingPlaza", SPOT_NAMES.TradingPlaza, buildTradingPlaza)
	buildFeature("DailyRewards", SPOT_NAMES.DailyRewards, buildDailyRewards)
	buildFeature("QuestHall", SPOT_NAMES.QuestHall, buildQuestHall)
end

buildAll()
