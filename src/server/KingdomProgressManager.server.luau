local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local BuildingConfig = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WorkspaceLayout = require(ReplicatedStorage:WaitForChild("WorkspaceLayout"))
local KingdomEvents = ReplicatedStorage:WaitForChild("KingdomEvents")
local RequestKingdomData = KingdomEvents:WaitForChild("RequestKingdomData")
local UpdateKingdomName = KingdomEvents:WaitForChild("UpdateKingdomName")
local PlaceDecoration = KingdomEvents:WaitForChild("PlaceDecoration")
local KingdomStateUpdated = KingdomEvents:WaitForChild("KingdomStateUpdated")
local GrantDecoration = KingdomEvents:WaitForChild("GrantDecoration")

local KINGDOM_DATASTORE = "KingdomProgressV1"
local DEFAULT_NAME = "Dragon Island Kingdom"
local MAX_NAME_LENGTH = 28
local MAX_DECORATIONS = 12

local DECORATION_DEFS = {
	CrystalCrown = {
		DisplayName = "Crystal Crown",
		Size = Vector3.new(2.4, 3.2, 2.4),
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
	},
	DragonBanner = {
		DisplayName = "Dragon Banner",
		Size = Vector3.new(0.3, 6, 3.5),
		Color = Color3.fromRGB(120, 60, 160),
		Material = Enum.Material.Fabric,
	},
	StoneLantern = {
		DisplayName = "Stone Lantern",
		Size = Vector3.new(1.4, 2.8, 1.4),
		Color = Color3.fromRGB(150, 145, 140),
		Material = Enum.Material.Slate,
	},
	GoldenStatue = {
		DisplayName = "Golden Statue",
		Size = Vector3.new(2, 4.5, 2),
		Color = Color3.fromRGB(218, 175, 70),
		Material = Enum.Material.Metal,
	},
	StormBanner = {
		DisplayName = "Storm Banner",
		Size = Vector3.new(0.35, 7, 4),
		Color = Color3.fromRGB(70, 120, 220),
		Material = Enum.Material.Neon,
	},
	PlatinumCrown = {
		DisplayName = "Platinum Crown",
		Size = Vector3.new(2.8, 3.6, 2.8),
		Color = Color3.fromRGB(220, 230, 245),
		Material = Enum.Material.Glass,
	},
	ObsidianThrone = {
		DisplayName = "Obsidian Throne",
		Size = Vector3.new(3.2, 4.2, 2.8),
		Color = Color3.fromRGB(35, 30, 45),
		Material = Enum.Material.Slate,
	},
	CelestialObelisk = {
		DisplayName = "Celestial Obelisk",
		Size = Vector3.new(2.2, 8, 2.2),
		Color = Color3.fromRGB(180, 140, 255),
		Material = Enum.Material.Neon,
	},
}

local kingdomStore = nil
local dataStoreAvailable = false
if game.GameId ~= 0 then
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(KINGDOM_DATASTORE)
	end)
	if success then
		kingdomStore = result
		dataStoreAvailable = true
	end
end

local playerKingdomData = {}
local saveQueued = {}
local decorationFolders = {}

local function sanitizeName(name)
	if typeof(name) ~= "string" then
		return DEFAULT_NAME
	end
	name = string.gsub(name, "%s+", " ")
	name = string.gsub(name, "^%s+", "")
	name = string.gsub(name, "%s+$", "")
	if name == "" or #name > MAX_NAME_LENGTH then
		return DEFAULT_NAME
	end
	return name
end

local function getData(player)
	if not playerKingdomData[player] then
		playerKingdomData[player] = {
			kingdomName = DEFAULT_NAME,
			lifetimeEssence = 0,
			decorations = {},
			loaded = false,
		}
	end
	return playerKingdomData[player]
end

local function computeKingdomLevel(player)
	local data = getData(player)
	local buildingLevels = 0
	local island = WorkspaceLayout.GetPlayerIsland(player)
	if island then
		for _, typeId in BuildingConfig.BuildingOrder do
			local model = island:FindFirstChild(typeId)
			if model then
				buildingLevels += math.max(1, model:GetAttribute("BuildingLevel") or 1)
			end
		end
	end

	local dragonCount = 0
	local dragonsFolder = workspace:FindFirstChild("DragonWorkers")
	if dragonsFolder then
		for _, dragon in dragonsFolder:GetChildren() do
			if dragon:GetAttribute("OwnerUserId") == player.UserId then
				dragonCount += 1
			end
		end
	end

	local lifetime = math.max(0, data.lifetimeEssence or 0)
	local level = math.floor(1 + buildingLevels * 0.45 + dragonCount * 0.35 + math.sqrt(lifetime / 400))
	return math.max(1, level)
end

local function getDecorationFolder(player)
	if decorationFolders[player] and decorationFolders[player].Parent then
		return decorationFolders[player]
	end
	local island = WorkspaceLayout.GetPlayerIsland(player)
	if not island then
		return nil
	end
	local folder = island:FindFirstChild("KingdomDecorations")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "KingdomDecorations"
		folder.Parent = island
	end
	decorationFolders[player] = folder
	return folder
end

local function buildDecorationModel(player, decorationId, position)
	local def = DECORATION_DEFS[decorationId]
	if not def then
		return nil
	end
	local folder = getDecorationFolder(player)
	if not folder then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = decorationId .. "_" .. tostring(#folder:GetChildren() + 1)

	local part = Instance.new("Part")
	part.Name = "Base"
	part.Size = def.Size
	part.Color = def.Color
	part.Material = def.Material
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position)
	part.Parent = model

	if decorationId == "CrystalCrown" then
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Brightness = 1.2
		light.Range = 10
		light.Parent = part
	elseif decorationId == "StoneLantern" then
		local flame = Instance.new("Part")
		flame.Name = "Flame"
		flame.Size = Vector3.new(0.6, 0.8, 0.6)
		flame.Shape = Enum.PartType.Ball
		flame.Material = Enum.Material.Neon
		flame.Color = Color3.fromRGB(255, 200, 90)
		flame.Anchored = true
		flame.CanCollide = false
		flame.CFrame = part.CFrame * CFrame.new(0, def.Size.Y * 0.5 + 0.3, 0)
		flame.Parent = model
	elseif decorationId == "StormBanner" then
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Brightness = 1
		light.Range = 12
		light.Parent = part
	elseif decorationId == "PlatinumCrown" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 255, 255)
		light.Brightness = 1.4
		light.Range = 11
		light.Parent = part
	elseif decorationId == "ObsidianThrone" then
		local seat = Instance.new("Part")
		seat.Name = "Seat"
		seat.Size = Vector3.new(2.6, 0.6, 2.2)
		seat.Color = Color3.fromRGB(55, 50, 65)
		seat.Material = Enum.Material.Slate
		seat.Anchored = true
		seat.CanCollide = false
		seat.CFrame = part.CFrame * CFrame.new(0, def.Size.Y * 0.15, 0)
		seat.Parent = model
	elseif decorationId == "CelestialObelisk" then
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Brightness = 1.6
		light.Range = 16
		light.Parent = part
	end

	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("DecorationId", decorationId)
	model.PrimaryPart = part
	model:PivotTo(part.CFrame)
	model.Parent = folder
	return model
end

local function rebuildDecorations(player)
	local folder = getDecorationFolder(player)
	if not folder then
		return
	end
	folder:ClearAllChildren()
	local data = getData(player)
	for _, entry in data.decorations do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and typeof(entry.x) == "number" and typeof(entry.z) == "number" then
			local island = WorkspaceLayout.GetPlayerIsland(player)
			local topY = island and island:GetAttribute("BaseIslandTopY") or 0
			buildDecorationModel(player, entry.id, Vector3.new(entry.x, topY + 0.5, entry.z))
		end
	end
end

local function syncAttributes(player)
	local data = getData(player)
	local level = computeKingdomLevel(player)
	player:SetAttribute("KingdomLevel", level)
	player:SetAttribute("KingdomName", data.kingdomName)
	player:SetAttribute("LifetimeEssence", data.lifetimeEssence)
end

local function buildPayload(player, message)
	local data = getData(player)
	return {
		kingdomName = data.kingdomName,
		kingdomLevel = computeKingdomLevel(player),
		lifetimeEssence = data.lifetimeEssence,
		decorations = data.decorations,
		maxDecorations = MAX_DECORATIONS,
		availableDecorations = {
			{ id = "StoneLantern", displayName = "Stone Lantern", cost = 250 },
			{ id = "DragonBanner", displayName = "Dragon Banner", cost = 900 },
			{ id = "CrystalCrown", displayName = "Crystal Crown", cost = 1200 },
			{ id = "GoldenStatue", displayName = "Golden Statue", cost = 2000 },
		},
		message = message,
	}
end

local function sendState(player, message)
	syncAttributes(player)
	KingdomStateUpdated:FireClient(player, buildPayload(player, message))
end

local function saveNow(player)
	local data = playerKingdomData[player]
	if not data or not data.loaded or not dataStoreAvailable or not kingdomStore then
		return
	end
	local payload = {
		kingdomName = data.kingdomName,
		lifetimeEssence = data.lifetimeEssence,
		decorations = data.decorations,
		updatedAt = os.time(),
	}
	pcall(function()
		kingdomStore:UpdateAsync(tostring(player.UserId), function()
			return payload
		end)
	end)
end

local function queueSave(player)
	if saveQueued[player] then
		return
	end
	saveQueued[player] = true
	task.delay(4, function()
		saveQueued[player] = nil
		if player.Parent then
			saveNow(player)
		end
	end)
end

local function loadPlayer(player)
	local data = getData(player)
	if dataStoreAvailable and kingdomStore then
		local success, result = pcall(function()
			return kingdomStore:GetAsync(tostring(player.UserId))
		end)
		if success and typeof(result) == "table" then
			data.kingdomName = sanitizeName(result.kingdomName)
			data.lifetimeEssence = math.max(0, tonumber(result.lifetimeEssence) or 0)
			data.decorations = typeof(result.decorations) == "table" and result.decorations or {}
		end
	end
	data.loaded = true

	local startTime = os.clock()
	while player.Parent and os.clock() - startTime < 12 and not WorkspaceLayout.GetPlayerIsland(player) do
		task.wait(0.25)
	end
	rebuildDecorations(player)
	sendState(player)
end

local function changeEssence(player, delta)
	local essence = player:GetAttribute("DragonEssence") or 0
	if essence + delta < 0 then
		return false
	end
	player:SetAttribute("DragonEssence", essence + delta)
	return true
end

RequestKingdomData.OnServerInvoke = function(player)
	return buildPayload(player)
end

UpdateKingdomName.OnServerEvent:Connect(function(player, newName)
	local data = getData(player)
	data.kingdomName = sanitizeName(newName)
	queueSave(player)
	sendState(player, "Kingdom renamed to " .. data.kingdomName)
end)

local function placeDecorationForPlayer(player, decorationId, worldX, worldZ, skipCost)
	decorationId = tostring(decorationId or "")
	local def = DECORATION_DEFS[decorationId]
	if not def then
		sendState(player, "Unknown decoration")
		return false
	end

	local data = getData(player)
	if #data.decorations >= MAX_DECORATIONS then
		sendState(player, "Decoration limit reached")
		return false
	end

	if not skipCost then
		local available = {
			StoneLantern = 250,
			DragonBanner = 900,
			CrystalCrown = 1200,
			GoldenStatue = 2000,
		}
		local cost = available[decorationId] or 500
		if not changeEssence(player, -cost) then
			sendState(player, "Need " .. tostring(cost) .. " Dragon Essence")
			return false
		end
	end

	local island = WorkspaceLayout.GetPlayerIsland(player)
	if not island then
		sendState(player, "Island not ready")
		return false
	end

	local center = island:GetAttribute("BaseIslandCenter") or WorkspaceLayout.GetIslandSpawnCFrame().Position
	local size = island:GetAttribute("BaseIslandSize") or Vector3.new(80, 1, 80)
	local x = tonumber(worldX) or (center.X + math.random(-10, 10))
	local z = tonumber(worldZ) or (center.Z + math.random(-10, 10))
	x = math.clamp(x, center.X - size.X * 0.35, center.X + size.X * 0.35)
	z = math.clamp(z, center.Z - size.Z * 0.35, center.Z + size.Z * 0.35)
	local topY = island:GetAttribute("BaseIslandTopY") or center.Y

	table.insert(data.decorations, { id = decorationId, x = x, z = z })
	buildDecorationModel(player, decorationId, Vector3.new(x, topY + 0.5, z))
	queueSave(player)
	sendState(player, "Placed " .. def.DisplayName)
	return true
end

PlaceDecoration.OnServerEvent:Connect(function(player, decorationId, worldX, worldZ)
	placeDecorationForPlayer(player, decorationId, worldX, worldZ, false)
end)

GrantDecoration.Event:Connect(function(player, decorationId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	placeDecorationForPlayer(player, decorationId, nil, nil, true)
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayer(player)
	local lastEssence = player:GetAttribute("DragonEssence") or 0
	player:GetAttributeChangedSignal("DragonEssence"):Connect(function()
		local current = player:GetAttribute("DragonEssence") or 0
		local data = getData(player)
		if current > lastEssence then
			data.lifetimeEssence += current - lastEssence
		end
		lastEssence = current
		syncAttributes(player)
	end)
end)

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

local function refreshAllLevels()
	for _, player in Players:GetPlayers() do
		syncAttributes(player)
	end
end

task.spawn(function()
	while true do
		task.wait(8)
		refreshAllLevels()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveNow(player)
	playerKingdomData[player] = nil
	decorationFolders[player] = nil
	saveQueued[player] = nil
end)

local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

AdminBridge.register("Kingdom", {
	refreshState = function(player)
		sendState(player)
		return "Kingdom UI refreshed"
	end,
	save = function(player)
		saveNow(player)
		return "Kingdom progress saved"
	end,
	wipe = function(player)
		local data = getData(player)
		data.kingdomName = DEFAULT_NAME
		data.lifetimeEssence = 0
		data.decorations = {}
		rebuildDecorations(player)
		queueSave(player)
		sendState(player, "Kingdom wiped")
		return "Kingdom progress wiped"
	end,
})

local RebirthDomainBridge = require(ServerScriptService:WaitForChild("RebirthDomainBridge"))

RebirthDomainBridge.Register("Kingdom", {
	getSnapshotPatch = function(player)
		local data = getData(player)
		return {
			kingdomLevel = computeKingdomLevel(player),
			lifetimeEssence = math.max(0, math.floor(tonumber(data.lifetimeEssence) or 0)),
		}
	end,
	canReset = function()
		return { ok = true }
	end,
	resetRunState = function(player)
		syncAttributes(player)
		return { success = true }
	end,
	restorePermanentState = function()
		return { success = true }
	end,
})

print("[KingdomProgressManager] Kingdom level, naming, and decorations ready")
