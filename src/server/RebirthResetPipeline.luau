local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthState = require(ServerScriptService:WaitForChild("RebirthState"))
local RebirthRunSnapshot = require(ServerScriptService:WaitForChild("RebirthRunSnapshot"))
local RebirthValidator = require(ServerScriptService:WaitForChild("RebirthValidator"))
local RebirthScoreCalculator = require(ServerScriptService:WaitForChild("RebirthScoreCalculator"))
local AscensionShardService = require(ServerScriptService:WaitForChild("AscensionShardService"))
local RebirthMilestoneService = require(ServerScriptService:WaitForChild("RebirthMilestoneService"))
local RebirthAdapterRegistry = require(ServerScriptService:WaitForChild("RebirthAdapterRegistry"))
local IslandTeleportService = require(ServerScriptService:WaitForChild("IslandTeleportService"))

local RebirthResetPipeline = {}

local STEP = {
	LOCK = "Lock",
	VALIDATE = "Validate",
	CALCULATE = "Calculate",
	PERSIST_PERMANENT = "PersistPermanent",
	GRANT_SHARDS = "GrantShards",
	SAVE = "Save",
	RESET_RUN = "ResetRun",
	RESTORE_PERMANENT = "RestorePermanent",
	TELEPORT = "Teleport",
	LIFECYCLE = "Lifecycle",
	UNLOCK = "Unlock",
}

local function buildFailure(step, message, details)
	return {
		success = false,
		step = step,
		message = message,
		details = details,
	}
end

local function buildSuccess(context)
	return {
		success = true,
		message = string.format("Ascended to Rebirth %d!", context.newRebirthCount or 0),
		rebirthCount = context.newRebirthCount,
		previousRebirthCount = context.previousRebirthCount,
		shardsGranted = context.shardsGranted or 0,
		totalShards = AscensionShardService.GetBalance(context.player),
		scoreBreakdown = context.score and context.score.breakdown or nil,
		resetResults = context.resetResults,
		restoreResults = context.restoreResults,
	}
end

function RebirthResetPipeline.Execute(player, options)
	options = options or {}

	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return buildFailure(STEP.LOCK, "Invalid player.")
	end
	if not RebirthState.IsLoaded(player) then
		return buildFailure(STEP.LOCK, "Rebirth data not loaded.")
	end
	if options.isLocked and options.isLocked(player) then
		return buildFailure(STEP.LOCK, "Rebirth already in progress.")
	end

	local callbacks = options.callbacks or {}
	local context = {
		player = player,
		options = options,
		startedAt = os.clock(),
	}

	-- 1. Lock player actions
	if callbacks.setLock then
		callbacks.setLock(player, true)
	end

	local permanentBackup = nil
	local permanentModified = false
	local permanentCommitted = false

	local function rollbackPermanent()
		if permanentModified and permanentBackup then
			RebirthState.RestorePermanentBackup(player, permanentBackup)
			if callbacks.syncAttributes then
				callbacks.syncAttributes(player)
			end
			if permanentCommitted and callbacks.forceSave then
				callbacks.forceSave(player)
			end
			if callbacks.pushState then
				callbacks.pushState(player)
			end
		end
	end

	local function unlockPlayer()
		if callbacks.setLock then
			callbacks.setLock(player, false)
		end
	end

	local ok, result = pcall(function()
		-- 2. Build snapshot and validate requirements
		local data = RebirthState.Get(player)
		context.previousRebirthCount = data.rebirthCount or 0
		context.newRebirthCount = context.previousRebirthCount + 1

		local snapshot = RebirthRunSnapshot.Build(player, context.previousRebirthCount)
		RebirthAdapterRegistry.EnrichSnapshot(player, snapshot)
		RebirthRunSnapshot.Finalize(snapshot)
		RebirthState.UpdateLifetimePeaks(player, snapshot)
		context.snapshot = snapshot

		local adapterReady, adapterReason = RebirthAdapterRegistry.CheckCanReset(player, context)
		if not adapterReady then
			error({ step = STEP.VALIDATE, message = adapterReason or "Systems are not ready for Rebirth." })
		end

		local validation = RebirthValidator.Validate(snapshot, {
			ignorePendingTransactions = options.ignorePendingTransactions == true,
		})
		context.validation = validation
		if not validation.eligible and options.ignoreValidation ~= true then
			error({
				step = STEP.VALIDATE,
				message = validation.reason or "Rebirth requirements not met.",
				details = {
					reasons = validation.reasons,
					requirements = validation.requirements,
				},
			})
		end

		-- 3. Calculate rewards
		local score = RebirthScoreCalculator.Calculate(snapshot)
		context.score = score
		context.shardsGranted = math.max(0, math.floor(tonumber(score.projectedShards) or 0))

		-- 4. Persist permanent progression (in-memory, with rollback backup)
		permanentBackup = RebirthState.CreatePermanentBackup(player)
		RebirthState.ApplyRebirthCompletion(player, snapshot, {
			shardsGranted = context.shardsGranted,
		})
		permanentModified = true
		if callbacks.syncAttributes then
			callbacks.syncAttributes(player)
		end

		-- 5. Grant Ascension Shards
		local grantResult = AscensionShardService.Grant(player, context.shardsGranted, "Rebirth", {
			runShards = context.shardsGranted,
			rebirthNumber = context.newRebirthCount,
		})
		if not grantResult.success then
			error({ step = STEP.GRANT_SHARDS, message = grantResult.message or "Failed to grant Ascension Shards." })
		end
		permanentCommitted = true

		context.milestonesGranted = RebirthMilestoneService.OnRebirthCompleted(player, context.newRebirthCount)
		RebirthMilestoneService.SyncPlayerAttributes(player)

		-- 6. Save permanent progression immediately
		if callbacks.forceSave then
			local saveOk = callbacks.forceSave(player)
			if saveOk == false then
				error({ step = STEP.SAVE, message = "Failed to save Rebirth progress." })
			end
		end

		-- 7. Reset run-specific progression via adapters
		local resetOk, resetResults = RebirthAdapterRegistry.ResetRunState(player, context)
		context.resetResults = resetResults
		if not resetOk then
			warn(string.format("[RebirthResetPipeline] Run reset completed with adapter errors for %s", player.Name))
		end

		-- 8. Restore permanent progression via adapters
		local restoreOk, restoreResults = RebirthAdapterRegistry.RestorePermanentState(player, context)
		context.restoreResults = restoreResults
		if not restoreOk then
			warn(string.format("[RebirthResetPipeline] Permanent restore completed with adapter errors for %s", player.Name))
		end

		-- 9. Teleport player to Hub
		if options.teleportToHub ~= false and IslandTeleportService.IsReady() then
			IslandTeleportService.TeleportToHub(player)
		end

		-- 10. Fire lifecycle events
		if callbacks.fireCeremonyStart then
			callbacks.fireCeremonyStart(player, {
				rebirthCount = context.newRebirthCount,
				shardsGranted = context.shardsGranted,
				totalShards = AscensionShardService.GetBalance(player),
				scoreBreakdown = score.breakdown,
				milestonesGranted = context.milestonesGranted,
			})
		end

		if callbacks.fireProgressSignal then
			callbacks.fireProgressSignal(player, "RebirthCompleted", context.newRebirthCount, {
				shardsGranted = context.shardsGranted,
				highestIslandIndex = snapshot.highestIslandIndex,
				kingdomLevel = snapshot.kingdomLevel,
				celestialUnlocked = snapshot.celestialUnlocked,
			})
		end

		if callbacks.pushState then
			callbacks.pushState(player, AscensionShardService.BuildPreviewPayload(player, validation, score, snapshot))
		end

		if callbacks.fireCeremonyComplete then
			callbacks.fireCeremonyComplete(player, {
				rebirthCount = context.newRebirthCount,
				shardsGranted = context.shardsGranted,
				totalShards = AscensionShardService.GetBalance(player),
				openSkillTree = true,
				milestonesGranted = context.milestonesGranted,
			})
		end

		return buildSuccess(context)
	end)

	if not ok then
		local failure = result
		if typeof(failure) == "table" and failure.step then
			rollbackPermanent()
			unlockPlayer()
			return buildFailure(failure.step, failure.message, failure.details)
		end

		rollbackPermanent()
		unlockPlayer()
		warn(string.format("[RebirthResetPipeline] Unexpected error for %s: %s", player.Name, tostring(failure)))
		return buildFailure(STEP.LOCK, "Rebirth failed due to an unexpected error.")
	end

	-- 11. Unlock player
	unlockPlayer()
	return result
end

return RebirthResetPipeline
