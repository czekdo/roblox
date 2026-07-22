local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local UIBridge = require(ReplicatedStorage:WaitForChild("UIBridge"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DragonTrainingConfig = require(ReplicatedStorage:WaitForChild("DragonTrainingConfig"))
local BuildingEvents = ReplicatedStorage:WaitForChild("BuildingEvents")
local BuildingStateUpdated = BuildingEvents:WaitForChild("BuildingStateUpdated")
local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local RequestDragonTrainingData = HarvestEvents:WaitForChild("RequestDragonTrainingData")
local StartDragonTraining = HarvestEvents:WaitForChild("StartDragonTraining")
local ClaimDragonTraining = HarvestEvents:WaitForChild("ClaimDragonTraining")
local CancelDragonTraining = HarvestEvents:WaitForChild("CancelDragonTraining")
local SkipDragonTraining = HarvestEvents:WaitForChild("SkipDragonTraining")
local DragonTrainingUpdate = HarvestEvents:WaitForChild("DragonTrainingUpdate")

local trainingGui = nil
local trainingPanel = nil
local dragonList = nil
local programList = nil
local sessionList = nil
local statusLabel = nil
local academyInfoLabel = nil
local startButton = nil
local selectedDragonId = nil
local selectedProgramId = DragonTrainingConfig.ProgramOrder[1]
local trainingState = {
	dragons = {},
	programs = {},
	sessions = {},
	maxSessions = 3,
	academyLevel = 1,
	trainingTimeMultiplier = 1,
	xpGainMultiplier = 1,
}

local function formatTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	if minutes >= 60 then
		local hours = math.floor(minutes / 60)
		minutes = minutes % 60
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, secs)
end

local function getSelectedDragon()
	for _, dragon in trainingState.dragons do
		if dragon.id == selectedDragonId then
			return dragon
		end
	end
	return nil
end

local function getSelectedProgram()
	for _, program in trainingState.programs do
		if program.id == selectedProgramId then
			return program
		end
	end
	return nil
end

local function isDragonTraining(dragonId)
	for _, session in trainingState.sessions do
		if session.dragonId == dragonId then
			return true
		end
	end
	return false
end

local function updateTrainingUI()
	if not trainingPanel then
		return
	end

	academyInfoLabel.Text = string.format(
		"Academy Lv. %d  •  Time x%.2f  •  XP x%.2f  •  Slots %d/%d",
		trainingState.academyLevel or 1,
		trainingState.trainingTimeMultiplier or 1,
		trainingState.xpGainMultiplier or 1,
		#trainingState.sessions,
		trainingState.maxSessions or 3
	)

	for _, child in dragonList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for index, dragon in trainingState.dragons do
		local busy = isDragonTraining(dragon.id)
		local row = Theme.createListRow(dragonList, {
			Name = "DragonRow_" .. tostring(dragon.id),
			Text = (dragon.displayName or dragon.dragonType) .. "  " .. (dragon.rarity or "Common") .. "\nLv. " .. tostring(dragon.level or 1) .. "  " .. (dragon.stars or "") .. (busy and "  • Training" or "  • " .. string.upper(dragon.state or "idle")),
			TextColor = Theme.getRarityColor(dragon.rarity),
			LayoutOrder = index,
			Height = 58,
			ZIndex = 9,
			OnClick = function()
				if busy then
					statusLabel.Text = "That dragon is already in training."
					return
				end
				selectedDragonId = dragon.id
				updateTrainingUI()
			end,
		})
		if busy then
			row.BackgroundColor3 = Theme.Colors.StoneDeep
		end
		Theme.setListRowSelected(row, selectedDragonId == dragon.id and not busy, Theme.Colors.Crystal)
	end

	for _, child in programList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	for index, program in trainingState.programs do
		local row = Theme.createListRow(programList, {
			Name = "Program_" .. program.id,
			Text = program.displayName .. "\n" .. formatTime(program.duration) .. "  •  +" .. tostring(program.levelReward) .. " Lv  •  +" .. tostring(program.essenceReward) .. " essence"
				.. ((program.essenceCost or 0) > 0 and ("\nCost: " .. tostring(program.essenceCost) .. " essence") or "\nFree training"),
			LayoutOrder = index,
			Height = 88,
			ZIndex = 9,
			OnClick = function()
				selectedProgramId = program.id
				updateTrainingUI()
			end,
		})
		Theme.setListRowSelected(row, selectedProgramId == program.id, program.color or Theme.Colors.Purple)
	end

	for _, child in sessionList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, session in trainingState.sessions do
		local card = Theme.createFrame({
			Name = "Session_" .. session.id, Parent = sessionList,
			Size = UDim2.new(1, -4, 0, 78), Bg = session.complete and Theme.Colors.SuccessDark or Theme.Colors.NavyEdge,
			Corner = Theme.Corner.Medium, LayoutOrder = index, ZIndex = 9,
		})
		Theme.stroke(card, Theme.Colors.Gold, 1.5, 0.45)

		local dragonName = session.dragon and (session.dragon.displayName or session.dragon.dragonType) or ("Dragon #" .. tostring(session.dragonId))
		local remaining = math.max(0, math.floor((session.endsAt or 0) - workspace:GetServerTimeNow()))
		local infoText
		if session.complete then
			infoText = dragonName .. "\nTraining complete! +" .. tostring(session.levelReward) .. " Lv, +" .. tostring(session.essenceReward) .. " essence"
		else
			infoText = dragonName .. "\nIn training — " .. formatTime(remaining) .. " left"
		end
		Theme.createText({
			Name = "Info", Parent = card, Text = infoText,
			Size = UDim2.new(1, -140, 1, -10), Position = UDim2.fromOffset(10, 8),
			TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, YAlign = Enum.TextYAlignment.Top, ZIndex = 10,
		})

		if session.complete then
			Theme.createButton({
				Name = "SessionAction", Parent = card, Text = "Claim",
				Size = UDim2.fromOffset(120, 36), Position = UDim2.new(1, -130, 0.5, -18),
				AnchorPoint = Vector2.new(0, 0.5), Bg = Theme.Colors.Success,
				TextSize = 14, ZIndex = 10,
				OnClick = function()
					ClaimDragonTraining:FireServer(session.id)
				end,
			})
		else
			Theme.createButton({
				Name = "SessionAction", Parent = card, Text = "Cancel",
				Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, -130, 0, 4),
				Bg = Theme.Colors.Danger, TextSize = 13, ZIndex = 10,
				OnClick = function()
					CancelDragonTraining:FireServer(session.id)
				end,
			})
			-- Gems sink: pay to instantly finish this session instead of waiting. Cost is priced
			-- off remaining time server-side (DragonTrainingManager.getSkipCost) and sent in
			-- session.skipCost each state update.
			Theme.createButton({
				Name = "SkipButton", Parent = card,
				Text = "Skip (" .. tostring(session.skipCost or 0) .. " Gems)",
				Size = UDim2.fromOffset(120, 34), Position = UDim2.new(1, -130, 0, 40),
				Bg = Theme.Colors.Gold, TextSize = 12, ZIndex = 10,
				OnClick = function()
					SkipDragonTraining:FireServer(session.id)
				end,
			})
		end
	end

	local dragon = getSelectedDragon()
	local program = getSelectedProgram()
	local canStart = dragon and program and not isDragonTraining(dragon.id) and #trainingState.sessions < (trainingState.maxSessions or 3)
	startButton.Active = canStart == true
	startButton.AutoButtonColor = canStart == true
	startButton.BackgroundColor3 = canStart and Theme.Colors.Success or Theme.Colors.Slate
	if dragon and program then
		startButton.Text = "Start " .. program.displayName .. " with " .. (dragon.displayName or dragon.dragonType)
	else
		startButton.Text = "Select a dragon and training program"
	end
end

local function applyTrainingPayload(payload)
	if typeof(payload) ~= "table" then
		return
	end
	trainingState.dragons = payload.dragons or trainingState.dragons
	trainingState.programs = payload.programs or trainingState.programs
	trainingState.sessions = payload.sessions or trainingState.sessions
	trainingState.maxSessions = payload.maxSessions or trainingState.maxSessions
	trainingState.academyLevel = payload.academyLevel or trainingState.academyLevel
	trainingState.trainingTimeMultiplier = payload.trainingTimeMultiplier or trainingState.trainingTimeMultiplier
	trainingState.xpGainMultiplier = payload.xpGainMultiplier or trainingState.xpGainMultiplier
	if payload.message and statusLabel then
		statusLabel.Text = payload.message
	end
	if selectedDragonId then
		local stillExists = false
		for _, dragon in trainingState.dragons do
			if dragon.id == selectedDragonId then
				stillExists = true
				break
			end
		end
		if not stillExists then
			selectedDragonId = nil
		end
	end
	updateTrainingUI()
end

local function closeTrainingUI()
	if not trainingGui or not trainingPanel then
		return
	end
	local dim = trainingGui:FindFirstChild("DimBackground")
	Theme.closeModalWindow(trainingGui, trainingPanel, dim, function()
		if _G.DragonIslandNotifyModalClosed then
			_G.DragonIslandNotifyModalClosed(trainingGui.Name)
		end
	end)
end

local function createTrainingUI()
	if trainingGui then
		return
	end

	trainingGui = Instance.new("ScreenGui")
	trainingGui.Name = "DragonTrainingUI"
	trainingGui.ResetOnSpawn = false
	trainingGui.IgnoreGuiInset = true
	trainingGui.DisplayOrder = 36
	trainingGui.Enabled = false
	trainingGui.Parent = playerGui

	local dim = Theme.createDim(trainingGui, 1)
	dim.Name = "DimBackground"
	dim.Visible = false
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			closeTrainingUI()
		end
	end)

	trainingPanel = Theme.createPanel({
		Name = "DragonTrainingPanel", Parent = trainingGui,
		Size = UDim2.fromOffset(920, 620), Visible = false,
	})
	trainingPanel:SetAttribute("OpenPosition", trainingPanel.Position)
	Theme.createCloseButton(trainingPanel, function()
		closeTrainingUI()
	end, 30)
	Theme.createWindowHeader(trainingPanel, "Dragon Academy", "Send dragons to train while you harvest", 8)

	academyInfoLabel = Theme.createText({
		Name = "AcademyInfo", Parent = trainingPanel, Text = "Academy bonuses loading...",
		Size = UDim2.new(1, -36, 0, 22), Position = UDim2.fromOffset(18, 68),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.CrystalSoft, ZIndex = 8,
	})

	dragonList = Theme.createScrollList(trainingPanel, UDim2.fromOffset(280, 430), UDim2.fromOffset(18, 98), 8)
	dragonList.Name = "DragonList"

	Theme.createText({
		Name = "ProgramsTitle", Parent = trainingPanel, Text = "Training Programs",
		Size = UDim2.fromOffset(280, 22), Position = UDim2.fromOffset(314, 98),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = 8,
	})

	programList = Theme.createScrollList(trainingPanel, UDim2.fromOffset(280, 300), UDim2.fromOffset(314, 124), 8)
	programList.Name = "ProgramList"

	Theme.createText({
		Name = "SessionsTitle", Parent = trainingPanel, Text = "Active Training",
		Size = UDim2.fromOffset(280, 22), Position = UDim2.fromOffset(614, 98),
		TextSize = 15, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextLight, ZIndex = 8,
	})

	sessionList = Theme.createScrollList(trainingPanel, UDim2.fromOffset(288, 430), UDim2.fromOffset(614, 124), 8)
	sessionList.Name = "SessionList"

	startButton = Theme.createButton({
		Name = "StartTrainingButton", Parent = trainingPanel,
		Text = "Select a dragon and training program",
		Size = UDim2.fromOffset(576, 48), Position = UDim2.fromOffset(314, 438),
		Bg = Theme.Colors.Success, TextSize = 16, ZIndex = 8,
	})

	statusLabel = Theme.createText({
		Name = "Status", Parent = trainingPanel,
		Text = "Send dragons to the Academy to level them up while you keep harvesting with the rest.",
		Size = UDim2.new(1, -36, 0, 28), Position = UDim2.new(0, 18, 1, -42),
		TextSize = 13, Font = Theme.Fonts.Bold, Color = Theme.Colors.TextGold,
		XAlign = Enum.TextXAlignment.Center, ZIndex = 8,
	})

	startButton.Activated:Connect(function()
		if startButton.Active and selectedDragonId and selectedProgramId then
			statusLabel.Text = "Starting training..."
			StartDragonTraining:FireServer(selectedDragonId, selectedProgramId)
		end
	end)

	updateTrainingUI()
end

local function openTrainingUI(message)
	createTrainingUI()
	trainingGui.Enabled = true
	local success, payload = pcall(function()
		return RequestDragonTrainingData:InvokeServer()
	end)
	if success then
		applyTrainingPayload(payload)
	elseif statusLabel then
		statusLabel.Text = "Could not load training data."
	end
	local dim = trainingGui:FindFirstChild("DimBackground")
	local opening = trainingPanel and not trainingPanel.Visible
	if opening then
		Theme.raiseModalGui(trainingGui)
		if _G.DragonIslandNotifyModalOpened then
			_G.DragonIslandNotifyModalOpened(trainingGui.Name)
		end
	end
	Theme.tweenOpen(trainingPanel, dim)
	if message and statusLabel then
		statusLabel.Text = message
	end
	updateTrainingUI()
end

_G.DragonIslandOpenTrainingUI = openTrainingUI
_G.DragonIslandCloseTrainingUI = closeTrainingUI

UIBridge.RegisterPanel("DragonTraining", { Open = openTrainingUI, Close = closeTrainingUI })

_G.DragonIslandOpenTrainingForDragon = function(dragonId, message)
	openTrainingUI(message or "Choose a training program for your dragon.")
	if typeof(dragonId) == "number" then
		selectedDragonId = dragonId
		updateTrainingUI()
	end
end

createTrainingUI()

DragonTrainingUpdate.OnClientEvent:Connect(function(payload)
	applyTrainingPayload(payload)
	if payload and payload.message and _G.DragonIslandNotify then
		local lower = string.lower(payload.message)
		if string.find(lower, "complete", 1, true) or string.find(lower, "claimed", 1, true) or string.find(lower, "started", 1, true) then
			_G.DragonIslandNotify(payload.message, Theme.Colors.Navy)
		end
	end
end)

BuildingStateUpdated.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local academyChanged = false
	for _, building in payload.buildings or {} do
		if building.typeId == "DragonAcademy" then
			academyChanged = true
			break
		end
	end
	if not academyChanged then
		return
	end
	local success, trainingPayload = pcall(function()
		return RequestDragonTrainingData:InvokeServer()
	end)
	if success then
		applyTrainingPayload(trainingPayload)
		if trainingPanel and trainingPanel.Visible and payload.message and string.find(payload.message, "Upgraded", 1, true) and statusLabel then
			statusLabel.Text = "Academy upgraded! Training is faster with bigger XP rewards."
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local ownerUserId = prompt.Parent and prompt.Parent:GetAttribute("OwnerUserId")
	if ownerUserId and ownerUserId ~= player.UserId then
		return
	end
	if prompt.Name == "DragonTrainingPrompt" then
		openTrainingUI("Choose a dragon and training program at the Academy.")
	end
end)

task.spawn(function()
	while trainingGui and trainingGui.Parent do
		if trainingPanel and trainingPanel.Visible and #trainingState.sessions > 0 then
			updateTrainingUI()
		end
		task.wait(1)
	end
end)