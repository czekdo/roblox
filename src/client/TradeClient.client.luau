local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))

local TradeEvents = ReplicatedStorage:WaitForChild("TradeEvents")
local RequestServerPlayers = TradeEvents:WaitForChild("RequestServerPlayers")
local RequestTradeableDragons = TradeEvents:WaitForChild("RequestTradeableDragons")
local RequestTrade = TradeEvents:WaitForChild("RequestTrade")
local RespondToTradeRequest = TradeEvents:WaitForChild("RespondToTradeRequest")
local UpdateOffer = TradeEvents:WaitForChild("UpdateOffer")
local ConfirmOffer = TradeEvents:WaitForChild("ConfirmOffer")
local CancelTrade = TradeEvents:WaitForChild("CancelTrade")
local TradeUpdate = TradeEvents:WaitForChild("TradeUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function dragonLabel(d)
	local text = tostring(d.DragonType or "Dragon") .. " (" .. tostring(d.Rarity or "Common") .. " Lv." .. tostring(d.Level or 1) .. ")"
	return text
end

-- ============================================================
-- Player list panel (browse + request)
-- ============================================================

local listGui, listPanel, listDim, listScroll

local function ensureListUi()
	if listGui then
		return
	end
	listGui = Instance.new("ScreenGui")
	listGui.Name = "TradeListUI"
	listGui.ResetOnSpawn = false
	listGui.DisplayOrder = 40
	listGui.Enabled = false
	listGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	listGui.Parent = playerGui
	Theme.applyScreenSafeArea(listGui)

	listDim = Theme.createDim(listGui, 1)
	listDim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UIBridge.ClosePanel("Trade")
		end
	end)

	listPanel = Theme.createPanel({ Name = "TradeListPanel", Parent = listGui, Size = UDim2.fromOffset(400, 460), Visible = false, ZIndex = 25 })
	listPanel:SetAttribute("OpenPosition", listPanel.Position)
	Theme.createCloseButton(listPanel, function()
		UIBridge.ClosePanel("Trade")
	end, 30)
	Theme.createWindowHeader(listPanel, "Trade", "Players on this server", 30)

	listScroll = Instance.new("ScrollingFrame")
	listScroll.Name = "PlayerScroll"
	listScroll.Size = UDim2.new(1, -32, 1, -104)
	listScroll.Position = UDim2.fromOffset(16, 88)
	listScroll.BackgroundTransparency = 1
	listScroll.BorderSizePixel = 0
	listScroll.ScrollBarThickness = 10
	listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listScroll.CanvasSize = UDim2.fromOffset(0, 0)
	listScroll.Active = true
	listScroll.ZIndex = 8
	listScroll.Parent = listPanel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listScroll
end

local function refreshPlayerList()
	for _, child in listScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local ok, others = pcall(function()
		return RequestServerPlayers:InvokeServer()
	end)
	if not ok or typeof(others) ~= "table" or #others == 0 then
		Theme.createEmptyState(listScroll, Theme.Icons.Backpack, "No One Else Here", "You're the only player on this server right now.", 8)
		return
	end
	for i, entry in others do
		local row = Theme.createFrame({
			Name = "Player_" .. entry.UserId, Parent = listScroll,
			Size = UDim2.new(1, 0, 0, 52), Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8, LayoutOrder = i,
		})
		Theme.padding(row, 8, 8, 12, 12)
		Theme.createText({
			Name = "Name", Parent = row, Text = entry.DisplayName,
			Size = UDim2.new(1, -110, 1, 0), TextSize = 15, Font = Theme.Fonts.Bold,
			Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
		})
		Theme.createButton({
			Name = "RequestButton", Parent = row, Text = "Request Trade",
			Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, 0, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5), Bg = Theme.Colors.Success, TextSize = 12, ZIndex = 9,
			OnClick = function()
				RequestTrade:FireServer(entry.UserId)
			end,
		})
	end
end

local function openListPanel()
	ensureListUi()
	listGui.Enabled = true
	Theme.raiseModalGui(listGui)
	UIBridge.NotifyModalOpened(listGui.Name)
	Theme.tweenOpen(listPanel, listDim)
	refreshPlayerList()
end

local function closeListPanel()
	if not listGui or not listPanel then
		return
	end
	Theme.closeModalWindow(listGui, listPanel, listDim, function()
		UIBridge.NotifyModalClosed(listGui.Name)
	end)
end

UIBridge.RegisterPanel("Trade", { Open = openListPanel, Close = closeListPanel })
_G.DragonIslandOpenTrade = openListPanel

-- ============================================================
-- Incoming request popup
-- ============================================================

local requestGui

local function showIncomingRequest(fromUserId, fromName)
	if requestGui then
		requestGui:Destroy()
	end
	requestGui = Instance.new("ScreenGui")
	requestGui.Name = "TradeRequestUI"
	requestGui.ResetOnSpawn = false
	requestGui.DisplayOrder = 60
	requestGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	requestGui.Parent = playerGui

	local box = Theme.createPanel({ Name = "RequestBox", Parent = requestGui, Size = UDim2.fromOffset(340, 150), ZIndex = 30 })
	box.Position = UDim2.new(0.5, 0, 0, 90)
	box.AnchorPoint = Vector2.new(0.5, 0)
	Theme.createText({
		Name = "Message", Parent = box, Text = tostring(fromName) .. " wants to trade with you!",
		Size = UDim2.new(1, -24, 0, 50), Position = UDim2.fromOffset(12, 16),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight,
		Wrapped = true, XAlign = Enum.TextXAlignment.Center, ZIndex = 31,
	})
	Theme.createButton({
		Name = "Accept", Parent = box, Text = "Accept",
		Size = UDim2.fromOffset(140, 40), Position = UDim2.fromOffset(12, 90),
		Bg = Theme.Colors.Success, TextSize = 14, ZIndex = 31,
		OnClick = function()
			RespondToTradeRequest:FireServer(true)
			requestGui:Destroy()
			requestGui = nil
		end,
	})
	Theme.createButton({
		Name = "Decline", Parent = box, Text = "Decline",
		Size = UDim2.fromOffset(140, 40), Position = UDim2.new(1, -12, 0, 90), AnchorPoint = Vector2.new(1, 0),
		Bg = Theme.Colors.Danger, TextSize = 14, ZIndex = 31,
		OnClick = function()
			RespondToTradeRequest:FireServer(false)
			requestGui:Destroy()
			requestGui = nil
		end,
	})
end

-- ============================================================
-- Trade session window
-- ============================================================

local sessionGui, sessionPanel, sessionDim
local opponentLabel, statusLabel
local myEssenceBox, myGemsBox, myDragonScroll, myConfirmButton
local theirEssenceLabel, theirGemsLabel, theirDragonScroll, theirConfirmLabel

local myTradeableDragons = {}
local mySelectedDragonIds = {}

local function sendMyOffer()
	local ids = {}
	for id in mySelectedDragonIds do
		table.insert(ids, id)
	end
	UpdateOffer:FireServer({
		Essence = tonumber(myEssenceBox.Text) or 0,
		Gems = tonumber(myGemsBox.Text) or 0,
		DragonIds = ids,
	})
end

local function ensureSessionUi()
	if sessionGui then
		return
	end
	sessionGui = Instance.new("ScreenGui")
	sessionGui.Name = "TradeSessionUI"
	sessionGui.ResetOnSpawn = false
	sessionGui.DisplayOrder = 45
	sessionGui.Enabled = false
	sessionGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sessionGui.Parent = playerGui
	Theme.applyScreenSafeArea(sessionGui)

	sessionDim = Theme.createDim(sessionGui, 1)

	sessionPanel = Theme.createPanel({ Name = "TradeSessionPanel", Parent = sessionGui, Size = UDim2.fromOffset(620, 480), Visible = false, ZIndex = 25 })
	sessionPanel:SetAttribute("OpenPosition", sessionPanel.Position)
	Theme.createCloseButton(sessionPanel, function()
		CancelTrade:FireServer()
	end, 30)

	opponentLabel = Theme.createText({
		Name = "OpponentLabel", Parent = sessionPanel, Text = "Trading with...",
		Size = UDim2.new(1, -60, 0, 26), Position = UDim2.fromOffset(16, 14),
		TextSize = 18, Font = Theme.Fonts.Title, Color = Theme.Colors.TextLight,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 27,
	})
	statusLabel = Theme.createText({
		Name = "StatusLabel", Parent = sessionPanel, Text = "",
		Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(16, 40),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted,
		XAlign = Enum.TextXAlignment.Left, ZIndex = 27,
	})

	-- My side (left)
	local myColumn = Theme.createFrame({
		Name = "MyColumn", Parent = sessionPanel,
		Size = UDim2.new(0.5, -24, 1, -140), Position = UDim2.fromOffset(16, 70),
		Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.createText({
		Name = "Header", Parent = myColumn, Text = "YOUR OFFER",
		Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 6),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 9,
	})

	Theme.createText({
		Name = "EssenceLabel", Parent = myColumn, Text = "Essence:",
		Size = UDim2.fromOffset(70, 26), Position = UDim2.fromOffset(8, 30),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})
	myEssenceBox = Instance.new("TextBox")
	myEssenceBox.Name = "EssenceBox"
	myEssenceBox.Size = UDim2.fromOffset(90, 26)
	myEssenceBox.Position = UDim2.fromOffset(80, 30)
	myEssenceBox.Text = "0"
	myEssenceBox.PlaceholderText = "0"
	myEssenceBox.Font = Theme.Fonts.Body
	myEssenceBox.TextSize = 13
	myEssenceBox.BackgroundColor3 = Theme.Colors.NavyEdge
	myEssenceBox.TextColor3 = Theme.Colors.TextLight
	myEssenceBox.ZIndex = 9
	myEssenceBox.Parent = myColumn
	Theme.corner(myEssenceBox, Theme.Corner.Small)
	myEssenceBox.FocusLost:Connect(sendMyOffer)

	Theme.createText({
		Name = "GemsLabel", Parent = myColumn, Text = "Gems:",
		Size = UDim2.fromOffset(70, 26), Position = UDim2.fromOffset(8, 60),
		TextSize = 12, Font = Theme.Fonts.Body, Color = Theme.Colors.TextMuted, ZIndex = 9,
	})
	myGemsBox = Instance.new("TextBox")
	myGemsBox.Name = "GemsBox"
	myGemsBox.Size = UDim2.fromOffset(90, 26)
	myGemsBox.Position = UDim2.fromOffset(80, 60)
	myGemsBox.Text = "0"
	myGemsBox.PlaceholderText = "0"
	myGemsBox.Font = Theme.Fonts.Body
	myGemsBox.TextSize = 13
	myGemsBox.BackgroundColor3 = Theme.Colors.NavyEdge
	myGemsBox.TextColor3 = Theme.Colors.TextLight
	myGemsBox.ZIndex = 9
	myGemsBox.Parent = myColumn
	Theme.corner(myGemsBox, Theme.Corner.Small)
	myGemsBox.FocusLost:Connect(sendMyOffer)

	myDragonScroll = Instance.new("ScrollingFrame")
	myDragonScroll.Size = UDim2.new(1, -16, 1, -128)
	myDragonScroll.Position = UDim2.fromOffset(8, 92)
	myDragonScroll.BackgroundTransparency = 1
	myDragonScroll.BorderSizePixel = 0
	myDragonScroll.ScrollBarThickness = 8
	myDragonScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	myDragonScroll.CanvasSize = UDim2.fromOffset(0, 0)
	myDragonScroll.ZIndex = 9
	myDragonScroll.Parent = myColumn
	local myDragonLayout = Instance.new("UIListLayout")
	myDragonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	myDragonLayout.Padding = UDim.new(0, 4)
	myDragonLayout.Parent = myDragonScroll

	myConfirmButton = Theme.createButton({
		Name = "ConfirmButton", Parent = myColumn, Text = "Confirm",
		Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1), Bg = Theme.Colors.Success, TextSize = 13, ZIndex = 9,
		OnClick = function()
			ConfirmOffer:FireServer()
		end,
	})

	-- Their side (right)
	local theirColumn = Theme.createFrame({
		Name = "TheirColumn", Parent = sessionPanel,
		Size = UDim2.new(0.5, -24, 1, -140), Position = UDim2.new(0.5, 8, 0, 70),
		Bg = Theme.Colors.PanelInner, Corner = Theme.Corner.Medium, ZIndex = 8,
	})
	Theme.createText({
		Name = "Header", Parent = theirColumn, Text = "THEIR OFFER",
		Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 6),
		TextSize = 12, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold, ZIndex = 9,
	})
	theirEssenceLabel = Theme.createText({
		Name = "EssenceLabel", Parent = theirColumn, Text = "Essence: 0",
		Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 30),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})
	theirGemsLabel = Theme.createText({
		Name = "GemsLabel", Parent = theirColumn, Text = "Gems: 0",
		Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 58),
		TextSize = 13, Font = Theme.Fonts.Body, Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Left, ZIndex = 9,
	})
	theirDragonScroll = Instance.new("ScrollingFrame")
	theirDragonScroll.Size = UDim2.new(1, -16, 1, -128)
	theirDragonScroll.Position = UDim2.fromOffset(8, 92)
	theirDragonScroll.BackgroundTransparency = 1
	theirDragonScroll.BorderSizePixel = 0
	theirDragonScroll.ScrollBarThickness = 8
	theirDragonScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	theirDragonScroll.CanvasSize = UDim2.fromOffset(0, 0)
	theirDragonScroll.ZIndex = 9
	theirDragonScroll.Parent = theirColumn
	local theirDragonLayout = Instance.new("UIListLayout")
	theirDragonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	theirDragonLayout.Padding = UDim.new(0, 4)
	theirDragonLayout.Parent = theirDragonScroll

	theirConfirmLabel = Theme.createText({
		Name = "ConfirmLabel", Parent = theirColumn, Text = "Waiting for offer...",
		Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1), TextSize = 13, Font = Theme.Fonts.Bold,
		Color = Theme.Colors.TextMuted, XAlign = Enum.TextXAlignment.Center, ZIndex = 9,
	})

	Theme.createButton({
		Name = "CancelButton", Parent = sessionPanel, Text = "Cancel Trade",
		Size = UDim2.fromOffset(160, 40), Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1), Bg = Theme.Colors.Danger, TextSize = 14, ZIndex = 27,
		OnClick = function()
			CancelTrade:FireServer()
		end,
	})
end

local function rebuildMyDragonList()
	for _, child in myDragonScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, d in myTradeableDragons do
		local selected = mySelectedDragonIds[d.id] == true
		local row = Theme.createButton({
			Name = "Dragon_" .. d.id, Parent = myDragonScroll, Text = dragonLabel({ DragonType = d.displayName or d.dragonType, Rarity = d.rarity, Level = d.level }),
			Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, TextSize = 11,
			Bg = selected and Theme.Colors.Gold or Theme.Colors.NavyEdge, ZIndex = 9,
			OnClick = function()
				if mySelectedDragonIds[d.id] then
					mySelectedDragonIds[d.id] = nil
				else
					mySelectedDragonIds[d.id] = true
				end
				rebuildMyDragonList()
				sendMyOffer()
			end,
		})
	end
end

local function rebuildTheirDragonList(dragons)
	for _, child in theirDragonScroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, d in dragons do
		Theme.createText({
			Name = "Dragon_" .. i, Parent = theirDragonScroll, Text = dragonLabel(d),
			Size = UDim2.new(1, 0, 0, 22), TextSize = 12, Font = Theme.Fonts.Body,
			Color = Theme.Colors.TextLight, XAlign = Enum.TextXAlignment.Left, ZIndex = 9, LayoutOrder = i,
		})
	end
end

local function closeSessionUi(message)
	if sessionGui then
		sessionGui.Enabled = false
	end
	if message then
		UIBridge.Notify(message)
	end
	mySelectedDragonIds = {}
end

local function openSessionUi(opponentName)
	ensureSessionUi()
	opponentLabel.Text = "Trading with " .. tostring(opponentName)
	statusLabel.Text = "Add currency or dragons to your offer, then Confirm."
	myEssenceBox.Text = "0"
	myGemsBox.Text = "0"
	mySelectedDragonIds = {}
	sessionGui.Enabled = true
	Theme.raiseModalGui(sessionGui)
	Theme.tweenOpen(sessionPanel, sessionDim)

	task.spawn(function()
		local ok, dragons = pcall(function()
			return RequestTradeableDragons:InvokeServer()
		end)
		if ok and typeof(dragons) == "table" then
			myTradeableDragons = dragons
			rebuildMyDragonList()
		end
	end)
end

TradeUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.type == "Request" then
		showIncomingRequest(payload.fromUserId, payload.fromName)
	elseif payload.type == "RequestSent" then
		UIBridge.Notify("Trade request sent to " .. tostring(payload.toName))
	elseif payload.type == "Declined" then
		UIBridge.Notify(tostring(payload.byName) .. " declined the trade.")
	elseif payload.type == "Error" then
		UIBridge.Notify(tostring(payload.message))
	elseif payload.type == "SessionStarted" then
		closeListPanel()
		openSessionUi(payload.opponentName)
	elseif payload.type == "StateChanged" then
		if not sessionGui or not sessionGui.Enabled then
			return
		end
		theirEssenceLabel.Text = "Essence: " .. tostring(payload.theirOffer.Essence)
		theirGemsLabel.Text = "Gems: " .. tostring(payload.theirOffer.Gems)
		rebuildTheirDragonList(payload.theirOffer.Dragons)
		theirConfirmLabel.Text = payload.theirConfirmed and "✓ Confirmed" or "Waiting for offer..."
		theirConfirmLabel.Color = payload.theirConfirmed and Theme.Colors.Success or Theme.Colors.TextMuted
		if payload.myConfirmed then
			myConfirmButton.Text = "Waiting..."
			myConfirmButton.Active = false
		else
			myConfirmButton.Text = "Confirm"
			myConfirmButton.Active = true
		end
	elseif payload.type == "Completed" then
		closeSessionUi("Trade completed!")
	elseif payload.type == "Cancelled" then
		closeSessionUi(tostring(payload.reason or "Trade cancelled."))
	end
end)

print("[TradeClient] Trade UI ready")
