local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local BuildingEvents = ReplicatedStorage:WaitForChild("BuildingEvents")
local RequestBuildingData = BuildingEvents:WaitForChild("RequestBuildingData")
local UpgradeBuilding = BuildingEvents:WaitForChild("UpgradeBuilding")
local UnlockBuilding = BuildingEvents:WaitForChild("UnlockBuilding")
local BuildingStateUpdated = BuildingEvents:WaitForChild("BuildingStateUpdated")

local state = {
	buildings = {},
	buildingOrder = {},
	selectedBuildingId = nil,
}

local BUILDING_ICONS = {
	DragonNest = Theme.Icons.Dragon,
	DragonStorage = Theme.Icons.Backpack,
	CrystalStorage = Theme.Icons.Crystal,
	DragonAcademy = Theme.Icons.Book,
	Workshop = Theme.Icons.Hammer,
	EggHatchery = Theme.Icons.Egg,
}

local BUILDING_DESCRIPTIONS = {
	DragonNest = "Expand your roster with more active dragon slots for harvesting.",
	DragonStorage = "Increase how many dragons you can own in storage.",
	CrystalStorage = "Increase Dragon Essence storage so you never overflow rewards.",
	DragonAcademy = "Train dragons faster and earn bonus XP while you play.",
	Workshop = "Unlock higher-tier crafting recipes for powerful gear.",
	EggHatchery = "Access the egg shop and future hatchery upgrades.",
}

local screenGui = nil
local panel = nil
local listFrame = nil
local detailPanel = nil
local detailIcon = nil
local detailNameLabel = nil
local detailLevelLabel = nil
local detailDescLabel = nil
local detailBonusLabel = nil
local detailCostLabel = nil
local actionButton = nil
local statusLabel = nil
local selectionBox = nil
local buildingRows = {}

local function getDefinition(typeId)
	return BuildingConfig.Buildings[typeId]
end

local function formatNumber(value)
	local numberValue = tonumber(value) or 0
	if numberValue >= 1000000 then
		return string.format("%.1fM", numberValue / 1000000)
	elseif numberValue >= 1000 then
		return string.format("%.1fK", numberValue / 1000)
	end
	return tostring(math.floor(numberValue))
end

local function getBuildingById(buildingId)
	for _, building in state.buildings do
		if building.id == buildingId then
			return building
		end
	end
	return nil
end

local function getBuildingIcon(typeId)
	return BUILDING_ICONS[typeId] or Theme.Icons.House
end

local function getEffectText(building)
	if not building then
		return "Select a permanent building to view upgrades."
	end
	local effects = building.effects or {}
	if building.typeId == "DragonNest" then
		return "+" .. formatNumber(effects.ActiveDragonSlots or 0) .. " active dragon slots"
	elseif building.typeId == "DragonStorage" then
		return formatNumber(effects.DragonStorageCapacity or 0) .. " dragon storage slots"
	elseif building.typeId == "CrystalStorage" then
		return formatNumber(effects.DragonEssenceStorageCapacity or 0) .. " Dragon Essence capacity"
	elseif building.typeId == "DragonAcademy" then
		local trainingMultiplier = tonumber(effects.TrainingTimeMultiplier) or 1
		local xpMultiplier = tonumber(effects.XpGainMultiplier) or 1
		return math.floor((1 - trainingMultiplier) * 100) .. "% faster training, x" .. string.format("%.1f", xpMultiplier) .. " XP"
	elseif building.typeId == "Workshop" then
		return "Crafting recipe tier " .. formatNumber(effects.CraftingRecipeTier or 1)
	elseif building.typeId == "EggHatchery" then
		return "Egg shop access and future hatchery upgrades"
	end
	return "Level " .. formatNumber(building.level or 1)
end

local function setStatus(text, isGood)
	if statusLabel then
		statusLabel.Text = text
		statusLabel.TextColor3 = isGood and Theme.Colors.Success or Theme.Colors.Danger
	end
end

local function getOwnIsland()
	return WorkspaceLayout.GetPlayerIsland(player)
end

local function clearSelectionBox()
	if selectionBox then
		selectionBox:Destroy()
		selectionBox = nil
	end
end

local function selectWorldModel(buildingId)
	clearSelectionBox()
	local island = getOwnIsland()
	local model = island and island:FindFirstChild(buildingId)
	if model and model:IsA("Model") then
		selectionBox = Instance.new("SelectionBox")
		selectionBox.Name = "BuildingSelectionBox"
		selectionBox.Adornee = model
		selectionBox.LineThickness = 0.06
		selectionBox.Color3 = Theme.Colors.GoldBright
		selectionBox.Parent = model
	end
end

local function updateButtons()
	for typeId, row in buildingRows do
		local building = getBuildingById(typeId)
		local definition = getDefinition(typeId)
		if definition then
			local prefix = building and building.unlocked and ("Lv. " .. tostring(building.level or 1)) or "Locked"
			row.Text = definition.DisplayName .. "\n" .. prefix
			Theme.setListRowSelected(row, typeId == state.selectedBuildingId, definition.PrimaryColor)
		end
	end
end

local function updateSelectedBuilding()
	local building = state.selectedBuildingId and getBuildingById(state.selectedBuildingId) or nil
	local definition = state.selectedBuildingId and getDefinition(state.selectedBuildingId) or nil

	for typeId, row in buildingRows do
		local def = getDefinition(typeId)
		Theme.setListRowSelected(row, typeId == state.selectedBuildingId, def and def.PrimaryColor)
	end

	if not building or not definition then
		clearSelectionBox()
		if detailIcon then detailIcon.Image = Theme.Icons.House end
		if detailNameLabel then detailNameLabel.Text = "Select a Building" end
		if detailLevelLabel then detailLevelLabel.Text = "" end
		if detailDescLabel then detailDescLabel.Text = "Choose a kingdom building from the list to view upgrades and bonuses." end
		if detailBonusLabel then detailBonusLabel.Text = "" end
		if detailCostLabel then detailCostLabel.Text = "" end
		if actionButton then
			actionButton.Text = "Select Building"
			actionButton.AutoButtonColor = false
			actionButton.BackgroundColor3 = Theme.Colors.Slate
		end
		return
	end

	selectWorldModel(building.id)
	if detailIcon then detailIcon.Image = getBuildingIcon(building.typeId) end
	if detailNameLabel then detailNameLabel.Text = definition.DisplayName end
	if detailLevelLabel then
		local lockText = building.unlocked and ("Level " .. tostring(building.level or 1)) or "Locked"
		detailLevelLabel.Text = lockText
		detailLevelLabel.TextColor3 = building.unlocked and Theme.Colors.GoldBright or Theme.Colors.TextMuted
	end
	if detailDescLabel then
		detailDescLabel.Text = BUILDING_DESCRIPTIONS[building.typeId] or "Permanent kingdom building."
	end
	if detailBonusLabel then
		detailBonusLabel.Text = "Current Bonus: " .. getEffectText(building)
	end
	if detailCostLabel then
		if building.unlocked then
			local maxLevel = BuildingConfig.Upgrade.MaxLevel or 25
			if (building.level or 1) >= maxLevel then
				detailCostLabel.Text = "Maximum level reached"
				detailCostLabel.TextColor3 = Theme.Colors.GoldBright
			else
				detailCostLabel.Text = "Upgrade Cost: " .. formatNumber(building.upgradeCost or 0) .. " Dragon Essence"
				detailCostLabel.TextColor3 = Theme.Colors.TextGold
			end
		else
			detailCostLabel.Text = "Unlock Cost: " .. formatNumber(building.unlockCost or 0) .. " Dragon Essence"
			detailCostLabel.TextColor3 = Theme.Colors.Crystal
		end
	end
	if actionButton then
		actionButton.AutoButtonColor = true
		if building.unlocked then
			local maxLevel = BuildingConfig.Upgrade.MaxLevel or 25
			if (building.level or 1) >= maxLevel then
				actionButton.Text = "Max Level"
				actionButton.AutoButtonColor = false
				actionButton.BackgroundColor3 = Theme.Colors.Slate
			else
				actionButton.Text = "Upgrade Building"
				actionButton.BackgroundColor3 = Theme.Colors.Success
			end
		else
			actionButton.Text = "Unlock Building"
			actionButton.BackgroundColor3 = Theme.Colors.Crystal
		end
	end
end

local function refreshState(newState)
	if typeof(newState) ~= "table" then
		return
	end
	if typeof(newState.buildings) == "table" then
		state.buildings = newState.buildings
	end
	if typeof(newState.buildingOrder) == "table" then
		state.buildingOrder = newState.buildingOrder
	end
	if state.selectedBuildingId and not getBuildingById(state.selectedBuildingId) then
		state.selectedBuildingId = nil
	end
	updateButtons()
	updateSelectedBuilding()
	if typeof(newState.message) == "string" and newState.message ~= "" then
		local goodMessage = string.find(newState.message, "Upgraded", 1, true) ~= nil or string.find(newState.message, "Unlocked", 1, true) ~= nil or newState.message == "Already unlocked"
		setStatus(newState.message, goodMessage)
	end
end

local function closeBuildingsPanel()
	if not screenGui or not panel then
		return
	end
	local dim = screenGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(screenGui, panel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function buildUi()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BuildingUpgradeUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 28
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	Theme.applyScreenSafeArea(screenGui)

	local dim = Theme.createDim(screenGui, 1)
	dim.Name = "DimBackground"
	dim.Visible = false
	dim.ZIndex = 1
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeBuildingsPanel()
		end
	end)

	panel = Theme.createPanel({ Name = "BuildingPanel", Parent = screenGui, Size = UDim2.fromOffset(760, 540), Visible = false, ZIndex = 5 })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function() closeBuildingsPanel() end, 30)
	Theme.createWindowHeader(panel, "Kingdom Buildings", "Unlock and upgrade permanent island structures", 8)

	listFrame = Theme.createScrollList(panel, UDim2.fromOffset(240, 430), UDim2.fromOffset(16, 72), 8)
	listFrame.Name = "BuildingList"

	for index, typeId in BuildingConfig.BuildingOrder do
		local definition = getDefinition(typeId)
		if definition then
			local row = Theme.createListRow(listFrame, {
				Name = typeId .. "Row",
				Text = definition.DisplayName .. "\nLocked",
				LayoutOrder = index,
				Height = 58,
				ZIndex = 9,
				OnClick = function()
					state.selectedBuildingId = typeId
					updateSelectedBuilding()
					setStatus("Selected " .. definition.DisplayName, true)
				end,
			})
			buildingRows[typeId] = row
		end
	end

	detailPanel = Theme.createDetailPanel(panel, UDim2.fromOffset(470, 430), UDim2.fromOffset(270, 72), 8)
	local iconFrame, iconImage = Theme.createIconFrame(detailPanel, Theme.Icons.House, 88, 9)
	iconImage.Name = "DetailIcon"
	detailIcon = iconImage
	iconFrame.Position = UDim2.fromOffset(0, 0)

	detailNameLabel = Theme.createText({
		Name = "DetailName", Parent = detailPanel, Text = "Select a Building",
		Size = UDim2.new(1, -104, 0, 28), Position = UDim2.fromOffset(104, 0),
		TextSize = 20, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight, Wrapped = false, ZIndex = 9,
	})
	detailLevelLabel = Theme.createText({
		Name = "DetailLevel", Parent = detailPanel, Text = "",
		Size = UDim2.new(1, -104, 0, 20), Position = UDim2.fromOffset(104, 30),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright, ZIndex = 9,
	})
	detailDescLabel = Theme.createText({
		Name = "DetailDesc", Parent = detailPanel, Text = "Choose a kingdom building from the list to view upgrades and bonuses.",
		Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 100),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, YAlign = Enum.TextYAlignment.Top, ZIndex = 9,
	})
	detailBonusLabel = Theme.createText({
		Name = "DetailBonus", Parent = detailPanel, Text = "",
		Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 156),
		Bg = Theme.Colors.PanelInner, BgTransparency = 0.1, Corner = Theme.Corner.Medium,
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, YAlign = Enum.TextYAlignment.Top, ZIndex = 9,
	})
	detailCostLabel = Theme.createText({
		Name = "DetailCost", Parent = detailPanel, Text = "",
		Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 210),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 9,
	})

	actionButton = Theme.createButton({
		Name = "ActionButton", Parent = detailPanel, Text = "Select Building",
		Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48),
		AnchorPoint = Vector2.new(0, 1), Bg = Theme.Colors.Slate, TextSize = 17, ZIndex = 9,
		AutoButtonColor = false,
	})
	actionButton.MouseButton1Click:Connect(function()
		local building = state.selectedBuildingId and getBuildingById(state.selectedBuildingId) or nil
		if not building then setStatus("Select a building first", false) return end
		if building.unlocked then UpgradeBuilding:FireServer(building.id) else UnlockBuilding:FireServer(building.id) end
	end)

	statusLabel = Theme.createText({
		Name = "StatusLabel", Parent = panel, Text = "Select a building",
		Size = UDim2.new(1, -32, 0, 24), Position = UDim2.new(0, 16, 1, -32),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.Success, ZIndex = 8,
	})
end

local function requestInitialState()
	local success, result = pcall(function()
		return RequestBuildingData:InvokeServer()
	end)
	if success then
		refreshState(result)
	else
		setStatus("Building data unavailable", false)
		warn("[BuildingUpgradeClient] Failed to request building data:", result)
	end
end

buildUi()
requestInitialState()

BuildingStateUpdated.OnClientEvent:Connect(refreshState)

mouse.Button1Down:Connect(function()
	local target = mouse.Target
	if not target then
		return
	end
	local buildingId = target:GetAttribute("BuildingId")
	local ownerId = target:GetAttribute("OwnerUserId")
	if typeof(buildingId) == "string" and ownerId == player.UserId and getBuildingById(buildingId) then
		state.selectedBuildingId = buildingId
		updateSelectedBuilding()
		setStatus("Building selected", true)
	end
end)

player.CharacterAdded:Connect(function()
	task.delay(1, function()
		requestInitialState()
		updateSelectedBuilding()
	end)
end)

local function openBuildingsPanel(buildingId)
	local dim = screenGui and screenGui:FindFirstChild("DimBackground")
	local opening = panel and not panel.Visible
	screenGui.Enabled = true
	if opening then
		Theme.raiseModalGui(screenGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(screenGui.Name)
		end
	end
	if panel then
		Theme.tweenOpen(panel, dim)
	end
	if typeof(buildingId) == "string" then
		for _, building in state.buildings do
			if building.id == buildingId or building.typeId == buildingId then
				state.selectedBuildingId = building.id
				break
			end
		end
	end
	requestInitialState()
	updateSelectedBuilding()
end

_G.DragonIslandOpenBuildings = openBuildingsPanel
_G.DragonIslandCloseBuildings = closeBuildingsPanel

UIBridge.RegisterPanel("Buildings", { Open = openBuildingsPanel, Close = closeBuildingsPanel })