local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local DragonStorageFull = HarvestEvents:WaitForChild("DragonStorageFull")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui
local panel
local dimFrame

local function closePopup()
	if not screenGui or not panel then
		return
	end
	Theme.closeModalWindow(screenGui, panel, dimFrame, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function ensureUi()
	if screenGui then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DragonStorageFullUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 90
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	dimFrame = Theme.createDim(screenGui, 1)
	dimFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePopup()
		end
	end)

	panel = Theme.createPanel({
		Name = "StorageFullPanel",
		Parent = screenGui,
		Size = UDim2.fromOffset(460, 360),
		Visible = false,
		ZIndex = 25,
	})
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, closePopup, 30)

	Theme.createWindowHeader(panel, "DRAGON STORAGE FULL", "Your Dragon Storage is full.", 30)

	Theme.createText({
		Name = "Body",
		Parent = panel,
		Text = "You cannot hatch another dragon until you make room in storage.",
		Size = UDim2.new(1, -32, 0, 72),
		Position = UDim2.fromOffset(16, 88),
		TextSize = 14,
		Font = Theme.Fonts.Body,
		Color = Theme.Colors.TextMuted,
		Wrapped = true,
		ZIndex = 8,
	})

	local function makeAction(name, text, position, size, bg, onClick)
		return Theme.createButton({
			Name = name,
			Parent = panel,
			Text = text,
			Size = size,
			Position = position,
			Bg = bg,
			TextSize = 13,
			OnClick = onClick,
		})
	end

	makeAction("OpenStorageButton", "Open Storage", UDim2.fromOffset(16, 176), UDim2.new(0.46, 0, 0, 40), Theme.Colors.Crystal, function()
		closePopup()
		if _G.DragonIslandOpenRoster then
			_G.DragonIslandOpenRoster("Manage your dragon storage.")
		end
	end)

	makeAction("MergeButton", "Merge Dragons", UDim2.new(0.54, 0, 0, 176), UDim2.new(0.46, 0, 0, 40), Theme.Colors.Purple, function()
		closePopup()
		if _G.DragonIslandOpenMergeUI then
			_G.DragonIslandOpenMergeUI("Merge dragons to free storage.")
		end
	end)

	makeAction("UpgradeButton", "Upgrade Storage", UDim2.fromOffset(16, 228), UDim2.new(0.46, 0, 0, 40), Theme.Colors.Gold, function()
		closePopup()
		if _G.DragonIslandOpenBuildings then
			_G.DragonIslandOpenBuildings("Upgrade Dragon Storage capacity.")
		end
	end)

	makeAction("CancelButton", "Cancel", UDim2.new(0.54, 0, 0, 228), UDim2.new(0.46, 0, 0, 40), Theme.Colors.StoneDeep, closePopup)
end

_G.DragonIslandCloseStorageFull = function()
	closePopup()
end

local function openPopup(payload)
	ensureUi()
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	if _G.DragonIslandNotifyModalOpened then
		_G.DragonIslandNotifyModalOpened(screenGui.Name)
	end
	Theme.tweenOpen(panel, dimFrame)
end

DragonStorageFull.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		payload = {}
	end
	openPopup(payload)
end)
