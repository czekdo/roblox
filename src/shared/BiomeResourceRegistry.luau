local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local BiomeResourceConfig = require(ReplicatedStorage:WaitForChild("BiomeResourceConfig"))

local BiomeResourceRegistry = {}

local nodesBySpawnId = {}
local spawnRecords = {}

local function getUnlockChecker()
	local checker = BiomeResourceRegistry.IsIslandUnlockedForPlayer
	if typeof(checker) == "function" then
		return checker
	end
	return function()
		return true
	end
end

function BiomeResourceRegistry.RegisterSpawnRecord(record)
	if typeof(record) ~= "table" or typeof(record.spawnId) ~= "string" then
		return
	end
	spawnRecords[record.spawnId] = record
end

function BiomeResourceRegistry.RegisterNode(node, spawnId)
	if typeof(spawnId) ~= "string" then
		return
	end
	if node then
		nodesBySpawnId[spawnId] = node
	else
		nodesBySpawnId[spawnId] = nil
	end
end

function BiomeResourceRegistry.GetNode(spawnId)
	return nodesBySpawnId[spawnId]
end

function BiomeResourceRegistry.GetSpawnRecord(spawnId)
	return spawnRecords[spawnId]
end

function BiomeResourceRegistry.IsBiomeNode(node)
	return node and node:GetAttribute("BiomeResource") == true
end

function BiomeResourceRegistry.CanPlayerHarvest(player, node)
	if not BiomeResourceRegistry.IsBiomeNode(node) then
		return false
	end
	local islandId = node:GetAttribute("IslandId")
	if typeof(islandId) ~= "string" then
		return false
	end
	return getUnlockChecker()(player, islandId)
end

function BiomeResourceRegistry.GetAllSpawnRecords()
	local list = {}
	for _, record in pairs(spawnRecords) do
		table.insert(list, record)
	end
	return list
end

function BiomeResourceRegistry.Clear()
	table.clear(nodesBySpawnId)
	table.clear(spawnRecords)
end

function BiomeResourceRegistry.GetConfiguredIslandIds()
	local ids = {}
	for islandId in pairs(BiomeResourceConfig.IslandResources) do
		if IslandUnlockConfig.GetIslandById(islandId) then
			table.insert(ids, islandId)
		end
	end
	table.sort(ids, function(a, b)
		local indexA = IslandUnlockConfig.GetIslandIndex(a) or 999
		local indexB = IslandUnlockConfig.GetIslandIndex(b) or 999
		return indexA < indexB
	end)
	return ids
end

return BiomeResourceRegistry
