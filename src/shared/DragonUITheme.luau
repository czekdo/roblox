local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Theme = {}

Theme.Colors = {
	NavyDeep = Color3.fromRGB(18, 26, 48),
	Navy = Color3.fromRGB(28, 38, 68),
	NavyMid = Color3.fromRGB(34, 44, 72),
	NavyEdge = Color3.fromRGB(52, 64, 98),
	Slate = Color3.fromRGB(58, 72, 108),
	SlateLight = Color3.fromRGB(72, 88, 128),
	Stone = Color3.fromRGB(34, 44, 72),
	StoneDark = Color3.fromRGB(28, 38, 68),
	StoneDeep = Color3.fromRGB(22, 30, 54),
	Panel = Color3.fromRGB(22, 30, 54),
	PanelInner = Color3.fromRGB(42, 54, 88),
	Gold = Color3.fromRGB(218, 178, 72),
	GoldBright = Color3.fromRGB(255, 214, 102),
	GoldDark = Color3.fromRGB(168, 128, 48),
	Crystal = Color3.fromRGB(72, 162, 255),
	CrystalGlow = Color3.fromRGB(120, 200, 255),
	CrystalSoft = Color3.fromRGB(100, 175, 255),
	Text = Color3.fromRGB(235, 240, 255),
	TextMuted = Color3.fromRGB(148, 162, 192),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextGold = Color3.fromRGB(255, 220, 140),
	Success = Color3.fromRGB(72, 190, 120),
	SuccessDark = Color3.fromRGB(52, 150, 95),
	Danger = Color3.fromRGB(220, 88, 98),
	DangerDark = Color3.fromRGB(175, 62, 72),
	Dim = Color3.fromRGB(8, 12, 24),
	Nav = Color3.fromRGB(42, 54, 88),
	NavActive = Color3.fromRGB(72, 162, 255),
	Purple = Color3.fromRGB(155, 95, 220),
	Gem = Color3.fromRGB(180, 95, 255),
	TopBarCapsule = Color3.fromRGB(34, 44, 72),
	TopBarCapsuleEdge = Color3.fromRGB(52, 64, 98),
}

Theme.Icons = {
	Crystal = "rbxassetid://73150429062000",
	Diamond = "rbxassetid://75581768563141",
	Premium = "rbxassetid://78918235954057",
	Egg = "rbxassetid://113316632422703",
	Dragon = "rbxassetid://73214946386499",
	Merge = "rbxassetid://71704954911252",
	Book = "rbxassetid://117316658726625",
	Hammer = "rbxassetid://95064026158349",
	House = "rbxassetid://101953044632807",
	Scroll = "rbxassetid://76733867334368",
	Settings = "rbxassetid://119570973950437",
	Mail = "rbxassetid://106567385913035",
	Gift = "rbxassetid://122416766679510",
	Trophy = "rbxassetid://77830885604568",
	Star = "rbxassetid://112684829478873",
	Close = "rbxassetid://109798318511632",
	Plus = "rbxassetid://127726919558379",
	Crown = "rbxassetid://78843852703854",
	Backpack = "rbxassetid://118915534669949",
	Upgrade = "rbxassetid://124300905660565",
	Rebirth = "rbxassetid://80234316052758",
}

Theme.Rarity = {
	Common = Color3.fromRGB(168, 175, 190),
	Rare = Color3.fromRGB(72, 145, 255),
	Epic = Color3.fromRGB(155, 85, 235),
	Legendary = Color3.fromRGB(255, 185, 55),
	Mythic = Color3.fromRGB(255, 85, 195),
	Ancient = Color3.fromRGB(255, 75, 55),
}

Theme.Fonts = {
	Title = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Regular = Enum.Font.Gotham,
}

Theme.Corner = {
	Small = UDim.new(0, 8),
	Medium = UDim.new(0, 12),
	Large = UDim.new(0, 16),
	XL = UDim.new(0, 20),
	Pill = UDim.new(0.5, 0),
}

Theme.MobileScale = UserInputService.TouchEnabled and 0.88 or 1

Theme.SafeArea = {
	Edge = UserInputService.TouchEnabled and 16 or 12,
	TopExtra = 8,
	NavColumnWidth = 68,
	NotificationHeight = 148,
	BottomExtra = UserInputService.TouchEnabled and 16 or 12,
}

Theme.ModalDisplayOrder = 55
Theme.HudDisplayOrder = 5
Theme.NavDisplayOrder = 25

local modalSuppressedGuis = {}

local ALWAYS_ALLOWED_GUIS = {
	DragonUIUXController = true,
	KingdomHUD = true,
	DragonTutorialUI = true,
	PortalTravelFade = true,
	EggHatchCinematicUI = true,
}

function Theme.hideDim(dim)
	if not dim or not dim:IsA("GuiObject") then return end
	dim.Visible = false
	dim.Active = false
	dim.BackgroundTransparency = 1
end

function Theme.showDim(dim)
	if not dim or not dim:IsA("GuiObject") then return end
	dim.Visible = true
	dim.Active = true
	dim.BackgroundTransparency = 0.5
end

function Theme.cleanupAllModalOverlays(playerGui)
	if not playerGui then return end
	for _, gui in playerGui:GetChildren() do
		if not gui:IsA("ScreenGui") then continue end
		for _, child in gui:GetDescendants() do
			if child.Name == "DimBackground" and child:IsA("GuiObject") then
				Theme.hideDim(child)
			elseif child.Name == "Dim" and child:IsA("GuiObject") and child.Size == UDim2.fromScale(1, 1) then
				Theme.hideDim(child)
			end
		end
	end
end

function Theme.releaseAllInput(playerGui)
	Theme.cleanupAllModalOverlays(playerGui)
	Theme.setModalLock(playerGui, false)
	pcall(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)
	pcall(function() GuiService.SelectedObject = nil end)
	if _G.DragonIslandResetModalRegistry then _G.DragonIslandResetModalRegistry() end
	if _G.DragonIslandSetTutorialSuppressed then _G.DragonIslandSetTutorialSuppressed(false) end
	if _G.DragonIslandSetWorldPanelsSuppressed then _G.DragonIslandSetWorldPanelsSuppressed(false) end
end

function Theme.closeModalWindow(screenGui, panel, dim, onComplete)
	if dim then dim.Active = false end
	if panel and panel:IsA("GuiObject") and panel.Visible then
		Theme.tweenClose(panel, dim, function()
			if screenGui and screenGui:IsA("ScreenGui") then
				screenGui.Enabled = false
				Theme.restoreModalGui(screenGui)
			end
			if onComplete then onComplete() end
		end)
	else
		if dim then Theme.hideDim(dim) end
		if panel and panel:IsA("GuiObject") then panel.Visible = false end
		if screenGui and screenGui:IsA("ScreenGui") then
			screenGui.Enabled = false
			Theme.restoreModalGui(screenGui)
		end
		if onComplete then onComplete() end
	end
end

function Theme.setModalLock(playerGui, locked, allowedNames)
	if not playerGui then return end
	local allowed = table.clone(ALWAYS_ALLOWED_GUIS)
	if typeof(allowedNames) == "table" then
		for _, name in allowedNames do allowed[name] = true end
	elseif typeof(allowedNames) == "string" then
		allowed[allowedNames] = true
	end
	for _, gui in playerGui:GetChildren() do
		if not gui:IsA("ScreenGui") then continue end
		local name = gui.Name
		if allowed[name] or gui:GetAttribute("BypassTutorialLockout") == true then continue end
		if locked then
			if modalSuppressedGuis[gui] == nil then modalSuppressedGuis[gui] = gui.Enabled end
			if gui:GetAttribute("ModalBaseDisplayOrder") == nil then
				gui:SetAttribute("ModalBaseDisplayOrder", gui.DisplayOrder)
			end
			gui.Enabled = false
		else
			local wasEnabled = modalSuppressedGuis[gui]
			if wasEnabled ~= nil then
				gui.Enabled = wasEnabled
				modalSuppressedGuis[gui] = nil
			end
			local baseOrder = gui:GetAttribute("ModalBaseDisplayOrder")
			if typeof(baseOrder) == "number" then gui.DisplayOrder = baseOrder end
		end
	end
	if not locked then modalSuppressedGuis = {} end
	if _G.DragonIslandSetTutorialSuppressed then _G.DragonIslandSetTutorialSuppressed(locked) end
	if _G.DragonIslandSetWorldPanelsSuppressed then _G.DragonIslandSetWorldPanelsSuppressed(locked) end
end

function Theme.raiseModalGui(screenGui)
	if screenGui and screenGui:IsA("ScreenGui") then
		if screenGui:GetAttribute("ModalBaseDisplayOrder") == nil then
			screenGui:SetAttribute("ModalBaseDisplayOrder", screenGui.DisplayOrder)
		end
		screenGui.Enabled = true
		screenGui.DisplayOrder = Theme.ModalDisplayOrder
	end
end

function Theme.restoreModalGui(screenGui)
	if screenGui and screenGui:IsA("ScreenGui") then
		local baseOrder = screenGui:GetAttribute("ModalBaseDisplayOrder")
		if typeof(baseOrder) == "number" then screenGui.DisplayOrder = baseOrder end
	end
end

function Theme.applyScreenSafeArea(screenGui)
	screenGui.IgnoreGuiInset = false
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end

function Theme.getGuiInset()
	local inset = GuiService:GetGuiInset()
	return Vector2.new(inset.X, inset.Y)
end

function Theme.makeInputTransparent(gui)
	if gui and gui:IsA("GuiObject") then
		gui.Active = false
		gui.Selectable = false
	end
	return gui
end

function Theme.formatCompact(value)
	local n = tonumber(value) or 0
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n >= 1e9 then return sign .. string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then return sign .. string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then return sign .. string.format("%.0fK", n / 1e3)
	elseif n >= 1e3 then return sign .. string.format("%.1fK", n / 1e3) end
	return sign .. tostring(math.floor(n))
end

function Theme.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.Corner.Medium
	c.Parent = parent
	return c
end

function Theme.stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.Gold
	s.Thickness = thickness or 2
	s.Transparency = transparency or 0.15
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.padding(parent, t, b, l, r)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, t or 12)
	p.PaddingBottom = UDim.new(0, b or t or 12)
	p.PaddingLeft = UDim.new(0, l or t or 12)
	p.PaddingRight = UDim.new(0, r or l or t or 12)
	p.Parent = parent
	return p
end

function Theme.createFrame(props)
	local f = Instance.new(props.ClassName or "Frame")
	f.Name = props.Name or "Frame"
	f.Size = props.Size or UDim2.fromOffset(100, 100)
	f.Position = props.Position or UDim2.fromScale(0, 0)
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	f.BackgroundColor3 = props.Bg or Theme.Colors.PanelInner
	f.BackgroundTransparency = props.BgTransparency or 0
	f.BorderSizePixel = 0
	f.Visible = props.Visible ~= false
	f.ZIndex = props.ZIndex or 1
	if props.ClipsDescendants ~= nil then f.ClipsDescendants = props.ClipsDescendants end
	if props.Parent then f.Parent = props.Parent end
	if props.LayoutOrder then f.LayoutOrder = props.LayoutOrder end
	if props.Corner then Theme.corner(f, props.Corner) end
	if props.Stroke then Theme.stroke(f, props.StrokeColor, props.StrokeThickness, props.StrokeTransparency) end
	return f
end

function Theme.createText(props)
	local l = Instance.new("TextLabel")
	l.Name = props.Name or "Label"
	l.Size = props.Size or UDim2.fromScale(1, 0)
	l.Position = props.Position or UDim2.fromOffset(0, 0)
	l.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	l.BackgroundTransparency = props.BgTransparency or 1
	l.BackgroundColor3 = props.Bg or Theme.Colors.PanelInner
	l.Font = props.Font or Theme.Fonts.Bold
	l.Text = props.Text or ""
	l.TextColor3 = props.Color or Theme.Colors.Text
	l.TextSize = props.TextSize or 14
	l.TextWrapped = props.Wrapped ~= false
	l.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	l.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	if props.Truncate then l.TextTruncate = props.Truncate end
	if props.LayoutOrder then l.LayoutOrder = props.LayoutOrder end
	l.ZIndex = props.ZIndex or 2
	l.Visible = props.Visible ~= false
	if props.AutoSize then l.AutomaticSize = props.AutoSize end
	l.Parent = props.Parent
	if props.Corner then Theme.corner(l, props.Corner) end
	if props.Stroke then Theme.stroke(l, props.StrokeColor, props.StrokeThickness, props.StrokeTransparency) end
	return l
end

function Theme.createButton(props)
	local baseBg = props.Bg or Theme.Colors.Success
	local b = Instance.new("TextButton")
	b.Name = props.Name or "Button"
	b.Size = props.Size or UDim2.fromOffset(120, 44)
	b.Position = props.Position or UDim2.fromOffset(0, 0)
	b.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	b.BackgroundColor3 = baseBg
	b.BorderSizePixel = 0
	b.AutoButtonColor = props.AutoButtonColor ~= false
	b.Font = props.Font or Theme.Fonts.Bold
	b.Text = props.Text or ""
	b.TextColor3 = props.TextColor or Theme.Colors.TextLight
	b.TextSize = props.TextSize or 15
	b.TextWrapped = props.Wrapped ~= false
	if props.LayoutOrder then b.LayoutOrder = props.LayoutOrder end
	b.ZIndex = props.ZIndex or 2
	b.Parent = props.Parent
	Theme.corner(b, props.Corner or Theme.Corner.Medium)
	if props.Stroke ~= false then
		Theme.stroke(b, props.StrokeColor or Theme.Colors.GoldBright, props.StrokeThickness or 1.5, props.StrokeTransparency or 0.25)
	end
	if props.OnClick then b.Activated:Connect(props.OnClick) end
	if props.Hover ~= false then Theme.attachHover(b, baseBg) end
	if props.Bounce ~= false then Theme.attachBounce(b) end
	return b
end

function Theme.createSecondaryButton(props)
	props.Bg = props.Bg or Theme.Colors.NavyEdge
	props.TextColor = props.TextColor or Theme.Colors.Text
	return Theme.createButton(props)
end

function Theme.createIconButton(props)
	local baseBg = props.Bg or Theme.Colors.TopBarCapsule
	local b = Instance.new("ImageButton")
	b.Name = props.Name or "IconButton"
	b.Size = props.Size or UDim2.fromOffset(44, 44)
	b.Position = props.Position or UDim2.fromOffset(0, 0)
	b.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	b.BackgroundColor3 = baseBg
	b.BorderSizePixel = 0
	b.Image = props.Image or ""
	b.ScaleType = Enum.ScaleType.Fit
	b.ImageTransparency = props.ImageTransparency or 0
	if props.LayoutOrder then b.LayoutOrder = props.LayoutOrder end
	b.ZIndex = props.ZIndex or 2
	b.Parent = props.Parent
	Theme.corner(b, props.Corner or Theme.Corner.Medium)
	if props.Stroke then Theme.stroke(b, props.StrokeColor or Theme.Colors.Gold, 1.5, props.StrokeTransparency or 0.3) end
	if props.OnClick then b.Activated:Connect(props.OnClick) end
	Theme.attachHover(b, baseBg)
	Theme.attachBounce(b)
	if props.Badge then
		Theme.createText({
			Name = "Badge", Parent = b, Size = UDim2.fromOffset(18, 18),
			Position = UDim2.new(1, -4, 0, -4), AnchorPoint = Vector2.new(1, 0),
			Bg = Theme.Colors.Danger, BgTransparency = 0, Corner = Theme.Corner.Pill,
			Text = props.Badge, Color = Theme.Colors.TextLight, TextSize = 11,
			XAlign = Enum.TextXAlignment.Center, ZIndex = b.ZIndex + 2,
		})
	end
	return b
end

function Theme.createCloseButton(parent, onClose, zIndex)
	return Theme.createIconButton({
		Name = "CloseButton", Parent = parent,
		Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -10, 0, 10),
		AnchorPoint = Vector2.new(1, 0), Bg = Theme.Colors.Danger,
		Image = Theme.Icons.Close, Corner = Theme.Corner.Medium, ZIndex = zIndex or 10,
		OnClick = onClose, Stroke = true, StrokeColor = Theme.Colors.DangerDark,
	})
end

function Theme.createDim(parent, zIndex)
	local dim = Theme.createFrame({
		Name = "DimBackground", Parent = parent, ClassName = "Frame",
		Size = UDim2.fromScale(1, 1), Bg = Theme.Colors.Dim, BgTransparency = 0.5,
		Visible = false, ZIndex = zIndex or 1,
	})
	dim.Active = false
	dim.Selectable = false
	return dim
end

function Theme.addDecorativeCorners(parent, zIndex)
	local corners = {
		{ pos = UDim2.fromOffset(6, 6), anchor = Vector2.new(0, 0) },
		{ pos = UDim2.new(1, -6, 0, 6), anchor = Vector2.new(1, 0) },
		{ pos = UDim2.new(0, 6, 1, -6), anchor = Vector2.new(0, 1) },
		{ pos = UDim2.new(1, -6, 1, -6), anchor = Vector2.new(1, 1) },
	}
	for i, c in corners do
		local dot = Theme.createFrame({
			Name = "CornerAccent" .. i, Parent = parent,
			Size = UDim2.fromOffset(10, 10), Position = c.pos, AnchorPoint = c.anchor,
			Bg = Theme.Colors.GoldBright, Corner = Theme.Corner.Pill, ZIndex = zIndex or 3,
		})
		dot.BackgroundTransparency = 0.35
	end
end

function Theme.createPanel(props)
	local panel = Theme.createFrame({
		Name = props.Name or "Panel", Parent = props.Parent,
		Size = props.Size or UDim2.fromOffset(800, 560),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Bg = props.Bg or Theme.Colors.NavyDeep, Corner = props.Corner or Theme.Corner.XL,
		Visible = props.Visible ~= false, ZIndex = props.ZIndex or 5,
	})
	Theme.stroke(panel, props.StrokeColor or Theme.Colors.Gold, props.StrokeThickness or 2.5, props.StrokeTransparency or 0.12)
	Theme.createFrame({
		Name = "PanelGradient", Parent = panel,
		Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3),
		Bg = Theme.Colors.NavyMid, Corner = Theme.Corner.Large, ZIndex = 1,
	})
	Theme.addDecorativeCorners(panel, 4)
	local scale = Instance.new("UIScale")
	scale.Name = "PanelScale"
	scale.Scale = props.Scale or Theme.MobileScale
	scale.Parent = panel
	Theme.addCrystalShine(panel)
	return panel, scale
end

function Theme.createWindowHeader(parent, title, subtitle, zIndex)
	zIndex = zIndex or 8
	local header = Theme.createFrame({
		Name = "WindowHeader", Parent = parent,
		Size = UDim2.new(1, -20, 0, subtitle and 56 or 44),
		Position = UDim2.fromOffset(10, 8), BgTransparency = 1, ZIndex = zIndex,
	})
	Theme.createText({
		Name = "Title", Parent = header, Text = title,
		Size = UDim2.new(1, -50, 0, 28), Position = UDim2.fromOffset(8, 4),
		TextSize = 22, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight, ZIndex = zIndex + 1,
	})
	if subtitle then
		Theme.createText({
			Name = "Subtitle", Parent = header, Text = subtitle,
			Size = UDim2.new(1, -50, 0, 18), Position = UDim2.fromOffset(8, 32),
			TextSize = 12, Font = Theme.Fonts.Regular, Color = Theme.Colors.TextMuted, ZIndex = zIndex + 1,
		})
	end
	Theme.createFrame({
		Name = "HeaderLine", Parent = header,
		Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
		Bg = Theme.Colors.Gold, BgTransparency = 0.4, Corner = Theme.Corner.Pill, ZIndex = zIndex,
	})
	return header
end

function Theme.createContentArea(parent, size, position, zIndex)
	local area = Theme.createFrame({
		Name = "ContentArea", Parent = parent, Size = size, Position = position,
		Bg = Theme.Colors.Navy, Corner = Theme.Corner.Large, ZIndex = zIndex or 6,
	})
	Theme.stroke(area, Theme.Colors.Gold, 1.5, 0.45)
	return area
end

function Theme.createScrollList(parent, size, position, zIndex)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "ScrollList"
	sf.Size = size
	sf.Position = position or UDim2.fromOffset(0, 0)
	sf.BackgroundColor3 = Theme.Colors.StoneDeep
	sf.BackgroundTransparency = 0.05
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 5
	sf.ScrollBarImageColor3 = Theme.Colors.Crystal
	sf.CanvasSize = UDim2.fromOffset(0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ZIndex = zIndex or 6
	sf.Parent = parent
	Theme.corner(sf, Theme.Corner.Medium)
	Theme.stroke(sf, Theme.Colors.Gold, 1, 0.55)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sf
	Theme.padding(sf, 8, 8, 8, 8)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		sf.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
	end)
	return sf, layout
end

function Theme.createDetailPanel(parent, size, position, zIndex)
	local panel = Theme.createFrame({
		Name = "DetailPanel", Parent = parent, Size = size, Position = position,
		Bg = Theme.Colors.Navy, Corner = Theme.Corner.Large, ZIndex = zIndex or 6,
	})
	Theme.stroke(panel, Theme.Colors.Gold, 2, 0.25)
	Theme.padding(panel, 14, 14, 14, 14)
	return panel
end

function Theme.createIconFrame(parent, icon, size, zIndex)
	size = size or 64
	local frame = Theme.createFrame({
		Name = "IconFrame", Parent = parent, Size = UDim2.fromOffset(size, size),
		Bg = Theme.Colors.TopBarCapsuleEdge, Corner = Theme.Corner.Large, ZIndex = zIndex or 7,
	})
	Theme.stroke(frame, Theme.Colors.GoldBright, 2, 0.35)
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(size - 16, size - 16)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Image = icon or ""
	img.ScaleType = Enum.ScaleType.Fit
	img.ZIndex = (zIndex or 7) + 1
	img.Parent = frame
	return frame, img
end

function Theme.createListRow(parent, props)
	local baseBg = props.Bg or Theme.Colors.NavyEdge
	local row = Instance.new("TextButton")
	row.Name = props.Name or "ListRow"
	row.Size = props.Size or UDim2.new(1, -4, 0, props.Height or 56)
	row.BackgroundColor3 = baseBg
	row.BorderSizePixel = 0
	row.AutoButtonColor = false
	row.Font = Theme.Fonts.Bold
	row.Text = props.Text or ""
	row.TextColor3 = props.TextColor or Theme.Colors.Text
	row.TextSize = props.TextSize or 13
	row.TextWrapped = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	if props.LayoutOrder then row.LayoutOrder = props.LayoutOrder end
	row.ZIndex = props.ZIndex or 7
	row.Parent = parent
	Theme.corner(row, Theme.Corner.Medium)
	Theme.stroke(row, props.StrokeColor or Theme.Colors.Gold, 1.5, 0.55)
	Theme.padding(row, 8, 8, 10, 10)
	if props.OnClick then row.Activated:Connect(props.OnClick) end
	Theme.attachHover(row, baseBg)
	return row
end

function Theme.setListRowSelected(row, selected, accentColor)
	if not row then return end
	local targetBg = selected and (accentColor or Theme.Colors.Crystal) or Theme.Colors.NavyEdge
	local targetStroke = selected and Theme.Colors.GoldBright or Theme.Colors.Gold
	TweenService:Create(row, TweenInfo.new(0.15), { BackgroundColor3 = targetBg }):Play()
	local s = row:FindFirstChildOfClass("UIStroke")
	if s then
		TweenService:Create(s, TweenInfo.new(0.15), {
			Color = targetStroke,
			Transparency = selected and 0.1 or 0.55,
			Thickness = selected and 2 or 1.5,
		}):Play()
	end
	row.TextColor3 = selected and Theme.Colors.TextLight or Theme.Colors.Text
end

function Theme.createStatRow(parent, label, value, layoutOrder, zIndex)
	local row = Theme.createFrame({
		Name = label .. "Row", Parent = parent,
		Size = UDim2.new(1, 0, 0, 22), BgTransparency = 1, LayoutOrder = layoutOrder, ZIndex = zIndex or 7,
	})
	Theme.createText({
		Name = "Label", Parent = row, Text = label,
		Size = UDim2.new(0.55, 0, 1, 0), TextSize = 12, Font = Theme.Fonts.Regular,
		Color = Theme.Colors.TextMuted, ZIndex = (zIndex or 7) + 1,
	})
	Theme.createText({
		Name = "Value", Parent = row, Text = value or "—",
		Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Right, ZIndex = (zIndex or 7) + 1,
	})
	return row
end

function Theme.createEmptyState(parent, icon, title, body, zIndex)
	local wrap = Theme.createFrame({
		Name = "EmptyState", Parent = parent, Size = UDim2.fromScale(1, 1),
		BgTransparency = 1, ZIndex = zIndex or 7,
	})
	Theme.createIconFrame(wrap, icon or Theme.Icons.Dragon, 72, zIndex)
	local iconFrame = wrap:FindFirstChild("IconFrame")
	if iconFrame then
		iconFrame.Position = UDim2.new(0.5, 0, 0.32, 0)
		iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	Theme.createText({
		Name = "EmptyTitle", Parent = wrap, Text = title or "Nothing here yet",
		Size = UDim2.new(1, -40, 0, 28), Position = UDim2.new(0.5, 0, 0.48, 0),
		AnchorPoint = Vector2.new(0.5, 0), TextSize = 18, Font = Theme.Fonts.Title,
		Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Center, ZIndex = (zIndex or 7) + 1,
	})
	Theme.createText({
		Name = "EmptyBody", Parent = wrap, Text = body or "",
		Size = UDim2.new(1, -48, 0, 48), Position = UDim2.new(0.5, 0, 0.56, 0),
		AnchorPoint = Vector2.new(0.5, 0), TextSize = 13, Font = Theme.Fonts.Body,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Center, ZIndex = (zIndex or 7) + 1,
	})
	return wrap
end

function Theme.createProgressBar(parent, size, position, color)
	local back = Theme.createFrame({
		Name = "ProgressBack", Parent = parent, Size = size, Position = position,
		Bg = Theme.Colors.StoneDeep, Corner = Theme.Corner.Pill, BgTransparency = 0,
	})
	Theme.stroke(back, Theme.Colors.Gold, 1, 0.6)
	local fill = Theme.createFrame({
		Name = "ProgressFill", Parent = back, Size = UDim2.fromScale(0, 1),
		Bg = color or Theme.Colors.Crystal, Corner = Theme.Corner.Pill,
	})
	return back, fill
end

-- Draggable horizontal slider (0-1). props: Parent, Size, Position, LayoutOrder, ZIndex,
-- Label (text shown above the track), Value (initial 0-1), Color (fill color),
-- OnChanged(value) fires continuously while dragging (for live local preview),
-- OnCommit(value) fires once when the drag ends (for persisting to the server).
-- Returns the container Frame and an api table with SetValue/GetValue.
function Theme.createSlider(props)
	local z = props.ZIndex or 1
	local container = Theme.createFrame({
		Name = props.Name or "Slider", Parent = props.Parent,
		Size = props.Size or UDim2.new(1, 0, 0, 56), Position = props.Position,
		BgTransparency = 1, ZIndex = z, LayoutOrder = props.LayoutOrder,
	})

	Theme.createText({
		Name = "Label", Parent = container, Text = props.Label or "",
		Size = UDim2.new(0.6, 0, 0, 18), Position = UDim2.fromOffset(0, 0),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = z + 1,
	})

	local startValue = math.clamp(props.Value or 1, 0, 1)
	local valueLabel = Theme.createText({
		Name = "Value", Parent = container, Text = string.format("%d%%", math.floor(startValue * 100 + 0.5)),
		Size = UDim2.new(0.4, 0, 0, 18), Position = UDim2.new(0.6, 0, 0, 0),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Right, ZIndex = z + 1,
	})

	-- HitArea is taller than the visual Track (10px) so the drag target is comfortable on
	-- touch/mouse, matching the Handle's own footprint. It's transparent and only exists for
	-- input; percentage math always uses Track's own AbsolutePosition/AbsoluteSize.
	local hitArea = Theme.createFrame({
		Name = "HitArea", Parent = container, Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 21),
		BgTransparency = 1, ZIndex = z + 1,
	})
	hitArea.Active = true

	local track = Theme.createFrame({
		Name = "Track", Parent = container, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 30),
		Bg = Theme.Colors.StoneDeep, Corner = Theme.Corner.Pill, ZIndex = z + 1,
	})
	track.Active = true
	Theme.stroke(track, Theme.Colors.Gold, 1, 0.6)

	local fill = Theme.createFrame({
		Name = "Fill", Parent = track, Size = UDim2.fromScale(startValue, 1),
		Bg = props.Color or Theme.Colors.Crystal, Corner = Theme.Corner.Pill, ZIndex = z + 2,
	})

	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Size = UDim2.fromOffset(18, 18)
	handle.AnchorPoint = Vector2.new(0.5, 0.5)
	handle.Position = UDim2.new(startValue, 0, 0.5, 0)
	handle.BackgroundColor3 = Theme.Colors.GoldBright
	handle.BorderSizePixel = 0
	handle.Active = true
	handle.ZIndex = z + 3
	handle.Parent = track
	Theme.corner(handle, Theme.Corner.Pill)
	Theme.stroke(handle, Theme.Colors.TextLight, 1.5, 0.2)

	local dragging = false

	local function setValue(value, fireChanged)
		value = math.clamp(value, 0, 1)
		fill.Size = UDim2.fromScale(value, 1)
		handle.Position = UDim2.new(value, 0, 0.5, 0)
		valueLabel.Text = string.format("%d%%", math.floor(value * 100 + 0.5))
		if fireChanged and props.OnChanged then
			props.OnChanged(value)
		end
		return value
	end

	local function updateFromInput(input)
		local relativeX = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
		setValue(relativeX, true)
	end

	local function beginDrag(input)
		dragging = true
		updateFromInput(input)
	end

	hitArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromInput(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			if props.OnCommit then
				props.OnCommit(fill.Size.X.Scale)
			end
		end
	end)

	local api = {}
	function api.SetValue(value)
		setValue(value, false)
	end
	function api.GetValue()
		return fill.Size.X.Scale
	end

	return container, api
end

function Theme.createResourcePill(parent, icon, valueLabel, layoutOrder)
	local pill = Theme.createFrame({
		Name = valueLabel .. "Pill", Parent = parent,
		Size = UDim2.fromOffset(108, 36), Bg = Theme.Colors.TopBarCapsule, Corner = Theme.Corner.Pill,
		LayoutOrder = layoutOrder,
	})
	Theme.stroke(pill, Theme.Colors.Gold, 1.5, 0.35)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill
	Theme.padding(pill, 6, 6, 10, 10)
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Size = UDim2.fromOffset(24, 24)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = icon
	iconLabel.ScaleType = Enum.ScaleType.Fit
	iconLabel.LayoutOrder = 1
	iconLabel.Parent = pill
	local val = Theme.createText({
		Name = valueLabel, Parent = pill, Size = UDim2.fromOffset(0, 24),
		AutoSize = Enum.AutomaticSize.X, Text = "0", TextSize = 15,
		Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, LayoutOrder = 2,
	})
	local sizeC = Instance.new("UISizeConstraint")
	sizeC.MinSize = Vector2.new(80, 36)
	sizeC.Parent = pill
	return pill, val
end

function Theme.createPremiumResourceCapsule(parent, icon, valueLabel, layoutOrder)
	local pill = Theme.createFrame({
		Name = valueLabel .. "Capsule", Parent = parent,
		Size = UDim2.fromOffset(0, 44), Bg = Theme.Colors.TopBarCapsule,
		Corner = Theme.Corner.Pill, LayoutOrder = layoutOrder,
	})
	pill.AutomaticSize = Enum.AutomaticSize.X
	Theme.stroke(pill, Theme.Colors.Gold, 2, 0.2)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill
	Theme.padding(pill, 8, 8, 12, 12)
	local iconFrame = Theme.createFrame({
		Name = "IconFrame", Parent = pill, Size = UDim2.fromOffset(32, 32),
		Bg = Theme.Colors.TopBarCapsuleEdge, Corner = Theme.Corner.Medium, LayoutOrder = 1,
	})
	Theme.stroke(iconFrame, Theme.Colors.GoldBright, 1.5, 0.45)
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Size = UDim2.fromOffset(24, 24)
	iconLabel.Position = UDim2.fromScale(0.5, 0.5)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = icon
	iconLabel.ScaleType = Enum.ScaleType.Fit
	iconLabel.Parent = iconFrame
	local val = Theme.createText({
		Name = valueLabel, Parent = pill, Size = UDim2.fromOffset(0, 28),
		AutoSize = Enum.AutomaticSize.X, Text = "0", TextSize = 17,
		Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, LayoutOrder = 2,
	})
	local sizeC = Instance.new("UISizeConstraint")
	sizeC.MinSize = Vector2.new(108, 44)
	sizeC.Parent = pill
	return pill, val
end

function Theme.createKingdomCapsule(parent)
	local capsule = Theme.createFrame({
		Name = "KingdomCapsule", Parent = parent,
		Size = UDim2.fromOffset(250, 56), Bg = Theme.Colors.TopBarCapsule, Corner = Theme.Corner.Pill,
	})
	capsule.ClipsDescendants = true
	Theme.stroke(capsule, Theme.Colors.Gold, 2, 0.18)
	local badge = Theme.createFrame({
		Name = "KingdomBadge", Parent = capsule, Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(10, 8), Bg = Theme.Colors.TopBarCapsuleEdge, Corner = Theme.Corner.Medium,
	})
	Theme.stroke(badge, Theme.Colors.GoldBright, 1.5, 0.35)
	local crownIcon = Instance.new("ImageLabel")
	crownIcon.Size = UDim2.fromOffset(26, 26)
	crownIcon.Position = UDim2.fromScale(0.5, 0.5)
	crownIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	crownIcon.BackgroundTransparency = 1
	crownIcon.Image = Theme.Icons.Crown
	crownIcon.ScaleType = Enum.ScaleType.Fit
	crownIcon.Parent = badge
	local nameLabel = Theme.createText({
		Name = "KingdomName", Parent = capsule, Text = "KINGDOM",
		Size = UDim2.new(1, -62, 0, 18), Position = UDim2.fromOffset(56, 8),
		TextSize = 14, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight, Wrapped = false,
	})
	local levelRow = Theme.createFrame({
		Name = "LevelRow", Parent = capsule, Size = UDim2.new(1, -62, 0, 18),
		Position = UDim2.fromOffset(56, 30), BgTransparency = 1,
	})
	local levelLabel = Theme.createText({
		Name = "KingdomLevel", Parent = levelRow, Text = "Lv. 1",
		Size = UDim2.fromOffset(46, 16), TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.GoldBright,
	})
	local _, xpFill = Theme.createProgressBar(levelRow, UDim2.new(1, -52, 0, 12), UDim2.fromOffset(50, 2), Theme.Colors.Crystal)
	local progressBack = levelRow:FindFirstChild("ProgressBack", true)
	if progressBack then progressBack.BackgroundColor3 = Theme.Colors.TopBarCapsuleEdge end
	return capsule, nameLabel, levelLabel, xpFill
end

function Theme.createNavButton(parent, name, icon, label, layoutOrder, onClick, zIndex)
	zIndex = zIndex or 2
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = Theme.Colors.Nav
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.LayoutOrder = layoutOrder
	btn.ZIndex = zIndex
	btn.Parent = parent
	Theme.corner(btn, Theme.Corner.Medium)
	Theme.stroke(btn, Theme.Colors.Gold, 1.5, 0.5)
	local iconImg = Instance.new("ImageLabel")
	iconImg.Name = "Icon"
	iconImg.Size = UDim2.fromOffset(20, 20)
	iconImg.Position = UDim2.fromOffset(10, 10)
	iconImg.BackgroundTransparency = 1
	iconImg.Image = icon
	iconImg.ScaleType = Enum.ScaleType.Fit
	iconImg.ZIndex = zIndex + 1
	iconImg.Parent = btn
	Theme.createText({
		Name = "Label", Parent = btn, Size = UDim2.new(1, -36, 1, 0),
		Position = UDim2.fromOffset(34, 0), Text = label, TextSize = 12, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.Text, Wrapped = false, ZIndex = zIndex + 1,
	})
	Theme.attachHover(btn, Theme.Colors.Nav)
	Theme.attachBounce(btn)
	if onClick then btn.Activated:Connect(onClick) end
	return btn
end

function Theme.setNavActive(btn, active)
	if not btn then return end
	local targetBg = active and Theme.Colors.Crystal or Theme.Colors.Nav
	local targetStroke = active and Theme.Colors.GoldBright or Theme.Colors.Gold
	TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = targetBg }):Play()
	local s = btn:FindFirstChildOfClass("UIStroke")
	if s then TweenService:Create(s, TweenInfo.new(0.18), { Color = targetStroke, Transparency = active and 0.05 or 0.5 }):Play() end
	local label = btn:FindFirstChild("Label")
	if label then label.TextColor3 = active and Theme.Colors.TextLight or Theme.Colors.Text end
end

function Theme.createFloatingNavButton(props)
	local size = props.Size or 52
	local baseBg = props.Bg or Theme.Colors.TopBarCapsule
	local btn = Instance.new("ImageButton")
	btn.Name = props.Name or "FloatingNavButton"
	btn.Size = UDim2.fromOffset(size, size)
	btn.Position = props.Position or UDim2.fromOffset(0, 0)
	btn.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	btn.BackgroundColor3 = baseBg
	btn.BorderSizePixel = 0
	btn.Image = props.Image or ""
	btn.ScaleType = Enum.ScaleType.Fit
	btn.AutoButtonColor = false
	btn.ImageTransparency = props.ImageTransparency or 0
	if props.LayoutOrder then btn.LayoutOrder = props.LayoutOrder end
	btn.ZIndex = props.ZIndex or 2
	btn.Parent = props.Parent
	Theme.corner(btn, UDim.new(1, 0))
	Theme.stroke(btn, props.StrokeColor or Theme.Colors.Gold, 2, 0.25)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 11)
	pad.PaddingBottom = UDim.new(0, 11)
	pad.PaddingLeft = UDim.new(0, 11)
	pad.PaddingRight = UDim.new(0, 11)
	pad.Parent = btn
	Theme.attachHover(btn, baseBg)
	Theme.attachBounce(btn)
	if props.OnClick then btn.Activated:Connect(props.OnClick) end
	return btn
end

function Theme.setFloatingNavActive(btn, active)
	if not btn then return end
	local targetBg = active and Theme.Colors.Crystal or Theme.Colors.TopBarCapsule
	local targetStroke = active and Theme.Colors.GoldBright or Theme.Colors.Gold
	TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = targetBg }):Play()
	local s = btn:FindFirstChildOfClass("UIStroke")
	if s then
		TweenService:Create(s, TweenInfo.new(0.18), {
			Color = targetStroke,
			Thickness = active and 2.5 or 2,
			Transparency = active and 0.05 or 0.25,
		}):Play()
	end
end

function Theme.attachHover(gui, baseColor)
	baseColor = baseColor or (gui:IsA("GuiObject") and gui.BackgroundColor3) or Theme.Colors.Nav
	gui.MouseEnter:Connect(function()
		if not gui.Parent then return end
		TweenService:Create(gui, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = baseColor:Lerp(Theme.Colors.CrystalSoft, 0.35),
		}):Play()
	end)
	gui.MouseLeave:Connect(function()
		if not gui.Parent then return end
		TweenService:Create(gui, TweenInfo.new(0.14), { BackgroundColor3 = baseColor }):Play()
	end)
end

function Theme.attachBounce(gui)
	local baseSize = gui.Size
	gui.Activated:Connect(function()
		if not gui.Parent then return end
		local shrink = TweenService:Create(gui, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = baseSize - UDim2.fromOffset(4, 4),
		})
		shrink:Play()
		shrink.Completed:Connect(function()
			TweenService:Create(gui, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = baseSize }):Play()
		end)
	end)
end

function Theme.addIconPulse(icon)
	task.spawn(function()
		while icon.Parent do
			TweenService:Create(icon, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Rotation = 6, Size = UDim2.fromOffset(40, 40),
			}):Play()
			task.wait(0.8)
			TweenService:Create(icon, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Rotation = -6, Size = UDim2.fromOffset(36, 36),
			}):Play()
			task.wait(0.8)
		end
	end)
end

function Theme.addCrystalShine(panel)
	local shine = Instance.new("Frame")
	shine.Name = "CrystalShine"
	shine.Size = UDim2.new(0.35, 0, 0.5, 0)
	shine.Position = UDim2.new(-0.5, 0, 0.25, 0)
	shine.BackgroundColor3 = Theme.Colors.CrystalGlow
	shine.BackgroundTransparency = 0.88
	shine.BorderSizePixel = 0
	shine.Rotation = 25
	shine.ZIndex = 2
	shine.Active = false
	shine.Selectable = false
	shine.Parent = panel
	Theme.corner(shine, Theme.Corner.Large)
	task.spawn(function()
		while shine.Parent do
			shine.Position = UDim2.new(-0.5, 0, 0.25, 0)
			TweenService:Create(shine, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(1.1, 0, 0.25, 0),
			}):Play()
			task.wait(3.5)
		end
	end)
end

function Theme.tweenOpen(panel, dim)
	if dim then
		dim.Visible = true
		dim.Active = true
		dim.BackgroundTransparency = 1
		TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.5 }):Play()
	end
	local openPos = panel:GetAttribute("OpenPosition")
	if typeof(openPos) ~= "UDim2" then openPos = panel.Position; panel:SetAttribute("OpenPosition", openPos) end
	local closedPos = openPos + UDim2.fromOffset(0, 30)
	panel.Visible = true
	panel.Position = closedPos
	panel.BackgroundTransparency = 0.2
	local panelScale = panel:FindFirstChild("PanelScale")
	if panelScale and panelScale:IsA("UIScale") then panelScale.Scale = (Theme.MobileScale or 1) * 0.94 end
	TweenService:Create(panel, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = openPos, BackgroundTransparency = 0,
	}):Play()
	if panelScale and panelScale:IsA("UIScale") then
		TweenService:Create(panelScale, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = Theme.MobileScale or 1,
		}):Play()
	end
end

function Theme.tweenClose(panel, dim, onDone)
	local openPos = panel:GetAttribute("OpenPosition") or panel.Position
	local closedPos = openPos + UDim2.fromOffset(0, 30)
	if dim then
		dim.Active = false
		TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	end
	local panelScale = panel:FindFirstChild("PanelScale")
	if panelScale and panelScale:IsA("UIScale") then
		TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = (Theme.MobileScale or 1) * 0.94,
		}):Play()
	end
	local t = TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = closedPos })
	t:Play()
	t.Completed:Connect(function()
		panel.Visible = false
		panel.Position = openPos
		if panelScale and panelScale:IsA("UIScale") then panelScale.Scale = Theme.MobileScale or 1 end
		if dim then Theme.hideDim(dim) end
		if onDone then onDone() end
	end)
end

function Theme.getRarityColor(rarity)
	return Theme.Rarity[rarity] or Theme.Rarity.Common
end

function Theme.styleScrollFrame(sf)
	sf.BackgroundColor3 = Theme.Colors.StoneDeep
	sf.BackgroundTransparency = 0.05
	sf.BorderSizePixel = 0
	sf.ScrollBarImageColor3 = Theme.Colors.Crystal
	Theme.corner(sf, Theme.Corner.Medium)
	Theme.stroke(sf, Theme.Colors.Gold, 1, 0.55)
end

function Theme.createSectionTitle(parent, text, position, size)
	return Theme.createText({
		Name = "SectionTitle", Parent = parent, Text = text,
		Size = size or UDim2.new(1, -60, 0, 32), Position = position or UDim2.fromOffset(16, 12),
		TextSize = 22, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight,
	})
end

function Theme.fadeTooltip(tooltip, visible)
	if not tooltip then return end
	if visible then
		tooltip.Visible = true
		tooltip.TextTransparency = 1
		tooltip.BackgroundTransparency = 1
		TweenService:Create(tooltip, TweenInfo.new(0.18), { TextTransparency = 0, BackgroundTransparency = 0.05 }):Play()
		local s = tooltip:FindFirstChildOfClass("UIStroke")
		if s then TweenService:Create(s, TweenInfo.new(0.18), { Transparency = 0.3 }):Play() end
	else
		local t = TweenService:Create(tooltip, TweenInfo.new(0.14), { TextTransparency = 1, BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Connect(function() tooltip.Visible = false end)
	end
end

return Theme
