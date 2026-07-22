local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local LOADING_IMAGE = "rbxassetid://74886332909363"
local MIN_DISPLAY_TIME = 1.5
local FADE_TIME = 0.5

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameLoadingScreen"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.Parent = playerGui

local background = Instance.new("ImageLabel")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
background.BorderSizePixel = 0
background.Image = LOADING_IMAGE
background.ScaleType = Enum.ScaleType.Crop
background.ZIndex = 1
background.Parent = screenGui

local dim = Instance.new("Frame")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.4
dim.BorderSizePixel = 0
dim.ZIndex = 2
dim.Parent = screenGui

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -40, 0, 60)
title.Position = UDim2.new(0.5, 0, 0.74, 0)
title.AnchorPoint = Vector2.new(0.5, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 34
title.TextColor3 = Color3.fromRGB(255, 221, 133)
title.TextStrokeTransparency = 0.4
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.Text = "DRAGON ISLAND KINGDOM"
title.ZIndex = 3
title.Parent = screenGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -40, 0, 22)
statusLabel.Position = UDim2.new(0.5, 0, 0.74, 62)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 15
statusLabel.TextColor3 = Color3.fromRGB(214, 222, 236)
statusLabel.TextStrokeTransparency = 0.6
statusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
statusLabel.Text = "Summoning your kingdom..."
statusLabel.ZIndex = 3
statusLabel.Parent = screenGui

local barBack = Instance.new("Frame")
barBack.Name = "BarBack"
barBack.Size = UDim2.new(0, 360, 0, 8)
barBack.Position = UDim2.new(0.5, 0, 0.74, 96)
barBack.AnchorPoint = Vector2.new(0.5, 0)
barBack.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
barBack.BorderSizePixel = 0
barBack.ZIndex = 3
barBack.Parent = screenGui

local barBackCorner = Instance.new("UICorner")
barBackCorner.CornerRadius = UDim.new(1, 0)
barBackCorner.Parent = barBack

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 200, 92)
barFill.BorderSizePixel = 0
barFill.ZIndex = 4
barFill.Parent = barBack

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent = barFill

-- Creeps toward ~92% while real assets stream in, then snaps to 100% once actually ready - avoids
-- a fake bar that finishes long before the game is actually playable.
local progress = 0
local animating = true
task.spawn(function()
	while animating do
		progress = math.min(0.92, progress + (0.92 - progress) * 0.05 + 0.003)
		barFill.Size = UDim2.new(progress, 0, 1, 0)
		task.wait(0.05)
	end
end)

local startClock = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Keep the artwork on screen for a minimum stretch so it isn't just a one-frame flash for players
-- on a fast connection where everything loads almost instantly.
local elapsed = os.clock() - startClock
if elapsed < MIN_DISPLAY_TIME then
	task.wait(MIN_DISPLAY_TIME - elapsed)
end

animating = false
barFill.Size = UDim2.new(1, 0, 1, 0)
statusLabel.Text = "Ready!"
task.wait(0.25)

local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(background, fadeInfo, { ImageTransparency = 1 }):Play()
TweenService:Create(dim, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
TweenService:Create(statusLabel, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
TweenService:Create(barBack, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barFill, fadeInfo, { BackgroundTransparency = 1 }):Play()

task.wait(FADE_TIME + 0.1)
screenGui:Destroy()
