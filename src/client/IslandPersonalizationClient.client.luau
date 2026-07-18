local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local KingdomEvents = ReplicatedStorage:WaitForChild("KingdomEvents")
local RequestKingdomData = KingdomEvents:WaitForChild("RequestKingdomData")
local UpdateKingdomName = KingdomEvents:WaitForChild("UpdateKingdomName")
local PlaceDecoration = KingdomEvents:WaitForChild("PlaceDecoration")
local KingdomStateUpdated = KingdomEvents:WaitForChild("KingdomStateUpdated")

local screenGui
local panel
local nameBox
local statusLabel
local decorList

local function setStatus(text, good)
	if statusLabel then
		statusLabel.Text = text or ""
		statusLabel.TextColor3 = good and Theme.Colors.Success or Theme.Colors.Danger
	end
end

local function closePersonalizationPanel()
	if not screenGui or not panel then
		return
	end
	local dim = screenGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(screenGui, panel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(screenGui.Name)
		end
	end)
end

local function buildUi()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IslandPersonalizationUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 30
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local dim = Theme.createDim(screenGui, 1)
	dim.Name = "DimBackground"
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closePersonalizationPanel()
		end
	end)

	panel = Theme.createPanel({ Name = "PersonalizePanel", Parent = screenGui, Size = UDim2.fromOffset(540, 500), Visible = false })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		closePersonalizationPanel()
	end, 30)
	Theme.createWindowHeader(panel, "Kingdom Management", "Name your realm and place decorations", 8)

	Theme.createText({
		Name = "NameLabel", Parent = panel, Text = "Kingdom Name",
		Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(18, 72),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 8,
	})

	local nameInputWrap = Theme.createFrame({
		Name = "NameInputWrap", Parent = panel,
		Size = UDim2.new(1, -32, 0, 38), Position = UDim2.fromOffset(16, 94),
		Bg = Theme.Colors.NavyEdge, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.stroke(nameInputWrap, Theme.Colors.Gold, 1.5, 0.45)

	nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(1, -16, 1, -8)
	nameBox.Position = UDim2.fromOffset(8, 4)
	nameBox.BackgroundTransparency = 1
	nameBox.Font = Theme.Fonts.Bold
	nameBox.PlaceholderText = "Enter kingdom name"
	nameBox.PlaceholderColor3 = Theme.Colors.TextMuted
	nameBox.Text = ""
	nameBox.TextColor3 = Theme.Colors.TextLight
	nameBox.TextSize = 15
	nameBox.ClearTextOnFocus = false
	nameBox.ZIndex = 9
	nameBox.Parent = nameInputWrap

	Theme.createButton({
		Name = "SaveNameButton", Parent = panel, Text = "Save Name",
		Size = UDim2.new(1, -32, 0, 36), Position = UDim2.fromOffset(16, 140),
		Bg = Theme.Colors.Success, TextSize = 15, ZIndex = 8,
		OnClick = function()
			UpdateKingdomName:FireServer(nameBox.Text)
		end,
	})

	Theme.createText({
		Name = "DecorTitle", Parent = panel, Text = "Place Decorations",
		Size = UDim2.new(1, -32, 0, 20), Position = UDim2.fromOffset(18, 188),
		TextSize = 14, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 8,
	})

	decorList = Theme.createScrollList(panel, UDim2.new(1, -32, 0, 190), UDim2.fromOffset(16, 214), 8)
	decorList.Name = "DecorList"

	statusLabel = Theme.createText({
		Name = "StatusLabel", Parent = panel, Text = "",
		Size = UDim2.new(1, -32, 0, 36), Position = UDim2.new(0, 16, 1, -44),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.CrystalSoft,
		YAlign = Enum.TextYAlignment.Top, ZIndex = 8,
	})
end

local function refreshDecorations(decorations, available)
	if not decorList then return end
	for _, child in decorList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if typeof(available) ~= "table" then
		return
	end
	for index, decor in available do
		Theme.createListRow(decorList, {
			Name = decor.id .. "Row",
			Text = decor.displayName .. "\nCost: " .. tostring(decor.cost) .. " essence",
			LayoutOrder = index,
			Height = 52,
			ZIndex = 9,
			OnClick = function()
				PlaceDecoration:FireServer(decor.id)
			end,
		})
	end
	if typeof(decorations) == "table" then
		setStatus(#decorations .. " decorations placed", true)
	end
end

local function refreshState(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if nameBox and typeof(payload.kingdomName) == "string" then
		nameBox.Text = payload.kingdomName
	end
	refreshDecorations(payload.decorations, payload.availableDecorations)
	if typeof(payload.message) == "string" and payload.message ~= "" then
		local good = string.find(payload.message, "Placed", 1, true) ~= nil or string.find(payload.message, "renamed", 1, true) ~= nil
		setStatus(payload.message, good)
	end
end

local function openPanel()
	if not screenGui then
		buildUi()
	end
	local dim = screenGui:FindFirstChild("DimBackground")
	local opening = panel and not panel.Visible
	screenGui.Enabled = true
	if opening then
		Theme.raiseModalGui(screenGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(screenGui.Name)
		end
	end
	Theme.tweenOpen(panel, dim)
	local success, result = pcall(function()
		return RequestKingdomData:InvokeServer()
	end)
	if success then
		refreshState(result)
	end
end

_G.DragonIslandOpenPersonalization = openPanel
_G.DragonIslandClosePersonalization = closePersonalizationPanel

UIBridge.RegisterPanel("Personalization", { Open = openPanel, Close = closePersonalizationPanel })

KingdomStateUpdated.OnClientEvent:Connect(refreshState)