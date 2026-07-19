local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui, panel, dim

local function createRow(parent, name, description, buttonText, available, onClick)
	local row = Theme.createFrame({
		Name = "Row_" .. name, Parent = parent,
		Size = UDim2.new(1, 0, 0, 64),
		Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.padding(row, 8, 8, 12, 12)

	Theme.createText({
		Name = "Name", Parent = row, Text = name,
		Size = UDim2.new(1, -110, 0, 20), Position = UDim2.fromOffset(0, 4),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})
	Theme.createText({
		Name = "Description", Parent = row, Text = description or "",
		Size = UDim2.new(1, -110, 0, 20), Position = UDim2.fromOffset(0, 24),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})

	local button = Theme.createButton({
		Name = "BuyButton", Parent = row, Text = available and buttonText or "Coming Soon",
		Size = UDim2.fromOffset(96, 36), Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), TextSize = 13, ZIndex = 9,
		Bg = available and Theme.Colors.Success or Theme.Colors.TextMuted,
		OnClick = available and onClick or nil,
	})
	if not available then
		button.Active = false
		button.AutoButtonColor = false
	end
	return row
end

local function ensureUi()
	if screenGui then
		return
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 40
	screenGui.Enabled = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	Theme.applyScreenSafeArea(screenGui)

	dim = Theme.createDim(screenGui, 1)
	dim.Name = "DimBackground"
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UIBridge.ClosePanel("Shop")
		end
	end)

	panel = Theme.createPanel({ Name = "ShopPanel", Parent = screenGui, Size = UDim2.fromOffset(420, 520), Visible = false, ZIndex = 25 })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		UIBridge.ClosePanel("Shop")
	end, 30)
	Theme.createWindowHeader(panel, "Shop", "Support the kingdom", 30)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "ShopScroll"
	scroll.Size = UDim2.new(1, -32, 1, -104)
	scroll.Position = UDim2.fromOffset(16, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Active = true
	scroll.ZIndex = 6
	scroll.Parent = panel

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll

	local order = 1

	Theme.createText({
		Name = "GamePassesHeader", Parent = scroll, Text = "GAME PASSES",
		Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Left, ZIndex = 8, LayoutOrder = order,
	})
	order += 1
	for _, pass in MonetizationConfig.GamePasses do
		local row = createRow(scroll, pass.Name, pass.Description, "Buy", pass.Id > 0, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end)
		row.LayoutOrder = order
		order += 1
	end

	Theme.createText({
		Name = "ProductsHeader", Parent = scroll, Text = "GEMS",
		Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Left, ZIndex = 8, LayoutOrder = order,
	})
	order += 1
	for _, product in MonetizationConfig.DeveloperProducts do
		local row = createRow(scroll, product.Name, nil, "Buy", product.Id > 0, function()
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end)
		row.LayoutOrder = order
		order += 1
	end
end

local function openShopPanel()
	ensureUi()
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	UIBridge.NotifyModalOpened(screenGui.Name)
	Theme.tweenOpen(panel, dim)
end

local function closeShopPanel()
	if not screenGui or not panel then
		return
	end
	Theme.closeModalWindow(screenGui, panel, dim, function()
		UIBridge.NotifyModalClosed(screenGui.Name)
	end)
end

UIBridge.RegisterPanel("Shop", { Open = openShopPanel, Close = closeShopPanel })
_G.DragonIslandOpenShop = openShopPanel

print("[ShopClient] Shop UI ready")
