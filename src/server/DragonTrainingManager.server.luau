local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local DragonTrainingConfig = require(ReplicatedStorage:WaitForChild("DragonTrainingConfig"))
local DragonRosterBridge = require(script.Parent:WaitForChild("DragonRosterBridge"))
local RateLimiter = require(ServerScriptService:WaitForChild("RateLimiter"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))
local HarvestEvents = ReplicatedStorage:WaitForChild("HarvestEvents")
local RequestDragonTrainingData = HarvestEvents:WaitForChild("RequestDragonTrainingData")
local StartDragonTraining = HarvestEvents:WaitForChild("StartDragonTraining")
local ClaimDragonTraining = HarvestEvents:WaitForChild("ClaimDragonTraining")
local CancelDragonTraining = HarvestEvents:WaitForChild("CancelDragonTraining")
local SkipDragonTraining = HarvestEvents:WaitForChild("SkipDragonTraining")
local DragonTrainingUpdate = HarvestEvents:WaitForChild("DragonTrainingUpdate")
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestProgressSignal = QuestEvents:WaitForChild("QuestProgressSignal")

local TRAINING_DATASTORE = "DragonTrainingSessionsV1"
local playerSessions = {}
local saveQueued = {}
local trainingStore = nil
local dataStoreAvailable = false

if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(TRAINING_DATASTORE)
	end)
	if success then
		trainingStore = result
		dataStoreAvailable = true
	else
		warn("[DragonTrainingManager] Training DataStore unavailable:", result)
	end
end

local function getServerNow()
	return workspace:GetServerTimeNow()
end

local function getPlayerSessions(player)
	if not playerSessions[player] then
		playerSessions[player] = { sessions = {}, loaded = false }
	end
	return playerSessions[player]
end

local function sanitizeSession(rawSession)
	if typeof(rawSession) ~= "table" then
		return nil
	end
	local dragonId = tonumber(rawSession.dragonId)
	local programId = tostring(rawSession.programId or "")
	local program = DragonTrainingConfig.GetProgram(programId)
	if not dragonId or not program then
		return nil
	end
	return {
		id = tostring(rawSession.id or ("session_" .. tostring(dragonId))),
		dragonId = dragonId,
		programId = programId,
		startedAt = tonumber(rawSession.startedAt) or getServerNow(),
		endsAt = tonumber(rawSession.endsAt) or getServerNow(),
		claimed = rawSession.claimed == true,
		levelReward = math.max(1, math.floor(tonumber(rawSession.levelReward) or program.LevelReward or 1)),
		essenceReward = math.max(0, math.floor(tonumber(rawSession.essenceReward) or program.EssenceReward or 0)),
	}
end

local function getActiveSessions(player)
	local data = getPlayerSessions(player)
	local active = {}
	for _, session in data.sessions do
		if not session.claimed then
			table.insert(active, session)
		end
	end
	return active
end

local function countActiveSessions(player)
	return #getActiveSessions(player)
end

local function findSession(player, sessionId)
	local data = getPlayerSessions(player)
	for _, session in data.sessions do
		if session.id == sessionId then
			return session
		end
	end
	return nil
end

local function findSessionByDragonId(player, dragonId)
	local data = getPlayerSessions(player)
	for _, session in data.sessions do
		if session.dragonId == dragonId and not session.claimed then
			return session
		end
	end
	return nil
end

local function isSessionComplete(session)
	return session and not session.claimed and getServerNow() >= session.endsAt
end

-- Gems sink: pay to instantly finish an in-progress session instead of waiting. Priced off
-- remaining time (not total duration) so skipping a session that's almost done costs almost
-- nothing, and skipping right after starting costs close to the full price.
local SKIP_GEMS_PER_MINUTE = 2
local SKIP_MIN_COST = 5

local function getSkipCost(session)
	local remaining = math.max(0, session.endsAt - getServerNow())
	return math.max(SKIP_MIN_COST, math.ceil(remaining / 60 * SKIP_GEMS_PER_MINUTE))
end

local function buildProgramPayload(player, programId)
	local program = DragonTrainingConfig.GetProgram(programId)
	if not program then
		return nil
	end
	local multipliers = DragonRosterBridge.getAcademyMultipliers(player)
	local duration = DragonTrainingConfig.GetEffectiveDuration(program.BaseDuration, multipliers.TrainingTimeMultiplier)
	local xpMultiplier = multipliers.XpGainMultiplier or 1
	return {
		id = program.Id,
		displayName = program.DisplayName,
		description = program.Description,
		duration = duration,
		levelReward = math.max(1, math.floor(program.LevelReward * xpMultiplier + 0.5)),
		essenceReward = math.max(0, math.floor(program.EssenceReward * xpMultiplier + 0.5)),
		essenceCost = program.EssenceCost or 0,
		color = program.Color,
	}
end

local function buildPayload(player, message)
	local roster = DragonRosterBridge.getRoster(player)
	local multipliers = DragonRosterBridge.getAcademyMultipliers(player)
	local programs = {}
	for _, programId in DragonTrainingConfig.ProgramOrder do
		local programPayload = buildProgramPayload(player, programId)
		if programPayload then
			table.insert(programs, programPayload)
		end
	end

	local sessions = {}
	for _, session in getActiveSessions(player) do
		local dragonEntry = nil
		for _, dragon in roster do
			if dragon.id == session.dragonId then
				dragonEntry = dragon
				break
			end
		end
		table.insert(sessions, {
			id = session.id,
			dragonId = session.dragonId,
			programId = session.programId,
			startedAt = session.startedAt,
			endsAt = session.endsAt,
			complete = isSessionComplete(session),
			levelReward = session.levelReward,
			essenceReward = session.essenceReward,
			skipCost = isSessionComplete(session) and 0 or getSkipCost(session),
			dragon = dragonEntry,
		})
	end

	return {
		dragons = roster,
		programs = programs,
		sessions = sessions,
		maxSessions = DragonTrainingConfig.MaxConcurrentSessions,
		academyLevel = multipliers.BuildingLevel or 1,
		trainingTimeMultiplier = multipliers.TrainingTimeMultiplier or 1,
		xpGainMultiplier = multipliers.XpGainMultiplier or 1,
		message = message,
	}
end

local function sendUpdate(player, message)
	DragonTrainingUpdate:FireClient(player, buildPayload(player, message))
end

local function saveNow(player)
	local data = playerSessions[player]
	if not data or not data.loaded or not dataStoreAvailable or not trainingStore then
		return
	end
	local payload = {
		sessions = data.sessions,
		updatedAt = os.time(),
	}
	local success, err = pcall(function()
		trainingStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
	if not success then
		warn("[DragonTrainingManager] Failed to save training sessions for", player.UserId, err)
	end
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(2, function()
		saveQueued[player] = nil
		if player.Parent then
			saveNow(player)
		end
	end)
end

local function restoreSessionVisuals(player)
	local anchor = DragonRosterBridge.getAcademyPosition(player)
	for _, session in getActiveSessions(player) do
		if not isSessionComplete(session) then
			DragonRosterBridge.setDragonTraining(player, session.dragonId, true, anchor)
		end
	end
end

local function loadPlayerSessions(player)
	local data = getPlayerSessions(player)
	data.sessions = {}
	if dataStoreAvailable and trainingStore then
		local success, result = pcall(function()
			return trainingStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" and typeof(result.sessions) == "table" then
			for _, rawSession in result.sessions do
				local session = sanitizeSession(rawSession)
				if session and not session.claimed then
					table.insert(data.sessions, session)
				end
			end
		elseif not success then
			warn("[DragonTrainingManager] Failed to load training sessions for", player.UserId, result)
		end
	end
	data.loaded = true
	task.defer(function()
		if player.Parent then
			restoreSessionVisuals(player)
			sendUpdate(player)
		end
	end)
end

local function startTraining(player, dragonId, programId)
	local numericDragonId = tonumber(dragonId)
	local program = DragonTrainingConfig.GetProgram(tostring(programId or ""))
	if not numericDragonId or not program then
		sendUpdate(player, "Invalid training request")
		return
	end
	if countActiveSessions(player) >= DragonTrainingConfig.MaxConcurrentSessions then
		sendUpdate(player, "Academy training slots full (" .. tostring(DragonTrainingConfig.MaxConcurrentSessions) .. ")")
		return
	end
	if findSessionByDragonId(player, numericDragonId) then
		sendUpdate(player, "That dragon is already training")
		return
	end
	if DragonRosterBridge.isDragonBusy(player, numericDragonId) then
		sendUpdate(player, "That dragon is already training")
		return
	end

	local programPayload = buildProgramPayload(player, program.Id)
	if not programPayload then
		sendUpdate(player, "Training program unavailable")
		return
	end

	local essence = player:GetAttribute("DragonEssence") or 0
	if essence < (programPayload.essenceCost or 0) then
		sendUpdate(player, "Need " .. tostring(programPayload.essenceCost) .. " Dragon Essence")
		return
	end

	local anchor = DragonRosterBridge.getAcademyPosition(player)
	if not DragonRosterBridge.setDragonTraining(player, numericDragonId, true, anchor) then
		sendUpdate(player, "Could not assign dragon to training")
		return
	end

	if programPayload.essenceCost > 0 then
		local found = AdminBridge.call("Harvest", "adjustEssence", player, -programPayload.essenceCost)
		if not found then
			player:SetAttribute("DragonEssence", essence - programPayload.essenceCost)
		end
	end

	local now = getServerNow()
	local session = {
		id = "train_" .. tostring(math.floor(now * 1000)) .. "_" .. tostring(numericDragonId),
		dragonId = numericDragonId,
		programId = program.Id,
		startedAt = now,
		endsAt = now + programPayload.duration,
		claimed = false,
		levelReward = programPayload.levelReward,
		essenceReward = programPayload.essenceReward,
	}
	table.insert(getPlayerSessions(player).sessions, session)
	queueSave(player)
	sendUpdate(player, "Training started: " .. program.DisplayName)
end

local function claimTraining(player, sessionId)
	local session = findSession(player, tostring(sessionId or ""))
	if not session or session.claimed then
		sendUpdate(player, "Training session not found")
		return
	end
	if not isSessionComplete(session) then
		sendUpdate(player, "Training is still in progress")
		return
	end

	local success = DragonRosterBridge.applyTrainingRewards(player, session.dragonId, session.levelReward, session.essenceReward)
	DragonRosterBridge.setDragonTraining(player, session.dragonId, false, nil)
	session.claimed = true
	queueSave(player)
	if success then
		QuestProgressSignal:Fire(player, "TrainDragons", 1)
		sendUpdate(player, "Training complete! +" .. tostring(session.levelReward) .. " level(s), +" .. tostring(session.essenceReward) .. " essence")
	else
		sendUpdate(player, "Training claimed, but dragon was unavailable")
	end
end

local function skipTraining(player, sessionId)
	local session = findSession(player, tostring(sessionId or ""))
	if not session or session.claimed then
		sendUpdate(player, "Training session not found")
		return
	end
	if isSessionComplete(session) then
		sendUpdate(player, "Training is already complete - claim your rewards!")
		return
	end
	local cost = getSkipCost(session)
	local gems = player:GetAttribute("PremiumGems") or 0
	if gems < cost then
		sendUpdate(player, "Need " .. tostring(cost) .. " Gems to skip")
		return
	end
	player:SetAttribute("PremiumGems", gems - cost)
	session.endsAt = getServerNow()
	claimTraining(player, session.id)
end

local function cancelTraining(player, sessionId)
	local session = findSession(player, tostring(sessionId or ""))
	if not session or session.claimed then
		sendUpdate(player, "Training session not found")
		return
	end
	if isSessionComplete(session) then
		sendUpdate(player, "Training is complete — claim your rewards instead")
		return
	end

	DragonRosterBridge.setDragonTraining(player, session.dragonId, false, nil)
	session.claimed = true
	queueSave(player)
	sendUpdate(player, "Training cancelled. Dragon returned to harvest duty.")
end

RequestDragonTrainingData.OnServerInvoke = function(player)
	return buildPayload(player)
end

StartDragonTraining.OnServerEvent:Connect(function(player, dragonId, programId)
	if not RateLimiter.check(player, "StartDragonTraining", 0.3) then
		return
	end
	startTraining(player, dragonId, programId)
end)

ClaimDragonTraining.OnServerEvent:Connect(function(player, sessionId)
	if not RateLimiter.check(player, "ClaimDragonTraining", 0.3) then
		return
	end
	claimTraining(player, sessionId)
end)

CancelDragonTraining.OnServerEvent:Connect(function(player, sessionId)
	cancelTraining(player, sessionId)
end)

SkipDragonTraining.OnServerEvent:Connect(function(player, sessionId)
	if not RateLimiter.check(player, "SkipDragonTraining", 0.3) then
		return
	end
	skipTraining(player, sessionId)
end)

Players.PlayerAdded:Connect(loadPlayerSessions)
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayerSessions, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveNow(player)
	playerSessions[player] = nil
	saveQueued[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(5)
		for _, player in Players:GetPlayers() do
			local data = playerSessions[player]
			if data and data.loaded then
				local hasReady = false
				for _, session in getActiveSessions(player) do
					if isSessionComplete(session) then
						hasReady = true
						break
					end
				end
				if hasReady then
					sendUpdate(player, "Training complete! Claim your rewards at the Academy.")
				end
			end
		end
	end
end)

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))

RebirthDomainBridge.Register("Training", {
	getSnapshotPatch = function(player)
		local activeCount = countActiveSessions(player)
		if activeCount <= 0 then
			return nil
		end
		return {
			hasPendingTransactions = true,
			pendingTransactionReason = "Academy training is in progress.",
		}
	end,
	canReset = function(player)
		for _, session in getActiveSessions(player) do
			if not isSessionComplete(session) then
				return { ok = false, reason = "Cancel or finish academy training before Rebirth." }
			end
		end
		return { ok = true }
	end,
	resetRunState = function(player)
		for _, session in getActiveSessions(player) do
			DragonRosterBridge.setDragonTraining(player, session.dragonId, false, nil)
			session.claimed = true
		end
		queueSave(player)
		sendUpdate(player)
		return { success = true }
	end,
	restorePermanentState = function()
		return { success = true }
	end,
})

print("[DragonTrainingManager] Dragon Academy training ready")