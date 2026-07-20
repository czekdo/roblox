local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local IslandPortalRegistry = require(ReplicatedStorage:WaitForChild("IslandPortalRegistry"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local BiomeResourceRegistry = require(ReplicatedStorage:WaitForChild("BiomeResourceRegistry"))

local DragonAIController = {}

local deps = {}

local MAIN_ISLAND_ID = "MainIsland"
local HUB_ZONE_ID = "Hub"

local FORMATION_DISTANCE = 7.5
local FORMATION_SPACING = 5.5
local FORMATION_ROW_DEPTH = 5.25
local FOLLOW_HOVER_HEIGHT = 1.5
local TELEPORT_DISTANCE = 110
local STUCK_TIME = 2.75
local STUCK_MOVE_EPSILON = 0.4
local ISLAND_CHECK_INTERVAL = 0.12
local NODE_CACHE_TTL = 0.35

local islandModelCache = {}
local islandModelCacheReady = false

local function rebuildIslandModelCache()
	table.clear(islandModelCache)

	local mainIsland = WorkspaceLayout.GetMainIsland()
	if mainIsland then
		islandModelCache[mainIsland] = MAIN_ISLAND_ID
	end

	if IslandPortalRegistry.IsReady() then
		for _, entry in IslandPortalRegistry.GetAllEntries() do
			if entry.model then
				islandModelCache[entry.model] = entry.islandId
			end
		end
	else
		local biomeFolder = workspace:FindFirstChild(IslandUnlockConfig.FolderName)
		if biomeFolder then
			for _, island in IslandUnlockConfig.Islands do
				local model = biomeFolder:FindFirstChild(island.ModelName)
				if model and model:IsA("Model") then
					islandModelCache[model] = island.Id
				end
			end
		end
	end

	islandModelCacheReady = next(islandModelCache) ~= nil
end

local function isPointInsideModel(model, point)
	local cframe, size = model:GetBoundingBox()
	local localPoint = cframe:PointToObjectSpace(point)
	return math.abs(localPoint.X) <= size.X * 0.5
		and math.abs(localPoint.Y) <= size.Y * 0.5 + 14
		and math.abs(localPoint.Z) <= size.Z * 0.5
end

local function getCharacterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHorizontalUnit(vector)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

function DragonAIController.Init(dependencies)
	deps = dependencies or {}
	rebuildIslandModelCache()
end

function DragonAIController.RefreshIslandCache()
	rebuildIslandModelCache()
end

function DragonAIController.GetPlayerIslandId(player)
	local tracked = player:GetAttribute("CurrentIslandId")
	if typeof(tracked) == "string" and tracked ~= "" then
		return tracked
	end

	local zone = player:GetAttribute("CurrentZone")
	if zone == HUB_ZONE_ID then
		return HUB_ZONE_ID
	end

	local root = getCharacterRoot(player)
	if not root then
		return zone == "BiomeIsland" and player:GetAttribute("CurrentIslandId") or MAIN_ISLAND_ID
	end

	if not islandModelCacheReady then
		rebuildIslandModelCache()
	end

	local position = root.Position
	for model, islandId in pairs(islandModelCache) do
		if model.Parent and isPointInsideModel(model, position) then
			return islandId
		end
	end

	if zone == "BiomeIsland" then
		local tracked = player:GetAttribute("CurrentIslandId")
		if typeof(tracked) == "string" then
			return tracked
		end
	end

	return MAIN_ISLAND_ID
end

function DragonAIController.IsHarvestIsland(islandId)
	return typeof(islandId) == "string" and islandId ~= HUB_ZONE_ID
end

function DragonAIController.GetNodeIslandId(node)
	if not node then
		return nil
	end
	if BiomeResourceRegistry.IsBiomeNode(node) then
		return node:GetAttribute("IslandId")
	end
	return MAIN_ISLAND_ID
end

function DragonAIController.IsNodeOnIsland(player, node, islandId)
	if not node or not islandId then
		return false
	end
	local nodeIslandId = DragonAIController.GetNodeIslandId(node)
	return nodeIslandId == islandId
end

function DragonAIController.AssignFormationIndices(data)
	local activeDragons = {}
	for _, dragon in data.dragons do
		if dragon.state ~= "training" then
			table.insert(activeDragons, dragon)
		end
	end

	table.sort(activeDragons, function(a, b)
		return a.id < b.id
	end)

	for index, dragon in activeDragons do
		dragon.formationIndex = index
	end
end

local function getFormationOffsets(totalCount)
	local offsets = table.create(totalCount)
	if totalCount <= 0 then
		return offsets
	end

	if totalCount == 1 then
		offsets[1] = Vector3.new(0, 0, FORMATION_DISTANCE)
	elseif totalCount == 2 then
		offsets[1] = Vector3.new(-FORMATION_SPACING * 0.5, 0, FORMATION_DISTANCE)
		offsets[2] = Vector3.new(FORMATION_SPACING * 0.5, 0, FORMATION_DISTANCE)
	elseif totalCount == 3 then
		offsets[1] = Vector3.new(0, 0, FORMATION_DISTANCE + 1.75)
		offsets[2] = Vector3.new(-FORMATION_SPACING, 0, FORMATION_DISTANCE - 2.25)
		offsets[3] = Vector3.new(FORMATION_SPACING, 0, FORMATION_DISTANCE - 2.25)
	else
		local perRow = 3
		for index = 1, totalCount do
			local rowIndex = math.floor((index - 1) / perRow)
			local rowStart = rowIndex * perRow + 1
			local rowEnd = math.min(totalCount, rowStart + perRow - 1)
			local rowCount = rowEnd - rowStart + 1
			local colIndex = index - rowStart
			local x = (colIndex - (rowCount - 1) * 0.5) * FORMATION_SPACING
			local z = FORMATION_DISTANCE + rowIndex * FORMATION_ROW_DEPTH
			offsets[index] = Vector3.new(x, 0, z)
		end
	end

	return offsets
end

function DragonAIController.GetFormationPosition(player, data, dragon)
	local root = getCharacterRoot(player)
	if not root then
		return dragon.position
	end

	local activeCount = 0
	for _, entry in data.dragons do
		if entry.state ~= "training" then
			activeCount += 1
		end
	end
	if activeCount <= 0 then
		activeCount = 1
	end

	local slotIndex = math.clamp(dragon.formationIndex or 1, 1, activeCount)
	local offsets = getFormationOffsets(activeCount)
	local offset = offsets[slotIndex] or offsets[1] or Vector3.new(0, 0, FORMATION_DISTANCE)

	local flatLook = getHorizontalUnit(root.CFrame.LookVector)
	local right = flatLook:Cross(Vector3.yAxis)
	if right.Magnitude < 0.01 then
		right = Vector3.new(1, 0, 0)
	else
		right = right.Unit
	end

	local basePosition = root.Position - flatLook * offset.Z + right * offset.X
	return basePosition + Vector3.new(0, FOLLOW_HOVER_HEIGHT, 0), flatLook
end

local function getCachedIslandNodes(data, islandId)
	local now = os.clock()
	data.nodeCache = data.nodeCache or {}
	local cache = data.nodeCache[islandId]
	if cache and now - cache.time < NODE_CACHE_TTL then
		return cache.nodes
	end

	local nodes = {}
	if islandId == MAIN_ISLAND_ID then
		for _, node in data.nodes do
			table.insert(nodes, node)
		end
	elseif DragonAIController.IsHarvestIsland(islandId) then
		local nodesFolder = deps.nodesFolder
		if nodesFolder then
			for _, node in nodesFolder:GetChildren() do
				if BiomeResourceRegistry.IsBiomeNode(node) and node:GetAttribute("IslandId") == islandId then
					table.insert(nodes, node)
				end
			end
		end
	end

	data.nodeCache[islandId] = {
		time = now,
		nodes = nodes,
	}
	return nodes
end

function DragonAIController.InvalidateNodeCache(data)
	if data then
		data.nodeCache = {}
	end
end

function DragonAIController.FindClosestAvailableNode(player, data, dragon)
	local islandId = data.currentIslandId or DragonAIController.GetPlayerIslandId(player)
	if not DragonAIController.IsHarvestIsland(islandId) then
		return nil
	end

	local isAvailableNode = deps.isAvailableNode
	local isNodeAlreadyAssigned = deps.isNodeAlreadyAssigned
	if not isAvailableNode or not isNodeAlreadyAssigned then
		return nil
	end

	local islandNodes = getCachedIslandNodes(data, islandId)
	local closestNode = nil
	local closestDistance = math.huge

	for _, node in islandNodes do
		if isAvailableNode(player, node)
			and DragonAIController.IsNodeOnIsland(player, node, islandId)
			and not isNodeAlreadyAssigned(data, node) then
			local nodePos = deps.getNodePosition(node)
			local distance = (nodePos - dragon.position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestNode = node
			end
		end
	end

	if closestNode then
		return closestNode
	end

	for _, node in islandNodes do
		if isAvailableNode(player, node) and DragonAIController.IsNodeOnIsland(player, node, islandId) then
			local nodePos = deps.getNodePosition(node)
			local distance = (nodePos - dragon.position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestNode = node
			end
		end
	end

	return closestNode
end

local function applyDragonPosition(dragon, position, lookVector)
	dragon.position = position
	if dragon.model then
		dragon.model:SetAttribute("ServerPosition", position)
		if typeof(lookVector) == "Vector3" and lookVector.Magnitude > 0.01 then
			dragon.model:SetAttribute("LookDirection", lookVector.Unit)
		end
	end
end

function DragonAIController.RepositionDragon(player, data, dragon, immediate)
	local targetPos, facing = DragonAIController.GetFormationPosition(player, data, dragon)
	if immediate then
		applyDragonPosition(dragon, targetPos, facing)
		dragon.stuckTimer = 0
		dragon.lastMoveCheckPos = targetPos
		dragon.velocity = Vector3.zero
	else
		dragon.followTarget = targetPos
	end
end

function DragonAIController.RepositionAllDragons(player, data, immediate)
	DragonAIController.AssignFormationIndices(data)
	for _, dragon in data.dragons do
		if dragon.state ~= "training" then
			DragonAIController.RepositionDragon(player, data, dragon, immediate)
		end
	end
end

function DragonAIController.HandleIslandChanged(player, data, previousIslandId, newIslandId)
	data.currentIslandId = newIslandId
	player:SetAttribute("CurrentIslandId", newIslandId)
	DragonAIController.InvalidateNodeCache(data)

	local setDragonIdle = deps.setDragonIdle
	if setDragonIdle then
		for _, dragon in data.dragons do
			if dragon.state == "moving" or dragon.state == "harvesting" then
				setDragonIdle(dragon)
			end
		end
	end

	DragonAIController.RepositionAllDragons(player, data, true)
	data.autoAssignTimer = (deps.HarvestConfig and deps.HarvestConfig.AutoAssignInterval) or 0.45

	local autoAssign = deps.autoAssignIdleDragons
	if autoAssign then
		autoAssign(player, data)
	end
end

function DragonAIController.UpdatePlayerIsland(player, data, dt)
	data.islandCheckTimer = (data.islandCheckTimer or 0) + dt
	if data.islandCheckTimer < ISLAND_CHECK_INTERVAL then
		return false
	end
	data.islandCheckTimer = 0

	local detectedIsland = DragonAIController.GetPlayerIslandId(player)
	local previousIsland = data.currentIslandId
	if previousIsland == detectedIsland then
		return false
	end

	DragonAIController.HandleIslandChanged(player, data, previousIsland, detectedIsland)
	return true
end

function DragonAIController.ValidateActiveHarvest(player, data, dragon)
	if not dragon.targetNode then
		return false
	end

	local islandId = data.currentIslandId or DragonAIController.GetPlayerIslandId(player)
	if not DragonAIController.IsHarvestIsland(islandId) then
		return false
	end

	if not DragonAIController.IsNodeOnIsland(player, dragon.targetNode, islandId) then
		return false
	end

	local isAvailableNode = deps.isAvailableNode
	if isAvailableNode and not isAvailableNode(player, dragon.targetNode) then
		return false
	end

	local root = getCharacterRoot(player)
	if root and (dragon.position - root.Position).Magnitude > TELEPORT_DISTANCE * 1.35 then
		return false
	end

	return true
end

local function getMoveSpeed(dragon)
	local getDragonMoveSpeed = deps.getDragonMoveSpeed
	if getDragonMoveSpeed then
		return getDragonMoveSpeed(dragon.level, dragon.rarity, dragon.evolutionLevel)
	end
	return 16
end

local function moveDragonToward(dragon, targetPos, dt, speed)
	local offset = targetPos - dragon.position
	local distance = offset.Magnitude
	if distance <= 0.05 then
		return targetPos, Vector3.zero, true
	end

	local direction = offset.Unit
	local step = math.min(speed * dt, distance)
	local newPos = dragon.position + direction * step
	return newPos, direction, distance <= step + 0.05
end

function DragonAIController.UpdateDragonMovement(player, data, dragon, dt)
	local root = getCharacterRoot(player)
	if not root then
		return
	end

	local playerDistance = (dragon.position - root.Position).Magnitude
	if playerDistance > TELEPORT_DISTANCE then
		DragonAIController.RepositionDragon(player, data, dragon, true)
		return
	end

	if dragon.state == "harvesting" then
		dragon.stuckTimer = 0
		dragon.lastMoveCheckPos = dragon.position
		return
	end

	local lastPos = dragon.lastMoveCheckPos or dragon.position
	local moved = (dragon.position - lastPos).Magnitude
	if moved < STUCK_MOVE_EPSILON then
		dragon.stuckTimer = (dragon.stuckTimer or 0) + dt
	else
		dragon.stuckTimer = 0
		dragon.lastMoveCheckPos = dragon.position
	end

	if dragon.stuckTimer >= STUCK_TIME then
		DragonAIController.RepositionDragon(player, data, dragon, true)
		return
	end
end

function DragonAIController.UpdateIdleDragon(player, data, dragon, dt)
	DragonAIController.UpdateDragonMovement(player, data, dragon, dt)

	local targetPos, facing = DragonAIController.GetFormationPosition(player, data, dragon)
	local speed = getMoveSpeed(dragon) * 0.92
	local newPos, moveDir, arrived = moveDragonToward(dragon, targetPos, dt, speed)

	local lookVector = facing
	if moveDir.Magnitude > 0.01 and not arrived then
		lookVector = moveDir
	end

	applyDragonPosition(dragon, newPos, lookVector)

	if dragon.model then
		dragon.model:SetAttribute("DragonState", "idle")
		dragon.model:SetAttribute("TargetLookPosition", targetPos)
	end
end

return DragonAIController
