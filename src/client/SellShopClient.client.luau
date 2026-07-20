local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))

local SellEvents = ReplicatedStorage:WaitForChild("SellEvents")
local RequestSellableDragons = SellEvents:WaitForChild("RequestSellableDragons")
local SellDragons = SellEvents:WaitForChild("SellDragons")
local SellResult = SellEvents:WaitForChild("SellResult")

local InventoryEvents = ReplicatedStorage:WaitForChild("InventoryEvents")
local RequestInventoryData = InventoryEvents:WaitForChild("RequestInventoryData")
local SellInventoryItem = InventoryEvents:WaitForChild("SellInventoryItem")
local InventoryStateUpdated = InventoryEvents:WaitForChild("InventoryStateUpdated")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Ancient" }

local screenGui, panel, dim
local dragonTabButton, itemsTabButton
local dragonPane, itemsPane
local dragonScroll, dragonSummaryLabel, dragonSellButton
local itemsScroll

local activeTab = "Dragons"
local dragonList = {}
local selectedDragonIds = {}

-- ============================================================
-- Confirmation popup
-- ============================================================

local confirmGui

local function showConfirm(message, onConfirm)
	if confirmGui then
		confirmGui:Destroy()
	end
	confirmGui = Instance.new("ScreenGui")
	confirmGui.Name = "SellConfirmUI"
	confirmGui.ResetOnSpawn = false
	confirmGui.DisplayOrder = 60
	confirmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	confirmGui.Parent = playerGui

	local box = Theme.createPanel({ Name = "ConfirmBox", Parent = confirmGui, Size = UDim2.fromOffset(360, 170), ZIndex = 30 })
	box.Position = UDim2.new(0.5, 0, 0, 90)
	box.AnchorPoint = Vector2.new(0.5, 0)
	Theme.createText({
		Name = "Message", Parent = box, Text = message,
		Size = UDim2.new(1, -24, 0, 70), Position = UDim2.fromOffset(12, 16),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = true, XAlign = Enum.TextXAlignment.Center, ZIndex = 31,
	})
	Theme.createButton({
		Name = "Confirm", Parent = box, Text = "Sell",
		Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(12, 110),
		Bg = Theme.Colors.Success, TextSize = 14, ZIndex = 31,
		OnClick = function()
			confirmGui:Destroy()
			confirmGui = nil
			onConfirm()
		end,
	})
	Theme.createButton({
		Name = "Cancel", Parent = box, Text = "Cancel",
		Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -12, 0, 110), AnchorPoint = Vector2.new(1, 0),
		Bg = Theme.Colors.Danger, TextSize = 14, ZIndex = 31,
		OnClick = function()
			confirmGui:Destroy()
			confirmGui = nil
		end,
	})
end

-- ============================================================
-- Dragons tab
-- ============================================================

local function dragonRowLabel(d)
	return string.format("%s (%s Lv.%d%s)", d.displayName or d.dragonType, d.rarity, d.level,
		d.evolutionLevel and d.evolutionLevel > 0 and (" " .. string.rep("★", d.evolutionLevel)) or "")
end

local function updateDragonSummary()
	local count = 0
	local total = 0
	for _, d in dragonList do
		if selectedDragonIds[d.id] then
			count += 1
			total += d.sellValue
		end
	end
	dragonSummaryLabel.Text = count > 0
		and string.format("Selected: %d dragon(s) — %d Essence", count, total)
		or "No dragons selected"
	dragonSellButton.Text = count > 0 and ("Sell Selected (" .. count .. ")") or "Sell Selected"
	dragonSellButton.Active = count > 0
end

local rebuildDragonList

local function doSellSelected()
	local ids = {}
	for id in selectedDragonIds do
		table.insert(ids, id)
	end
	if #ids == 0 then
		return
	end
	SellDragons:FireServer(ids)
end

local function setupDragonFilterBar(parent)
	local bar = Theme.createFrame({
		Name = "FilterBar", Parent = parent,
		Size = UDim2.new(1, 0, 0, 64), BgTransparency = 1, ZIndex = 8,
	})

	local topRow = Theme.createFrame({ Name = "TopRow", Parent = bar, Size = UDim2.new(1, 0, 0, 28), BgTransparency = 1, ZIndex = 8 })
	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.Padding = UDim.new(0, 6)
	topLayout.Parent = topRow

	Theme.createButton({
		Name = "SelectAll", Parent = topRow, Text = "Select All", Size = UDim2.fromOffset(90, 26),
		TextSize = 11, Bg = Theme.Colors.NavyEdge, ZIndex = 9,
		OnClick = function()
			for _, d in dragonList do
				selectedDragonIds[d.id] = true
			end
			rebuildDragonList()
		end,
	})
	Theme.createButton({
		Name = "SelectNone", Parent = topRow, Text = "Select None", Size = UDim2.fromOffset(90, 26),
		TextSize = 11, Bg = Theme.Colors.NavyEdge, ZIndex = 9,
		OnClick = function()
			table.clear(selectedDragonIds)
			rebuildDragonList()
		end,
	})
	Theme.createButton({
		Name = "SellAll", Parent = topRow, Text = "Sell ALL", Size = UDim2.fromOffset(90, 26),
		TextSize = 11, Bg = Theme.Colors.Danger, ZIndex = 9,
		OnClick = function()
			if #dragonList == 0 then
				return
			end
			local total = 0
			for _, d in dragonList do
				total += d.sellValue
			end
			showConfirm(string.format("Sell ALL %d dragons for %d Essence?", #dragonList, total), function()
				local ids = {}
				for _, d in dragonList do
					table.insert(ids, d.id)
				end
				SellDragons:FireServer(ids)
			end)
		end,
	})

	local rarityRow = Instance.new("ScrollingFrame")
	rarityRow.Name = "RarityRow"
	rarityRow.Size = UDim2.new(1, 0, 0, 28)
	rarityRow.Position = UDim2.fromOffset(0, 32)
	rarityRow.BackgroundTransparency = 1
	rarityRow.BorderSizePixel = 0
	rarityRow.ScrollingDirection = Enum.ScrollingDirection.X
	rarityRow.ScrollBarThickness = 4
	rarityRow.AutomaticCanvasSize = Enum.AutomaticSize.X
	rarityRow.CanvasSize = UDim2.fromOffset(0, 0)
	rarityRow.ZIndex = 8
	rarityRow.Parent = bar
	local rarityLayout = Instance.new("UIListLayout")
	rarityLayout.FillDirection = Enum.FillDirection.Horizontal
	rarityLayout.Padding = UDim.new(0, 6)
	rarityLayout.Parent = rarityRow

	for _, rarityName in RARITY_ORDER do
		Theme.createButton({
			Name = "Rarity_" .. rarityName, Parent = rarityRow, Text = rarityName,
			Size = UDim2.fromOffset(80, 26), TextSize = 11,
			Bg = Theme.getRarityColor(rarityName), ZIndex = 9,
			OnClick = function()
				table.clear(selectedDragonIds)
				for _, d in dragonList do
					if d.rarity == rarityName then
						selectedDragonIds[d.id] = true
					end
				end
				rebuildDragonList()
			end,
		})
	end
end

local dragonFilterBarBuilt = false

rebuildDragonList = function()
	if not dragonFilterBarBuilt then
		setupDragonFilterBar(dragonPane)
		dragonFilterBarBuilt = true
	end
	for _, child in dragonScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #dragonList == 0 then
		Theme.createEmptyState(dragonScroll, Theme.Icons.Dragon, "No Dragons In Storage", "Unequip a dragon or hatch one to see it here.", 8)
		updateDragonSummary()
		return
	end
	for i, d in dragonList do
		local selected = selectedDragonIds[d.id] == true
		local row = Theme.createFrame({
			Name = "Dragon_" .. d.id, Parent = dragonScroll,
			Size = UDim2.new(1, 0, 0, 40), Bg = selected and Theme.Colors.Gold or Theme.Colors.PanelInner,
			Corner = Theme.Corner.Small, ZIndex = 8, LayoutOrder = i,
		})
		Theme.padding(row, 6, 6, 10, 10)
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 9
		button.Parent = row
		button.Activated:Connect(function()
			selectedDragonIds[d.id] = not selected or nil
			rebuildDragonList()
		end)
		Theme.createText({
			Name = "Label", Parent = row, Text = dragonRowLabel(d),
			Size = UDim2.new(1, -80, 1, 0), TextSize = 13, Font = Theme.Fonts.Body,
			Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
		})
		Theme.createText({
			Name = "Value", Parent = row, Text = tostring(d.sellValue),
			Size = UDim2.fromOffset(70, 28), Position = UDim2.new(1, -70, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
			XAlign = Enum.TextXAlignment.Right, ZIndex = 10,
		})
	end
	updateDragonSummary()
end

local function refreshDragons()
	local ok, list = pcall(function()
		return RequestSellableDragons:InvokeServer()
	end)
	if ok and typeof(list) == "table" then
		dragonList = list
		table.clear(selectedDragonIds)
		rebuildDragonList()
	end
end

-- ============================================================
-- Items tab
-- ============================================================

local itemSellValues = {}

local function rebuildItemsList(payload)
	for _, child in itemsScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local items = (payload and payload.items) or {}
	if #items == 0 then
		Theme.createEmptyState(itemsScroll, Theme.Icons.Backpack, "No Extra Items", "Craft potions at the Workshop to sell duplicates here.", 8)
		return
	end
	for i, item in items do
		local row = Theme.createFrame({
			Name = "Item_" .. item.itemId, Parent = itemsScroll,
			Size = UDim2.new(1, 0, 0, 52), Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Small, ZIndex = 8, LayoutOrder = i,
		})
		Theme.padding(row, 6, 6, 10, 10)
		Theme.createText({
			Name = "Label", Parent = row, Text = item.displayName .. "  x" .. tostring(item.count),
			Size = UDim2.new(1, -180, 1, 0), TextSize = 13, Font = Theme.Fonts.Body,
			Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
		})
		Theme.createButton({
			Name = "SellOne", Parent = row, Text = "Sell 1",
			Size = UDim2.fromOffset(80, 32), Position = UDim2.new(1, -170, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			Bg = Theme.Colors.NavyEdge, TextSize = 11, ZIndex = 9,
			OnClick = function()
				SellInventoryItem:FireServer(item.itemId, 1)
			end,
		})
		Theme.createButton({
			Name = "SellExcess", Parent = row, Text = "Sell Extra",
			Size = UDim2.fromOffset(80, 32), Position = UDim2.new(1, -84, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			Bg = Theme.Colors.Success, TextSize = 11, ZIndex = 9, Active = item.count > 1,
			OnClick = function()
				if item.count > 1 then
					SellInventoryItem:FireServer(item.itemId, item.count - 1)
				end
			end,
		})
	end
end

local function refreshItems()
	local ok, payload = pcall(function()
		return RequestInventoryData:InvokeServer()
	end)
	if ok then
		rebuildItemsList(payload)
	end
end

-- ============================================================
-- Panel + tabs
-- ============================================================

local function setActiveTab(tabName)
	activeTab = tabName
	dragonPane.Visible = tabName == "Dragons"
	itemsPane.Visible = tabName == "Items"
	dragonSummaryLabel.Visible = tabName == "Dragons"
	dragonSellButton.Visible = tabName == "Dragons"
	dragonTabButton.BackgroundColor3 = tabName == "Dragons" and Theme.Colors.Gold or Theme.Colors.NavyEdge
	itemsTabButton.BackgroundColor3 = tabName == "Items" and Theme.Colors.Gold or Theme.Colors.NavyEdge
	if tabName == "Dragons" then
		refreshDragons()
	else
		refreshItems()
	end
end

local function ensureUi()
	if screenGui then
		return
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SellShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 40
	screenGui.Enabled = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	Theme.applyScreenSafeArea(screenGui)

	dim = Theme.createDim(screenGui, 1)
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UIBridge.ClosePanel("SellShop")
		end
	end)

	panel = Theme.createPanel({ Name = "SellShopPanel", Parent = screenGui, Size = UDim2.fromOffset(440, 560), Visible = false, ZIndex = 25 })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		UIBridge.ClosePanel("SellShop")
	end, 30)
	Theme.createWindowHeader(panel, "Sell Shop", "Convert extra dragons and items into Essence", 30)

	local tabRow = Theme.createFrame({ Name = "TabRow", Parent = panel, Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 84), BgTransparency = 1, ZIndex = 8 })
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabRow

	dragonTabButton = Theme.createButton({
		Name = "DragonsTab", Parent = tabRow, Text = "Dragons", Size = UDim2.fromOffset(120, 34),
		TextSize = 13, Bg = Theme.Colors.Gold, ZIndex = 9,
		OnClick = function() setActiveTab("Dragons") end,
	})
	itemsTabButton = Theme.createButton({
		Name = "ItemsTab", Parent = tabRow, Text = "Items", Size = UDim2.fromOffset(120, 34),
		TextSize = 13, Bg = Theme.Colors.NavyEdge, ZIndex = 9,
		OnClick = function() setActiveTab("Items") end,
	})

	dragonPane = Theme.createFrame({
		Name = "DragonPane", Parent = panel, Size = UDim2.new(1, -32, 1, -196), Position = UDim2.fromOffset(16, 124),
		BgTransparency = 1, ZIndex = 8,
	})

	dragonScroll = Instance.new("ScrollingFrame")
	dragonScroll.Name = "DragonScroll"
	dragonScroll.Size = UDim2.new(1, 0, 1, -68)
	dragonScroll.Position = UDim2.fromOffset(0, 68)
	dragonScroll.BackgroundTransparency = 1
	dragonScroll.BorderSizePixel = 0
	dragonScroll.ScrollBarThickness = 8
	dragonScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dragonScroll.CanvasSize = UDim2.fromOffset(0, 0)
	dragonScroll.ZIndex = 8
	dragonScroll.Parent = dragonPane
	local dragonListLayout = Instance.new("UIListLayout")
	dragonListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dragonListLayout.Padding = UDim.new(0, 4)
	dragonListLayout.Parent = dragonScroll

	itemsPane = Theme.createFrame({
		Name = "ItemsPane", Parent = panel, Size = UDim2.new(1, -32, 1, -196), Position = UDim2.fromOffset(16, 124),
		BgTransparency = 1, ZIndex = 8, Visible = false,
	})
	itemsScroll = Instance.new("ScrollingFrame")
	itemsScroll.Name = "ItemsScroll"
	itemsScroll.Size = UDim2.fromScale(1, 1)
	itemsScroll.BackgroundTransparency = 1
	itemsScroll.BorderSizePixel = 0
	itemsScroll.ScrollBarThickness = 8
	itemsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	itemsScroll.CanvasSize = UDim2.fromOffset(0, 0)
	itemsScroll.ZIndex = 8
	itemsScroll.Parent = itemsPane
	local itemsListLayout = Instance.new("UIListLayout")
	itemsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	itemsListLayout.Padding = UDim.new(0, 4)
	itemsListLayout.Parent = itemsScroll

	dragonSummaryLabel = Theme.createText({
		Name = "Summary", Parent = panel, Text = "No dragons selected",
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.new(0.5, 0, 1, -66), AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	dragonSellButton = Theme.createButton({
		Name = "SellSelectedButton", Parent = panel, Text = "Sell Selected",
		Size = UDim2.new(1, -32, 0, 44), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1),
		Bg = Theme.Colors.Success, TextSize = 15, ZIndex = 9, Active = false,
		OnClick = function()
			local count = 0
			local total = 0
			for _, d in dragonList do
				if selectedDragonIds[d.id] then
					count += 1
					total += d.sellValue
				end
			end
			if count == 0 then
				return
			end
			showConfirm(string.format("Sell %d dragon(s) for %d Essence?", count, total), doSellSelected)
		end,
	})
end

local function openSellShopPanel()
	ensureUi()
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	UIBridge.NotifyModalOpened(screenGui.Name)
	Theme.tweenOpen(panel, dim)
	setActiveTab(activeTab)
end

local function closeSellShopPanel()
	if not screenGui or not panel then
		return
	end
	Theme.closeModalWindow(screenGui, panel, dim, function()
		UIBridge.NotifyModalClosed(screenGui.Name)
	end)
end

UIBridge.RegisterPanel("SellShop", { Open = openSellShopPanel, Close = closeSellShopPanel })
_G.DragonIslandOpenSellShop = openSellShopPanel

SellResult.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	UIBridge.Notify(payload.message or "")
	if screenGui and screenGui.Enabled and activeTab == "Dragons" then
		refreshDragons()
	end
end)

InventoryStateUpdated.OnClientEvent:Connect(function(payload)
	if screenGui and screenGui.Enabled and activeTab == "Items" then
		rebuildItemsList(payload)
	end
end)

print("[SellShopClient] Sell shop UI ready")
