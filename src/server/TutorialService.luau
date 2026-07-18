local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local TutorialData = require(ReplicatedStorage:WaitForChild("TutorialData"))
local TutorialEvents = ReplicatedStorage:WaitForChild("TutorialEvents")
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))

local RequestTutorialState = TutorialEvents:WaitForChild("RequestTutorialState")
local TutorialStepCompleted = TutorialEvents:WaitForChild("TutorialStepCompleted")
local TutorialStateUpdated = TutorialEvents:WaitForChild("TutorialStateUpdated")
local TutorialProgressSignal = TutorialEvents:WaitForChild("TutorialProgressSignal")
local TutorialSkipRequest = TutorialEvents:WaitForChild("TutorialSkipRequest")
local TutorialReplayRequest = TutorialEvents:WaitForChild("TutorialReplayRequest")
local GrantTutorialRewardEgg = TutorialEvents:WaitForChild("GrantTutorialRewardEgg")

local TutorialService = {}

local tutorialStore = nil
local legacyStore = nil
local dataStoreAvailable = false

if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(TutorialData.DATASTORE_NAME)
	end)
	if success then
		tutorialStore = result
		dataStoreAvailable = true
		local legacySuccess, legacyResult = pcall(function()
			return DataStoreService:GetDataStore(TutorialData.LEGACY_DATASTORE_NAME)
		end)
		if legacySuccess then
			legacyStore = legacyResult
		end
	else
		warn("[TutorialService] Tutorial DataStore unavailable:", result)
	end
end

local playerData = {}

local function createDefaultData()
	return {
		CurrentStep = 1,
		Completed = false,
		Skipped = false,
		RewardClaimed = false,
		RewardsDisabled = false,
		StepRewardsClaimed = {},
		UpdatedAt = os.time(),
		Version = TutorialData.VERSION,
	}
end

local function sanitizeData(raw)
	local data = createDefaultData()
	if typeof(raw) ~= "table" then
		return data
	end
	data.CurrentStep = math.clamp(math.floor(tonumber(raw.CurrentStep) or 1), 1, TutorialData.StepCount + 1)
	data.Completed = raw.Completed == true
	data.Skipped = raw.Skipped == true
	data.RewardClaimed = raw.RewardClaimed == true
	data.RewardsDisabled = raw.RewardsDisabled == true
	data.UpdatedAt = tonumber(raw.UpdatedAt) or os.time()
	if typeof(raw.StepRewardsClaimed) == "table" then
		for stepId, claimed in raw.StepRewardsClaimed do
			if claimed == true and TutorialData.StepIndexById[stepId] then
				data.StepRewardsClaimed[stepId] = true
			end
		end
	end
	if data.Completed then
		data.CurrentStep = TutorialData.StepCount + 1
	end
	return data
end

local function loadFromStore(store, userId)
	if not store then
		return nil
	end
	local success, result = pcall(function()
		return store:GetAsync(tostring(userId))
	end)
	if success then
		return result
	end
	warn("[TutorialService] Failed to load tutorial data for", userId, result)
	return nil
end

local function migrateLegacyData(legacyRaw)
	if typeof(legacyRaw) ~= "table" then
		return nil
	end
	if legacyRaw.Completed == true then
		local data = createDefaultData()
		data.Completed = true
		data.CurrentStep = TutorialData.StepCount + 1
		data.RewardClaimed = legacyRaw.RewardClaimed == true
		return data
	end
	return nil
end

local function copySteps()
	return TutorialData.CopyStepsForClient()
end

local function serializeForClient(data, extras)
	extras = extras or {}
	local currentStep = TutorialData.GetStep(data.CurrentStep)
	return {
		currentStep = data.CurrentStep,
		stepCount = TutorialData.StepCount,
		completed = data.Completed,
		skipped = data.Skipped,
		rewardClaimed = data.RewardClaimed,
		rewardsDisabled = data.RewardsDisabled,
		steps = copySteps(),
		activeStep = currentStep and {
			Id = currentStep.Id,
			Title = currentStep.Title,
			Description = currentStep.Description,
			ActionHint = currentStep.ActionHint,
			Kind = currentStep.Kind,
			Reward = currentStep.Reward,
		} or nil,
		completionReward = TutorialData.COMPLETION_REWARD,
		message = extras.message,
		stepReward = extras.stepReward,
		stepRewardText = extras.stepRewardText,
	}
end

function TutorialService.getPlayerData(player)
	return playerData[player]
end

function TutorialService.sendState(player, extras)
	local data = playerData[player]
	if data then
		local payload = serializeForClient(data, extras or {})
		TutorialStateUpdated:FireClient(player, payload)
	end
end

local function saveNow(player)
	local data = playerData[player]
	if not data or not dataStoreAvailable or not tutorialStore then
		return
	end
	local payload = {
		CurrentStep = data.CurrentStep,
		Completed = data.Completed,
		Skipped = data.Skipped,
		RewardClaimed = data.RewardClaimed,
		RewardsDisabled = data.RewardsDisabled,
		StepRewardsClaimed = data.StepRewardsClaimed,
		UpdatedAt = os.time(),
		Version = TutorialData.VERSION,
	}
	local success, err = pcall(function()
		tutorialStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
	if not success then
		warn("[TutorialService] Failed to save tutorial data for", player.UserId, err)
	end
end

local function applyReward(player, reward)
	if typeof(reward) ~= "table" then
		return
	end
	if reward.DragonEssence then
		local current = player:GetAttribute("DragonEssence") or 0
		player:SetAttribute("DragonEssence", current + reward.DragonEssence)
	end
	if reward.PremiumGems then
		local gems = player:GetAttribute("PremiumGems") or 0
		player:SetAttribute("PremiumGems", gems + reward.PremiumGems)
	end
	if reward.BoostSeconds then
		local expires = os.time() + math.floor(reward.BoostSeconds)
		local existing = tonumber(player:GetAttribute("TutorialHarvestBoostUntil")) or 0
		player:SetAttribute("TutorialHarvestBoostUntil", math.max(existing, expires))
	end
	if reward.EggType then
		GrantTutorialRewardEgg:Fire(player, reward.EggType)
	end
	if reward.Title then
		player:SetAttribute("TutorialEquippedTitle", reward.Title)
	end
	if reward.Badge then
		player:SetAttribute("TutorialBadge", reward.Badge)
	end
end

local function grantStepReward(player, data, step)
	if not step or data.StepRewardsClaimed[step.Id] or data.RewardsDisabled then
		return nil
	end
	data.StepRewardsClaimed[step.Id] = true
	applyReward(player, step.Reward)
	return step.Reward
end

local function grantCompletionRewards(player, data)
	if data.RewardClaimed or data.RewardsDisabled then
		return
	end
	data.RewardClaimed = true
	applyReward(player, TutorialData.COMPLETION_REWARD)
end

local function syncAttributes(player, data)
	player:SetAttribute("TutorialCompleted", data.Completed)
	player:SetAttribute("TutorialSkipped", data.Skipped)
	player:SetAttribute("TutorialStep", data.CurrentStep)
end

local LEGACY_STEP_MAP = {
	PlaceDragonNest = "UpgradeKingdom",
	UpgradeDragonNest = "UpgradeKingdom",
	UpgradeCrystalStorage = "UpgradeKingdom",
	CompleteFirstQuest = "ExplainDailyQuests",
}

local function normalizeStepId(stepId)
	return LEGACY_STEP_MAP[stepId] or stepId
end

local function completeCurrentStep(player, stepId, message)
	local data = playerData[player]
	if not data or data.Completed then
		return false
	end
	stepId = normalizeStepId(stepId)
	local expected = TutorialData.GetStep(data.CurrentStep)
	if not expected or expected.Id ~= stepId then
		return false
	end
	local stepReward = grantStepReward(player, data, expected)
	data.CurrentStep += 1
	data.UpdatedAt = os.time()
	local stepRewardText = stepReward and TutorialData.FormatReward(stepReward) or nil
	if data.CurrentStep > TutorialData.StepCount then
		data.Completed = true
		grantCompletionRewards(player, data)
		message = message or ("Tutorial complete! " .. TutorialData.FormatReward(TutorialData.COMPLETION_REWARD))
	else
		local nextStep = TutorialData.GetStep(data.CurrentStep)
		message = message or ("Step complete!" .. (stepRewardText and (" " .. stepRewardText) or ""))
		if nextStep then
			message ..= "\nNext: " .. nextStep.Title
		end
	end
	syncAttributes(player, data)
	saveNow(player)
	TutorialService.sendState(player, {
		message = message,
		stepReward = stepReward,
		stepRewardText = stepRewardText,
	})
	return true
end

local function syncBuildingTutorial(player)
	local data = playerData[player]
	if not data or data.Completed then
		return
	end
	local activeStep = TutorialData.GetStep(data.CurrentStep)
	if not activeStep or activeStep.Id ~= "UpgradeKingdom" then
		return
	end
	local island = WorkspaceLayout.GetPlayerIsland(player)
	if not island then
		return
	end
	for _, child in island:GetChildren() do
		if child:IsA("Model") then
			local level = child:GetAttribute("BuildingLevel") or 1
			if level > 1 then
				completeCurrentStep(player, "UpgradeKingdom")
				return
			end
		end
	end
end

function TutorialService.loadPlayer(player)
	local data = createDefaultData()
	if dataStoreAvailable and tutorialStore then
		local raw = loadFromStore(tutorialStore, player.UserId)
		if raw then
			data = sanitizeData(raw)
		elseif legacyStore then
			local legacyRaw = loadFromStore(legacyStore, player.UserId)
			local migrated = migrateLegacyData(legacyRaw)
			if migrated then
				data = migrated
			end
		end
	end
	playerData[player] = data
	syncAttributes(player, data)
	task.defer(TutorialService.sendState, player)
	task.defer(syncBuildingTutorial, player)
end

function TutorialService.savePlayer(player)
	saveNow(player)
end

function TutorialService.completeStep(player, stepId, message)
	return completeCurrentStep(player, stepId, message)
end

function TutorialService.skipTutorial(player)
	local data = playerData[player]
	if not data or data.Completed then
		return false
	end
	data.Skipped = true
	data.Completed = true
	data.CurrentStep = TutorialData.StepCount + 1
	data.UpdatedAt = os.time()
	syncAttributes(player, data)
	saveNow(player)
	TutorialService.sendState(player, { message = "Tutorial skipped. You can replay it anytime from Settings." })
	return true
end

function TutorialService.replayTutorial(player)
	local data = playerData[player]
	if not data then
		return false
	end
	local rewardsDisabled = data.RewardClaimed == true
	data.CurrentStep = 1
	data.Completed = false
	data.Skipped = false
	data.RewardsDisabled = rewardsDisabled
	data.StepRewardsClaimed = {}
	data.UpdatedAt = os.time()
	syncAttributes(player, data)
	saveNow(player)
	TutorialService.sendState(player, { message = "Tutorial restarted. Follow the guide to relearn every system." })
	return true
end

function TutorialService.adminComplete(player)
	local data = playerData[player]
	if not data then
		return "Tutorial data unavailable"
	end
	if data.Completed then
		return "Tutorial already completed"
	end
	data.CurrentStep = TutorialData.StepCount + 1
	data.Completed = true
	data.UpdatedAt = os.time()
	grantCompletionRewards(player, data)
	syncAttributes(player, data)
	saveNow(player)
	TutorialService.sendState(player, { message = "Tutorial completed via admin" })
	return "Tutorial completed"
end

function TutorialService.adminReset(player)
	playerData[player] = createDefaultData()
	syncAttributes(player, playerData[player])
	saveNow(player)
	TutorialService.sendState(player, { message = "Tutorial reset" })
	return "Tutorial reset"
end

function TutorialService.init()
	RequestTutorialState.OnServerInvoke = function(player)
		if not playerData[player] then
			TutorialService.loadPlayer(player)
		end
		return serializeForClient(playerData[player])
	end

	TutorialStepCompleted.OnServerEvent:Connect(function(player, stepId)
		if typeof(stepId) ~= "string" or not TutorialData.StepIndexById[normalizeStepId(stepId)] then
			return
		end
		completeCurrentStep(player, stepId)
	end)

	TutorialProgressSignal.Event:Connect(function(player, stepId)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if typeof(stepId) ~= "string" then
			return
		end
		completeCurrentStep(player, stepId)
	end)

	TutorialSkipRequest.OnServerEvent:Connect(function(player)
		TutorialService.skipTutorial(player)
	end)

	TutorialReplayRequest.OnServerEvent:Connect(function(player)
		TutorialService.replayTutorial(player)
	end)

	Players.PlayerAdded:Connect(TutorialService.loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(TutorialService.loadPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveNow(player)
		playerData[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			saveNow(player)
		end
	end)
end

return TutorialService
