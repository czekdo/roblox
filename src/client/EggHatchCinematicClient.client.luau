local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local EggOpeningSequence = require(ReplicatedStorage:WaitForChild("EggOpening"):WaitForChild("EggOpeningSequence"))
local EggOpeningConfig = require(ReplicatedStorage:WaitForChild("EggOpening"):WaitForChild("EggOpeningConfig"))

local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local EggHatchStart = HarvestEvents:WaitForChild("EggHatchStart")
local EggHatchComplete = HarvestEvents:WaitForChild("EggHatchComplete")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local hatchQueue = {}
local isPlaying = false
local activeHatchId = nil
local activeController = nil
local floatConnection = nil

local SkipController = {}
SkipController.__index = SkipController

function SkipController.new()
	return setmetatable({ skipped = false }, SkipController)
end

function SkipController:RequestSkip()
	self.skipped = true
end

function SkipController:IsSkipped()
	return self.skipped
end

local function tween(instance, info, goals)
	local tweenObj = TweenService:Create(instance, info, goals)
	tweenObj:Play()
	return tweenObj
end

local function getRarityColor(rarity)
	return DragonEggConfig.GetRarityInfo(rarity).Color
end

-- Per-species reveal art (ServerStorage.Image decals, uploaded by hand) shown in the reward card
-- instead of the generic egg-shell icon, so the hatch reveal actually shows the dragon you got.
local DRAGON_TYPE_ICONS = {
	ForestDragon = "rbxassetid://114447555397002",
	IceDragon = "rbxassetid://79175381980147",
	FireDragon = "rbxassetid://130942758121470",
	LavaDragon = "rbxassetid://113492446505113",
	StormDragon = "rbxassetid://108007135510335",
	VoidDragon = "rbxassetid://106499302625266",
	CrystalDragon = "rbxassetid://110920243474682",
	CelestialDragon = "rbxassetid://137631014879654",
	PoisonDragon = "rbxassetid://81777420880303",
	CoralOceanDragon = "rbxassetid://140189536944717",
	VipDragon = "rbxassetid://117149685970656",
}

local function createCinematicGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "EggHatchCinematicUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 120
	gui.Enabled = false
	gui:SetAttribute("BypassTutorialLockout", true)
	gui.Parent = playerGui

	local dim = Theme.createDim(gui, 1)
	dim.Name = "Dim"
	Theme.hideDim(dim)

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Active = false
	flash.Selectable = false
	flash.Parent = gui

	local glowRing = Instance.new("ImageLabel")
	glowRing.Name = "GlowRing"
	glowRing.AnchorPoint = Vector2.new(0.5, 0.5)
	glowRing.Position = UDim2.fromScale(0.5, 0.44)
	glowRing.Size = UDim2.fromOffset(420, 420)
	glowRing.BackgroundTransparency = 1
	glowRing.Image = "rbxassetid://5028857084"
	glowRing.ImageColor3 = Theme.Colors.CrystalGlow
	glowRing.ImageTransparency = 1
	glowRing.Visible = false
	glowRing.ZIndex = 8
	glowRing.Parent = gui
	Theme.makeInputTransparent(glowRing)

	local revealCard = Theme.createPanel({
		Name = "RevealCard",
		Parent = gui,
		Size = UDim2.fromOffset(360, 360),
		Position = UDim2.fromScale(0.5, 0.44),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = 10,
	})
	revealCard:SetAttribute("OpenPosition", revealCard.Position)

	local iconFrame, icon = Theme.createIconFrame(revealCard, Theme.Icons.Egg, 104, 12)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 20)
	icon.Name = "RewardIcon"
	icon.ImageTransparency = 1

	local petName = Theme.createText({
		Name = "PetName",
		Parent = revealCard,
		Size = UDim2.new(1, -32, 0, 40),
		Position = UDim2.fromOffset(16, 138),
		TextSize = 28,
		Font = Theme.Fonts.Title,
		Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 12,
	})
	petName.TextTransparency = 1

	local rarityLabel = Theme.createText({
		Name = "RarityLabel",
		Parent = revealCard,
		Size = UDim2.new(1, -32, 0, 30),
		Position = UDim2.fromOffset(16, 182),
		TextSize = 20,
		Font = Theme.Fonts.Bold,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 12,
	})
	rarityLabel.TextTransparency = 1

	local eggLabel = Theme.createText({
		Name = "EggLabel",
		Parent = revealCard,
		Size = UDim2.new(1, -32, 0, 24),
		Position = UDim2.fromOffset(16, 218),
		TextSize = 14,
		Font = Theme.Fonts.Regular,
		Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 12,
	})
	eggLabel.TextTransparency = 1

	local inputCatcher = Theme.createFrame({
		Name = "InputCatcher",
		Parent = gui,
		ClassName = "Frame",
		Size = UDim2.fromScale(1, 1),
		BgTransparency = 1,
		Visible = false,
		ZIndex = 2,
	})
	inputCatcher.Active = true

	local skipHint = Theme.createText({
		Name = "SkipHint",
		Parent = gui,
		Text = "Click or press Space to skip",
		Size = UDim2.fromOffset(320, 28),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 14,
		Font = Theme.Fonts.Regular,
		Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 15,
	})

	return gui, flash, glowRing, revealCard, icon, petName, rarityLabel, eggLabel, dim, skipHint, inputCatcher
end

local cinematicGui, flashFrame, glowRing, revealCard, rewardIcon, petNameLabel, rarityLabel, eggLabel, dimFrame, skipHint, inputCatcher = createCinematicGui()

local function closeOpenModals()
	-- Closes every panel registered with UIBridge, not just a hand-maintained subset —
	-- previously this list (EggShop/MergeUI/Roster/TrainingUI/Crafting/Buildings/DailyQuests
	-- only) silently missed Achievements/Rebirth/Personalization/WorldPortal/StorageFull/
	-- SkillTree/Milestones, so those stayed open through the hatch cinematic.
	UIBridge.CloseAllPanels()
	Theme.cleanupAllModalOverlays(playerGui)
end

local function beginHatchPresentation()
	closeOpenModals()
	Theme.setModalLock(playerGui, true, {
		"EggHatchCinematicUI",
		"DragonUIUXController",
		"KingdomHUD",
	})
	if _G.DragonIslandSetTutorialSuppressed then
		_G.DragonIslandSetTutorialSuppressed(true)
	end
	if _G.DragonIslandSetWorldPanelsSuppressed then
		_G.DragonIslandSetWorldPanelsSuppressed(true)
	end
	local legacyInventoryGui = playerGui:FindFirstChild("DragonInventoryUI")
	if legacyInventoryGui then
		legacyInventoryGui.Enabled = false
	end
end

local function endHatchPresentation()
	Theme.hideDim(dimFrame)
	Theme.setModalLock(playerGui, false)
	if _G.DragonIslandSetTutorialSuppressed then
		_G.DragonIslandSetTutorialSuppressed(false)
	end
	if _G.DragonIslandSetWorldPanelsSuppressed then
		_G.DragonIslandSetWorldPanelsSuppressed(false)
	end
end

local function disconnectFloat()
	if floatConnection then
		floatConnection:Disconnect()
		floatConnection = nil
	end
end

local function hideRewardCard()
	disconnectFloat()
	revealCard.Visible = false
	glowRing.Visible = false
	glowRing.ImageTransparency = 1
	rewardIcon.ImageTransparency = 1
	petNameLabel.TextTransparency = 1
	rarityLabel.TextTransparency = 1
	eggLabel.TextTransparency = 1
	Theme.hideDim(dimFrame)
end

local function showRewardCard(payload, profile, controller)
	local rarity = payload.rarity or "Common"
	local rarityColor = getRarityColor(rarity)
	local eggInfo = DragonEggConfig.GetEggTypeInfo(payload.eggType or "Common")

	petNameLabel.Text = payload.dragonDisplayName or payload.dragonType or "Dragon"
	rarityLabel.Text = string.upper(rarity)
	rarityLabel.TextColor3 = rarityColor
	eggLabel.Text = payload.eggDisplayName or eggInfo.DisplayName or "Egg"
	rewardIcon.Image = DRAGON_TYPE_ICONS[payload.dragonType] or eggInfo.Icon or Theme.Icons.Egg

	local revealStroke = revealCard:FindFirstChildOfClass("UIStroke")
	if revealStroke then
		revealStroke.Color = rarityColor
	end

	glowRing.ImageColor3 = rarityColor
	glowRing.ImageTransparency = 0.35
	glowRing.Visible = true

	dimFrame.Visible = true
	dimFrame.Active = false
	dimFrame.BackgroundTransparency = 1
	tween(dimFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.5,
	})

	revealCard.Visible = true
	revealCard.Position = UDim2.fromScale(0.5, 0.44)
	revealCard.Size = UDim2.fromOffset(280, 280)
	revealCard.BackgroundTransparency = 0.15

	local rewardSound = (rarity == "Legendary" or rarity == "Mythic" or rarity == "Ancient") and "LegendaryReward"
		or (rarity == "Rare" or rarity == "Epic") and "RareReward"
		or "RewardAppear"

	local EggOpeningEffects = require(ReplicatedStorage:WaitForChild("EggOpening"):WaitForChild("EggOpeningEffects"))
	EggOpeningEffects.PlaySound(rewardSound, 0.65, profile.soundPitch)

	tween(revealCard, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(360, 360),
		BackgroundTransparency = 0,
	})
	tween(rewardIcon, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = 0 })
	tween(petNameLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
	tween(rarityLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })
	tween(eggLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 })

	disconnectFloat()
	local floatStart = os.clock()
	floatConnection = RunService.RenderStepped:Connect(function()
		if controller and controller:IsSkipped() then
			disconnectFloat()
			return
		end
		local t = os.clock() - floatStart
		revealCard.Position = UDim2.new(0.5, 0, 0.44, math.sin(t * 2.2) * 6)
		glowRing.Rotation = t * 24
	end)

	task.delay(profile.rewardHold or 2, function()
		disconnectFloat()
	end)
end

local function playHatchCinematic(payload)
	activeHatchId = payload.hatchId

	local controller = SkipController.new()
	activeController = controller
	local profile = EggOpeningConfig.GetProfile(payload.rarity or "Common")

	beginHatchPresentation()
	hideRewardCard()

	cinematicGui.Enabled = true
	Theme.hideDim(dimFrame)
	revealCard.Visible = false
	glowRing.Visible = false
	inputCatcher.Visible = true
	skipHint.Visible = true
	flashFrame.BackgroundTransparency = 1

	EggOpeningSequence.Play({
		payload = payload,
		player = player,
		camera = camera,
		controller = controller,
		ui = {
			flashFrame = flashFrame,
			showReward = showRewardCard,
		},
	})

	tween(dimFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	tween(revealCard, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 300),
	})
	tween(petNameLabel, TweenInfo.new(0.25), { TextTransparency = 1 })
	tween(rarityLabel, TweenInfo.new(0.25), { TextTransparency = 1 })
	tween(eggLabel, TweenInfo.new(0.25), { TextTransparency = 1 })
	tween(rewardIcon, TweenInfo.new(0.25), { ImageTransparency = 1 })
	tween(glowRing, TweenInfo.new(0.25), { ImageTransparency = 1 })

	task.wait(0.3)
	inputCatcher.Visible = false
	skipHint.Visible = false
	cinematicGui.Enabled = false
	hideRewardCard()
	endHatchPresentation()

	EggHatchComplete:FireServer(payload.hatchId)
	activeHatchId = nil
	activeController = nil
end

local function processQueue()
	if isPlaying then
		return
	end
	local payload = table.remove(hatchQueue, 1)
	if not payload then
		return
	end
	isPlaying = true
	local ok, err = pcall(function()
		playHatchCinematic(payload)
	end)
	if not ok then
		warn("[EggHatchCinematicClient]", err)
		inputCatcher.Visible = false
		skipHint.Visible = false
		cinematicGui.Enabled = false
		hideRewardCard()
		endHatchPresentation()
		EggHatchComplete:FireServer(payload.hatchId)
	end
	isPlaying = false
	processQueue()
end

EggHatchStart.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.hatchId) ~= "string" then
		return
	end
	table.insert(hatchQueue, payload)
	processQueue()
end)

local function requestSkip()
	if activeController and not activeController:IsSkipped() then
		activeController:RequestSkip()
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not activeHatchId then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		requestSkip()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		requestSkip()
	end
end)

inputCatcher.InputBegan:Connect(function(input)
	if not activeHatchId then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		requestSkip()
	end
end)
