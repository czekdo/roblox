local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthSaveData = require(ServerScriptService:WaitForChild("RebirthSaveData"))
local RebirthState = require(ServerScriptService:WaitForChild("RebirthState"))
local RebirthRunSnapshot = require(ServerScriptService:WaitForChild("RebirthRunSnapshot"))
local RebirthValidator = require(ServerScriptService:WaitForChild("RebirthValidator"))
local RebirthScoreCalculator = require(ServerScriptService:WaitForChild("RebirthScoreCalculator"))
local AscensionShardService = require(ServerScriptService:WaitForChild("AscensionShardService"))
local RebirthResetPipeline = require(ServerScriptService:WaitForChild("RebirthResetPipeline"))
local RebirthAdapterRegistry = require(ServerScriptService:WaitForChild("RebirthAdapterRegistry"))
local RebirthSkillTreeService = require(ServerScriptService:WaitForChild("RebirthSkillTreeService"))
local RebirthMilestoneService = require(ServerScriptService:WaitForChild("RebirthMilestoneService"))
local AscensionBonusService = require(ServerScriptService:WaitForChild("AscensionBonusService"))

local RebirthEvents = ReplicatedStorage:WaitForChild("RebirthEvents")
local RequestRebirthPreview = RebirthEvents:WaitForChild("RequestRebirthPreview")
local RequestRebirthState = RebirthEvents:WaitForChild("RequestRebirthState")
local RequestRebirth = RebirthEvents:WaitForChild("RequestRebirth")
local RequestSkillTreePurchase = RebirthEvents:WaitForChild("RequestSkillTreePurchase")
local RebirthStateUpdated = RebirthEvents:WaitForChild("RebirthStateUpdated")
local RebirthCeremonyStart = RebirthEvents:WaitForChild("RebirthCeremonyStart")
local RebirthCeremonyComplete = RebirthEvents:WaitForChild("RebirthCeremonyComplete")
local RebirthProgressSignal = RebirthEvents:WaitForChild("RebirthProgressSignal")

local rebirthStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(RebirthConfig.DataStoreName)
	end)
	if success then
		rebirthStore = result
		dataStoreAvailable = true
	end
end

local saveQueued = {}
local rebirthLocks = {}

local RebirthOrchestrator = {}

function RebirthOrchestrator.IsLocked(player)
	return rebirthLocks[player] == true
end

function RebirthOrchestrator.SetLock(player, locked)
	rebirthLocks[player] = locked == true
	player:SetAttribute("Rebirthing", locked == true)
end

local function saveNow(player)
	local data = RebirthState.Get(player)
	if not data.loaded or not dataStoreAvailable or not rebirthStore then
		return true
	end

	local payload = RebirthSaveData.Serialize(data)
	if not payload then
		return false
	end

	local success = false
	pcall(function()
		rebirthStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
		success = true
	end)
	return success
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(RebirthConfig.SaveDelay, function()
		saveQueued[player] = nil
		if player.Parent then
			saveNow(player)
		end
	end)
end

local function buildPreview(player)
	local data = RebirthState.Get(player)
	local snapshot = RebirthRunSnapshot.Build(player, data.rebirthCount)
	RebirthAdapterRegistry.EnrichSnapshot(player, snapshot)
	RebirthRunSnapshot.Finalize(snapshot)
	RebirthState.UpdateLifetimePeaks(player, snapshot)
	local validation = RebirthValidator.Validate(snapshot)
	local score = RebirthScoreCalculator.Calculate(snapshot)
	return AscensionShardService.BuildPreviewPayload(player, validation, score, snapshot)
end

local function sendState(player, preview)
	local payload = RebirthState.BuildClientPayload(player, preview)
	RebirthStateUpdated:FireClient(player, payload)
	return payload
end

local function loadPlayer(player)
	local data = RebirthSaveData.CreateDefault()

	if dataStoreAvailable and rebirthStore then
		local success, result = pcall(function()
			return rebirthStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			data = RebirthSaveData.Normalize(result)
		end
	end

	RebirthState.Set(player, data)
	RebirthState.MarkLoaded(player)
	RebirthMilestoneService.SyncPlayer(player)
	RebirthState.SyncPlayerAttributes(player)
	AscensionBonusService.RefreshPlayer(player)

	local snapshot = RebirthRunSnapshot.Build(player, data.rebirthCount)
	RebirthState.UpdateLifetimePeaks(player, snapshot)
	RebirthState.SyncPlayerAttributes(player)

	task.defer(function()
		if player.Parent then
			sendState(player)
		end
	end)
end

local function buildPipelineCallbacks()
	return {
		setLock = function(player, locked)
			RebirthOrchestrator.SetLock(player, locked)
		end,
		syncAttributes = function(player)
			RebirthState.SyncPlayerAttributes(player)
		end,
		forceSave = function(player)
			return saveNow(player)
		end,
		pushState = function(player, preview)
			sendState(player, preview)
		end,
		fireCeremonyStart = function(player, payload)
			RebirthCeremonyStart:FireClient(player, payload)
		end,
		fireCeremonyComplete = function(player, payload)
			RebirthCeremonyComplete:FireClient(player, payload)
		end,
		fireProgressSignal = function(player, eventType, amount, metadata)
			RebirthProgressSignal:Fire(player, eventType, amount, metadata)
		end,
	}
end

function RebirthOrchestrator.ExecuteRebirth(player, options)
	options = options or {}
	options.isLocked = RebirthOrchestrator.IsLocked
	options.callbacks = buildPipelineCallbacks()
	return RebirthResetPipeline.Execute(player, options)
end

AscensionShardService.SetCallbacks({
	onSave = queueSave,
	onStateUpdated = function(player)
		sendState(player)
	end,
})

RequestRebirthState.OnServerInvoke = function(player)
	if not RebirthState.IsLoaded(player) then
		return { loaded = false }
	end
	return sendState(player)
end

RequestRebirthPreview.OnServerInvoke = function(player)
	if not RebirthState.IsLoaded(player) then
		return { loaded = false, eligible = false, reason = "Rebirth data not loaded." }
	end
	if RebirthOrchestrator.IsLocked(player) then
		return { loaded = true, eligible = false, reason = "Rebirth already in progress." }
	end
	return buildPreview(player)
end

RequestRebirth.OnServerInvoke = function(player)
	if not RebirthState.IsLoaded(player) then
		return { success = false, message = "Rebirth data not loaded." }
	end
	if RebirthOrchestrator.IsLocked(player) then
		return { success = false, message = "Rebirth already in progress." }
	end
	return RebirthOrchestrator.ExecuteRebirth(player)
end

RequestSkillTreePurchase.OnServerInvoke = function(player, nodeId)
	local result = RebirthSkillTreeService.Purchase(player, nodeId)
	if result.success then
		sendState(player)
	end
	return result
end

RebirthProgressSignal.Event:Connect(function(player, eventType, amount, metadata)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if not RebirthState.IsLoaded(player) then
		return
	end

	if eventType == "RunIslandReached" and typeof(metadata) == "table" then
		local snapshot = {
			highestIslandIndex = metadata.islandIndex,
			highestIslandId = metadata.islandId,
			celestialUnlocked = metadata.islandIndex and metadata.islandIndex >= 7 or false,
		}
		RebirthState.UpdateLifetimePeaks(player, snapshot)
		RebirthState.SyncPlayerAttributes(player)
		queueSave(player)
	elseif eventType == "KingdomLevel" then
		local snapshot = { kingdomLevel = math.max(1, math.floor(tonumber(amount) or 1)) }
		RebirthState.UpdateLifetimePeaks(player, snapshot)
		RebirthState.SyncPlayerAttributes(player)
		queueSave(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayer(player)

	player:GetAttributeChangedSignal("KingdomLevel"):Connect(function()
		if not RebirthState.IsLoaded(player) then
			return
		end
		RebirthProgressSignal:Fire(player, "KingdomLevel", player:GetAttribute("KingdomLevel"))
	end)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	saveNow(player)
	RebirthState.Clear(player)
	AscensionBonusService.ClearPlayer(player)
	saveQueued[player] = nil
	rebirthLocks[player] = nil
end)

-- Safety net for shutdown scenarios where PlayerRemoving isn't guaranteed to fire for every
-- connected player - rebirth/ascension progress is major, hard-earned player progression.
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		saveNow(player)
	end
end)

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

AdminBridge.register("Rebirth", {
	refreshState = function(player)
		return sendState(player)
	end,
	save = function(player)
		saveNow(player)
		return "Rebirth progress saved"
	end,
	preview = function(player)
		return buildPreview(player)
	end,
	executeRebirth = function(player, force)
		return RebirthOrchestrator.ExecuteRebirth(player, {
			ignoreValidation = force == true,
			ignorePendingTransactions = force == true,
		})
	end,
	grantShards = function(player, amount)
		return AscensionShardService.Grant(player, amount, "Admin")
	end,
	spendShards = function(player, amount)
		return AscensionShardService.TrySpend(player, amount, "Admin")
	end,
	setShards = function(player, amount)
		return AscensionShardService.SetBalance(player, amount, "Admin")
	end,
	purchaseSkill = function(player, nodeId)
		local result = RebirthSkillTreeService.Purchase(player, tostring(nodeId))
		if result.success then
			sendState(player)
		end
		return result
	end,
	refreshBonuses = function(player)
		AscensionBonusService.RefreshPlayer(player)
		return AscensionBonusService.BuildClientPayload(player)
	end,
	wipe = function(player)
		RebirthState.Set(player, RebirthSaveData.CreateDefault())
		RebirthState.MarkLoaded(player)
		RebirthState.SyncPlayerAttributes(player)
		sendState(player)
		saveNow(player)
		return "Rebirth progress wiped"
	end,
})

RebirthOrchestrator.GetAscensionShards = AscensionShardService.GetBalance
RebirthOrchestrator.CanAffordShards = AscensionShardService.CanAfford
RebirthOrchestrator.GrantAscensionShards = function(player, amount, source, metadata)
	return AscensionShardService.Grant(player, amount, source, metadata)
end
RebirthOrchestrator.TrySpendAscensionShards = function(player, amount, reason, metadata)
	return AscensionShardService.TrySpend(player, amount, reason, metadata)
end
RebirthOrchestrator.BuildPreview = buildPreview
RebirthOrchestrator.CalculateReward = AscensionShardService.CalculateReward

_G.RebirthOrchestrator = RebirthOrchestrator

print("[RebirthOrchestrator] Rebirth Version 1 ready — milestones, skill tree, and ascension bonuses active")
