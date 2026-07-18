local IslandPortalRegistry = {}

local ready = false
local byIslandId = {}
local byPortal = {}
local byModel = {}

local DEFAULT_HIP_HEIGHT = 3

function IslandPortalRegistry.Register(islandId, islandModel, spawn, portal)
	if typeof(islandId) ~= "string" or not islandModel then
		return
	end

	local entry = {
		islandId = islandId,
		model = islandModel,
		spawn = spawn,
		portal = portal,
	}

	byIslandId[islandId] = entry
	byModel[islandModel] = islandId

	if portal then
		byPortal[portal] = islandId
	end
end

function IslandPortalRegistry.MarkReady()
	ready = true
end

function IslandPortalRegistry.IsReady()
	return ready
end

function IslandPortalRegistry.GetByIslandId(islandId)
	return byIslandId[islandId]
end

function IslandPortalRegistry.GetIslandIdForModel(islandModel)
	return byModel[islandModel]
end

function IslandPortalRegistry.GetIslandIdForPortal(portal)
	return byPortal[portal]
end

function IslandPortalRegistry.GetAllEntries()
	local entries = {}
	for islandId, entry in pairs(byIslandId) do
		table.insert(entries, {
			islandId = islandId,
			model = entry.model,
			spawn = entry.spawn,
			portal = entry.portal,
		})
	end
	return entries
end

function IslandPortalRegistry.GetCharacterSpawnCFrame(spawn)
	if not spawn or not spawn:IsA("SpawnLocation") then
		return nil
	end

	local hipOffset = spawn.Size.Y * 0.5 + DEFAULT_HIP_HEIGHT
	return spawn.CFrame * CFrame.new(0, hipOffset, 0)
end

function IslandPortalRegistry.GetIslandSpawnCFrame(islandId)
	local entry = byIslandId[islandId]
	if not entry then
		return nil
	end

	local spawn = entry.spawn
	if not spawn and entry.model then
		spawn = entry.model:FindFirstChild("IslandSpawn")
	end
	if spawn and spawn:IsA("SpawnLocation") then
		return IslandPortalRegistry.GetCharacterSpawnCFrame(spawn)
	end

	return nil
end

function IslandPortalRegistry.WaitUntilReady(timeout)
	timeout = timeout or 35
	local start = os.clock()
	while not ready and os.clock() - start < timeout do
		task.wait(0.1)
	end
	return ready
end

return IslandPortalRegistry
