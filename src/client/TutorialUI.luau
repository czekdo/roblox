local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))

local TutorialUI = {}
TutorialUI.__index = TutorialUI

local PANEL_WIDTH = 360
local PANEL_HEIGHT = 168
local PORTRAIT_SIZE = 64
local HINT_MARGIN = 16
local ARROW_GAP = 24

function TutorialUI.new(playerGui)
	local self = setmetatable({}, TutorialUI)
	self.playerGui = playerGui
	self.arrowTime = 0
	self.highlightedTarget = nil
	self.targetHighlightStroke = nil
	self.onNext = nil
	self.onSkipConfirm = nil
	self.onSkipCancel = nil
	self:_build()
	return self
end

function TutorialUI:_build()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DragonTutorialUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 38
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self.playerGui
	Theme.applyScreenSafeArea(screenGui)
	self.screenGui = screenGui

	local arrow = Instance.new("TextLabel")
	arrow.Name = "TutorialArrow"
	arrow.Size = UDim2.fromOffset(40, 40)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.Text = "▼"
	arrow.TextColor3 = Theme.Colors.GoldBright
	arrow.TextSize = 32
	arrow.TextStrokeTransparency = 0.3
	arrow.Visible = false
	arrow.ZIndex = 14
	arrow.Parent = screenGui
	Theme.makeInputTransparent(arrow)
	self.arrow = arrow

	local panel = Instance.new("Frame")
	panel.Name = "TutorialPanel"
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.BackgroundColor3 = Theme.Colors.Stone
	panel.BackgroundTransparency = 0.02
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 12
	panel.Parent = screenGui
	Theme.corner(panel, Theme.Corner.Large)
	Theme.stroke(panel, Theme.Colors.Gold, 2, 0.1)
	self.panel = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.Size = UDim2.new(1, 0, 0, 6)
	progressTrack.BackgroundColor3 = Theme.Colors.StoneDeep
	progressTrack.BorderSizePixel = 0
	progressTrack.ZIndex = 13
	progressTrack.Parent = panel
	Theme.corner(progressTrack, Theme.Corner.Pill)
	self.progressTrack = progressTrack

	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Theme.Colors.GoldBright
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 14
	progressFill.Parent = progressTrack
	Theme.corner(progressFill, Theme.Corner.Pill)
	self.progressFill = progressFill

	self.stepLabel = Instance.new("TextLabel")
	self.stepLabel.Name = "StepLabel"
	self.stepLabel.Size = UDim2.new(1, -70, 0, 16)
	self.stepLabel.Position = UDim2.fromOffset(0, 12)
	self.stepLabel.BackgroundTransparency = 1
	self.stepLabel.Font = Enum.Font.GothamBold
	self.stepLabel.TextColor3 = Theme.Colors.Crystal
	self.stepLabel.TextSize = 11
	self.stepLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.stepLabel.ZIndex = 13
	self.stepLabel.Parent = panel

	Theme.createSecondaryButton({
		Name = "SkipButton", Parent = panel, Text = "Skip",
		Size = UDim2.fromOffset(54, 22), Position = UDim2.new(1, 0, 0, 10),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 11, ZIndex = 15,
		OnClick = function()
			self:showSkipConfirm()
		end,
	})

	local portraitFrame = Instance.new("Frame")
	portraitFrame.Name = "Portrait"
	portraitFrame.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portraitFrame.Position = UDim2.fromOffset(0, 34)
	portraitFrame.BackgroundColor3 = Theme.Colors.NavyEdge
	portraitFrame.BorderSizePixel = 0
	portraitFrame.ZIndex = 13
	portraitFrame.Parent = panel
	Theme.corner(portraitFrame, Theme.Corner.Medium)
	Theme.stroke(portraitFrame, Theme.Colors.GoldBright, 1.5, 0.25)

	local portrait = Instance.new("ImageLabel")
	portrait.Name = "PortraitImage"
	portrait.Size = UDim2.fromScale(0.82, 0.82)
	portrait.Position = UDim2.fromScale(0.5, 0.5)
	portrait.AnchorPoint = Vector2.new(0.5, 0.5)
	portrait.BackgroundTransparency = 1
	portrait.Image = Theme.Icons.Dragon
	portrait.ScaleType = Enum.ScaleType.Fit
	portrait.ZIndex = 14
	portrait.Parent = portraitFrame

	self.titleLabel = Instance.new("TextLabel")
	self.titleLabel.Name = "Title"
	self.titleLabel.Size = UDim2.new(1, -(PORTRAIT_SIZE + 10), 0, 22)
	self.titleLabel.Position = UDim2.fromOffset(PORTRAIT_SIZE + 10, 34)
	self.titleLabel.BackgroundTransparency = 1
	self.titleLabel.Font = Enum.Font.GothamBlack
	self.titleLabel.TextColor3 = Theme.Colors.GoldDark
	self.titleLabel.TextSize = 16
	self.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	self.titleLabel.ZIndex = 13
	self.titleLabel.Parent = panel

	self.descriptionLabel = Instance.new("TextLabel")
	self.descriptionLabel.Name = "Description"
	self.descriptionLabel.Size = UDim2.new(1, -(PORTRAIT_SIZE + 10), 0, 38)
	self.descriptionLabel.Position = UDim2.fromOffset(PORTRAIT_SIZE + 10, 56)
	self.descriptionLabel.BackgroundTransparency = 1
	self.descriptionLabel.Font = Enum.Font.GothamMedium
	self.descriptionLabel.TextColor3 = Theme.Colors.Text
	self.descriptionLabel.TextSize = 12
	self.descriptionLabel.TextWrapped = true
	self.descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	self.descriptionLabel.ZIndex = 13
	self.descriptionLabel.Parent = panel

	self.actionLabel = Instance.new("TextLabel")
	self.actionLabel.Name = "Action"
	self.actionLabel.Size = UDim2.new(1, 0, 0, 30)
	self.actionLabel.Position = UDim2.fromOffset(0, 98)
	self.actionLabel.BackgroundColor3 = Theme.Colors.StoneDark
	self.actionLabel.BackgroundTransparency = 0.06
	self.actionLabel.BorderSizePixel = 0
	self.actionLabel.Font = Enum.Font.GothamBold
	self.actionLabel.TextColor3 = Theme.Colors.Success
	self.actionLabel.TextSize = 11
	self.actionLabel.TextWrapped = true
	self.actionLabel.ZIndex = 13
	self.actionLabel.Parent = panel
	Theme.corner(self.actionLabel, UDim.new(0, 8))

	self.nextButton = Theme.createButton({
		Name = "NextButton", Parent = panel, Text = "Continue",
		Size = UDim2.fromOffset(110, 30), Position = UDim2.new(1, 0, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		Bg = Theme.Colors.Success, TextSize = 12, ZIndex = 15, Visible = false,
		OnClick = function()
			if self.onNext then
				self.onNext()
			end
		end,
	})

	self.rewardToast = Theme.createFrame({
		Name = "RewardToast", Parent = screenGui,
		Size = UDim2.fromOffset(260, 44), Position = UDim2.new(0.5, 0, 0, 88),
		AnchorPoint = Vector2.new(0.5, 0),
		Bg = Theme.Colors.Navy, Corner = Theme.Corner.Medium, Visible = false, ZIndex = 20,
	})
	Theme.stroke(self.rewardToast, Theme.Colors.GoldBright, 1.5, 0.2)
	self.rewardToastLabel = Theme.createText({
		Name = "RewardText", Parent = self.rewardToast,
		Text = "", Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 21,
	})

	self:_buildSkipConfirm()
	self:_buildCompletionPanel()
end

function TutorialUI:_buildSkipConfirm()
	self.skipDim = Theme.createDim(self.screenGui, 10)
	self.skipDim.Name = "SkipDim"
	self.skipDim.Visible = false
	Theme.hideDim(self.skipDim)

	self.skipPanel = Theme.createPanel({
		Name = "SkipConfirmPanel", Parent = self.screenGui,
		Size = UDim2.fromOffset(360, 200), Visible = false, ZIndex = 30,
	})
	self.skipPanel:SetAttribute("OpenPosition", self.skipPanel.Position)

	Theme.createWindowHeader(self.skipPanel, "Skip Tutorial?", "You can replay it later from Settings.", 20)
	Theme.createText({
		Name = "SkipBody", Parent = self.skipPanel,
		Text = "Skipping ends the guided tour. Step rewards and the completion bonus will not be granted.",
		Size = UDim2.new(1, -32, 0, 56), Position = UDim2.fromOffset(16, 72),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, YAlign = Enum.TextYAlignment.Top, ZIndex = 22,
	})
	Theme.createButton({
		Name = "ConfirmSkip", Parent = self.skipPanel, Text = "Yes, Skip",
		Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(24, 140),
		Bg = Theme.Colors.Danger, TextSize = 14, ZIndex = 22,
		OnClick = function()
			self:hideSkipConfirm()
			if self.onSkipConfirm then
				self.onSkipConfirm()
			end
		end,
	})
	Theme.createSecondaryButton({
		Name = "CancelSkip", Parent = self.skipPanel, Text = "Keep Learning",
		Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(186, 140),
		TextSize = 14, ZIndex = 22,
		OnClick = function()
			self:hideSkipConfirm()
			if self.onSkipCancel then
				self.onSkipCancel()
			end
		end,
	})
end

function TutorialUI:_buildCompletionPanel()
	self.rewardDim = Theme.createDim(self.screenGui, 8)
	self.rewardDim.Name = "RewardDimBackground"
	Theme.hideDim(self.rewardDim)

	self.rewardPanel = Theme.createPanel({
		Name = "TutorialRewardPanel", Parent = self.screenGui,
		Size = UDim2.fromOffset(440, 360), Visible = false, ZIndex = 25,
	})
	self.rewardPanel:SetAttribute("OpenPosition", self.rewardPanel.Position)

	self.rewardTitleLabel = Theme.createText({
		Name = "RewardTitle", Parent = self.rewardPanel, Text = "Tutorial Complete!",
		Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 16),
		TextSize = 24, Font = Theme.Fonts.Title, Color = Theme.Colors.GoldDark,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 27,
	})
	self.rewardBodyLabel = Theme.createText({
		Name = "RewardBody", Parent = self.rewardPanel, Text = "",
		Size = UDim2.new(1, -40, 0, 180), Position = UDim2.fromOffset(20, 64),
		TextSize = 15, Font = Theme.Fonts.Body, Color = Theme.Colors.Text,
		Wrapped = true, YAlign = Enum.TextYAlignment.Top, ZIndex = 27,
	})

	Theme.createCloseButton(self.rewardPanel, function()
		self:closeRewardPanel()
	end, 24)

	Theme.createButton({
		Name = "ClaimRewardButton", Parent = self.rewardPanel, Text = "Claim Rewards",
		Size = UDim2.new(1, -40, 0, 48), Position = UDim2.new(0.5, 0, 1, -64),
		AnchorPoint = Vector2.new(0.5, 0), Bg = Theme.Colors.Success, TextSize = 16, ZIndex = 27,
		OnClick = function()
			self:closeRewardPanel()
		end,
	})

	self.rewardDim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:closeRewardPanel()
		end
	end)
end

function TutorialUI:clearTargetHighlight()
	if self.targetHighlightStroke then
		self.targetHighlightStroke:Destroy()
		self.targetHighlightStroke = nil
	end
	self.highlightedTarget = nil
end

function TutorialUI:applyTargetHighlight(target)
	if target == self.highlightedTarget then
		return
	end
	self:clearTargetHighlight()
	if not target or not target:IsA("GuiObject") then
		return
	end
	self.highlightedTarget = target
	self.targetHighlightStroke = Instance.new("UIStroke")
	self.targetHighlightStroke.Name = "TutorialTargetStroke"
	self.targetHighlightStroke.Color = Theme.Colors.GoldBright
	self.targetHighlightStroke.Thickness = 3
	self.targetHighlightStroke.Transparency = 0.12
	self.targetHighlightStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	self.targetHighlightStroke.Parent = target
end

function TutorialUI:getReservedRects(screen)
	local inset = Theme.getGuiInset()
	local edge = Theme.SafeArea.Edge
	local navWidth = Theme.SafeArea.NavColumnWidth + edge
	local topBarHeight = inset.Y + 64 + Theme.SafeArea.TopExtra + 8
	return {
		{ pos = Vector2.new(0, 0), size = Vector2.new(screen.X, topBarHeight) },
		{ pos = Vector2.new(screen.X - navWidth, 0), size = Vector2.new(navWidth, screen.Y) },
	}
end

function TutorialUI:rectsOverlap(aPos, aSize, bPos, bSize)
	return not (
		aPos.X + aSize.X <= bPos.X
		or bPos.X + bSize.X <= aPos.X
		or aPos.Y + aSize.Y <= bPos.Y
		or bPos.Y + bSize.Y <= aPos.Y
	)
end

function TutorialUI:positionPanelNearTarget(target)
	local screen = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local inset = Theme.getGuiInset()
	local edge = Theme.SafeArea.Edge
	local minY = inset.Y + Theme.SafeArea.TopExtra + 72
	local maxY = screen.Y - PANEL_HEIGHT - edge
	local minX = edge
	local maxX = screen.X - PANEL_WIDTH - edge

	if not target then
		self.panel.Position = UDim2.fromOffset(edge + 8, math.max(minY, screen.Y - PANEL_HEIGHT - edge - 24))
		self.arrow.Visible = false
		self:clearTargetHighlight()
		return
	end

	local targetPos = target.AbsolutePosition
	local targetSize = target.AbsoluteSize
	if targetSize.X <= 0 or targetSize.Y <= 0 then
		return
	end

	self:applyTargetHighlight(target)
	local targetCenter = Vector2.new(targetPos.X + targetSize.X * 0.5, targetPos.Y + targetSize.Y * 0.5)
	local reservedRects = self:getReservedRects(screen)

	local placements = {
		{ hintX = targetCenter.X - PANEL_WIDTH * 0.5, hintY = targetPos.Y - PANEL_HEIGHT - ARROW_GAP, arrowX = targetCenter.X, arrowY = targetPos.Y - 8, arrowText = "▼", score = 1 },
		{ hintX = targetCenter.X - PANEL_WIDTH * 0.5, hintY = targetPos.Y + targetSize.Y + ARROW_GAP, arrowX = targetCenter.X, arrowY = targetPos.Y + targetSize.Y + 8, arrowText = "▲", score = 2 },
		{ hintX = targetPos.X - PANEL_WIDTH - ARROW_GAP, hintY = targetCenter.Y - PANEL_HEIGHT * 0.5, arrowX = targetPos.X - 8, arrowY = targetCenter.Y, arrowText = "▶", score = 0 },
		{ hintX = targetPos.X + targetSize.X + ARROW_GAP, hintY = targetCenter.Y - PANEL_HEIGHT * 0.5, arrowX = targetPos.X + targetSize.X + 8, arrowY = targetCenter.Y, arrowText = "◀", score = 3 },
	}

	if targetCenter.X > screen.X * 0.55 then
		placements[3].score = -2
		placements[4].score = 4
	end

	table.sort(placements, function(a, b)
		return a.score < b.score
	end)

	local chosen = placements[1]
	for _, placement in placements do
		local hintPos = Vector2.new(
			math.clamp(placement.hintX, minX, maxX),
			math.clamp(placement.hintY, minY, maxY)
		)
		local overlaps = false
		for _, rect in reservedRects do
			if self:rectsOverlap(hintPos, Vector2.new(PANEL_WIDTH, PANEL_HEIGHT), rect.pos, rect.size) then
				overlaps = true
				break
			end
		end
		if not overlaps and not self:rectsOverlap(hintPos, Vector2.new(PANEL_WIDTH, PANEL_HEIGHT), targetPos, targetSize) then
			chosen = placement
			chosen.hintX = hintPos.X
			chosen.hintY = hintPos.Y
			break
		end
	end

	self.panel.Position = UDim2.fromOffset(chosen.hintX, chosen.hintY)
	self.arrow.Position = UDim2.fromOffset(chosen.arrowX, chosen.arrowY)
	self.arrow.Text = chosen.arrowText
	self.arrow.Visible = true
end

function TutorialUI:updateStep(state, target, showNext)
	if not state or not state.activeStep then
		self:hideGuide()
		return
	end

	local active = state.activeStep
	local stepCount = state.stepCount or #(state.steps or {})
	local current = state.currentStep or 1
	self.stepLabel.Text = string.format("Step %d / %d", current, stepCount)
	self.titleLabel.Text = active.Title or "Tutorial"
	self.descriptionLabel.Text = active.Description or ""
	self.actionLabel.Text = active.ActionHint or "Follow the guide to continue."
	self.nextButton.Visible = showNext == true

	local ratio = math.clamp(current / math.max(1, stepCount), 0, 1)
	TweenService:Create(self.progressFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(ratio, 1),
	}):Play()

	if not self.panel.Visible then
		self.panel.Position = UDim2.fromOffset(self.panel.Position.X.Offset, self.panel.Position.Y.Offset + 24)
		self.panel.BackgroundTransparency = 0.25
		self.panel.Visible = true
		TweenService:Create(self.panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(self.panel.Position.X.Offset, self.panel.Position.Y.Offset - 24),
			BackgroundTransparency = 0.02,
		}):Play()
	end

	self:positionPanelNearTarget(target)
end

function TutorialUI:hideGuide()
	self.panel.Visible = false
	self.arrow.Visible = false
	self:clearTargetHighlight()
end

function TutorialUI:showSkipConfirm()
	Theme.tweenOpen(self.skipPanel, self.skipDim)
end

function TutorialUI:hideSkipConfirm()
	Theme.tweenClose(self.skipPanel, self.skipDim)
end

function TutorialUI:showStepReward(text)
	if typeof(text) ~= "string" or text == "" then
		return
	end
	self.rewardToastLabel.Text = "✓ " .. text
	self.rewardToast.Visible = true
	self.rewardToast.BackgroundTransparency = 0.15
	self.rewardToast.Position = UDim2.new(0.5, 0, 0, 72)
	TweenService:Create(self.rewardToast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 88),
		BackgroundTransparency = 0.02,
	}):Play()
	task.delay(2.8, function()
		if self.rewardToast and self.rewardToast.Visible then
			TweenService:Create(self.rewardToast, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
			task.delay(0.22, function()
				if self.rewardToast then
					self.rewardToast.Visible = false
				end
			end)
		end
	end)
	self:playSound("rbxassetid://12221967", 0.35)
end

function TutorialUI:playSound(soundId, volume)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = root
	sound:Play()
	task.delay(2, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

function TutorialUI:playCompletionEffects()
	self:playSound("rbxassetid://12221967", 0.7)
	local player = Players.LocalPlayer
	local character = player.Character
	local attachPart = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart"))
	if not attachPart then
		return
	end
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxassetid://243660364"
	burst.Color = ColorSequence.new(Theme.Colors.GoldBright, Theme.Colors.Crystal)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	burst.Lifetime = NumberRange.new(0.8, 1.4)
	burst.Speed = NumberRange.new(12, 22)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.LightEmission = 0.95
	burst.Parent = attachPart
	burst:Emit(48)
	task.delay(1.6, function()
		if burst.Parent then
			burst:Destroy()
		end
	end)
end

function TutorialUI:showCompletionPanel(rewardInfo, message)
	local lines = { message or "You finished the tutorial!" }
	if rewardInfo then
		table.insert(lines, "")
		if rewardInfo.DragonEssence then table.insert(lines, "+" .. tostring(rewardInfo.DragonEssence) .. " Dragon Essence") end
		if rewardInfo.PremiumGems then table.insert(lines, "+" .. tostring(rewardInfo.PremiumGems) .. " Gems") end
		if rewardInfo.EggType then table.insert(lines, "+1 " .. rewardInfo.EggType .. " Egg") end
		if rewardInfo.BoostSeconds then table.insert(lines, "Starter Harvest Boost (30 min)") end
		if rewardInfo.Title then table.insert(lines, "Title: " .. rewardInfo.Title) end
		if rewardInfo.Badge then table.insert(lines, rewardInfo.Badge .. " Badge") end
	end
	self.rewardBodyLabel.Text = table.concat(lines, "\n")
	self:hideGuide()
	self:playCompletionEffects()
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(self.screenGui.Name)
	end
	Theme.tweenOpen(self.rewardPanel, self.rewardDim)
end

function TutorialUI:closeRewardPanel()
	Theme.tweenClose(self.rewardPanel, self.rewardDim)
	if _G.DragonIslandNotifyModalClosed then
		_G.DragonIslandNotifyModalClosed(self.screenGui.Name)
	end
end

function TutorialUI:setSuppressed(suppressed)
	if suppressed then
		self:hideGuide()
	end
end

function TutorialUI:isRewardVisible()
	return self.rewardPanel and self.rewardPanel.Visible
end

function TutorialUI:isPaused()
	local fade = self.playerGui:FindFirstChild("PortalTravelFade")
	if fade and fade:IsA("ScreenGui") and fade.Enabled then
		return true
	end
	local cinematic = self.playerGui:FindFirstChild("EggHatchCinematicUI")
	if cinematic and cinematic:IsA("ScreenGui") and cinematic.Enabled then
		return true
	end
	return false
end

function TutorialUI:tick(deltaTime, target)
	if self:isPaused() or not self.panel.Visible then
		return
	end
	self.arrowTime += deltaTime
	if self.arrow.Visible then
		local base = self.arrow.Position
		self.arrow.Position = base + UDim2.fromOffset(0, math.sin(self.arrowTime * 6) * 0.8)
	end
	if self.targetHighlightStroke and self.targetHighlightStroke.Parent then
		self.targetHighlightStroke.Transparency = 0.1 + (math.sin(self.arrowTime * 4) + 1) * 0.15
	end
	if target then
		self:positionPanelNearTarget(target)
	end
end

function TutorialUI:shutdown()
	self:hideGuide()
	self:closeRewardPanel()
	self.screenGui.Enabled = false
end

return TutorialUI
