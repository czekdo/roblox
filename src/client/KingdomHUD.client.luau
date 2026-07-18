local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local HarvestConfig = require(ReplicatedStorage:WaitForChild("HarvestConfig"))
local HarvestUIUpdate = ReplicatedStorage:WaitForChild("HarvestEvents"):WaitForChild("HarvestUIUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local KINGDOM_NAME = "Dragon Island Kingdom"
local essenceLabel
local gemsLabel
local shardsLabel
local capacityLabel
local levelLabel
local kingdomNameLabel
local xpFill

local function getKingdomLevel()
	return player:GetAttribute("KingdomLevel") or 1
end

local function getKingdomName()
	return player:GetAttribute("KingdomName") or KINGDOM_NAME
end

local function getKingdomXP()
	return player:GetAttribute("KingdomXP") or 0
end

local function getKingdomXPMax()
	return player:GetAttribute("KingdomXPMax") or 18000
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KingdomHUD"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = Theme.HudDisplayOrder
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui
Theme.applyScreenSafeArea(screenGui)

local edge = Theme.SafeArea.Edge
local topBar = Theme.createFrame({
	Name = "TopBar", Parent = screenGui,
	Size = UDim2.new(1, -(edge * 2), 0, 72),
	Position = UDim2.new(0.5, 0, 0, Theme.SafeArea.TopExtra),
	AnchorPoint = Vector2.new(0.5, 0), BgTransparency = 1,
})
Theme.makeInputTransparent(topBar)

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0, 10)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.Parent = topBar

local kingdomCapsule
kingdomCapsule, kingdomNameLabel, levelLabel, xpFill = Theme.createKingdomCapsule(topBar)
kingdomCapsule.LayoutOrder = 1

local centerWrap = Theme.createFrame({
	Name = "Resources", Parent = topBar, Size = UDim2.fromOffset(0, 48),
	BgTransparency = 1, LayoutOrder = 2,
})
centerWrap.AutomaticSize = Enum.AutomaticSize.X
Theme.makeInputTransparent(centerWrap)
local resLayout = Instance.new("UIListLayout")
resLayout.FillDirection = Enum.FillDirection.Horizontal
resLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
resLayout.VerticalAlignment = Enum.VerticalAlignment.Center
resLayout.Padding = UDim.new(0, 10)
resLayout.SortOrder = Enum.SortOrder.LayoutOrder
resLayout.Parent = centerWrap

local _, essenceVal = Theme.createPremiumResourceCapsule(centerWrap, Theme.Icons.Crystal, "EssenceAmount", 1)
essenceLabel = essenceVal
local _, gemsVal = Theme.createPremiumResourceCapsule(centerWrap, Theme.Icons.Premium, "GemsAmount", 2)
gemsLabel = gemsVal
gemsLabel.Text = Theme.formatCompact(player:GetAttribute("PremiumGems") or 2450)
local _, shardsVal = Theme.createPremiumResourceCapsule(centerWrap, Theme.Icons.Star, "AscensionShardsAmount", 3)
shardsLabel = shardsVal
shardsLabel.Text = Theme.formatCompact(player:GetAttribute("AscensionShards") or 0)
local _, capVal = Theme.createPremiumResourceCapsule(centerWrap, Theme.Icons.Dragon, "CapacityAmount", 4)
capacityLabel = capVal
capacityLabel.Text = "0 / " .. tostring(HarvestConfig.MaxDragons)

local rightWrap = Theme.createFrame({
	Name = "RightWrap", Parent = topBar, Size = UDim2.fromOffset(0, 48),
	BgTransparency = 1, LayoutOrder = 3,
})
rightWrap.AutomaticSize = Enum.AutomaticSize.X
Theme.makeInputTransparent(rightWrap)
local rightLayout = Instance.new("UIListLayout")
rightLayout.FillDirection = Enum.FillDirection.Horizontal
rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rightLayout.Padding = UDim.new(0, 8)
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
rightLayout.Parent = rightWrap

local profileCapsule = Theme.createFrame({
	Name = "ProfileCapsule", Parent = rightWrap, Size = UDim2.fromOffset(0, 48),
	Bg = Theme.Colors.TopBarCapsule, Corner = Theme.Corner.Pill, LayoutOrder = 1,
})
profileCapsule.AutomaticSize = Enum.AutomaticSize.X
Theme.stroke(profileCapsule, Theme.Colors.Gold, 2, 0.2)
Theme.padding(profileCapsule, 6, 6, 6, 8)
local profileLayout = Instance.new("UIListLayout")
profileLayout.FillDirection = Enum.FillDirection.Horizontal
profileLayout.VerticalAlignment = Enum.VerticalAlignment.Center
profileLayout.Padding = UDim.new(0, 6)
profileLayout.SortOrder = Enum.SortOrder.LayoutOrder
profileLayout.Parent = profileCapsule

local avatarFrame = Theme.createFrame({
	Name = "Avatar", Parent = profileCapsule, Size = UDim2.fromOffset(36, 36),
	Bg = Theme.Colors.TopBarCapsuleEdge, Corner = Theme.Corner.Pill, LayoutOrder = 1,
})
Theme.stroke(avatarFrame, Theme.Colors.GoldBright, 1.5, 0.35)
local avatarImg = Instance.new("ImageLabel")
avatarImg.Name = "AvatarImage"
avatarImg.Size = UDim2.fromScale(1, 1)
avatarImg.BackgroundTransparency = 1
avatarImg.Parent = avatarFrame
Theme.corner(avatarImg, Theme.Corner.Pill)
task.spawn(function()
	local ok, thumb = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)
	if ok then avatarImg.Image = thumb end
end)

local playerNameLabel = Theme.createText({
	Name = "PlayerName", Parent = profileCapsule, Text = player.DisplayName,
	Size = UDim2.fromOffset(88, 20),
	TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
	Wrapped = false, Truncate = Enum.TextTruncate.AtEnd, LayoutOrder = 2,
})

Theme.createIconButton({
	Name = "SettingsButton", Parent = rightWrap, Size = UDim2.fromOffset(44, 44),
	Bg = Theme.Colors.TopBarCapsule, Image = Theme.Icons.Settings, LayoutOrder = 2,
	Stroke = true, StrokeColor = Theme.Colors.Gold, StrokeTransparency = 0.2,
	OnClick = function() if _G.DragonIslandOpenSettings then _G.DragonIslandOpenSettings() end end,
})
Theme.createIconButton({
	Name = "MailButton", Parent = rightWrap, Size = UDim2.fromOffset(44, 44),
	Bg = Theme.Colors.TopBarCapsule, Image = Theme.Icons.Mail, LayoutOrder = 3,
	Stroke = true, StrokeColor = Theme.Colors.Gold, StrokeTransparency = 0.2,
	OnClick = function() if _G.DragonIslandOpenMail then _G.DragonIslandOpenMail() end end,
})
Theme.createIconButton({
	Name = "DailyRewardButton", Parent = rightWrap, Size = UDim2.fromOffset(44, 44),
	Bg = Theme.Colors.TopBarCapsule, Image = Theme.Icons.Gift, LayoutOrder = 4, Badge = "1",
	Stroke = true, StrokeColor = Theme.Colors.Gold, StrokeTransparency = 0.2,
	OnClick = function() if _G.DragonIslandOpenDailyReward then _G.DragonIslandOpenDailyReward() end end,
})

local function refreshKingdomStatus()
	kingdomNameLabel.Text = string.upper(getKingdomName())
	levelLabel.Text = "Lv. " .. tostring(getKingdomLevel())
	local xp = getKingdomXP()
	local xpMax = math.max(1, getKingdomXPMax())
	local ratio = math.clamp(xp / xpMax, 0, 1)
	TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(ratio, 1) }):Play()
end

local function updateResources(essence, activeCount, _activeWorkers, maxActive, storageCount, storageMax)
	if typeof(essence) == "number" then
		essenceLabel.Text = Theme.formatCompact(essence)
	end
	if typeof(activeCount) == "number" and typeof(maxActive) == "number" then
		local storageLine = ""
		if typeof(storageCount) == "number" and typeof(storageMax) == "number" then
			storageLine = "  •  " .. tostring(storageCount) .. "/" .. tostring(storageMax)
		end
		capacityLabel.Text = tostring(activeCount) .. "/" .. tostring(maxActive) .. storageLine
	end
end

HarvestUIUpdate.OnClientEvent:Connect(function(essence, activeCount, activeWorkers, maxActive, storageCount, storageMax)
	updateResources(essence, activeCount, activeWorkers, maxActive, storageCount, storageMax)
end)

player:GetAttributeChangedSignal("KingdomLevel"):Connect(refreshKingdomStatus)
player:GetAttributeChangedSignal("KingdomName"):Connect(refreshKingdomStatus)
player:GetAttributeChangedSignal("KingdomXP"):Connect(refreshKingdomStatus)
player:GetAttributeChangedSignal("KingdomXPMax"):Connect(refreshKingdomStatus)
player:GetAttributeChangedSignal("PremiumGems"):Connect(function()
	gemsLabel.Text = Theme.formatCompact(player:GetAttribute("PremiumGems") or 0)
end)
player:GetAttributeChangedSignal("AscensionShards"):Connect(function()
	shardsLabel.Text = Theme.formatCompact(player:GetAttribute("AscensionShards") or 0)
end)

refreshKingdomStatus()
updateResources(0, 0, HarvestConfig.MaxDragons)
