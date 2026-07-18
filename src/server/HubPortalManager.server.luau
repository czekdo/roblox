local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local IslandUnlockConfig = require(ReplicatedStorage:WaitForChild("IslandUnlockConfig"))
local IslandPortalRegistry = require(ReplicatedStorage:WaitForChild("IslandPortalRegistry"))
local IslandTeleportService = require(ServerScriptService:WaitForChild("IslandTeleportService"))
local IslandEvents = ReplicatedStorage:WaitForChild("IslandEvents")
local PortalTravel = IslandEvents:WaitForChild("PortalTravel")
local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestProgressSignal = QuestEvents:WaitForChild("QuestProgressSignal")

local ZONE_HUB = "Hub"
local ZONE_MAIN_ISLAND = "MainIsland"
local TELEPORT_COOLDOWN = 2
local FADE_IN_TIME = 0.45
local FADE_HOLD_TIME = 0.15
local HUB_PORTAL_MARGIN = 40

local teleportCooldown = {}
local connectedPortals = {}

local function getPortalPromptPart(portalModel)
	local interactionAnchor = portalModel:FindFirstChild("InteractionAnchor")
	if not interactionAnchor then
		interactionAnchor = portalModel:WaitForChild("InteractionAnchor", 10)
	end
	if interactionAnchor and interactionAnchor:IsA("BasePart") then
		return interactionAnchor
	end

	if portalModel.PrimaryPart and portalModel.PrimaryPart:IsA("BasePart") then
		return portalModel.PrimaryPart
	end

	local largestPart = nil
	local largestVolume = -math.huge
	for _, descendant in portalModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			local volume = descendant.Size.X * descendant.Size.Y * descendant.Size.Z
			if volume > largestVolume then
				largestVolume = volume
				largestPart = descendant
			end
		end
	end

	if largestPart then
		portalModel.PrimaryPart = largestPart
	end
	return largestPart
end

local function waitForPortalRouting()
	local arranger = ServerScriptService:FindFirstChild("IslandArranger")
	if arranger and arranger:IsA("Script") then
		local start = os.clock()
		while arranger.Enabled and os.clock() - start < 35 do
			task.wait(0.1)
		end
	end

	IslandPortalRegistry.WaitUntilReady(10)

	local start = os.clock()
	while not IslandTeleportService.IsReady() and os.clock() - start < 20 do
		task.wait(0.1)
	end
end

local function getHorizontalDistance(a, b)
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function getDistanceToModel(instance, model)
	if not instance or not model then
		return math.huge
	end

	local position
	if instance:IsA("Model") then
		position = instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		position = instance.Position
	else
		return math.huge
	end

	local cframe, size = model:GetBoundingBox()
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

local function isHubOutboundPortal(portalModel, islandModel)
	local hub = WorkspaceLayout.GetHub()
	if not hub then
		return false
	end

	local portalPos = portalModel:GetPivot().Position
	local hubPos = hub:GetPivot().Position
	local hubExtents = hub:GetExtentsSize()
	local hubRadius = math.max(hubExtents.X, hubExtents.Z) * 0.5 + HUB_PORTAL_MARGIN

	local nearHub = getHorizontalDistance(portalPos, hubPos) <= hubRadius
	if not nearHub then
		return false
	end

	if not islandModel then
		return true
	end

	local hubDistance = getHorizontalDistance(portalPos, hubPos)
	local islandDistance = getDistanceToModel(portalModel, islandModel)
	return hubDistance <= islandDistance
end

local function teleportPlayer(player, destinationZone)
	if teleportCooldown[player] then
		return
	end

	teleportCooldown[player] = true
	task.delay(TELEPORT_COOLDOWN, function()
		teleportCooldown[player] = nil
	end)

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	local targetCFrame
	if destinationZone == ZONE_MAIN_ISLAND then
		targetCFrame = WorkspaceLayout.GetIslandSpawnCFrame()
		player:SetAttribute("CurrentZone", ZONE_MAIN_ISLAND)
		player:SetAttribute("CurrentIslandId", "MainIsland")
	else
		targetCFrame = WorkspaceLayout.GetHubSpawnCFrame()
		player:SetAttribute("CurrentZone", ZONE_HUB)
		player:SetAttribute("CurrentIslandId", ZONE_HUB)
		QuestProgressSignal:Fire(player, "VisitHub", 1)
	end

	PortalTravel:FireClient(player, "fadeIn")
	task.wait(FADE_IN_TIME + FADE_HOLD_TIME)

	humanoid.Sit = false
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = targetCFrame

	task.wait()
	PortalTravel:FireClient(player, "fadeOut")
end

local function connectPortal(portalModel, onTriggered, actionText, objectText)
	if not portalModel or connectedPortals[portalModel] then
		return
	end

	local promptPart = getPortalPromptPart(portalModel)
	if not promptPart then
		warn("[HubPortalManager] Portal has no usable part:", portalModel:GetFullName())
		return
	end

	local prompt = promptPart:FindFirstChild("PortalPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PortalPrompt"
		prompt.Parent = promptPart
	end

	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false

	prompt.Triggered:Connect(onTriggered)

	connectedPortals[portalModel] = true
end

local function connectMainHubPortal()
	local hubPortal = WorkspaceLayout.GetHubPortal()
	if not hubPortal then
		return
	end

	connectPortal(hubPortal, function(player)
		teleportPlayer(player, ZONE_MAIN_ISLAND)
	end, "Travel", "Main Island")
end

local function connectBiomePortals()
	waitForPortalRouting()

	local connectedCount = 0
	local unmatchedPortals = {}

	for _, child in workspace:GetChildren() do
		if not (child:IsA("Model") and child.Name:match("^HubPortal%d+$")) then
			continue
		end

		local islandId = IslandPortalRegistry.GetIslandIdForPortal(child)
		if not islandId then
			table.insert(unmatchedPortals, child:GetFullName())
			continue
		end

		local entry = IslandPortalRegistry.GetByIslandId(islandId)
		local islandConfig = IslandUnlockConfig.GetIslandById(islandId)
		local islandLabel = islandConfig and islandConfig.DisplayName or islandId

		if isHubOutboundPortal(child, entry and entry.model or nil) then
			connectPortal(child, function(player)
				IslandTeleportService.TeleportToIsland(player, islandId)
			end, "Travel", islandLabel)
		else
			connectPortal(child, function(player)
				IslandTeleportService.TeleportToHub(player)
			end, "Return", "Hub")
		end

		connectedCount += 1
	end

	if connectedCount == 0 then
		warn("[HubPortalManager] No biome HubPortals were connected")
	end

	for _, portalPath in unmatchedPortals do
		warn("[HubPortalManager] HubPortal could not be matched to an island:", portalPath)
	end
end

local function setupPortals()
	task.defer(connectMainHubPortal)
	task.defer(connectBiomePortals)
end

setupPortals()

workspace.ChildAdded:Connect(function(child)
	if child.Name == WorkspaceLayout.HubPortalName then
		task.defer(connectMainHubPortal)
	elseif child:IsA("Model") and child.Name:match("^HubPortal%d+$") then
		task.defer(connectBiomePortals)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	teleportCooldown[player] = nil
end)

print("[HubPortalManager] Hub, biome, and return portals ready")
