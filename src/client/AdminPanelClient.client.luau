local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local AdminEvents = ReplicatedStorage:WaitForChild("AdminEvents")
local AdminCommand = AdminEvents:WaitForChild("AdminCommand")
local AdminResult = AdminEvents:WaitForChild("AdminResult")
local CheckAdminAccess = AdminEvents:WaitForChild("CheckAdminAccess")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local adminData
local ok, result = pcall(function()
	return CheckAdminAccess:InvokeServer()
end)
if not ok or typeof(result) ~= "table" or result.isAdmin ~= true then
	return
end
adminData = result

local Colors = {
	Panel = Color3.fromRGB(16, 24, 40),
	PanelGlass = Color3.fromRGB(22, 32, 52),
	Sidebar = Color3.fromRGB(12, 18, 32),
	Row = Color3.fromRGB(26, 36, 58),
	Input = Color3.fromRGB(20, 30, 48),
	Border = Color3.fromRGB(72, 162, 255),
	BorderSoft = Color3.fromRGB(48, 98, 160),
	Gold = Color3.fromRGB(218, 178, 72),
	GoldBright = Color3.fromRGB(255, 214, 102),
	Text = Color3.fromRGB(232, 238, 248),
	TextMuted = Color3.fromRGB(132, 148, 176),
	Success = Color3.fromRGB(72, 190, 120),
	Danger = Color3.fromRGB(220, 88, 98),
	Info = Color3.fromRGB(72, 162, 255),
	Dim = Color3.fromRGB(6, 10, 18),
}

local TabIcons = {
	Player = Theme.Icons.Crown,
	Resources = Theme.Icons.Crystal,
	Eggs = Theme.Icons.Egg,
	Dragons = Theme.Icons.Dragon,
	World = Theme.Icons.House,
	Buildings = Theme.Icons.Hammer,
	Events = Theme.Icons.Star,
	Progress = Theme.Icons.Scroll,
	Save = Theme.Icons.Backpack,
	Debug = Theme.Icons.Settings,
}

local TAB_ORDER = adminData.tabs or AdminConfig.TabOrder
local isOpen = false
local currentTab = "Player"
local savedTab = "Player"
local savedPanelPosition = UDim2.fromScale(0.5, 0.5)
local searchQuery = ""
local tabButtons = {}
local tabPages = {}
local searchableRows = {}
local notificationTokens = 0

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Colors.Border
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function padding(parent, top, bottom, left, right)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, top or 12)
	p.PaddingBottom = UDim.new(0, bottom or top or 12)
	p.PaddingLeft = UDim.new(0, left or top or 12)
	p.PaddingRight = UDim.new(0, right or left or top or 12)
	p.Parent = parent
	return p
end

local function createFrame(props)
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Frame"
	frame.Size = props.Size or UDim2.fromOffset(100, 100)
	frame.Position = props.Position or UDim2.fromOffset(0, 0)
	frame.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = props.Bg or Colors.PanelGlass
	frame.BackgroundTransparency = props.BgTransparency or 0.08
	frame.BorderSizePixel = 0
	frame.Visible = props.Visible ~= false
	frame.ZIndex = props.ZIndex or 2
	if props.LayoutOrder then frame.LayoutOrder = props.LayoutOrder end
	frame.Parent = props.Parent
	if props.Corner then corner(frame, props.Corner) end
	if props.Stroke then stroke(frame, props.StrokeColor, props.StrokeThickness, props.StrokeTransparency) end
	return frame
end

local function createText(props)
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.Size = props.Size or UDim2.fromScale(1, 0)
	label.Position = props.Position or UDim2.fromOffset(0, 0)
	label.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	label.BackgroundTransparency = props.BgTransparency or 1
	label.Font = props.Font or Theme.Fonts.Bold
	label.Text = props.Text or ""
	label.TextColor3 = props.Color or Colors.Text
	label.TextSize = props.TextSize or 14
	label.TextWrapped = props.Wrapped ~= false
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	if props.Truncate then label.TextTruncate = props.Truncate end
	if props.LayoutOrder then label.LayoutOrder = props.LayoutOrder end
	label.ZIndex = props.ZIndex or 3
	if props.AutoSize then label.AutomaticSize = props.AutoSize end
	label.Parent = props.Parent
	return label
end

local function attachHover(gui, baseColor)
	baseColor = baseColor or gui.BackgroundColor3
	gui.MouseEnter:Connect(function()
		if gui.Parent then
			TweenService:Create(gui, TweenInfo.new(0.14), { BackgroundColor3 = baseColor:Lerp(Colors.Border, 0.25) }):Play()
		end
	end)
	gui.MouseLeave:Connect(function()
		if gui.Parent then
			TweenService:Create(gui, TweenInfo.new(0.14), { BackgroundColor3 = baseColor }):Play()
		end
	end)
end

local function attachBounce(gui)
	local baseSize = gui.Size
	gui.Activated:Connect(function()
		if not gui.Parent then return end
		local shrink = TweenService:Create(gui, TweenInfo.new(0.06), { Size = baseSize - UDim2.fromOffset(3, 3) })
		shrink:Play()
		shrink.Completed:Connect(function()
			TweenService:Create(gui, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = baseSize }):Play()
		end)
	end)
end

local function createButton(props)
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.Size = props.Size or UDim2.fromOffset(120, 40)
	button.Position = props.Position or UDim2.fromOffset(0, 0)
	button.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	button.BackgroundColor3 = props.Bg or Colors.Info
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = props.Font or Theme.Fonts.Bold
	button.Text = props.Text or ""
	button.TextColor3 = props.TextColor or Colors.Text
	button.TextSize = props.TextSize or 14
	button.TextWrapped = props.Wrapped ~= false
	if props.LayoutOrder then button.LayoutOrder = props.LayoutOrder end
	button.ZIndex = props.ZIndex or 4
	button.Parent = props.Parent
	corner(button, props.Corner or UDim.new(0, 10))
	if props.Stroke then stroke(button, props.StrokeColor or Colors.BorderSoft, 1, 0.45) end
	if props.OnClick then button.Activated:Connect(props.OnClick) end
	attachHover(button, props.Bg or Colors.Info)
	attachBounce(button)
	return button
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DevAdminPanel"
screenGui.ResetOnSpawn = false
screenGui.Enabled = true
screenGui.DisplayOrder = 95
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui
Theme.applyScreenSafeArea(screenGui)

local notificationLayer = createFrame({ Name = "NotificationLayer", Parent = screenGui, Size = UDim2.fromScale(1, 1), BgTransparency = 1, ZIndex = 30 })
notificationLayer.Active = false
local notificationList = Instance.new("UIListLayout")
notificationList.FillDirection = Enum.FillDirection.Vertical
notificationList.HorizontalAlignment = Enum.HorizontalAlignment.Right
notificationList.VerticalAlignment = Enum.VerticalAlignment.Bottom
notificationList.Padding = UDim.new(0, 8)
notificationList.SortOrder = Enum.SortOrder.LayoutOrder
notificationList.Parent = notificationLayer
padding(notificationLayer, 16, 16, 16, 16)

local function showNotification(message, kind)
	notificationTokens += 1
	local bg = Colors.Info
	local prefix = "ℹ "
	if kind == "success" then bg = Colors.Success; prefix = "✔ "
	elseif kind == "error" then bg = Colors.Danger; prefix = "✖ " end
	local toast = createFrame({ Name = "Toast" .. notificationTokens, Parent = notificationLayer, Size = UDim2.fromOffset(280, 44), Bg = bg, BgTransparency = 0.12, Corner = UDim.new(0, 10), ZIndex = 31 })
	stroke(toast, Colors.Border, 1, 0.55)
	createText({ Parent = toast, Text = prefix .. tostring(message or ""), Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 13, Color = Colors.Text, ZIndex = 32 })
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 0.12 }):Play()
	task.delay(3.2, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Connect(function() if toast.Parent then toast:Destroy() end end)
		end
	end)
end

local function sendAction(action, payload)
	AdminCommand:FireServer(action, payload or {})
end

local blur = Lighting:FindFirstChild("DevAdminBlur")
if not blur then
	blur = Instance.new("BlurEffect")
	blur.Name = "DevAdminBlur"
	blur.Size = 0
	blur.Parent = Lighting
end

local dim = createFrame({ Name = "DimBackground", Parent = screenGui, Size = UDim2.fromScale(1, 1), Bg = Colors.Dim, BgTransparency = 1, Visible = false, ZIndex = 1 })
dim.Active = true

local panel = createFrame({ Name = "AdminPanel", Parent = screenGui, Size = UDim2.fromScale(0.7, 0.8), Position = savedPanelPosition, AnchorPoint = Vector2.new(0.5, 0.5), Bg = Colors.Panel, BgTransparency = 0.06, Corner = UDim.new(0, 18), Visible = false, ZIndex = 5 })
stroke(panel, Colors.Border, 1.5, 0.2)
local panelScale = Instance.new("UIScale")
panelScale.Scale = 1
panelScale.Parent = panel

createFrame({ Name = "Shadow", Parent = panel, Size = UDim2.new(1, 18, 1, 18), Position = UDim2.fromOffset(-9, -4), Bg = Color3.fromRGB(0, 0, 0), BgTransparency = 0.72, Corner = UDim.new(0, 20), ZIndex = 1 })

local header = createFrame({ Name = "Header", Parent = panel, Size = UDim2.new(1, 0, 0, 72), Bg = Colors.PanelGlass, BgTransparency = 0.04, Corner = UDim.new(0, 18), ZIndex = 6 })
createText({ Name = "Title", Parent = header, Text = "🛠 Developer Panel", Size = UDim2.new(0.45, 0, 0, 28), Position = UDim2.fromOffset(18, 12), TextSize = 20, Font = Theme.Fonts.Title, Color = Colors.GoldBright, ZIndex = 7 })
createText({ Name = "Subtitle", Parent = header, Text = "Dragon Island Kingdom", Size = UDim2.new(0.45, 0, 0, 18), Position = UDim2.fromOffset(18, 40), TextSize = 12, Font = Theme.Fonts.Body, Color = Colors.TextMuted, ZIndex = 7 })

local headerStats = createFrame({ Name = "HeaderStats", Parent = header, Size = UDim2.new(0.5, -56, 1, -16), Position = UDim2.new(0.45, 0, 0, 8), BgTransparency = 1, ZIndex = 7 })
local headerStatsLayout = Instance.new("UIListLayout")
headerStatsLayout.FillDirection = Enum.FillDirection.Horizontal
headerStatsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
headerStatsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
headerStatsLayout.Padding = UDim.new(0, 8)
headerStatsLayout.Parent = headerStats

local function createHeaderPill(name, defaultText)
	local pill = createFrame({ Name = name, Parent = headerStats, Size = UDim2.fromOffset(0, 28), Bg = Colors.Row, BgTransparency = 0.15, Corner = UDim.new(1, 0), ZIndex = 8 })
	pill.AutomaticSize = Enum.AutomaticSize.X
	padding(pill, 6, 6, 10, 10)
	return createText({ Name = "Value", Parent = pill, Text = defaultText, Size = UDim2.new(0, 0, 0, 16), AutoSize = Enum.AutomaticSize.X, TextSize = 12, Color = Colors.Text, Wrapped = false, ZIndex = 9 })
end

local headerPlayerLabel = createHeaderPill("PlayerPill", player.DisplayName)
local headerIslandLabel = createHeaderPill("IslandPill", "Island: Hub")
local headerEssenceLabel = createHeaderPill("EssencePill", "Essence: 0")
local headerKingdomLabel = createHeaderPill("KingdomPill", "Lv. 1")

local closeButton = createButton({ Name = "CloseButton", Parent = header, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), Bg = Colors.Danger, Text = "✕", TextSize = 16, ZIndex = 10 })

local searchBar = Instance.new("TextBox")
searchBar.Name = "SearchBar"
searchBar.Size = UDim2.new(1, -24, 0, 36)
searchBar.Position = UDim2.fromOffset(12, 80)
searchBar.BackgroundColor3 = Colors.Input
searchBar.BackgroundTransparency = 0.1
searchBar.BorderSizePixel = 0
searchBar.ClearTextOnFocus = false
searchBar.Font = Theme.Fonts.Body
searchBar.PlaceholderText = "Search actions, resources, eggs..."
searchBar.PlaceholderColor3 = Colors.TextMuted
searchBar.Text = ""
searchBar.TextColor3 = Colors.Text
searchBar.TextSize = 14
searchBar.ZIndex = 7
searchBar.Parent = panel
corner(searchBar, UDim.new(0, 10))
stroke(searchBar, Colors.BorderSoft, 1, 0.55)

local body = createFrame({ Name = "Body", Parent = panel, Size = UDim2.new(1, -24, 1, -132), Position = UDim2.fromOffset(12, 124), BgTransparency = 1, ZIndex = 6 })
local sidebar = createFrame({ Name = "Sidebar", Parent = body, Size = UDim2.new(0, 148, 1, 0), Bg = Colors.Sidebar, BgTransparency = 0.05, Corner = UDim.new(0, 14), ZIndex = 7 })
stroke(sidebar, Colors.BorderSoft, 1, 0.6)
local sidebarScroll = Instance.new("ScrollingFrame")
sidebarScroll.Name = "SidebarScroll"
sidebarScroll.Size = UDim2.fromScale(1, 1)
sidebarScroll.BackgroundTransparency = 1
sidebarScroll.BorderSizePixel = 0
sidebarScroll.ScrollBarThickness = 4
sidebarScroll.ScrollBarImageColor3 = Colors.Border
sidebarScroll.CanvasSize = UDim2.fromOffset(0, 0)
sidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebarScroll.Parent = sidebar
padding(sidebarScroll, 8, 8, 8, 8)
local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 8)
sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
sidebarLayout.Parent = sidebarScroll

local contentHost = createFrame({ Name = "ContentHost", Parent = body, Size = UDim2.new(1, -160, 1, 0), Position = UDim2.fromOffset(160, 0), Bg = Colors.PanelGlass, BgTransparency = 0.1, Corner = UDim.new(0, 14), ZIndex = 7 })
stroke(contentHost, Colors.BorderSoft, 1, 0.65)

local function registerSearchRow(row, keywords)
	row:SetAttribute("SearchKeywords", string.lower(keywords or ""))
	table.insert(searchableRows, row)
end

local function applySearchFilter()
	local query = string.lower(searchQuery)
	for _, row in searchableRows do
		if row.Parent then
			row.Visible = query == "" or string.find(row:GetAttribute("SearchKeywords") or "", query, 1, true) ~= nil
		end
	end
end

local function createPage(tabName)
	local page = createFrame({ Name = tabName .. "Page", Parent = contentHost, Size = UDim2.fromScale(1, 1), BgTransparency = 1, Visible = false, ZIndex = 8 })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Colors.Border
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = page
	padding(scroll, 12, 12, 12, 12)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	tabPages[tabName] = { page = page, scroll = scroll }
	return tabPages[tabName]
end

local function createSection(parent, title, layoutOrder)
	local section = createFrame({ Name = title .. "Section", Parent = parent, Size = UDim2.new(1, -4, 0, 0), Bg = Colors.Row, BgTransparency = 0.12, Corner = UDim.new(0, 12), LayoutOrder = layoutOrder, ZIndex = 9 })
	section.AutomaticSize = Enum.AutomaticSize.Y
	padding(section, 12, 12, 12, 12)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section
	createText({ Parent = section, Text = title, Size = UDim2.new(1, 0, 0, 22), TextSize = 15, Color = Colors.Border, LayoutOrder = 1, ZIndex = 10 })
	return section
end

local function createRow(parent, layoutOrder, height)
	local row = createFrame({ Name = "Row", Parent = parent, Size = UDim2.new(1, 0, 0, height or 44), BgTransparency = 1, LayoutOrder = layoutOrder, ZIndex = 10 })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

local function createInput(parent, placeholder, width, layoutOrder, defaultText)
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Size = UDim2.fromOffset(width or 120, 40)
	box.BackgroundColor3 = Colors.Input
	box.BackgroundTransparency = 0.05
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Theme.Fonts.Bold
	box.PlaceholderText = placeholder or ""
	box.PlaceholderColor3 = Colors.TextMuted
	box.Text = defaultText or ""
	box.TextColor3 = Colors.Text
	box.TextSize = 14
	box.LayoutOrder = layoutOrder or 1
	box.ZIndex = 11
	box.Parent = parent
	corner(box, UDim.new(0, 8))
	stroke(box, Colors.BorderSoft, 1, 0.55)
	return box
end

local function normalizeOptions(options)
	local normalized = {}
	for index, entry in options do
		if typeof(entry) == "table" then
			table.insert(normalized, { id = entry.id or entry.name, name = entry.name or entry.id })
		else
			table.insert(normalized, { id = tostring(entry), name = tostring(entry) })
		end
	end
	return normalized
end

local function createDropdown(parent, options, width, layoutOrder)
	options = normalizeOptions(options)
	local selectedIndex = 1
	local button = createButton({ Name = "Dropdown", Parent = parent, Size = UDim2.fromOffset(width or 180, 40), Bg = Colors.Input, TextColor = Colors.Text, Text = options[1] and options[1].name or "Select", TextSize = 13, LayoutOrder = layoutOrder or 1, ZIndex = 11 })
	button.Activated:Connect(function()
		selectedIndex += 1
		if selectedIndex > #options then selectedIndex = 1 end
		button.Text = options[selectedIndex] and options[selectedIndex].name or "Select"
	end)
	return {
		Button = button,
		GetValue = function()
			local entry = options[selectedIndex]
			return entry and entry.id or nil
		end,
	}
end

local function setTab(tabName)
	currentTab = tabName
	savedTab = tabName
	for name, button in tabButtons do
		local active = name == tabName
		button.BackgroundColor3 = active and Colors.Border or Colors.Row
		local label = button:FindFirstChild("Label")
		if label then label.TextColor3 = active and Colors.Text or Colors.TextMuted end
		local icon = button:FindFirstChild("Icon")
		if icon then icon.ImageColor3 = active and Colors.GoldBright or Colors.TextMuted end
	end
	for name, pageData in tabPages do
		pageData.page.Visible = name == tabName
	end
end

for index, tabName in TAB_ORDER do
	local tabButton = Instance.new("TextButton")
	tabButton.Name = tabName .. "Tab"
	tabButton.Size = UDim2.new(1, 0, 0, 52)
	tabButton.BackgroundColor3 = Colors.Row
	tabButton.BorderSizePixel = 0
	tabButton.Text = ""
	tabButton.LayoutOrder = index
	tabButton.ZIndex = 8
	tabButton.Parent = sidebarScroll
	corner(tabButton, UDim.new(0, 10))
	stroke(tabButton, Colors.BorderSoft, 1, 0.65)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(22, 22)
	icon.Position = UDim2.fromOffset(12, 10)
	icon.BackgroundTransparency = 1
	icon.Image = TabIcons[tabName] or Theme.Icons.Settings
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 9
	icon.Parent = tabButton
	createText({ Name = "Label", Parent = tabButton, Text = tabName, Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(40, 0), TextSize = 13, Color = Colors.TextMuted, ZIndex = 9 })
	attachHover(tabButton, Colors.Row)
	tabButton.Activated:Connect(function() setTab(tabName) end)
	tabButtons[tabName] = tabButton
	createPage(tabName)
end

local playerPage = tabPages.Player.scroll
local playerSection = createSection(playerPage, "Player Overview", 1)
local playerInfoRow = createRow(playerSection, 2, 108)
playerInfoRow.Size = UDim2.new(1, 0, 0, 108)
registerSearchRow(playerInfoRow, "player avatar username userid essence kingdom tutorial")
local avatarFrame = createFrame({ Name = "AvatarFrame", Parent = playerInfoRow, Size = UDim2.fromOffset(84, 84), Bg = Colors.Input, Corner = UDim.new(0, 12), LayoutOrder = 1, ZIndex = 11 })
local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.fromScale(1, 1)
avatarImage.BackgroundTransparency = 1
avatarImage.ZIndex = 12
avatarImage.Parent = avatarFrame
task.spawn(function()
	avatarImage.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
local playerInfoCol = createFrame({ Name = "PlayerInfoCol", Parent = playerInfoRow, Size = UDim2.new(1, -100, 0, 96), BgTransparency = 1, LayoutOrder = 2, ZIndex = 11 })
local playerInfoLayout = Instance.new("UIListLayout")
playerInfoLayout.Padding = UDim.new(0, 4)
playerInfoLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerInfoLayout.Parent = playerInfoCol
createText({ Parent = playerInfoCol, Text = player.DisplayName, Size = UDim2.new(1, 0, 0, 22), TextSize = 18, Color = Colors.GoldBright, LayoutOrder = 1, ZIndex = 12, Wrapped = false })
createText({ Parent = playerInfoCol, Text = "UserId: " .. player.UserId, Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Color = Colors.TextMuted, LayoutOrder = 2, ZIndex = 12, Wrapped = false })
local playerEssenceLabel = createText({ Parent = playerInfoCol, Text = "Dragon Essence: 0", Size = UDim2.new(1, 0, 0, 18), TextSize = 13, LayoutOrder = 3, ZIndex = 12, Wrapped = false })
local playerKingdomLabel = createText({ Parent = playerInfoCol, Text = "Kingdom Level: 1", Size = UDim2.new(1, 0, 0, 18), TextSize = 13, LayoutOrder = 4, ZIndex = 12, Wrapped = false })
local playerTutorialLabel = createText({ Parent = playerInfoCol, Text = "Tutorial Step: 1", Size = UDim2.new(1, 0, 0, 18), TextSize = 13, LayoutOrder = 5, ZIndex = 12, Wrapped = false })
local essenceActions = createRow(playerSection, 3, 44)
registerSearchRow(essenceActions, "essence add remove refresh player")
for order, preset in {
	{ label = "+1K Essence", amount = 1000, order = 1 },
	{ label = "+10K Essence", amount = 10000, order = 2 },
	{ label = "+100K Essence", amount = 100000, order = 3 },
	{ label = "+1M Essence", amount = 1000000, order = 4 },
} do
	createButton({ Parent = essenceActions, Size = UDim2.fromOffset(118, 40), Bg = Colors.Success, Text = preset.label, TextSize = 12, LayoutOrder = preset.order, OnClick = function() sendAction("AddEssence", { amount = preset.amount }) end })
end
local essenceUtilityRow = createRow(playerSection, 4, 44)
registerSearchRow(essenceUtilityRow, "remove essence refresh player")
local removeEssenceInput = createInput(essenceUtilityRow, "Amount", 100, 1, "1000")
createButton({ Parent = essenceUtilityRow, Size = UDim2.fromOffset(130, 40), Bg = Colors.Danger, Text = "Remove Essence", LayoutOrder = 2, OnClick = function() sendAction("RemoveEssence", { amount = tonumber(removeEssenceInput.Text) or 1000 }) end })
createButton({ Parent = essenceUtilityRow, Size = UDim2.fromOffset(130, 40), Bg = Colors.Info, Text = "Refresh Player", LayoutOrder = 3, OnClick = function() sendAction("ReloadPlayer") end })

local moderationSection = createSection(playerPage, "Moderation", 2)
local moderationRow = createRow(moderationSection, 2, 44)
registerSearchRow(moderationRow, "kick ban unban moderate player username userid")
local moderationTargetInput = createInput(moderationRow, "Username or UserId", 190, 1, "")
local moderationReasonInput = createInput(moderationRow, "Reason (optional)", 190, 2, "")
local moderationActionRow = createRow(moderationSection, 3, 44)
createButton({
	Parent = moderationActionRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Info, Text = "Kick", LayoutOrder = 1,
	OnClick = function() sendAction("KickPlayer", { target = moderationTargetInput.Text, reason = moderationReasonInput.Text }) end,
})
createButton({
	Parent = moderationActionRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Danger, Text = "Ban", LayoutOrder = 2,
	OnClick = function() sendAction("BanPlayer", { target = moderationTargetInput.Text, reason = moderationReasonInput.Text }) end,
})
createButton({
	Parent = moderationActionRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Success, Text = "Unban", LayoutOrder = 3,
	OnClick = function() sendAction("UnbanPlayer", { target = moderationTargetInput.Text }) end,
})

local resourcesPage = tabPages.Resources.scroll
local resourcesSection = createSection(resourcesPage, "Spawn Resources", 1)
for resourceIndex, resource in adminData.resources or AdminConfig.ResourceTypes do
	local row = createRow(resourcesSection, resourceIndex + 1, 56)
	registerSearchRow(row, (resource.DisplayName or resource.Id) .. " " .. (resource.Id or "") .. " spawn resource")
	local iconFrame = createFrame({ Parent = row, Size = UDim2.fromOffset(40, 40), Bg = Colors.Input, Corner = UDim.new(0, 8), LayoutOrder = 1, ZIndex = 11 })
	local iconImage = Instance.new("ImageLabel")
	iconImage.Size = UDim2.fromOffset(28, 28)
	iconImage.Position = UDim2.fromScale(0.5, 0.5)
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = resource.Icon or Theme.Icons.Crystal
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.ZIndex = 12
	iconImage.Parent = iconFrame
	createText({ Parent = row, Text = resource.DisplayName or resource.Id, Size = UDim2.fromOffset(140, 40), TextSize = 13, LayoutOrder = 2, ZIndex = 11 })
	local amountBox = createInput(row, "Amount", 80, 3, "1")
	createButton({ Parent = row, Size = UDim2.fromOffset(80, 40), Bg = Colors.Info, Text = "Spawn", TextSize = 12, LayoutOrder = 4, OnClick = function() sendAction("GiveResource", { resourceId = resource.Id, amount = tonumber(amountBox.Text) or 1 }) end })
	createButton({ Parent = row, Size = UDim2.fromOffset(80, 40), Bg = Colors.BorderSoft, Text = "Spawn 10", TextSize = 12, LayoutOrder = 5, OnClick = function() sendAction("GiveResource", { resourceId = resource.Id, amount = 10 }) end })
	createButton({ Parent = row, Size = UDim2.fromOffset(80, 40), Bg = Colors.BorderSoft, Text = "Spawn 100", TextSize = 12, LayoutOrder = 6, OnClick = function() sendAction("GiveResource", { resourceId = resource.Id, amount = 100 }) end })
end

local eggsPage = tabPages.Eggs.scroll
local eggsSection = createSection(eggsPage, "Give Eggs", 1)
for eggIndex, egg in adminData.eggTypes or {} do
	local row = createRow(eggsSection, eggIndex + 1, 72)
	registerSearchRow(row, (egg.name or egg.id) .. " egg give")
	row.Size = UDim2.new(1, 0, 0, 72)
	local eggIconFrame = createFrame({ Parent = row, Size = UDim2.fromOffset(56, 56), Bg = Colors.Input, Corner = UDim.new(0, 12), LayoutOrder = 1, ZIndex = 11 })
	local eggIcon = Instance.new("ImageLabel")
	eggIcon.Size = UDim2.fromOffset(44, 44)
	eggIcon.Position = UDim2.fromScale(0.5, 0.5)
	eggIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	eggIcon.BackgroundTransparency = 1
	eggIcon.Image = egg.icon or Theme.Icons.Egg
	eggIcon.ScaleType = Enum.ScaleType.Fit
	eggIcon.ZIndex = 12
	eggIcon.Parent = eggIconFrame
	createText({ Parent = row, Text = egg.name or egg.id, Size = UDim2.new(1, -180, 0, 56), TextSize = 16, Color = Colors.GoldBright, LayoutOrder = 2, ZIndex = 11 })
	createButton({ Parent = row, Size = UDim2.fromOffset(110, 44), Bg = Theme.Colors.Purple, Text = "Give", LayoutOrder = 3, OnClick = function() sendAction("GiveEgg", { eggType = egg.id }) end })
end

local dragonsPage = tabPages.Dragons.scroll
local dragonsSection = createSection(dragonsPage, "Dragon Tools", 1)
local dragonRow = createRow(dragonsSection, 2, 44)
registerSearchRow(dragonRow, "dragon give spawn test rarity type remove")
local dragonTypeDropdown = createDropdown(dragonRow, adminData.dragonTypes or {}, 150, 1)
local rarityDropdown = createDropdown(dragonRow, adminData.rarities or {}, 120, 2)
local dragonLevelInput = createInput(dragonRow, "Level", 70, 3, "1")
local dragonEvoInput = createInput(dragonRow, "Evo", 60, 4, "0")
local dragonActions = createRow(dragonsSection, 3, 44)
registerSearchRow(dragonActions, "give spawn test dragon remove all")
createButton({ Parent = dragonActions, Size = UDim2.fromOffset(130, 40), Bg = Colors.Success, Text = "Give Dragon", LayoutOrder = 1, OnClick = function() sendAction("GiveDragon", { dragonType = dragonTypeDropdown:GetValue(), rarity = rarityDropdown:GetValue(), level = tonumber(dragonLevelInput.Text) or 1, evolutionLevel = tonumber(dragonEvoInput.Text) or 0 }) end })
createButton({ Parent = dragonActions, Size = UDim2.fromOffset(150, 40), Bg = Theme.Colors.Purple, Text = "Spawn Test Dragon", LayoutOrder = 2, OnClick = function() sendAction("SpawnTestDragon", { dragonType = dragonTypeDropdown:GetValue(), rarity = rarityDropdown:GetValue() }) end })
createButton({ Parent = dragonActions, Size = UDim2.fromOffset(130, 40), Bg = Colors.Danger, Text = "Remove Dragon", LayoutOrder = 3, OnClick = function() sendAction("RemoveDragon", { dragonType = dragonTypeDropdown:GetValue(), rarity = rarityDropdown:GetValue() }) end })
createButton({ Parent = dragonActions, Size = UDim2.fromOffset(150, 40), Bg = Colors.Danger, Text = "Remove All Dragons", LayoutOrder = 4, OnClick = function() sendAction("RemoveAllDragons") end })

local worldPage = tabPages.World.scroll
local worldSection = createSection(worldPage, "Island Travel", 1)
local worldRow = createRow(worldSection, 2, 44)
registerSearchRow(worldRow, "island teleport unlock world hub crystal")
local islandDropdown = createDropdown(worldRow, adminData.islands or {}, 220, 1)
createButton({ Parent = worldRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Info, Text = "Teleport", LayoutOrder = 2, OnClick = function() sendAction("TeleportIsland", { islandId = islandDropdown:GetValue() }) end })
createButton({ Parent = worldRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Success, Text = "Unlock", LayoutOrder = 3, OnClick = function()
	local id = islandDropdown:GetValue()
	if id == "Hub" or id == "MainIsland" then showNotification("Hub and Main Island are always available", "error") return end
	sendAction("UnlockIsland", { islandId = id })
end })
local worldRow2 = createRow(worldSection, 3, 44)
registerSearchRow(worldRow2, "unlock all respawn spawn crystal nodes")
createButton({ Parent = worldRow2, Size = UDim2.fromOffset(150, 40), Bg = Colors.Gold, Text = "Unlock All", LayoutOrder = 1, OnClick = function() sendAction("UnlockAllIslands") end })
createButton({ Parent = worldRow2, Size = UDim2.fromOffset(170, 40), Bg = Colors.Info, Text = "Respawn Crystal Nodes", LayoutOrder = 2, OnClick = function() sendAction("RespawnCrystalNodes") end })
createButton({ Parent = worldRow2, Size = UDim2.fromOffset(170, 40), Bg = Colors.BorderSoft, Text = "Spawn Crystal Nodes", LayoutOrder = 3, OnClick = function() sendAction("SpawnCrystalNodes", { count = 5 }) end })

local buildingsPage = tabPages.Buildings.scroll
local buildingsSection = createSection(buildingsPage, "Building Levels", 1)
local buildingRow = createRow(buildingsSection, 2, 44)
registerSearchRow(buildingRow, "building level set max nest academy workshop storage hatchery")
local buildingDropdown = createDropdown(buildingRow, adminData.buildings or {}, 200, 1)
local buildingLevelInput = createInput(buildingRow, "Level", 80, 2, tostring(adminData.maxBuildingLevel or 5))
createButton({ Parent = buildingRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Gold, Text = "Set Level", LayoutOrder = 3, OnClick = function() sendAction("SetBuildingLevel", { buildingId = buildingDropdown:GetValue(), level = tonumber(buildingLevelInput.Text) or 1 }) end })
createButton({ Parent = buildingRow, Size = UDim2.fromOffset(110, 40), Bg = Colors.Success, Text = "Max Level", LayoutOrder = 4, OnClick = function() sendAction("SetBuildingMaxLevel", { buildingId = buildingDropdown:GetValue() }) end })

local eventsPage = tabPages.Events.scroll
local eventsSection = createSection(eventsPage, "Global Events", 1)

local eventsStatusRow = createRow(eventsSection, 2, 28)
local eventsStatus = createText({
	Name = "EventsStatus", Parent = eventsStatusRow, Text = "No event active",
	Size = UDim2.new(1, 0, 1, 0), TextSize = 14, Color = Colors.TextMuted,
	XAlign = Enum.TextXAlignment.Left, ZIndex = 11,
})

local eventsRow = createRow(eventsSection, 3, 44)
registerSearchRow(eventsRow, "event luck essence boost start end global promotion")
local eventTypeDropdown = createDropdown(eventsRow, adminData.eventTypes or {}, 160, 1)
local eventMultiplierInput = createInput(eventsRow, "Multiplier (e.g. 2)", 150, 2, "2")
local eventDurationInput = createInput(eventsRow, "Hours (e.g. 24)", 140, 3, "24")

local eventsActionRow = createRow(eventsSection, 4, 44)
createButton({
	Parent = eventsActionRow, Size = UDim2.fromOffset(150, 40), Bg = Colors.Success, Text = "Start Event", LayoutOrder = 1,
	OnClick = function()
		sendAction("StartGlobalEvent", {
			eventType = eventTypeDropdown:GetValue(),
			multiplier = tonumber(eventMultiplierInput.Text) or 2,
			durationHours = tonumber(eventDurationInput.Text) or 24,
		})
	end,
})
createButton({
	Parent = eventsActionRow, Size = UDim2.fromOffset(150, 40), Bg = Colors.Danger, Text = "End Event Now", LayoutOrder = 2,
	OnClick = function() sendAction("EndGlobalEvent") end,
})

local function formatEventStatus(event)
	if typeof(event) ~= "table" then
		return "No event active"
	end
	local remaining = math.max(0, math.floor((event.endsAt or 0) - os.time()))
	local hours = math.floor(remaining / 3600)
	local minutes = math.floor((remaining % 3600) / 60)
	return string.format("%s active - x%.2f - %dh %dm left", tostring(event.label or event.type), tonumber(event.multiplier) or 1, hours, minutes)
end

eventsStatus.Text = formatEventStatus(adminData.activeEvent)

task.spawn(function()
	while eventsStatus.Parent do
		if adminData.activeEvent then
			eventsStatus.Text = formatEventStatus(adminData.activeEvent)
		end
		task.wait(30)
	end
end)

local progressPage = tabPages.Progress.scroll
local progressSection = createSection(progressPage, "Progress Tools", 1)
local progressRow = createRow(progressSection, 2, 44)
registerSearchRow(progressRow, "tutorial quest complete reset refresh ui")
createButton({ Parent = progressRow, Size = UDim2.fromOffset(150, 40), Bg = Colors.Success, Text = "Complete Tutorial", LayoutOrder = 1, OnClick = function() sendAction("CompleteTutorial") end })
createButton({ Parent = progressRow, Size = UDim2.fromOffset(140, 40), Bg = Colors.Danger, Text = "Reset Tutorial", LayoutOrder = 2, OnClick = function() sendAction("ResetTutorial") end })
createButton({ Parent = progressRow, Size = UDim2.fromOffset(150, 40), Bg = Colors.Success, Text = "Complete Quests", LayoutOrder = 3, OnClick = function() sendAction("CompleteQuests") end })
createButton({ Parent = progressRow, Size = UDim2.fromOffset(120, 40), Bg = Colors.Info, Text = "Refresh UI", LayoutOrder = 4, OnClick = function() sendAction("RefreshUI") end })

local savePage = tabPages.Save.scroll
local saveSection = createSection(savePage, "Player Save", 1)
local saveRow = createRow(saveSection, 2, 44)
registerSearchRow(saveRow, "save reload wipe player data")
createButton({ Parent = saveRow, Size = UDim2.fromOffset(130, 40), Bg = Colors.Gold, Text = "Save Player", LayoutOrder = 1, OnClick = function() sendAction("SavePlayer") end })
createButton({ Parent = saveRow, Size = UDim2.fromOffset(130, 40), Bg = Colors.Info, Text = "Reload Player", LayoutOrder = 2, OnClick = function() sendAction("ReloadPlayer") end })
createButton({ Parent = saveRow, Size = UDim2.fromOffset(130, 40), Bg = Colors.Danger, Text = "Wipe Save", LayoutOrder = 3, OnClick = function() confirmWipe.Visible = true end })

local confirmWipe = createFrame({ Name = "ConfirmWipe", Parent = panel, Size = UDim2.fromOffset(360, 180), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Bg = Colors.PanelGlass, BgTransparency = 0.02, Corner = UDim.new(0, 14), Visible = false, ZIndex = 40 })
stroke(confirmWipe, Colors.Danger, 2, 0.15)
createText({ Parent = confirmWipe, Text = "Wipe player save?", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 16), TextSize = 18, Color = Colors.GoldBright, ZIndex = 41 })
createText({ Parent = confirmWipe, Text = "This permanently deletes all saved progress for this account.", Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 52), TextSize = 13, Color = Colors.TextMuted, ZIndex = 41 })
local confirmRow = createRow(confirmWipe, 1, 44)
confirmRow.Position = UDim2.new(0, 12, 1, -56)
confirmRow.Size = UDim2.new(1, -24, 0, 44)
createButton({ Parent = confirmRow, Size = UDim2.new(0.5, -6, 1, 0), Bg = Colors.Row, Text = "Cancel", LayoutOrder = 1, ZIndex = 41, OnClick = function() confirmWipe.Visible = false end })
createButton({ Parent = confirmRow, Size = UDim2.new(0.5, -6, 1, 0), Bg = Colors.Danger, Text = "Confirm Wipe", LayoutOrder = 2, ZIndex = 41, OnClick = function() confirmWipe.Visible = false; sendAction("WipeSave") end })

local debugPage = tabPages.Debug.scroll
local debugSection = createSection(debugPage, "Live Debug", 1)
local debugLabels = {}
for index, field in {
	{ key = "island", label = "Current Island" },
	{ key = "zone", label = "Current Zone" },
	{ key = "essence", label = "Dragon Essence" },
	{ key = "kingdom", label = "Kingdom Level" },
	{ key = "tutorial", label = "Tutorial Step" },
	{ key = "quests", label = "Quest Count" },
	{ key = "dragons", label = "Dragon Count" },
	{ key = "crystals", label = "Crystal Count" },
	{ key = "fps", label = "FPS" },
	{ key = "ping", label = "Ping" },
} do
	local row = createRow(debugSection, index + 1, 34)
	createText({ Parent = row, Text = field.label, Size = UDim2.fromOffset(160, 30), TextSize = 13, Color = Colors.TextMuted, LayoutOrder = 1, ZIndex = 11 })
	debugLabels[field.key] = createText({ Parent = row, Text = "—", Size = UDim2.new(1, -170, 0, 30), TextSize = 13, Color = Colors.Text, LayoutOrder = 2, ZIndex = 11 })
end

local function countOwnedModels(folderName)
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then return 0 end
	local total = 0
	for _, child in folder:GetChildren() do
		if child:GetAttribute("OwnerUserId") == player.UserId then total += 1 end
	end
	return total
end

local function refreshHeaderAndPlayerLabels()
	local essence = player:GetAttribute("DragonEssence") or 0
	local kingdom = player:GetAttribute("KingdomLevel") or 1
	local tutorial = player:GetAttribute("TutorialStep") or 1
	local zone = player:GetAttribute("CurrentZone") or "Hub"
	headerPlayerLabel.Text = player.DisplayName
	headerIslandLabel.Text = "Island: " .. tostring(zone)
	headerEssenceLabel.Text = "Essence: " .. Theme.formatCompact(essence)
	headerKingdomLabel.Text = "Lv. " .. tostring(kingdom)
	playerEssenceLabel.Text = "Dragon Essence: " .. Theme.formatCompact(essence)
	playerKingdomLabel.Text = "Kingdom Level: " .. tostring(kingdom)
	playerTutorialLabel.Text = "Tutorial Step: " .. tostring(tutorial)
	debugLabels.island.Text = tostring(zone)
	debugLabels.zone.Text = tostring(zone)
	debugLabels.essence.Text = Theme.formatCompact(essence)
	debugLabels.kingdom.Text = tostring(kingdom)
	debugLabels.tutorial.Text = tostring(tutorial)
	debugLabels.quests.Text = tostring(player:GetAttribute("QuestEggs") or 0)
	debugLabels.dragons.Text = tostring(countOwnedModels("DragonWorkers"))
	debugLabels.crystals.Text = tostring(countOwnedModels("ResourceNodes"))
end

player:GetAttributeChangedSignal("DragonEssence"):Connect(refreshHeaderAndPlayerLabels)
player:GetAttributeChangedSignal("KingdomLevel"):Connect(refreshHeaderAndPlayerLabels)
player:GetAttributeChangedSignal("TutorialStep"):Connect(refreshHeaderAndPlayerLabels)
player:GetAttributeChangedSignal("CurrentZone"):Connect(refreshHeaderAndPlayerLabels)
refreshHeaderAndPlayerLabels()

local debugAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if not isOpen or currentTab ~= "Debug" then return end
	debugAccumulator += dt
	if debugAccumulator < 0.25 then return end
	debugAccumulator = 0
	debugLabels.fps.Text = tostring(math.floor(1 / math.max(dt, 0.001)))
	debugLabels.ping.Text = string.format("%d ms", math.floor(player:GetNetworkPing() * 1000 + 0.5))
end)

local function tweenOpenPanel()
	dim.Visible = true
	dim.BackgroundTransparency = 1
	panel.Visible = true
	panel.BackgroundTransparency = 0.2
	panelScale.Scale = 0.95
	panel.Position = savedPanelPosition
	TweenService:Create(dim, TweenInfo.new(0.22), { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(blur, TweenInfo.new(0.22), { Size = 18 }):Play()
	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.06 }):Play()
	TweenService:Create(panelScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function tweenClosePanel(onDone)
	TweenService:Create(dim, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(blur, TweenInfo.new(0.18), { Size = 0 }):Play()
	local panelTween = TweenService:Create(panel, TweenInfo.new(0.18), { BackgroundTransparency = 0.25 })
	TweenService:Create(panelScale, TweenInfo.new(0.18), { Scale = 0.95 }):Play()
	panelTween:Play()
	panelTween.Completed:Connect(function()
		panel.Visible = false
		dim.Visible = false
		confirmWipe.Visible = false
		if onDone then onDone() end
	end)
end

local function setOpen(open)
	isOpen = open
	if open then
		Theme.setModalLock(playerGui, true, "DevAdminPanel")
		Theme.raiseModalGui(screenGui)
		setTab(savedTab)
		refreshHeaderAndPlayerLabels()
		tweenOpenPanel()
	else
		tweenClosePanel(function()
			Theme.setModalLock(playerGui, false, "DevAdminPanel")
			Theme.restoreModalGui(screenGui)
		end)
	end
end

closeButton.Activated:Connect(function() setOpen(false) end)

local dragging = false
local dragStart
local startPos
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = panel.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position - dragStart
		local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		panel.Position = newPos
		savedPanelPosition = newPos
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

searchBar:GetPropertyChangedSignal("Text"):Connect(function()
	searchQuery = searchBar.Text
	applySearchFilter()
end)

AdminResult.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	showNotification(payload.message or "Done", payload.success and "success" or "error")
	refreshHeaderAndPlayerLabels()
end)

local tabIndex = 1
for index, tabName in TAB_ORDER do
	if tabName == savedTab then tabIndex = index break end
end
setTab(savedTab)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == AdminConfig.GetToggleKey() then
		if gameProcessed and not isOpen then return end
		setOpen(not isOpen)
		return
	end
	if not isOpen then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if confirmWipe.Visible then confirmWipe.Visible = false else setOpen(false) end
		return
	end
	if input.KeyCode == Enum.KeyCode.Up then
		tabIndex = math.max(1, tabIndex - 1)
		setTab(TAB_ORDER[tabIndex])
	elseif input.KeyCode == Enum.KeyCode.Down then
		tabIndex = math.min(#TAB_ORDER, tabIndex + 1)
		setTab(TAB_ORDER[tabIndex])
	end
end)
