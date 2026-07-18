local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local AchievementConfig = require(ReplicatedStorage:WaitForChild("AchievementConfig"))
local AchievementEvents = ReplicatedStorage:WaitForChild("AchievementEvents")
local AchievementUpdate = AchievementEvents:WaitForChild("AchievementUpdate")
local ClaimAchievement = AchievementEvents:WaitForChild("ClaimAchievement")
local AchievementCompleted = AchievementEvents:WaitForChild("AchievementCompleted")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui
local rootPanel
local dimFrame
local categoryButtons = {}
local achievementCards = {}
local achievementList
local selectedCategory = "Dragons"
local latestPayload

local function getIcon(iconKey)
	return Theme.Icons[iconKey] or Theme.Icons.Trophy
end

local function setVisible(visible)
	if not screenGui or not rootPanel then
		return
	end
	if visible then
		screenGui.Enabled = true
		Theme.raiseModalGui(screenGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(screenGui.Name)
		end
		Theme.tweenOpen(rootPanel, dimFrame)
	else
		Theme.closeModalWindow(screenGui, rootPanel, dimFrame, function()
			if _G.DragonIslandNotifyModalClosed then
				_G.DragonIslandNotifyModalClosed(screenGui.Name)
			end
		end)
	end
end

local function setCardBorder(card, highlight)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = highlight and Theme.Colors.GoldBright or Theme.Colors.Gold
		stroke.Thickness = highlight and 2.5 or 1.5
		stroke.Transparency = highlight and 0.05 or 0.45
	end
end

local function updateAchievementCard(achievement)
	local card = achievementCards[achievement.Id]
	if not card then
		return
	end
	local ratio = math.clamp((achievement.Progress or 0) / math.max(1, achievement.Target or 1), 0, 1)
	card.ProgressFill.Size = UDim2.fromScale(ratio, 1)
	card.ProgressText.Text = tostring(achievement.Progress or 0) .. " / " .. tostring(achievement.Target or 0)
	card.Reward.Text = achievement.RewardText or ""

	if achievement.Claimed then
		card.ClaimButton.Text = "✔ Claimed"
		card.ClaimButton.Active = false
		card.ClaimButton.AutoButtonColor = false
		card.ClaimButton.BackgroundColor3 = Theme.Colors.Slate
		card.Status.Text = "✔ Claimed"
		card.Status.TextColor3 = Theme.Colors.TextMuted
		card.ProgressFill.BackgroundColor3 = Theme.Colors.Success
		setCardBorder(card.Card, false)
	elseif achievement.Completed or achievement.ReadyToClaim then
		card.ClaimButton.Text = "Claim"
		card.ClaimButton.Active = true
		card.ClaimButton.AutoButtonColor = true
		card.ClaimButton.BackgroundColor3 = Theme.Colors.Success
		card.Status.Text = "✔ Completed"
		card.Status.TextColor3 = Theme.Colors.Success
		card.ProgressFill.BackgroundColor3 = Theme.Colors.GoldBright
		setCardBorder(card.Card, true)
	else
		card.ClaimButton.Text = "Claim"
		card.ClaimButton.Active = false
		card.ClaimButton.AutoButtonColor = false
		card.ClaimButton.BackgroundColor3 = Theme.Colors.NavyEdge
		card.Status.Text = ""
		card.ProgressFill.BackgroundColor3 = Theme.Colors.Crystal
		setCardBorder(card.Card, false)
	end
end

local function createAchievementCard(achievement, order)
	local card = Theme.createFrame({
		Name = achievement.Id, Parent = achievementList,
		Size = UDim2.new(1, -4, 0, 128), Bg = Theme.Colors.Navy, Corner = Theme.Corner.Medium,
		BgTransparency = 0.05, LayoutOrder = order, ZIndex = 9,
	})
	Theme.stroke(card, Theme.Colors.Gold, 1.5, 0.45)

	Theme.createIconFrame(card, getIcon(achievement.IconKey), 52, 10)
	local iconFrame = card:FindFirstChild("IconFrame")
	if iconFrame then
		iconFrame.Position = UDim2.fromOffset(10, 14)
	end

	Theme.createText({
		Name = "Title", Parent = card, Text = achievement.Title,
		Size = UDim2.new(1, -180, 0, 22), Position = UDim2.fromOffset(72, 10),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})

	Theme.createText({
		Name = "Description", Parent = card, Text = achievement.Description,
		Size = UDim2.new(1, -180, 0, 18), Position = UDim2.fromOffset(72, 32),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})

	local progressText = Theme.createText({
		Name = "ProgressText", Parent = card, Text = "0 / 0",
		Size = UDim2.new(1, -180, 0, 16), Position = UDim2.fromOffset(72, 54),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.CrystalSoft, ZIndex = 10,
	})

	local progressBack, progressFill = Theme.createProgressBar(
		card, UDim2.new(1, -180, 0, 12), UDim2.fromOffset(72, 76), Theme.Colors.Crystal
	)
	progressBack.ZIndex = 10
	progressFill.ZIndex = 11

	local reward = Theme.createText({
		Name = "Reward", Parent = card, Text = achievement.RewardText or "",
		Size = UDim2.new(1, -180, 0, 16), Position = UDim2.fromOffset(72, 94),
		TextSize = 11, Font = Theme.Fonts.Body, Color = Theme.Colors.TextGold,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})

	local status = Theme.createText({
		Name = "Status", Parent = card, Text = "",
		Size = UDim2.fromOffset(90, 18), Position = UDim2.new(1, -168, 0, 12),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.Success,
		XAlign = Enum.TextXAlignment.Right, ZIndex = 10,
	})

	local claimButton = Theme.createButton({
		Name = "ClaimButton", Parent = card, Text = "Claim",
		Size = UDim2.fromOffset(78, 34), Position = UDim2.new(1, -88, 1, -42),
		AnchorPoint = Vector2.new(0, 0.5), Bg = Theme.Colors.Success, TextSize = 13, ZIndex = 10,
		OnClick = function()
			ClaimAchievement:FireServer(achievement.Id)
		end,
	})

	achievementCards[achievement.Id] = {
		Card = card,
		ProgressText = progressText,
		ProgressFill = progressFill,
		Reward = reward,
		ClaimButton = claimButton,
		Status = status,
	}
	updateAchievementCard(achievement)
end

local function renderAchievements()
	if not achievementList then
		return
	end
	for _, child in achievementList:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIPadding" and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	table.clear(achievementCards)

	if not latestPayload or typeof(latestPayload.achievements) ~= "table" then
		return
	end

	local order = 0
	for _, achievement in latestPayload.achievements do
		if achievement.Category == selectedCategory and not (achievement.Hidden and not achievement.Completed and not achievement.Claimed) then
			order += 1
			createAchievementCard(achievement, order)
		end
	end
end

local function setCategoryActive(categoryId)
	selectedCategory = categoryId
	for id, btn in categoryButtons do
		Theme.setNavActive(btn, id == categoryId)
	end
	renderAchievements()
end

local function buildUi()
	local existing = playerGui:FindFirstChild("AchievementUI")
	if existing then
		existing:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AchievementUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 29
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	Theme.applyScreenSafeArea(screenGui)

	dimFrame = Theme.createDim(screenGui, 1)
	dimFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setVisible(false)
		end
	end)

	rootPanel = Theme.createPanel({
		Name = "AchievementPanel", Parent = screenGui,
		Size = UDim2.fromOffset(820, 580), Visible = false,
	})
	rootPanel:SetAttribute("OpenPosition", rootPanel.Position)
	Theme.createCloseButton(rootPanel, function()
		setVisible(false)
	end, 30)
	Theme.createWindowHeader(rootPanel, "Achievements", "Long-term goals for your dragon kingdom", 8)

	local sidebar = Theme.createFrame({
		Name = "CategorySidebar", Parent = rootPanel,
		Size = UDim2.fromOffset(156, 470), Position = UDim2.fromOffset(16, 84),
		Bg = Theme.Colors.StoneDark, Corner = Theme.Corner.Large, ZIndex = 8,
	})
	Theme.stroke(sidebar, Theme.Colors.Gold, 1.5, 0.35)
	Theme.padding(sidebar, 8, 8, 8, 8)
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = sidebar

	for index, category in AchievementConfig.Categories do
		local label = category.Emoji .. " " .. category.Name
		local btn = Theme.createNavButton(sidebar, category.Id .. "Tab", getIcon(category.IconKey), label, index, function()
			setCategoryActive(category.Id)
		end, 9)
		categoryButtons[category.Id] = btn
	end

	local content = Theme.createContentArea(rootPanel, UDim2.new(1, -196, 1, -100), UDim2.fromOffset(180, 84), 8)
	achievementList, _ = Theme.createScrollList(content, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), 9)
	achievementList.Name = "AchievementList"
end

local function showAchievementToast(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local message = "🏆 Achievement Complete\n" .. tostring(payload.Title or "Achievement")
	if payload.RewardText and payload.RewardText ~= "" then
		message ..= "\nReward: " .. payload.RewardText
	end
	if _G.DragonIslandNotify then
		_G.DragonIslandNotify(message, Theme.Colors.GoldBright)
	end
end

local function openAchievements()
	if not screenGui then
		buildUi()
	end
	setCategoryActive(selectedCategory)
	setVisible(true)
end

local function closeAchievements()
	setVisible(false)
end

_G.DragonIslandOpenAchievements = openAchievements
_G.DragonIslandCloseAchievements = closeAchievements

UIBridge.RegisterPanel("Achievements", { Open = openAchievements, Close = closeAchievements })

AchievementUpdate.OnClientEvent:Connect(function(payload)
	latestPayload = payload
	if typeof(payload) ~= "table" or typeof(payload.achievements) ~= "table" then
		return
	end
	if screenGui and screenGui.Enabled then
		renderAchievements()
	else
		for _, achievement in payload.achievements do
			if achievementCards[achievement.Id] then
				updateAchievementCard(achievement)
			end
		end
	end
end)

AchievementCompleted.OnClientEvent:Connect(showAchievementToast)

buildUi()
