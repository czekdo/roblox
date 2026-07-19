local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local DailyRewardConfig = require(ReplicatedStorage:WaitForChild("DailyRewardConfig"))

local DailyRewardEvents = ReplicatedStorage:WaitForChild("DailyRewardEvents")
local RequestDailyRewardState = DailyRewardEvents:WaitForChild("RequestDailyRewardState")
local ClaimDailyReward = DailyRewardEvents:WaitForChild("ClaimDailyReward")
local DailyRewardResult = DailyRewardEvents:WaitForChild("DailyRewardResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ICON_BY_TYPE = {
	DragonEssence = Theme.Icons.Crystal,
	PremiumCurrency = Theme.Icons.Premium,
}

local screenGui, panel, dim
local statusLabel, claimButton, resultLabel
local dayCells = {}

local function ensureUi()
	if screenGui then
		return
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DailyRewardUI"
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
			UIBridge.ClosePanel("DailyReward")
		end
	end)

	panel = Theme.createPanel({ Name = "DailyRewardPanel", Parent = screenGui, Size = UDim2.fromOffset(400, 400), Visible = false, ZIndex = 25 })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		UIBridge.ClosePanel("DailyReward")
	end, 30)
	Theme.createWindowHeader(panel, "Daily Reward", "Log in every day for bigger rewards", 30)

	local track = Theme.createFrame({
		Name = "Track", Parent = panel,
		Size = UDim2.new(1, -32, 0, 92), Position = UDim2.fromOffset(16, 88),
		Bg = Color3.new(0, 0, 0), BgTransparency = 1, ZIndex = 8,
	})
	local trackLayout = Instance.new("UIListLayout")
	trackLayout.FillDirection = Enum.FillDirection.Horizontal
	trackLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	trackLayout.Padding = UDim.new(0, 4)
	trackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	trackLayout.Parent = track

	for i, entry in DailyRewardConfig.Track do
		local cell = Theme.createFrame({
			Name = "Day" .. i, Parent = track,
			Size = UDim2.fromOffset(48, 92),
			Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Small, ZIndex = 8, LayoutOrder = i,
		})
		Theme.createText({
			Name = "DayLabel", Parent = cell, Text = "Day " .. entry.Day,
			Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 4),
			TextSize = 10, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
			XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
		})
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(26, 26)
		icon.Position = UDim2.fromOffset(11, 24)
		icon.BackgroundTransparency = 1
		icon.Image = ICON_BY_TYPE[entry.Reward.Type] or Theme.Icons.Star
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 9
		icon.Parent = cell
		Theme.createText({
			Name = "Amount", Parent = cell, Text = "+" .. tostring(entry.Reward.Amount),
			Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 54),
			TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
			XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
		})
		local check = Theme.createText({
			Name = "Check", Parent = cell, Text = "✓",
			Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 72),
			TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.Success,
			XAlign = Enum.TextXAlignment.Center, ZIndex = 9, Visible = false,
		})
		dayCells[i] = { Cell = cell, Check = check }
	end

	statusLabel = Theme.createText({
		Name = "Status", Parent = panel, Text = "",
		Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 192),
		TextSize = 14, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, YAlign = Enum.TextYAlignment.Top, XAlign = Enum.TextXAlignment.Center, ZIndex = 8,
	})

	resultLabel = Theme.createText({
		Name = "Result", Parent = panel, Text = "",
		Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 232),
		TextSize = 16, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		Wrapped = true, XAlign = Enum.TextXAlignment.Center, ZIndex = 8,
	})

	claimButton = Theme.createButton({
		Name = "ClaimButton", Parent = panel, Text = "Claim",
		Size = UDim2.new(1, -32, 0, 48), Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1), Bg = Theme.Colors.Success, TextSize = 16, ZIndex = 9,
		OnClick = function()
			if not claimButton.Active then
				return
			end
			claimButton.Active = false
			ClaimDailyReward:FireServer()
		end,
	})
end

local function updateTrackVisual(streak, canClaim)
	local n = #DailyRewardConfig.Track
	local currentPosition = ((streak - 1) % n) + 1
	for i, entry in dayCells do
		local isPast = i < currentPosition
		local isCurrent = i == currentPosition
		local isFuture = i > currentPosition
		entry.Cell.BackgroundTransparency = isFuture and 0.6 or 0
		local existingStroke = entry.Cell:FindFirstChildOfClass("UIStroke")
		if existingStroke then
			existingStroke:Destroy()
		end
		if isCurrent then
			Theme.stroke(entry.Cell, canClaim and Theme.Colors.Gold or Theme.Colors.TextMuted, 2, canClaim and 0 or 0.4)
		end
		entry.Check.Visible = isPast or (isCurrent and not canClaim)
	end
end

local function formatCountdown(secondsLeft)
	secondsLeft = math.max(0, math.floor(secondsLeft))
	local h = math.floor(secondsLeft / 3600)
	local m = math.floor((secondsLeft % 3600) / 60)
	local s = secondsLeft % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local countdownThread = nil
local function stopCountdown()
	if countdownThread then
		task.cancel(countdownThread)
		countdownThread = nil
	end
end

local function applyState(state)
	if not statusLabel then
		return
	end
	stopCountdown()
	updateTrackVisual(state.streak, state.canClaim)
	UIBridge.Fire("DailyRewardAvailableChanged", state.canClaim)
	if state.canClaim then
		statusLabel.Text = "Your daily reward is ready!"
		claimButton.Visible = true
		claimButton.Active = true
	else
		claimButton.Visible = false
		local function update()
			local secondsLeft = state.nextResetAt - os.time()
			if secondsLeft <= 0 then
				statusLabel.Text = "Your daily reward is ready!"
				claimButton.Visible = true
				claimButton.Active = true
				stopCountdown()
				return
			end
			statusLabel.Text = "Already claimed today. Next reward in:\n" .. formatCountdown(secondsLeft)
		end
		update()
		countdownThread = task.spawn(function()
			while panel and panel.Visible and not claimButton.Visible do
				task.wait(1)
				update()
			end
		end)
	end
end

local function refreshState()
	local ok, state = pcall(function()
		return RequestDailyRewardState:InvokeServer()
	end)
	if not ok or typeof(state) ~= "table" then
		statusLabel.Text = "Could not load daily reward state."
		claimButton.Visible = false
		return
	end
	applyState(state)
end

local function openDailyRewardPanel()
	ensureUi()
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	UIBridge.NotifyModalOpened(screenGui.Name)
	Theme.tweenOpen(panel, dim)
	resultLabel.Text = ""
	refreshState()
end

local function closeDailyRewardPanel()
	if not screenGui or not panel then
		return
	end
	Theme.closeModalWindow(screenGui, panel, dim, function()
		UIBridge.NotifyModalClosed(screenGui.Name)
	end)
end

UIBridge.RegisterPanel("DailyReward", { Open = openDailyRewardPanel, Close = closeDailyRewardPanel })
_G.DragonIslandOpenDailyReward = openDailyRewardPanel

DailyRewardResult.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not payload.success then
		if statusLabel then
			statusLabel.Text = payload.message or "Already claimed today."
		end
		if payload.nextResetAt then
			applyState({ canClaim = false, streak = payload.streak or 1, nextResetAt = payload.nextResetAt })
		end
		return
	end
	if resultLabel then
		resultLabel.Text = "🎉 " .. tostring(payload.message or "Reward claimed!")
	end
	applyState({ canClaim = false, streak = payload.streak, nextResetAt = payload.nextResetAt })
end)

-- Refresh the HUD badge on join without opening the panel.
task.spawn(function()
	task.wait(2)
	local ok, state = pcall(function()
		return RequestDailyRewardState:InvokeServer()
	end)
	if ok and typeof(state) == "table" then
		UIBridge.Fire("DailyRewardAvailableChanged", state.canClaim)
	end
end)

print("[DailyRewardClient] Daily reward UI ready")
