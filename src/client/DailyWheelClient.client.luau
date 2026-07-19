local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local AssetService = game:GetService("AssetService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local DailyWheelConfig = require(ReplicatedStorage:WaitForChild("DailyWheelConfig"))

local WheelEvents = ReplicatedStorage:WaitForChild("WheelEvents")
local RequestWheelState = WheelEvents:WaitForChild("RequestWheelState")
local RequestSpin = WheelEvents:WaitForChild("RequestSpin")
local WheelSpinResult = WheelEvents:WaitForChild("WheelSpinResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- 2D wheel graphic (drawn procedurally so wedge widths can match
-- DailyWheelConfig's weights exactly - no external art asset needed)
-- ============================================================

local IMAGE_SIZE = 512
local IMAGE_CENTER = IMAGE_SIZE / 2
local IMAGE_RADIUS = 246

-- Segment center angles (deg, clockwise from top=0), parallel-indexed to DailyWheelConfig.Segments.
-- Boundaries are the midpoints between consecutive centers, so wedge width follows directly from
-- how the centers are spaced below - keep this list evenly reflecting relative reward weight/feel.
local SEGMENT_CENTER_ANGLES = { 0, 49.8, 114.1, 164.4, 208.575, 250.325, 292.3, 330.45 }
local SEGMENT_COLORS = {
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(170, 90, 230),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(190, 110, 240),
	Color3.fromRGB(60, 210, 210),
	Color3.fromRGB(90, 210, 90),
	Color3.fromRGB(255, 140, 60),
}
local RIM_COLOR = Color3.fromRGB(255, 215, 120)

local function buildSegmentBoundaries()
	local n = #SEGMENT_CENTER_ANGLES
	local boundaries = {}
	for i = 1, n do
		local a = SEGMENT_CENTER_ANGLES[i]
		local b = SEGMENT_CENTER_ANGLES[(i % n) + 1]
		if b < a then
			b += 360
		end
		boundaries[i] = (a + b) / 2 % 360
	end
	return boundaries
end

-- boundaries[i] is the upper edge of segment i's wedge (going clockwise); segment n wraps past 360.
local SEGMENT_BOUNDARIES = buildSegmentBoundaries()

local function circDist(a, b)
	local d = math.abs(a - b) % 360
	return math.min(d, 360 - d)
end

local function colorForAngle(angle)
	angle = angle % 360
	for i = 1, #SEGMENT_BOUNDARIES do
		if angle < SEGMENT_BOUNDARIES[i] then
			return SEGMENT_COLORS[i]
		end
	end
	return SEGMENT_COLORS[#SEGMENT_COLORS]
end

local function buildWheelImage()
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(IMAGE_SIZE, IMAGE_SIZE) })
	local buf = buffer.create(IMAGE_SIZE * IMAGE_SIZE * 4)
	for y = 0, IMAGE_SIZE - 1 do
		for x = 0, IMAGE_SIZE - 1 do
			local dx = x + 0.5 - IMAGE_CENTER
			local dy = y + 0.5 - IMAGE_CENTER
			local r = math.sqrt(dx * dx + dy * dy)
			local idx = (y * IMAGE_SIZE + x) * 4
			if r > IMAGE_RADIUS then
				buffer.writeu8(buf, idx + 3, 0)
			else
				local angle = math.deg(math.atan2(dx, -dy)) % 360
				local nearBoundary = false
				for _, b in SEGMENT_BOUNDARIES do
					if circDist(angle, b) < 0.9 then
						nearBoundary = true
						break
					end
				end
				local c
				if r > IMAGE_RADIUS - 6 or nearBoundary or r < 22 then
					c = RIM_COLOR
				else
					c = colorForAngle(angle)
				end
				buffer.writeu8(buf, idx, c.R * 255)
				buffer.writeu8(buf, idx + 1, c.G * 255)
				buffer.writeu8(buf, idx + 2, c.B * 255)
				buffer.writeu8(buf, idx + 3, 255)
			end
		end
	end
	img:WritePixelsBuffer(Vector2.new(0, 0), Vector2.new(IMAGE_SIZE, IMAGE_SIZE), buf)
	return img
end

local FULL_SPINS = 5
local SPIN_DURATION = 3.2

local spinning = false
local wheelImageLabel = nil
local currentRotation = 0

-- Advances currentRotation forward by at least FULL_SPINS full turns and lands it on the exact
-- rotation (mod 360) that puts the given segment's center under the fixed top pointer.
local function nextRotationFor(segmentIndex)
	local center = SEGMENT_CENTER_ANGLES[segmentIndex] or 0
	local base = -center
	local m = (currentRotation - base) % 360
	return currentRotation - FULL_SPINS * 360 - m
end

local function playSpinAnimation(segmentIndex, onDone)
	if not wheelImageLabel then
		if onDone then
			onDone()
		end
		return
	end
	spinning = true
	local target = nextRotationFor(segmentIndex)
	local tween = TweenService:Create(
		wheelImageLabel,
		TweenInfo.new(SPIN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Rotation = target }
	)
	tween.Completed:Connect(function()
		spinning = false
		currentRotation = target
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

-- ============================================================
-- UI panel
-- ============================================================

local screenGui, panel, dim
local statusLabel, spinButton, resultLabel

local function ensureUi()
	if screenGui then
		return
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DailyWheelUI"
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
			UIBridge.ClosePanel("DailyWheel")
		end
	end)

	panel = Theme.createPanel({ Name = "WheelPanel", Parent = screenGui, Size = UDim2.fromOffset(400, 520), Visible = false, ZIndex = 25 })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		UIBridge.ClosePanel("DailyWheel")
	end, 30)
	Theme.createWindowHeader(panel, "Daily Wheel", "One free spin every day", 30)

	local wheelSize = 236
	local wheelContainer = Theme.createFrame({
		Name = "WheelContainer", Parent = panel,
		Size = UDim2.fromOffset(wheelSize, wheelSize),
		Position = UDim2.new(0.5, 0, 0, 90), AnchorPoint = Vector2.new(0.5, 0),
		Bg = Color3.new(0, 0, 0), BgTransparency = 1, ZIndex = 8,
	})

	wheelImageLabel = Instance.new("ImageLabel")
	wheelImageLabel.Name = "WheelImage"
	wheelImageLabel.Size = UDim2.fromScale(1, 1)
	wheelImageLabel.Position = UDim2.fromScale(0.5, 0.5)
	wheelImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheelImageLabel.BackgroundTransparency = 1
	wheelImageLabel.ZIndex = 8
	wheelImageLabel.Rotation = currentRotation
	wheelImageLabel.ImageContent = Content.fromObject(buildWheelImage())
	wheelImageLabel.Parent = wheelContainer

	local pointer = Theme.createFrame({
		Name = "Pointer", Parent = wheelContainer,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0.5),
		Bg = Theme.Colors.Danger or Color3.fromRGB(235, 70, 70), ZIndex = 9,
	})
	pointer.Rotation = 45

	statusLabel = Theme.createText({
		Name = "Status", Parent = panel, Text = "",
		Size = UDim2.new(1, -32, 0, 50), Position = UDim2.fromOffset(16, 340),
		TextSize = 14, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, YAlign = Enum.TextYAlignment.Top, XAlign = Enum.TextXAlignment.Center, ZIndex = 8,
	})

	resultLabel = Theme.createText({
		Name = "Result", Parent = panel, Text = "",
		Size = UDim2.new(1, -32, 0, 60), Position = UDim2.fromOffset(16, 398),
		TextSize = 18, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		Wrapped = true, XAlign = Enum.TextXAlignment.Center, ZIndex = 8,
	})

	spinButton = Theme.createButton({
		Name = "SpinButton", Parent = panel, Text = "Spin",
		Size = UDim2.new(1, -32, 0, 48), Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1), Bg = Theme.Colors.Success, TextSize = 16, ZIndex = 9,
		OnClick = function()
			if spinning or not spinButton.Active then
				return
			end
			spinButton.Active = false
			spinButton.Text = "Spinning..."
			statusLabel.Text = "Good luck!"
			RequestSpin:FireServer()
		end,
	})
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

local function showCooldownState(nextResetAt)
	if not spinButton then
		return
	end
	stopCountdown()
	spinButton.Visible = false
	local function update()
		local secondsLeft = nextResetAt - os.time()
		if secondsLeft <= 0 then
			statusLabel.Text = "Your daily spin is ready!"
			stopCountdown()
			spinButton.Visible = true
			spinButton.Text = "Spin"
			spinButton.Active = true
			return
		end
		statusLabel.Text = "Already spun today. Next spin in:\n" .. formatCountdown(secondsLeft)
	end
	update()
	countdownThread = task.spawn(function()
		while panel and panel.Visible and not spinButton.Visible do
			task.wait(1)
			update()
		end
	end)
end

local function showReadyState()
	stopCountdown()
	statusLabel.Text = "Spin the wheel for a free daily reward!"
	resultLabel.Text = ""
	spinButton.Visible = true
	spinButton.Text = "Spin"
	spinButton.Active = true
end

local function refreshState()
	local ok, state = pcall(function()
		return RequestWheelState:InvokeServer()
	end)
	if not ok or typeof(state) ~= "table" then
		statusLabel.Text = "Could not load wheel state."
		spinButton.Visible = false
		return
	end
	if state.canSpin then
		showReadyState()
	else
		showCooldownState(state.nextResetAt)
	end
end

local function openWheelPanel()
	ensureUi()
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	UIBridge.NotifyModalOpened(screenGui.Name)
	Theme.tweenOpen(panel, dim)
	resultLabel.Text = ""
	refreshState()
end

local function closeWheelPanel()
	if not screenGui or not panel then
		return
	end
	Theme.closeModalWindow(screenGui, panel, dim, function()
		UIBridge.NotifyModalClosed(screenGui.Name)
	end)
end

UIBridge.RegisterPanel("DailyWheel", { Open = openWheelPanel, Close = closeWheelPanel })
_G.DragonIslandOpenDailyWheel = openWheelPanel

WheelSpinResult.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if not payload.success then
		if statusLabel then
			statusLabel.Text = payload.message or "You already spun today."
		end
		if payload.nextResetAt then
			showCooldownState(payload.nextResetAt)
		end
		return
	end

	playSpinAnimation(payload.segmentIndex or 1, function()
		if resultLabel then
			resultLabel.Text = "🎉 " .. tostring(payload.message or "You won a reward!")
		end
		if payload.nextResetAt then
			showCooldownState(payload.nextResetAt)
		end
	end)
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, playerWhoTriggered)
	if playerWhoTriggered ~= player then
		return
	end
	if prompt.Name ~= "DailyWheelPrompt" then
		return
	end
	UIBridge.OpenPanel("DailyWheel")
end)

print("[DailyWheelClient] Daily wheel UI ready")
