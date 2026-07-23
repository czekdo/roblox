local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local GlobalEventConfig = require(ReplicatedStorage:WaitForChild("GlobalEventConfig"))

local GlobalEventEvents = ReplicatedStorage:WaitForChild("GlobalEventEvents")
local RequestGlobalEventState = GlobalEventEvents:WaitForChild("RequestGlobalEventState")
local GlobalEventChanged = GlobalEventEvents:WaitForChild("GlobalEventChanged")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GlobalEventUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = Theme.HudDisplayOrder or 5
screenGui.Enabled = false
screenGui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "EventBanner"
banner.Size = UDim2.fromOffset(280, 44)
banner.Position = UDim2.new(0.5, 0, 0, 8)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.BackgroundColor3 = Theme.Colors.NavyDeep
banner.BorderSizePixel = 0
banner.ZIndex = Theme.HudDisplayOrder or 5
banner.Parent = screenGui
Theme.corner(banner, Theme.Corner.Pill)
Theme.stroke(banner, Theme.Colors.GoldBright, 2, 0.1)

local icon = Instance.new("ImageLabel")
icon.Name = "Icon"
icon.Size = UDim2.fromOffset(28, 28)
icon.Position = UDim2.fromOffset(8, 8)
icon.BackgroundTransparency = 1
icon.ScaleType = Enum.ScaleType.Fit
icon.ZIndex = banner.ZIndex + 1
icon.Parent = banner

local label = Instance.new("TextLabel")
label.Name = "Label"
label.Size = UDim2.new(1, -46, 1, 0)
label.Position = UDim2.fromOffset(42, 0)
label.BackgroundTransparency = 1
label.Font = Theme.Fonts.Bold
label.TextSize = 13
label.TextColor3 = Theme.Colors.TextLight
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextWrapped = false
label.Text = ""
label.ZIndex = banner.ZIndex + 1
label.Parent = banner

local currentEvent = nil

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%dh %dm left", hours, minutes)
	end
	return string.format("%dm left", math.max(1, minutes))
end

local function applyEvent(event)
	currentEvent = event
	if typeof(event) ~= "table" then
		screenGui.Enabled = false
		return
	end
	local typeInfo = GlobalEventConfig.Types[event.type]
	icon.Image = (typeInfo and typeInfo.Icon) or Theme.Icons.Star
	screenGui.Enabled = true
end

local initialOk, initialState = pcall(function()
	return RequestGlobalEventState:InvokeServer()
end)
if initialOk then
	applyEvent(initialState)
end

GlobalEventChanged.OnClientEvent:Connect(applyEvent)

RunService.Heartbeat:Connect(function()
	if typeof(currentEvent) ~= "table" then
		return
	end
	local remaining = (currentEvent.endsAt or 0) - os.time()
	if remaining <= 0 then
		applyEvent(nil)
		return
	end
	local multiplier = tonumber(currentEvent.multiplier) or 1
	label.Text = string.format("%s x%.2g - %s", tostring(currentEvent.label or currentEvent.type), multiplier, formatRemaining(remaining))
end)

print("[GlobalEventClient] Global event banner ready")
