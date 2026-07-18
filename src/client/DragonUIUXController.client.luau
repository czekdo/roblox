local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local HarvestUIUpdate = HarvestEvents:WaitForChild("HarvestUIUpdate")
local EggShopUpdate = HarvestEvents:WaitForChild("EggShopUpdate")
local DragonMergeUpdate = HarvestEvents:WaitForChild("DragonMergeUpdate")
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestUpdate = QuestEvents:WaitForChild("QuestUpdate")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DragonUIUXController"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = Theme.NavDisplayOrder
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui
Theme.applyScreenSafeArea(screenGui)

local safeEdge = Theme.SafeArea.Edge
local navColumnWidth = Theme.SafeArea.NavColumnWidth

local NOTIFICATION_WIDTH = 280
local NOTIFICATION_HEIGHT = 52
local NOTIFICATION_GAP = 8
local NOTIFICATION_MAX = 4
local NOTIFICATION_BOTTOM = Theme.SafeArea.BottomExtra

local notifications = Theme.createFrame({
	Name = "Notifications", Parent = screenGui,
	Size = UDim2.fromOffset(NOTIFICATION_WIDTH, 320),
	Position = UDim2.new(1, -(safeEdge + 8), 1, -NOTIFICATION_BOTTOM),
	AnchorPoint = Vector2.new(1, 1), BgTransparency = 1, ZIndex = 20,
})
Theme.makeInputTransparent(notifications)

local tooltip = Theme.createText({
	Name = "Tooltip", Parent = screenGui, Size = UDim2.fromOffset(260, 54),
	Bg = Theme.Colors.Navy, BgTransparency = 0.02, Corner = Theme.Corner.Medium,
	Text = "", TextSize = 13, Color = Theme.Colors.TextLight, Visible = false, ZIndex = 100,
})
tooltip.Visible = false
tooltip.Active = false
tooltip.Selectable = false
Theme.stroke(tooltip, Theme.Colors.Gold, 1.5, 0.3)
Theme.padding(tooltip, 8, 8, 10, 10)

local FLOAT_BTN_SIZE = 52
local FLOAT_BTN_GAP = 10
local FLOAT_BTN_RIGHT = safeEdge

local nav = Theme.createFrame({
	Name = "WindowToggles", Parent = screenGui,
	Size = UDim2.fromOffset(FLOAT_BTN_SIZE, 1),
	Position = UDim2.new(1, -FLOAT_BTN_RIGHT, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BgTransparency = 1,
})
Theme.makeInputTransparent(nav)
nav.AutomaticSize = Enum.AutomaticSize.Y
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Vertical
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
navLayout.Padding = UDim.new(0, FLOAT_BTN_GAP)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = nav

-- Keys here double as UIBridge panel ids (openPanel/closePanel below resolve the panel's
-- own Open/Close through UIBridge.RegisterPanel by this same key, so there is one place —
-- the owning script's RegisterPanel call — that says what a panel's opener/closer are,
-- not a second copy of opener/closer name strings here.
local windows = {
	EggShop = { label = "Egg Shop", gui = "EggShopUI", panel = "EggShopPanel", dim = "DimBackground", icon = Theme.Icons.Egg },
	Dragons = { label = "Dragons", gui = "DragonRosterUI", panel = "DragonRosterPanel", dim = "DimBackground", icon = Theme.Icons.Dragon },
	DragonMerge = { label = "Merge", gui = "DragonMergeUI", panel = "DragonMergePanel", dim = "DimBackground", icon = Theme.Icons.Merge },
	DragonTraining = { label = "Academy", gui = "DragonTrainingUI", panel = "DragonTrainingPanel", dim = "DimBackground", icon = Theme.Icons.Book },
	Workshop = { label = "Workshop", gui = "WorkshopCraftUI", panel = "CraftPanel", dim = "DimBackground", icon = Theme.Icons.Hammer, enabledKey = true },
	Buildings = { label = "Buildings", gui = "BuildingUpgradeUI", panel = "BuildingPanel", dim = "DimBackground", icon = Theme.Icons.House },
	DailyQuests = { label = "Quests", gui = "DailyQuestUI", panel = "QuestPanel", dim = "DimBackground", icon = Theme.Icons.Scroll },
	Achievements = { label = "Achievements", gui = "AchievementUI", panel = "AchievementPanel", dim = "DimBackground", icon = Theme.Icons.Trophy },
	Rebirth = { label = "Ascension", gui = "RebirthUI", panel = "RebirthPanel", dim = "DimBackground", icon = Theme.Icons.Rebirth },
	-- Not part of navOrder (no nav button): opened only by its own popup event, but registered
	-- here so Escape's closeTopWindow can find and close it instead of falling through to the
	-- releaseAllInput fallback, which never actually hides the panel.
	StorageFull = { label = "Storage Full", gui = "DragonStorageFullUI", panel = "StorageFullPanel", dim = "DimBackground" },
}

local navButtons = {}
local windowStack = {}
local activeNotifications = {}
local lastEssence = nil
local essenceNotification = nil
local essenceStackTotal = 0
local ESSENCE_NOTIFY_DURATION = 3.2

local function formatCompact(value)
	return Theme.formatCompact(value)
end

local function getPanel(info)
	local gui = playerGui:FindFirstChild(info.gui)
	if not gui then return nil, nil end
	local panel = gui:FindFirstChild(info.panel, true)
	return gui, panel
end

local function isPanelVisible(info)
	local gui, panel = getPanel(info)
	if info.enabledKey and gui then return gui.Enabled == true end
	return panel and panel:IsA("GuiObject") and panel.Visible
end

local function setNavInputEnabled(enabled)
	for _, btn in navButtons do
		btn.Active = enabled
		btn.Selectable = enabled
	end
	nav.Active = enabled
end

-- Modal registry state now lives in UIBridge (single source of truth for
-- every script that reports/queries "is a panel open"), this file only
-- owns the side effects of that state changing.
UIBridge.Subscribe("ModalLockChanged", function(locked, openNames)
	setNavInputEnabled(not locked)
	Theme.setModalLock(playerGui, locked, openNames)
	if _G.DragonIslandSetTutorialSuppressed then
		_G.DragonIslandSetTutorialSuppressed(locked)
	end
	if _G.DragonIslandSetWorldPanelsSuppressed then
		_G.DragonIslandSetWorldPanelsSuppressed(locked)
	end
end)

local function registerModalOpen(guiName)
	UIBridge.NotifyModalOpened(guiName)
end

local function registerModalClosed(guiName)
	UIBridge.NotifyModalClosed(guiName)
end

local function setNavHighlights(activeKey)
	for key, btn in navButtons do
		Theme.setFloatingNavActive(btn, key == activeKey and isPanelVisible(windows[key]))
	end
end

local function pushWindow(key)
	for index = #windowStack, 1, -1 do
		if windowStack[index] == key then table.remove(windowStack, index) end
	end
	table.insert(windowStack, key)
end

local function closePanel(key, info)
	if UIBridge.ClosePanel(key) then
		return
	end
	-- Fallback for a panel that somehow isn't registered yet (e.g. load-order edge case):
	-- manipulate its GUI directly instead of doing nothing.
	local gui, panel = getPanel(info)
	if not gui then
		return
	end
	local dim = info.dim and gui:FindFirstChild(info.dim, true)
	Theme.closeModalWindow(gui, panel, dim, function()
		UIBridge.NotifyModalClosed(gui.Name)
	end)
end

local function openPanel(key, info)
	-- No filler message: openEggShop/openTrainingUI/openMergeUI/openRoster already fall back
	-- to their own more useful default hint (or capacity subtitle, for Roster) when message is
	-- nil. Passing a generic "Opened from navigation." string here would overwrite that.
	if UIBridge.OpenPanel(key) then
		return
	end
	local gui, panel = getPanel(info)
	if info.enabledKey and gui then
		Theme.raiseModalGui(gui)
		gui.Enabled = true
		registerModalOpen(gui.Name)
		return
	end
	if not panel then return end
	local dim = gui and info.dim and gui:FindFirstChild(info.dim)
	Theme.raiseModalGui(gui)
	registerModalOpen(gui.Name)
	Theme.tweenOpen(panel, dim)
end

local function setWindow(key, visible)
	local info = windows[key]
	if not info then return end
	if visible then openPanel(key, info) pushWindow(key) else closePanel(key, info) end
	task.defer(setNavHighlights)
end

local function closeTopWindow()
	for index = #windowStack, 1, -1 do
		local key = windowStack[index]
		if windows[key] and isPanelVisible(windows[key]) then
			setWindow(key, false)
			table.remove(windowStack, index)
			return true
		end
		table.remove(windowStack, index)
	end
	for key, info in pairs(windows) do
		if isPanelVisible(info) then setWindow(key, false) return true end
	end
	return false
end

local function layoutNotifications()
	for index, popup in activeNotifications do
		local offsetY = (index - 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_GAP)
		TweenService:Create(popup, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, 0, 1, -(offsetY + NOTIFICATION_HEIGHT)),
		}):Play()
	end
end

local function removeActiveNotification(popup)
	for index, activePopup in activeNotifications do
		if activePopup == popup then
			table.remove(activeNotifications, index)
			break
		end
	end
end

local function fadeEssenceNotification()
	if not essenceNotification or not essenceNotification.Parent then
		essenceNotification = nil
		essenceStackTotal = 0
		return
	end
	if essenceNotification:GetAttribute("Fading") == true then
		return
	end
	essenceNotification:SetAttribute("Fading", true)
	local popup = essenceNotification
	local current = popup.Position
	TweenService:Create(popup, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = current + UDim2.fromOffset(0, -18),
		TextTransparency = 1,
		BackgroundTransparency = 1,
	}):Play()
	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.28), { Transparency = 1 }):Play()
	end
	task.delay(0.3, function()
		if popup.Parent then
			popup:Destroy()
		end
		if essenceNotification == popup then
			essenceNotification = nil
			essenceStackTotal = 0
		end
	end)
end

local function showEssenceGain(amount)
	local gain = math.floor(tonumber(amount) or 0)
	if gain <= 0 then
		return
	end

	if essenceNotification and essenceNotification.Parent then
		essenceStackTotal += gain
		essenceNotification.Text = "+" .. formatCompact(essenceStackTotal) .. " Dragon Essence"
		essenceNotification:SetAttribute("ExpiresAt", time() + ESSENCE_NOTIFY_DURATION)
		essenceNotification:SetAttribute("Fading", false)
		essenceNotification.TextTransparency = 0
		essenceNotification.BackgroundTransparency = 0.05
		local stroke = essenceNotification:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.5
		end
		return
	end

	essenceStackTotal = gain
	local popup = Theme.createText({
		Name = "EssenceNotification", Parent = notifications,
		Size = UDim2.fromOffset(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT),
		Text = "+" .. formatCompact(essenceStackTotal) .. " Dragon Essence",
		Bg = Theme.Colors.Navy, BgTransparency = 0.05, Corner = Theme.Corner.Medium,
		TextSize = 14, Color = Theme.Colors.TextGold, ZIndex = 21,
	})
	popup.AnchorPoint = Vector2.new(1, 1)
	popup.Position = UDim2.new(1, 72, 1, 24)
	popup.TextTransparency = 1
	Theme.stroke(popup, Theme.Colors.GoldBright, 1.5, 0.5)
	popup:SetAttribute("ExpiresAt", time() + ESSENCE_NOTIFY_DURATION)
	essenceNotification = popup
	TweenService:Create(popup, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 0, 1, -NOTIFICATION_HEIGHT),
		TextTransparency = 0,
		BackgroundTransparency = 0.05,
	}):Play()
end

local function fadeNotification(popup)
	if popup:GetAttribute("Fading") == true then return end
	popup:SetAttribute("Fading", true)
	local current = popup.Position
	TweenService:Create(popup, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = current + UDim2.fromOffset(0, -18),
		TextTransparency = 1,
		BackgroundTransparency = 1,
	}):Play()
	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.28), { Transparency = 1 }):Play()
	end
	task.delay(0.3, function()
		removeActiveNotification(popup)
		if popup.Parent then popup:Destroy() end
		layoutNotifications()
	end)
end

local function notify(message, color)
	while #activeNotifications >= NOTIFICATION_MAX do
		fadeNotification(activeNotifications[1])
		break
	end

	local popup = Theme.createText({
		Name = "Notification", Parent = notifications, Size = UDim2.fromOffset(NOTIFICATION_WIDTH, NOTIFICATION_HEIGHT), Text = tostring(message or ""),
		Bg = Theme.Colors.Navy, BgTransparency = 0.05, Corner = Theme.Corner.Medium,
		TextSize = 14, Color = Theme.Colors.TextGold, ZIndex = 21,
	})
	popup.AnchorPoint = Vector2.new(1, 1)
	popup.Position = UDim2.new(1, 72, 1, 24)
	popup.TextTransparency = 1
	Theme.stroke(popup, Theme.Colors.GoldBright, 1.5, 0.5)
	popup:SetAttribute("ExpiresAt", time() + 3.2)
	table.insert(activeNotifications, popup)
	layoutNotifications()
	TweenService:Create(popup, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 0, 1, -(#activeNotifications - 1) * (NOTIFICATION_HEIGHT + NOTIFICATION_GAP) - NOTIFICATION_HEIGHT),
		TextTransparency = 0,
		BackgroundTransparency = 0.05,
	}):Play()
end

local extrasGui
local extrasPanel
local extrasTitle
local extrasBody
local extrasActions

local function closeExtrasPanel()
	if not extrasGui or not extrasPanel then
		return
	end
	local dim = extrasGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(extrasGui, extrasPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(extrasGui.Name)
		end
	end)
end

local function ensureExtrasGui()
	if extrasGui then
		return
	end
	extrasGui = Instance.new("ScreenGui")
	extrasGui.Name = "DragonExtrasUI"
	extrasGui.ResetOnSpawn = false
	extrasGui.DisplayOrder = 40
	extrasGui.Enabled = false
	extrasGui.Parent = playerGui
	Theme.applyScreenSafeArea(extrasGui)
	local dim = Theme.createDim(extrasGui, 1)
	dim.Name = "DimBackground"
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeExtrasPanel()
		end
	end)
	extrasPanel = Theme.createPanel({ Name = "ExtrasPanel", Parent = extrasGui, Size = UDim2.fromOffset(440, 360), Visible = false, ZIndex = 25 })
	extrasPanel:SetAttribute("OpenPosition", extrasPanel.Position)
	Theme.createCloseButton(extrasPanel, function()
		closeExtrasPanel()
	end, 30)
	local header = Theme.createWindowHeader(extrasPanel, "Panel", nil, 30)
	extrasTitle = header:FindFirstChild("Title")
	extrasBody = Theme.createText({
		Name = "Body", Parent = extrasPanel, Size = UDim2.new(1, -32, 0, 140),
		Position = UDim2.fromOffset(16, 72), TextSize = 15, Font = Theme.Fonts.Body,
		Color = Theme.Colors.TextMuted, YAlign = Enum.TextYAlignment.Top, ZIndex = 8,
	})
	extrasActions = Theme.createFrame({
		Name = "Actions", Parent = extrasPanel,
		Size = UDim2.new(1, -32, 0, 120), Position = UDim2.fromOffset(16, 220),
		BgTransparency = 1, ZIndex = 8,
	})
	local actionLayout = Instance.new("UIListLayout")
	actionLayout.Padding = UDim.new(0, 10)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = extrasActions
end

local function openExtrasPanel(title, body, actions)
	ensureExtrasGui()
	for _, child in extrasActions:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local dim = extrasGui:FindFirstChild("DimBackground")
	extrasTitle.Text = title
	extrasBody.Text = body
	if typeof(actions) == "table" then
		for index, action in actions do
			Theme.createButton({
				Name = action.Name or ("Action" .. tostring(index)),
				Parent = extrasActions,
				Text = action.Text,
				Size = UDim2.new(1, 0, 0, 44),
				Bg = action.Bg or Theme.Colors.NavyEdge,
				TextSize = 15,
				LayoutOrder = index,
				ZIndex = 9,
				OnClick = function()
					if action.OnClick then
						action.OnClick()
					end
					if action.CloseOnClick ~= false then
						closeExtrasPanel()
					end
				end,
			})
		end
	end
	extrasGui.Enabled = true
	Theme.raiseModalGui(extrasGui)
	registerModalOpen(extrasGui.Name)
	Theme.tweenOpen(extrasPanel, dim)
end

_G.DragonIslandOpenSettings = function()
	openExtrasPanel(
		"Settings",
		"Gameplay helpers and preferences. Lost the tutorial guide? Use the \"Resume Tutorial\" chip in the corner of the screen instead of restarting.",
		{
			{
				Name = "ReplayTutorialButton",
				Text = "Restart Tutorial from Step 1",
				Bg = Theme.Colors.Crystal,
				CloseOnClick = false,
				OnClick = function()
					openExtrasPanel(
						"Restart Tutorial?",
						"This restarts the guided tour from Step 1 and re-plays every step. If the tutorial guide just went missing, close this and use the \"Resume Tutorial\" chip instead — it brings back your current step without losing progress.",
						{
							{
								Name = "ConfirmRestartTutorial",
								Text = "Yes, Restart from Step 1",
								Bg = Theme.Colors.Danger,
								OnClick = function()
									if _G.DragonIslandReplayTutorial then
										_G.DragonIslandReplayTutorial()
									end
								end,
							},
							{
								Name = "CancelRestartTutorial",
								Text = "Cancel",
							},
						}
					)
				end,
			},
		}
	)
end
_G.DragonIslandOpenMail = function() openExtrasPanel("Mail", "No new mail yet. Quest rewards and event gifts will show up here.") end
_G.DragonIslandOpenDailyReward = function() openExtrasPanel("Daily Rewards", "Your daily reward is ready! Claim streak bonuses for consecutive logins.") end

local navOrder = { "EggShop", "Dragons", "DragonMerge", "DragonTraining", "Workshop", "Buildings", "DailyQuests", "Achievements", "Rebirth" }
local order = 1
for _, key in navOrder do
	local info = windows[key]
	local btn = Theme.createFloatingNavButton({
		Name = key .. "Toggle",
		Parent = nav,
		Image = info.icon,
		LayoutOrder = order,
		OnClick = function()
			local visible = isPanelVisible(info)
			if visible then setWindow(key, false) else
				for otherKey, otherInfo in pairs(windows) do
					if otherKey ~= key and isPanelVisible(otherInfo) then setWindow(otherKey, false) end
				end
				setWindow(key, true)
			end
			setNavHighlights(visible and nil or key)
		end,
	})
	navButtons[key] = btn
	order += 1
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode ~= Enum.KeyCode.Escape then
		return
	end
	if _G.DragonIslandCloseTutorialReward and _G.DragonIslandCloseTutorialReward() then
		return
	end
	if closeTopWindow() then
		return
	end
	if UIBridge.IsModalOpen() or processed then
		Theme.releaseAllInput(playerGui)
	end
end)

HarvestUIUpdate.OnClientEvent:Connect(function(essence)
	if typeof(essence) == "number" then
		if lastEssence and essence > lastEssence then
			showEssenceGain(essence - lastEssence)
		end
		lastEssence = essence
	end
end)

EggShopUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and typeof(payload.message) == "string" and payload.message ~= "" then notify(payload.message, Theme.Colors.Navy) end
end)

DragonMergeUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and typeof(payload.message) == "string" and payload.message ~= "" then
		notify(payload.message, Theme.Colors.Navy)
	end
end)

local questReady = {}
QuestUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.Quests) ~= "table" then return end
	for _, quest in payload.Quests do
		local wasReady = questReady[quest.Id]
		questReady[quest.Id] = quest.ReadyToClaim == true and quest.Claimed ~= true
		if questReady[quest.Id] and not wasReady then notify("Quest complete: " .. tostring(quest.Title or "Daily Quest"), Theme.Colors.Navy)
		elseif quest.Claimed and wasReady then notify("Quest reward claimed", Theme.Colors.Navy) end
	end
end)

task.spawn(function()
	while screenGui.Parent do
		local now = time()
		if essenceNotification and essenceNotification.Parent then
			local expiresAt = essenceNotification:GetAttribute("ExpiresAt")
			if typeof(expiresAt) == "number" and now >= expiresAt then
				fadeEssenceNotification()
			end
		end
		if #activeNotifications > 0 then
			for _, popup in activeNotifications do
				local expiresAt = popup:GetAttribute("ExpiresAt")
				if typeof(expiresAt) == "number" and now >= expiresAt then fadeNotification(popup) end
			end
		end
		task.wait(0.2)
	end
end)

_G.DragonIslandNotify = function(message, color)
	UIBridge.Notify(message, color)
end

UIBridge.Subscribe("Notify", notify)

-- DragonIslandFormatCompact removed: it was a re-export of Theme.formatCompact with zero
-- external callers (every client script already requires DragonUITheme directly).

_G.DragonIslandIsModalOpen = UIBridge.IsModalOpen

_G.DragonIslandResetModalRegistry = UIBridge.ResetModalRegistry

_G.DragonIslandForceReleaseInput = function()
	Theme.releaseAllInput(playerGui)
end

_G.DragonIslandNotifyModalOpened = function(guiName)
	registerModalOpen(guiName)
end

_G.DragonIslandNotifyModalClosed = function(guiName)
	registerModalClosed(guiName)
end
