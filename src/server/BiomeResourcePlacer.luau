local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local HarvestConfig = require(ReplicatedStorage:WaitForChild("HarvestConfig"))
local BiomeResourceConfig = require(ReplicatedStorage:WaitForChild("BiomeResourceConfig"))
local BiomeResourceRegistry = require(ReplicatedStorage:WaitForChild("BiomeResourceRegistry"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))

local BiomeResourcePlacer = {}

local resourcesFolder = ServerStorage:WaitForChild("Resources")
local templateCache = {}

local function getObjectPosition(instance)
	if not instance then
		return nil
	end
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function resolveTemplateName(canonicalName)
	local alias = BiomeResourceConfig.ResourceAliases[canonicalName]
	if alias and resourcesFolder:FindFirstChild(alias) then
		return alias
	end
	if resourcesFolder:FindFirstChild(canonicalName) then
		return canonicalName
	end
	local lower = string.lower(canonicalName)
	for _, child in resourcesFolder:GetChildren() do
		if child:IsA("Model") and string.lower(child.Name) == lower then
			return child.Name
		end
	end
	return nil
end

local function getTemplate(canonicalName)
	if templateCache[canonicalName] then
		return templateCache[canonicalName]
	end
	local templateName = resolveTemplateName(canonicalName)
	if not templateName then
		warn("[BiomeResourcePlacer] Missing resource template for", canonicalName)
		return nil
	end
	local template = resourcesFolder:FindFirstChild(templateName)
	templateCache[canonicalName] = template
	return template
end

local function findPlacementPart(islandModel)
	local placementPart = islandModel:FindFirstChild("Part")
	if placementPart and placementPart:IsA("BasePart") then
		return placementPart
	end
	return nil
end

local function hidePlacementPart(placementPart)
	placementPart.Transparency = 1
	placementPart.CanCollide = false
	placementPart.CanTouch = false
	placementPart.CanQuery = false
	placementPart.CastShadow = false
end

local function buildRaycastIncludes(islandModel, placementPart)
	local includes = {}
	for _, descendant in islandModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= placementPart then
			table.insert(includes, descendant)
		end
	end
	return includes
end

local function getPartWorldTopY(placementPart)
	local cframe = placementPart.CFrame
	local halfSize = placementPart.Size * 0.5
	local topY = -math.huge

	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local corner = cframe:PointToWorldSpace(Vector3.new(halfSize.X * sx, halfSize.Y * sy, halfSize.Z * sz))
				topY = math.max(topY, corner.Y)
			end
		end
	end

	return topY
end

local function isFarEnough(candidate, placedPositions, minSpacing, exclusions)
	for _, placed in placedPositions do
		if (candidate - placed).Magnitude < minSpacing then
			return false
		end
	end
	for _, exclusion in exclusions do
		if (candidate - exclusion.position).Magnitude < exclusion.radius then
			return false
		end
	end
	return true
end

local function getSortedPartAxes(size)
	local dims = {
		{ axis = "X", half = size.X * 0.5 },
		{ axis = "Y", half = size.Y * 0.5 },
		{ axis = "Z", half = size.Z * 0.5 },
	}
	table.sort(dims, function(a, b)
		return a.half < b.half
	end)
	return dims
end

local function getAxisCoord(axisName, localPoint)
	if axisName == "X" then
		return localPoint.X
	end
	if axisName == "Y" then
		return localPoint.Y
	end
	return localPoint.Z
end

local function setAxisCoord(axisName, coords, value)
	coords[axisName] = value
end

local function isInsidePlacementFootprint(placementPart, worldPoint)
	local localPoint = placementPart.CFrame:PointToObjectSpace(worldPoint)
	local dims = getSortedPartAxes(placementPart.Size)
	local wideA = dims[2]
	local wideB = dims[3]

	return math.abs(getAxisCoord(wideA.axis, localPoint)) <= wideA.half
		and math.abs(getAxisCoord(wideB.axis, localPoint)) <= wideB.half
end

local function randomLocalPointInPart(placementPart, edgeMargin)
	local dims = getSortedPartAxes(placementPart.Size)
	local thinAxis = dims[1]
	local wideA = dims[2]
	local wideB = dims[3]
	local inset = 1 - (edgeMargin or 0.08)
	local coords = { X = 0, Y = 0, Z = 0 }

	setAxisCoord(wideA.axis, coords, (math.random() * 2 - 1) * wideA.half * inset)
	setAxisCoord(wideB.axis, coords, (math.random() * 2 - 1) * wideB.half * inset)
	setAxisCoord(thinAxis.axis, coords, (math.random() * 2 - 1) * thinAxis.half * inset)

	return Vector3.new(coords.X, coords.Y, coords.Z)
end

local function ringLocalPointInPart(placementPart, edgeMargin, angle, radiusFactor)
	local dims = getSortedPartAxes(placementPart.Size)
	local thinAxis = dims[1]
	local wideA = dims[2]
	local wideB = dims[3]
	local inset = 1 - (edgeMargin or 0.08)
	local coords = { X = 0, Y = 0, Z = 0 }

	setAxisCoord(wideA.axis, coords, math.cos(angle) * wideA.half * radiusFactor * inset)
	setAxisCoord(wideB.axis, coords, math.sin(angle) * wideB.half * radiusFactor * inset)
	setAxisCoord(thinAxis.axis, coords, thinAxis.half * inset)

	return Vector3.new(coords.X, coords.Y, coords.Z)
end

local function getSpawnExclusionRadius(placementPart, configuredRadius)
	local largestHalf = math.max(placementPart.Size.X, placementPart.Size.Y, placementPart.Size.Z) * 0.5
	return math.min(configuredRadius, math.max(8, largestHalf * 0.4))
end

local function getPortalExclusionRadius(placementPart, configuredRadius)
	local largestHalf = math.max(placementPart.Size.X, placementPart.Size.Y, placementPart.Size.Z) * 0.5
	return math.min(configuredRadius, largestHalf * 0.65)
end

local function isNearPlacementFootprint(placementPart, worldPoint, buffer)
	buffer = buffer or 0
	local localPoint = placementPart.CFrame:PointToObjectSpace(worldPoint)
	local dims = getSortedPartAxes(placementPart.Size)
	local wideA = dims[2]
	local wideB = dims[3]

	return math.abs(getAxisCoord(wideA.axis, localPoint)) <= wideA.half + buffer
		and math.abs(getAxisCoord(wideB.axis, localPoint)) <= wideB.half + buffer
end

local function getEffectiveMinSpacing(placementPart, totalCount, configuredSpacing)
	local dims = getSortedPartAxes(placementPart.Size)
	local width = dims[2].half * 2
	local depth = dims[3].half * 2
	local area = math.max(1, width * depth)
	local idealSpacing = math.sqrt(area / math.max(1, totalCount)) * 0.75
	return math.clamp(idealSpacing, 7, configuredSpacing)
end

local function localPointToWorld(placementPart, localPoint)
	return placementPart.CFrame:PointToWorldSpace(localPoint)
end

local function raycastGroundAtColumn(worldColumn, topY, raycastIncludes, minNormalY)
	local origin = Vector3.new(worldColumn.X, topY + 30, worldColumn.Z)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = raycastIncludes

	local result = workspace:Raycast(origin, Vector3.new(0, -(topY + 120), 0), rayParams)
	minNormalY = minNormalY or 0.3
	if result and result.Normal.Y > minNormalY then
		return result
	end
	return nil
end

local function tryPlaceOnSurface(worldColumn, placementPart, topY, raycastIncludes, placedPositions, minSpacing, exclusions, minNormalY)
	local result = raycastGroundAtColumn(worldColumn, topY, raycastIncludes, minNormalY)
	if not result then
		return nil
	end

	if not isInsidePlacementFootprint(placementPart, result.Position) then
		return nil
	end

	if not isFarEnough(result.Position, placedPositions, minSpacing, exclusions) then
		return nil
	end

	return result.Position
end

local function buildExclusions(islandModel, spawn, portal, placementPart)
	local exclusions = {}
	local spawnRadius = getSpawnExclusionRadius(placementPart, BiomeResourceConfig.ExclusionRadius.Spawn)
	local portalRadius = getPortalExclusionRadius(placementPart, BiomeResourceConfig.ExclusionRadius.Portal)

	local spawnPos = getObjectPosition(spawn)
	if spawnPos and isNearPlacementFootprint(placementPart, spawnPos, 4) then
		table.insert(exclusions, { position = spawnPos, radius = spawnRadius })
	end

	local portalPos = getObjectPosition(portal)
	if portalPos and isNearPlacementFootprint(placementPart, portalPos, 6) then
		table.insert(exclusions, { position = portalPos, radius = portalRadius })
	end

	for _, child in islandModel:GetChildren() do
		if child:IsA("SpawnLocation") and child ~= spawn then
			local pos = getObjectPosition(child)
			if pos then
				table.insert(exclusions, { position = pos, radius = spawnRadius })
			end
		end
	end

	return exclusions
end

local function ensurePrimaryPart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local largestPart = nil
	local largestVolume = -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = descendant
			end
		end
	end
	if largestPart then
		model.PrimaryPart = largestPart
	end
	return largestPart
end

local function getVisualGroundOffset(visual, rotation)
	local upVector = rotation.UpVector
	local probePos = Vector3.new(0, 200, 0)

	if visual:IsA("Model") then
		ensurePrimaryPart(visual)
		visual:PivotTo(CFrame.new(probePos) * rotation)
	elseif visual:IsA("BasePart") then
		visual.CFrame = CFrame.new(probePos) * rotation
	end

	local bboxCF, bboxSize = visual:GetBoundingBox()
	local halfSize = bboxSize * 0.5
	local minAlongUp = math.huge

	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local corner = bboxCF:PointToWorldSpace(Vector3.new(halfSize.X * sx, halfSize.Y * sy, halfSize.Z * sz))
				minAlongUp = math.min(minAlongUp, corner:Dot(upVector))
			end
		end
	end

	local pivotPos = visual:IsA("Model") and visual:GetPivot().Position or visual.Position
	local pivotAlongUp = pivotPos:Dot(upVector)
	local centerAlongUp = bboxCF.Position:Dot(upVector)

	return {
		pivotToBottom = pivotAlongUp - minAlongUp,
		halfHeight = centerAlongUp - minAlongUp,
	}
end

local function prepareVisualModel(visualModel, visualScale)
	if visualModel:IsA("Model") and visualScale ~= 1 then
		pcall(function()
			visualModel:ScaleTo(visualScale)
		end)
	end
	for _, descendant in visualModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = true
			descendant.CanTouch = false
		end
	end
end

local function createHarvestableNode(canonicalName, islandId, spawnId, placementCFrame)
	local template = getTemplate(canonicalName)
	if not template then
		return nil
	end

	local baseScale = BiomeResourceConfig.BaseCrystalScale or HarvestConfig.CrystalScale or 3.35
	local variation = BiomeResourceConfig.ScaleVariation or 0.1
	local visualScale = baseScale * (1 + (math.random() * 2 - 1) * variation)

	local rotation = placementCFrame - placementCFrame.Position
	local upVector = rotation.UpVector
	local groundPoint = placementCFrame.Position

	local node = Instance.new("Model")
	node.Name = string.format("Biome_%s_%s", islandId, spawnId)

	local visual = template:Clone()
	visual.Name = "Visual"
	prepareVisualModel(visual, visualScale)

	local extents = getVisualGroundOffset(visual, rotation)
	local hitboxCenter = groundPoint + upVector * extents.halfHeight
	local hitboxCFrame = CFrame.new(hitboxCenter) * rotation
	local visualPivotCFrame = CFrame.new(groundPoint + upVector * extents.pivotToBottom) * rotation

	local hitbox = Instance.new("Part")
	hitbox.Name = "HarvestHitbox"
	hitbox.Size = BiomeResourceConfig.HitboxSize
	hitbox.Anchored = true
	hitbox.CanCollide = true
	hitbox.CanQuery = true
	hitbox.CanTouch = true
	hitbox.Transparency = 1
	hitbox.CFrame = hitboxCFrame
	hitbox.Parent = node

	if visual:IsA("Model") then
		ensurePrimaryPart(visual)
		visual:PivotTo(visualPivotCFrame)
	elseif visual:IsA("BasePart") then
		visual.CFrame = visualPivotCFrame
	end
	visual.Parent = node

	node.PrimaryPart = hitbox
	node:PivotTo(hitboxCFrame)

	local maxHealth = math.floor(HarvestConfig.NodeMaxHealth * IslandUnlockConfig.GetHealthMultiplier(islandId) + 0.5)

	node:SetAttribute("BiomeResource", true)
	node:SetAttribute("IslandId", islandId)
	node:SetAttribute("ResourceType", canonicalName)
	node:SetAttribute("SpawnId", spawnId)
	node:SetAttribute("HarvestHitboxScale", baseScale)
	node:SetAttribute("VisualScale", visualScale)
	node:SetAttribute("MaxHealth", maxHealth)
	node:SetAttribute("Health", maxHealth)
	node:SetAttribute("Depleted", false)

	return node
end

function BiomeResourcePlacer.FindPositions(islandModel, spawn, portal, placementPart, totalCount)
	if not placementPart then
		return {}
	end

	local exclusions = buildExclusions(islandModel, spawn, portal, placementPart)
	local minSpacing = getEffectiveMinSpacing(placementPart, totalCount, BiomeResourceConfig.MinNodeSpacing)
	local edgeMargin = BiomeResourceConfig.PlacementEdgeMargin or 0.08
	local raycastIncludes = buildRaycastIncludes(islandModel, placementPart)
	local topY = getPartWorldTopY(placementPart)
	local positions = {}
	local attempts = 0
	local maxAttempts = math.max(BiomeResourceConfig.MaxPlacementAttempts, totalCount * 80)

	local function tryAddFromLocalPoint(localPoint, spacing, minNormalY)
		if #positions >= totalCount then
			return
		end

		local worldColumn = localPointToWorld(placementPart, localPoint)
		local placedPosition = tryPlaceOnSurface(
			worldColumn,
			placementPart,
			topY,
			raycastIncludes,
			positions,
			spacing,
			exclusions,
			minNormalY
		)
		if placedPosition then
			table.insert(positions, placedPosition)
		end
	end

	local function fillPositions(spacing, minNormalY)
		attempts = 0
		while #positions < totalCount and attempts < maxAttempts do
			attempts += 1
			tryAddFromLocalPoint(randomLocalPointInPart(placementPart, edgeMargin), spacing, minNormalY)
		end

		for ringIndex = 1, totalCount * 6 do
			if #positions >= totalCount then
				break
			end

			local angle = (ringIndex / math.max(1, totalCount)) * math.pi * 2 + math.random() * 0.35
			local radiusFactor = 0.15 + (ringIndex % 7) * 0.1
			tryAddFromLocalPoint(ringLocalPointInPart(placementPart, edgeMargin, angle, radiusFactor), spacing, minNormalY)
		end

		local dims = getSortedPartAxes(placementPart.Size)
		local wideA = dims[2]
		local wideB = dims[3]
		local thinAxis = dims[1]
		local gridSteps = math.ceil(math.sqrt(totalCount)) + 2

		for stepA = 1, gridSteps do
			if #positions >= totalCount then
				break
			end
			for stepB = 1, gridSteps do
				if #positions >= totalCount then
					break
				end

				local coords = { X = 0, Y = 0, Z = 0 }
				local factorA = ((stepA / (gridSteps + 1)) * 2 - 1)
				local factorB = ((stepB / (gridSteps + 1)) * 2 - 1)
				setAxisCoord(wideA.axis, coords, factorA * wideA.half * (1 - edgeMargin))
				setAxisCoord(wideB.axis, coords, factorB * wideB.half * (1 - edgeMargin))
				setAxisCoord(thinAxis.axis, coords, thinAxis.half * (1 - edgeMargin))
				tryAddFromLocalPoint(Vector3.new(coords.X, coords.Y, coords.Z), spacing, minNormalY)
			end
		end
	end

	fillPositions(minSpacing, 0.3)
	if #positions < totalCount then
		fillPositions(math.max(7, minSpacing * 0.82), 0.22)
	end
	if #positions < totalCount then
		fillPositions(math.max(7, minSpacing * 0.68), 0.15)
	end

	return positions
end

function BiomeResourcePlacer.SpawnFromRecord(record, parentFolder)
	if typeof(record) ~= "table" or typeof(record.spawnId) ~= "string" then
		return nil
	end

	local pivot = record.pivot
	if typeof(pivot) ~= "CFrame" then
		return nil
	end

	local node = createHarvestableNode(record.resourceType, record.islandId, record.spawnId, pivot)
	if not node then
		return nil
	end

	node.Parent = parentFolder
	BiomeResourceRegistry.RegisterNode(node, record.spawnId)
	return node
end

function BiomeResourcePlacer.PlaceIslandResources(islandId, islandModel, spawn, portal, resourcesFolder)
	local resourceTypes = BiomeResourceConfig.GetResourcesForIsland(islandId)
	if #resourceTypes == 0 then
		return 0
	end

	local placementPart = findPlacementPart(islandModel)
	if not placementPart then
		warn(string.format("[BiomeResourcePlacer] Missing placement Part for %s", islandId))
		return 0
	end

	hidePlacementPart(placementPart)

	local nodesPerType = BiomeResourceConfig.NodesPerType
	local totalCount = nodesPerType * #resourceTypes
	local positions = BiomeResourcePlacer.FindPositions(islandModel, spawn, portal, placementPart, totalCount)
	if #positions == 0 then
		warn(string.format("[BiomeResourcePlacer] No valid positions found for %s", islandId))
		return 0
	end

	local placed = 0
	local positionIndex = 1

	for _, canonicalName in resourceTypes do
		for nodeIndex = 1, nodesPerType do
			if positionIndex > #positions then
				break
			end

			local worldPos = positions[positionIndex]
			positionIndex += 1
			local yaw = math.random() * math.pi * 2
			local pitch = math.rad(math.random(-8, 8))
			local roll = math.rad(math.random(-8, 8))
			local pivot = CFrame.new(worldPos) * CFrame.Angles(pitch, yaw, roll)

			local spawnId = string.format("%s_%s_%02d", islandId, canonicalName, nodeIndex)
			local record = {
				spawnId = spawnId,
				islandId = islandId,
				resourceType = canonicalName,
				pivot = pivot,
			}
			BiomeResourceRegistry.RegisterSpawnRecord(record)
			local node = BiomeResourcePlacer.SpawnFromRecord(record, resourcesFolder)
			if node then
				placed += 1
			end
		end
	end

	return placed
end

return BiomeResourcePlacer
