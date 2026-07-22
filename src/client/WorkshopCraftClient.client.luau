local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CraftEvents = ReplicatedStorage:WaitForChild("CraftEvents")
local RequestCraftData = CraftEvents:WaitForChild("RequestCraftData")
local CraftItem = CraftEvents:WaitForChild("CraftItem")
local CraftStateUpdated = CraftEvents:WaitForChild("CraftStateUpdated")

local screenGui
local panel
local recipeList
local detailPanel
local detailIcon
local detailNameLabel
local detailTierLabel
local detailDescLabel
local detailCostLabel
local craftButton
local statusLabel
local tierLabel
local recipeRows = {}
local selectedRecipeId = nil

local tierColors = {
	[1] = Theme.Colors.TextMuted,
	[2] = Theme.Colors.Success,
	[3] = Theme.Colors.Crystal,
	[4] = Theme.Colors.Purple,
	[5] = Theme.Colors.Gold,
	[6] = Theme.Colors.Danger,
	[7] = Theme.Colors.GoldBright,
	[8] = Theme.Colors.Gem,
	[9] = Theme.Colors.TextLight,
}

local function formatNumber(value)
	local n = tonumber(value) or 0
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	end
	if n >= 10000 then
		return string.format("%.0fK", n / 1000)
	end
	if n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local function setStatus(text, good)
	if statusLabel then
		statusLabel.Text = text or ""
		statusLabel.TextColor3 = good and Theme.Colors.Success or Theme.Colors.Danger
	end
end

local function closeCraftPanel()
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

local function updateDetailPanel(recipe)
	for recipeId, row in recipeRows do
		Theme.setListRowSelected(row, recipeId == selectedRecipeId, tierColors[recipe and recipe.tier or 1] or Theme.Colors.Crystal)
	end

	if not recipe then
		if detailIcon then detailIcon.Image = Theme.Icons.Hammer end
		if detailNameLabel then detailNameLabel.Text = "Select a Recipe" end
		if detailTierLabel then detailTierLabel.Text = "" end
		if detailDescLabel then detailDescLabel.Text = "Choose a recipe from the workshop list to preview its details and craft it." end
		if detailCostLabel then detailCostLabel.Text = "" end
		if craftButton then
			craftButton.Text = "Select Recipe"
			craftButton.Active = false
			craftButton.AutoButtonColor = false
			craftButton.BackgroundColor3 = Theme.Colors.Slate
		end
		return
	end

	if detailIcon then detailIcon.Image = recipe.icon or Theme.Icons.Hammer end
	if detailNameLabel then detailNameLabel.Text = recipe.displayName end
	if detailTierLabel then
		detailTierLabel.Text = "Tier " .. tostring(recipe.tier or 1)
		detailTierLabel.TextColor3 = tierColors[recipe.tier] or Theme.Colors.TextMuted
	end
	if detailDescLabel then detailDescLabel.Text = recipe.description or "" end
	if detailCostLabel then detailCostLabel.Text = "Craft Cost: " .. formatNumber(recipe.cost) .. " Dragon Essence" end
	if craftButton then
		craftButton.Text = "Craft for " .. formatNumber(recipe.cost)
		craftButton.Active = true
		craftButton.AutoButtonColor = true
		craftButton.BackgroundColor3 = Theme.Colors.GoldDark
	end
end

local function buildUi()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WorkshopCraftUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 30
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local dim = Theme.createDim(screenGui, 1)
	dim.Name = "DimBackground"
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeCraftPanel()
		end
	end)

	panel = Theme.createPanel({ Name = "CraftPanel", Parent = screenGui, Size = UDim2.fromOffset(720, 540), Visible = false })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		closeCraftPanel()
	end, 30)
	Theme.createWindowHeader(panel, "Workshop Crafting", "Forge items using Dragon Essence", 8)

	tierLabel = Theme.createText({
		Name = "TierLabel", Parent = panel, Text = "Recipe Tier 1",
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(18, 68),
		TextSize = 13, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 8,
	})

	recipeList = Theme.createScrollList(panel, UDim2.fromOffset(260, 400), UDim2.fromOffset(16, 92), 8)
	recipeList.Name = "RecipeList"

	detailPanel = Theme.createDetailPanel(panel, UDim2.fromOffset(410, 400), UDim2.fromOffset(290, 92), 8)
	local iconFrame, iconImage = Theme.createIconFrame(detailPanel, Theme.Icons.Hammer, 80, 9)
	detailIcon = iconImage
	iconFrame.Position = UDim2.fromOffset(0, 0)

	detailNameLabel = Theme.createText({
		Name = "DetailName", Parent = detailPanel, Text = "Select a Recipe",
		Size = UDim2.new(1, -96, 0, 26), Position = UDim2.fromOffset(96, 0),
		TextSize = 19, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight, Wrapped = false, ZIndex = 9,
	})
	detailTierLabel = Theme.createText({
		Name = "DetailTier", Parent = detailPanel, Text = "",
		Size = UDim2.new(1, -96, 0, 18), Position = UDim2.fromOffset(96, 28),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 9,
	})
	detailDescLabel = Theme.createText({
		Name = "DetailDesc", Parent = detailPanel,
		Text = "Choose a recipe from the workshop list to preview its details and craft it.",
		Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 92),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, YAlign = Enum.TextYAlignment.Top, ZIndex = 9,
	})
	detailCostLabel = Theme.createText({
		Name = "DetailCost", Parent = detailPanel, Text = "",
		Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 180),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 9,
	})

	craftButton = Theme.createButton({
		Name = "CraftButton", Parent = detailPanel, Text = "Select Recipe",
		Size = UDim2.new(1, 0, 0, 46), Position = UDim2.new(0, 0, 1, -46),
		AnchorPoint = Vector2.new(0, 1), Bg = Theme.Colors.Slate, TextSize = 16, ZIndex = 9,
		AutoButtonColor = false,
		OnClick = function()
			if selectedRecipeId then
				CraftItem:FireServer(selectedRecipeId)
			end
		end,
	})

	statusLabel = Theme.createText({
		Name = "StatusLabel", Parent = panel, Text = "Select a recipe to craft",
		Size = UDim2.new(1, -32, 0, 28), Position = UDim2.new(0, 16, 1, -36),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 8,
	})
end

local function refreshState(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if tierLabel then
		tierLabel.Text = "Recipe Tier " .. tostring(payload.recipeTier or 1) .. "  •  " .. formatNumber(payload.essence or 0) .. " essence"
	end

	for _, child in recipeList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	table.clear(recipeRows)

	local recipes = typeof(payload.recipes) == "table" and payload.recipes or {}
	local selectedRecipe = nil

	for index, recipe in recipes do
		local row = Theme.createListRow(recipeList, {
			Name = recipe.id .. "Row",
			Text = recipe.displayName .. "\nT" .. tostring(recipe.tier or 1) .. "  •  " .. formatNumber(recipe.cost) .. " essence",
			LayoutOrder = index,
			Height = 56,
			ZIndex = 9,
			OnClick = function()
				selectedRecipeId = recipe.id
				updateDetailPanel(recipe)
			end,
		})
		recipeRows[recipe.id] = row
		if selectedRecipeId == recipe.id or (not selectedRecipeId and index == 1) then
			selectedRecipeId = recipe.id
			selectedRecipe = recipe
		end
	end

	if selectedRecipeId and not selectedRecipe then
		for _, recipe in recipes do
			if recipe.id == selectedRecipeId then
				selectedRecipe = recipe
				break
			end
		end
	end
	updateDetailPanel(selectedRecipe)

	if typeof(payload.message) == "string" and payload.message ~= "" then
		local good = string.find(payload.message, "Crafted", 1, true) ~= nil
		setStatus(payload.message, good)
	end
end

local function openPanel()
	if not screenGui then
		buildUi()
	end
	local dim = screenGui:FindFirstChild("DimBackground")
	local opening = panel and not panel.Visible
	screenGui.Enabled = true
	if opening then
		Theme.raiseModalGui(screenGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(screenGui.Name)
		end
	end
	Theme.tweenOpen(panel, dim)
	local success, result = pcall(function()
		return RequestCraftData:InvokeServer()
	end)
	if success then
		refreshState(result)
	else
		setStatus("Craft data unavailable", false)
	end
end

_G.DragonIslandOpenCrafting = openPanel
_G.DragonIslandCloseCrafting = closeCraftPanel

UIBridge.RegisterPanel("Workshop", { Open = openPanel, Close = closeCraftPanel })

CraftStateUpdated.OnClientEvent:Connect(refreshState)

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then
		return
	end
	if prompt.Name == "WorkshopCraftPrompt" then
		openPanel()
	end
end)