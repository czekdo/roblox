--[[ IslandArranger
	Arranges the 7 biome islands evenly in a circle around the central Island
	and rotates each so its bridge/forward faces the center.
	Moves each island's assigned SpawnLocation and HubPortal with the same transform.
	Runs once on start then disables itself.
]]
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local IslandPortalRegistry = require(ReplicatedStorage:WaitForChild("IslandPortalRegistry"))

local FOLDER_NAME = IslandUnlockConfig.FolderName
local ISLAND_SPAWN_NAME = "IslandSpawn"
local SPACING_BUFFER = 60
local Y_OFFSET = 0
local MATCH_MAX_DISTANCE = 220

local EXCLUDED_SPAWN_NAMES = {
	SpawnLocation = true,
	SpawnLocation2 = true,
}

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

local function getBoundingInfo(model)
	local cframe, size = model:GetBoundingBox()
	return cframe, size
end

local function getObjectPosition(instance)
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

local function getDistanceToIsland(instance, islandModel)
	local position = getObjectPosition(instance)
	if not position then
		return math.huge
	end

	local cframe, size = islandModel:GetBoundingBox()
	local localPoint = cframe:PointToObjectSpace(position)
	local halfSize = size * 0.5
	local clamped = Vector3.new(
		math.clamp(localPoint.X, -halfSize.X, halfSize.X),
		math.clamp(localPoint.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPoint.Z, -halfSize.Z, halfSize.Z)
	)
	local nearest = cframe:PointToWorldSpace(clamped)
	return (position - nearest).Magnitude
end

local function applyDeltaTransform(instance, delta)
	if instance:IsA("Model") then
		instance:PivotTo(delta * instance:GetPivot())
	elseif instance:IsA("BasePart") then
		instance.CFrame = delta * instance.CFrame
	end
end

local function collectCandidateSpawns(biomeIslands)
	local candidates = {}
	local seen = {}

	local function addSpawn(spawn)
		if not spawn or not spawn:IsA("SpawnLocation") or seen[spawn] then
			return
		end
		if EXCLUDED_SPAWN_NAMES[spawn.Name] then
			return
		end
		seen[spawn] = true
		local position = getObjectPosition(spawn)
		if position then
			table.insert(candidates, spawn)
		end
	end

	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			if EXCLUDED_SPAWN_NAMES[descendant.Name] then
				continue
			end
			if descendant.Name == ISLAND_SPAWN_NAME or descendant.Parent == Workspace then
				addSpawn(descendant)
			end
		end
	end

	for _, island in biomeIslands do
		local childSpawn = island:FindFirstChild(ISLAND_SPAWN_NAME)
		if childSpawn then
			addSpawn(childSpawn)
		end
	end

	return candidates
end

local function collectCandidatePortals()
	local candidates = {}
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child.Name:match("^HubPortal%d+$") then
			local position = getObjectPosition(child)
			if position then
				table.insert(candidates, child)
			end
		end
	end
	return candidates
end

local function buildIslandAttachments(biomeIslands, spawns, portals)
	local attachments = {}
	for _, island in biomeIslands do
		attachments[island] = {
			spawn = nil,
			portal = nil,
		}

		local childSpawn = island:FindFirstChild(ISLAND_SPAWN_NAME)
		if childSpawn and childSpawn:IsA("SpawnLocation") then
			attachments[island].spawn = childSpawn
		end
	end

	local function assignNearest(candidates, key)
		local remainingIslands = {}
		for _, island in biomeIslands do
			if not attachments[island][key] then
				table.insert(remainingIslands, island)
			end
		end
		if #remainingIslands == 0 or #candidates == 0 then
			return
		end

		local usedCandidates = {}
		for _, island in biomeIslands do
			local assigned = attachments[island][key]
			if assigned then
				usedCandidates[assigned] = true
			end
		end

		local pairsList = {}
		for _, island in remainingIslands do
			for _, candidate in candidates do
				if usedCandidates[candidate] then
					continue
				end
				local candidatePos = getObjectPosition(candidate)
				if candidatePos then
					local distance = getDistanceToIsland(candidate, island)
					if distance <= MATCH_MAX_DISTANCE then
						table.insert(pairsList, {
							island = island,
							object = candidate,
							distance = distance,
						})
					end
				end
			end
		end

		table.sort(pairsList, function(a, b)
			return a.distance < b.distance
		end)

		local usedIslands = {}
		for _, pair in pairsList do
			if not usedCandidates[pair.object] and not usedIslands[pair.island] then
				attachments[pair.island][key] = pair.object
				usedCandidates[pair.object] = true
				usedIslands[pair.island] = true
			end
		end
	end

	assignNearest(spawns, "spawn")
	assignNearest(portals, "portal")

	return attachments
end

local function moveIslandAttachments(islandModel, oldPivot, newPivot, attachment)
	local delta = newPivot * oldPivot:Inverse()

	if attachment.spawn and not attachment.spawn:IsDescendantOf(islandModel) then
		applyDeltaTransform(attachment.spawn, delta)
	end
	if attachment.portal and not attachment.portal:IsDescendantOf(islandModel) then
		applyDeltaTransform(attachment.portal, delta)
	end

	islandModel:PivotTo(newPivot)
end

local function isSpawnAboveIslandSurface(spawn, islandModel)
	if not spawn or not islandModel then
		return false
	end

	local spawnPos = spawn.Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { islandModel }

	local result = Workspace:Raycast(
		spawnPos + Vector3.new(0, 8, 0),
		Vector3.new(0, -120, 0),
		rayParams
	)
	if not result or result.Normal.Y < 0.45 then
		return false
	end

	local heightDelta = spawnPos.Y - result.Position.Y
	return heightDelta >= -1 and heightDelta <= 20
end

local function isPortalAccessible(portal, islandModel)
	if not portal or not islandModel then
		return false
	end

	local portalPos = getObjectPosition(portal)
	if not portalPos then
		return false
	end

	if getDistanceToIsland(portal, islandModel) > MATCH_MAX_DISTANCE then
		return false
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { islandModel }

	for _, offset in {
		Vector3.new(0, 0, 0),
		Vector3.new(6, 0, 0),
		Vector3.new(-6, 0, 0),
		Vector3.new(0, 0, 6),
		Vector3.new(0, 0, -6),
	} do
		local sample = portalPos + offset
		local result = Workspace:Raycast(
			sample + Vector3.new(0, 12, 0),
			Vector3.new(0, -80, 0),
			rayParams
		)
		if result and result.Normal.Y > 0.45 then
			return true
		end
	end

	return false
end

local function verifyAttachments(biomeIslands, attachments)
	for _, island in biomeIslands do
		local attachment = attachments[island]
		local label = island.Name

		local spawn = attachment.spawn or island:FindFirstChild(ISLAND_SPAWN_NAME)
		if not spawn then
			warn(string.format("[IslandArranger] No SpawnLocation matched for '%s'", label))
		elseif not isSpawnAboveIslandSurface(spawn, island) then
			warn(string.format("[IslandArranger] SpawnLocation for '%s' may be below or above island surface (%s)", label, spawn:GetFullName()))
		end

		if not attachment.portal then
			warn(string.format("[IslandArranger] No HubPortal matched for '%s'", label))
		elseif not isPortalAccessible(attachment.portal, island) then
			warn(string.format("[IslandArranger] HubPortal for '%s' may be inaccessible (%s)", label, attachment.portal:GetFullName()))
		end
	end
end

local function reportUnmatched(biomeIslands, attachments, spawns, portals)
	local matchedSpawns = {}
	local matchedPortals = {}
	for _, island in biomeIslands do
		if attachments[island].spawn then
			matchedSpawns[attachments[island].spawn] = true
		end
		if attachments[island].portal then
			matchedPortals[attachments[island].portal] = true
		end
	end

	for _, spawn in spawns do
		if not matchedSpawns[spawn] then
			warn(string.format("[IslandArranger] SpawnLocation could not be matched to an island: %s", spawn:GetFullName()))
		end
	end

	for _, portal in portals do
		if not matchedPortals[portal] then
			warn(string.format("[IslandArranger] HubPortal could not be matched to an island: %s", portal:GetFullName()))
		end
	end
end

-- Wait for the central Island model
local islandMainFolder = Workspace:WaitForChild("islandMain", 30)
local centralIsland = islandMainFolder and islandMainFolder:WaitForChild("Island", 30)
if not centralIsland then
	warn("[IslandArranger] Central Island model not found under Workspace.islandMain")
	return
end

local biomeFolder = Workspace:WaitForChild(FOLDER_NAME, 30)
if not biomeFolder then
	warn("[IslandArranger] Folder '" .. FOLDER_NAME .. "' not found in Workspace")
	return
end

local biomeIslands = {}
for _, islandConfig in IslandUnlockConfig.Islands do
	local model = biomeFolder:WaitForChild(islandConfig.ModelName, 30)
	if not model then
		warn("[IslandArranger] Island model '" .. islandConfig.ModelName .. "' not found in folder '" .. FOLDER_NAME .. "'")
		return
	end
	table.insert(biomeIslands, model)
end

local spawnCandidates = collectCandidateSpawns(biomeIslands)
local portalCandidates = collectCandidatePortals()
local islandAttachments = buildIslandAttachments(biomeIslands, spawnCandidates, portalCandidates)

for _, islandConfig in IslandUnlockConfig.Islands do
	local islandModel = biomeFolder:FindFirstChild(islandConfig.ModelName)
	if islandModel then
		local attachment = islandAttachments[islandModel]
		if attachment then
			IslandPortalRegistry.Register(
				islandConfig.Id,
				islandModel,
				attachment.spawn,
				attachment.portal
			)
		end
	end
end
IslandPortalRegistry.MarkReady()

for _, island in biomeIslands do
	local attachment = islandAttachments[island]
	local spawnName = attachment.spawn and attachment.spawn.Name or "none"
	local portalName = attachment.portal and attachment.portal.Name or "none"
	print(string.format("[IslandArranger] '%s' -> Spawn=%s, Portal=%s", island.Name, spawnName, portalName))
end

local centralCFrame, centralSize = getBoundingInfo(centralIsland)
local center = centralCFrame.Position

local maxRadius = 0
for _, model in biomeIslands do
	ensurePrimaryPart(model)
	local _, size = getBoundingInfo(model)
	local radius = math.max(size.X, size.Z) * 0.5
	if radius > maxRadius then
		maxRadius = radius
	end
end

local centralRadius = math.max(centralSize.X, centralSize.Z) * 0.5
local circleRadius = centralRadius + maxRadius + SPACING_BUFFER

print(string.format("[IslandArranger] Center: %s, Circle radius: %.1f", tostring(center), circleRadius))

local count = #biomeIslands
for i, model in ipairs(biomeIslands) do
	local angle = (i - 1) * (2 * math.pi / count)
	local targetPos = Vector3.new(
		center.X + math.cos(angle) * circleRadius,
		center.Y + Y_OFFSET,
		center.Z + math.sin(angle) * circleRadius
	)

	local targetCFrame = CFrame.lookAt(targetPos, Vector3.new(center.X, targetPos.Y, center.Z))
	local oldPivot = model:GetPivot()

	moveIslandAttachments(model, oldPivot, targetCFrame, islandAttachments[model])

	print(string.format(
		"[IslandArranger] Placed '%s' at angle %.1f° pos %s",
		model.Name,
		math.deg(angle),
		tostring(targetPos)
	))
end

verifyAttachments(biomeIslands, islandAttachments)
reportUnmatched(biomeIslands, islandAttachments, spawnCandidates, portalCandidates)

print("[IslandArranger] All 7 islands arranged around central Island. Script disabling.")
script.Disabled = true