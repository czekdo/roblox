local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local HarvestConfig = require(ReplicatedStorage:WaitForChild("HarvestConfig"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local DragonBoneAnimator = require(ReplicatedStorage:WaitForChild("DragonBoneAnimator"))
local Events = ReplicatedStorage:WaitForChild("HarvestEvents")
local TargetNode = Events:WaitForChild("TargetNode")
local HarvestHit = Events:WaitForChild("HarvestHit")
local NodeDepleted = Events:WaitForChild("NodeDepleted")
local EggHatched = Events:WaitForChild("EggHatched")
local HarvestUIUpdate = Events:WaitForChild("HarvestUIUpdate")
local UpgradeDragon = Events:WaitForChild("UpgradeDragon")
local BuyDragonEgg = Events:WaitForChild("BuyDragonEgg")
local EggShopUpdate = Events:WaitForChild("EggShopUpdate")
local RequestDragonMergeData = Events:WaitForChild("RequestDragonMergeData")
local MergeDragons = Events:WaitForChild("MergeDragons")
local DragonMergeUpdate = Events:WaitForChild("DragonMergeUpdate")
local BulkHatchEggs = Events:WaitForChild("BulkHatchEggs")
local BulkEggHatched = Events:WaitForChild("BulkEggHatched")
local SetAutoHatch = Events:WaitForChild("SetAutoHatch")

local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local IslandUnlockState = IslandEvents:WaitForChild("IslandUnlockState")

_G.DragonIslandUnlockedBiomes = _G.DragonIslandUnlockedBiomes or {}

local nodesFolder = workspace:WaitForChild("ResourceNodes")
local dragonsFolder = workspace:WaitForChild("DragonWorkers")
local eggsFolder = workspace:WaitForChild("DragonEggs")

local trackedDragons = {}
local trackedEggs = {}
local nodeBillboards = {}
local selectedDragon = nil
local currentEssence = 0
local upgradeButton = nil
local upgradePanel = nil
local upgradeStatus = nil
local upgradeInfo = nil
local eggShopGui = nil
local eggShopPanel = nil
local eggShopEssenceLabel = nil
local eggShopOwnedLabel = nil
local eggShopStatusLabel = nil
local selectedEggType = nil
local eggShopList = nil
local eggShopDetailPanel = nil
local eggShopPreviewIcon = nil
local eggShopPreviewIconGlow = nil
local eggShopPreviewName = nil
local eggShopPreviewDesc = nil
local eggShopPreviewCost = nil
local eggShopPreviewInfoScroll = nil
local eggShopPurchaseButton = nil
local eggShopPurchasePriceText = nil
local eggShopPreviewShowcase = nil
local eggShopPreviewGlow = nil
local eggShopCards = {}
local eggShopState = {
	essence = 0,
	ownedEggs = {},
	eggStats = {},
}
local eggShopBulkButton = nil
local eggShopAutoButton = nil
local autoHatchEnabled = false
local AUTO_HATCH_PASS = nil
for _, pass in MonetizationConfig.GamePasses do
	if pass.Key == "AutoHatch" then
		AUTO_HATCH_PASS = pass
		break
	end
end
local bulkResultsGui = nil
local bulkResultsPanel = nil
local bulkResultsList = nil
local bulkResultsSummary = nil
local mergeGui = nil
local mergePanel = nil
local mergeList = nil
local mergeSlots = {}
local mergePreview = nil
local mergeStatsLabel = nil
local mergeCostLabel = nil
local mergeStatusLabel = nil
local mergeButton = nil
local mergeCancelButton = nil
local mergeListRows = {}
local selectedMergeIds = {}
local mergeState = {
	essence = 0,
	dragons = {},
	mergeStats = {},
	maxEvolutionLevel = 5,
}

local HOVER_HEIGHT = HarvestConfig.HoverHeight
local BOB_AMPLITUDE = HarvestConfig.BobAmplitude
local BOB_SPEED_IDLE = 2.0
local BOB_SPEED_MOVE = 3.2
local MOVE_PITCH = math.rad(-16)
local MOVE_ROLL = math.rad(8)
local IDLE_SWAY = math.rad(4)
local MOVE_SWAY = math.rad(10)
local SMOOTH_FLY_SPEED = 10
local SMOOTH_FLY_CATCHUP = 18
local SMOOTH_TURN_SPEED = 7.5
local SMOOTH_TURN_BANK = 6
local VELOCITY_DAMPING = 8.5

local function pulseCrystalEyes(dragon, time, isActive)
	local pulseSpeed = isActive and 5.5 or 2.8
	local pulse = (math.sin(time * pulseSpeed) + 1) * 0.5
	local brightness = 0.8 + pulse * (isActive and 1.4 or 0.9)

	for _, eyeName in { "LeftEye", "RightEye" } do
		local eye = dragon:FindFirstChild(eyeName, true)
		if eye and eye:IsA("BasePart") then
			eye.Transparency = 0.05 + (1 - pulse) * 0.15
			local light = eye:FindFirstChild("EyeLight")
			if light then
				light.Brightness = brightness
			end
		end
	end
end

local function updateCrystalTrail(dragon, isActive)
	local trail = dragon:FindFirstChild("CrystalTrail", true)
	if trail and trail:IsA("ParticleEmitter") then
		trail.Rate = isActive and 28 or 6
		trail.Speed = NumberRange.new(isActive and 2 or 0.5, isActive and 5 or 1.5)
	end
end

local function animateDragon(dragon, state, time)
	local isMoving = state == "moving"
	local isHarvesting = state == "harvesting"
	local isActive = isMoving or isHarvesting

	local bobSpeed = isActive and BOB_SPEED_MOVE or BOB_SPEED_IDLE
	local bob = math.sin(time * bobSpeed) * BOB_AMPLITUDE
	local swayAmp = isActive and MOVE_SWAY or IDLE_SWAY
	local sway = math.sin(time * (isActive and 4.5 or 2.2)) * swayAmp
	local roll = isActive and math.sin(time * 3.8) * MOVE_ROLL or 0

	pulseCrystalEyes(dragon, time, isActive)
	updateCrystalTrail(dragon, isActive)

	return bob, isActive, sway, roll
end

local function isOwnedNode(node)
	if not node or not node:IsA("Model") then
		return false
	end
	if node:GetAttribute("BiomeResource") == true then
		local islandId = node:GetAttribute("IslandId")
		if typeof(islandId) ~= "string" then
			return false
		end
		local unlocked = _G.DragonIslandUnlockedBiomes
		return typeof(unlocked) == "table" and unlocked[islandId] == true
	end
	return node:GetAttribute("OwnerUserId") == player.UserId
end

local function getClickedNode()
	local target = mouse.Target
	if not target then
		return nil
	end
	local model = target:FindFirstAncestorWhichIsA("Model")
	if model and model:IsDescendantOf(nodesFolder) and isOwnedNode(model) then
		return model
	end
	return nil
end

local function getClickedDragon()
	local target = mouse.Target
	if not target then
		return nil
	end
	local model = target:FindFirstAncestorWhichIsA("Model")
	if model and model:IsDescendantOf(dragonsFolder) and model:GetAttribute("OwnerUserId") == player.UserId then
		return model
	end
	return nil
end

local function getUpgradeButtonText(dragon)
	if not dragon then
		return "Upgrade Dragon"
	end
	local level = dragon:GetAttribute("DragonLevel") or 1
	local cost = dragon:GetAttribute("UpgradeCost") or 0
	return "Upgrade Dragon  Lv. " .. tostring(level) .. " → " .. tostring(level + 1) .. "  (" .. tostring(cost) .. " essence)"
end

local function updateUpgradeUI()
	if not upgradePanel or not upgradeButton or not upgradeInfo then
		return
	end

	local dragon = selectedDragon
	local isValidSelection = dragon and dragon.Parent and dragon:GetAttribute("OwnerUserId") == player.UserId
	if _G.DragonIslandIsModalOpen and _G.DragonIslandIsModalOpen() then
		upgradePanel.Visible = false
		return
	end
	upgradePanel.Visible = isValidSelection == true
	local upgradeScreenGui = upgradePanel.Parent
	if upgradeScreenGui and upgradeScreenGui:IsA("ScreenGui") then
		upgradeScreenGui.Enabled = isValidSelection == true
	end
	if not isValidSelection then
		return
	end

	local level = dragon:GetAttribute("DragonLevel") or 1
	local cost = dragon:GetAttribute("UpgradeCost") or 0
	local flightSpeed = dragon:GetAttribute("FlightSpeed") or dragon:GetAttribute("MoveSpeed") or HarvestConfig.DragonMoveSpeed
	local harvestSpeed = dragon:GetAttribute("HarvestSpeed") or 1
	local carryCapacity = dragon:GetAttribute("CarryCapacity") or HarvestConfig.EssencePerHit
	local criticalChance = dragon:GetAttribute("CriticalHarvestChance") or 0
	local luck = dragon:GetAttribute("Luck") or 1
	local dragonType = dragon:GetAttribute("DragonType") or "Dragon"
	local rarity = dragon:GetAttribute("DragonRarity") or "Common"
	upgradeInfo.Text = table.concat({
		"Dragon Inventory",
		dragonType .. "  " .. rarity .. "  Lv. " .. tostring(level),
		"Harvest Speed: x" .. string.format("%.2f", harvestSpeed),
		"Flight Speed: " .. string.format("%.1f", flightSpeed),
		"Carry Capacity: " .. tostring(carryCapacity) .. " Essence",
		"Critical Harvest Chance: " .. string.format("%.0f%%", criticalChance * 100),
		"Luck: x" .. string.format("%.2f", luck),
	}, "\n")
	upgradeButton.Text = getUpgradeButtonText(dragon)
	upgradeButton.AutoButtonColor = currentEssence >= cost
	upgradeButton.BackgroundColor3 = currentEssence >= cost and Color3.fromRGB(70, 160, 90) or Color3.fromRGB(90, 90, 100)
end

local function selectDragon(dragon)
	selectedDragon = dragon
	if upgradeStatus then
		upgradeStatus.Text = ""
	end
	updateUpgradeUI()
end

local function createUpgradeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DragonInventoryUI"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	upgradePanel = Theme.createPanel({
		Name = "DragonInventoryPanel", Parent = screenGui,
		Size = UDim2.fromOffset(400, 280), Position = UDim2.new(0.5, 0, 1, -200),
		AnchorPoint = Vector2.new(0.5, 1), Visible = false,
	})
	upgradePanel:SetAttribute("OpenPosition", upgradePanel.Position)

	upgradeInfo = Theme.createText({
		Name = "DragonInventoryStats", Parent = upgradePanel,
		Size = UDim2.new(1, -24, 0, 146), Position = UDim2.fromOffset(12, 48),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.Text, YAlign = Enum.TextYAlignment.Top,
	})

	upgradeButton = Theme.createButton({
		Name = "UpgradeButton", Parent = upgradePanel, Text = "Upgrade Dragon",
		Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 200),
		Bg = Theme.Colors.Success, TextSize = 15,
	})

	upgradeStatus = Theme.createText({
		Name = "UpgradeStatus", Parent = upgradePanel, Text = "",
		Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 252),
		TextSize = 13, Font = Theme.Fonts.Regular, Color = Theme.Colors.Gold,
	})

	upgradeButton.Activated:Connect(function()
		if selectedDragon and selectedDragon.Parent then
			UpgradeDragon:FireServer(selectedDragon)
		end
	end)
end

_G.DragonIslandSetWorldPanelsSuppressed = function(suppressed)
	UIBridge.SetWorldPanelsSuppressed(suppressed)
end

UIBridge.Subscribe("WorldPanelsSuppressedChanged", function(suppressed)
	local playerGui = player:WaitForChild("PlayerGui")
	local invGui = playerGui:FindFirstChild("DragonInventoryUI")
	if invGui then
		invGui.Enabled = not suppressed
	end
	if upgradePanel then
		if suppressed then
			upgradePanel.Visible = false
		else
			updateUpgradeUI()
		end
	end
end)

createUpgradeUI()

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	local text = tostring(value)
	local result = text
	while true do
		local formatted, replacements = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
		result = formatted
		if replacements == 0 then
			break
		end
	end
	return result
end

local function formatChance(chance)
	chance = tonumber(chance) or 0
	if chance >= 10 then
		return string.format("%.0f%%", chance)
	elseif chance >= 1 then
		return string.format("%.1f%%", chance)
	end
	return string.format("%.1f%%", chance)
end

local function getEggDragonChances(eggInfo)
	local chances = {}
	local totalWeight = 0
	for _, dragon in eggInfo.Dragons or {} do
		totalWeight += dragon.Weight or 1
	end
	for _, dragon in eggInfo.Dragons or {} do
		local weight = dragon.Weight or 1
		table.insert(chances, {
			Name = dragon.DisplayName or dragon.Name,
			Chance = totalWeight > 0 and (weight / totalWeight) * 100 or 0,
		})
	end
	return chances
end

local function setEggShopStatus(message)
	if eggShopStatusLabel then
		eggShopStatusLabel.Text = message or ""
	end
end

local function getCurrentEssence()
	return math.max(
		tonumber(eggShopState.essence) or 0,
		tonumber(currentEssence) or 0,
		tonumber(player:GetAttribute("DragonEssence")) or 0
	)
end

local function getCurrentGems()
	return tonumber(player:GetAttribute("PremiumGems")) or 0
end

-- The Gem Egg is bought with Gems instead of Essence (eggInfo.GemCost set instead of .Cost) - these
-- three helpers keep every cost/afford/display check below currency-agnostic.
local function isGemEgg(eggInfo)
	return eggInfo.GemCost ~= nil
end

local function getEggCostText(eggInfo)
	if isGemEgg(eggInfo) then
		return formatNumber(eggInfo.GemCost) .. " Gems"
	end
	return formatNumber(eggInfo.Cost) .. " Essence"
end

local function canAffordEgg(eggInfo)
	if eggInfo.Reserved then
		return false
	end
	if eggInfo.IsFeatured and not DragonEggConfig.IsFeaturedEggActive() then
		return false
	end
	if isGemEgg(eggInfo) then
		return getCurrentGems() >= eggInfo.GemCost
	end
	return getCurrentEssence() >= eggInfo.Cost
end

local function formatFeaturedCountdown(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	end
	local minutes = math.floor((seconds % 3600) / 60)
	return string.format("%dh %dm", hours, minutes)
end

local EGG_SHOP_GOLD = Color3.fromRGB(235, 188, 82)
local EGG_SHOP_GOLD_DIM = Color3.fromRGB(120, 98, 52)
local EGG_SHOP_PANEL_BG = Color3.fromRGB(14, 20, 42)
local EGG_SHOP_INNER_BG = Color3.fromRGB(22, 30, 58)
local EGG_SHOP_CARD_BG = Color3.fromRGB(26, 34, 62)
local EGG_SHOP_CARD_SELECTED = Color3.fromRGB(36, 46, 78)

local function applyEggShopPanelGradient(frame)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 32, 62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 16, 34)),
	})
	gradient.Rotation = 90
	gradient.Parent = frame
	return gradient
end

local function applyPurchaseButtonGradient(button, enabled)
	local existing = button:FindFirstChild("PurchaseGradient")
	if existing then
		existing:Destroy()
	end
	local gradient = Instance.new("UIGradient")
	gradient.Name = "PurchaseGradient"
	if enabled then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(108, 228, 142)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 148, 88)),
		})
	else
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 68, 92)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 44, 62)),
		})
	end
	gradient.Rotation = 90
	gradient.Parent = button
end

local function setEggShopCardSelected(cardData, selected)
	if not cardData or not cardData.card then
		return
	end
	local card = cardData.card
	local stroke = cardData.cardStroke
	TweenService:Create(card, TweenInfo.new(0.16), {
		BackgroundColor3 = selected and EGG_SHOP_CARD_SELECTED or EGG_SHOP_CARD_BG,
	}):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.16), {
			Color = selected and Theme.Colors.GoldBright or EGG_SHOP_GOLD_DIM,
			Thickness = selected and 2.8 or 1.2,
			Transparency = selected and 0 or 0.55,
		}):Play()
	end
	if cardData.iconStroke then
		TweenService:Create(cardData.iconStroke, TweenInfo.new(0.16), {
			Color = selected and Theme.Colors.GoldBright or (cardData.accentColor or EGG_SHOP_GOLD),
			Thickness = selected and 2.2 or 1.5,
			Transparency = selected and 0.1 or 0.35,
		}):Play()
	end
	if cardData.title then
		cardData.title.TextColor3 = selected and Theme.Colors.TextLight or Theme.Colors.Text
	end
end

local function createEggShopBanner(parent)
	local banner = Theme.createFrame({
		Name = "DecorBanner", Parent = parent,
		Size = UDim2.new(1, -36, 0, 86), Position = UDim2.fromOffset(18, 64),
		Bg = Color3.fromRGB(18, 28, 52), Corner = Theme.Corner.Medium, ClipsDescendants = true, ZIndex = 8,
	})
	Theme.stroke(banner, EGG_SHOP_GOLD, 1.5, 0.35)
	applyEggShopPanelGradient(banner)

	local glow = Theme.createFrame({
		Name = "BannerGlow", Parent = banner,
		Size = UDim2.new(1, 0, 0.7, 0), Position = UDim2.fromScale(0, 0),
		Bg = Color3.fromRGB(72, 140, 255), BgTransparency = 0.82, ZIndex = 9,
	})
	local glowGrad = Instance.new("UIGradient")
	glowGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGrad.Rotation = 90
	glowGrad.Parent = glow

	local forestFloor = Theme.createFrame({
		Name = "ForestFloor", Parent = banner,
		Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1), Bg = Color3.fromRGB(48, 108, 62), ZIndex = 9,
	})
	local floorGrad = Instance.new("UIGradient")
	floorGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(32, 78, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(62, 128, 72)),
	})
	floorGrad.Rotation = 0
	floorGrad.Parent = forestFloor

	local pedestalRow = Theme.createFrame({
		Name = "PedestalRow", Parent = banner,
		Size = UDim2.new(1, -24, 0, 54), Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1), BgTransparency = 1, ZIndex = 10,
	})
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rowLayout.Padding = UDim.new(0, 10)
	rowLayout.Parent = pedestalRow

	for index, eggType in DragonEggConfig.GetEggOrder() do
		local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
		local slot = Theme.createFrame({
			Name = eggType .. "BannerSlot", Parent = pedestalRow,
			Size = UDim2.fromOffset(44, 50), BgTransparency = 1, LayoutOrder = index, ZIndex = 11,
		})
		local base = Theme.createFrame({
			Name = "Base", Parent = slot,
			Size = UDim2.fromOffset(38, 14), Position = UDim2.new(0.5, 0, 1, -2),
			AnchorPoint = Vector2.new(0.5, 1), Bg = Color3.fromRGB(88, 82, 72), Corner = Theme.Corner.Small, ZIndex = 11,
		})
		Theme.stroke(base, EGG_SHOP_GOLD_DIM, 1, 0.6)
		local orb = Theme.createFrame({
			Name = "Orb", Parent = slot,
			Size = UDim2.fromOffset(30, 30), Position = UDim2.new(0.5, 0, 0, 2),
			AnchorPoint = Vector2.new(0.5, 0), Bg = eggInfo.EggColor or Theme.Colors.NavyEdge,
			Corner = UDim.new(1, 0), ZIndex = 12,
		})
		Theme.stroke(orb, eggInfo.GlowColor or EGG_SHOP_GOLD, 1.5, 0.25)
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(22, 22)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = eggInfo.Icon or DragonEggConfig.IconAssetId or Theme.Icons.Egg
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 13
		icon.Parent = orb
	end

	return banner
end

local function updateEggShopCard(eggType)
	local cardData = eggShopCards[eggType]
	if not cardData then
		return
	end
	local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
	local ownedCounts = eggShopState.ownedEggs or {}
	local stats = eggShopState.eggStats or {}
	local purchases = stats.Purchases or {}
	local hatched = stats.Hatched or {}
	local owned = ownedCounts[eggType] or (stats.OwnedEggs and stats.OwnedEggs[eggType]) or 0
	cardData.cost.Text = getEggCostText(eggInfo)
	cardData.owned.Text = "Owned: " .. tostring(owned)
	if eggInfo.IsFeatured then
		local active = DragonEggConfig.IsFeaturedEggActive()
		local countdown = formatFeaturedCountdown(DragonEggConfig.GetFeaturedEggCountdown())
		cardData.owned.Text = active and ("Ends in " .. countdown) or ("Returns in " .. countdown)
	end
	if cardData.cardStroke then
		cardData.cardStroke.Transparency = canAffordEgg(eggInfo) and 0.35 or 0.55
	end
end

local selectEggShopEgg

local function updateEggShopUI()
	local essence = getCurrentEssence()
	if eggShopEssenceLabel then
		eggShopEssenceLabel.Text = formatNumber(essence)
	end
	if eggShopOwnedLabel then
		local stats = eggShopState.eggStats or {}
		eggShopOwnedLabel.Text = "Owned Eggs: " .. tostring(stats.TotalPurchases or 0) .. " bought  •  " .. tostring(stats.TotalHatched or 0) .. " hatched"
	end
	for _, eggType in DragonEggConfig.GetEggOrder() do
		updateEggShopCard(eggType)
	end
	if selectedEggType then
		selectEggShopEgg(selectedEggType)
	end
end

selectEggShopEgg = function(eggType)
	if not eggType or not eggShopDetailPanel then
		return
	end
	selectedEggType = eggType
	local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)
	local tierColor = eggInfo.RarityColor or Theme.getRarityColor(eggInfo.Rarity or "Common")

	for typeName, cardData in eggShopCards do
		setEggShopCardSelected(cardData, typeName == eggType)
	end

	if eggShopPreviewIcon then
		eggShopPreviewIcon.Image = eggInfo.Icon or DragonEggConfig.IconAssetId or Theme.Icons.Egg
	end
	local previewIconFrame = eggShopPreviewIcon and eggShopPreviewIcon.Parent
	if previewIconFrame and previewIconFrame:IsA("GuiObject") then
		previewIconFrame.BackgroundColor3 = (eggInfo.EggColor or Theme.Colors.NavyMid):Lerp(Color3.fromRGB(20, 26, 44), 0.35)
	end
	if eggShopPreviewIconGlow then
		eggShopPreviewIconGlow.Color = eggInfo.GlowColor or tierColor
		eggShopPreviewIconGlow.Transparency = 0.15
	end
	if eggShopPreviewGlow then
		eggShopPreviewGlow.BackgroundColor3 = eggInfo.GlowColor or tierColor
	end
	if eggShopPreviewName then
		eggShopPreviewName.Text = eggInfo.DisplayName
		eggShopPreviewName.TextColor3 = Theme.Colors.TextLight
	end
	if eggShopPreviewDesc then
		eggShopPreviewDesc.Text = eggInfo.Description
	end
	if eggShopPreviewCost then
		eggShopPreviewCost.Text = getEggCostText(eggInfo)
	end

	if eggShopPreviewInfoScroll then
		for _, child in eggShopPreviewInfoScroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		eggShopPreviewInfoScroll.CanvasPosition = Vector2.new(0, 0)
		local order = 0
		local function addSectionHeader(text)
			order += 1
			Theme.createText({
				Name = "Header" .. order, Parent = eggShopPreviewInfoScroll, Text = text,
				Size = UDim2.new(1, 0, 0, 16), TextSize = 11, Font = Theme.Fonts.Bold,
				Color = EGG_SHOP_GOLD, XAlign = Enum.TextXAlignment.Left, ZIndex = 10, LayoutOrder = order,
			})
		end

		addSectionHeader("POSSIBLE DRAGONS")
		local dragonChances = getEggDragonChances(eggInfo)
		if #dragonChances == 0 then
			order += 1
			Theme.createText({
				Name = "Row" .. order, Parent = eggShopPreviewInfoScroll, Text = "Future dragon pool",
				Size = UDim2.new(1, 0, 0, 16), TextSize = 12, Font = Theme.Fonts.Regular,
				Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Left, ZIndex = 10, LayoutOrder = order,
			})
		else
			for _, entry in dragonChances do
				order += 1
				local row = Theme.createFrame({
					Name = "Row" .. order, Parent = eggShopPreviewInfoScroll,
					Size = UDim2.new(1, 0, 0, 16), BgTransparency = 1, ZIndex = 10, LayoutOrder = order,
				})
				Theme.createText({
					Name = "Name", Parent = row, Text = entry.Name,
					Size = UDim2.new(1, -50, 1, 0), TextSize = 12, Font = Theme.Fonts.Regular,
					Color = Theme.Colors.Text, XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
				})
				Theme.createText({
					Name = "Chance", Parent = row, Text = formatChance(entry.Chance),
					Size = UDim2.fromOffset(50, 16), Position = UDim2.new(1, -50, 0, 0),
					TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextMuted,
					XAlign = Enum.TextXAlignment.Right, ZIndex = 10,
				})
			end
		end

		order += 1
		addSectionHeader("RARITY CHANCES")
		order += 1
		local rarityGrid = Theme.createFrame({
			Name = "RarityGrid", Parent = eggShopPreviewInfoScroll,
			Size = UDim2.new(1, 0, 0, 50), BgTransparency = 1, ZIndex = 10, LayoutOrder = order,
		})
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.fromOffset(88, 20)
		gridLayout.CellPadding = UDim2.fromOffset(4, 4)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = rarityGrid
		for i, rarity in DragonEggConfig.GetRarityDropChances() do
			local pillColor = Theme.getRarityColor(rarity.Name)
			local pill = Theme.createFrame({
				Name = "Pill" .. i, Parent = rarityGrid, Bg = pillColor, BgTransparency = 0.78,
				Corner = Theme.Corner.Small, ZIndex = 10, LayoutOrder = i,
			})
			Theme.stroke(pill, pillColor, 1, 0.35)
			Theme.createText({
				Name = "Label", Parent = pill, Text = rarity.Name .. " " .. formatChance(rarity.Chance),
				Size = UDim2.new(1, -6, 1, 0), Position = UDim2.fromOffset(3, 0),
				TextSize = 10, Font = Theme.Fonts.Bold, Color = pillColor,
				XAlign = Enum.TextXAlignment.Center, ZIndex = 11,
			})
		end

		local ownedCounts = eggShopState.ownedEggs or {}
		local stats = eggShopState.eggStats or {}
		local purchases = stats.Purchases or {}
		local hatched = stats.Hatched or {}
		local owned = ownedCounts[eggType] or (stats.OwnedEggs and stats.OwnedEggs[eggType]) or 0
		order += 1
		Theme.createText({
			Name = "Stats", Parent = eggShopPreviewInfoScroll,
			Text = "Owned: " .. tostring(owned) .. "   Bought: " .. tostring(purchases[eggType] or 0) .. "   Hatched: " .. tostring(hatched[eggType] or 0),
			Size = UDim2.new(1, 0, 0, 16), TextSize = 11, Font = Theme.Fonts.Bold,
			Color = Theme.Colors.GoldBright, XAlign = Enum.TextXAlignment.Center, ZIndex = 10, LayoutOrder = order,
		})
	end

	local canBuy = canAffordEgg(eggInfo)
	if eggShopPurchaseButton then
		eggShopPurchaseButton.Text = eggInfo.Reserved and "Reserved" or "Purchase Egg"
		eggShopPurchaseButton.Active = true
		eggShopPurchaseButton.AutoButtonColor = canBuy
		eggShopPurchaseButton.BackgroundColor3 = canBuy and Theme.Colors.Success or Theme.Colors.NavyEdge
		eggShopPurchaseButton.TextColor3 = canBuy and Theme.Colors.TextLight or Theme.Colors.TextMuted
		applyPurchaseButtonGradient(eggShopPurchaseButton, canBuy)
		local buttonStroke = eggShopPurchaseButton:FindFirstChildOfClass("UIStroke")
		if buttonStroke then
			buttonStroke.Color = canBuy and Theme.Colors.GoldBright or Theme.Colors.Gold
			buttonStroke.Transparency = canBuy and 0.15 or 0.5
		end
	end
end

local function createText(parent, name, size, text, color, font, textSize, order)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.Gotham
	label.Text = text or ""
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize or 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.LayoutOrder = order or 1
	label.Parent = parent
	return label
end

local function createEggShopCard(parent, eggType)
	local eggInfo = DragonEggConfig.GetEggTypeInfo(eggType)

	local card = Instance.new("TextButton")
	card.Name = eggType .. "EggCard"
	card.Size = UDim2.new(1, -2, 0, 68)
	card.BackgroundColor3 = EGG_SHOP_CARD_BG
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.ZIndex = 9
	card.Parent = parent
	Theme.corner(card, Theme.Corner.Medium)
	local cardStroke = Theme.stroke(card, EGG_SHOP_GOLD_DIM, 1.2, 0.55)
	Theme.attachHover(card, EGG_SHOP_CARD_BG)

	local iconOrb = Theme.createFrame({
		Name = "IconOrb", Parent = card,
		Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 12),
		Bg = Color3.fromRGB(18, 24, 44), Corner = UDim.new(1, 0), ZIndex = 10,
	})
	Theme.stroke(iconOrb, eggInfo.GlowColor or EGG_SHOP_GOLD, 1.5, 0.35)
	local iconStroke = iconOrb:FindFirstChildOfClass("UIStroke")
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(30, 30)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = eggInfo.Icon or DragonEggConfig.IconAssetId or Theme.Icons.Egg
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 11
	icon.Parent = iconOrb
	Theme.makeInputTransparent(iconOrb)

	local title = Theme.createText({
		Name = "Title", Parent = card,
		Text = eggInfo.DisplayName,
		Size = UDim2.new(1, -66, 0, 20),
		Position = UDim2.fromOffset(60, 12),
		TextSize = 14,
		Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextLight,
		Wrapped = false,
		Truncate = Enum.TextTruncate.AtEnd,
		ZIndex = 10,
	})
	Theme.makeInputTransparent(title)

	local cost = Theme.createText({
		Name = "Cost", Parent = card,
		Text = getEggCostText(eggInfo),
		Size = UDim2.new(1, -66, 0, 16),
		Position = UDim2.fromOffset(60, 32),
		TextSize = 12,
		Font = Theme.Fonts.Bold,
		Color = Theme.Colors.CrystalSoft,
		ZIndex = 10,
	})
	Theme.makeInputTransparent(cost)

	local owned = Theme.createText({
		Name = "OwnedStats", Parent = card,
		Text = "Owned: 0",
		Size = UDim2.new(1, -66, 0, 14),
		Position = UDim2.fromOffset(60, 48),
		TextSize = 10,
		Font = Theme.Fonts.Regular,
		Color = Color3.fromRGB(170, 182, 210),
		ZIndex = 10,
	})
	Theme.makeInputTransparent(owned)

	card.Activated:Connect(function()
		selectEggShopEgg(eggType)
	end)

	eggShopCards[eggType] = {
		card = card,
		cost = cost,
		owned = owned,
		title = title,
		cardStroke = cardStroke,
		iconStroke = iconStroke,
		accentColor = eggInfo.GlowColor or EGG_SHOP_GOLD,
	}
	updateEggShopCard(eggType)
	return card
end

local function closeEggShop()
	if not eggShopGui or not eggShopPanel then
		return
	end
	local dim = eggShopGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(eggShopGui, eggShopPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(eggShopGui.Name)
		end
	end)
end

local function closeMergeUI()
	if not mergeGui or not mergePanel then
		return
	end
	local dim = mergeGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(mergeGui, mergePanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(mergeGui.Name)
		end
	end)
end

local function createEggShopUI()
	if eggShopGui then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")
	eggShopGui = Instance.new("ScreenGui")
	eggShopGui.Name = "EggShopUI"
	eggShopGui.ResetOnSpawn = false
	eggShopGui.DisplayOrder = 30
	eggShopGui.Enabled = false
	eggShopGui.Parent = playerGui
	Theme.applyScreenSafeArea(eggShopGui)

	local dim = Theme.createDim(eggShopGui, 1)
	dim.Name = "DimBackground"
	dim.Visible = false

	eggShopPanel = Theme.createPanel({
		Name = "EggShopPanel", Parent = eggShopGui,
		Size = UDim2.fromOffset(920, 620), Visible = false,
		Bg = EGG_SHOP_PANEL_BG,
	})
	eggShopPanel:SetAttribute("OpenPosition", eggShopPanel.Position)
	local inner = eggShopPanel:FindFirstChild("PanelGradient")
	if inner then
		inner.BackgroundColor3 = EGG_SHOP_INNER_BG
		applyEggShopPanelGradient(inner)
	end

	Theme.createCloseButton(eggShopPanel, function()
		closeEggShop()
	end, 30)

	Theme.createText({
		Name = "Title", Parent = eggShopPanel,
		Text = "Egg Shop",
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(20, 14),
		TextSize = 28, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight, ZIndex = 9,
	})
	Theme.createText({
		Name = "Subtitle", Parent = eggShopPanel,
		Text = "Purchase eggs to hatch new dragons!",
		Size = UDim2.new(1, -80, 0, 18),
		Position = UDim2.fromOffset(20, 42),
		TextSize = 13, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})

	createEggShopBanner(eggShopPanel)

	local essencePill, essenceValue = Theme.createPremiumResourceCapsule(eggShopPanel, Theme.Icons.Crystal, "EssenceValue", 1)
	essencePill.Name = "EssencePill"
	essencePill.Position = UDim2.new(1, -96, 0, 14)
	essencePill.AnchorPoint = Vector2.new(1, 0)
	essencePill.ZIndex = 12
	eggShopEssenceLabel = essenceValue

	eggShopOwnedLabel = Theme.createText({
		Name = "OwnedEggs", Parent = eggShopPanel,
		Text = "", Size = UDim2.fromOffset(1, 1), Visible = false,
	})

	local bodyTop = 162
	local bodyBottom = 44

	eggShopList, _ = Theme.createScrollList(
		eggShopPanel,
		UDim2.new(0, 228, 1, -(bodyTop + bodyBottom)),
		UDim2.fromOffset(18, bodyTop),
		8
	)
	eggShopList.Name = "EggList"
	eggShopList.BackgroundColor3 = Color3.fromRGB(16, 22, 42)
	eggShopList.BackgroundTransparency = 0.08
	local listStroke = eggShopList:FindFirstChildOfClass("UIStroke")
	if listStroke then
		listStroke.Color = EGG_SHOP_GOLD_DIM
		listStroke.Transparency = 0.45
	end

	for index, eggType in DragonEggConfig.GetEggOrder() do
		local card = createEggShopCard(eggShopList, eggType)
		card.LayoutOrder = index
	end

	eggShopDetailPanel = Theme.createFrame({
		Name = "EggPreviewPanel", Parent = eggShopPanel,
		Size = UDim2.new(1, -270, 1, -(bodyTop + bodyBottom)),
		Position = UDim2.fromOffset(256, bodyTop),
		Bg = Color3.fromRGB(18, 26, 50), Corner = Theme.Corner.Large, ZIndex = 8,
	})
	Theme.stroke(eggShopDetailPanel, EGG_SHOP_GOLD, 1.8, 0.28)
	Theme.padding(eggShopDetailPanel, 16, 16, 16, 16)
	applyEggShopPanelGradient(eggShopDetailPanel)

	eggShopPreviewShowcase = Theme.createFrame({
		Name = "Showcase", Parent = eggShopDetailPanel,
		Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 0),
		Bg = Color3.fromRGB(12, 18, 36), Corner = Theme.Corner.Medium, ClipsDescendants = true, ZIndex = 9,
	})
	Theme.stroke(eggShopPreviewShowcase, EGG_SHOP_GOLD_DIM, 1.2, 0.55)
	local showcaseGrad = Instance.new("UIGradient")
	showcaseGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 42, 72)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 14, 28)),
	})
	showcaseGrad.Rotation = 90
	showcaseGrad.Parent = eggShopPreviewShowcase

	eggShopPreviewGlow = Theme.createFrame({
		Name = "Glow", Parent = eggShopPreviewShowcase,
		Size = UDim2.fromOffset(170, 170), Position = UDim2.new(0.5, 0, 0.42, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), Bg = Theme.Colors.Crystal, Corner = UDim.new(1, 0),
		BgTransparency = 0.72, ZIndex = 10,
	})
	Theme.createFrame({
		Name = "GlowInner", Parent = eggShopPreviewShowcase,
		Size = UDim2.fromOffset(120, 120), Position = UDim2.new(0.5, 0, 0.42, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), Bg = Theme.Colors.GoldBright, Corner = UDim.new(1, 0),
		BgTransparency = 0.82, ZIndex = 10,
	})

	local pedestal = Theme.createFrame({
		Name = "Pedestal", Parent = eggShopPreviewShowcase,
		Size = UDim2.fromOffset(120, 22), Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1), Bg = Color3.fromRGB(72, 78, 96), Corner = Theme.Corner.Small, ZIndex = 11,
	})
	Theme.stroke(pedestal, EGG_SHOP_GOLD_DIM, 1, 0.5)

	local iconFrame, iconImg = Theme.createIconFrame(eggShopPreviewShowcase, Theme.Icons.Egg, 68, 12)
	iconFrame.Position = UDim2.new(0.5, 0, 0.44, 0)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	iconFrame.BackgroundColor3 = Color3.fromRGB(20, 26, 44)
	eggShopPreviewIcon = iconImg
	eggShopPreviewIconGlow = iconFrame:FindFirstChildOfClass("UIStroke")

	for i = 1, 4 do
		local spark = Theme.createFrame({
			Name = "Spark" .. i, Parent = eggShopPreviewShowcase,
			Size = UDim2.fromOffset(6, 6), Bg = Theme.Colors.GoldBright, Corner = Theme.Corner.Pill,
			BgTransparency = 0.2, ZIndex = 11,
		})
		spark.Position = UDim2.new(0.22 + (i * 0.14), 0, 0.18 + ((i % 2) * 0.08), 0)
	end

	eggShopPreviewName = Theme.createText({
		Name = "PreviewName", Parent = eggShopDetailPanel,
		Text = "Select an egg", Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 106), TextSize = 19, Font = Theme.Fonts.Title,
		Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Center, ZIndex = 10,
	})
	eggShopPreviewDesc = Theme.createText({
		Name = "PreviewDesc", Parent = eggShopDetailPanel,
		Text = "", Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, 130), TextSize = 12, Font = Theme.Fonts.Body,
		Color = Theme.Colors.Text, YAlign = Enum.TextYAlignment.Top, XAlign = Enum.TextXAlignment.Center, ZIndex = 10,
	})
	-- Scrollable so per-egg content (species list + rarity chances + stats) never gets clipped or
	-- overlaps the purchase button below it, regardless of how many dragons/lines a given egg has.
	-- Fixed offset height (not scale-relative) - measured empirically against the purchase button's
	-- actual position so there's no overlap; see PurchaseButton below (anchored 58px from panel bottom).
	eggShopPreviewInfoScroll = Instance.new("ScrollingFrame")
	eggShopPreviewInfoScroll.Name = "PreviewInfoScroll"
	eggShopPreviewInfoScroll.Size = UDim2.new(1, 0, 0, 64)
	eggShopPreviewInfoScroll.Position = UDim2.fromOffset(0, 166)
	eggShopPreviewInfoScroll.BackgroundTransparency = 1
	eggShopPreviewInfoScroll.BorderSizePixel = 0
	eggShopPreviewInfoScroll.ScrollBarThickness = 5
	eggShopPreviewInfoScroll.ScrollBarImageColor3 = EGG_SHOP_GOLD_DIM
	eggShopPreviewInfoScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	eggShopPreviewInfoScroll.CanvasSize = UDim2.fromOffset(0, 0)
	eggShopPreviewInfoScroll.ZIndex = 10
	eggShopPreviewInfoScroll.Parent = eggShopDetailPanel
	local infoLayout = Instance.new("UIListLayout")
	infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	infoLayout.Padding = UDim.new(0, 8)
	infoLayout.Parent = eggShopPreviewInfoScroll

	eggShopPurchaseButton = Theme.createButton({
		Name = "PurchaseButton", Parent = eggShopDetailPanel,
		Text = "Purchase Egg", Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.new(0.5, 0, 1, -58), AnchorPoint = Vector2.new(0.5, 1),
		Bg = Theme.Colors.Success, TextSize = 18, ZIndex = 12, Stroke = true,
		OnClick = function()
			if not selectedEggType then
				return
			end
			local eggInfo = DragonEggConfig.GetEggTypeInfo(selectedEggType)
			if eggInfo.Reserved then
				setEggShopStatus(eggInfo.DisplayName .. " is reserved for future dragons.")
				return
			end
			if eggInfo.IsFeatured and not DragonEggConfig.IsFeaturedEggActive() then
				setEggShopStatus(eggInfo.DisplayName .. " returns in " .. formatFeaturedCountdown(DragonEggConfig.GetFeaturedEggCountdown()) .. ".")
				return
			end
			if canAffordEgg(eggInfo) then
				setEggShopStatus("Purchasing " .. eggInfo.DisplayName .. "...")
				BuyDragonEgg:FireServer(selectedEggType)
			else
				setEggShopStatus("Need " .. getEggCostText(eggInfo) .. ". Keep collecting!")
			end
		end,
	})
	applyPurchaseButtonGradient(eggShopPurchaseButton, true)

	local bulkAutoRow = Theme.createFrame({
		Name = "BulkAutoRow", Parent = eggShopDetailPanel,
		Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 234),
		BgTransparency = 1, ZIndex = 12,
	})
	local bulkAutoLayout = Instance.new("UIListLayout")
	bulkAutoLayout.FillDirection = Enum.FillDirection.Horizontal
	bulkAutoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bulkAutoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	bulkAutoLayout.Padding = UDim.new(0, 8)
	bulkAutoLayout.Parent = bulkAutoRow

	eggShopBulkButton = Theme.createButton({
		Name = "BulkButton", Parent = bulkAutoRow, Text = "Open x10",
		Size = UDim2.fromOffset(150, 34), Bg = Theme.Colors.Crystal, TextSize = 13, ZIndex = 13,
		OnClick = function()
			if not selectedEggType then
				return
			end
			local eggInfo = DragonEggConfig.GetEggTypeInfo(selectedEggType)
			if eggInfo.Reserved then
				setEggShopStatus(eggInfo.DisplayName .. " is reserved for future dragons.")
				return
			end
			if eggInfo.IsFeatured and not DragonEggConfig.IsFeaturedEggActive() then
				setEggShopStatus(eggInfo.DisplayName .. " returns in " .. formatFeaturedCountdown(DragonEggConfig.GetFeaturedEggCountdown()) .. ".")
				return
			end
			setEggShopStatus("Opening 10 " .. eggInfo.DisplayName .. "s...")
			BulkHatchEggs:FireServer(selectedEggType, 10)
		end,
	})

	eggShopAutoButton = Theme.createButton({
		Name = "AutoHatchButton", Parent = bulkAutoRow, Text = "Auto-Hatch: OFF",
		Size = UDim2.fromOffset(150, 34), Bg = Theme.Colors.NavyEdge, TextSize = 13, ZIndex = 13,
		OnClick = function()
			if not player:GetAttribute("OwnsAutoHatch") then
				if AUTO_HATCH_PASS and AUTO_HATCH_PASS.Id > 0 then
					MarketplaceService:PromptGamePassPurchase(player, AUTO_HATCH_PASS.Id)
				else
					setEggShopStatus("Auto-Hatch Pass coming soon.")
				end
				return
			end
			if not selectedEggType then
				setEggShopStatus("Select an egg to auto-hatch first.")
				return
			end
			autoHatchEnabled = not autoHatchEnabled
			SetAutoHatch:FireServer(selectedEggType, autoHatchEnabled)
			eggShopAutoButton.Text = autoHatchEnabled and "Auto-Hatch: ON" or "Auto-Hatch: OFF"
			eggShopAutoButton.BackgroundColor3 = autoHatchEnabled and Theme.Colors.Success or Theme.Colors.NavyEdge
		end,
	})

	local priceRow = Theme.createFrame({
		Name = "PurchasePriceRow", Parent = eggShopDetailPanel,
		Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1), BgTransparency = 1, ZIndex = 12,
	})
	local priceLayout = Instance.new("UIListLayout")
	priceLayout.FillDirection = Enum.FillDirection.Horizontal
	priceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	priceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	priceLayout.Padding = UDim.new(0, 6)
	priceLayout.Parent = priceRow
	local priceIcon = Instance.new("ImageLabel")
	priceIcon.Name = "PriceIcon"
	priceIcon.Size = UDim2.fromOffset(18, 18)
	priceIcon.BackgroundTransparency = 1
	priceIcon.Image = Theme.Icons.Crystal
	priceIcon.ScaleType = Enum.ScaleType.Fit
	priceIcon.LayoutOrder = 1
	priceIcon.ZIndex = 13
	priceIcon.Parent = priceRow
	eggShopPurchasePriceText = Theme.createText({
		Name = "PurchasePrice", Parent = priceRow,
		Text = "0 Essence", TextSize = 15, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.CrystalSoft, Size = UDim2.fromOffset(0, 20),
		AutoSize = Enum.AutomaticSize.X, XAlign = Enum.TextXAlignment.Left, ZIndex = 13,
	})
	eggShopPreviewCost = eggShopPurchasePriceText

	eggShopStatusLabel = Theme.createText({
		Name = "Status", Parent = eggShopPanel,
		Text = "Interact with the Egg Pedestal to open this shop.",
		Size = UDim2.new(1, -36, 0, 28), Position = UDim2.new(0, 18, 1, -34),
		TextSize = 12, Font = Theme.Fonts.Regular, Color = Color3.fromRGB(175, 188, 215),
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeEggShop()
		end
	end)

	updateEggShopUI()
	selectEggShopEgg(DragonEggConfig.GetEggOrder()[1])
end

local function openEggShop(message)
	createEggShopUI()
	eggShopGui.Enabled = true
	local syncedEssence = getCurrentEssence()
	currentEssence = syncedEssence
	eggShopState.essence = syncedEssence
	local dim = eggShopGui and eggShopGui:FindFirstChild("DimBackground")
	local opening = eggShopPanel and not eggShopPanel.Visible
	if opening then
		Theme.raiseModalGui(eggShopGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(eggShopGui.Name)
		end
	end
	Theme.tweenOpen(eggShopPanel, dim)
	selectEggShopEgg(DragonEggConfig.GetEggOrder()[1])
	setEggShopStatus(message or "Choose an egg to purchase and hatch a dragon.")
	updateEggShopUI()
end

local function findMergeDragon(dragonId)
	for _, dragon in mergeState.dragons do
		if dragon.id == dragonId then
			return dragon
		end
	end
	return nil
end

local function isMergeSelected(dragonId)
	return table.find(selectedMergeIds, dragonId) ~= nil
end

local function getSelectedMergeDragons()
	local selected = {}
	for _, dragonId in selectedMergeIds do
		local dragon = findMergeDragon(dragonId)
		if dragon then
			table.insert(selected, dragon)
		end
	end
	return selected
end

local function getMergeSelectionPreview()
	local selected = getSelectedMergeDragons()
	if #selected == 0 then
		return nil, "Select 3 matching dragons."
	end
	if #selected < 3 then
		return selected[1], "Select " .. tostring(3 - #selected) .. " more matching dragon(s)."
	end
	local first = selected[1]
	for _, dragon in selected do
		if dragon.dragonType ~= first.dragonType or dragon.rarity ~= first.rarity or dragon.evolutionLevel ~= first.evolutionLevel then
			return first, "Selected dragons must match type, rarity, and evolution."
		end
	end
	-- The server only merges dragons that are actively equipped (it needs a live world model to
	-- work with) and silently rejects anything else with "One selected dragon is unavailable" - a
	-- message easy to miss. Without this check the preview would say "Ready to merge" and light up
	-- the button green for 3 matching storage dragons, and clicking it would just do nothing,
	-- looking exactly like a broken button.
	for _, dragon in selected do
		if not dragon.isEquipped then
			return first, "All 3 dragons must be active (not in storage) to merge - equip them first."
		end
	end
	if first.evolutionLevel >= (mergeState.maxEvolutionLevel or 5) then
		return first, "This dragon is already max evolution."
	end
	if (mergeState.essence or 0) < (first.mergeCost or 0) then
		return first, "Need " .. formatNumber(first.mergeCost or 0) .. " Dragon Essence."
	end
	return first, "Ready to merge into " .. (first.displayName or first.dragonType) .. " " .. DragonEggConfig.GetEvolutionStars((first.evolutionLevel or 0) + 1)
end

local function formatMergeStats(stats)
	if not stats then
		return "Stats unavailable"
	end
	return table.concat({
		"Harvest Speed: x" .. string.format("%.2f", stats.HarvestSpeed or 1),
		"Flight Speed: " .. string.format("%.1f", stats.FlightSpeed or 0),
		"Carry Capacity: " .. tostring(stats.CarryCapacity or 0),
		"Critical Chance: " .. string.format("%.0f%%", (stats.CriticalHarvestChance or 0) * 100),
		"Luck: x" .. string.format("%.2f", stats.Luck or 1),
		"XP Gain: x" .. string.format("%.2f", stats.XpGainMultiplier or 1),
	}, "\n")
end

-- Cheap: slot text, existing row highlights, preview/stats/cost/status, and the merge button
-- state. Deliberately does NOT touch the dragon list rows - call updateMergeUI() instead when
-- mergeState.dragons itself changes (new/removed/changed dragon from a server payload). Selecting
-- or deselecting a dragon, or essence changing from background harvesting, doesn't change which
-- dragons exist, so it never needs to touch the rows themselves.
local function updateMergeSelectionUI()
	if not mergePanel then
		return
	end
	for index, slot in mergeSlots do
		local dragon = selectedMergeIds[index] and findMergeDragon(selectedMergeIds[index])
		slot.Text = dragon and ((dragon.displayName or dragon.dragonType) .. "\n" .. (dragon.rarity or "Common") .. " " .. (dragon.stars or "")) or ("Slot " .. tostring(index))
	end

	for dragonId, row in mergeListRows do
		Theme.setListRowSelected(row, isMergeSelected(dragonId), Theme.Colors.Crystal)
	end

	local previewDragon, message = getMergeSelectionPreview()
	if previewDragon then
		local nextStars = DragonEggConfig.GetEvolutionStars((previewDragon.evolutionLevel or 0) + 1)
		mergePreview.Text = (previewDragon.displayName or previewDragon.dragonType) .. " " .. nextStars .. "\n" .. (previewDragon.rarity or "Common")
		mergeStatsLabel.Text = "Current Stats\n" .. formatMergeStats(previewDragon.stats) .. "\n\nAfter Merge\n" .. formatMergeStats(previewDragon.nextStats)
		mergeCostLabel.Text = "Merge Cost: " .. formatNumber(previewDragon.mergeCost or 0) .. " Dragon Essence"
	else
		mergePreview.Text = "Evolved dragon preview"
		mergeStatsLabel.Text = "Select three identical dragons to preview the evolved stats."
		mergeCostLabel.Text = "Merge Cost: -"
	end
	mergeStatusLabel.Text = message or ""
	local canMerge = #selectedMergeIds == 3 and previewDragon ~= nil and message and string.find(message, "Ready") == 1
	mergeButton.Active = canMerge
	mergeButton.AutoButtonColor = canMerge
	mergeButton.BackgroundColor3 = canMerge and Theme.Colors.Success or Theme.Colors.NavyEdge
	mergeButton.TextColor3 = canMerge and Theme.Colors.TextLight or Theme.Colors.TextMuted
	local mergeStroke = mergeButton:FindFirstChildOfClass("UIStroke")
	if mergeStroke then
		mergeStroke.Color = canMerge and Theme.Colors.GoldBright or Theme.Colors.Gold
		mergeStroke.Transparency = canMerge and 0.2 or 0.5
	end
end

-- Full rebuild: destroys and recreates every row in the dragon list, so it's only for when
-- mergeState.dragons itself changed. This used to also run on every single row click AND on every
-- HarvestUIUpdate tick (i.e. continuously while dragons harvest in the background) - destroying and
-- recreating potentially hundreds of rows several times a second, which is exactly what looked like
-- the merge list "flickering" and made clicking a specific dragon unreliable (a click landing mid-
-- rebuild can miss the row entirely, or the list can rescroll out from under the player's cursor).
local function updateMergeUI()
	if not mergePanel then
		return
	end

	if mergeList then
		for _, child in mergeList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		mergeListRows = {}
		for index, dragon in mergeState.dragons do
			local row = Theme.createListRow(mergeList, {
				Name = "DragonRow_" .. tostring(dragon.id),
				Text = (dragon.displayName or dragon.dragonType) .. "  " .. (dragon.rarity or "Common") .. " " .. (dragon.stars or "") .. "\nLv. " .. tostring(dragon.level or 1) .. "  Matching: " .. tostring(dragon.matchingCount or 0) .. (dragon.mergeAvailable and "  Can Merge" or ""),
				Height = 58,
				Bg = dragon.mergeAvailable and Theme.Colors.NavyEdge or Theme.Colors.NavyDeep,
				LayoutOrder = index,
				OnClick = function()
					local selectedIndex = table.find(selectedMergeIds, dragon.id)
					if selectedIndex then
						table.remove(selectedMergeIds, selectedIndex)
					elseif #selectedMergeIds < 3 then
						table.insert(selectedMergeIds, dragon.id)
					end
					updateMergeSelectionUI()
				end,
			})
			Theme.setListRowSelected(row, isMergeSelected(dragon.id), Theme.Colors.Crystal)
			mergeListRows[dragon.id] = row
		end
	end

	updateMergeSelectionUI()
end

local function applyMergePayload(payload)
	if typeof(payload) ~= "table" then
		return
	end
	mergeState.essence = payload.essence or mergeState.essence
	mergeState.dragons = payload.dragons or mergeState.dragons
	mergeState.mergeStats = payload.mergeStats or mergeState.mergeStats
	mergeState.maxEvolutionLevel = payload.maxEvolutionLevel or mergeState.maxEvolutionLevel
	if payload.message and mergeStatusLabel then
		mergeStatusLabel.Text = payload.message
	end
	local availableIds = {}
	for _, dragon in mergeState.dragons do
		availableIds[dragon.id] = true
	end
	for index = #selectedMergeIds, 1, -1 do
		if not availableIds[selectedMergeIds[index]] then
			table.remove(selectedMergeIds, index)
		end
	end
	updateMergeUI()
end

local function createMergeUI()
	if mergeGui then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	mergeGui = Instance.new("ScreenGui")
	mergeGui.Name = "DragonMergeUI"
	mergeGui.ResetOnSpawn = false
	mergeGui.IgnoreGuiInset = true
	mergeGui.DisplayOrder = 35
	mergeGui.Enabled = false
	mergeGui.Parent = playerGui

	local dim = Theme.createDim(mergeGui, 1)
	dim.Name = "DimBackground"
	dim.Visible = false

	mergePanel = Theme.createPanel({
		Name = "DragonMergePanel", Parent = mergeGui,
		Size = UDim2.fromOffset(900, 610), Visible = false,
	})
	mergePanel:SetAttribute("OpenPosition", mergePanel.Position)
	Theme.createCloseButton(mergePanel, function()
		closeMergeUI()
	end, 30)
	Theme.createWindowHeader(mergePanel, "Dragon Merge", "Combine three matching dragons to evolve", 8)

	mergeList, _ = Theme.createScrollList(
		mergePanel,
		UDim2.fromOffset(330, 486),
		UDim2.fromOffset(18, 76),
		7
	)
	mergeList.Name = "OwnedDragons"

	for index = 1, 3 do
		local slot = Instance.new("TextButton")
		slot.Name = "MergeSlot" .. tostring(index)
		slot.Size = UDim2.fromOffset(158, 68)
		slot.Position = UDim2.fromOffset(374 + (index - 1) * 168, 82)
		slot.BackgroundColor3 = Theme.Colors.NavyEdge
		slot.BorderSizePixel = 0
		slot.AutoButtonColor = false
		slot.Font = Theme.Fonts.Bold
		slot.Text = "Slot " .. tostring(index)
		slot.TextColor3 = Theme.Colors.Text
		slot.TextSize = 13
		slot.TextWrapped = true
		slot.ZIndex = 7
		slot.Parent = mergePanel
		Theme.corner(slot, Theme.Corner.Medium)
		Theme.stroke(slot, Theme.Colors.Gold, 1.5, 0.45)
		Theme.attachHover(slot, Theme.Colors.NavyEdge)
		slot.Activated:Connect(function()
			table.remove(selectedMergeIds, index)
			updateMergeSelectionUI()
		end)
		mergeSlots[index] = slot
	end

	local previewPanel = Theme.createDetailPanel(mergePanel, UDim2.fromOffset(486, 72), UDim2.fromOffset(374, 168), 7)
	previewPanel.Name = "PreviewPanel"
	mergePreview = Theme.createText({
		Name = "PreviewText", Parent = previewPanel,
		Text = "Evolved dragon preview", Size = UDim2.fromScale(1, 1),
		TextSize = 20, Font = Theme.Fonts.Title, Color = Theme.Colors.CrystalSoft,
		XAlign = Enum.TextXAlignment.Center, YAlign = Enum.TextYAlignment.Center,
	})

	local statsPanel = Theme.createDetailPanel(mergePanel, UDim2.fromOffset(486, 220), UDim2.fromOffset(374, 252), 7)
	statsPanel.Name = "StatsPanel"
	mergeStatsLabel = Theme.createText({
		Name = "StatsText", Parent = statsPanel,
		Text = "Select three identical dragons to preview the evolved stats.", Size = UDim2.fromScale(1, 1),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.Text,
		YAlign = Enum.TextYAlignment.Top,
	})

	mergeCostLabel = Theme.createText({
		Name = "MergeCost", Parent = mergePanel,
		Text = "Merge Cost: -", Size = UDim2.fromOffset(486, 28),
		Position = UDim2.fromOffset(374, 486), TextSize = 16, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextGold, XAlign = Enum.TextXAlignment.Center, ZIndex = 7,
	})

	mergeButton = Theme.createButton({
		Name = "MergeButton", Parent = mergePanel, Text = "Merge Dragons",
		Size = UDim2.fromOffset(238, 48), Position = UDim2.fromOffset(374, 532),
		Bg = Theme.Colors.Success, TextSize = 18, ZIndex = 8,
	})

	mergeCancelButton = Theme.createSecondaryButton({
		Name = "CancelButton", Parent = mergePanel, Text = "Cancel",
		Size = UDim2.fromOffset(238, 48), Position = UDim2.fromOffset(622, 532),
		TextSize = 18, ZIndex = 8,
	})

	mergeStatusLabel = Theme.createText({
		Name = "Status", Parent = mergePanel, Text = "",
		Size = UDim2.fromOffset(486, 28), Position = UDim2.fromOffset(374, 58),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 7,
	})

	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeMergeUI()
		end
	end)
	mergeCancelButton.Activated:Connect(function()
		selectedMergeIds = {}
		updateMergeSelectionUI()
	end)
	mergeButton.Activated:Connect(function()
		if mergeButton.Active then
			mergeStatusLabel.Text = "Merging dragons..."
			MergeDragons:FireServer(selectedMergeIds)
		end
	end)
	updateMergeUI()
end

local function openMergeUI(message)
	createMergeUI()
	mergeGui.Enabled = true
	selectedMergeIds = {}
	local success, payload = pcall(function()
		return RequestDragonMergeData:InvokeServer()
	end)
	if success then
		applyMergePayload(payload)
	elseif mergeStatusLabel then
		mergeStatusLabel.Text = "Could not load merge data."
	end
	local dim = mergeGui and mergeGui:FindFirstChild("DimBackground")
	local opening = mergePanel and not mergePanel.Visible
	if opening then
		Theme.raiseModalGui(mergeGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(mergeGui.Name)
		end
	end
	Theme.tweenOpen(mergePanel, dim)
	mergeStatusLabel.Text = message or mergeStatusLabel.Text
	updateMergeUI()
end

local function playMergeSuccessVFX(result)
	local position = result and result.position
	if typeof(position) ~= "Vector3" then
		position = player.Character and player.Character:GetPivot().Position or Vector3.new(0, 5, 0)
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 4, 0))
	anchor.Parent = workspace
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.fromRGB(130, 220, 255), Color3.fromRGB(255, 245, 170))
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
	burst.Lifetime = NumberRange.new(0.7, 1.4)
	burst.Speed = NumberRange.new(10, 22)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 1
	burst.Parent = anchor
	burst:Emit(90)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(160, 230, 255)
	light.Brightness = 5
	light.Range = 24
	light.Parent = anchor
	local originalCFrame = camera.CFrame
	for _ = 1, 8 do
		camera.CFrame = originalCFrame * CFrame.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0)
		task.wait(0.03)
	end
	camera.CFrame = originalCFrame
	task.delay(1.8, function()
		anchor:Destroy()
	end)
end

_G.DragonIslandOpenEggShop = openEggShop
_G.DragonIslandCloseEggShop = closeEggShop
_G.DragonIslandOpenMergeUI = openMergeUI
_G.DragonIslandCloseMergeUI = closeMergeUI

UIBridge.RegisterPanel("EggShop", { Open = openEggShop, Close = closeEggShop })
UIBridge.RegisterPanel("DragonMerge", { Open = openMergeUI, Close = closeMergeUI })

createEggShopUI()
createMergeUI()

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local ownerUserId = prompt.Parent and prompt.Parent:GetAttribute("OwnerUserId")
	if ownerUserId and ownerUserId ~= player.UserId then
		return
	end
	if prompt.Name == "EggShopPrompt" then
		openEggShop("Welcome to the Dragon Egg Shop.")
	elseif prompt.Name == "DragonMergePrompt" then
		openMergeUI("Dragon Academy merge chamber ready.")
	end
end)

local function closeBulkResultsUI()
	if not bulkResultsGui or not bulkResultsPanel then
		return
	end
	local dim = bulkResultsGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(bulkResultsGui, bulkResultsPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(bulkResultsGui.Name)
		end
	end)
end

local function createBulkResultsUI()
	if bulkResultsGui then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	bulkResultsGui = Instance.new("ScreenGui")
	bulkResultsGui.Name = "BulkHatchResultsUI"
	bulkResultsGui.ResetOnSpawn = false
	bulkResultsGui.IgnoreGuiInset = true
	bulkResultsGui.DisplayOrder = 40
	bulkResultsGui.Enabled = false
	bulkResultsGui.Parent = playerGui

	local dim = Theme.createDim(bulkResultsGui, 1)
	dim.Name = "DimBackground"
	dim.Visible = false

	bulkResultsPanel = Theme.createPanel({
		Name = "BulkResultsPanel", Parent = bulkResultsGui,
		Size = UDim2.fromOffset(480, 480), Visible = false,
	})
	Theme.createCloseButton(bulkResultsPanel, function()
		closeBulkResultsUI()
	end, 30)
	Theme.createWindowHeader(bulkResultsPanel, "Hatch Results", "Here's what you got", 8)

	bulkResultsSummary = Theme.createText({
		Name = "Summary", Parent = bulkResultsPanel, Text = "",
		Size = UDim2.new(1, -32, 0, 24), Position = UDim2.fromOffset(16, 62),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	bulkResultsList = Theme.createScrollList(
		bulkResultsPanel,
		UDim2.fromOffset(448, 350),
		UDim2.fromOffset(16, 96),
		7
	)

	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeBulkResultsUI()
		end
	end)
end

local function openBulkResultsUI(payload)
	createBulkResultsUI()
	bulkResultsGui.Enabled = true
	local dim = bulkResultsGui:FindFirstChild("DimBackground")
	local opening = bulkResultsPanel and not bulkResultsPanel.Visible
	if opening then
		Theme.raiseModalGui(bulkResultsGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(bulkResultsGui.Name)
		end
	end
	Theme.tweenOpen(bulkResultsPanel, dim)

	local currency = payload.isGemEgg and "Gems" or "Dragon Essence"
	bulkResultsSummary.Text = string.format(
		"%s x%d - spent %s %s",
		payload.eggDisplayName or "Eggs",
		payload.granted or 0,
		formatNumber(payload.totalCost or 0),
		currency
	)
	if (payload.granted or 0) < (payload.requested or 0) then
		bulkResultsSummary.Text ..= string.format(" (%d requested)", payload.requested or 0)
	end

	for _, child in bulkResultsList:GetChildren() do
		if string.sub(child.Name, 1, 10) == "ResultRow_" then
			child:Destroy()
		end
	end
	for index, result in payload.results or {} do
		local rarityInfo = DragonEggConfig.GetRarityInfo(result.rarity)
		Theme.createListRow(bulkResultsList, {
			Name = "ResultRow_" .. tostring(index),
			Text = (result.displayName or result.dragonType or "Dragon") .. "   -   " .. (result.rarity or "Common"),
			Height = 46,
			LayoutOrder = index,
			StrokeColor = rarityInfo and rarityInfo.Color or nil,
		})
	end
end

BulkEggHatched.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	openBulkResultsUI(payload)
end)

EggShopUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	eggShopState.essence = payload.essence or eggShopState.essence
	eggShopState.ownedEggs = payload.ownedEggs or eggShopState.ownedEggs
	eggShopState.eggStats = payload.eggStats or eggShopState.eggStats
	updateEggShopUI()
	if payload.message then
		setEggShopStatus(payload.message)
	end
end)

DragonMergeUpdate.OnClientEvent:Connect(function(payload)
	applyMergePayload(payload)
	if payload and payload.result and payload.result.success then
		selectedMergeIds = {}
		playMergeSuccessVFX(payload.result)
	end
end)

local updateAssignmentVisuals

local function createNodeBillboard(node)
	if nodeBillboards[node] then
		return
	end

	local anchor = node:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NodeHealthBar"
	billboard.Size = UDim2.fromOffset(104, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local assignmentLabel = Instance.new("TextLabel")
	assignmentLabel.Name = "AssignmentLabel"
	assignmentLabel.Size = UDim2.new(1, 0, 0, 18)
	assignmentLabel.BackgroundTransparency = 1
	assignmentLabel.Font = Enum.Font.GothamBold
	assignmentLabel.Text = ""
	assignmentLabel.TextColor3 = Color3.fromRGB(255, 225, 100)
	assignmentLabel.TextScaled = true
	assignmentLabel.TextStrokeTransparency = 0.35
	assignmentLabel.Parent = billboard

	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 14)
	back.Position = UDim2.fromOffset(0, 20)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	back.BorderSizePixel = 0
	back.Parent = billboard

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 4)
	backCorner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 220, 255)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local effectLabel = Instance.new("TextLabel")
	effectLabel.Name = "EffectLabel"
	effectLabel.Size = UDim2.new(1, 0, 0, 14)
	effectLabel.Position = UDim2.fromOffset(0, 34)
	effectLabel.BackgroundTransparency = 1
	effectLabel.Font = Enum.Font.GothamBold
	effectLabel.Text = ""
	effectLabel.TextColor3 = Color3.fromRGB(180, 230, 255)
	effectLabel.TextScaled = true
	effectLabel.TextStrokeTransparency = 0.35
	effectLabel.Parent = billboard

	local function updateEffects()
		local brittle = tonumber(node:GetAttribute("BrittleStacks")) or 0
		local poisoned = node:GetAttribute("Poisoned") == true
		if brittle > 0 then
			effectLabel.Text = "Brittle x" .. tostring(brittle)
			effectLabel.TextColor3 = Color3.fromRGB(140, 220, 255)
		elseif poisoned then
			effectLabel.Text = "Poisoned"
			effectLabel.TextColor3 = Color3.fromRGB(130, 230, 90)
		else
			effectLabel.Text = ""
		end
	end

	local function updateHealth()
		local health = node:GetAttribute("Health") or HarvestConfig.NodeMaxHealth
		local maxHealth = node:GetAttribute("MaxHealth") or HarvestConfig.NodeMaxHealth
		local ratio = math.clamp(health / maxHealth, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		billboard.Enabled = not node:GetAttribute("Depleted")
	end

	node:GetAttributeChangedSignal("Health"):Connect(updateHealth)
	node:GetAttributeChangedSignal("BrittleStacks"):Connect(updateEffects)
	node:GetAttributeChangedSignal("Poisoned"):Connect(updateEffects)
	node:GetAttributeChangedSignal("Depleted"):Connect(function()
		updateHealth()
		updateEffects()
		if updateAssignmentVisuals then
			updateAssignmentVisuals()
		end
	end)
	updateHealth()
	updateEffects()

	nodeBillboards[node] = {
		billboard = billboard,
		assignmentLabel = assignmentLabel,
		effectLabel = effectLabel,
		assignedCount = 0,
	}
	if updateAssignmentVisuals then
		updateAssignmentVisuals()
	end
end

for _, node in nodesFolder:GetChildren() do
	if isOwnedNode(node) then
		createNodeBillboard(node)
	end
end

nodesFolder.ChildAdded:Connect(function(node)
	task.spawn(function()
		local startedAt = os.clock()
		while node.Parent and not isOwnedNode(node) and os.clock() - startedAt < 5 do
			task.wait(0.1)
		end
		if isOwnedNode(node) then
			createNodeBillboard(node)
		end
	end)
end)

local function applyUnlockedBiomes(unlockedList)
	local unlocked = {}
	if typeof(unlockedList) == "table" then
		for _, islandId in unlockedList do
			if typeof(islandId) == "string" then
				unlocked[islandId] = true
			end
		end
	end
	_G.DragonIslandUnlockedBiomes = unlocked
	for _, node in nodesFolder:GetChildren() do
		if node:GetAttribute("BiomeResource") == true and isOwnedNode(node) and not nodeBillboards[node] then
			createNodeBillboard(node)
		end
	end
end

IslandUnlockState.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" then
		applyUnlockedBiomes(payload.unlocked)
	end
end)

local ABILITY_VFX_COLORS = {
	Inferno = Color3.fromRGB(255, 120, 60),
	ChainLightning = Color3.fromRGB(120, 200, 255),
	NaturesBlessing = Color3.fromRGB(90, 220, 120),
	CrystalMaster = Color3.fromRGB(180, 120, 255),
	FrozenTouch = Color3.fromRGB(120, 220, 255),
	Corrosion = Color3.fromRGB(120, 220, 80),
	MoltenCore = Color3.fromRGB(255, 140, 60),
	OceanBlessing = Color3.fromRGB(70, 170, 255),
	VoidRift = Color3.fromRGB(140, 80, 220),
	Starfall = Color3.fromRGB(255, 230, 150),
	RoyalBlessing = Color3.fromRGB(255, 215, 130),
}

local function emitBurst(parent, color, count, size)
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(color)
	burst.Size = NumberSequence.new(size or 0.6, 0)
	burst.Lifetime = NumberRange.new(0.35, 0.75)
	burst.Rate = 0
	burst.Speed = NumberRange.new(5, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 1
	burst.Parent = parent
	burst:Emit(count or 14)
	task.delay(1, function()
		if burst.Parent then
			burst:Destroy()
		end
	end)
end

local function playAbilityVFX(dragonModel, node, vfxTag)
	if typeof(vfxTag) ~= "string" or vfxTag == "" then
		return
	end

	local color = ABILITY_VFX_COLORS[vfxTag] or Color3.fromRGB(255, 220, 120)
	local dragonRoot = dragonModel and dragonModel:FindFirstChild("DragonRoot")
	local nodePart = node and node:FindFirstChildWhichIsA("BasePart", true)

	if dragonRoot then
		emitBurst(dragonRoot, color, 16, 0.7)
	end
	if nodePart then
		emitBurst(nodePart, color, 20, 0.85)
	end

	if vfxTag == "ChainLightning" and dragonRoot and nodePart then
		local attachment0 = Instance.new("Attachment")
		attachment0.Parent = dragonRoot
		local attachment1 = Instance.new("Attachment")
		attachment1.Parent = nodePart
		local arc = Instance.new("Beam")
		arc.Attachment0 = attachment0
		arc.Attachment1 = attachment1
		arc.Color = ColorSequence.new(color)
		arc.Width0 = 0.5
		arc.Width1 = 1.2
		arc.LightEmission = 1
		arc.FaceCamera = true
		arc.Parent = dragonRoot
		task.delay(0.25, function()
			arc:Destroy()
			attachment0:Destroy()
			attachment1:Destroy()
		end)
	elseif vfxTag == "CrystalMaster" and nodePart then
		emitBurst(nodePart, color, 28, 1.1)
	end
end

local function playHarvestVFX(dragonModel, node, vfxTag)
	playAbilityVFX(dragonModel, node, vfxTag)
	local dragonRoot = dragonModel and dragonModel:FindFirstChild("DragonRoot")
	local nodePart = node and node:FindFirstChildWhichIsA("BasePart", true)
	if not dragonRoot or not nodePart then
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Parent = dragonRoot

	local attachment1 = Instance.new("Attachment")
	attachment1.Parent = nodePart

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80))
	local effectScale = HarvestConfig.DragonScaleMultiplier
	beam.Width0 = 0.4 * effectScale
	beam.Width1 = 0.8 * effectScale
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Parent = dragonRoot

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 220, 100))
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Lifetime = NumberRange.new(0.3, 0.6)
	burst.Rate = 0
	burst.Speed = NumberRange.new(4, 8)
	burst.SpreadAngle = Vector2.new(30, 30)
	burst.LightEmission = 1
	burst.Parent = nodePart
	burst:Emit(12)

	for _, part in node:GetDescendants() do
		if part:IsA("BasePart") then
			local originalMaterial = part.Material
			local originalSize = part.Size
			part.Material = Enum.Material.Neon
			local pulse = TweenService:Create(part, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = originalSize * 1.15,
			})
			pulse:Play()
			pulse.Completed:Connect(function()
				local shrink = TweenService:Create(part, TweenInfo.new(0.15), {
					Size = originalSize,
				})
				shrink:Play()
				task.delay(0.2, function()
					if part.Parent then
						part.Material = originalMaterial
					end
				end)
			end)
		end
	end

	task.delay(0.35, function()
		beam:Destroy()
		attachment0:Destroy()
		attachment1:Destroy()
		burst:Destroy()
	end)
end

local function shakeCamera(intensity, duration)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if elapsed >= duration then
			connection:Disconnect()
			return
		end
		local decay = 1 - (elapsed / duration)
		local offset = Vector3.new(
			(math.random() - 0.5) * intensity * decay,
			(math.random() - 0.5) * intensity * decay,
			(math.random() - 0.5) * intensity * 0.5 * decay
		)
		camera.CFrame = camera.CFrame * CFrame.new(offset)
	end)
end

local function playDepletionVFX(node)
	local nodePart = node and node:FindFirstChildWhichIsA("BasePart", true)
	if not nodePart then
		return
	end

	local explosion = Instance.new("ParticleEmitter")
	explosion.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 180, 80)),
	})
	explosion.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0),
	})
	explosion.Lifetime = NumberRange.new(0.5, 1.2)
	explosion.Speed = NumberRange.new(8, 18)
	explosion.SpreadAngle = Vector2.new(180, 180)
	explosion.Rate = 0
	explosion.LightEmission = 1
	explosion.Parent = nodePart
	explosion:Emit(40)

	shakeCamera(0.6, 0.4)

	task.delay(1.5, function()
		explosion:Destroy()
	end)
end

HarvestHit.OnClientEvent:Connect(function(dragonModel, node, amount, isCritical, vfxTag)
	playHarvestVFX(dragonModel, node, vfxTag)
	if dragonModel and dragonModel.Parent and typeof(amount) == "number" then
		local root = dragonModel:FindFirstChild("DragonRoot")
		if root then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "HarvestAmountPopup"
			billboard.Size = UDim2.fromOffset(120, 34)
			billboard.StudsOffset = Vector3.new(0, 6.5, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = root

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			local prefix = isCritical and "CRIT +" or "+"
			if typeof(vfxTag) == "string" and vfxTag == "CrystalMaster" then
				prefix = "RESONANCE +"
			elseif typeof(vfxTag) == "string" and vfxTag == "ChainLightning" then
				prefix = "CHAIN +"
			elseif typeof(vfxTag) == "string" and vfxTag == "OceanBlessing" then
				prefix = "SURGE +"
			end
			label.Text = prefix .. tostring(amount)
			local abilityColor = typeof(vfxTag) == "string" and ABILITY_VFX_COLORS[vfxTag]
			label.TextColor3 = abilityColor or (isCritical and Color3.fromRGB(255, 205, 75) or Color3.fromRGB(140, 255, 170))
			label.TextSize = isCritical and 22 or 18
			label.TextStrokeTransparency = 0.35
			label.Parent = billboard

			local rise = TweenService:Create(billboard, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffset = Vector3.new(0, 8, 0),
			})
			rise:Play()
			task.delay(0.85, function()
				if billboard.Parent then
					billboard:Destroy()
				end
			end)
		end
	end
end)

NodeDepleted.OnClientEvent:Connect(function(node)
	playDepletionVFX(node)
end)

HarvestUIUpdate.OnClientEvent:Connect(function(essence)
	currentEssence = essence or 0
	eggShopState.essence = currentEssence
	mergeState.essence = currentEssence
	updateUpgradeUI()
	updateEggShopUI()
	updateMergeSelectionUI()
end)

player:GetAttributeChangedSignal("DragonEssence"):Connect(function()
	local essence = tonumber(player:GetAttribute("DragonEssence")) or 0
	currentEssence = math.max(currentEssence, essence)
	eggShopState.essence = getCurrentEssence()
	updateEggShopUI()
end)

UpgradeDragon.OnClientEvent:Connect(function(success, dragonModel, level, cost, essence)
	currentEssence = essence or currentEssence
	if dragonModel == selectedDragon and upgradeStatus then
		upgradeStatus.Text = success and ("Upgraded to Lv. " .. tostring(level)) or ("Need " .. tostring(cost) .. " essence")
	end
	updateUpgradeUI()
end)

EggHatched.OnClientEvent:Connect(function(rarity, dragonType, dragonModel)
	if not dragonModel or not dragonModel.Parent then
		return
	end
	local root = dragonModel:FindFirstChild("DragonRoot", true)
	if not root then
		return
	end
	local rarityInfo = DragonEggConfig.GetRarityInfo(rarity)
	local pop = Instance.new("ParticleEmitter")
	pop.Color = ColorSequence.new(rarityInfo.Color)
	pop.Size = NumberSequence.new(0.8, 0)
	pop.Lifetime = NumberRange.new(0.4, 0.8)
	pop.Rate = 0
	pop.Speed = NumberRange.new(2, 5)
	pop.SpreadAngle = Vector2.new(180, 180)
	pop.LightEmission = 1
	pop.Parent = root
	pop:Emit(12)
	task.delay(1, function()
		if pop.Parent then
			pop:Destroy()
		end
	end)
end)

local function getTargetNodeForDragon(dragon)
	local nodeName = dragon:GetAttribute("TargetNodeName")
	if not nodeName or nodeName == "" then
		return nil
	end
	local node = nodesFolder:FindFirstChild(nodeName)
	if isOwnedNode(node) and not node:GetAttribute("Depleted") then
		return node
	end
	return nil
end

local function getNodeAnchor(node)
	return node and node:FindFirstChildWhichIsA("BasePart", true)
end

local function clearTargetBeam(data)
	if data.beam then
		data.beam:Destroy()
		data.beam = nil
	end
	if data.beamAttachment then
		data.beamAttachment:Destroy()
		data.beamAttachment = nil
	end
	if data.targetAttachment then
		data.targetAttachment:Destroy()
		data.targetAttachment = nil
	end
	data.currentTargetNode = nil
end

local function updateTargetBeam(data, node)
	if data.currentTargetNode ~= node then
		clearTargetBeam(data)
	end

	if not node then
		return
	end

	local nodeAnchor = getNodeAnchor(node)
	if not data.root or not data.root.Parent or not nodeAnchor then
		clearTargetBeam(data)
		return
	end

	if not data.beam then
		local dragonAttachment = Instance.new("Attachment")
		dragonAttachment.Name = "AssignedTargetBeamStart"
		dragonAttachment.Parent = data.root

		local targetAttachment = Instance.new("Attachment")
		targetAttachment.Name = "AssignedTargetBeamEnd"
		targetAttachment.Parent = nodeAnchor

		local beam = Instance.new("Beam")
		beam.Name = "AssignedTargetBeam"
		beam.Attachment0 = dragonAttachment
		beam.Attachment1 = targetAttachment
		beam.Color = ColorSequence.new(Color3.fromRGB(95, 210, 255), Color3.fromRGB(255, 225, 100))
		beam.Transparency = NumberSequence.new(0.25)
		beam.Width0 = 0.14
		beam.Width1 = 0.32
		beam.LightEmission = 0.8
		beam.FaceCamera = true
		beam.Parent = data.root

		data.beam = beam
		data.beamAttachment = dragonAttachment
		data.targetAttachment = targetAttachment
	end
	data.currentTargetNode = node
end

updateAssignmentVisuals = function()
	local counts = {}
	for _, data in pairs(nodeBillboards) do
		data.assignedCount = 0
	end

	for dragon, data in pairs(trackedDragons) do
		local node = getTargetNodeForDragon(dragon)
		updateTargetBeam(data, node)
		if node and not nodeBillboards[node] then
			createNodeBillboard(node)
		end
		if node and nodeBillboards[node] then
			counts[node] = (counts[node] or 0) + 1
			nodeBillboards[node].assignedCount = counts[node]
		end
	end

	for node, data in pairs(nodeBillboards) do
		local count = data.assignedCount or 0
		if count > 0 and not node:GetAttribute("Depleted") then
			data.assignmentLabel.Text = count == 1 and "Assigned" or ("Assigned x" .. tostring(count))
			data.assignmentLabel.Visible = true
		else
			data.assignmentLabel.Text = ""
			data.assignmentLabel.Visible = false
		end
	end
end

local function trackEgg(egg)
	if egg:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if trackedEggs[egg] then
		return
	end

	local root = egg:WaitForChild("EggRoot", 5)
	if not root then
		return
	end

	trackedEggs[egg] = {
		model = egg,
		root = root,
		basePos = root.Position,
	}
end

local function updateDragonAbilityMeter(dragon, data)
	if not data or not data.abilityMeterLabel then
		return
	end

	local dragonType = dragon:GetAttribute("DragonType") or ""
	local chainRequired = dragon:GetAttribute("AbilityChainRequired") or 0
	local chainHits = dragon:GetAttribute("AbilityChainHits") or 0
	local heat = dragon:GetAttribute("AbilityHeat") or 0
	local heatMax = dragon:GetAttribute("AbilityHeatMax") or 0
	local tide = dragon:GetAttribute("AbilityTide") or 0

	local text = ""
	local color = Color3.fromRGB(220, 230, 255)
	if dragonType == "StormDragon" and chainRequired > 0 then
		text = "Chain " .. tostring(chainHits) .. "/" .. tostring(chainRequired)
		color = ABILITY_VFX_COLORS.ChainLightning
	elseif dragonType == "LavaDragon" and heatMax > 0 then
		text = "Heat " .. tostring(heat) .. "/" .. tostring(heatMax)
		color = ABILITY_VFX_COLORS.MoltenCore
	elseif dragonType == "CoralOceanDragon" then
		text = "Tide " .. tostring(tide) .. "%"
		color = ABILITY_VFX_COLORS.OceanBlessing
	end

	data.abilityMeterLabel.Text = text
	data.abilityMeterLabel.TextColor3 = color
	data.abilityMeter.Enabled = text ~= ""
end

local function ensureDragonAbilityMeter(dragon, data)
	if data.abilityMeter then
		return
	end
	local meter = Instance.new("BillboardGui")
	meter.Name = "AbilityMeter"
	meter.Size = UDim2.fromOffset(90, 18)
	meter.StudsOffset = Vector3.new(0, 5.2, 0)
	meter.AlwaysOnTop = true
	meter.Enabled = false
	meter.Parent = data.root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = meter

	data.abilityMeter = meter
	data.abilityMeterLabel = label
end

local function trackDragon(dragon)
	if dragon:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if trackedDragons[dragon] then
		return
	end

	local root = dragon:WaitForChild("DragonRoot", 5)
	if not root then
		return
	end

	trackedDragons[dragon] = {
		model = dragon,
		root = root,
		visualPos = root.Position,
		velocity = Vector3.zero,
		facing = Vector3.new(0, 0, -1),
		beam = nil,
		beamAttachment = nil,
		targetAttachment = nil,
		currentTargetNode = nil,
		boneCache = DragonBoneAnimator.BuildCache(dragon),
	}

	ensureDragonAbilityMeter(dragon, trackedDragons[dragon])
	updateDragonAbilityMeter(dragon, trackedDragons[dragon])

	dragon:GetAttributeChangedSignal("TargetNodeName"):Connect(updateAssignmentVisuals)
	dragon:GetAttributeChangedSignal("DragonState"):Connect(updateAssignmentVisuals)
	dragon:GetAttributeChangedSignal("AbilityChainHits"):Connect(function()
		updateDragonAbilityMeter(dragon, trackedDragons[dragon])
	end)
	dragon:GetAttributeChangedSignal("AbilityChainRequired"):Connect(function()
		updateDragonAbilityMeter(dragon, trackedDragons[dragon])
	end)
	dragon:GetAttributeChangedSignal("AbilityHeat"):Connect(function()
		updateDragonAbilityMeter(dragon, trackedDragons[dragon])
	end)
	dragon:GetAttributeChangedSignal("AbilityHeatMax"):Connect(function()
		updateDragonAbilityMeter(dragon, trackedDragons[dragon])
	end)
	dragon:GetAttributeChangedSignal("AbilityTide"):Connect(function()
		updateDragonAbilityMeter(dragon, trackedDragons[dragon])
	end)
	dragon:GetAttributeChangedSignal("DragonLevel"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("UpgradeCost"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("MoveSpeed"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("HarvestRate"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("HarvestSpeed"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("FlightSpeed"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("CarryCapacity"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("CriticalHarvestChance"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("Luck"):Connect(updateUpgradeUI)
	dragon:GetAttributeChangedSignal("DragonEvolution"):Connect(function()
		updateUpgradeUI()
		updateMergeUI()
	end)
	dragon:GetAttributeChangedSignal("EvolutionStars"):Connect(updateMergeUI)
	if updateAssignmentVisuals then
		updateAssignmentVisuals()
	end
end

for _, egg in eggsFolder:GetChildren() do
	trackEgg(egg)
end

eggsFolder.ChildAdded:Connect(trackEgg)

eggsFolder.ChildRemoved:Connect(function(egg)
	trackedEggs[egg] = nil
end)

for _, dragon in dragonsFolder:GetChildren() do
	trackDragon(dragon)
end

dragonsFolder.ChildAdded:Connect(trackDragon)

dragonsFolder.ChildRemoved:Connect(function(dragon)
	local data = trackedDragons[dragon]
	if data then
		clearTargetBeam(data)
	end
	trackedDragons[dragon] = nil
	updateAssignmentVisuals()
	if selectedDragon == dragon then
		selectDragon(nil)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local time = os.clock()

	for _, data in pairs(trackedEggs) do
		local egg = data.model
		if not egg.Parent then
			continue
		end

		local hatchReadyAt = egg:GetAttribute("HatchReadyAt")
		local isHatching = egg:GetAttribute("Hatching") == true
		if isHatching then
			continue
		end
		local hatchDuration = egg:GetAttribute("HatchDuration") or DragonEggConfig.HatchTime
		local remaining = 0
		if typeof(hatchReadyAt) == "number" then
			remaining = math.max(0, hatchReadyAt - workspace:GetServerTimeNow())
		end
		local progress = 1 - math.clamp(remaining / hatchDuration, 0, 1)

		local bob = math.sin(time * 3.5) * 0.2
		local wobble = math.sin(time * 8 + progress * 6) * math.rad(4 + progress * 10)
		local hover = data.basePos + Vector3.new(0, 0.6 + bob, 0)
		egg:PivotTo(CFrame.new(hover) * CFrame.Angles(wobble, time * 0.6, wobble * 0.5))

		local glow = egg:FindFirstChild("EggGlow", true)
		if glow then
			glow.Transparency = 0.75 - progress * 0.35
		end
	end

	for _, data in pairs(trackedDragons) do
		local dragon = data.model
		if not dragon.Parent then
			continue
		end

		local serverPos = dragon:GetAttribute("ServerPosition")
		if typeof(serverPos) == "Vector3" then
			local gap = (serverPos - data.visualPos).Magnitude
			local flySpeed = gap > 8 and SMOOTH_FLY_CATCHUP or SMOOTH_FLY_SPEED
			local flyAlpha = math.clamp(dt * flySpeed, 0, 1)
			local desiredVelocity = (serverPos - data.visualPos) * flySpeed
			data.velocity = data.velocity:Lerp(desiredVelocity, math.clamp(dt * VELOCITY_DAMPING, 0, 1))
			data.visualPos += data.velocity * dt * flyAlpha
			if gap < 0.08 then
				data.visualPos = data.visualPos:Lerp(serverPos, flyAlpha)
			end
		end

		local state = dragon:GetAttribute("DragonState") or "idle"
		local bob, isActive, sway, roll = animateDragon(dragon, state, time)
		if state == "idle" then
			sway += math.sin(time * 1.35 + (dragon:GetAttribute("DragonId") or 0)) * math.rad(2.5)
			roll += math.cos(time * 1.1 + (dragon:GetAttribute("DragonId") or 0) * 0.5) * math.rad(2)
		end
		local hoverPos = data.visualPos + Vector3.new(0, HOVER_HEIGHT + bob, 0)

		local lookDir = dragon:GetAttribute("LookDirection")
		if typeof(lookDir) == "Vector3" and lookDir.Magnitude > 0.01 then
			local turnAlpha = math.clamp(dt * SMOOTH_TURN_SPEED, 0, 1)
			data.facing = data.facing:Lerp(lookDir.Unit, turnAlpha)
		end

		local baseCFrame
		if data.facing.Magnitude > 0.01 then
			baseCFrame = CFrame.lookAt(hoverPos, hoverPos + data.facing)
		else
			baseCFrame = CFrame.new(hoverPos)
		end

		local turnBank = 0
		if isActive and data.facing.Magnitude > 0.01 then
			local prevFacing = data.prevFacing or data.facing
			if prevFacing.Magnitude > 0.01 then
				turnBank = math.clamp(prevFacing:Cross(data.facing).Y * SMOOTH_TURN_BANK, -0.45, 0.45)
			end
			data.prevFacing = data.facing
		end

		local pitch = isActive and MOVE_PITCH or math.rad(-4)
		baseCFrame = baseCFrame * CFrame.Angles(pitch + sway, 0, roll + turnBank)

		dragon:PivotTo(baseCFrame)

		local targetLookPos = dragon:GetAttribute("TargetLookPosition")
		if typeof(targetLookPos) ~= "Vector3" then
			local nodeName = dragon:GetAttribute("TargetNodeName")
			if nodeName and nodeName ~= "" then
				local node = nodesFolder:FindFirstChild(nodeName)
				if node then
					local cf = node:GetBoundingBox()
					targetLookPos = cf.Position
				end
			end
		end

		if data.boneCache then
			DragonBoneAnimator.Animate(data.boneCache, {
				state = state,
				time = time,
				dt = dt,
				facing = data.facing,
				targetLookPos = targetLookPos,
				dragonPivot = baseCFrame,
			})
		end
	end
end)

mouse.Button1Down:Connect(function()
	local dragon = getClickedDragon()
	if dragon then
		selectDragon(dragon)
		return
	end

	local node = getClickedNode()
	if node and not node:GetAttribute("Depleted") then
		TargetNode:FireServer(node)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		local dragon = getClickedDragon()
		if dragon then
			selectDragon(dragon)
			return
		end

		local node = getClickedNode()
		if node and not node:GetAttribute("Depleted") then
			TargetNode:FireServer(node)
		end
	end
end)
