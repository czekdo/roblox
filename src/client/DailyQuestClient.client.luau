local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestUpdate = QuestEvents:WaitForChild("QuestUpdate")
local ClaimQuest = QuestEvents:WaitForChild("ClaimQuest")

local questCards = {}
local questList = nil
local dayLabel = nil
local questScreenGui = nil
local questRoot = nil
local questDim = nil

local function setQuestVisible(visible)
	if not questScreenGui or not questRoot then
		return
	end
	if visible then
		questScreenGui.Enabled = true
		if not questRoot.Visible then
			Theme.raiseModalGui(questScreenGui)
			if _G.DragonIslandNotifyModalOpened then
				_G.DragonIslandNotifyModalOpened(questScreenGui.Name)
			end
		end
		Theme.tweenOpen(questRoot, questDim)
	else
		Theme.closeModalWindow(questScreenGui, questRoot, questDim, function()
			if _G.DragonIslandNotifyModalClosed then
				_G.DragonIslandNotifyModalClosed(questScreenGui.Name)
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

local function createQuestUI()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("DailyQuestUI")
	if existing then
		existing:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DailyQuestUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 28
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	Theme.applyScreenSafeArea(screenGui)
	questScreenGui = screenGui

	local dim = Theme.createDim(screenGui, 1)
	dim.Name = "DimBackground"
	dim.Visible = false
	questDim = dim
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setQuestVisible(false)
		end
	end)

	local root = Theme.createPanel({
		Name = "QuestPanel", Parent = screenGui,
		Size = UDim2.fromOffset(680, 580), Visible = false,
	})
	questRoot = root
	root:SetAttribute("OpenPosition", root.Position)
	Theme.createCloseButton(root, function()
		setQuestVisible(false)
	end, 30)
	Theme.createWindowHeader(root, "Quest Journal", "Daily challenges for your dragon kingdom", 8)

	dayLabel = Theme.createText({
		Name = "DayLabel", Parent = root, Text = "",
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(18, 68),
		TextSize = 12, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 8,
	})

	questList, _ = Theme.createScrollList(root, UDim2.new(1, -32, 1, -108), UDim2.fromOffset(16, 92), 8)
	questList.Name = "QuestList"
end

local function openQuests()
	setQuestVisible(true)
end
local function closeQuests()
	setQuestVisible(false)
end

_G.DragonIslandOpenQuests = openQuests
_G.DragonIslandOpenDailyQuests = openQuests
_G.DragonIslandCloseDailyQuests = closeQuests

UIBridge.RegisterPanel("DailyQuests", { Open = openQuests, Close = closeQuests })

local function createQuestCard(quest, order)
	local card = Theme.createFrame({
		Name = quest.Id, Parent = questList,
		Size = UDim2.new(1, -4, 0, 118), Bg = Theme.Colors.Navy, Corner = Theme.Corner.Medium,
		BgTransparency = 0.05, LayoutOrder = order, ZIndex = 9,
	})
	Theme.stroke(card, Theme.Colors.Gold, 1.5, 0.45)

	Theme.createIconFrame(card, Theme.Icons.Scroll, 52, 10)
	local iconFrame = card:FindFirstChild("IconFrame")
	if iconFrame then
		iconFrame.Position = UDim2.fromOffset(10, 12)
	end

	local title = Theme.createText({
		Name = "QuestTitle", Parent = card, Text = quest.Title,
		Size = UDim2.new(1, -170, 0, 22), Position = UDim2.fromOffset(72, 10),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})

	local reward = Theme.createText({
		Name = "Reward", Parent = card, Text = quest.RewardText,
		Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(72, 34),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextGold,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})

	local progressText = Theme.createText({
		Name = "ProgressText", Parent = card, Text = "0 / 0",
		Size = UDim2.new(1, -170, 0, 16), Position = UDim2.fromOffset(72, 56),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.CrystalSoft, ZIndex = 10,
	})

	local progressBack, progressFill = Theme.createProgressBar(
		card, UDim2.new(1, -170, 0, 12), UDim2.fromOffset(72, 78), Theme.Colors.Crystal
	)
	progressBack.ZIndex = 10
	progressFill.ZIndex = 11

	local claimButton = Theme.createButton({
		Name = "ClaimButton", Parent = card, Text = "Claim",
		Size = UDim2.fromOffset(78, 34), Position = UDim2.new(1, -88, 0.5, -17),
		AnchorPoint = Vector2.new(0, 0.5), Bg = Theme.Colors.Success, TextSize = 13, ZIndex = 10,
		OnClick = function()
			ClaimQuest:FireServer(quest.Id)
		end,
	})

	questCards[quest.Id] = {
		Card = card,
		ProgressText = progressText,
		ProgressFill = progressFill,
		ClaimButton = claimButton,
		Reward = reward,
	}
end

local function updateQuestCard(quest)
	local card = questCards[quest.Id]
	if not card then
		return
	end

	local ratio = math.clamp((quest.Progress or 0) / math.max(1, quest.Target or 1), 0, 1)
	card.ProgressFill.Size = UDim2.fromScale(ratio, 1)
	card.ProgressText.Text = tostring(quest.Progress or 0) .. " / " .. tostring(quest.Target or 0)

	if quest.Claimed then
		card.ClaimButton.Text = "Done"
		card.ClaimButton.Active = false
		card.ClaimButton.AutoButtonColor = false
		card.ClaimButton.BackgroundColor3 = Theme.Colors.Slate
		card.ProgressFill.BackgroundColor3 = Theme.Colors.Success
		setCardBorder(card.Card, true)
	elseif quest.ReadyToClaim then
		card.ClaimButton.Text = "Claim"
		card.ClaimButton.Active = true
		card.ClaimButton.AutoButtonColor = true
		card.ClaimButton.BackgroundColor3 = Theme.Colors.Success
		card.ProgressFill.BackgroundColor3 = Theme.Colors.GoldBright
		setCardBorder(card.Card, true)
	else
		card.ClaimButton.Text = "Claim"
		card.ClaimButton.Active = false
		card.ClaimButton.AutoButtonColor = false
		card.ClaimButton.BackgroundColor3 = Theme.Colors.NavyEdge
		card.ProgressFill.BackgroundColor3 = Theme.Colors.Crystal
		setCardBorder(card.Card, false)
	end
end

createQuestUI()

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then
		return
	end
	if prompt.ActionText == "Quests" and prompt.ObjectText == "Quest Hall" then
		if _G.DragonIslandOpenQuests then
			_G.DragonIslandOpenQuests()
		end
	end
end)

QuestUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.Quests) ~= "table" then
		return
	end

	if dayLabel then
		dayLabel.Text = "Resets daily • " .. tostring(payload.DayKey or "")
	end

	for order, quest in payload.Quests do
		if not questCards[quest.Id] then
			createQuestCard(quest, order)
		end
		updateQuestCard(quest)
	end
end)