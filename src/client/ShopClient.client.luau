local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local MonetizationConfig = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))

local RewardPassEvents = ReplicatedStorage:WaitForChild("RewardPassEvents")
local RequestRewardPassState = RewardPassEvents:WaitForChild("RequestRewardPassState")
local ClaimFreeReward = RewardPassEvents:WaitForChild("ClaimFreeReward")
local ClaimPremiumReward = RewardPassEvents:WaitForChild("ClaimPremiumReward")
local RewardPassResult = RewardPassEvents:WaitForChild("RewardPassResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui, panel, dim
local detailsGui
local rewardPassFreeButton, rewardPassPremiumButton, rewardPassPremiumLabel

local function createRow(parent, name, description, buttonText, available, onClick, onDetails)
	local row = Theme.createFrame({
		Name = "Row_" .. name, Parent = parent,
		Size = UDim2.new(1, 0, 0, 64),
		Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.padding(row, 8, 8, 12, 12)

	Theme.createText({
		Name = "Name", Parent = row, Text = name,
		Size = UDim2.new(1, onDetails and -166 or -110, 0, 20), Position = UDim2.fromOffset(0, 4),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})
	Theme.createText({
		Name = "Description", Parent = row, Text = description or "",
		Size = UDim2.new(1, onDetails and -166 or -110, 0, 20), Position = UDim2.fromOffset(0, 24),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})

	if onDetails then
		Theme.createButton({
			Name = "DetailsButton", Parent = row, Text = "Details",
			Size = UDim2.fromOffset(56, 36), Position = UDim2.new(1, -104, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), TextSize = 12, ZIndex = 9,
			Bg = Theme.Colors.NavyEdge, OnClick = onDetails,
		})
	end

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

-- Full perk breakdown for a GamePass, shown via its "Details" button - the Shop row itself only
-- has room for a one-line description, not enough to actually explain what a purchase includes.
local function openVipDetailsPanel(pass)
	if detailsGui then
		detailsGui:Destroy()
	end
	detailsGui = Instance.new("ScreenGui")
	detailsGui.Name = "GamePassDetailsUI"
	detailsGui.ResetOnSpawn = false
	detailsGui.DisplayOrder = 60
	detailsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	detailsGui.Parent = playerGui

	local detailsDim = Theme.createDim(detailsGui, 29)
	detailsDim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			detailsGui:Destroy()
			detailsGui = nil
		end
	end)

	local box = Theme.createPanel({ Name = "DetailsBox", Parent = detailsGui, Size = UDim2.fromOffset(380, 560), ZIndex = 30 })
	Theme.createCloseButton(box, function()
		detailsGui:Destroy()
		detailsGui = nil
	end, 31)
	Theme.createWindowHeader(box, pass.Name, "What you get", 31)

	-- Preview image so players see the actual dragon before buying, not just a text description.
	if pass.Key == "VIP" then
		local imageFrame = Theme.createFrame({
			Name = "PreviewFrame", Parent = box, Size = UDim2.new(1, -32, 0, 160), Position = UDim2.fromOffset(16, 84),
			Bg = Theme.Colors.NavyDeep, Corner = Theme.Corner.Medium, ZIndex = 31,
		})
		Theme.stroke(imageFrame, Theme.Colors.Gold, 1.5, 0.3)
		local image = Instance.new("ImageLabel")
		image.Name = "DragonPreview"
		image.BackgroundTransparency = 1
		image.Size = UDim2.new(1, -12, 1, -12)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Image = "rbxassetid://101419979417867"
		image.ScaleType = Enum.ScaleType.Fit
		image.ZIndex = 32
		image.Parent = imageFrame
	end

	local perks = {
		"🐉 Exclusive Royal Dragon - not available anywhere else",
		"⚔️ Epic rarity, 2.2x species power - a strong dragon from day one",
		"✨ Unique ability: Royal Blessing - up to 10% chance per harvest for +100% bonus essence",
		"👑 Yours forever - granted once, permanently, the moment you own the pass",
	}

	local listFrame = Theme.createFrame({
		Name = "PerkList", Parent = box, Size = UDim2.new(1, -32, 0, 200), Position = UDim2.fromOffset(16, pass.Key == "VIP" and 256 or 84),
		BgTransparency = 1, ZIndex = 31,
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = listFrame
	for i, perk in perks do
		Theme.createText({
			Name = "Perk" .. i, Parent = listFrame, Text = perk,
			Size = UDim2.new(1, 0, 0, 36), TextSize = 14, Font = Theme.Fonts.Body,
			Color = Theme.Colors.TextLight, Wrapped = true, XAlign = Enum.TextXAlignment.Left,
			ZIndex = 32, LayoutOrder = i,
		})
	end

	Theme.createButton({
		Name = "BuyButton", Parent = box, Text = pass.Id > 0 and "Buy" or "Coming Soon",
		Size = UDim2.new(1, -32, 0, 44), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1),
		Bg = pass.Id > 0 and Theme.Colors.Success or Theme.Colors.TextMuted, TextSize = 15, ZIndex = 31,
		OnClick = pass.Id > 0 and function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end or nil,
	})
end

-- Two-tier "what you get" showcase card: Free (everyone, one-time claim) on top, Premium (VIP Pass
-- owners, one-time claim) on the bottom - shown together so players see the free reward AND get
-- enticed by what VIP unlocks, side by side.
local function refreshRewardPassCard()
	local ok, state = pcall(function()
		return RequestRewardPassState:InvokeServer()
	end)
	if not ok or typeof(state) ~= "table" then
		return
	end

	if state.freeClaimed then
		rewardPassFreeButton.Text = "Claimed"
		rewardPassFreeButton.Active = false
		rewardPassFreeButton.AutoButtonColor = false
		rewardPassFreeButton.BackgroundColor3 = Theme.Colors.TextMuted
	end

	if state.premiumClaimed then
		rewardPassPremiumButton.Text = "Claimed"
		rewardPassPremiumButton.Active = false
		rewardPassPremiumButton.AutoButtonColor = false
		rewardPassPremiumButton.BackgroundColor3 = Theme.Colors.TextMuted
	elseif not state.ownsVip then
		rewardPassPremiumButton.Text = "Get VIP"
		rewardPassPremiumButton.BackgroundColor3 = Theme.Colors.Gold
	end
end

local function createRewardPassCard(parent)
	local card = Theme.createFrame({
		Name = "RewardPassCard", Parent = parent, Size = UDim2.new(1, 0, 0, 210),
		Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8,
	})

	-- FREE half
	local freeHalf = Theme.createFrame({
		Name = "FreeHalf", Parent = card, Size = UDim2.new(1, 0, 0, 96),
		Position = UDim2.fromOffset(0, 0), Bg = Theme.Colors.NavyEdge, Corner = Theme.Corner.Medium, ZIndex = 9,
	})
	Theme.padding(freeHalf, 8, 8, 12, 12)
	Theme.createText({
		Name = "Tag", Parent = freeHalf, Text = "FREE - EVERYONE",
		Size = UDim2.new(1, 0, 0, 16), TextSize = 11, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	Theme.createText({
		Name = "Item", Parent = freeHalf, Text = "🧪 Essence Boost Potion",
		Size = UDim2.new(1, -110, 0, 24), Position = UDim2.fromOffset(0, 20),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	Theme.createText({
		Name = "Desc", Parent = freeHalf, Text = "+25% essence for 10 minutes",
		Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(0, 44),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	rewardPassFreeButton = Theme.createButton({
		Name = "ClaimButton", Parent = freeHalf, Text = "Claim",
		Size = UDim2.fromOffset(96, 36), Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5), TextSize = 13, ZIndex = 10, Bg = Theme.Colors.Success,
		-- Hover disabled: this button's color changes after creation (once claimed/owns-VIP state
		-- is known), and Theme.attachHover keeps re-asserting its creation-time base color on
		-- MouseLeave, fighting any later manual recolor.
		Hover = false,
		OnClick = function()
			ClaimFreeReward:FireServer()
		end,
	})

	-- PREMIUM half
	local premiumHalf = Theme.createFrame({
		Name = "PremiumHalf", Parent = card, Size = UDim2.new(1, 0, 0, 106),
		Position = UDim2.fromOffset(0, 100), Bg = Theme.Colors.NavyDeep, Corner = Theme.Corner.Medium, ZIndex = 9,
	})
	Theme.stroke(premiumHalf, Theme.Colors.Gold, 1.5, 0.4)
	Theme.padding(premiumHalf, 8, 8, 12, 12)
	Theme.createText({
		Name = "Tag", Parent = premiumHalf, Text = "PREMIUM - VIP PASS",
		Size = UDim2.new(1, 0, 0, 16), TextSize = 11, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextGold, XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	local dragonThumb = Instance.new("ImageButton")
	dragonThumb.Name = "DragonThumb"
	dragonThumb.Size = UDim2.fromOffset(28, 28)
	dragonThumb.Position = UDim2.fromOffset(0, 18)
	dragonThumb.BackgroundColor3 = Theme.Colors.NavyDeep
	dragonThumb.BorderSizePixel = 0
	dragonThumb.Image = "rbxassetid://101419979417867"
	dragonThumb.ScaleType = Enum.ScaleType.Fit
	dragonThumb.ZIndex = 10
	dragonThumb.Parent = premiumHalf
	Theme.corner(dragonThumb, Theme.Corner.Small)
	Theme.stroke(dragonThumb, Theme.Colors.Gold, 1, 0.4)
	dragonThumb.Activated:Connect(function()
		for _, pass in MonetizationConfig.GamePasses do
			if pass.Key == "VIP" then
				openVipDetailsPanel(pass)
				break
			end
		end
	end)

	Theme.createText({
		Name = "DragonShowcase", Parent = premiumHalf, Text = "🐉 Royal Dragon - included with VIP Pass (tap to preview)",
		Size = UDim2.new(1, -34, 0, 28), Position = UDim2.fromOffset(34, 18),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		Wrapped = true, XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	Theme.createText({
		Name = "Item", Parent = premiumHalf, Text = "🧪 Grand Elixir",
		Size = UDim2.new(1, -110, 0, 22), Position = UDim2.fromOffset(0, 44),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	Theme.createText({
		Name = "Desc", Parent = premiumHalf, Text = "+60% harvest speed for 25 minutes",
		Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(0, 66),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 10,
	})
	rewardPassPremiumButton = Theme.createButton({
		Name = "ClaimButton", Parent = premiumHalf, Text = "Claim",
		Size = UDim2.fromOffset(96, 36), Position = UDim2.new(1, 0, 1, -8),
		AnchorPoint = Vector2.new(1, 1), TextSize = 13, ZIndex = 10, Bg = Theme.Colors.Success,
		Hover = false,
		OnClick = function()
			if rewardPassPremiumButton.Text == "Get VIP" then
				for _, pass in MonetizationConfig.GamePasses do
					if pass.Key == "VIP" then
						openVipDetailsPanel(pass)
						break
					end
				end
				return
			end
			ClaimPremiumReward:FireServer()
		end,
	})

	return card
end

RewardPassResult.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	UIBridge.Notify(payload.message or "")
	refreshRewardPassCard()
end)

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

	local rewardCard = createRewardPassCard(scroll)
	rewardCard.LayoutOrder = order
	order += 1
	refreshRewardPassCard()

	Theme.createText({
		Name = "GamePassesHeader", Parent = scroll, Text = "GAME PASSES",
		Size = UDim2.new(1, 0, 0, 18), TextSize = 12, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Left, ZIndex = 8, LayoutOrder = order,
	})
	order += 1
	for _, pass in MonetizationConfig.GamePasses do
		local row = createRow(scroll, pass.Name, pass.Description, "Buy", pass.Id > 0, function()
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end, function()
			openVipDetailsPanel(pass)
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
