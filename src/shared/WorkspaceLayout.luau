local WorkspaceLayout = {}

WorkspaceLayout.MainIslandFolderName = "islandMain"
WorkspaceLayout.MainIslandModelName = "Island"
WorkspaceLayout.HubModelName = "Hub"
WorkspaceLayout.HubSpawnName = "SpawnLocation2"
WorkspaceLayout.HubSpawnPointName = "HubSpawnPoint"
WorkspaceLayout.MainIslandSpawnName = "SpawnLocation"
WorkspaceLayout.HubPortalName = "HubPortal"
WorkspaceLayout.MainIslandPortalName = "MainIslandPortal"
WorkspaceLayout.CrystalSpawnPointNames = { "1", "2", "3", "4", "5" }

local function findNamedChild(className, name)
	local instance = workspace:FindFirstChild(name)
	if instance and instance:IsA(className) then
		return instance
	end
	return nil
end

function WorkspaceLayout.GetMainIslandContainer()
	return workspace:FindFirstChild(WorkspaceLayout.MainIslandFolderName)
end

function WorkspaceLayout.GetMainIsland()
	local container = WorkspaceLayout.GetMainIslandContainer()
	local island = container and container:FindFirstChild(WorkspaceLayout.MainIslandModelName)
	if island and island:IsA("Model") then
		return island
	end
	return nil
end

function WorkspaceLayout.GetHub()
	local hub = workspace:FindFirstChild(WorkspaceLayout.HubModelName)
	if hub and hub:IsA("Model") then
		return hub
	end
	return nil
end

function WorkspaceLayout.GetHubSpawn()
	return findNamedChild("SpawnLocation", WorkspaceLayout.HubSpawnName)
end

function WorkspaceLayout.GetHubSpawnPoint()
	local point = workspace:FindFirstChild(WorkspaceLayout.HubSpawnPointName)
	if point and point:IsA("BasePart") then
		return point
	end
	return nil
end

function WorkspaceLayout.GetMainIslandSpawn()
	return findNamedChild("SpawnLocation", WorkspaceLayout.MainIslandSpawnName)
end

function WorkspaceLayout.GetHubPortal()
	local portal = workspace:FindFirstChild(WorkspaceLayout.HubPortalName)
	if portal and portal:IsA("Model") then
		return portal
	end
	return nil
end

function WorkspaceLayout.GetMainIslandPortal()
	local portal = workspace:FindFirstChild(WorkspaceLayout.MainIslandPortalName)
	if portal and portal:IsA("Model") then
		return portal
	end
	return nil
end

function WorkspaceLayout.GetPlayerIsland(player)
	local container = WorkspaceLayout.GetMainIslandContainer()
	if not container then
		return nil
	end
	local ownerUserId = container:GetAttribute("OwnerUserId")
	if ownerUserId == nil or ownerUserId == player.UserId then
		return container
	end
	return nil
end

function WorkspaceLayout.GetCrystalSpawnPoints()
	local points = {}
	for _, name in WorkspaceLayout.CrystalSpawnPointNames do
		local point = workspace:FindFirstChild(name)
		if point and point:IsA("BasePart") then
			table.insert(points, point)
		else
			warn("[WorkspaceLayout] Missing crystal spawn point:", name)
		end
	end
	return points
end

local DEFAULT_HIP_HEIGHT = 3
local HUB_SPAWN_YAW = math.rad(180)

local function getHubSpawnSamplePosition()
	local spawnPoint = WorkspaceLayout.GetHubSpawnPoint()
	if spawnPoint then
		return spawnPoint.Position
	end

	local hubSpawn = WorkspaceLayout.GetHubSpawn()
	if hubSpawn then
		return hubSpawn.Position
	end

	local hub = WorkspaceLayout.GetHub()
	if hub then
		return hub:GetPivot().Position
	end

	return Vector3.new(1000, -50, -56)
end

local function raycastLocalSurface(position, includeInstances, ignoreInstances, castUp, castDown)
	local rayParams = RaycastParams.new()
	if includeInstances and #includeInstances > 0 then
		rayParams.FilterType = Enum.RaycastFilterType.Include
		rayParams.FilterDescendantsInstances = includeInstances
	else
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = ignoreInstances or {}
	end

	local origin = position + Vector3.new(0, castUp or 12, 0)
	local direction = Vector3.new(0, -(castDown or 80), 0)
	return workspace:Raycast(origin, direction, rayParams)
end

local function getSurfaceCFrameNear(position, includeInstances, ignoreInstances, hipHeight, yaw)
	hipHeight = hipHeight or DEFAULT_HIP_HEIGHT
	yaw = yaw or 0

	local result = raycastLocalSurface(position, includeInstances, ignoreInstances)
	if result then
		return CFrame.new(result.Position + Vector3.new(0, hipHeight, 0)) * CFrame.Angles(0, yaw, 0)
	end

	return CFrame.new(position + Vector3.new(0, hipHeight, 0)) * CFrame.Angles(0, yaw, 0)
end

function WorkspaceLayout.GetHubSpawnCFrame(hipHeight)
	local hub = WorkspaceLayout.GetHub()
	local samplePosition = getHubSpawnSamplePosition()

	if hub then
		return getSurfaceCFrameNear(samplePosition, { hub }, nil, hipHeight, HUB_SPAWN_YAW)
	end

	local ignoreInstances = {}
	local spawnPoint = WorkspaceLayout.GetHubSpawnPoint()
	if spawnPoint then
		table.insert(ignoreInstances, spawnPoint)
	end
	local hubSpawn = WorkspaceLayout.GetHubSpawn()
	if hubSpawn then
		table.insert(ignoreInstances, hubSpawn)
	end

	return getSurfaceCFrameNear(samplePosition, nil, ignoreInstances, hipHeight, HUB_SPAWN_YAW)
end

function WorkspaceLayout.PlaceCharacterOnHub(player)
	local character = player.Character
	if not character then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = WorkspaceLayout.GetHubSpawnCFrame(humanoid.HipHeight)
	return true
end

function WorkspaceLayout.GetIslandSpawnCFrame()
	local island = WorkspaceLayout.GetMainIsland()
	local islandSpawn = WorkspaceLayout.GetMainIslandSpawn()
	local samplePosition

	if islandSpawn then
		samplePosition = islandSpawn.Position
	elseif island then
		samplePosition = island:GetPivot().Position
	else
		return CFrame.new(0, 10, 0)
	end

	local ignoreInstances = {}
	if islandSpawn then
		table.insert(ignoreInstances, islandSpawn)
	end
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(ignoreInstances, player.Character)
		end
	end

	if island then
		return getSurfaceCFrameNear(samplePosition, { island }, nil, DEFAULT_HIP_HEIGHT, 0)
	end
	return getSurfaceCFrameNear(samplePosition, nil, ignoreInstances, DEFAULT_HIP_HEIGHT, 0)
end

function WorkspaceLayout.GetPortalSpawnCFrame(portalModel)
	if portalModel and portalModel:IsA("Model") then
		local pivot = portalModel:GetPivot()
		local forward = pivot.LookVector
		local spawnPosition = pivot.Position + forward * 10
		return getSurfaceCFrameNear(spawnPosition, { portalModel }, nil, DEFAULT_HIP_HEIGHT, 0)
	end
	return WorkspaceLayout.GetHubSpawnCFrame()
end

return WorkspaceLayout
