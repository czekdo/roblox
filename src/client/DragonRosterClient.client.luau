local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local HarvestConfig = require(ReplicatedStorage:WaitForChild("HarvestConfig"))
local DragonAbilityConfig = require(ReplicatedStorage:WaitForChild("DragonAbilityConfig"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local DragonInventoryConfig = require(ReplicatedStorage:WaitForChild("DragonInventoryConfig"))
local InventoryEvents = ReplicatedStorage:WaitForChild("InventoryEvents")
local RequestInventoryData = InventoryEvents:WaitForChild("RequestInventoryData")
local UseInventoryItem = InventoryEvents:WaitForChild("UseInventoryItem")
local InventoryStateUpdated = InventoryEvents:WaitForChild("InventoryStateUpdated")
local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local RequestDragonMergeData = HarvestEvents:WaitForChild("RequestDragonMergeData")
local UpgradeDragon = HarvestEvents:WaitForChild("UpgradeDragon")
local DragonMergeUpdate = HarvestEvents:WaitForChild("DragonMergeUpdate")
local HarvestUIUpdate = HarvestEvents:WaitForChild("HarvestUIUpdate")
local EquipDragon = HarvestEvents:WaitForChild("EquipDragon")
local UnequipDragon = HarvestEvents:WaitForChild("UnequipDragon")
local EquipBestDragons = HarvestEvents:WaitForChild("EquipBestDragons")
local SetDragonFavorite = HarvestEvents:WaitForChild("SetDragonFavorite")
local SetDragonLocked = HarvestEvents:WaitForChild("SetDragonLocked")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local dragonsFolder = workspace:WaitForChild("DragonWorkers")

local rosterGui
local rosterPanel
local dimFrame
local contentFrame
local headerTitle
local headerSubtitle
local sidebarButtons = {}
local listRows = {}
local codexRows = {}
local inventoryRows = {}
local inventoryState = { items = {} }
local selectedItemId
local rosterState = {
	dragons = {},
	essence = 0,
	activeCount = 0,
	activeMax = HarvestConfig.MaxDragons,
	storageCount = 0,
	storageMax = 50,
}
local sortMode = "Power"
local filterMode = "All"
local sortModes = DragonInventoryConfig.SortOptions
local filterModes = { "All", "Equipped", "Storage", "Favorites", "Locked", "Idle", "Training", "Harvesting" }
local activeTab = "Dragons"
local refreshToken = 0
local selectedDragonId
local selectedSpeciesId

local PANEL_WIDTH = 960
local PANEL_HEIGHT = 600
local LIST_WIDTH_SCALE = 0.36

local sidebarItems = {
	{ id = "Dragons", label = "Dragons", icon = Theme.Icons.Dragon },
	{ id = "Codex", label = "Codex", icon = Theme.Icons.Book },
	{ id = "Inventory", label = "Inventory", icon = Theme.Icons.Backpack },
	{ id = "Kingdom", label = "Kingdom", icon = Theme.Icons.Crown, panelId = "Personalization" },
	{ id = "Leaderboards", label = "Leaderboards", icon = Theme.Icons.Trophy },
}

local renderDragonDetail
local renderCodexDetail
local renderInventoryDetail

local function findDragonModel(dragonId)
	for _, model in dragonsFolder:GetChildren() do
		if model:GetAttribute("OwnerUserId") == player.UserId then
			if model:GetAttribute("OwnedDragonId") == dragonId or model:GetAttribute("DragonId") == dragonId then
				return model
			end
		end
	end
	return nil
end

local function getRarityOrder(rarity)
	local order = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5, Ancient = 6 }
	return order[rarity] or 0
end

local function passesFilter(dragon)
	if filterMode == "All" then
		return true
	elseif filterMode == "Equipped" then
		return dragon.isEquipped == true
	elseif filterMode == "Storage" then
		return dragon.isEquipped ~= true
	elseif filterMode == "Favorites" then
		return dragon.isFavorite == true
	elseif filterMode == "Locked" then
		return dragon.isLocked == true
	elseif filterMode == "Idle" then
		return string.lower(dragon.state or "") == "idle" or dragon.state == "storage"
	elseif filterMode == "Training" then
		return string.lower(dragon.state or "") == "training"
	elseif filterMode == "Harvesting" then
		local state = string.lower(dragon.state or "")
		return state == "harvesting" or state == "moving"
	end
	return true
end

local function sortDragons(dragons)
	local sorted = table.clone(dragons)
	table.sort(sorted, function(a, b)
		if sortMode == "Power" then
			return (a.powerScore or 0) > (b.powerScore or 0)
		elseif sortMode == "Training" then
			return (a.level or 0) > (b.level or 0)
		elseif sortMode == "Stars" then
			return (a.evolutionLevel or 0) > (b.evolutionLevel or 0)
		elseif sortMode == "Ability Level" then
			return ((a.ability and a.ability.abilityLevel) or 0) > ((b.ability and b.ability.abilityLevel) or 0)
		elseif sortMode == "Rarity" then
			return getRarityOrder(a.rarity) > getRarityOrder(b.rarity)
		elseif sortMode == "Species" then
			return tostring(a.displayName or a.dragonType) < tostring(b.displayName or b.dragonType)
		elseif sortMode == "Newest" then
			return (a.acquiredAt or 0) > (b.acquiredAt or 0)
		elseif sortMode == "Oldest" then
			return (a.acquiredAt or 0) < (b.acquiredAt or 0)
		end
		return (a.powerScore or 0) > (b.powerScore or 0)
	end)
	return sorted
end

local function getFilteredDragons()
	local filtered = {}
	for _, dragon in rosterState.dragons do
		if passesFilter(dragon) then
			table.insert(filtered, dragon)
		end
	end
	return sortDragons(filtered)
end

local function getCapacitySubtitle()
	return string.format(
		"Active Dragons  %d / %d   •   Dragon Storage  %d / %d",
		rosterState.activeCount or 0,
		rosterState.activeMax or 0,
		rosterState.storageCount or 0,
		rosterState.storageMax or 0
	)
end

local function getDragonById(dragonId)
	for _, dragon in rosterState.dragons do
		if dragon.id == dragonId then
			return dragon
		end
	end
	return nil
end

local function getSpeciesIdFromDragon(dragon)
	if not dragon then
		return nil
	end
	return DragonEggConfig.GetDragonModelName(dragon.dragonType or "")
end

local function isSpeciesDiscovered(speciesId)
	for _, dragon in rosterState.dragons do
		if getSpeciesIdFromDragon(dragon) == speciesId then
			return true
		end
	end
	return false
end

local function getSpeciesCompletion(speciesId)
	if not isSpeciesDiscovered(speciesId) then
		return 0
	end
	local maxLevel = DragonAbilityConfig.GetMaxLevel()
	local bestLevel = 0
	for _, dragon in rosterState.dragons do
		if getSpeciesIdFromDragon(dragon) == speciesId then
			local abilityLevel = (dragon.ability and dragon.ability.abilityLevel) or 1
			bestLevel = math.max(bestLevel, abilityLevel)
		end
	end
	return math.floor((bestLevel / math.max(1, maxLevel)) * 100 + 0.5)
end

local function getDiscoveredSpeciesCount()
	local count = 0
	for _, speciesId in DragonAbilityConfig.GetAllSpeciesIds() do
		if isSpeciesDiscovered(speciesId) then
			count += 1
		end
	end
	return count
end

local function getActivityText(dragon)
	local state = string.lower(dragon.state or "idle")
	if state == "harvesting" or state == "moving" then
		local nodeName = dragon.targetNodeName
		if typeof(nodeName) == "string" and nodeName ~= "" then
			return "Harvesting " .. nodeName, Theme.Colors.Crystal
		end
		return "Harvesting", Theme.Colors.Crystal
	end
	if state == "training" then
		return "Training", Theme.Colors.Purple
	end
	return "Idle", Theme.Colors.TextMuted
end

local function setHeader(title, subtitle)
	if headerTitle then
		headerTitle.Text = title
	end
	if headerSubtitle then
		headerSubtitle.Text = subtitle or ""
	end
end

local function clearContent()
	if not contentFrame then
		return
	end
	for _, child in contentFrame:GetChildren() do
		child:Destroy()
	end
	table.clear(listRows)
	table.clear(codexRows)
	table.clear(inventoryRows)
end

local function createSplitLayout()
	local split = Theme.createFrame({
		Name = "SplitLayout", Parent = contentFrame,
		Size = UDim2.new(1, -12, 1, -12), Position = UDim2.fromOffset(6, 6),
		BgTransparency = 1, ZIndex = 3,
	})
	local listScroll = Theme.createScrollList(
		split,
		UDim2.new(LIST_WIDTH_SCALE, -4, 1, 0),
		UDim2.fromOffset(0, 0),
		4
	)
	listScroll.Name = "ListScroll"
	local detailPanel = Theme.createDetailPanel(
		split,
		UDim2.new(1 - LIST_WIDTH_SCALE, -8, 1, 0),
		UDim2.new(LIST_WIDTH_SCALE, 8, 0, 0),
		4
	)
	detailPanel.Name = "DetailPanel"
	return listScroll, detailPanel
end

local function createActionButton(parent, name, text, position, size, bg, onClick)
	local btn = Theme.createButton({
		Name = name, Parent = parent, Text = text, Size = size, Position = position,
		Bg = bg, TextSize = 11, TextColor = Theme.Colors.TextLight, Corner = Theme.Corner.Small,
		OnClick = onClick, Bounce = false, Hover = true,
	})
	btn.ZIndex = 10
	return btn
end

local function populateDragonListRow(row, dragon)
	row.Text = ""
	local rarityColor = Theme.getRarityColor(dragon.rarity or "Common")
	local iconFrame, iconImage = Theme.createIconFrame(row, Theme.Icons.Dragon, 36, 8)
	iconFrame.Position = UDim2.fromOffset(6, 8)
	iconImage.ImageColor3 = rarityColor

	Theme.createText({
		Name = "RowName", Parent = row,
		Text = dragon.displayName or dragon.dragonType or "Dragon",
		Size = UDim2.new(1, -58, 0, 18), Position = UDim2.fromOffset(50, 6),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
	})

	Theme.createText({
		Name = "RowMeta", Parent = row,
		Text = string.format("Lv. %s %s  •  %s", tostring(dragon.level or 1), dragon.stars or "", dragon.rarity or "Common"),
		Size = UDim2.new(1, -58, 0, 16), Position = UDim2.fromOffset(50, 26),
		TextSize = 11, Font = Theme.Fonts.Regular, Color = rarityColor, ZIndex = 9,
	})

	local activity, activityColor = getActivityText(dragon)
	if dragon.isEquipped ~= true then
		activity = "In Storage"
		activityColor = Theme.Colors.TextMuted
	end
	Theme.createText({
		Name = "RowActivity", Parent = row,
		Text = activity,
		Size = UDim2.new(0.55, 0, 0, 14), Position = UDim2.fromOffset(50, 42),
		TextSize = 10, Font = Theme.Fonts.Bold, Color = activityColor, ZIndex = 9,
	})

	if dragon.isFavorite then
		local star = Theme.createIconFrame(row, Theme.Icons.Star, 16, 8)
		star.Position = UDim2.new(1, -22, 0, 8)
		star.AnchorPoint = Vector2.new(1, 0)
		local starImage = star:FindFirstChildWhichIsA("ImageLabel", true)
		if starImage then
			starImage.ImageColor3 = Theme.Colors.GoldBright
		end
	end

	if dragon.isLocked then
		Theme.createText({
			Name = "LockBadge", Parent = row, Text = "🔒",
			Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -22, 0, 30),
			AnchorPoint = Vector2.new(1, 0), TextSize = 12, ZIndex = 9,
		})
	end
end

local function highlightDragonRows()
	for dragonId, row in listRows do
		local dragon = getDragonById(dragonId)
		Theme.setListRowSelected(row, dragonId == selectedDragonId, dragon and Theme.getRarityColor(dragon.rarity or "Common"))
	end
end

local function selectDragon(dragonId)
	selectedDragonId = dragonId
	highlightDragonRows()
	local listHost = contentFrame and contentFrame:FindFirstChild("ListHost")
	local detailPanel = listHost and listHost:FindFirstChild("DetailPanel")
	if detailPanel then
		renderDragonDetail(detailPanel, getDragonById(dragonId))
	end
end

renderDragonDetail = function(detailPanel, dragon)
	for _, child in detailPanel:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end

	if not dragon then
		Theme.createEmptyState(
			detailPanel,
			Theme.Icons.Dragon,
			"Select a Dragon",
			"Choose a dragon from the list to inspect stats, abilities, and actions.",
			8
		)
		return
	end

	local ability = dragon.ability or {}
	local rarityColor = Theme.getRarityColor(dragon.rarity or "Common")
	local stats = dragon.stats or {}

	local iconFrame, iconImage = Theme.createIconFrame(detailPanel, Theme.Icons.Dragon, 88, 8)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconImage.ImageColor3 = rarityColor

	Theme.createText({
		Name = "DetailName", Parent = detailPanel,
		Text = dragon.displayName or dragon.dragonType or "Dragon",
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 96),
		TextSize = 20, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createText({
		Name = "DetailMeta", Parent = detailPanel,
		Text = string.format("%s  •  Lv. %s %s", string.upper(dragon.rarity or "COMMON"), tostring(dragon.level or 1), dragon.stars or ""),
		Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 122),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = rarityColor,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	local activity, activityColor = getActivityText(dragon)
	local assignedText = dragon.assigned and "  •  ASSIGNED" or ""
	Theme.createText({
		Name = "DetailActivity", Parent = detailPanel,
		Text = activity .. assignedText,
		Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 142),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = activityColor,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createText({
		Name = "DetailPower", Parent = detailPanel,
		Text = "Power Score  " .. string.format("%.0f", dragon.powerScore or 0),
		Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 158),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	local abilityPanel = Theme.createFrame({
		Name = "AbilityPanel", Parent = detailPanel,
		Size = UDim2.new(1, 0, 0, 118), Position = UDim2.fromOffset(0, 178),
		Bg = Theme.Colors.StoneDeep, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.stroke(abilityPanel, Theme.Colors.Crystal, 1.5, 0.35)

	Theme.createText({
		Name = "AbilityName", Parent = abilityPanel,
		Text = ability.abilityName or "Unknown Ability",
		Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 8),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.Crystal, ZIndex = 9,
	})

	Theme.createText({
		Name = "AbilityDescription", Parent = abilityPanel,
		Text = ability.description or "",
		Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 28),
		TextSize = 11, Font = Theme.Fonts.Body, Color = Theme.Colors.Text, Wrapped = true, ZIndex = 9,
	})

	Theme.createText({
		Name = "AbilityLevel", Parent = abilityPanel,
		Text = "Ability Lv. " .. tostring(ability.abilityLevel or 1) .. (ability.isMaxLevel and "  •  MAX" or ""),
		Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 58),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright, ZIndex = 9,
	})

	if ability.isMaxLevel then
		Theme.createText({
			Name = "AbilityValue", Parent = abilityPanel,
			Text = "Now: " .. tostring(ability.currentValueText or "—"),
			Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 78),
			TextSize = 11, Font = Theme.Fonts.Body, Color = Theme.Colors.Text, ZIndex = 9,
		})
	else
		local progress = ability.abilityProgress or 0
		local required = ability.progressRequired or 1
		local _, abilityFill = Theme.createProgressBar(
			abilityPanel,
			UDim2.new(1, -16, 0, 10),
			UDim2.fromOffset(8, 78),
			Theme.Colors.Crystal
		)
		abilityFill.ZIndex = 10
		abilityFill.Size = UDim2.fromScale(math.clamp(progress / math.max(1, required), 0, 1), 1)
		Theme.createText({
			Name = "AbilityProgress", Parent = abilityPanel,
			Text = string.format("Progress %d / %d  •  Now: %s", progress, required, tostring(ability.currentValueText or "—")),
			Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 92),
			TextSize = 10, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
		})
		if ability.nextValueText then
			Theme.createText({
				Name = "AbilityNext", Parent = abilityPanel,
				Text = "Next: " .. ability.nextValueText,
				Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 104),
				TextSize = 10, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
			})
		end
	end

	local statsPanel = Theme.createFrame({
		Name = "StatsPanel", Parent = detailPanel,
		Size = UDim2.new(1, 0, 0, 118), Position = UDim2.fromOffset(0, 304),
		Bg = Theme.Colors.StoneDeep, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.stroke(statsPanel, Theme.Colors.Gold, 1, 0.5)
	local statsLayout = Instance.new("UIListLayout")
	statsLayout.Padding = UDim.new(0, 4)
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = statsPanel
	Theme.padding(statsPanel, 8, 8, 10, 10)

	Theme.createStatRow(statsPanel, "Harvest Speed", "x" .. string.format("%.2f", stats.HarvestSpeed or 1), 1, 9)
	Theme.createStatRow(statsPanel, "Flight Speed", string.format("%.1f", stats.FlightSpeed or 0), 2, 9)
	Theme.createStatRow(statsPanel, "Carry Capacity", tostring(stats.CarryCapacity or 0) .. " Essence", 3, 9)
	Theme.createStatRow(statsPanel, "Crit Chance", string.format("%.1f%%", (stats.CriticalHarvestChance or 0) * 100), 4, 9)

	local isTraining = string.lower(dragon.state or "") == "training"
	local isEquipped = dragon.isEquipped == true
	local upgradeCost = dragon.upgradeCost or 0
	local canUpgrade = rosterState.essence >= upgradeCost and not isTraining and isEquipped
	local btnWidth = math.max(84, math.floor((detailPanel.AbsoluteSize.X - 36) / 4))

	createActionButton(
		detailPanel, "EquipButton", isEquipped and "Unequip" or "Equip",
		UDim2.new(0, 0, 1, -40), UDim2.fromOffset(btnWidth, 32),
		isEquipped and Theme.Colors.NavyEdge or Theme.Colors.Success,
		function()
			if isEquipped then
				UnequipDragon:FireServer(dragon.id)
			else
				EquipDragon:FireServer(dragon.id)
			end
		end
	)

	createActionButton(
		detailPanel, "FavoriteButton", dragon.isFavorite and "Unfavorite" or "Favorite",
		UDim2.new(0, btnWidth + 6, 1, -40), UDim2.fromOffset(btnWidth, 32),
		dragon.isFavorite and Theme.Colors.GoldBright or Theme.Colors.StoneDeep,
		function()
			SetDragonFavorite:FireServer(dragon.id, not dragon.isFavorite)
		end
	)

	createActionButton(
		detailPanel, "LockButton", dragon.isLocked and "Unlock" or "Lock",
		UDim2.new(0, (btnWidth + 6) * 2, 1, -40), UDim2.fromOffset(btnWidth, 32),
		dragon.isLocked and Theme.Colors.Danger or Theme.Colors.StoneDeep,
		function()
			SetDragonLocked:FireServer(dragon.id, not dragon.isLocked)
		end
	)

	createActionButton(
		detailPanel, "UpgradeButton", "Upgrade",
		UDim2.new(0, (btnWidth + 6) * 3, 1, -40), UDim2.fromOffset(btnWidth, 32),
		canUpgrade and Theme.Colors.Success or Theme.Colors.StoneDeep,
		function()
			local model = findDragonModel(dragon.id)
			if model then
				UpgradeDragon:FireServer(model)
			elseif _G.DragonIslandNotify then
				_G.DragonIslandNotify("Dragon is not available right now.", Theme.Colors.Danger)
			end
		end
	)

	createActionButton(
		detailPanel, "TrainButton", isTraining and "Training" or "Train",
		UDim2.new(0, 0, 1, -78), UDim2.fromOffset(btnWidth, 32),
		(isTraining or not isEquipped) and Theme.Colors.StoneDeep or Theme.Colors.Crystal,
		function()
			if isTraining or not isEquipped then
				return
			end
			if _G.DragonIslandOpenTrainingForDragon then
				_G.DragonIslandOpenTrainingForDragon(dragon.id, "Send this dragon to the Academy.")
			elseif _G.DragonIslandOpenTrainingUI then
				_G.DragonIslandOpenTrainingUI("Send this dragon to the Academy.")
			end
		end
	)

	createActionButton(
		detailPanel, "FocusButton", "Focus",
		UDim2.new(0, btnWidth + 6, 1, -78), UDim2.fromOffset(btnWidth, 32),
		isEquipped and Theme.Colors.NavActive or Theme.Colors.StoneDeep,
		function()
			if not isEquipped then
				return
			end
			local model = findDragonModel(dragon.id)
			if model and model.PrimaryPart then
				local camera = workspace.CurrentCamera
				local target = model.PrimaryPart.Position + Vector3.new(0, 3, 10)
				camera.CFrame = CFrame.new(target, model.PrimaryPart.Position + Vector3.new(0, 2, 0))
			end
		end
	)
end

local function renderDragonsTab()
	clearContent()
	local visibleDragons = getFilteredDragons()
	setHeader("DRAGON ROSTER", getCapacitySubtitle())

	local toolbar = Theme.createFrame({
		Name = "Toolbar", Parent = contentFrame,
		Size = UDim2.new(1, -12, 0, 34), Position = UDim2.fromOffset(6, 6),
		BgTransparency = 1, ZIndex = 4,
	})

	Theme.createButton({
		Name = "EquipBestButton", Parent = toolbar, Text = "Equip Best",
		Size = UDim2.fromOffset(108, 30), Position = UDim2.fromOffset(0, 0),
		Bg = Theme.Colors.Gold, TextSize = 12,
		OnClick = function()
			EquipBestDragons:FireServer()
		end,
	})

	Theme.createButton({
		Name = "SortButton", Parent = toolbar, Text = "Sort: " .. sortMode,
		Size = UDim2.fromOffset(140, 30), Position = UDim2.fromOffset(116, 0),
		Bg = Theme.Colors.NavyEdge, TextSize = 12,
		OnClick = function()
			local currentIndex = table.find(sortModes, sortMode) or 1
			sortMode = sortModes[(currentIndex % #sortModes) + 1]
			renderDragonsTab()
		end,
	})

	Theme.createButton({
		Name = "FilterButton", Parent = toolbar, Text = "Filter: " .. filterMode,
		Size = UDim2.fromOffset(150, 30), Position = UDim2.fromOffset(264, 0),
		Bg = Theme.Colors.NavyEdge, TextSize = 12,
		OnClick = function()
			local currentIndex = table.find(filterModes, filterMode) or 1
			filterMode = filterModes[(currentIndex % #filterModes) + 1]
			renderDragonsTab()
		end,
	})

	local listHost = Theme.createFrame({
		Name = "ListHost", Parent = contentFrame,
		Size = UDim2.new(1, -12, 1, -48), Position = UDim2.fromOffset(6, 44),
		BgTransparency = 1, ZIndex = 3,
	})

	if #visibleDragons == 0 then
		selectedDragonId = nil
		Theme.createEmptyState(
			listHost,
			Theme.Icons.Dragon,
			"No Dragons Found",
			"Try another filter or hatch eggs to grow your collection.",
			8
		)
		return
	end

	local listScroll = Theme.createScrollList(listHost, UDim2.new(LIST_WIDTH_SCALE, -4, 1, 0), UDim2.fromOffset(0, 0), 4)
	listScroll.Name = "ListScroll"
	local detailPanel = Theme.createDetailPanel(
		listHost,
		UDim2.new(1 - LIST_WIDTH_SCALE, -8, 1, 0),
		UDim2.new(LIST_WIDTH_SCALE, 8, 0, 0),
		4
	)
	detailPanel.Name = "DetailPanel"

	if not selectedDragonId or not getDragonById(selectedDragonId) then
		selectedDragonId = visibleDragons[1].id
	end

	for index, dragon in ipairs(visibleDragons) do
		local row = Theme.createListRow(listScroll, {
			Name = "DragonRow_" .. tostring(dragon.id),
			Text = "",
			Height = 56,
			LayoutOrder = index,
			ZIndex = 8,
			OnClick = function()
				selectDragon(dragon.id)
			end,
		})
		populateDragonListRow(row, dragon)
		listRows[dragon.id] = row
	end

	highlightDragonRows()
	renderDragonDetail(detailPanel, getDragonById(selectedDragonId))
end

local function populateCodexListRow(row, speciesId)
	row.Text = ""
	local discovered = isSpeciesDiscovered(speciesId)
	local displayName = DragonEggConfig.GetDragonDisplayName(speciesId)
	local speciesConfig = DragonAbilityConfig.GetSpeciesConfig(speciesId)
	local iconFrame, iconImage = Theme.createIconFrame(row, Theme.Icons.Dragon, 36, 8)
	iconFrame.Position = UDim2.fromOffset(6, 8)
	if not discovered then
		iconImage.ImageTransparency = 0.45
	end

	Theme.createText({
		Name = "RowName", Parent = row,
		Text = discovered and displayName or "???",
		Size = UDim2.new(1, -58, 0, 18), Position = UDim2.fromOffset(50, 8),
		TextSize = 13, Font = Theme.Fonts.Bold,
		Color = discovered and Theme.Colors.TextLight or Theme.Colors.TextMuted,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
	})

	Theme.createText({
		Name = "RowMeta", Parent = row,
		Text = discovered and (speciesConfig and speciesConfig.AbilityName or "Ability") or "Undiscovered",
		Size = UDim2.new(1, -58, 0, 16), Position = UDim2.fromOffset(50, 28),
		TextSize = 11, Font = Theme.Fonts.Regular,
		Color = discovered and Theme.Colors.Crystal or Theme.Colors.TextMuted, ZIndex = 9,
	})

	if discovered then
		Theme.createText({
			Name = "RowCompletion", Parent = row,
			Text = getSpeciesCompletion(speciesId) .. "%",
			Size = UDim2.fromOffset(42, 16), Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright,
			XAlign = Enum.TextXAlignment.Right, ZIndex = 9,
		})
	end
end

local function highlightCodexRows()
	for speciesId, row in codexRows do
		Theme.setListRowSelected(row, speciesId == selectedSpeciesId, Theme.Colors.Crystal)
	end
end

local function selectSpecies(speciesId)
	selectedSpeciesId = speciesId
	highlightCodexRows()
	local split = contentFrame and contentFrame:FindFirstChild("SplitLayout")
	local detailPanel = split and split:FindFirstChild("DetailPanel")
	if detailPanel then
		renderCodexDetail(detailPanel, speciesId)
	end
end

renderCodexDetail = function(detailPanel, speciesId)
	for _, child in detailPanel:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end

	if not speciesId then
		Theme.createEmptyState(
			detailPanel,
			Theme.Icons.Book,
			"Select a Species",
			"Browse the codex to learn about every dragon ability.",
			8
		)
		return
	end

	local discovered = isSpeciesDiscovered(speciesId)
	local speciesConfig = DragonAbilityConfig.GetSpeciesConfig(speciesId)
	local displayName = DragonEggConfig.GetDragonDisplayName(speciesId)
	local completion = getSpeciesCompletion(speciesId)
	local abilityLevel = 1
	if discovered then
		for _, dragon in rosterState.dragons do
			if getSpeciesIdFromDragon(dragon) == speciesId then
				abilityLevel = math.max(abilityLevel, (dragon.ability and dragon.ability.abilityLevel) or 1)
			end
		end
	end

	local iconFrame, iconImage = Theme.createIconFrame(detailPanel, Theme.Icons.Dragon, 88, 8)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	if not discovered then
		iconImage.ImageTransparency = 0.35
	end

	Theme.createText({
		Name = "DetailName", Parent = detailPanel,
		Text = discovered and displayName or "???",
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 96),
		TextSize = 20, Font = Theme.Fonts.Title,
		Color = discovered and Theme.Colors.TextLight or Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createText({
		Name = "DetailStatus", Parent = detailPanel,
		Text = discovered and "DISCOVERED" or "UNDISCOVERED",
		Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 122),
		TextSize = 12, Font = Theme.Fonts.Bold,
		Color = discovered and Theme.Colors.Success or Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createText({
		Name = "DetailCompletion", Parent = detailPanel,
		Text = "Codex Completion  " .. tostring(completion) .. "%",
		Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 142),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	local _, completionFill = Theme.createProgressBar(
		detailPanel,
		UDim2.new(1, 0, 0, 10),
		UDim2.fromOffset(0, 162),
		Theme.Colors.GoldBright
	)
	completionFill.ZIndex = 10
	completionFill.Size = UDim2.fromScale(math.clamp(completion / 100, 0, 1), 1)

	local infoPanel = Theme.createFrame({
		Name = "AbilityInfoPanel", Parent = detailPanel,
		Size = UDim2.new(1, 0, 0, 170), Position = UDim2.fromOffset(0, 184),
		Bg = Theme.Colors.StoneDeep, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.stroke(infoPanel, Theme.Colors.Crystal, 1.5, 0.35)

	Theme.createText({
		Name = "AbilityLabel", Parent = infoPanel, Text = "SPECIES ABILITY",
		Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 8),
		TextSize = 10, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})

	Theme.createText({
		Name = "AbilityName", Parent = infoPanel,
		Text = speciesConfig and speciesConfig.AbilityName or "Unknown",
		Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 24),
		TextSize = 16, Font = Theme.Fonts.Bold, Color = Theme.Colors.Crystal, ZIndex = 9,
	})

	Theme.createText({
		Name = "AbilityDescription", Parent = infoPanel,
		Text = speciesConfig and speciesConfig.Description or "",
		Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 48),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.Text, Wrapped = true, ZIndex = 9,
	})

	Theme.createText({
		Name = "AbilityValue", Parent = infoPanel,
		Text = "Value: " .. DragonAbilityConfig.FormatAbilityValue(speciesId, abilityLevel),
		Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 96),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 9,
	})

	if discovered then
		Theme.createText({
			Name = "AbilityHint", Parent = infoPanel,
			Text = "Merge dragons of this species to raise ability level and codex completion.",
			Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 118),
			TextSize = 11, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, Wrapped = true, ZIndex = 9,
		})
	else
		Theme.createText({
			Name = "AbilityHint", Parent = infoPanel,
			Text = "Hatch this dragon species to unlock its codex entry and track your mastery.",
			Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 118),
			TextSize = 11, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, Wrapped = true, ZIndex = 9,
		})
	end
end

local function renderCodexTab()
	clearContent()
	local allSpecies = DragonAbilityConfig.GetAllSpeciesIds()
	local discoveredCount = getDiscoveredSpeciesCount()
	setHeader(
		"DRAGON CODEX",
		discoveredCount .. " / " .. #allSpecies .. " species discovered"
	)

	local listScroll, detailPanel = createSplitLayout()

	if not selectedSpeciesId or not table.find(allSpecies, selectedSpeciesId) then
		selectedSpeciesId = allSpecies[1]
	end

	for index, speciesId in ipairs(allSpecies) do
		local row = Theme.createListRow(listScroll, {
			Name = "CodexRow_" .. speciesId,
			Text = "",
			Height = 52,
			LayoutOrder = index,
			ZIndex = 8,
			OnClick = function()
				selectSpecies(speciesId)
			end,
		})
		populateCodexListRow(row, speciesId)
		codexRows[speciesId] = row
	end

	highlightCodexRows()
	renderCodexDetail(detailPanel, selectedSpeciesId)
end

local function getInventoryItemById(itemId)
	for _, item in inventoryState.items do
		if item.itemId == itemId then
			return item
		end
	end
	return nil
end

local function applyInventoryPayload(payload)
	if typeof(payload) ~= "table" then
		return false
	end
	inventoryState.items = payload.items or {}
	return true
end

local function refreshInventory()
	local success, payload = pcall(function()
		return RequestInventoryData:InvokeServer()
	end)
	if success then
		applyInventoryPayload(payload)
	end
end

local function populateInventoryListRow(row, item)
	row.Text = ""
	local iconFrame = Theme.createIconFrame(row, Theme.Icons.Backpack, 36, 8)
	iconFrame.Position = UDim2.fromOffset(6, 8)

	Theme.createText({
		Name = "RowName", Parent = row,
		Text = item.displayName,
		Size = UDim2.new(1, -58, 0, 18), Position = UDim2.fromOffset(50, 6),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 9,
	})

	Theme.createText({
		Name = "RowMeta", Parent = row,
		Text = "Owned x" .. tostring(item.count),
		Size = UDim2.new(1, -58, 0, 16), Position = UDim2.fromOffset(50, 26),
		TextSize = 11, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextGold, ZIndex = 9,
	})
end

local function highlightInventoryRows()
	for itemId, row in inventoryRows do
		Theme.setListRowSelected(row, itemId == selectedItemId, Theme.Colors.Crystal)
	end
end

local function selectInventoryItem(itemId)
	selectedItemId = itemId
	highlightInventoryRows()
	local listHost = contentFrame and contentFrame:FindFirstChild("ListHost")
	local detailPanel = listHost and listHost:FindFirstChild("DetailPanel")
	if detailPanel then
		renderInventoryDetail(detailPanel, getInventoryItemById(itemId))
	end
end

renderInventoryDetail = function(detailPanel, item)
	for _, child in detailPanel:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIPadding" then
			child:Destroy()
		end
	end

	if not item then
		Theme.createEmptyState(
			detailPanel,
			Theme.Icons.Backpack,
			"Select an Item",
			"Choose a potion from the list to view its effect and use it.",
			8
		)
		return
	end

	local iconFrame = Theme.createIconFrame(detailPanel, Theme.Icons.Backpack, 88, 8)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 0)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)

	Theme.createText({
		Name = "DetailName", Parent = detailPanel,
		Text = item.displayName,
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 96),
		TextSize = 20, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createText({
		Name = "DetailMeta", Parent = detailPanel,
		Text = "Owned x" .. tostring(item.count),
		Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 122),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createText({
		Name = "DetailDescription", Parent = detailPanel,
		Text = item.description or "",
		Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 150),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.Text,
		Wrapped = true, XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createButton({
		Name = "UseButton", Parent = detailPanel, Text = "Use",
		Size = UDim2.fromOffset(160, 32), Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1), Bg = Theme.Colors.Success, TextSize = 13, ZIndex = 10,
		OnClick = function()
			UseInventoryItem:FireServer(item.itemId)
		end,
	})
end

local function renderInventoryTab()
	clearContent()
	setHeader("DRAGON INVENTORY", "Potions crafted at the Workshop")
	refreshInventory()

	if #inventoryState.items == 0 then
		Theme.createEmptyState(
			contentFrame,
			Theme.Icons.Backpack,
			"No Items Yet",
			"Craft potions at the Workshop, then use them here whenever you're ready.",
			8
		)
		return
	end

	local listScroll, detailPanel = createSplitLayout()

	if not selectedItemId or not getInventoryItemById(selectedItemId) then
		selectedItemId = inventoryState.items[1].itemId
	end

	for index, item in ipairs(inventoryState.items) do
		local row = Theme.createListRow(listScroll, {
			Name = "InventoryRow_" .. item.itemId,
			Text = "",
			Height = 52,
			LayoutOrder = index,
			ZIndex = 8,
			OnClick = function()
				selectInventoryItem(item.itemId)
			end,
		})
		populateInventoryListRow(row, item)
		inventoryRows[item.itemId] = row
	end

	highlightInventoryRows()
	renderInventoryDetail(detailPanel, getInventoryItemById(selectedItemId))
end

local function renderLeaderboardsTab()
	clearContent()
	setHeader("LEADERBOARDS", "Kingdom rankings and dragon power")
	Theme.createEmptyState(
		contentFrame,
		Theme.Icons.Trophy,
		"Leaderboards Coming Soon",
		"Top players ranked by Kingdom Level, Lifetime Dragon Essence, and Dragon Power.",
		8
	)
end

local function renderLoadingState()
	clearContent()
	setHeader("DRAGON ROSTER", "Loading your dragons...")
	Theme.createText({
		Name = "LoadingLabel", Parent = contentFrame, Text = "Fetching dragon roster...",
		Size = UDim2.new(1, -40, 0, 32), Position = UDim2.new(0.5, 0, 0.45, 0),
		AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 16, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Center, ZIndex = 3,
	})
end

local function setSidebarActive(tabId)
	activeTab = tabId
	for id, btn in sidebarButtons do
		Theme.setNavActive(btn, id == tabId)
	end
	if tabId == "Dragons" then
		renderDragonsTab()
	elseif tabId == "Codex" then
		renderCodexTab()
	elseif tabId == "Inventory" then
		renderInventoryTab()
	elseif tabId == "Leaderboards" then
		renderLeaderboardsTab()
	end
end

local function applyRosterPayload(payload)
	if typeof(payload) ~= "table" then
		return false
	end
	rosterState.dragons = payload.dragons or {}
	rosterState.essence = payload.essence or rosterState.essence
	rosterState.activeCount = payload.activeCount or rosterState.activeCount
	rosterState.activeMax = payload.activeMax or rosterState.activeMax
	rosterState.storageCount = payload.storageCount or rosterState.storageCount
	rosterState.storageMax = payload.storageMax or rosterState.storageMax
	return true
end

local function refreshRoster()
	local success, payload = pcall(function()
		return RequestDragonMergeData:InvokeServer()
	end)
	if success then
		applyRosterPayload(payload)
	end
	if rosterPanel and rosterPanel.Visible and activeTab == "Dragons" then
		renderDragonsTab()
	elseif rosterPanel and rosterPanel.Visible and activeTab == "Codex" then
		renderCodexTab()
	end
	return success and #rosterState.dragons > 0
end

local function refreshRosterWithRetry()
	local token = refreshToken + 1
	refreshToken = token
	if refreshRoster() then
		return
	end
	task.spawn(function()
		for _, delay in { 0.25, 0.5, 1, 2 } do
			task.wait(delay)
			if token ~= refreshToken or not rosterPanel or not rosterPanel.Visible then
				return
			end
			if refreshRoster() then
				return
			end
		end
		if token == refreshToken and rosterPanel and rosterPanel.Visible then
			if activeTab == "Dragons" then
				renderDragonsTab()
			elseif activeTab == "Codex" then
				renderCodexTab()
			end
		end
	end)
end

local function closeRoster()
	if not rosterGui or not rosterPanel then
		return
	end
	Theme.closeModalWindow(rosterGui, rosterPanel, dimFrame, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(rosterGui.Name)
		end
	end)
end

local function buildUi()
	rosterGui = Instance.new("ScreenGui")
	rosterGui.Name = "DragonRosterUI"
	rosterGui.ResetOnSpawn = false
	rosterGui.IgnoreGuiInset = true
	rosterGui.DisplayOrder = 32
	rosterGui.Enabled = false
	rosterGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	rosterGui.Parent = playerGui

	dimFrame = Theme.createDim(rosterGui, 20)
	dimFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeRoster()
		end
	end)

	rosterPanel = Theme.createPanel({
		Name = "DragonRosterPanel", Parent = rosterGui,
		Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT), Visible = false, ZIndex = 25,
	})
	rosterPanel:SetAttribute("OpenPosition", rosterPanel.Position)
	Theme.createCloseButton(rosterPanel, function()
		closeRoster()
	end, 30)

	local windowHeader = Theme.createWindowHeader(
		rosterPanel,
		"DRAGON ROSTER",
		"My Dragons  0 / " .. tostring(rosterState.activeMax),
		30
	)
	headerTitle = windowHeader:FindFirstChild("Title")
	headerSubtitle = windowHeader:FindFirstChild("Subtitle")

	local sidebar = Theme.createFrame({
		Name = "Sidebar", Parent = rosterPanel,
		Size = UDim2.fromOffset(148, PANEL_HEIGHT - 78),
		Position = UDim2.fromOffset(14, 64), Bg = Theme.Colors.StoneDark, Corner = Theme.Corner.Large, ZIndex = 26,
	})
	Theme.stroke(sidebar, Theme.Colors.Gold, 1.5, 0.35)
	Theme.padding(sidebar, 8, 8, 8, 8)
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = sidebar

	for index, item in sidebarItems do
		local btn = Theme.createNavButton(
			sidebar,
			item.id .. "Tab",
			item.icon,
			item.label,
			index,
			function()
				if item.panelId and UIBridge.OpenPanel(item.panelId) then
					return
				end
				setSidebarActive(item.id)
			end
		)
		btn.ZIndex = 5
		sidebarButtons[item.id] = btn
	end

	contentFrame = Theme.createContentArea(
		rosterPanel,
		UDim2.new(1, -186, 1, -78),
		UDim2.fromOffset(172, 64),
		26
	)
	contentFrame.Name = "Content"
	contentFrame.ClipsDescendants = true

	local shine = rosterPanel:FindFirstChild("CrystalShine")
	if shine then
		shine.ZIndex = 2
	end
end

local function openRoster(message)
	if not rosterGui then
		buildUi()
	end
	activeTab = "Dragons"
	for id, btn in sidebarButtons do
		Theme.setNavActive(btn, id == "Dragons")
	end
	renderLoadingState()
	rosterGui.Enabled = true
	Theme.raiseModalGui(rosterGui)
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(rosterGui.Name)
	end
	Theme.tweenOpen(rosterPanel, dimFrame)
	if not refreshRoster() then
		refreshRosterWithRetry()
	end
	-- Callers like DragonStorageFullClient pass a contextual hint (e.g. "Manage your
	-- dragon storage.") the same way openEggShop/openTrainingUI do; show it once as the
	-- header subtitle. If refreshRosterWithRetry() is still pending, its own renderDragonsTab
	-- call will overwrite this with the capacity subtitle once roster data loads — acceptable
	-- since this is a one-off hint, not persistent state.
	if typeof(message) == "string" and message ~= "" and headerSubtitle then
		headerSubtitle.Text = message
	end
end

_G.DragonIslandOpenRoster = openRoster
_G.DragonIslandCloseRoster = closeRoster

UIBridge.RegisterPanel("Dragons", { Open = openRoster, Close = closeRoster })

HarvestUIUpdate.OnClientEvent:Connect(function(_essence, _dragonCount, _activeWorkers, maxDragons, storageCount, storageMax)
	if typeof(maxDragons) == "number" then
		rosterState.activeMax = maxDragons
	end
	if typeof(storageCount) == "number" then
		rosterState.storageCount = storageCount
	end
	if typeof(storageMax) == "number" then
		rosterState.storageMax = storageMax
	end
	if rosterPanel and rosterPanel.Visible and activeTab == "Dragons" then
		setHeader("DRAGON ROSTER", getCapacitySubtitle())
	end
end)

DragonMergeUpdate.OnClientEvent:Connect(function(payload)
	if applyRosterPayload(payload) and rosterPanel and rosterPanel.Visible then
		if activeTab == "Dragons" then
			renderDragonsTab()
		elseif activeTab == "Codex" then
			renderCodexTab()
		end
	end
end)

UpgradeDragon.OnClientEvent:Connect(function()
	if rosterPanel and rosterPanel.Visible then
		refreshRoster()
	end
end)

InventoryStateUpdated.OnClientEvent:Connect(function(payload)
	if applyInventoryPayload(payload) and rosterPanel and rosterPanel.Visible and activeTab == "Inventory" then
		renderInventoryTab()
	end
	if payload and payload.message and _G.DragonIslandNotify then
		_G.DragonIslandNotify(payload.message, Theme.Colors.Navy)
	end
end)

buildUi()
