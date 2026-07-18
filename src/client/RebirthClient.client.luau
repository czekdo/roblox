local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))

local RebirthEvents = ReplicatedStorage:WaitForChild("RebirthEvents")
local RequestRebirthState = RebirthEvents:WaitForChild("RequestRebirthState")
local RequestRebirthPreview = RebirthEvents:WaitForChild("RequestRebirthPreview")
local RequestRebirth = RebirthEvents:WaitForChild("RequestRebirth")
local RequestSkillTreePurchase = RebirthEvents:WaitForChild("RequestSkillTreePurchase")
local RebirthStateUpdated = RebirthEvents:WaitForChild("RebirthStateUpdated")
local RebirthCeremonyStart = RebirthEvents:WaitForChild("RebirthCeremonyStart")
local RebirthCeremonyComplete = RebirthEvents:WaitForChild("RebirthCeremonyComplete")

local CeremonyTimings = RebirthConfig.Ceremony
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = { loaded = false }
local preview = nil
local previewLoading = false
local previewLoadFailed = false
local ceremonyActive = false
local rebirthInvokeInProgress = false
local pendingOpenSkillTree = false

local screenGui
local dim
local rebirthPanel
local skillTreePanel
local milestonePanel
local ceremonyGui
local ceremonyDim
local ceremonyContent
local ceremonyRebirthLabel
local ceremonyShardLabel
local ceremonyShardIcon

local rebirthCountLabel
local nextRebirthLabel
local shardBalanceLabel
local requirementScroll
local breakdownScroll
local previewShardLabel
local rebirthStatusLabel
local confirmButton
local skillTreeButton
local milestoneButton
local skillTreeShardLabel
local skillTreeStatusLabel
local milestoneScroll
local milestoneStatusLabel
local branchColumns = {}
local nodeButtons = {}
local nodeLayouts = {}

local previewStatsFrame
local currentShardsPreviewLabel
local projectedShardsPreviewLabel
local resetSummaryScroll
local keptProgressScroll
local previewErrorFrame
local previewRetryButton
local ascendSection
local ascendRewardLabel
local ascendReasonLabel
local requirementEmptyState
local breakdownEmptyState
local milestoneEmptyState
local skillTreeBackButton
local milestoneBackButton

local RESET_SUMMARY_ITEMS = {
	"Island unlock progress (return to Hub)",
	"Kingdom level and run essence",
	"Building upgrade levels",
	"Dragon roster and training progress",
	"Daily quest and run-only counters",
}

local KEPT_PROGRESSION_ITEMS = {
	"Ascension Shards and Skill Tree ranks",
	"Milestone titles, auras, and cosmetics",
	"Lifetime stats and rebirth count",
	"Permanent ascension bonuses",
}

local MILESTONE_ICONS = {
	Title = Theme.Icons.Trophy,
	Aura = Theme.Icons.Star,
	PortalEffect = Theme.Icons.Scroll,
	Cosmetic = Theme.Icons.Gift,
}

local BRANCH_ICONS = {
	Dragon = Theme.Icons.Dragon,
	Kingdom = Theme.Icons.Crown,
	Explorer = Theme.Icons.House,
}

-- Defined here (not further down near its sibling scroll helpers) because
-- refreshMilestoneUI/refreshPreviewUI below can run before the rest of this file's
-- top-to-bottom initialization finishes, if RebirthStateUpdated fires from the server
-- early enough — a local function declared later would still be nil at that point.
local function clearScrollChildren(scroll)
	if not scroll then return end
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "UIListLayout" and child.Name ~= "EmptyState" and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function setScrollEmptyState(scroll, emptyState, show, title, body, icon)
	if not scroll then
		return
	end
	if emptyState then
		emptyState.Visible = show == true
		if show then
			local titleLabel = emptyState:FindFirstChild("EmptyTitle")
			local bodyLabel = emptyState:FindFirstChild("EmptyBody")
			if titleLabel then
				titleLabel.Text = title or "Nothing here yet"
			end
			if bodyLabel then
				bodyLabel.Text = body or ""
			end
			local iconFrame = emptyState:FindFirstChild("IconFrame")
			if iconFrame then
				local img = iconFrame:FindFirstChildOfClass("ImageLabel")
				if img and icon then
					img.Image = icon
				end
			end
		end
	end
end

local function formatMilestoneRewardType(rewardType)
	if rewardType == "Title" then
		return "Title"
	elseif rewardType == "Aura" then
		return "Dragon Aura"
	elseif rewardType == "PortalEffect" then
		return "Portal Effect"
	elseif rewardType == "Cosmetic" then
		return "Cosmetic"
	end
	return tostring(rewardType or "Reward")
end

local function getMilestoneStatus(milestone, rebirthCount)
	local requiredCount = math.max(1, math.floor(tonumber(milestone.rebirthCount) or 0))
	if milestone.claimed == true then
		return "Claimed", Theme.Colors.GoldBright
	end
	if milestone.unlocked == true then
		return "Unlocked", Theme.Colors.Success
	end
	if rebirthCount >= requiredCount then
		return "Unlocked", Theme.Colors.Crystal
	end
	return "Locked", Theme.Colors.TextMuted
end

local function refreshMilestoneUI()
	clearScrollChildren(milestoneScroll)
	local milestoneData = state.milestoneRewards or {}
	local milestones = milestoneData.milestones or {}
	local rebirthCount = state.rebirthCount or 0

	if #milestones == 0 then
		setScrollEmptyState(
			milestoneScroll,
			milestoneEmptyState,
			true,
			"No milestones unlocked yet.",
			"Ascend to higher rebirth counts to earn permanent milestone rewards.",
			Theme.Icons.Trophy
		)
	else
		setScrollEmptyState(milestoneScroll, milestoneEmptyState, false)
	end

	for index, milestone in milestones do
		local requiredCount = math.max(1, math.floor(tonumber(milestone.rebirthCount) or 0))
		local statusText, statusColor = getMilestoneStatus(milestone, rebirthCount)
		local progress = math.clamp(rebirthCount / requiredCount, 0, 1)
		local unlocked = milestone.unlocked == true

		local row = Theme.createFrame({
			Name = "Milestone_" .. tostring(requiredCount),
			Parent = milestoneScroll,
			Size = UDim2.new(1, -4, 0, 96),
			Bg = unlocked and Theme.Colors.NavyEdge or Theme.Colors.StoneDeep,
			Corner = Theme.Corner.Medium,
			LayoutOrder = index,
			ZIndex = 9,
		})
		Theme.stroke(row, unlocked and Theme.Colors.GoldBright or Theme.Colors.Gold, 1.5, unlocked and 0.35 or 0.45)
		Theme.padding(row, 8, 8, 10, 10)

		local iconId = MILESTONE_ICONS[milestone.rewardType] or Theme.Icons.Star
		Theme.createIconFrame(row, iconId, 52, 10)
		local iconFrame = row:FindFirstChild("IconFrame")
		if iconFrame then
			iconFrame.Position = UDim2.fromOffset(0, 8)
		end

		Theme.createText({
			Name = "Title", Parent = row,
			Text = milestone.displayName or "Milestone",
			Size = UDim2.new(1, -130, 0, 18), Position = UDim2.fromOffset(64, 4),
			TextSize = 14, Font = Theme.Fonts.Bold,
			Color = unlocked and Theme.Colors.TextGold or Theme.Colors.TextLight, ZIndex = 10,
		})
		Theme.createText({
			Name = "Required", Parent = row,
			Text = string.format("Rebirth %d", requiredCount),
			Size = UDim2.fromOffset(120, 16), Position = UDim2.fromOffset(64, 24),
			TextSize = 11, Font = Theme.Fonts.Body,
			Color = Theme.Colors.TextMuted, ZIndex = 10,
		})
		Theme.createText({
			Name = "Type", Parent = row,
			Text = formatMilestoneRewardType(milestone.rewardType),
			Size = UDim2.fromOffset(110, 16), Position = UDim2.new(1, -116, 0, 4),
			TextSize = 10, Font = Theme.Fonts.Body,
			Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Right, ZIndex = 10,
		})
		Theme.createText({
			Name = "Description", Parent = row,
			Text = milestone.description or "",
			Size = UDim2.new(1, -130, 0, 28), Position = UDim2.fromOffset(64, 42),
			TextSize = 11, Font = Theme.Fonts.Regular,
			Color = Theme.Colors.TextMuted, YAlign = Enum.TextYAlignment.Top, ZIndex = 10,
		})
		Theme.createText({
			Name = "Status", Parent = row,
			Text = statusText,
			Size = UDim2.fromOffset(110, 16), Position = UDim2.new(1, -116, 0, 24),
			TextSize = 11, Font = Theme.Fonts.Bold,
			Color = statusColor,
			XAlign = Enum.TextXAlignment.Right, ZIndex = 10,
		})

		local _, progressFill = Theme.createProgressBar(
			row,
			UDim2.new(1, -74, 0, 10),
			UDim2.new(0, 64, 1, -14),
			unlocked and Theme.Colors.Success or Theme.Colors.Crystal
		)
		progressFill.Size = UDim2.new(progress, 0, 1, 0)
		Theme.createText({
			Name = "ProgressLabel", Parent = row,
			Text = string.format("%d / %d rebirths", rebirthCount, requiredCount),
			Size = UDim2.new(1, -74, 0, 14), Position = UDim2.new(0, 64, 1, -12),
			TextSize = 10, Font = Theme.Fonts.Regular,
			Color = Theme.Colors.TextMuted, ZIndex = 10,
		})
	end

	if milestoneStatusLabel then
		local nextMilestone
		for _, milestone in milestones do
			if milestone.unlocked ~= true then
				nextMilestone = milestone
				break
			end
		end
		if nextMilestone then
			milestoneStatusLabel.Text = string.format(
				"Next milestone at Rebirth %d: %s",
				nextMilestone.rebirthCount or 0,
				nextMilestone.displayName or "Reward"
			)
		else
			milestoneStatusLabel.Text = "All milestone rewards unlocked."
		end
		if milestoneData.equippedTitle then
			milestoneStatusLabel.Text ..= " | Title active"
		end
	end
end

local function formatCompact(value)
	return Theme.formatCompact(value)
end

local function formatBreakdownLabel(key)
	local text = tostring(key or "")
	text = text:gsub("(%l)(%u)", "%1 %2")
	text = text:gsub("_", " ")
	if #text > 0 then
		text = text:sub(1, 1):upper() .. text:sub(2)
	end
	return text
end

local function formatEffectBonus(node, rank)
	if not node then
		return "—"
	end
	local perRank = tonumber(node.EffectPerRank) or 0
	local total = perRank * math.max(0, rank)
	local effectType = node.EffectType or ""
	if effectType == "ActiveDragonSlots" or effectType == "BuildingResetFloor" then
		return string.format("+%d", math.floor(total))
	end
	return string.format("+%.0f%%", total * 100)
end

local function populateSummaryList(scroll, items, emptyTitle, emptyBody)
	if not scroll then
		return
	end
	clearScrollChildren(scroll)
	if typeof(items) ~= "table" or #items == 0 then
		setScrollEmptyState(scroll, scroll:FindFirstChild("EmptyState"), true, emptyTitle, emptyBody, Theme.Icons.Book)
		return
	end
	setScrollEmptyState(scroll, scroll:FindFirstChild("EmptyState"), false)
	for index, item in items do
		local row = Theme.createFrame({
			Name = "SummaryRow" .. index,
			Parent = scroll,
			Size = UDim2.new(1, -4, 0, 24),
			BgTransparency = 1,
			LayoutOrder = index,
			ZIndex = 9,
		})
		Theme.createText({
			Name = "Bullet", Parent = row, Text = "•",
			Size = UDim2.fromOffset(14, 20), TextSize = 14,
			Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright, ZIndex = 10,
		})
		Theme.createText({
			Name = "Label", Parent = row, Text = tostring(item),
			Size = UDim2.new(1, -18, 1, 0), Position = UDim2.fromOffset(16, 0),
			TextSize = 11, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted,
			YAlign = Enum.TextYAlignment.Top, ZIndex = 10,
		})
	end
end

local function notify(message, isGood)
	if _G.DragonIslandNotify then
		_G.DragonIslandNotify(message)
	end
	if skillTreeStatusLabel and skillTreePanel and skillTreePanel.Visible then
		skillTreeStatusLabel.Text = message
		skillTreeStatusLabel.TextColor3 = isGood and Theme.Colors.Success or Theme.Colors.Danger
	end
	if rebirthStatusLabel and rebirthPanel and rebirthPanel.Visible then
		rebirthStatusLabel.Text = message
		rebirthStatusLabel.TextColor3 = isGood and Theme.Colors.Success or Theme.Colors.Danger
	end
end

local function isRebirthing()
	return player:GetAttribute("Rebirthing") == true
end

local function getShardBalance()
	return math.max(0, math.floor(tonumber(state.ascensionShards) or player:GetAttribute("AscensionShards") or 0))
end

local function setShardDisplays()
	local balance = getShardBalance()
	if shardBalanceLabel then
		shardBalanceLabel.Text = formatCompact(balance)
	end
	if skillTreeShardLabel then
		skillTreeShardLabel.Text = formatCompact(balance) .. " " .. (RebirthConfig.Currency.Symbol or "✦")
	end
end

local function createRequirementRow(parent, requirement, layoutOrder)
	local met = requirement.Met == true
	local row = Theme.createFrame({
		Name = requirement.Id or "Requirement",
		Parent = parent,
		Size = UDim2.new(1, -4, 0, 44),
		Bg = met and Theme.Colors.NavyEdge or Theme.Colors.StoneDeep,
		Corner = Theme.Corner.Medium,
		LayoutOrder = layoutOrder,
		ZIndex = 9,
	})
	Theme.stroke(row, met and Theme.Colors.Success or Theme.Colors.Gold, 1.5, met and 0.35 or 0.55)
	Theme.padding(row, 6, 6, 10, 10)
	Theme.createText({
		Name = "Check", Parent = row, Text = met and "✓" or "○",
		Size = UDim2.fromOffset(22, 22), TextSize = 16,
		Font = Theme.Fonts.Bold, Color = met and Theme.Colors.Success or Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 10,
	})
	Theme.createText({
		Name = "Label", Parent = row, Text = requirement.Label or "Requirement",
		Size = UDim2.new(1, -30, 0, 18), Position = UDim2.fromOffset(28, 2),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, ZIndex = 10,
	})
	Theme.createText({
		Name = "Progress", Parent = row, Text = tostring(requirement.Current or "—") .. " / " .. tostring(requirement.Target or "—"),
		Size = UDim2.new(1, -30, 0, 16), Position = UDim2.fromOffset(28, 22),
		TextSize = 11, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 10,
	})
	return row
end

local function createBreakdownRow(parent, label, value, layoutOrder)
	return Theme.createStatRow(parent, label, formatCompact(value), layoutOrder, 9)
end

local function refreshPreviewUI()
	clearScrollChildren(requirementScroll)
	clearScrollChildren(breakdownScroll)

	local rebirthCount = state.rebirthCount or 0
	local nextRebirth = (state.nextRebirthNumber or rebirthCount + 1)
	local shardBalance = getShardBalance()

	if rebirthCountLabel then
		rebirthCountLabel.Text = "Current Rebirth: " .. tostring(rebirthCount)
	end
	if nextRebirthLabel then
		nextRebirthLabel.Text = "Next Rebirth: #" .. tostring(nextRebirth)
	end
	if currentShardsPreviewLabel then
		currentShardsPreviewLabel.Text = formatCompact(shardBalance) .. " " .. (RebirthConfig.Currency.Symbol or "✦")
	end
	setShardDisplays()

	if previewErrorFrame then
		previewErrorFrame.Visible = previewLoadFailed == true
	end

	local activePreview = preview or state.preview
	if previewLoading and typeof(activePreview) ~= "table" then
		if previewShardLabel then
			previewShardLabel.Text = "Loading preview..."
		end
		if projectedShardsPreviewLabel then
			projectedShardsPreviewLabel.Text = "Loading..."
		end
		if ascendRewardLabel then
			ascendRewardLabel.Text = "Loading projected reward..."
		end
		if ascendReasonLabel then
			ascendReasonLabel.Text = "Fetching ascension preview..."
			ascendReasonLabel.TextColor3 = Theme.Colors.TextMuted
		end
		setScrollEmptyState(requirementScroll, requirementEmptyState, true, "Loading...", "Fetching rebirth requirements.", Theme.Icons.Rebirth)
		setScrollEmptyState(breakdownScroll, breakdownEmptyState, true, "Preview unavailable.", "Shard breakdown will appear once preview loads.", Theme.Icons.Star)
		populateSummaryList(resetSummaryScroll, nil, "Preview unavailable.", "Reset summary will appear once preview loads.")
		populateSummaryList(keptProgressScroll, KEPT_PROGRESSION_ITEMS, "Loading...", "Permanent progression is always kept across ascensions.")
		if confirmButton then
			confirmButton.Text = "Ascend"
			confirmButton.AutoButtonColor = false
			confirmButton.Active = false
			confirmButton.BackgroundColor3 = Theme.Colors.Slate
		end
		if rebirthStatusLabel then
			rebirthStatusLabel.Text = "Loading preview..."
			rebirthStatusLabel.TextColor3 = Theme.Colors.TextMuted
		end
		return
	end

	if previewLoadFailed or typeof(activePreview) ~= "table" then
		if previewShardLabel then
			previewShardLabel.Text = "Preview unavailable."
		end
		if projectedShardsPreviewLabel then
			projectedShardsPreviewLabel.Text = "—"
		end
		if ascendRewardLabel then
			ascendRewardLabel.Text = "Could not load projected reward"
		end
		if ascendReasonLabel then
			ascendReasonLabel.Text = "Use Retry to reload the ascension preview."
			ascendReasonLabel.TextColor3 = Theme.Colors.Danger
		end
		setScrollEmptyState(requirementScroll, requirementEmptyState, true, "Requirements not available.", "Preview failed to load. Tap Retry above.", Theme.Icons.Rebirth)
		setScrollEmptyState(breakdownScroll, breakdownEmptyState, true, "Preview unavailable.", "Shard reward breakdown could not be loaded.", Theme.Icons.Star)
		populateSummaryList(resetSummaryScroll, nil, "Preview unavailable.", "Retry loading the preview to see what resets.")
		populateSummaryList(keptProgressScroll, KEPT_PROGRESSION_ITEMS, "Permanent progression kept", "These rewards persist across every ascension.")
		if confirmButton then
			confirmButton.Text = "Ascend"
			confirmButton.AutoButtonColor = false
			confirmButton.Active = false
			confirmButton.BackgroundColor3 = Theme.Colors.Slate
		end
		if rebirthStatusLabel then
			rebirthStatusLabel.Text = "Preview unavailable — tap Retry."
			rebirthStatusLabel.TextColor3 = Theme.Colors.Danger
		end
		return
	end

	local requirements = activePreview.requirements or {}
	if #requirements == 0 then
		setScrollEmptyState(requirementScroll, requirementEmptyState, true, "Requirements not available.", "No requirement data was returned for this ascension.", Theme.Icons.Rebirth)
	else
		setScrollEmptyState(requirementScroll, requirementEmptyState, false)
		for index, requirement in requirements do
			createRequirementRow(requirementScroll, requirement, index)
		end
	end

	local breakdown = activePreview.scoreBreakdown or {}
	local order = 1
	local hasBreakdown = false
	for key, value in breakdown do
		if typeof(value) == "number" then
			hasBreakdown = true
			createBreakdownRow(breakdownScroll, formatBreakdownLabel(key), value, order)
			order += 1
		end
	end
	if not hasBreakdown then
		setScrollEmptyState(breakdownScroll, breakdownEmptyState, true, "Preview unavailable.", "Shard breakdown is not available for this run.", Theme.Icons.Star)
	else
		setScrollEmptyState(breakdownScroll, breakdownEmptyState, false)
	end

	populateSummaryList(resetSummaryScroll, RESET_SUMMARY_ITEMS, "Preview unavailable.", "Reset details are unavailable right now.")
	populateSummaryList(keptProgressScroll, KEPT_PROGRESSION_ITEMS, "Loading...", "Permanent progression is always kept across ascensions.")

	local projected = math.max(0, math.floor(tonumber(activePreview.projectedShards) or 0))
	local projectedTotal = math.max(0, math.floor(tonumber(activePreview.projectedTotalShards) or (shardBalance + projected)))
	local symbol = RebirthConfig.Currency.Symbol or "✦"

	if previewShardLabel then
		previewShardLabel.Text = "+" .. formatCompact(projected) .. " " .. symbol
	end
	if projectedShardsPreviewLabel then
		projectedShardsPreviewLabel.Text = "+" .. formatCompact(projected) .. " " .. symbol .. "  (" .. formatCompact(projectedTotal) .. " total)"
	end
	if ascendRewardLabel then
		ascendRewardLabel.Text = "Projected Reward: +" .. formatCompact(projected) .. " " .. symbol
	end

	local eligible = activePreview.eligible == true and not isRebirthing()
	local reasonText = activePreview.reason or "Complete requirements to ascend."

	if confirmButton then
		local gradient = confirmButton:FindFirstChildOfClass("UIGradient")
		if isRebirthing() then
			confirmButton.Text = "Ascending..."
			confirmButton.AutoButtonColor = false
			confirmButton.Active = false
			confirmButton.BackgroundColor3 = Theme.Colors.Slate
			if gradient then gradient.Enabled = false end
		elseif eligible then
			confirmButton.Text = "ASCEND"
			confirmButton.AutoButtonColor = true
			confirmButton.Active = true
			confirmButton.BackgroundColor3 = Theme.Colors.Success
			if gradient then gradient.Enabled = true end
		else
			confirmButton.Text = "ASCEND"
			confirmButton.AutoButtonColor = false
			confirmButton.Active = false
			confirmButton.BackgroundColor3 = Theme.Colors.Slate
			if gradient then gradient.Enabled = false end
		end
	end

	if ascendReasonLabel then
		if isRebirthing() then
			ascendReasonLabel.Text = "Ascension in progress..."
			ascendReasonLabel.TextColor3 = Theme.Colors.GoldBright
		elseif eligible then
			ascendReasonLabel.Text = "Ready to ascend and claim your shards!"
			ascendReasonLabel.TextColor3 = Theme.Colors.Success
		else
			ascendReasonLabel.Text = reasonText
			ascendReasonLabel.TextColor3 = Theme.Colors.Danger
		end
	end

	if rebirthStatusLabel then
		if isRebirthing() then
			rebirthStatusLabel.Text = "Ascension in progress..."
			rebirthStatusLabel.TextColor3 = Theme.Colors.GoldBright
		elseif eligible then
			rebirthStatusLabel.Text = "All requirements met — you may ascend."
			rebirthStatusLabel.TextColor3 = Theme.Colors.Success
		else
			rebirthStatusLabel.Text = reasonText
			rebirthStatusLabel.TextColor3 = Theme.Colors.Danger
		end
	end
end

local function getNodeState(nodeId)
	for _, node in state.skillTreeNodes or {} do
		if node.Id == nodeId then
			return node
		end
	end
	return nil
end

local function canPurchaseNode(node)
	if not node then return false end
	local currentRank = node.CurrentRank or 0
	local maxRank = node.MaxRank or 1
	if currentRank >= maxRank then return false end
	for _, prereqId in node.Prerequisites or {} do
		local prereq = getNodeState(prereqId)
		if not prereq or (prereq.CurrentRank or 0) <= 0 then
			return false
		end
	end
	local cost = node.NextCost
	if not cost then return false end
	return getShardBalance() >= cost
end

local function refreshSkillTreeUI()
	setShardDisplays()
	for nodeId, button in nodeButtons do
		local node = getNodeState(nodeId)
		if node and button then
			local currentRank = node.CurrentRank or 0
			local maxRank = node.MaxRank or 1
			local nextRank = math.min(currentRank + 1, maxRank)
			local atMax = currentRank >= maxRank
			local affordable = canPurchaseNode(node)

			local rankLabel = button:FindFirstChild("RankLabel")
			local nextRankLabel = button:FindFirstChild("NextRankLabel")
			local bonusLabel = button:FindFirstChild("BonusLabel")
			local costLabel = button:FindFirstChild("CostLabel")
			local affordLabel = button:FindFirstChild("AffordLabel")

			if rankLabel then
				rankLabel.Text = string.format("Current Rank: %d / %d", currentRank, maxRank)
			end
			if nextRankLabel then
				if atMax then
					nextRankLabel.Text = "Next Rank: MAX"
				else
					nextRankLabel.Text = string.format("Next Rank: %d", nextRank)
				end
			end
			if bonusLabel then
				if atMax then
					bonusLabel.Text = "Bonus: " .. formatEffectBonus(node, currentRank) .. " (maxed)"
				else
					bonusLabel.Text = "Next Bonus: " .. formatEffectBonus(node, 1) .. " at rank " .. nextRank
				end
			end
			if costLabel then
				if atMax then
					costLabel.Text = "Cost: MAX"
					costLabel.TextColor3 = Theme.Colors.GoldBright
				else
					costLabel.Text = "Cost: " .. tostring(node.NextCost or "—") .. " " .. (RebirthConfig.Currency.Symbol or "✦")
					costLabel.TextColor3 = affordable and Theme.Colors.TextGold or Theme.Colors.TextMuted
				end
			end
			if affordLabel then
				if atMax then
					affordLabel.Text = "Fully upgraded"
					affordLabel.TextColor3 = Theme.Colors.GoldBright
				elseif affordable then
					affordLabel.Text = "Affordable"
					affordLabel.TextColor3 = Theme.Colors.Success
				else
					affordLabel.Text = "Need more shards"
					affordLabel.TextColor3 = Theme.Colors.Danger
				end
			end

			button.AutoButtonColor = not atMax and affordable
			button.BackgroundColor3 = atMax and Theme.Colors.Slate
				or (affordable and Theme.Colors.NavyEdge or Theme.Colors.StoneDeep)

			local stroke = button:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = atMax and Theme.Colors.GoldBright
					or (affordable and Theme.Colors.Success or Theme.Colors.Gold)
				stroke.Transparency = atMax and 0.2 or (affordable and 0.25 or 0.55)
			end
		end
	end
end

local function applyState(payload)
	if typeof(payload) ~= "table" then return end
	state = payload
	state.loaded = payload.loaded == true
	if typeof(payload.preview) == "table" then
		preview = payload.preview
	end
	setShardDisplays()
	refreshPreviewUI()
	refreshSkillTreeUI()
	refreshMilestoneUI()
end

local function fetchPreview()
	previewLoading = true
	previewLoadFailed = false
	refreshPreviewUI()

	local ok, result = pcall(function()
		return RequestRebirthPreview:InvokeServer()
	end)

	previewLoading = false
	if ok and typeof(result) == "table" and result.loaded ~= false then
		preview = result
		previewLoadFailed = false
	else
		previewLoadFailed = true
		notify("Failed to load rebirth preview.", false)
	end
	refreshPreviewUI()
end

local function fetchState()
	local ok, result = pcall(function()
		return RequestRebirthState:InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		applyState(result)
	end
end

local function closeRebirthPanel()
	if not screenGui or not rebirthPanel then return end
	Theme.closeModalWindow(screenGui, rebirthPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function closeSkillTreePanel()
	if not screenGui or not skillTreePanel then return end
	skillTreePanel.Visible = false
	if milestonePanel and milestonePanel.Visible then
		return
	end
	if rebirthPanel and rebirthPanel.Visible then
		return
	end
	Theme.closeModalWindow(screenGui, rebirthPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function closeMilestonePanel()
	if not screenGui or not milestonePanel then return end
	milestonePanel.Visible = false
	if skillTreePanel and skillTreePanel.Visible then
		return
	end
	if rebirthPanel and rebirthPanel.Visible then
		return
	end
	Theme.closeModalWindow(screenGui, rebirthPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function backToRebirthFromSkillTree()
	if not screenGui or not skillTreePanel or not rebirthPanel then
		return
	end
	skillTreePanel.Visible = false
	rebirthPanel.Visible = true
	refreshPreviewUI()
end

local function backToRebirthFromMilestones()
	if not screenGui or not milestonePanel or not rebirthPanel then
		return
	end
	milestonePanel.Visible = false
	rebirthPanel.Visible = true
	refreshMilestoneUI()
end

local function openMilestonePanel()
	if not screenGui or not milestonePanel then return end
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(screenGui.Name)
	end
	if dim then Theme.showDim(dim) end
	rebirthPanel.Visible = false
	skillTreePanel.Visible = false
	milestonePanel.Visible = true
	Theme.tweenOpen(milestonePanel, dim)
	refreshMilestoneUI()
end

local function openSkillTreePanel()
	if not screenGui or not skillTreePanel then return end
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(screenGui.Name)
	end
	if dim then Theme.showDim(dim) end
	rebirthPanel.Visible = false
	if milestonePanel then
		milestonePanel.Visible = false
	end
	skillTreePanel.Visible = true
	Theme.tweenOpen(skillTreePanel, dim)
	refreshSkillTreeUI()
end

local function openRebirthPanel()
	if not screenGui or not rebirthPanel then return end
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(screenGui.Name)
	end
	rebirthPanel.Visible = true
	skillTreePanel.Visible = false
	if milestonePanel then
		milestonePanel.Visible = false
	end
	Theme.tweenOpen(rebirthPanel, dim)
	fetchState()
	fetchPreview()
end

local function purchaseNode(nodeId)
	if isRebirthing() then
		notify("Cannot purchase during Ascension.", false)
		return
	end
	local ok, result = pcall(function()
		return RequestSkillTreePurchase:InvokeServer(nodeId)
	end)
	if not ok then
		notify("Purchase failed.", false)
		return
	end
	if result.success then
		notify(result.message or "Skill purchased!", true)
	else
		notify(result.message or "Cannot purchase skill.", false)
	end
end

local function playCeremony(startPayload, completePayload)
	if ceremonyActive then return end
	ceremonyActive = true
	pendingOpenSkillTree = completePayload and completePayload.openSkillTree == true

	ceremonyGui.Enabled = true
	ceremonyDim.BackgroundTransparency = 1
	ceremonyContent.Visible = true
	ceremonyContent.BackgroundTransparency = 1
	ceremonyRebirthLabel.TextTransparency = 1
	ceremonyShardLabel.TextTransparency = 1
	ceremonyShardIcon.ImageTransparency = 1

	local rebirthCount = startPayload and startPayload.rebirthCount or (completePayload and completePayload.rebirthCount) or 1
	local shardsGranted = startPayload and startPayload.shardsGranted or (completePayload and completePayload.shardsGranted) or 0
	ceremonyRebirthLabel.Text = "ASCENSION " .. tostring(rebirthCount)
	ceremonyShardLabel.Text = "+" .. formatCompact(shardsGranted) .. " " .. RebirthConfig.Currency.Symbol

	TweenService:Create(ceremonyDim, TweenInfo.new(CeremonyTimings.FadeInTime or 0.6), { BackgroundTransparency = 0.15 }):Play()
	task.wait(CeremonyTimings.FadeInTime or 0.6)

	TweenService:Create(ceremonyRebirthLabel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	task.wait(CeremonyTimings.HoldTime or 1.2)

	task.wait(CeremonyTimings.ShardRevealDelay or 0.4)
	TweenService:Create(ceremonyShardIcon, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { ImageTransparency = 0 }):Play()
	TweenService:Create(ceremonyShardLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
	task.wait(0.8)

	TweenService:Create(ceremonyDim, TweenInfo.new(CeremonyTimings.FadeOutTime or 0.8), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(ceremonyRebirthLabel, TweenInfo.new(CeremonyTimings.FadeOutTime or 0.8), { TextTransparency = 1 }):Play()
	TweenService:Create(ceremonyShardLabel, TweenInfo.new(CeremonyTimings.FadeOutTime or 0.8), { TextTransparency = 1 }):Play()
	TweenService:Create(ceremonyShardIcon, TweenInfo.new(CeremonyTimings.FadeOutTime or 0.8), { ImageTransparency = 1 }):Play()
	task.wait(CeremonyTimings.FadeOutTime or 0.8)

	ceremonyGui.Enabled = false
	ceremonyActive = false
	setShardDisplays()

	local grantedMilestones = (completePayload and completePayload.milestonesGranted)
		or (startPayload and startPayload.milestonesGranted)
	if typeof(grantedMilestones) == "table" and #grantedMilestones > 0 then
		local names = {}
		for _, milestone in grantedMilestones do
			if typeof(milestone) == "table" and milestone.displayName then
				table.insert(names, milestone.displayName)
			end
		end
		if #names > 0 then
			notify("Milestone unlocked: " .. table.concat(names, ", "), true)
		end
	end

	if pendingOpenSkillTree then
		pendingOpenSkillTree = false
		task.defer(openSkillTreePanel)
	end
end

local function confirmRebirth()
	local activePreview = preview or state.preview
	if isRebirthing() or typeof(activePreview) ~= "table" or activePreview.eligible ~= true then
		return
	end
	confirmButton.Text = "Ascending..."
	confirmButton.AutoButtonColor = false
	confirmButton.Active = false
	confirmButton.BackgroundColor3 = Theme.Colors.Slate
	local gradient = confirmButton:FindFirstChildOfClass("UIGradient")
	if gradient then gradient.Enabled = false end

	local ceremonyStartPayload
	local ceremonyCompletePayload
	local startConn = RebirthCeremonyStart.OnClientEvent:Connect(function(payload)
		ceremonyStartPayload = payload
	end)
	local completeConn = RebirthCeremonyComplete.OnClientEvent:Connect(function(payload)
		ceremonyCompletePayload = payload
	end)

	rebirthInvokeInProgress = true
	local ok, result = pcall(function()
		return RequestRebirth:InvokeServer()
	end)
	rebirthInvokeInProgress = false
	startConn:Disconnect()
	completeConn:Disconnect()

	if ok and typeof(result) == "table" and result.success then
		closeRebirthPanel()
		playCeremony(ceremonyStartPayload or {
			rebirthCount = result.rebirthCount,
			shardsGranted = result.shardsGranted,
		}, ceremonyCompletePayload or {
			openSkillTree = true,
			rebirthCount = result.rebirthCount,
			shardsGranted = result.shardsGranted,
		})
		fetchState()
		fetchPreview()
		notify(result.message or "Ascension complete!", true)
	else
		local message = (typeof(result) == "table" and result.message) or "Ascension failed."
		notify(message, false)
		refreshPreviewUI()
	end
end

local function buildSkillTreeNode(parent, node, layoutOrder, showConnector)
	local wrap = Theme.createFrame({
		Name = node.Id .. "Wrap",
		Parent = parent,
		Size = UDim2.new(1, -4, 0, showConnector and 118 or 106),
		BgTransparency = 1,
		LayoutOrder = layoutOrder,
		ZIndex = 9,
	})

	if showConnector then
		local connector = Theme.createFrame({
			Name = "Connector",
			Parent = wrap,
			Size = UDim2.fromOffset(3, 10),
			Position = UDim2.new(0.5, 0, 0, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Bg = Theme.Colors.GoldBright,
			Corner = Theme.Corner.Pill,
			ZIndex = 8,
		})
		connector.BackgroundTransparency = 0.15
	end

	local button = Theme.createListRow(wrap, {
		Name = node.Id,
		Text = "",
		Height = 96,
		Position = UDim2.fromOffset(0, showConnector and 12 or 0),
		Size = UDim2.new(1, 0, 0, 96),
		ZIndex = 10,
		OnClick = function()
			purchaseNode(node.Id)
		end,
	})
	button.Text = ""

	Theme.createText({
		Name = "NodeName", Parent = button, Text = node.DisplayName or node.Id,
		Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(0, 0),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = 11,
	})
	Theme.createText({
		Name = "AffordLabel", Parent = button, Text = "",
		Size = UDim2.fromOffset(90, 14), Position = UDim2.new(1, -90, 0, 0),
		TextSize = 10, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Right, ZIndex = 11,
	})
	Theme.createText({
		Name = "RankLabel", Parent = button, Text = "",
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 18),
		TextSize = 11, Font = Theme.Fonts.Body, Color = Theme.Colors.GoldBright, ZIndex = 11,
	})
	Theme.createText({
		Name = "NextRankLabel", Parent = button, Text = "",
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 32),
		TextSize = 11, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 11,
	})
	Theme.createText({
		Name = "BonusLabel", Parent = button, Text = "",
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 46),
		TextSize = 10, Font = Theme.Fonts.Regular, Color = Theme.Colors.CrystalSoft, ZIndex = 11,
	})
	Theme.createText({
		Name = "NodeDesc", Parent = button, Text = node.Description or "",
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 60),
		TextSize = 10, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted,
		YAlign = Enum.TextYAlignment.Top, ZIndex = 11,
	})
	Theme.createText({
		Name = "CostLabel", Parent = button, Text = "",
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14),
		TextSize = 11, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Right, ZIndex = 11,
	})

	nodeButtons[node.Id] = button
	nodeLayouts[node.Id] = wrap
	return wrap
end

local function buildUi()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RebirthUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 30
	screenGui.Enabled = false
	screenGui.Parent = playerGui
	Theme.applyScreenSafeArea(screenGui)

	dim = Theme.createDim(screenGui, 1)
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if milestonePanel and milestonePanel.Visible then
				backToRebirthFromMilestones()
			elseif skillTreePanel and skillTreePanel.Visible then
				backToRebirthFromSkillTree()
			else
				closeRebirthPanel()
			end
		end
	end)

	rebirthPanel = Theme.createPanel({ Name = "RebirthPanel", Parent = screenGui, Size = UDim2.fromOffset(860, 620), Visible = false, ZIndex = 5 })
	rebirthPanel:SetAttribute("OpenPosition", rebirthPanel.Position)
	Theme.createCloseButton(rebirthPanel, function()
		if milestonePanel and milestonePanel.Visible then
			closeMilestonePanel()
		elseif skillTreePanel.Visible then
			closeSkillTreePanel()
		else
			closeRebirthPanel()
		end
	end, 30)
	Theme.createWindowHeader(rebirthPanel, "Ascension Gate", "Reset your run to earn permanent Ascension Shards", 8)

	previewStatsFrame = Theme.createFrame({
		Name = "PreviewStats", Parent = rebirthPanel,
		Size = UDim2.new(1, -32, 0, 54), Position = UDim2.fromOffset(16, 64),
		Bg = Theme.Colors.Navy, Corner = Theme.Corner.Large, ZIndex = 9,
	})
	Theme.stroke(previewStatsFrame, Theme.Colors.Gold, 1.5, 0.4)
	Theme.padding(previewStatsFrame, 8, 8, 12, 12)

	rebirthCountLabel = Theme.createText({
		Name = "RebirthCount", Parent = previewStatsFrame, Text = "Current Rebirth: 0",
		Size = UDim2.new(0.25, -6, 1, 0), TextSize = 12, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, ZIndex = 10,
	})
	nextRebirthLabel = Theme.createText({
		Name = "NextRebirth", Parent = previewStatsFrame, Text = "Next Rebirth: #1",
		Size = UDim2.new(0.25, -6, 1, 0), Position = UDim2.fromScale(0.25, 0),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright, ZIndex = 10,
	})
	Theme.createText({
		Name = "CurrentShardsTitle", Parent = previewStatsFrame, Text = "Current Shards",
		Size = UDim2.new(0.25, -6, 0, 16), Position = UDim2.fromScale(0.5, 0),
		TextSize = 10, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 10,
	})
	currentShardsPreviewLabel = Theme.createText({
		Name = "CurrentShardsValue", Parent = previewStatsFrame, Text = "0 ✦",
		Size = UDim2.new(0.25, -6, 0, 20), Position = UDim2.fromScale(0.5, 0.35),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 10,
	})
	Theme.createText({
		Name = "ProjectedShardsTitle", Parent = previewStatsFrame, Text = "Projected Shards",
		Size = UDim2.new(0.25, -6, 0, 16), Position = UDim2.fromScale(0.75, 0),
		TextSize = 10, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = 10,
	})
	projectedShardsPreviewLabel = Theme.createText({
		Name = "ProjectedShardsValue", Parent = previewStatsFrame, Text = "Loading...",
		Size = UDim2.new(0.25, -6, 0, 20), Position = UDim2.fromScale(0.75, 0.35),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.Success, ZIndex = 10,
	})

	local shardCapsule = Theme.createFrame({
		Name = "ShardCapsule", Parent = rebirthPanel, Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(1, -166, 0, 22), Bg = Theme.Colors.TopBarCapsule, Corner = Theme.Corner.Pill, ZIndex = 9,
	})
	Theme.stroke(shardCapsule, Theme.Colors.Gold, 1.5, 0.3)
	Theme.padding(shardCapsule, 6, 6, 10, 10)
	local shardIcon = Instance.new("ImageLabel")
	shardIcon.Size = UDim2.fromOffset(22, 22)
	shardIcon.BackgroundTransparency = 1
	shardIcon.Image = Theme.Icons.Star
	shardIcon.ScaleType = Enum.ScaleType.Fit
	shardIcon.Parent = shardCapsule
	shardBalanceLabel = Theme.createText({
		Name = "ShardBalance", Parent = shardCapsule, Text = "0",
		Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(28, 0),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 10,
	})

	previewErrorFrame = Theme.createFrame({
		Name = "PreviewError", Parent = rebirthPanel,
		Size = UDim2.new(1, -32, 0, 44), Position = UDim2.fromOffset(16, 124),
		Bg = Theme.Colors.StoneDeep, Corner = Theme.Corner.Medium, Visible = false, ZIndex = 10,
	})
	Theme.stroke(previewErrorFrame, Theme.Colors.Danger, 1.5, 0.35)
	Theme.padding(previewErrorFrame, 8, 8, 12, 12)
	Theme.createText({
		Name = "ErrorText", Parent = previewErrorFrame,
		Text = "Preview unavailable. Tap Retry to reload ascension data.",
		Size = UDim2.new(1, -110, 1, 0), TextSize = 12, Font = Theme.Fonts.Body,
		Color = Theme.Colors.Danger, ZIndex = 11,
	})
	previewRetryButton = Theme.createSecondaryButton({
		Name = "RetryPreview", Parent = previewErrorFrame, Text = "Retry",
		Size = UDim2.fromOffset(92, 30), Position = UDim2.new(1, -96, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5), ZIndex = 11, OnClick = fetchPreview,
	})

	Theme.createText({
		Name = "ReqTitle", Parent = rebirthPanel, Text = "Requirements",
		Size = UDim2.fromOffset(300, 24), Position = UDim2.fromOffset(16, 176),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = 9,
	})
	requirementScroll = Theme.createScrollList(rebirthPanel, UDim2.fromOffset(300, 250), UDim2.fromOffset(16, 204), 8)
	requirementScroll.Name = "RequirementList"
	requirementEmptyState = Theme.createEmptyState(requirementScroll, Theme.Icons.Rebirth, "Loading...", "Fetching rebirth requirements.", 10)

	Theme.createText({
		Name = "BreakdownTitle", Parent = rebirthPanel, Text = "Shard Reward Breakdown",
		Size = UDim2.fromOffset(260, 24), Position = UDim2.fromOffset(328, 176),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = 9,
	})
	breakdownScroll = Theme.createScrollList(rebirthPanel, UDim2.fromOffset(260, 118), UDim2.fromOffset(328, 204), 8)
	breakdownScroll.Name = "BreakdownList"
	breakdownEmptyState = Theme.createEmptyState(breakdownScroll, Theme.Icons.Star, "Preview unavailable.", "Shard breakdown will appear once preview loads.", 10)

	Theme.createText({
		Name = "ResetTitle", Parent = rebirthPanel, Text = "Reset Summary",
		Size = UDim2.fromOffset(260, 24), Position = UDim2.fromOffset(328, 330),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.Danger, ZIndex = 9,
	})
	resetSummaryScroll = Theme.createScrollList(rebirthPanel, UDim2.fromOffset(260, 96), UDim2.fromOffset(328, 358), 8)
	resetSummaryScroll.Name = "ResetSummaryList"
	Theme.createEmptyState(resetSummaryScroll, Theme.Icons.Book, "Preview unavailable.", "Reset summary will appear once preview loads.", 10)

	Theme.createText({
		Name = "KeptTitle", Parent = rebirthPanel, Text = "Permanent Progression Kept",
		Size = UDim2.fromOffset(516, 24), Position = UDim2.fromOffset(328, 462),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.Success, ZIndex = 9,
	})
	keptProgressScroll = Theme.createScrollList(rebirthPanel, UDim2.fromOffset(516, 72), UDim2.fromOffset(328, 490), 8)
	keptProgressScroll.Name = "KeptProgressList"
	Theme.createEmptyState(keptProgressScroll, Theme.Icons.Trophy, "Loading...", "Permanent progression is always kept across ascensions.", 10)

	skillTreeButton = Theme.createSecondaryButton({
		Name = "OpenSkillTree", Parent = rebirthPanel, Text = "Skill Tree",
		Size = UDim2.fromOffset(130, 44), Position = UDim2.fromOffset(16, 468),
		ZIndex = 9, OnClick = openSkillTreePanel,
	})

	milestoneButton = Theme.createSecondaryButton({
		Name = "OpenMilestones", Parent = rebirthPanel, Text = "Milestones",
		Size = UDim2.fromOffset(130, 44), Position = UDim2.fromOffset(154, 468),
		ZIndex = 9, OnClick = openMilestonePanel,
	})

	ascendSection = Theme.createFrame({
		Name = "AscendSection", Parent = rebirthPanel,
		Size = UDim2.fromOffset(516, 118), Position = UDim2.fromOffset(328, 572),
		AnchorPoint = Vector2.new(0, 1), Bg = Theme.Colors.Navy, Corner = Theme.Corner.Large, ZIndex = 9,
	})
	Theme.stroke(ascendSection, Theme.Colors.GoldBright, 2, 0.2)
	Theme.padding(ascendSection, 10, 10, 12, 12)

	ascendRewardLabel = Theme.createText({
		Name = "AscendReward", Parent = ascendSection, Text = "Projected Reward: Loading...",
		Size = UDim2.new(1, 0, 0, 22), TextSize = 16, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextGold, XAlign = Enum.TextXAlignment.Center, ZIndex = 10,
	})
	previewShardLabel = ascendRewardLabel

	confirmButton = Theme.createButton({
		Name = "ConfirmRebirth", Parent = ascendSection, Text = "ASCEND",
		Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 28),
		Bg = Theme.Colors.Success, TextSize = 22, ZIndex = 10, OnClick = confirmRebirth,
	})
	local ascendGradient = Instance.new("UIGradient")
	ascendGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.Success),
		ColorSequenceKeypoint.new(1, Theme.Colors.Gold),
	})
	ascendGradient.Rotation = 90
	ascendGradient.Parent = confirmButton

	ascendReasonLabel = Theme.createText({
		Name = "AscendReason", Parent = ascendSection, Text = "Loading preview...",
		Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16),
		TextSize = 11, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 10,
	})

	rebirthStatusLabel = Theme.createText({
		Name = "StatusLabel", Parent = rebirthPanel, Text = "Loading...",
		Size = UDim2.new(1, -32, 0, 22), Position = UDim2.new(0, 16, 1, -24),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})

	skillTreePanel = Theme.createPanel({ Name = "SkillTreePanel", Parent = screenGui, Size = UDim2.fromOffset(900, 600), Visible = false, ZIndex = 6 })
	skillTreePanel:SetAttribute("OpenPosition", skillTreePanel.Position)
	Theme.createWindowHeader(skillTreePanel, "Ascension Skill Tree", "Spend shards on permanent bonuses", 8)
	Theme.createCloseButton(skillTreePanel, closeSkillTreePanel, 30)

	skillTreeBackButton = Theme.createSecondaryButton({
		Name = "BackButton", Parent = skillTreePanel, Text = "← Back",
		Size = UDim2.fromOffset(100, 34), Position = UDim2.fromOffset(16, 64),
		ZIndex = 10, OnClick = backToRebirthFromSkillTree,
	})

	skillTreeShardLabel = Theme.createText({
		Name = "SkillTreeShards", Parent = skillTreePanel, Text = "0 ✦",
		Size = UDim2.fromOffset(200, 24), Position = UDim2.new(1, -216, 0, 68),
		TextSize = 16, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Right, ZIndex = 9,
	})

	local columnsWrap = Theme.createFrame({
		Name = "BranchColumns", Parent = skillTreePanel,
		Size = UDim2.new(1, -32, 1, -118), Position = UDim2.fromOffset(16, 104),
		BgTransparency = 1, ZIndex = 8,
	})
	local colLayout = Instance.new("UIListLayout")
	colLayout.FillDirection = Enum.FillDirection.Horizontal
	colLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	colLayout.Padding = UDim.new(0, 12)
	colLayout.SortOrder = Enum.SortOrder.LayoutOrder
	colLayout.Parent = columnsWrap

	for branchIndex, branch in RebirthConfig.SkillTreeBranches do
		local column = Theme.createFrame({
			Name = branch.Id .. "Column", Parent = columnsWrap,
			Size = UDim2.new(0.33, -8, 1, 0), Bg = Theme.Colors.Navy, Corner = Theme.Corner.Large,
			LayoutOrder = branchIndex, ZIndex = 8,
		})
		Theme.stroke(column, Theme.Colors.Gold, 1.5, 0.4)
		Theme.padding(column, 10, 10, 10, 10)

		local header = Theme.createFrame({
			Name = "Header", Parent = column, Size = UDim2.new(1, 0, 0, 44), BgTransparency = 1, ZIndex = 9,
		})
		Theme.createIconFrame(header, BRANCH_ICONS[branch.Id] or Theme.Icons.Star, 36, 9)
		local iconFrame = header:FindFirstChild("IconFrame")
		if iconFrame then iconFrame.Position = UDim2.fromOffset(0, 4) end
		Theme.createText({
			Name = "BranchTitle", Parent = header, Text = branch.Name or branch.Id,
			Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(44, 0),
			TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = 10,
		})

		local scroll = Theme.createScrollList(column, UDim2.new(1, 0, 1, -52), UDim2.fromOffset(0, 52), 9)
		scroll.Name = branch.Id .. "Nodes"
		branchColumns[branch.Id] = scroll

		local order = 1
		for _, node in RebirthConfig.SkillTreeNodes do
			if node.Branch == branch.Id and node.Disabled ~= true then
				local hasPrereq = typeof(node.Prerequisites) == "table" and #node.Prerequisites > 0
				buildSkillTreeNode(scroll, node, order, hasPrereq)
				order += 1
			end
		end
	end

	skillTreeStatusLabel = Theme.createText({
		Name = "SkillTreeStatus", Parent = skillTreePanel, Text = "Select a skill to purchase.",
		Size = UDim2.new(1, -32, 0, 22), Position = UDim2.new(0, 16, 1, -28),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})

	milestonePanel = Theme.createPanel({ Name = "MilestonePanel", Parent = screenGui, Size = UDim2.fromOffset(640, 520), Visible = false, ZIndex = 6 })
	milestonePanel:SetAttribute("OpenPosition", milestonePanel.Position)
	Theme.createWindowHeader(milestonePanel, "Ascension Milestones", "Permanent rewards earned across rebirths", 8)
	Theme.createCloseButton(milestonePanel, closeMilestonePanel, 30)

	milestoneBackButton = Theme.createSecondaryButton({
		Name = "BackButton", Parent = milestonePanel, Text = "← Back",
		Size = UDim2.fromOffset(100, 34), Position = UDim2.fromOffset(16, 64),
		ZIndex = 10, OnClick = backToRebirthFromMilestones,
	})

	milestoneScroll = Theme.createScrollList(milestonePanel, UDim2.new(1, -32, 1, -118), UDim2.fromOffset(16, 104), 9)
	milestoneScroll.Name = "MilestoneList"
	milestoneEmptyState = Theme.createEmptyState(milestoneScroll, Theme.Icons.Trophy, "No milestones unlocked yet.", "Ascend to higher rebirth counts to earn permanent milestone rewards.", 10)

	milestoneStatusLabel = Theme.createText({
		Name = "MilestoneStatus", Parent = milestonePanel, Text = "Reach higher rebirth counts to unlock rewards.",
		Size = UDim2.new(1, -32, 0, 22), Position = UDim2.new(0, 16, 1, -28),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})

	ceremonyGui = Instance.new("ScreenGui")
	ceremonyGui.Name = "RebirthCeremonyUI"
	ceremonyGui.ResetOnSpawn = false
	ceremonyGui.DisplayOrder = 80
	ceremonyGui.Enabled = false
	ceremonyGui.IgnoreGuiInset = true
	ceremonyGui.Parent = playerGui

	ceremonyDim = Theme.createFrame({
		Name = "CeremonyDim", Parent = ceremonyGui, Size = UDim2.fromScale(1, 1),
		Bg = Theme.Colors.Dim, BgTransparency = 1, ZIndex = 1,
	})
	ceremonyContent = Theme.createFrame({
		Name = "CeremonyContent", Parent = ceremonyGui, Size = UDim2.fromScale(1, 1),
		BgTransparency = 1, ZIndex = 2,
	})
	ceremonyRebirthLabel = Theme.createText({
		Name = "RebirthNumber", Parent = ceremonyContent, Text = "ASCENSION 1",
		Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromScale(0.5, 0.38), AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 48, Font = Theme.Fonts.Title, Color = Theme.Colors.GoldBright,
		XAlign = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 3,
	})
	ceremonyShardIcon = Instance.new("ImageLabel")
	ceremonyShardIcon.Name = "ShardIcon"
	ceremonyShardIcon.Size = UDim2.fromOffset(72, 72)
	ceremonyShardIcon.Position = UDim2.fromScale(0.5, 0.5)
	ceremonyShardIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	ceremonyShardIcon.BackgroundTransparency = 1
	ceremonyShardIcon.Image = Theme.Icons.Star
	ceremonyShardIcon.ScaleType = Enum.ScaleType.Fit
	ceremonyShardIcon.ImageTransparency = 1
	ceremonyShardIcon.ZIndex = 3
	ceremonyShardIcon.Parent = ceremonyContent
	ceremonyShardLabel = Theme.createText({
		Name = "ShardGrant", Parent = ceremonyContent, Text = "+0 ✦",
		Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromScale(0.5, 0.58), AnchorPoint = Vector2.new(0.5, 0.5),
		TextSize = 32, Font = Theme.Fonts.Title, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 3,
	})
end

buildUi()
fetchState()

RebirthStateUpdated.OnClientEvent:Connect(applyState)

RebirthCeremonyStart.OnClientEvent:Connect(function(payload)
	if rebirthInvokeInProgress or ceremonyActive then
		return
	end
	task.spawn(function()
		playCeremony(payload, { openSkillTree = true })
	end)
end)

RebirthCeremonyComplete.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" then
		pendingOpenSkillTree = payload.openSkillTree == true
	end
end)

player:GetAttributeChangedSignal("AscensionShards"):Connect(setShardDisplays)
player:GetAttributeChangedSignal("Rebirthing"):Connect(refreshPreviewUI)

_G.DragonIslandOpenRebirth = openRebirthPanel
_G.DragonIslandCloseRebirth = closeRebirthPanel
_G.DragonIslandOpenSkillTree = openSkillTreePanel
_G.DragonIslandCloseSkillTree = closeSkillTreePanel
_G.DragonIslandOpenMilestones = openMilestonePanel
_G.DragonIslandCloseMilestones = closeMilestonePanel

UIBridge.RegisterPanel("Rebirth", { Open = openRebirthPanel, Close = closeRebirthPanel })
UIBridge.RegisterPanel("SkillTree", { Open = openSkillTreePanel, Close = closeSkillTreePanel })
UIBridge.RegisterPanel("Milestones", { Open = openMilestonePanel, Close = closeMilestonePanel })
