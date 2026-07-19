local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))

local MailEvents = ReplicatedStorage:WaitForChild("MailEvents")
local RequestMailList = MailEvents:WaitForChild("RequestMailList")
local ClaimMail = MailEvents:WaitForChild("ClaimMail")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui, panel, dim, scroll, emptyLabel
local refreshList

local function updateHudBadge(unclaimedCount)
	UIBridge.Fire("MailUnreadChanged", unclaimedCount)
end

local function createMailCard(entry)
	local card = Theme.createFrame({
		Name = "Mail_" .. entry.Id, Parent = nil,
		Size = UDim2.new(1, 0, 0, 84),
		Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.stroke(card, entry.Claimed and Theme.Colors.TextMuted or Theme.Colors.Gold, 1, entry.Claimed and 0.7 or 0.3)
	Theme.padding(card, 10, 10, 12, 12)

	Theme.createText({
		Name = "Title", Parent = card, Text = entry.Title,
		Size = UDim2.new(1, entry.Reward and -110 or -20, 0, 20), Position = UDim2.fromOffset(0, 0),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})
	Theme.createText({
		Name = "Body", Parent = card, Text = entry.Body or "",
		Size = UDim2.new(1, entry.Reward and -110 or -20, 0, 44), Position = UDim2.fromOffset(0, 22),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		Wrapped = true, YAlign = Enum.TextYAlignment.Top, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})

	if entry.Reward then
		if entry.Claimed then
			Theme.createText({
				Name = "Claimed", Parent = card, Text = "Claimed",
				Size = UDim2.fromOffset(90, 32), Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5), TextSize = 13, Font = Theme.Fonts.Body,
				Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
			})
		else
			Theme.createButton({
				Name = "ClaimButton", Parent = card, Text = "Claim",
				Size = UDim2.fromOffset(90, 32), Position = UDim2.new(1, 0, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5), Bg = Theme.Colors.Success, TextSize = 13, ZIndex = 9,
				OnClick = function()
					ClaimMail:FireServer(entry.Id)
					task.wait(0.15)
					local ok, state = pcall(function()
						return RequestMailList:InvokeServer()
					end)
					if ok then
						refreshList(state)
					end
				end,
			})
		end
	end

	return card
end

refreshList = function(state)
	if not scroll then
		return
	end
	for _, child in scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not state or typeof(state.mail) ~= "table" or #state.mail == 0 then
		emptyLabel.Visible = true
		updateHudBadge(0)
		return
	end
	emptyLabel.Visible = false
	for i, entry in state.mail do
		local card = createMailCard(entry)
		card.LayoutOrder = i
		card.Parent = scroll
	end
	updateHudBadge(state.unclaimedCount or 0)
end

local function ensureUi()
	if screenGui then
		return
	end
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MailUI"
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
			UIBridge.ClosePanel("Mail")
		end
	end)

	panel = Theme.createPanel({ Name = "MailPanel", Parent = screenGui, Size = UDim2.fromOffset(420, 480), Visible = false, ZIndex = 25 })
	panel:SetAttribute("OpenPosition", panel.Position)
	Theme.createCloseButton(panel, function()
		UIBridge.ClosePanel("Mail")
	end, 30)
	Theme.createWindowHeader(panel, "Mail", "Gifts and messages", 30)

	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "MailScroll"
	scroll.Size = UDim2.new(1, -32, 1, -104)
	scroll.Position = UDim2.fromOffset(16, 88)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 10
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Active = true
	scroll.ZIndex = 6
	scroll.Parent = panel

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll

	emptyLabel = Theme.createText({
		Name = "Empty", Parent = panel, Text = "No mail yet. Check back later!",
		Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 200),
		TextSize = 14, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 8, Visible = false,
	})
end

local function refreshState()
	local ok, state = pcall(function()
		return RequestMailList:InvokeServer()
	end)
	if ok then
		refreshList(state)
	end
end

local function openMailPanel()
	ensureUi()
	screenGui.Enabled = true
	Theme.raiseModalGui(screenGui)
	UIBridge.NotifyModalOpened(screenGui.Name)
	Theme.tweenOpen(panel, dim)
	refreshState()
end

local function closeMailPanel()
	if not screenGui or not panel then
		return
	end
	Theme.closeModalWindow(screenGui, panel, dim, function()
		UIBridge.NotifyModalClosed(screenGui.Name)
	end)
end

UIBridge.RegisterPanel("Mail", { Open = openMailPanel, Close = closeMailPanel })
_G.DragonIslandOpenMail = openMailPanel

-- Refresh the HUD badge on join without opening the panel.
task.spawn(function()
	task.wait(2)
	local ok, state = pcall(function()
		return RequestMailList:InvokeServer()
	end)
	if ok and typeof(state) == "table" then
		updateHudBadge(state.unclaimedCount or 0)
	end
end)

print("[MailClient] Mail UI ready")
