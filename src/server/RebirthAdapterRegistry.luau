local RebirthAdapterRegistry = {}

local adapters = {}

local function getOrderedAdapters()
	local ordered = {}
	for _, adapter in adapters do
		table.insert(ordered, adapter)
	end
	table.sort(ordered, function(a, b)
		local priorityA = math.floor(tonumber(a.priority) or 100)
		local priorityB = math.floor(tonumber(b.priority) or 100)
		if priorityA == priorityB then
			return tostring(a.id) < tostring(b.id)
		end
		return priorityA < priorityB
	end)
	return ordered
end

function RebirthAdapterRegistry.Register(adapter)
	if typeof(adapter) ~= "table" or typeof(adapter.id) ~= "string" then
		return false
	end
	adapters[adapter.id] = adapter
	return true
end

function RebirthAdapterRegistry.Unregister(adapterId)
	if typeof(adapterId) ~= "string" then
		return false
	end
	adapters[adapterId] = nil
	return true
end

function RebirthAdapterRegistry.GetAdapter(adapterId)
	return adapters[adapterId]
end

function RebirthAdapterRegistry.GetOrderedAdapters()
	return getOrderedAdapters()
end

function RebirthAdapterRegistry.EnrichSnapshot(player, snapshot)
	if typeof(snapshot) ~= "table" then
		return snapshot
	end

	for _, adapter in getOrderedAdapters() do
		if typeof(adapter.getSnapshotPatch) == "function" then
			local success, patch = pcall(adapter.getSnapshotPatch, player)
			if success and typeof(patch) == "table" then
				for key, value in patch do
					if key == "buildingLevels" and typeof(value) == "table" then
						snapshot.buildingLevels = table.clone(value)
					elseif key == "unlockedIslandIds" and typeof(value) == "table" then
						snapshot.unlockedIslandIds = table.clone(value)
					elseif key == "buildingsAtOrAbove" and typeof(value) == "table" then
						snapshot.buildingsAtOrAbove = table.clone(value)
					else
						snapshot[key] = value
					end
				end
			elseif not success then
				warn(string.format("[RebirthAdapterRegistry] Snapshot patch failed for %s: %s", adapter.id, tostring(patch)))
			end
		end
	end

	for _, adapter in getOrderedAdapters() do
		if typeof(adapter.canReset) == "function" then
			local success, result = pcall(adapter.canReset, player, snapshot)
			if success and typeof(result) == "table" and result.ok == false then
				snapshot.hasPendingTransactions = true
				snapshot.pendingTransactionReason = result.reason or (adapter.id .. " has pending actions.")
				break
			elseif not success then
				warn(string.format("[RebirthAdapterRegistry] canReset failed for %s: %s", adapter.id, tostring(result)))
			end
		end
	end

	return snapshot
end

function RebirthAdapterRegistry.CheckCanReset(player, context)
	for _, adapter in getOrderedAdapters() do
		if typeof(adapter.canReset) == "function" then
			local success, result = pcall(adapter.canReset, player, context)
			if not success then
				return false, string.format("%s reset check failed.", adapter.id)
			end
			if typeof(result) == "table" and result.ok == false then
				return false, result.reason or string.format("%s is not ready for Rebirth.", adapter.id)
			end
		end
	end
	return true, nil
end

function RebirthAdapterRegistry.ResetRunState(player, context)
	local results = {}
	local allSuccess = true

	for _, adapter in getOrderedAdapters() do
		if typeof(adapter.resetRunState) ~= "function" then
			continue
		end

		local success, result = pcall(adapter.resetRunState, player, context)
		local stepResult = {
			adapterId = adapter.id,
			success = false,
			message = nil,
		}

		if success and typeof(result) == "table" then
			stepResult.success = result.success ~= false
			stepResult.message = result.message
		elseif success then
			stepResult.success = true
		else
			stepResult.message = tostring(result)
		end

		if not stepResult.success then
			allSuccess = false
			warn(string.format("[RebirthAdapterRegistry] resetRunState failed for %s: %s", adapter.id, stepResult.message or "unknown error"))
		end

		table.insert(results, stepResult)
	end

	return allSuccess, results
end

function RebirthAdapterRegistry.RestorePermanentState(player, context)
	local results = {}
	local allSuccess = true

	for _, adapter in getOrderedAdapters() do
		if typeof(adapter.restorePermanentState) ~= "function" then
			continue
		end

		local success, result = pcall(adapter.restorePermanentState, player, context)
		local stepResult = {
			adapterId = adapter.id,
			success = false,
			message = nil,
		}

		if success and typeof(result) == "table" then
			stepResult.success = result.success ~= false
			stepResult.message = result.message
		elseif success then
			stepResult.success = true
		else
			stepResult.message = tostring(result)
		end

		if not stepResult.success then
			allSuccess = false
			warn(string.format("[RebirthAdapterRegistry] restorePermanentState failed for %s: %s", adapter.id, stepResult.message or "unknown error"))
		end

		table.insert(results, stepResult)
	end

	return allSuccess, results
end

return RebirthAdapterRegistry
