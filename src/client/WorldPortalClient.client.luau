local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local IslandUnlockState = IslandEvents:WaitForChild("IslandUnlockState")
local IslandUnlockRequest = IslandEvents:WaitForChild("IslandUnlockRequest")
local IslandTeleportRequest = IslandEvents:WaitForChild("IslandTeleportRequest")
local OpenWorldPortal = IslandEvents:WaitForChild("OpenWorldPortal")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local unlockedSet = {}
local cardRecords = {}
local isOpen = false
local isAnimating = false

local CARD_HEIGHT = 196
local LIST_PADDING = 14
local SCROLL_TOP_OFFSET = 12

local ISLAND_DESCRIPTIONS = {
	Forest = "Lush wilderness filled with starter dragons and ancient groves.",
	Cold = "Frozen peaks where ice dragons thrive beneath the northern snow.",
	Lava = "Volcanic wasteland of fire dragons, magma flows, and molten riches.",
	Storm = "Lightning-charged cliffs haunted by storm dragons and wild tempests.",
	Shadow = "A dark realm of shadow dragons, secrets, and hidden treasures.",
	Crystal = "Glittering caverns home to rare crystal dragons and radiant gems.",
	Celestial = "The ultimate endgame island floating among the stars.",
}

local HUB_DESTINATION = {
	Id = "Hub",
	DisplayName = "Hub",
	ShortName = "Hub",
	Emoji = "🏠",
	Icon = Theme.Icons.Crown,
	Accent = Color3.fromRGB(155, 95, 220),
	Cost = 0,
	Description = "The social hub with quests, shops, and portals back to your island.",
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WorldPortalUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.DisplayOrder = Theme.NavDisplayOrder
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui
Theme.applyScreenSafeArea(screenGui)

local dim = Theme.createDim(screenGui, 1)
dim.Name = "DimBackground"
Theme.hideDim(dim)

local panel, panelScale = Theme.createPanel({
	Name = "WorldPortalPanel",
	Parent = screenGui,
	Size = UDim2.fromOffset(920, 660),
	Position = UDim2.fromScale(0.5, 0.5),
	Visible = false,
	ZIndex = 5,
})
panel:SetAttribute("OpenPosition", panel.Position)

local header = Theme.createFrame({
	Name = "Header",
	Parent = panel,
	Size = UDim2.new(1, -32, 0, 72),
	Position = UDim2.fromOffset(16, 12),
	Bg = Theme.Colors.PanelInner,
	Corner = Theme.Corner.Large,
	ZIndex = 6,
})
Theme.stroke(header, Theme.Colors.GoldBright, 2, 0.2)

local title = Theme.createText({
	Name = "Title",
	Parent = header,
	Text = "World Portal",
	Size = UDim2.new(1, -180, 0, 34),
	Position = UDim2.fromOffset(18, 8),
	TextSize = 28,
	Font = Theme.Fonts.Title,
	Color = Theme.Colors.Text,
	Wrapped = false,
	ZIndex = 7,
})

local subtitle = Theme.createText({
	Name = "Subtitle",
	Parent = header,
	Text = "Scroll the map, unlock islands, and teleport across the realm.",
	Size = UDim2.new(1, -180, 0, 22),
	Position = UDim2.fromOffset(18, 42),
	TextSize = 14,
	Font = Theme.Fonts.Body,
	Color = Theme.Colors.TextMuted,
	Wrapped = false,
	ZIndex = 7,
})

local essencePill, essenceLabel = Theme.createPremiumResourceCapsule(header, Theme.Icons.Crystal, "EssenceValue", 1)
essencePill.AnchorPoint = Vector2.new(1, 0.5)
essencePill.Position = UDim2.new(1, -58, 0.5, 0)
essencePill.ZIndex = 7

local function closePortal()
	if not isOpen or isAnimating then
		return
	end
	isAnimating = true
	isOpen = false
	Theme.closeModalWindow(screenGui, panel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
		isAnimating = false
	end)
end

Theme.createCloseButton(panel, function()
	closePortal()
end, 30)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "IslandScroll"
scroll.Size = UDim2.new(1, -32, 1, -104)
scroll.Position = UDim2.fromOffset(16, 88)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 10
scroll.ScrollBarImageColor3 = Theme.Colors.Crystal
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ScrollingEnabled = true
scroll.Active = true
scroll.Selectable = false
scroll.ElasticBehavior = Enum.ElasticBehavior.Always
scroll.ZIndex = 6
scroll.Parent = panel
Theme.styleScrollFrame(scroll)
scroll.BackgroundTransparency = 0.08

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop = UDim.new(0, 10)
scrollPadding.PaddingBottom = UDim.new(0, 14)
scrollPadding.PaddingLeft = UDim.new(0, 10)
scrollPadding.PaddingRight = UDim.new(0, 10)
scrollPadding.Parent = scroll

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, LIST_PADDING)
list.Parent = scroll

local function formatEssence(value)
	return IslandUnlockConfig.FormatCost(value) .. " Dragon Essence"
end

local function updateEssenceLabel()
	local essence = player:GetAttribute("DragonEssence") or 0
	essenceLabel.Text = Theme.formatCompact(essence)
end

local function getCardState(islandId)
	if islandId == HUB_DESTINATION.Id then
		return "unlocked"
	end
	if unlockedSet[islandId] then
		return "unlocked"
	end
	local previousId
	local index = IslandUnlockConfig.GetIslandIndex(islandId)
	if index and index > 1 then
		previousId = IslandUnlockConfig.Islands[index - 1].Id
	end
	if previousId and not unlockedSet[previousId] then
		return "blocked"
	end
	return "available"
end

local function setCardVisual(record, state)
	local island = record.island
	local card = record.card
	local statusLabel = record.statusLabel
	local actionButton = record.actionButton
	local costLabel = record.costLabel
	local lockOverlay = record.lockOverlay
	local accentStroke = record.accentStroke
	local nameLabel = record.nameLabel
	local descLabel = record.descLabel
	local previewImage = record.previewImage

	if accentStroke then
		accentStroke.Color = state == "unlocked" and Theme.Colors.Success or island.Accent or Theme.Colors.Crystal
	end

	if previewImage then
		previewImage.ImageTransparency = state == "blocked" and 0.35 or 0
	end

	if state == "unlocked" then
		statusLabel.Text = island.Id == HUB_DESTINATION.Id and "✅ Available" or "✅ Unlocked"
		statusLabel.TextColor3 = Theme.Colors.Success
		costLabel.Visible = true
		costLabel.Text = island.Id == HUB_DESTINATION.Id and "Free travel" or "Ready to travel"
		costLabel.TextColor3 = Theme.Colors.TextMuted
		lockOverlay.Visible = false
		if nameLabel then
			nameLabel.Visible = true
		end
		if descLabel then
			descLabel.Visible = true
		end
		actionButton.Visible = true
		actionButton.Text = "Teleport"
		actionButton.BackgroundColor3 = Theme.Colors.Crystal
		actionButton.AutoButtonColor = true
		actionButton.Active = true
		card.BackgroundColor3 = Theme.Colors.Stone
	elseif state == "available" then
		statusLabel.Text = "🔒 Locked"
		statusLabel.TextColor3 = Theme.Colors.Danger
		costLabel.Visible = true
		costLabel.Text = formatEssence(island.Cost)
		costLabel.TextColor3 = Theme.Colors.GoldBright
		lockOverlay.Visible = false
		if nameLabel then
			nameLabel.Visible = true
		end
		if descLabel then
			descLabel.Visible = true
		end
		actionButton.Visible = true
		actionButton.Text = "Unlock"
		actionButton.BackgroundColor3 = Theme.Colors.Gold
		actionButton.AutoButtonColor = true
		actionButton.Active = true
		card.BackgroundColor3 = Theme.Colors.Stone
	else
		statusLabel.Text = "🔒 Locked"
		statusLabel.TextColor3 = Theme.Colors.TextMuted
		costLabel.Visible = true
		costLabel.Text = formatEssence(island.Cost)
		costLabel.TextColor3 = Theme.Colors.TextMuted
		lockOverlay.Visible = true
		if nameLabel then
			nameLabel.Visible = true
		end
		if descLabel then
			descLabel.Visible = true
		end
		actionButton.Visible = false
		card.BackgroundColor3 = island.Accent:Lerp(Theme.Colors.StoneDeep, 0.55)
	end
end

local function refreshCards()
	setCardVisual(cardRecords[HUB_DESTINATION.Id], "unlocked")
	for islandId, record in cardRecords do
		if islandId ~= HUB_DESTINATION.Id then
			setCardVisual(record, getCardState(islandId))
		end
	end
	updateEssenceLabel()
end

local function getFocusIslandId()
	local focusIndex = 1
	for index, island in IslandUnlockConfig.Islands do
		if unlockedSet[island.Id] then
			focusIndex = index
		end
	end
	return IslandUnlockConfig.Islands[focusIndex].Id
end

local function scrollToIsland(islandId, animate)
	local record = cardRecords[islandId]
	if not record or not record.card then
		return
	end

	task.spawn(function()
		if not scroll.Parent then
			return
		end

		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()

		local card = record.card
		local cardTop = card.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
		local targetY = math.max(0, cardTop - SCROLL_TOP_OFFSET)
		local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
		targetY = math.clamp(targetY, 0, maxY)

		if animate then
			local tween = TweenService:Create(scroll, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				CanvasPosition = Vector2.new(0, targetY),
			})
			tween:Play()
		else
			scroll.CanvasPosition = Vector2.new(0, targetY)
		end
	end)
end

local function playCardEntrance()
	for index, island in IslandUnlockConfig.Islands do
		local record = cardRecords[island.Id]
		if not record or not record.cardScale then
			continue
		end
		record.cardScale.Scale = 0.94
		record.card.BackgroundTransparency = 0.2
		task.delay(0.04 * (index - 1), function()
			if not record.card.Parent then
				return
			end
			TweenService:Create(record.cardScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
			TweenService:Create(record.card, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
			}):Play()
		end)
	end
end

local function createIslandCard(island, layoutOrder)
	local card = Theme.createFrame({
		Name = island.Id .. "Card",
		Parent = scroll,
		Size = UDim2.new(1, -4, 0, CARD_HEIGHT),
		Bg = Theme.Colors.Stone,
		Corner = Theme.Corner.XL,
		LayoutOrder = layoutOrder,
		ZIndex = 7,
	})
	local accentStroke = Theme.stroke(card, island.Accent or Theme.Colors.Crystal, 2.5, 0.08)

	local shine = Theme.createFrame({
		Name = "CardShine",
		Parent = card,
		Size = UDim2.new(0.22, 0, 1.2, 0),
		Position = UDim2.new(-0.2, 0, -0.1, 0),
		Bg = island.Accent:Lerp(Color3.new(1, 1, 1), 0.55),
		BgTransparency = 0.82,
		Corner = Theme.Corner.Large,
		ZIndex = 8,
	})
	shine.Rotation = 18
	Theme.makeInputTransparent(shine)

	local imageWrap = Theme.createFrame({
		Name = "ImageWrap",
		Parent = card,
		Size = UDim2.fromOffset(168, 168),
		Position = UDim2.fromOffset(14, 14),
		Bg = island.Accent:Lerp(Color3.new(1, 1, 1), 0.72),
		Corner = Theme.Corner.Large,
		ZIndex = 8,
	})
	Theme.stroke(imageWrap, island.Accent, 2, 0.2)

	local previewImage = Instance.new("ImageLabel")
	previewImage.Name = "IslandPreview"
	previewImage.Size = UDim2.fromOffset(132, 132)
	previewImage.Position = UDim2.fromScale(0.5, 0.5)
	previewImage.AnchorPoint = Vector2.new(0.5, 0.5)
	previewImage.BackgroundTransparency = 1
	previewImage.Image = island.Icon or Theme.Icons.Star
	previewImage.ScaleType = Enum.ScaleType.Fit
	previewImage.ZIndex = 9
	previewImage.Parent = imageWrap

	local content = Theme.createFrame({
		Name = "Content",
		Parent = card,
		Size = UDim2.new(1, -202, 1, -28),
		Position = UDim2.fromOffset(190, 14),
		BgTransparency = 1,
		ZIndex = 8,
	})

	local nameLabel = Theme.createText({
		Name = "NameLabel",
		Parent = content,
		Text = island.Id == HUB_DESTINATION.Id and (HUB_DESTINATION.Emoji .. " " .. HUB_DESTINATION.DisplayName) or IslandUnlockConfig.GetCardTitle(island),
		Size = UDim2.new(1, -8, 0, 30),
		Position = UDim2.fromOffset(0, 0),
		TextSize = 22,
		Font = Theme.Fonts.Title,
		Color = Theme.Colors.Text,
		Wrapped = false,
		Truncate = Enum.TextTruncate.AtEnd,
		ZIndex = 9,
	})

	local descLabel = Theme.createText({
		Name = "DescriptionLabel",
		Parent = content,
		Text = (island.Id == HUB_DESTINATION.Id and HUB_DESTINATION.Description) or ISLAND_DESCRIPTIONS[island.Id] or "Discover new dragons and rewards on this island.",
		Size = UDim2.new(1, -8, 0, 40),
		Position = UDim2.fromOffset(0, 32),
		TextSize = 13,
		Font = Theme.Fonts.Body,
		Color = Theme.Colors.TextMuted,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		ZIndex = 9,
	})

	local metaRow = Theme.createFrame({
		Name = "MetaRow",
		Parent = content,
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.fromOffset(0, 76),
		BgTransparency = 1,
		ZIndex = 9,
	})

	local statusLabel = Theme.createText({
		Name = "StatusLabel",
		Parent = metaRow,
		Text = "🔒 Locked",
		Size = UDim2.new(0.42, 0, 1, 0),
		TextSize = 15,
		Font = Theme.Fonts.Bold,
		Color = Theme.Colors.Danger,
		Wrapped = false,
		ZIndex = 10,
	})

	local costLabel = Theme.createText({
		Name = "CostLabel",
		Parent = metaRow,
		Text = formatEssence(island.Cost),
		Size = UDim2.new(0.58, -8, 1, 0),
		Position = UDim2.new(0.42, 0, 0, 0),
		TextSize = 13,
		Font = Theme.Fonts.Bold,
		Color = Theme.Colors.GoldBright,
		XAlign = Enum.TextXAlignment.Right,
		Wrapped = false,
		Truncate = Enum.TextTruncate.AtEnd,
		ZIndex = 10,
	})

	local actionButton = Theme.createButton({
		Name = "ActionButton",
		Parent = content,
		Text = "Unlock",
		Size = UDim2.new(1, -8, 0, 48),
		Position = UDim2.new(0, 0, 1, -48),
		TextSize = 17,
		Font = Theme.Fonts.Bold,
		Bg = Theme.Colors.Gold,
		Corner = Theme.Corner.Large,
		ZIndex = 10,
		Stroke = true,
		StrokeColor = Theme.Colors.GoldBright,
	})
	actionButton.Selectable = true

	local lockOverlay = Theme.createFrame({
		Name = "LockOverlay",
		Parent = content,
		Size = UDim2.new(1, -8, 0, 48),
		Position = UDim2.new(0, 0, 1, -48),
		Bg = Theme.Colors.TopBarCapsule,
		BgTransparency = 0.08,
		Corner = Theme.Corner.Large,
		Visible = false,
		ZIndex = 12,
	})
	Theme.stroke(lockOverlay, Theme.Colors.Gold, 1.5, 0.35)

	local blockedLabel = Theme.createText({
		Name = "BlockedLabel",
		Parent = lockOverlay,
		Text = "Unlock the previous island first.",
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromOffset(8, 6),
		TextSize = 14,
		Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Center,
		YAlign = Enum.TextYAlignment.Center,
		ZIndex = 13,
	})

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 1
	cardScale.Parent = card

	local record = {
		island = island,
		card = card,
		statusLabel = statusLabel,
		costLabel = costLabel,
		actionButton = actionButton,
		lockOverlay = lockOverlay,
		accentStroke = accentStroke,
		cardScale = cardScale,
		nameLabel = nameLabel,
		descLabel = descLabel,
		previewImage = previewImage,
	}
	cardRecords[island.Id] = record

	actionButton.Activated:Connect(function()
		local state = getCardState(island.Id)
		if state == "unlocked" then
			IslandTeleportRequest:FireServer(island.Id)
			closePortal()
		elseif state == "available" then
			IslandUnlockRequest:FireServer(island.Id)
		end
	end)

	card.MouseEnter:Connect(function()
		if getCardState(island.Id) == "blocked" then
			return
		end
		TweenService:Create(cardScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.02,
		}):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(cardScale, TweenInfo.new(0.18), {
			Scale = 1,
		}):Play()
	end)

	setCardVisual(record, getCardState(island.Id))
	return card
end

for index, island in IslandUnlockConfig.Islands do
	createIslandCard(island, index + 1)
end

createIslandCard(HUB_DESTINATION, 0)

scroll.SelectionGroup = true

local function bindGamepadScroll()
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or not isOpen then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.Gamepad1 then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Thumbstick2 then
			return
		end

		local stickY = input.Position.Y
		if math.abs(stickY) < 0.2 then
			return
		end

		local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
		local nextY = math.clamp(scroll.CanvasPosition.Y + (stickY * 28), 0, maxY)
		scroll.CanvasPosition = Vector2.new(0, nextY)
	end)
end

bindGamepadScroll()

local function openPortal()
	if isOpen or isAnimating then
		return
	end
	isAnimating = true
	isOpen = true
	screenGui.Enabled = true
	refreshCards()
	scroll.CanvasPosition = Vector2.new(0, 0)
	Theme.raiseModalGui(screenGui)
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(screenGui.Name)
	else
		Theme.setModalLock(playerGui, true, screenGui.Name)
	end
	if _G.DragonIslandSetTutorialSuppressed then
		_G.DragonIslandSetTutorialSuppressed(true)
	end
	panelScale.Scale = Theme.MobileScale * 0.92
	Theme.tweenOpen(panel, dim)
	playCardEntrance()
	task.delay(0.34, function()
		TweenService:Create(panelScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = Theme.MobileScale,
		}):Play()
		scrollToIsland(getFocusIslandId(), true)
		isAnimating = false
	end)
end

dim.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		closePortal()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closePortal()
	end
	if input.KeyCode == Enum.KeyCode.ButtonB and isOpen then
		closePortal()
	end
end)

local function applyUnlockState(payload)
	unlockedSet = {}
	if typeof(payload) ~= "table" or typeof(payload.unlocked) ~= "table" then
		return
	end
	for _, islandId in payload.unlocked do
		unlockedSet[islandId] = true
	end
	refreshCards()
end

OpenWorldPortal.OnClientEvent:Connect(openPortal)
IslandUnlockState.OnClientEvent:Connect(applyUnlockState)

player:GetAttributeChangedSignal("DragonEssence"):Connect(updateEssenceLabel)
updateEssenceLabel()

_G.DragonIslandOpenWorldPortal = openPortal
_G.DragonIslandCloseWorldPortal = closePortal

print("[WorldPortalClient] World portal map ready")