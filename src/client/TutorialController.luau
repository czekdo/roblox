local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage:WaitForChild("DragonUITheme"))
local TutorialData = require(ReplicatedStorage:WaitForChild("TutorialData"))
local TutorialStep = require(script.Parent:WaitForChild("TutorialStep"))
local TutorialUI = require(script.Parent:WaitForChild("TutorialUI"))

local TutorialEvents = ReplicatedStorage:WaitForChild("TutorialEvents")
local RequestTutorialState = TutorialEvents:WaitForChild("RequestTutorialState")
local TutorialStepCompleted = TutorialEvents:WaitForChild("TutorialStepCompleted")
local TutorialStateUpdated = TutorialEvents:WaitForChild("TutorialStateUpdated")
local TutorialSkipRequest = TutorialEvents:WaitForChild("TutorialSkipRequest")
local TutorialReplayRequest = TutorialEvents:WaitForChild("TutorialReplayRequest")

local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local HarvestHit = HarvestEvents:WaitForChild("HarvestHit")
local EggHatched = HarvestEvents:WaitForChild("EggHatched")
local EggShopUpdate = HarvestEvents:WaitForChild("EggShopUpdate")
local DragonMergeUpdate = HarvestEvents:WaitForChild("DragonMergeUpdate")
local DragonTrainingUpdate = HarvestEvents:WaitForChild("DragonTrainingUpdate")
local HarvestUIUpdate = HarvestEvents:WaitForChild("HarvestUIUpdate")

local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestUpdate = QuestEvents:WaitForChild("QuestUpdate")
local BuildingEvents = ReplicatedStorage:WaitForChild("BuildingEvents")
local BuildingStateUpdated = BuildingEvents:WaitForChild("BuildingStateUpdated")
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local IslandUnlockFeedback = IslandEvents:WaitForChild("IslandUnlockFeedback")

local TutorialController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = nil
local ui = nil
local suppressed = false
local rewardDismissed = false
local lastActiveCount = 0
local lastTrainingSessions = 0
local lastKingdomLevel = player:GetAttribute("KingdomLevel") or 1
local unlockedIslands = {}
local buildingLevels = {}

local function getActiveStepId()
	return state and state.activeStep and state.activeStep.Id or nil
end

local function isCompleted()
	return state and state.completed == true
end

local function completeStep(stepId)
	if isCompleted() or getActiveStepId() ~= stepId then
		return
	end
	TutorialStepCompleted:FireServer(stepId)
end

local function shouldShowGuide()
	return not suppressed and not ui:isRewardVisible() and not isCompleted() and state and state.activeStep
end

local function refreshGuide()
	local stepId = getActiveStepId()
	if isCompleted() or not stepId then
		ui:hideGuide()
		ui:setResumeChipVisible(false)
		return
	end
	if ui:isPaused() or ui:isRewardVisible() then
		ui:hideGuide()
		ui:setResumeChipVisible(false)
		return
	end
	if suppressed then
		ui:hideGuide()
		local stepCount = state.stepCount or #(state.steps or {})
		ui:setResumeChipVisible(true, string.format("Resume Tutorial (Step %d/%d)", state.currentStep or 1, stepCount))
		return
	end
	ui:setResumeChipVisible(false)
	local showNext = TutorialStep.isInfoStep(stepId)
	local target = TutorialStep.findTargetForStep(playerGui, stepId)
	ui:updateStep(state, target, showNext)
end

local function handleInfoAutoComplete()
	local stepId = getActiveStepId()
	if not stepId then
		return
	end
	if TutorialStep.shouldAutoCompleteInfo(playerGui, stepId) then
		completeStep(stepId)
	end
end

local function applyState(payload, source)
	if typeof(payload) ~= "table" then
		return
	end

	local wasCompleted = state and state.completed == true
	local previousStep = state and state.currentStep or 0
	local previousStepId = getActiveStepId()
	state = payload
	player:SetAttribute("TutorialCompleted", payload.completed == true)
	player:SetAttribute("TutorialStep", payload.currentStep or 1)

	if payload.stepRewardText and source == "live" and (payload.currentStep or 0) > previousStep then
		ui:showStepReward(payload.stepRewardText)
	end

	if source == "live" and not suppressed and payload.completed ~= true and payload.activeStep
		and payload.activeStep.Id ~= previousStepId then
		ui:showNewGoalToast(payload.activeStep.Title)
	end

	if payload.completed == true then
		if source == "live" and not wasCompleted and not rewardDismissed and not payload.skipped then
			if payload.rewardsDisabled then
				ui:hideGuide()
				if _G.DragonIslandNotify then
					_G.DragonIslandNotify(payload.message or "Tutorial replay complete!", Theme.Colors.Success)
				end
				rewardDismissed = true
				ui:shutdown()
			else
				ui:showCompletionPanel(payload.completionReward, payload.message)
			end
		else
			rewardDismissed = true
			ui:shutdown()
		end
	else
		rewardDismissed = false
		refreshGuide()
	end
end

local function detectBuildingProgress(newState)
	local stepId = getActiveStepId()
	if typeof(newState) ~= "table" then
		return
	end
	if stepId == "UpgradeKingdom" and typeof(newState.message) == "string" then
		if string.find(newState.message, "Unlocked", 1, true) or string.find(newState.message, "Upgraded", 1, true) then
			completeStep("UpgradeKingdom")
			return
		end
	end
	if typeof(newState.buildings) ~= "table" then
		return
	end
	for _, building in newState.buildings do
		local typeId = building.typeId
		local level = tonumber(building.level) or 1
		local previous = buildingLevels[typeId] or 1
		buildingLevels[typeId] = level
		if stepId == "UpgradeKingdom" and building.unlocked and level > previous then
			completeStep("UpgradeKingdom")
			return
		end
	end
end

local function connectSignals()
	HarvestUIUpdate.OnClientEvent:Connect(function(_essence, activeCount)
		if typeof(activeCount) == "number" then
			if getActiveStepId() == "EquipFirstDragon" and activeCount > lastActiveCount and activeCount > 0 then
				completeStep("EquipFirstDragon")
			end
			lastActiveCount = activeCount
		end
	end)

	EggShopUpdate.OnClientEvent:Connect(function(payload)
		if getActiveStepId() == "BuyFirstEgg" and typeof(payload) == "table" then
			local owned = payload.ownedEggs or (payload.eggStats and payload.eggStats.OwnedEggs) or {}
			for _, count in owned do
				if tonumber(count) and tonumber(count) > 0 then
					completeStep("BuyFirstEgg")
					return
				end
			end
		end
	end)

	EggHatched.OnClientEvent:Connect(function()
		if getActiveStepId() == "HatchFirstDragon" then
			completeStep("HatchFirstDragon")
		end
	end)

	HarvestHit.OnClientEvent:Connect(function()
		-- Fires only on a real harvest hit, unlike the DragonEssence attribute (which every
		-- reward source, including this tutorial's own step rewards, also mutates) — so it can't
		-- be falsely triggered by a reward landing right as a step becomes active.
		local stepId = getActiveStepId()
		if stepId == "CollectDragonEssence" or stepId == "HarvestWithDragon" then
			completeStep(stepId)
		end
	end)

	DragonTrainingUpdate.OnClientEvent:Connect(function(payload)
		if getActiveStepId() ~= "TrainFirstDragon" or typeof(payload) ~= "table" then
			return
		end
		local sessions = payload.sessions or {}
		if #sessions > lastTrainingSessions then
			completeStep("TrainFirstDragon")
		end
		lastTrainingSessions = #sessions
	end)

	DragonMergeUpdate.OnClientEvent:Connect(function(payload)
		if getActiveStepId() ~= "MergeDragons" or typeof(payload) ~= "table" then
			return
		end
		local message = string.lower(tostring(payload.message or ""))
		if string.find(message, "merged", 1, true) or string.find(message, "evolved", 1, true) then
			completeStep("MergeDragons")
		end
	end)

	BuildingStateUpdated.OnClientEvent:Connect(detectBuildingProgress)

	IslandUnlockFeedback.OnClientEvent:Connect(function(payload)
		if getActiveStepId() ~= "UnlockSecondIsland" or typeof(payload) ~= "table" or payload.success ~= true then
			return
		end
		if typeof(payload.islandId) == "string" then
			unlockedIslands[payload.islandId] = true
			completeStep("UnlockSecondIsland")
		end
	end)

	QuestUpdate.OnClientEvent:Connect(function()
		if getActiveStepId() == "ExplainDailyQuests" then
			handleInfoAutoComplete()
		end
	end)

	player:GetAttributeChangedSignal("KingdomLevel"):Connect(function()
		local level = player:GetAttribute("KingdomLevel") or 1
		if getActiveStepId() == "UpgradeKingdom" and level > lastKingdomLevel then
			completeStep("UpgradeKingdom")
		end
		lastKingdomLevel = level
	end)
end

function TutorialController.init()
	ui = TutorialUI.new(playerGui)

	ui.onNext = function()
		local stepId = getActiveStepId()
		if stepId and TutorialStep.isInfoStep(stepId) then
			completeStep(stepId)
		end
	end

	ui.onSkipConfirm = function()
		TutorialSkipRequest:FireServer()
	end

	ui.onResume = function()
		suppressed = false
		refreshGuide()
	end

	connectSignals()

	TutorialStateUpdated.OnClientEvent:Connect(function(payload)
		applyState(payload, "live")
	end)

	local success, payload = pcall(function()
		return RequestTutorialState:InvokeServer()
	end)
	if success then
		applyState(payload, "initial")
	else
		warn("[TutorialController] Could not load tutorial state")
	end

	_G.DragonIslandSetTutorialSuppressed = function(value)
		suppressed = value == true
		refreshGuide()
	end

	_G.DragonIslandCloseTutorialReward = function()
		if ui:isRewardVisible() then
			ui:closeRewardPanel()
			rewardDismissed = true
			ui:shutdown()
			return true
		end
		return false
	end

	_G.DragonIslandReplayTutorial = function()
		TutorialReplayRequest:FireServer()
		rewardDismissed = false
		suppressed = false
		ui.screenGui.Enabled = true
	end

	RunService.RenderStepped:Connect(function(deltaTime)
		if not shouldShowGuide() or ui:isPaused() then
			return
		end
		local stepId = getActiveStepId()
		handleInfoAutoComplete()
		local target = TutorialStep.findTargetForStep(playerGui, stepId)
		ui:tick(deltaTime, target)
	end)
end

return TutorialController
